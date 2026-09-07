# การปิดระบบอย่างนุ่มนวลและการจัดการไลฟ์ไซเคิล

ในบท [การดีพลอยต์](./deployment.md) เราได้ดูวิธีปิดเซิร์ฟเวอร์ Axum ตัวเดียวอย่างหมดจดเมื่อได้รับสัญญาณ SIGTERM กันไปแล้ว นั่นเป็นเพียงกรณีที่เรียบง่ายที่สุด แต่ในโลกความเป็นจริง แอปพลิเคชันบน production มักไม่ได้มีแค่เซิร์ฟเวอร์ HTTP เพียงอย่างเดียว คุณมักจะมี background worker ที่กำลังประมวลผลงาน, การเชื่อมต่อ WebSocket ที่เปิดค้างไว้เพื่อระบายข้อความ, ตัวรายงานเมตริกที่กำลังฟลัชข้อมูล, และพูลฐานข้อมูลที่ต้องปิดการทำงานอย่างเป็นระเบียบ หากซับซิสเต็มใดซับซิสเต็มหนึ่งเหล่านี้ยังคงทำงานค้างอยู่ตอนที่โพรเซสยุติลง คุณอาจต้องเจอกับปัญหาข้อมูลสูญหาย การเชื่อมต่อขาดกะทันหัน หรือสถานะข้อมูลที่ไม่สอดคล้องกัน

ในบทนี้ เราจะมาดูวิธีประสานงานการปิดระบบ (graceful shutdown) ข้ามหลายซับซิสเต็มที่ทำงานพร้อมกัน เพื่อให้แต่ละส่วนสามารถเคลียร์งานที่ค้างอยู่ (in-flight work) ให้เสร็จสิ้นตามลำดับขั้นตอนที่ถูกต้อง ก่อนที่โพรเซสจะจบการทำงานลง

## CancellationToken ในฐานะพรามิทีฟกลางของการประสานงาน

หากคุณเคยพยายามประสานงานการปิดระบบมาก่อน คุณอาจจะเคยหยิบแชนเนล oneshot หรือแฟล็ก `Arc<AtomicBool>` มาใช้งาน วิธีการเหล่านั้นใช้งานได้จริง แต่โค้ดจะเริ่มยุ่งเหยิงอย่างรวดเร็วทันทีที่คุณมีซับซิสเต็มมากกว่าสองตัวขึ้นไป `tokio_util::sync::CancellationToken` จึงเหมาะสมกับงานนี้มากกว่ามาก โดยมีฟิวเจอร์ `cancelled()` ที่จะ resolve เมื่อโทเคนถูกยกเลิก และยังรองรับความสัมพันธ์แบบพ่อแม่-ลูก (parent-child relationship) ซึ่งการยกเลิกโทเคนพ่อแม่จะส่งผลให้โทเคนลูกทั้งหมดถูกยกเลิกตามไปด้วยโดยอัตโนมัติ

```rust
use tokio_util::sync::CancellationToken;

// Create a root token for the entire application.
let root_token = CancellationToken::new();

// Each subsystem gets a child token.
let http_token = root_token.child_token();
let worker_token = root_token.child_token();
let telemetry_token = root_token.child_token();
```

เมื่อสัญญาณปิดระบบมาถึง เราจะสั่งยกเลิก root token จากนั้นทุกซับซิสเต็มจะรับรู้การแจ้งเตือนผ่าน child token ของตนเอง ตัวโทเคนนี้ออกแบบมาเพื่อรองรับการยกเลิกโดยเฉพาะ และสามารถประกอบเข้ากับ `tokio::select!` ได้อย่างเป็นธรรมชาติ ช่วยให้โครงสร้างโค้ดอ่านและทำความเข้าใจได้ง่ายกว่าทางเลือกอื่นอย่างเห็นได้ชัด

## แอปพลิเคชันหลายซับซิสเต็ม

มาดูตัวอย่างฟังก์ชัน `main` ในสถานการณ์จริงที่เริ่มทำงาน 3 ซับซิสเต็มพร้อมกัน และจัดการประสานงานการปิดระบบของแต่ละตัว:

```rust
use tokio_util::sync::CancellationToken;

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    let config = Config::from_env()?;
    init_tracing(&config.log_level);

    let pool = create_pool(config.database_url.expose_secret()).await?;
    sqlx::migrate!("./migrations").run(&pool).await?;

    let root_token = CancellationToken::new();

    // Spawn the HTTP server.
    let http_token = root_token.child_token();
    let http_handle = tokio::spawn({
        let pool = pool.clone();
        let config = config.clone();
        async move {
            let app = build_router(config, pool);
            let listener = tokio::net::TcpListener::bind("0.0.0.0:3000")
                .await
                .expect("failed to bind");
            axum::serve(listener, app)
                .with_graceful_shutdown(http_token.cancelled_owned())
                .await
                .expect("server error");
        }
    });

    // Spawn a background job worker.
    let worker_token = root_token.child_token();
    let worker_handle = tokio::spawn({
        let pool = pool.clone();
        async move {
            run_job_worker(pool, worker_token).await;
        }
    });

    // Spawn a metrics reporter.
    let metrics_token = root_token.child_token();
    let metrics_handle = tokio::spawn(async move {
        run_metrics_reporter(metrics_token).await;
    });

    // Wait for the shutdown signal, then cancel everything.
    wait_for_signal().await;
    tracing::info!("shutdown signal received");
    root_token.cancel();

    // Wait for all subsystems to finish.
    let _ = tokio::join!(http_handle, worker_handle, metrics_handle);

    // Close the database pool after all subsystems have stopped.
    pool.close().await;

    tracing::info!("shutdown complete");
    Ok(())
}
```

จุดสำคัญที่ต้องสังเกตตรงนี้คือ พูลฐานข้อมูลจะถูกปิด **หลังจาก** ที่ซับซิสเต็มทั้งหมดหยุดทำงานลงแล้วเท่านั้น เหตุผลคืออะไร? เพราะในระหว่างช่วงระบายงาน (drain phase) ซับซิสเต็มเหล่านั้นอาจยังจำเป็นต้องรันคิวรีที่ค้างอยู่ หากคุณปิดพูลไปก่อน คิวรีเหล่านั้นก็จะล้มเหลวทันที นี่คือหัวใจสำคัญของ "การรื้อถอนแบบมีลำดับ" (ordered teardown) ซึ่งเป็นเรื่องที่คุ้มค่าแก่การทำความเข้าใจอย่างละเอียด

## การรื้อถอนแบบมีลำดับ

กฎทั่วไปคือ: จงคืนรีซอร์สในลำดับย้อนกลับของสายดีเพนเดนซี (dependency chain) หากแฮนด์เลอร์ HTTP ของเราต้องพึ่งพาพูลฐานข้อมูล และตัวรายงานเมตริกต้องพึ่งพาเซิร์ฟเวอร์ HTTP ที่ยังคงเปิดอยู่ ลำดับการรื้อถอนที่ถูกต้องควรเป็นดังนี้:

1. หยุดรับการเชื่อมต่อ HTTP ใหม่ (Axum จัดการเรื่องนี้ให้เมื่อ shutdown future ทำงานสำเร็จ/resolve)
2. ระบายคำขอ HTTP ที่ค้างอยู่ (in-flight requests) ให้เสร็จสิ้นทั้งหมด
3. หยุด background worker (ปล่อยให้มันทำงานชิ้นปัจจุบันให้เสร็จ แล้วค่อยออกจากลูป)
4. ฟลัชตัวรายงานเมตริก (ส่งข้อมูลทั้งหมดที่ค้างอยู่ในบัฟเฟอร์ออกไปให้ครบ แล้วค่อยออกจากลูป)
5. ปิดพูลฐานข้อมูล

ในทางปฏิบัติ ขั้นตอนที่ 2 ถึง 4 มักจะเกิดขึ้นไปพร้อมๆ กัน (ผ่าน `tokio::join!`) เนื่องจากแต่ละซับซิสเต็มต่างจัดการระบายงานของตนเองอย่างเป็นอิสระ สิ่งสำคัญอย่างเดียวที่เราต้องควบคุมให้รัดกุมคือ รีซอร์สส่วนกลางอย่าง connection pool จะต้องไม่ถูกปิดเด็ดขาดจนกว่าผู้ใช้งาน (consumer) ทุกตัวจะหยุดทำงานลงอย่างสมบูรณ์

## การจัดการพูลทาสก์แบบไดนามิกด้วย FuturesUnordered

ซับซิสเต็มบางประเภทไม่ได้มีจำนวนทาสก์ที่คงที่ตายตัว เช่น คุณอาจมี 1 ทาสก์ต่อ 1 การเชื่อมต่อ WebSocket ที่เปิดอยู่, 1 ทาสก์ต่องานเบื้องหลังที่กำลังประมวลผลอยู่, หรือ 1 ทาสก์ต่อ gRPC สตรีมที่กำลังเชื่อมต่อ ซึ่งจำนวนเหล่านี้มีความผันผวนตลอดเวลา สำหรับสถานการณ์เช่นนี้ `FuturesUnordered` เป็นเครื่องมือที่ยอดเยี่ยมมาก เพราะมันทำหน้าที่เป็นสตรีมของผลลัพธ์ทาสก์ที่ทำงานเสร็จแล้ว ทำให้คุณสามารถรอระบายทาสก์ทั้งหมดได้อย่างเป็นระเบียบในระหว่างกระบวนการปิดระบบ

```rust
use futures::stream::FuturesUnordered;
use futures::StreamExt;

async fn run_connection_manager(
    mut new_connections: mpsc::Receiver<TcpStream>,
    shutdown: CancellationToken,
) {
    let mut active_tasks = FuturesUnordered::new();

    loop {
        tokio::select! {
            // Accept new connections while running.
            conn = new_connections.recv() => {
                if let Some(stream) = conn {
                    let token = shutdown.child_token();
                    active_tasks.push(tokio::spawn(
                        handle_connection(stream, token)
                    ));
                }
            }

            // Reap completed tasks to free resources.
            Some(result) = active_tasks.next() => {
                if let Err(e) = result {
                    tracing::error!(error = ?e, "connection task panicked");
                }
            }

            // On shutdown, stop accepting new connections
            // and drain the remaining tasks.
            _ = shutdown.cancelled() => {
                tracing::info!(
                    active = active_tasks.len(),
                    "shutting down, draining active connections"
                );
                break;
            }
        }
    }

    // Drain: wait for all active connections to finish.
    while let Some(result) = active_tasks.next().await {
        if let Err(e) = result {
            tracing::error!(error = ?e, "connection task panicked during drain");
        }
    }

    tracing::info!("all connections drained");
}
```

ผมอยากเน้นย้ำถึงโครงสร้างแบบสองเฟส (two-phase structure) ตรงนี้เป็นพิเศษ เพราะนี่คือแพตเทิร์นที่คุณจะได้นำไปใช้บ่อยมาก โดยระหว่างการทำงานตามปกติ ลูป `select!` จะคอยรับการเชื่อมต่อใหม่ เคลียร์ทาสก์ที่ทำงานเสร็จสิ้นแล้ว และคอยเฝ้าฟังสัญญาณปิดระบบ และเมื่อการปิดระบบถูกกระตุ้นขึ้น ลูปจะหยุดทำงาน (break) ทันทีเพื่อก้าวเข้าสู่เฟสการระบายงาน (drain phase) ซึ่งก็คือการวนลูปรอให้ทาสก์ที่ยังค้างอยู่ทั้งหมดทำงานจนเสร็จสิ้น ทาสก์ของการเชื่อมต่อแต่ละตัวจะได้รับ child cancellation token ส่งต่อเข้าไป เพื่อเปิดโอกาสให้มันได้ทำความสะอาดรีซอร์สของตนเอง (เช่น ฟลัชบัฟเฟอร์ หรือส่ง close frame) ให้เรียบร้อยก่อนที่จะจบการทำงาน

## การล้างการเชื่อมต่อ

สำหรับการเชื่อมต่อที่มีอายุยืนยาว (long-lived connections) เช่น WebSocket ลำดับการล้างข้อมูลภายในแต่ละทาสก์มีความสำคัญมากกว่าที่คุณคาดคิด โปรเจกต์ [mozilla-services/autopush-rs](https://github.com/mozilla-services/autopush-rs) ถือเป็นตัวอย่างที่ดีเยี่ยมในการจัดการเรื่องนี้อย่างรัดกุม: เมื่อการเชื่อมต่อ WebSocket ต้องปิดตัวลง มันจะตัดการเชื่อมต่อออกจาก client registry, ทำการระบายการแจ้งเตือนจากฝั่งเซิร์ฟเวอร์ที่ยังค้างอยู่ผ่าน `on_server_notif_shutdown()`, เรียก `client.shutdown()` พร้อมแนบรายละเอียดข้อผิดพลาด, และปิดเซสชันด้วยรหัสเหตุผลการปิด WebSocket (close reason) ที่เหมาะสม การเก็บกวาดตามลำดับย้อนกลับเช่นนี้ช่วยรับประกันได้ว่าจะไม่มี notification ใดๆ ตกหล่นสูญหายไปในช่องว่างระหว่างการตัดสินใจปิดระบบกับการปิดการเชื่อมต่อจริง

หลักการที่ผมอยากแนะนำให้ยึดถือคือ: เมื่อการเชื่อมต่อหรือทาสก์ใดๆ จำเป็นต้องปิดตัวลง ให้สะสางงานขาออกที่ค้างอยู่ทั้งหมดให้เสร็จสิ้นเสียก่อน (ฟลัช write buffer, ส่งการแจ้งเตือนที่ค้างอยู่, ยืนยันรับทราบข้อความที่ยังค้างอยู่) ก่อนที่จะปิดทรานสปอร์ต (underlying transport) ด้านล่าง แม้การไล่เรียงรายละเอียดขั้นตอนเหล่านี้อาจดูจุกจิก แต่จากประสบการณ์จริง บั๊กที่เกิดจากการละเลยขั้นตอนการทำความสะอาดนั้นตามแก้ได้ยากกว่าการเขียนโค้ด cleanup เหล่านี้อย่างเทียบไม่ติด

## การทดสอบพฤติกรรมการปิดระบบ

คุณอาจสงสัยว่าจะทดสอบการทำงานทั้งหมดนี้ได้อย่างไร โค้ดส่วนการปิดระบบมักเป็นเรื่องที่ทดสอบได้ยาก เพราะมักจะขึ้นอยู่กับจังหวะเวลา (timing), การทำงานพร้อมกัน (concurrency), และ edge case ที่มักจะโผล่มาเฉพาะเมื่อเกิดลำดับเหตุการณ์แบบจำเพาะเจาะจงเท่านั้น สิ่งที่ผมพบว่าได้ผลดีมากคือการใช้ `tokio::time::timeout` เพื่อตรวจสอบและรับประกันว่าขั้นตอนการปิดระบบทั้งหมดจะเสร็จสิ้นภายในระยะเวลาที่กำหนดไว้อย่างสมเหตุสมผล:

```rust
#[tokio::test]
async fn shutdown_completes_within_timeout() {
    let token = CancellationToken::new();
    let handle = tokio::spawn(run_my_subsystem(token.clone()));

    // Give it a moment to start up.
    tokio::time::sleep(Duration::from_millis(100)).await;

    // Trigger shutdown.
    token.cancel();

    // It should finish within 5 seconds.
    let result = tokio::time::timeout(
        Duration::from_secs(5),
        handle,
    ).await;

    assert!(result.is_ok(), "shutdown did not complete within timeout");
}
```

หากการทดสอบนี้เกิดอาการค้าง (hang) นั่นเป็นสัญญาณชัดเจนว่าเส้นทางการปิดระบบของคุณมีบั๊กแฝงอยู่ อาจมีส่วนใดส่วนหนึ่งกำลังรอรับข้อความจากแชนเนลที่จะไม่มีวันส่งมาอีก หรือมีทาสก์บางตัวที่ไม่ได้ตรวจสอบ cancellation token ของตัวเอง แม้จะเป็นเพียงแบบทดสอบสั้นๆ เรียบง่าย แต่กลับช่วยดักจับปัญหาคอขาดบาดตายในระบบจริงได้อย่างยอดเยี่ยม และเมื่อคุณมีเทสต์นี้คอยกำกับไว้ คุณก็จะปรับแก้ตรรกะการปิดระบบในอนาคตได้อย่างมั่นใจยิ่งขึ้น
