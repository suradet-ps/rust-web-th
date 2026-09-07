# การส่งข้อความและแพตเทิร์นแชนเนล

เมื่อระบบเริ่มขยายใหญ่ขึ้น ย่อมถึงจุดที่ async task ต่างๆ จำเป็นต้องสื่อสารแลกเปลี่ยนข้อมูลระหว่างกัน และเมื่อเวลานั้นมาถึง โดยพื้นฐานแล้วคุณจะมี 2 ทางเลือกหลัก: นั่นคือการใช้ shared state ที่ปกป้องด้วย lock หรือการส่งข้อความผ่าน channel (Message Passing) แม้ทั้งสองวิธีจะมีจุดเด่นและกรณีการใช้งานที่เหมาะสมของตนเอง แต่จากประสบการณ์ของผม channel มักเป็นทางเลือกเริ่มต้น (default) ที่ดีกว่าสำหรับงานเว็บแอปพลิเคชันส่วนใหญ่ เพราะมันบังคับการประมวลผลตามลำดับอย่างเป็นธรรมชาติ ทำให้การถ่ายโอน ownership มีความชัดเจนตรงไปตรงมา และทำงานร่วมกับ `tokio::select!` ได้อย่างกลมกลืน

ในบทนี้ เราจะมาสำรวจ channel primitive ประเภทต่างๆ ที่ Tokio จัดเตรียมไว้ให้, รูปแบบสถาปัตยกรรมที่ต่อยอดจาก channel เหล่านี้ ตลอดจนการประกอบพวกมันเข้าด้วยกันเป็น Actor/Service-Worker Model ซึ่งผมพบว่าเป็นรากฐานสำคัญที่ค้ำจุนแอปพลิเคชัน concurrent Rust ที่มีโครงสร้างดีแทบทุกตัว

## ชนิดแชนเนลสามแบบ

Tokio มอบ channel มาให้เรา 3 ชนิดหลักๆ ซึ่งแต่ละชนิดถูกออกแบบมาเพื่อรูปแบบการสื่อสาร (communication shape) ที่แตกต่างกัน มาดูกันว่าแต่ละชนิดทำงานอย่างไร และควรเลือกหยิบมาใช้งานในสถานการณ์ใด

### mpsc: ผู้ผลิตหลายราย ผู้บริโภครายเดียว

`mpsc` (Multi-Producer, Single-Consumer) ถือเป็นม้าศึกหลักของงานส่วนใหญ่ ทาสก์หลายๆ ตัวสามารถส่งข้อความเข้ามาพร้อมกันได้ ขณะที่มีทาสก์ฝั่งรับเพียงตัวเดียวคอยดึงข้อความไปประมวลผลตามลำดับ หากคุณกำลังสร้างคิวคำสั่ง (command queue), ระบบกระจายงาน (work dispatching) หรือแพตเทิร์นการประสานงานใดๆ ก็ตาม นี่คือจุดเริ่มต้นที่คุณมักจะได้ใช้เสมอ

```rust
use tokio::sync::mpsc;

let (tx, mut rx) = mpsc::channel::<Command>(32); // bounded, capacity 32

// Senders can be cloned and shared across tasks.
let tx2 = tx.clone();

// The receiver processes commands one at a time.
while let Some(cmd) = rx.recv().await {
    process(cmd).await;
}
```

จุดสำคัญยิ่งในการนำไปใช้บน production คือการเลือกระหว่าง bounded channel หรือ unbounded channel โดย **Bounded Channel** (สร้างด้วยคำสั่ง `mpsc::channel(capacity)`) จะมอบกลไก Backpressure ให้โดยอัตโนมัติ: กล่าวคือ เมื่อ channel เต็ม คำสั่ง `send().await` จะสั่งพัก (block/wait) ทาสก์ฝั่งผู้ส่งไว้ชั่วคราวจนกว่าทาสก์ฝั่งผู้รับจะดึงข้อความออกไปประมวลผลทัน กลไกนี้ช่วยป้องกันไม่ให้ producer ที่ทำงานเร็วเกินไปส่งข้อมูลมาท่วม consumer ที่ประมวลผลช้าจนคิวล้น ในทางตรงกันข้าม **Unbounded Channel** (สร้างด้วย `mpsc::unbounded_channel()`) จะไม่มีวันบล็อกผู้ส่งเลย แต่มันอาจสูบกลืนหน่วยความจำของระบบไปอย่างไร้ขีดจำกัดหากฝั่งผู้รับทำงานตามไม่ทัน ผมจึงแนะนำให้ใช้ bounded channel เป็นค่าเริ่มต้นเสมอ และเลือกใช้ unbounded เฉพาะเมื่อคุณมีเหตุผลความจำเป็นที่ชัดเจนเท่านั้น

### oneshot: คำขอ-การตอบกลับแบบครั้งเดียว

คุณจะเลือกใช้ `oneshot` เมื่อต้องการรับคำตอบเพียงครั้งเดียวต่อหนึ่งคำขอ (Request-Response) โดยรูปแบบการทำงานจะเป็นดังนี้: คุณสร้าง oneshot channel ขึ้นมาชุดหนึ่ง ส่งครึ่งที่เป็น `Sender` แนบไปพร้อมกับคำสั่ง และรอรับผลลัพธ์จากฝั่ง `Receiver`

```rust
use tokio::sync::oneshot;

enum Command {
    Get {
        key: String,
        reply: oneshot::Sender<Option<String>>,
    },
    Set {
        key: String,
        value: String,
    },
}

// Caller side: send a command and wait for the response.
async fn get_value(tx: &mpsc::Sender<Command>, key: String) -> Option<String> {
    let (reply_tx, reply_rx) = oneshot::channel();
    tx.send(Command::Get { key, reply: reply_tx }).await.ok()?;
    reply_rx.await.ok()?
}
```

นี่คือวิธีการสร้างการสื่อสารแบบ Request-Response ซ้อนทับลงบน command channel แบบ mpsc ฝั่งผู้เรียกจะสร้างคู่ oneshot ขึ้นมา นำ `Sender` บรรจุเข้าไปใน command แล้วสั่ง `.await` รอผลลัพธ์จาก `Receiver` ในขณะที่ทาสก์ผู้ประมวลผลอีกฝั่งจะรับคำสั่งเข้ามา ทำงานจนเสร็จ แล้วส่งผลลัพธ์ย้อนกลับมาทาง `oneshot::Sender` ในตอนแรกอาจดูเหมือนมีขั้นตอนหลายสเต็ป แต่คุณจะพบว่ามันกลายเป็นเรื่องปกติที่คุ้นเคยได้อย่างรวดเร็ว

### broadcast: การกระจายหนึ่งต่อหลาย

Channel แบบ `broadcast` เปิดโอกาสให้ผู้ส่งสามารถถ่ายทอดทุกข้อความไปยัง receiver ที่กำลังทำงานอยู่ทั้งหมดได้ในคราวเดียว โดย receiver แต่ละตัวจะได้รับสำเนาของข้อความทุกชิ้นที่ถูกส่งออกมาหลังจากที่ตนเองกดสมัครรับข้อมูล (subscribe)

```rust
use tokio::sync::broadcast;

let (tx, _rx) = broadcast::channel::<Event>(100);

// Each subscriber gets a receiver by calling subscribe().
let mut rx1 = tx.subscribe();
let mut rx2 = tx.subscribe();

// Both rx1 and rx2 will receive this event.
tx.send(Event::CertificateReady { id: cert_id })?;
```

Broadcast channel เหมาะอย่างยิ่งสำหรับการกระจายอีเวนต์ (Event Distribution), การส่งสัญญาณเคลียร์แคช (Cache Invalidation) หรือการแจ้งเตือนการเปลี่ยนแปลง configuration ไปยัง consumer หลายๆ ตัวพร้อมกัน ทว่ามีจุดสำคัญที่ต้องพึงระวัง: หาก receiver ตัวใดประมวลผลช้าจนตามไม่ทัน มันจะเจอกับข้อผิดพลาด `RecvError::Lagged(n)` ซึ่งจะระบุจำนวนข้อความที่ตัวมันหลุดตกหล่นไป คุณจึงต้องมั่นใจเสมอว่า consumer ของคุณได้เขียนโค้ดรองรับกรณีนี้ไว้อย่างรัดกุม

## แพตเทิร์นแอ็กเตอร์/เซอร์วิสเวิร์กเกอร์

มาถึงแพตเทิร์นที่ผมรู้สึกตื่นเต้นและชื่นชอบมากที่สุด Actor Model (หรือ Service-Worker) คือผลลัพธ์ที่ทรงคุณค่าที่สุดที่ channel ช่วยเปิดทางให้ และเมื่อคุณเริ่มมองเห็นประโยชน์ของมันแล้ว คุณจะอยากนำมันไปปรับใช้ในทุกๆ ที่ แนวคิดของมันเรียบง่ายมาก: Actor คือ task ตัวหนึ่งที่เป็นเจ้าของ state บางอย่างเพียงผู้เดียว ทำหน้าที่คอยรับคำสั่งผ่าน channel และประมวลผลทีละคำสั่งตามลำดับ ในขณะที่โค้ดภายนอกจะสื่อสารกับ actor ผ่าน client struct ที่ห่อหุ้ม channel sender ไว้ข้างใน และเปิดเผย async API ที่มี type ชัดเจนสวยงามให้เรียกใช้งาน

มาดูตัวอย่างที่สมบูรณ์ของ Cache Actor แบบเรียบง่ายกันครับ:

```rust
use std::collections::HashMap;
use tokio::sync::{mpsc, oneshot};

// The commands the actor understands.
enum CacheCommand {
    Get {
        key: String,
        reply: oneshot::Sender<Option<String>>,
    },
    Set {
        key: String,
        value: String,
    },
    Invalidate {
        key: String,
    },
}

// The client that external code uses. It hides the channel details.
#[derive(Clone)]
pub struct CacheClient {
    sender: mpsc::Sender<CacheCommand>,
}

impl CacheClient {
    pub async fn get(&self, key: &str) -> Option<String> {
        let (tx, rx) = oneshot::channel();
        self.sender
            .send(CacheCommand::Get {
                key: key.to_string(),
                reply: tx,
            })
            .await
            .ok()?;
        rx.await.ok()?
    }

    pub async fn set(&self, key: String, value: String) {
        let _ = self
            .sender
            .send(CacheCommand::Set { key, value })
            .await;
    }

    pub async fn invalidate(&self, key: &str) {
        let _ = self
            .sender
            .send(CacheCommand::Invalidate {
                key: key.to_string(),
            })
            .await;
    }
}

// Spawn the actor and return the client.
pub fn spawn_cache(shutdown: CancellationToken) -> CacheClient {
    let (tx, rx) = mpsc::channel(64);
    tokio::spawn(run_cache_actor(rx, shutdown));
    CacheClient { sender: tx }
}

async fn run_cache_actor(
    mut commands: mpsc::Receiver<CacheCommand>,
    shutdown: CancellationToken,
) {
    let mut store: HashMap<String, String> = HashMap::new();

    loop {
        let cmd = tokio::select! {
            cmd = commands.recv() => match cmd {
                Some(c) => c,
                None => return, // All clients dropped.
            },
            _ = shutdown.cancelled() => return,
        };

        match cmd {
            CacheCommand::Get { key, reply } => {
                let _ = reply.send(store.get(&key).cloned());
            }
            CacheCommand::Set { key, value } => {
                store.insert(key, value);
            }
            CacheCommand::Invalidate { key } => {
                store.remove(&key);
            }
        }
    }
}
```

แล้วเหตุใดแพตเทิร์นนี้จึงเข้ากับโค้ดระดับ production ได้อย่างเป็นธรรมชาตินัก? ให้ผมสรุปข้อดีหลักๆ ที่ทำให้มันทรงพลังขนาดนี้:

**ไม่ต้องใช้ Lock เลย (No Locking)** ตัว `HashMap` ถูกถือครองกรรมสิทธิ์โดย actor task แต่เพียงผู้เดียว ไม่ต้องมี `Mutex`, ไม่ต้องมี `RwLock` และไม่มีปัญหา thread contention เกิดขึ้น เพราะ mpsc channel ทำหน้าที่เรียงคิวการเข้าถึงข้อมูลให้เราโดยอัตโนมัติตามธรรมชาติ

**ทนทานต่อการยกเลิก (Cancellation Resilient)** คำสั่งแต่ละคำสั่งจะได้รับการประมวลผลจนเสร็จสิ้นสมบูรณ์ก่อนที่จะวนกลับไปที่ `select!` รอบถัดไป จึงไม่มีความเสี่ยงที่ future จะถูก drop ทิ้งไปกึ่งกลางจังหวะที่มีการแก้ไข state ซึ่งเป็นบั๊กลึกที่มักตามมาหลอกหลอนในแนวทางอื่นๆ

**ทดสอบได้ง่าย (Testable)** คุณสามารถเขียนเทสต์ทดสอบ actor ได้อย่างตรงไปตรงมา เพียงแค่สร้าง channel, ยิงคำสั่งเข้าไป แล้ว assert ตรวจสอบผลลัพธ์จาก response ไม่ต้องมานั่งกังวลเรื่อง timing หรือ race condition ในการรันพร้อมกัน ซึ่งช่วยประหยัดแรงไปได้มหาศาล

**ประกอบเข้ากับระบบได้ลงตัว (Composable)** ตัว `CacheClient` สามารถบรรจุอยู่ใน `AppState` และถูกดึงออกมาผ่าน extractor ใน Axum handler ได้เหมือนกับ shared dependency ทั่วไป เพราะมัน implement ทั้ง `Clone` และ `Send` ไว้อย่างครบถ้วนตามที่ Axum ต้องการ

## เมื่อไหร่ควรใช้แชนเนลเทียบกับสถานะที่ใช้ร่วมกัน

คุณอาจสงสัยว่าจังหวะไหนควรเลือกใช้ channel และจังหวะไหนควรครอบ `Mutex` ทับลงบน state ไปตรงๆ นี่คือหลักคิดที่ผมใช้ในการตัดสินใจ:

Channel และ Actor Model เป็นเครื่องมือที่เหมาะสมอย่างยิ่งเมื่อ:

- State นั้นจำเป็นต้องได้รับการประมวลผลตามลำดับก่อนหลังอย่างเคร่งครัด (คำสั่งต้องไม่แทรกแซงกัน)
- คุณต้องการห่อหุ้ม (encapsulate) รายละเอียดของ state ไว้เบื้องหลัง async API
- รูปแบบการเข้าถึงประกอบด้วยทั้งการอ่านและการเขียนที่จำเป็นต้องประสานงานกันอย่างใกล้ชิด
- คุณมีการใช้งาน `tokio::select!` เพื่อทำ multiplex ระหว่างแหล่ง event หลายๆ แหล่งอยู่แล้ว

ในขณะที่ Shared State (`Arc<RwLock<T>>`, `Arc<DashMap<K, V>>`) เป็นเครื่องมือที่เหมาะสมเมื่อ:

- รูปแบบการเข้าถึงส่วนใหญ่เป็นการอ่าน (Read-heavy) และมีการเขียนข้อมูลเพียงนานๆ ครั้ง
- คุณต้องการเปิดให้ task จำนวนมากสามารถอ่านข้อมูลพร้อมๆ กันได้โดยไม่ต้องมาต่อคิวรอรับส่งข้อความ
- โครงสร้างของ state เรียบง่ายพอที่การใช้ lock จะไม่ก่อให้เกิดความซับซ้อนหรือ deadlock
- คุณไม่จำเป็นต้องประสานการทำงานของ state ร่วมกับ event source อื่นๆ ภายในลูป `select!`

และข้อคิดสุดท้ายก่อนจบบทนี้: สำหรับงานคอนฟิกูเรชันของแอปพลิเคชัน channel แบบ `watch` ก็นับเป็นอีกเครื่องมือที่คุ้มค่าแก่การเรียนรู้ โดยมันจะคอยเก็บค่าข้อมูลไว้เพียงค่าเดียวเพื่อให้ receiver กี่ตัวก็ได้เข้ามาสังเกตการณ์ และฝั่ง receiver จะมองเห็นเฉพาะค่าที่เป็นปัจจุบันล่าสุดเสมอ สิ่งนี้มีประโยชน์อย่างยิ่งสำหรับการทำ dynamic configuration reload ในตอนรันไทม์ หรือการตรวจสอบสถานะสุขภาพ (health status) ที่หลายๆ ทาสก์ต้องคอยตรวจเช็กอยู่ตลอดเวลา ซึ่งเราจะได้เห็นการประสานงานในลักษณะนี้เพิ่มเติมในบทถัดๆ ไปครับ
