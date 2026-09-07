# ข้อผิดพลาดแบบแอซิงก์และความปลอดภัยในการยกเลิก

หากคุณเคยเขียน async Rust มาระยะหนึ่ง คุณน่าจะเคยเจอบั๊กแปลกๆ ที่มองแวบแรกแล้วดูไม่มีเหตุผลเอาเสียเลย ข้อมูลจู่ๆ ก็สูญหาย, stream เกิดความเสียหาย หรือโค้ดทุกบรรทัดดูถูกต้องสมบูรณ์แบบ ทว่ากลับมีงานบางอย่างหลุดหายไปอย่างไร้ร่องรอย จากประสบการณ์ของผม ตัวการหลักเกือบทั้งหมดมักเกิดจากเรื่องของการยกเลิก (Cancellation): เมื่อ future ถูก drop ทิ้งไปก่อนที่มันจะทำงานจนเสร็จสิ้น งานที่มันกำลังทำอยู่จะหยุดชะงักลงทันที และโปรแกรมของคุณอาจตกค้างอยู่ในสถานะที่ไม่ได้คาดคิดมาก่อน

ในบทนี้ เราจะมาเจาะลึกแพตเทิร์นที่เป็นหลุมพรางดักผู้คนตรงจุดนี้ แม้แต่นักพัฒนา Rust ที่มีประสบการณ์สูงก็ยังพลาดได้ง่ายๆ โดยเราจะเน้นไปที่ `tokio::select!`, ความปลอดภัยในการยกเลิก (Cancellation Safety) และ structured concurrency primitive ที่จะช่วยให้คุณบริหารจัดการงานที่ทำงานพร้อมกันได้โดยไม่ชวนให้ปวดหัว

## หลักการทำงานของ `tokio::select!`

`tokio::select!` คือเครื่องมือหลักของเราสำหรับการรอรับผลลัพธ์จาก async operation หลายรายการพร้อมๆ กัน โดยมันจะคอย poll ตรวจสอบทุกๆ branch (แขนง) และเมื่อมี branch ใด branch หนึ่งทำงานเสร็จก่อน มันจะ drop ทิ้ง branch ที่เหลือทั้งหมดทันที แล้วจึงหันไปรันโค้ดใน handler ของ branch ที่เสร็จนั้น

```rust
tokio::select! {
    msg = rx.recv() => {
        // A message arrived from the channel.
        handle_message(msg).await;
    }
    _ = shutdown.cancelled() => {
        // A shutdown signal was received.
        tracing::info!("shutting down");
        return;
    }
}
```

จุดสำคัญที่สุดในที่นี้คือสิ่งที่เกิดขึ้นกับ branch ที่เป็นฝ่ายพ่ายแพ้ (branch ที่ไม่เสร็จเป็นอันแรก) เมื่อ `shutdown.cancelled()` ทำงานเสร็จก่อน future ของ `rx.recv()` จะถูกสั่ง drop ทิ้งทันที ซึ่งสำหรับเมธอด `recv()` นั้นไม่มีปัญหาใดๆ เกิดขึ้นเลย: เพราะ channel จะยังคงรักษาข้อความทั้งหมดที่ค้างอยู่ใน buffer ไว้อย่างปลอดภัย และเมื่อมีการเรียก `recv()` ในครั้งถัดไป มันก็จะหยิบข้อความมาทำงานต่อจากจุดเดิมได้อย่างราบรื่น คุณสมบัติอันยอดเยี่ยมเช่นนี้เองคือสิ่งที่เราเรียกว่า "ความปลอดภัยในการยกเลิก" (Cancellation Safety)

## "ปลอดภัยต่อการยกเลิก" หมายถึงอะไร

Future จะถือว่า "ปลอดภัยต่อการยกเลิก" (Cancellation-safe) ก็ต่อเมื่อการสั่ง drop มันทิ้งกลางคันไม่ก่อให้เกิดการสูญหายของข้อมูล หรือไม่ทิ้ง shared state ไว้ในสภาพที่เสียหาย ในเอกสารทางการของ Tokio จะมีการระบุไว้อย่างชัดเจนว่าแต่ละฟังก์ชันหรือเมธอดมีความปลอดภัยต่อการยกเลิกหรือไม่ และผมขอแนะนำอย่างยิ่งให้คุณตรวจสอบตรงนี้ให้ถี่ถ้วนเสมอก่อนที่จะนำคำสั่งใดๆ ไปวางไว้ใน branch ของ `select!`

ตัวอย่างของ operation ที่ **ปลอดภัยต่อการยกเลิก** ได้แก่ `channel.recv()`, `TcpListener::accept()`, `sleep()` และ `CancellationToken::cancelled()` การ drop future เหล่านี้ทิ้งมีความหมายเพียงแค่ว่า "เราเลิกรอแล้วนะ" และไม่มีข้อมูลใดๆ สูญหาย

ในทางตรงกันข้าม operation ที่ **ไม่ปลอดภัยต่อการยกเลิก** ได้แก่ `read_exact()`, `write_all()` และ `read_to_string()` ลองจินตนาการดูว่าจะเกิดอะไรขึ้นหาก `write_all` เขียนข้อมูลไปได้ 50 ไบต์จากทั้งหมด 100 ไบต์ แล้วจู่ๆ `select!` ก็สั่ง drop มันทิ้ง: ข้อมูล 50 ไบต์นั้นถูกส่งออกไปยัง network wire เรียบร้อยแล้ว แต่คุณกลับไม่มีทางรู้ได้เลยว่าส่งสำเร็จไปแล้วกี่ไบต์ และเมื่อมีความพยายามจะเขียนข้อมูลในครั้งถัดไป มันก็จะเริ่มต้นส่งข้อความใหม่อีก 100 ไบต์ตั้งแต่ต้น ส่งผลให้ data stream เกิดความเสียหายทันที

มาดูตัวอย่างรูปธรรมที่สะท้อนถึงปัญหานี้กัน:

```rust
// BROKEN: buf is not cancel-safe inside select!
let mut buf = vec![0u8; 1024];
loop {
    tokio::select! {
        // If this branch loses, we lose track of how many bytes
        // were read. The next iteration starts over with an empty buf.
        result = socket.read_exact(&mut buf) => {
            process(&buf).await;
        }
        _ = shutdown.cancelled() => {
            return;
        }
    }
}
```

ทางแก้ไขสำหรับกรณีนี้คือ การย้าย operation ที่ไม่ปลอดภัยต่อการยกเลิกออกไปจาก `select!` โดยสิ้นเชิง เพื่อเปิดโอกาสให้มันทำงานจนเสร็จสมบูรณ์เสมอ แล้วเก็บเฉพาะ operation ที่ cancellation-safe อย่างแท้จริง (เช่น การรอรับข้อมูลจาก channel) ไว้ภายใน branch ของ `select!`:

```rust
loop {
    tokio::select! {
        result = rx.recv() => {
            // Only cancel-safe operations in select! branches.
            if let Some(data) = result {
                process(&data).await;
            }
        }
        _ = shutdown.cancelled() => {
            return;
        }
    }
}
```

## โมเดลแอ็กเตอร์ แพตเทิร์นที่ทนทานต่อการยกเลิก

วิธีที่ผมพบว่ามีความน่าเชื่อถือที่สุดในการหลีกเลี่ยงบั๊กที่เกิดจากการยกเลิก คือการจัดวางโครงสร้างคอมโพเนนต์ที่ทำงานแบบขนานให้อยู่ในรูปแบบของ Actor Model โดย actor แต่ละตัวจะรัน loop เพื่อรอรับข้อความ, นำข้อความนั้นไปประมวลผลจนเสร็จสมบูรณ์ แล้วจึงค่อยวนกลับมารอรับข้อความถัดไป และเนื่องจาก `select!` จะทำงานเฉพาะในจังหวะระหว่างรอบของ loop เท่านั้น (ตอนที่ actor กำลังนอนรอ input ใหม่ ไม่ใช่ตอนที่กำลังทำงานอยู่กึ่งกลางคัน) จึงไม่มีความเสี่ยงใดๆ ที่จะเกิดการยกเลิกงานกลางคันขึ้นได้เลย

```rust
async fn run_worker(
    mut commands: mpsc::Receiver<Command>,
    shutdown: CancellationToken,
) {
    loop {
        let command = tokio::select! {
            cmd = commands.recv() => {
                match cmd {
                    Some(c) => c,
                    None => return, // Channel closed, all senders dropped.
                }
            }
            _ = shutdown.cancelled() => {
                tracing::info!("worker shutting down");
                return;
            }
        };

        // This runs to completion before the next select! iteration.
        // No cancellation risk here.
        process_command(command).await;
    }
}
```

นี่คือแพตเทิร์นที่เราเลือกใช้งานอย่างกว้างขวางใน [topos-protocol/topos](https://github.com/topos-protocol/topos) โดยแต่ละระบบย่อย (broadcast, synchronizer, API) จะรัน event loop ที่ทำ multiplex ระหว่างคำสั่ง, shutdown signal และ timer ต่างๆ ผ่านทาง `select!` แต่จะประมวลผลแต่ละ event จนเสร็จสิ้นอย่างสมบูรณ์ก่อนจะวนกลับขึ้นไปรับงานใหม่ที่จุดเริ่มต้นของ loop เสมอ ในตอนแรก โครงสร้างแบบนี้อาจดูเหมือนมีพิธีรีตองมากเกินจำเป็น แต่ในเวลาไม่นานมันจะตอบแทนคุณอย่างคุ้มค่า ด้วยการที่คุณจะไม่ต้องมานั่งปวดหัวไล่ล่าบั๊กพิลึกพิลั่นเหล่านี้อีกต่อไป

## การทำงานพร้อมกันแบบมีโครงสร้างด้วย CancellationToken

เมื่อแอปพลิเคชันของคุณประกอบด้วยระบบย่อยที่ทำงานพร้อมกันหลายตัว (เช่น HTTP server, background worker, metrics reporter) คุณจำเป็นต้องมีกลไกที่ชัดเจนในการส่งสัญญาณสั่งให้ทุกตัวปิดการทำงานลงอย่างพร้อมเพรียงกัน แล้วค่อยรอจนกว่าแต่ละตัวจะเก็บกวาดงานของตนเองเสร็จสิ้นจริงๆ ซึ่งนี่คือจุดที่ `tokio_util::sync::CancellationToken` ก้าวเข้ามามีบทบาทสำคัญ

```rust
use tokio_util::sync::CancellationToken;

let root_token = CancellationToken::new();

// Each subsystem gets a child token. Cancelling the root
// cancels all children, but cancelling a child does not
// affect siblings or the parent.
let http_token = root_token.child_token();
let worker_token = root_token.child_token();
let metrics_token = root_token.child_token();

// Spawn subsystems with their tokens.
let http_handle = tokio::spawn(run_http_server(http_token));
let worker_handle = tokio::spawn(run_background_worker(worker_token));
let metrics_handle = tokio::spawn(run_metrics_reporter(metrics_token));

// When a shutdown signal arrives, cancel the root.
wait_for_signal().await;
root_token.cancel();

// Wait for all subsystems to finish their cleanup.
let _ = tokio::join!(http_handle, worker_handle, metrics_handle);
tracing::info!("all subsystems shut down cleanly");
```

ความสัมพันธ์แบบ Parent-Child (แม่-ลูก) ช่วยให้สัญญาณการปิดระบบสามารถส่งต่อกระจายลงไปตามลำดับชั้นได้อย่างเป็นระบบ ระบบย่อยแต่ละตัวจะคอยเฝ้าดู `token.cancelled()` ภายใน event loop ของตนเอง (ผ่าน `select!`) และจะเริ่มขั้นตอน cleanup ทันทีเมื่อสัญญาณถูกกระตุ้นขึ้น ส่วนฝั่ง parent ก็จะคอยจนกระทั่ง handle ของงานย่อยทั้งหมด resolve สมบูรณ์ ทำให้เรามั่นใจได้อย่างเต็มร้อยว่าจะไม่มีงานใดถูกทอดทิ้งไว้กลางทาง

เราจะมาเจาะลึกแพตเทิร์นนี้อย่างละเอียดในบท [การปิดระบบอย่างนุ่มนวล](./graceful-shutdown.md) ซึ่งเราจะมาประกอบลำดับขั้นตอนการปิดระบบอย่างเต็มรูปแบบสำหรับแอปพลิเคชันที่ใช้งานจริง

## ข้อผิดพลาดที่พบบ่อย

**ใช้ `select!` ทั้งที่จริงๆ ต้องการ `join!`** คุณอาจเคยสงสัยว่าทำไมงานชิ้นที่สองถึงไม่เคยทำงานเสร็จสักที หากคุณต้องการรันสองงานควบคู่กันแล้วรอให้ทั้งคู่เสร็จสิ้น คุณต้องใช้ `tokio::join!` หรือ `tokio::try_join!` เพราะ `select!` จะคืนผลลัพธ์ทันทีที่งานแรกเสร็จ แล้วสั่ง drop งานที่เหลือทิ้งทั้งหมด ผมเคยเห็นความเข้าใจผิดตรงนี้ทำให้ข้อมูลหรืองานสูญหายมานับครั้งไม่ถ้วน

**ลืมไปว่า `select!` ที่อยู่ใน loop ต้องให้ทุก branch ปลอดภัยต่อการยกเลิก** ทุกครั้งที่ loop เริ่มต้นรอบใหม่ future ที่ยังค้างจากรอบก่อนหน้าจะถูก drop ทิ้ง หาก future ตัวใดตัวหนึ่งไม่ใช่ cancellation-safe ข้อมูลก็อาจสูญหายไปเงียบๆ ระหว่างรอบการทำงานได้ แพตเทิร์น Actor Model ที่เราได้ดูกันไปข้างต้นจะช่วยขจัดปัญหานี้ โดยการจำกัด branch ของ `select!` ให้มีเฉพาะ operation ที่ปลอดภัยต่อการยกเลิกเท่านั้น (เช่น การรับข้อมูลจาก channel, การนับของ timer หรือสัญญาณ cancellation)

**ถือ MutexGuard ข้ามจุด await** หากใช้ `std::sync::Mutex` การถือ guard ข้ามจุด `.await` อาจทำให้ runtime thread ทั้งเธรดถูกบล็อกสนิท ส่วนในกรณีของ `tokio::sync::Mutex` แม้จะปลอดภัยจากการบล็อกเธรด แต่ก็อาจทำให้เกิดการถือ lock ค้างไว้นานเกินไปหาก future ภายใน critical section นั้นใช้เวลาประมวลผลนาน ในทั้งสองกรณี ผมขอแนะนำให้พิจารณาใช้แพตเทิร์น Actor/Channel แทน นั่นคือส่งข้อความไปหา task ที่เป็นเจ้าของ state โดยตรง แทนที่จะพยายามแย่งกัน acquire lock บน shared state จากหลายๆ task

**ไม่ยอมจัดการ branch `else` ใน `select!`** หาก channel ทั้งหมดที่อยู่ใน `select!` ปิดตัวลง (ทุก `recv()` ทยอยคืนค่า `None` ออกมา) และไม่มีการระบุ branch `else` รองรับไว้ ตัวแมโคร `select!` จะเกิดอาการ panic ทันที ดังนั้นในโค้ด production ควรจัดการกรณี `None` อย่างรัดกุมรอบคอบเสมอ หรือตรวจสอบให้มั่นใจว่ามีอย่างน้อยหนึ่ง branch (เช่น cancellation token) ที่ไม่มีวันปิดตัวลง

## `tokio::pin!` และเมื่อไหร่ที่คุณต้องใช้

Future บางประเภทจำเป็นต้องถูก pin เสียก่อนจึงจะสามารถนำไปใช้งานใน `select!` ได้ เนื่องจาก `select!` กำหนดเงื่อนไขไว้ว่า future ในแต่ละ branch จะต้อง implement เทรต `Unpin` หรือไม่ก็ต้องผ่านการ pin มาแล้ว คุณมักจะพบเจอกรณีนี้บ่อยที่สุดเมื่อมีการเก็บ future ไว้ในตัวแปรเพื่อนำมาใช้ซ้ำข้ามรอบการทำงานของ loop:

```rust
let sleep_future = tokio::time::sleep(Duration::from_secs(30));
tokio::pin!(sleep_future);

loop {
    tokio::select! {
        _ = &mut sleep_future => {
            tracing::info!("timeout reached");
            break;
        }
        msg = rx.recv() => {
            // Process message. The sleep future continues
            // from where it left off on the next iteration.
        }
    }
}
```

หากปราศจาก `tokio::pin!` คอมไพเลอร์ของ Rust จะปฏิเสธโค้ดชุดนี้ทันทีด้วยข้อผิดพลาดเกี่ยวกับ bound ของ `Unpin` หากคุณยังไม่เคยเจอ error นี้มาก่อน ก็ไม่ต้องกังวลไปครับ อีกไม่นานคุณจะได้พบกับมันอย่างแน่นอน การทำ pinning จะช่วยการันตีว่าตำแหน่งในหน่วยความจำของ future จะคงที่อยู่กับที่ข้ามจุด await ต่างๆ ซึ่งเป็นข้อกำหนดสำคัญของกลไกการ poll ภายในแมโคร `select!` นี่เป็นหนึ่งในเรื่องที่อาจชวนให้สับสนในตอนแรก แต่จะกลายเป็นเรื่องปกติที่เป็นธรรมชาติอย่างยิ่งเมื่อคุณได้เห็นและใช้งานแพตเทิร์นนี้ไปสักสองสามครั้ง
