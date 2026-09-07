# การปิดระบบอย่างนุ่มนวลและการจัดการไลฟ์ไซเคิล

ในบท [การดีพลอยต์](./deployment.md) เราได้ดูวิธีปิดเซิร์ฟเวอร์ Axum ตัวเดียวอย่างสะอาดเมื่อมี SIGTERM เข้ามา นั่นครอบคลุมเคสที่ง่ายที่สุด แต่แอปพลิเคชันใน production ไม่ค่อยเป็นแค่เซิร์ฟเวอร์ HTTP เท่านั้น คุณมี worker เบื้องหลังที่ประมวลผลงาน การเชื่อมต่อ WebSocket ที่เปิดอยู่กำลังระบายข้อความ ตัวรายงานเมตริกกำลังฟลัชข้อมูล และพูลฐานข้อมูลที่ต้องปิดอย่างสะอาด ถ้าซับซิสเต็มใดก็ตามเหล่านี้ยังทำงานอยู่ตอนที่โพรเซสจบลง คุณจะจบลงด้วยข้อมูลที่สูญหาย การเชื่อมต่อที่ขาด หรือสถานะที่ไม่สอดคล้องกัน

ในบทนี้ เราจะประสานงานการปิดระบบข้ามซับซิสเต็มที่ทำงานพร้อมกันหลายตัว เพื่อให้แต่ละตัวทำงานที่กำลังดำเนินอยู่ให้เสร็จในลำดับที่ถูกต้องก่อนที่โพรเซสจะจบลง

## CancellationToken ในฐานะพรามิทีฟกลางของการประสานงาน

ถ้าคุณเคยพยายามประสานงานการปิดระบบมาก่อน คุณอาจหยิบใช้แชนเนล oneshot หรือแฟล็ก `Arc<AtomicBool>` สิ่งเหล่านั้นใช้ได้ แต่มันเริ่มรกเร็วทันทีที่คุณมีซับซิสเต็มเกินสองตัว `tokio_util::sync::CancellationToken` เหมาะกับตรงนี้มากกว่าเยอะ มันให้ฟิวเจอร์ `cancelled()` ที่ resolve เมื่อโทเคนถูกยกเลิก และรองรับความสัมพันธ์แบบพ่อแม่-ลูกที่การยกเลิกพ่อแม่จะยกเลิกลูกทั้งหมดโดยอัตโนมัติ

```rust
use tokio_util::sync::CancellationToken;

// Create a root token for the entire application.
let root_token = CancellationToken::new();

// Each subsystem gets a child token.
let http_token = root_token.child_token();
let worker_token = root_token.child_token();
let telemetry_token = root_token.child_token();
```

เมื่อสัญญาณปิดระบบมาถึง เรายกเลิกโทเคนราก และทุกซับซิสเต็มเห็นมันผ่านโทเคนลูกของตัวเอง โทเคนนี้ตระหนักรู้ถึงการยกเลิกและผสานเข้ากับ `tokio::select!` ได้อย่างเป็นธรรมชาติ ซึ่งทำให้โค้ดอ่านง่ายกว่าทางเลือกอื่นๆ มาก

## แอปพลิเคชันหลายซับซิสเต็ม

มาดูฟังก์ชัน `main` ที่สมจริงซึ่งเริ่มซับซิสเต็มสามตัวและประสานงานการปิดระบบของมัน:

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

สิ่งสำคัญที่ต้องสังเกตตรงนี้คือพูลฐานข้อมูลถูกปิด **หลังจาก** ซับซิสเต็มทั้งหมดหยุดทำงานแล้ว ทำไม? เพราะซับซิสเต็มเหล่านั้นอาจยังรันควิวรีอยู่ระหว่างเฟสระบายของมัน ถ้าคุณปิดพูลก่อน ควิวรีเหล่านั้นจะล้มเหลว นี่คือสิ่งที่ผมหมายถึงการรื้อถอนแบบมีลำดับ และมันคุ้มค่าที่จะพิจารณาให้ละเอียดขึ้น

## การรื้อถอนแบบมีลำดับ

กฎทั่วไปคือ: ปล่อยแหล่งข้อมูลในลำดับย้อนกลับของสายดีเพนเดนซีของมัน ถ้าแฮนด์เลอร์ HTTP ของเราพึ่งพาพูลฐานข้อมูล และตัวรายงานเมตริกพึ่งพาเซิร์ฟเวอร์ HTTP ที่ยังทำงานอยู่ ลำดับการรื้อถอนของเราควรเป็น:

1. หยุดรับการเชื่อมต่อ HTTP ใหม่ (Axum จัดการเรื่องนี้เมื่อ shutdown future resolve)
2. ระบายคำขอ HTTP ที่กำลังดำเนินอยู่ให้เสร็จ
3. หยุด worker เบื้องหลัง (มันทำงานปัจจุบันให้เสร็จ แล้วจึงออกจากลูป)
4. ฟลัชตัวรายงานเมตริก (มันส่งข้อมูลที่บัฟเฟอร์ไว้ แล้วจึงออกจากลูป)
5. ปิดพูลฐานข้อมูล

ในทางปฏิบัติ ขั้นที่ 2 ถึง 4 เกิดขึ้นพร้อมกัน (ผ่าน `tokio::join!`) เพราะซับซิสเต็มแต่ละตัวจัดการการระบายของตัวเองอย่างอิสระ สิ่งเดียวที่เราต้องทำให้แน่ใจคือแหล่งข้อมูลที่ใช้ร่วมกันอย่างพูลจะไม่ถูกปิดจนกว่าผู้บริโภคทุกตัวจะหยุดทำงาน

## การจัดการพูลทาสก์แบบไดนามิกด้วย FuturesUnordered

ซับซิสเต็มบางชนิดไม่มีจำนวนทาสก์ที่ตายตัว คุณอาจมีหนึ่งทาสก์ต่อการเชื่อมต่อ WebSocket ที่ใช้งานอยู่ หนึ่งต่องานเบื้องหลังที่กำลังดำเนินอยู่ หนึ่งต่อสตรีม gRPC ที่เชื่อมต่ออยู่ จำนวนเปลี่ยนแปลงตลอดเวลา สำหรับสถานการณ์เหล่านี้ `FuturesUnordered` เป็นเครื่องมือที่ยอดเยี่ยม เพราะมันให้สตรีมของความสำเร็จของทาสก์ที่คุณสามารถระบายได้ระหว่างการปิดระบบ

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

ผมอยากเน้นโครงสร้างสองเฟสตรงนี้ เพราะมันคือแพตเทิร์นที่คุณจะใช้บ่อย ระหว่างการทำงานปกติ ลูป `select!` รับการเชื่อมต่อใหม่ เก็บเกี่ยวการเชื่อมต่อที่เสร็จแล้ว และคอยดูสัญญาณปิดระบบ เมื่อการปิดระบบเริ่มทำงาน ลูปจะเบรกและเราเข้าสู่เฟสระบาย ซึ่งก็แค่รอให้ทาสก์ที่เหลือทั้งหมดเสร็จสมบูรณ์ ทาสก์การเชื่อมต่อแต่ละตัวได้รับ cancellation token ลูก เพื่อให้มันล้างแหล่งข้อมูลของตัวเองได้ (ฟลัชบัฟเฟอร์ ส่งเฟรมปิด) ก่อนที่จะคืนค่า

## การล้างการเชื่อมต่อ

สำหรับการเชื่อมต่อที่อายุยืนอย่าง WebSocket ลำดับการล้างภายในทาสก์การเชื่อมต่อแต่ละตัวสำคัญกว่าที่คุณคาดคิดเสียอีก โปรเจกต์ [mozilla-services/autopush-rs](https://github.com/mozilla-services/autopush-rs) เป็นตัวอย่างที่ดีของการทำเรื่องนี้อย่างละเอียดถี่ถ้วน: เมื่อการเชื่อมต่อ WebSocket ปิดตัวลง มันจะตัดการเชื่อมต่อจากรีจิสทรีของไคลเอนต์ ระบายการแจ้งเตือนจากเซิร์ฟเวอร์ที่เหลือผ่าน `on_server_notif_shutdown()` เรียก `client.shutdown()` พร้อมรายละเอียดข้อผิดพลาด แล้วปิดเซสชันด้วยเหตุผลการปิด WebSocket ที่เหมาะสม การล้างในลำดับย้อนกลับแบบนี้ทำให้ไม่มีการแจ้งเตือนสูญหายระหว่างการตัดสินใจปิดระบบกับการปิดการเชื่อมต่อจริง

หลักการที่ผมอยากให้คุณทำตาม: เมื่อการเชื่อมต่อหรือทาสก์ปิดตัวลง ให้ทำงานขาออกที่ค้างอยู่ทั้งหมดให้เสร็จ (ฟลัชบัฟเฟอร์การเขียน ส่งการแจ้งเตือนที่เหลือ ยืนยันการรับข้อความที่ค้างอยู่) ก่อนปิดท่อส่งสัญญาณข้างใต้ การคิดผ่านทุกขั้นตอนเหล่านี้อาจดูน่าเบื่อ แต่จากประสบการณ์ของผม บั๊กที่คุณได้จากการข้ามการล้างนั้นแก้ยากกว่าตัวโค้ดการล้างเองมาก

## การทดสอบพฤติกรรมการปิดระบบ

คุณอาจสงสัยว่าจะทดสอบทั้งหมดนี้อย่างไร ตรรกะการปิดระบบเป็นเรื่องที่จัดการยากเพราะมันเกี่ยวข้องกับจังหวะเวลา การทำงานพร้อมกัน และเคสขอบที่โผล่มาเฉพาะภายใต้ลำดับเหตุการณ์จำเพาะ สิ่งที่ผมพบว่าใช้ได้ดีคือการใช้ `tokio::time::timeout` เพื่อให้แน่ใจว่าลำดับการปิดระบบของคุณเสร็จสมบูรณ์ภายในระยะเวลาที่สมเหตุสมผล:

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

ถ้าการทดสอบนี้ค้าง คุณจะรู้ว่าเส้นทางการปิดระบบของคุณมีบั๊ก มีอะไรบางอย่างกำลังรอแชนเนลที่จะไม่มีวันส่ง หรือทาสก์ไม่ได้ตรวจสอบ cancellation token ของมัน มันเป็นการทดสอบง่ายๆ แต่จับปัญหาจริงได้ และเมื่อคุณมีมันไว้ในที่แล้ว คุณจะมั่นใจมากขึ้นเวลาจะแก้ตรรกะการปิดระบบของคุณในภายหลัง
