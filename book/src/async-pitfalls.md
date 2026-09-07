# ข้อผิดพลาดแบบแอซิงก์และความปลอดภัยในการยกเลิก

ถ้าคุณเขียน async Rust มาสักระยะ คุณคงเคยเจอบั๊กที่ตอนแรกดูไม่มีเหตุผล ข้อมูลหายไป สตรีมเสียหาย ทุกอย่างดูเหมือนถูกต้อง แต่มีอะไรบางอย่างทำงานหล่นหายไปเงียบๆ จากประสบการณ์ของผม ผู้ร้ายเกือบตลอดคือการยกเลิก: เมื่อฟิวเจอร์ถูกดรอปก่อนที่จะทำงานเสร็จ งานที่มันกำลังทำอยู่ก็หยุดลงเฉยๆ และโปรแกรมของคุณอาจจบลงในสถานะที่คุณไม่เคยวางแผนไว้

เราจะเดินดูแพตเทิร์นที่ทำให้คนสะดุดตรงนี้ แม้แต่นักพัฒนา Rust ที่มีประสบการณ์ เราจะโฟกัสไปที่ `tokio::select!` ความปลอดภัยในการยกเลิก และพรามิทีฟการทำงานพร้อมกันแบบมีโครงสร้างที่จะช่วยให้คุณจัดการงานที่ทำงานพร้อมกันได้โดยไม่ปวดหัว

## หลักการทำงานของ `tokio::select!`

`tokio::select!` คือเครื่องมือหลักของเราในการรอการทำงานแบบแอซิงก์หลายรายการพร้อมกัน มันโพลล์ทุกแขนงของมัน และเมื่อแขนงแรกเสร็จ มันจะดรอปแขนงที่เหลือแล้วรันแฮนด์เลอร์ที่ตรงกัน

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

สิ่งสำคัญตรงนี้คือสิ่งที่เกิดขึ้นกับแขนงที่แพ้ เมื่อ `shutdown.cancelled()` เสร็จก่อน ฟิวเจอร์ของ `rx.recv()` จะถูกดรอป สำหรับ `recv()` นี่ไม่ใช่ปัญหาเลย: แชนเนลยังคงเก็บข้อความทั้งหมดที่อยู่ในบัฟเฟอร์ไว้ และการเรียก `recv()` ครั้งต่อไปก็จะรับช่วงต่อจากจุดที่เราค้างไว้ สมบัติแบบนั้นคือสิ่งที่เราเรียกว่าความปลอดภัยในการยกเลิก

## "ปลอดภัยต่อการยกเลิก" หมายถึงอะไร

ฟิวเจอร์จะปลอดภัยต่อการยกเลิก ถ้าการดรอปมันกลางคันไม่ทำให้ข้อมูลสูญหายหรือทิ้งสถานะที่ใช้ร่วมกันไว้ในสภาพที่พัง เอกสารของ Tokio ระบุอย่างชัดเจนว่าแต่ละเมธอดปลอดภัยต่อการยกเลิกหรือไม่ และผมอยากแนะนำอย่างยิ่งให้คุณตรวจสอบก่อนที่จะใส่อะไรก็ตามลงในแขนงของ `select!`

การดำเนินการที่ปลอดภัยต่อการยกเลิก ได้แก่ `channel.recv()`, `TcpListener::accept()`, `sleep()` และ `CancellationToken::cancelled()` การดรอปสิ่งเหล่านี้ก็แค่หมายความว่า "ผมเลิกรอแล้ว" และไม่มีอะไรสูญหาย

การดำเนินการที่ **ไม่** ปลอดภัยต่อการยกเลิก ได้แก่ `read_exact()`, `write_all()` และ `read_to_string()` ลองคิดดูว่าจะเกิดอะไรขึ้นถ้า `write_all` เขียนไปแล้ว 50 ไบต์จากข้อความ 100 ไบต์ แล้ว `select!` ดรอปมันเสีย 50 ไบต์นั้นอยู่บนสายไปแล้ว และคุณไม่มีทางรู้ว่าส่งไปแล้วกี่ไบต์ การพยายามเขียนครั้งถัดไปจะเริ่มเขียนข้อความทั้งชุดใหม่ ทำให้สตรีมเสียหาย

มาดูตัวอย่างรูปธรรมของปัญหานี้กัน:

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

วิธีแก้คือย้ายการดำเนินการที่ไม่ปลอดภัยต่อการยกเลิกออกจาก `select!` ไปเลย เพื่อให้มันรันจนจบเสมอ เราจะเก็บเฉพาะการดำเนินการที่ปลอดภัยต่อการยกเลิก (เช่นการรับจากแชนเนล) ไว้ในแขนงของ `select!`:

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

สิ่งที่ผมพบว่าเป็นหนทางที่น่าเชื่อถือที่สุดในการหลีกเลี่ยงบั๊กจากการยกเลิก คือการจัดโครงสร้างคอมโพเนนต์ที่ทำงานพร้อมกันของคุณให้เป็นแอ็กเตอร์ แอ็กเตอร์แต่ละตัวรันลูปที่รับข้อความ ประมวลผลจนเสร็จ แล้วกลับไปรอข้อความถัดไป เพราะ `select!` จะทำงานระหว่างรอบของลูปเท่านั้น (ตอนที่แอ็กเตอร์กำลังรออินพุต ไม่ใช่ตอนกลางของงาน) จึงไม่มีอะไรให้ยกเลิกกลางคัน

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

นี่คือแพตเทิร์นที่เราใช้อย่างกว้างขวางใน [topos-protocol/topos](https://github.com/topos-protocol/topos) โดยที่แต่ละซับซิสเต็ม (broadcast, synchronizer, API) รันอีเวนต์ลูปที่มัลติเพล็กซ์คำสั่ง สัญญาณปิดระบบ และตัวจับเวลาผ่าน `select!` แต่ประมวลผลแต่ละอีเวนต์จนเสร็จก่อนกลับไปวนรอบบนสุดของลูป ตอนแรกมันอาจดูเหมือนโครงสร้างที่เกินจำเป็น แต่ในไม่ช้ามันก็คุ้มค่ากับตัวเอง กับบั๊กที่คุณไม่ต้องไล่ล่าอีกเลย

## การทำงานพร้อมกันแบบมีโครงสร้างด้วย CancellationToken

เมื่อแอปพลิเคชันของคุณมีซับซิสเต็มที่ทำงานพร้อมกันหลายตัว (เซิร์ฟเวอร์ HTTP, worker เบื้องหลัง, ตัวรายงานเมตริก) คุณต้องมีวิธีบอกให้ทั้งหมดปิดตัวลง แล้วค่อยรอให้มันทำงานเสร็จจริงๆ นี่คือจุดที่ `tokio_util::sync::CancellationToken` เข้ามามีบทบาท

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

ความสัมพันธ์แบบพ่อแม่-ลูกทำให้การปิดระบบแพร่กระจายลงไปตามลำดับ ซับซิสเต็มแต่ละตัวตรวจสอบ `token.cancelled()` ในอีเวนต์ลูปของมัน (ผ่าน `select!`) และเริ่มการล้างข้อมูลของตัวเองเมื่อมันทำงาน ฝั่งพ่อแม่รอให้แฮนเดิลทั้งหมด resolve เพื่อให้เรารู้ว่างานไม่ถูกทอดทิ้ง

เราจะเจาะลึกแพตเทิร์นนี้เพิ่มอีกมากในบท [การปิดระบบอย่างนุ่มนวล](./graceful-shutdown.md) ที่เราจะสร้างลำดับการปิดระบบแบบเต็มรูปแบบสำหรับแอปพลิเคชันจริง

## ข้อผิดพลาดที่พบบ่อย

**ใช้ `select!` ทั้งที่ตั้งใจจะใช้ `join!`.** คุณอาจสงสัยว่าทำไมการทำงานอันที่สองของคุณไม่เสร็จสักที ถ้าคุณต้องการรันการทำงานสองรายการพร้อมกันและรอทั้งคู่ ให้ใช้ `tokio::join!` หรือ `tokio::try_join!` ส่วน `select!` จะคืนค่าเมื่ออันแรกเสร็จและดรอปอีกอันหนึ่ง ผมเห็นความสับสนแบบนี้ทำให้งานสูญหายมากครั้งจนนับไม่ถ้วน

**ลืมว่า `select!` ในลูปต้องให้ทุกแขนงปลอดภัยต่อการยกเลิก.** ทุกครั้งที่ลูปวนรอบ ฟิวเจอร์จากรอบก่อนหน้าจะถูกดรอป ถ้าฟิวเจอร์ตัวใดตัวหนึ่งไม่ปลอดภัยต่อการยกเลิก ข้อมูลก็อาจหายไปเงียบๆ ระหว่างรอบ แพตเทิร์นแอ็กเตอร์ที่เราดูข้างบนหลีกเลี่ยงปัญหานี้ด้วยการจำกัดแขนงของ `select!` ทั้งหมดให้อยู่กับการดำเนินการที่ปลอดภัยต่อการยกเลิก (การรับจากแชนเนล การติ๊กของตัวจับเวลา สัญญาณการยกเลิก)

**ถือ MutexGuard ข้ามจุด await.** ด้วย `std::sync::Mutex` การถือการ์ดข้าม `.await` อาจบล็อกเธรดของรันไทม์ทั้งเธรดได้ ส่วนด้วย `tokio::sync::Mutex` มันปลอดภัยแต่ก็อาจทำให้ถือการ์ดนานเกินไปถ้าฟิวเจอร์ในคริติคัลเซกชันใช้เวลาสักพัก ในทั้งสองกรณี ผมอยากแนะนำแพตเทิร์นแอ็กเตอร์/แชนเนลแทน: ส่งข้อความไปหาทาสก์ที่เป็นเจ้าของสถานะ แทนที่จะล็อกสถานะที่ใช้ร่วมกันจากหลายทาสก์

**ไม่จัดการแขนง `else` ใน `select!`.** ถ้าแชนเนลทุกตัวใน `select!` ปิดหมด (ทุก `recv()` คืนค่า `None`) และไม่มีแขนง `else` ตัว `select!` จะแพนิก ในโค้ด production ให้จัดการเคส `None` อย่างชัดเจนเสมอ หรือทำให้แน่ใจว่ามีอย่างน้อยหนึ่งแขนง (เช่น cancellation token) ที่ไม่มีวันปิด

## `tokio::pin!` และเมื่อไหร่ที่คุณต้องใช้

ฟิวเจอร์บางชนิดต้องถูกพินก่อนที่จะนำไปใช้ใน `select!` ได้ เพราะ `select!` กำหนดให้ฟิวเจอร์ในแขนงของมัน implement `Unpin` หรือถูกพินแล้ว คุณจะเจอกรณีนี้บ่อยที่สุดตอนเก็บฟิวเจอร์ไว้ในตัวแปรและต้องการใช้มันซ้ำข้ามรอบของลูป:

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

หากไม่มี `tokio::pin!` คอมไพเลอร์จะปฏิเสธโค้ดนี้ด้วยข้อผิดพลาดเกี่ยวกับขอบเขต `Unpin` ถ้าคุณยังไม่เคยเจอข้อผิดพลาดนั้น ก็ไม่ต้องกังวล เดี๋ยวก็ได้เจอ การพินทำให้ตำแหน่งหน่วยความจำของฟิวเจอร์คงที่ข้ามจุด await ซึ่งเป็นข้อกำหนดของกลไกการโพลล์ของแมโคร `select!` มันเป็นหนึ่งในเรื่องที่ดูงงงวยในครั้งแรก แต่จะกลายเป็นเรื่องธรรมชาติเมื่อคุณเห็นแพตเทิร์นนี้สักสองสามครั้ง
