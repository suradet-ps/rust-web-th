# ไทป์สเตตและแพตเทิร์นระบบชนิดข้อมูลขั้นสูง

ในบท [การสร้างแบบจำลองโดเมน](./domain-modeling.md) เราได้ใช้ newtype เพื่อบังคับใช้อินแวเรียนต์ (invariant) กับค่าแต่ละตัว: เช่น `Email` จะสร้างขึ้นได้จากสตริงที่เป็นอีเมลที่ถูกต้องเท่านั้น และเมื่อสร้างขึ้นมาได้แล้ว ความถูกต้องของมันก็ได้รับการการันตีทันที คราวนี้เราจะนำแนวคิดดังกล่าวมาต่อยอดไปอีกขั้น แทนที่จะเข้ารหัสระบุว่าค่านั้น **คือ** อะไร เราจะเข้ารหัสระบุว่าเอนทิตี (entity) กำลังอยู่ **ใน** สถานะใด และใช้ระบบชนิดข้อมูล (type system) เพื่อควบคุมว่ามีโอเปอเรชันใดบ้างที่สามารถเรียกใช้งานได้ในแต่ละสถานะ

ผลตอบแทนที่ได้คืออะไร? การเปลี่ยนผ่านสถานะ (state transition) ที่ไม่ถูกต้องจะกลายเป็นข้อผิดพลาดตอนคอมไพล์ (compile-time error) ทันที แทนที่จะหลุดรอดไปเป็นบั๊กในตอนรันไทม์

## แพตเทิร์นไทป์สเตต

แนวคิดหลักนั้นเรียบง่ายและตรงไปตรงมา: เราจะแทนสถานะของเอนทิตีด้วย type parameter แล้วนิยามเมธอดต่างๆ ให้สามารถเรียกใช้งานได้เฉพาะเมื่อเอนทิตีอยู่ในสถานะที่ถูกต้องเท่านั้น และเมื่อคุณทำการเปลี่ยนผ่านไปยังสถานะใหม่ ค่าอ็อบเจกต์เดิมจะถูกบริโภคไป (consumed) แล้วคุณจะได้รับอ็อบเจกต์ตัวใหม่ที่มี type parameter เปลี่ยนไปตามสถานะนั้นกลับมาแทน เรามาดูกันว่าแพตเทิร์นนี้มีหน้าตาอย่างไรในทางปฏิบัติ

```rust
use std::marker::PhantomData;

// States are zero-sized types. They exist only at compile time.
pub struct Created;
pub struct Paid;
pub struct Shipped;

pub struct Order<State> {
    id: Uuid,
    customer_id: Uuid,
    total_cents: i64,
    _state: PhantomData<State>,
}

impl Order<Created> {
    pub fn new(customer_id: Uuid, total_cents: i64) -> Self {
        Self {
            id: Uuid::new_v4(),
            customer_id,
            total_cents,
            _state: PhantomData,
        }
    }

    /// Pay for the order. Consumes the Created order
    /// and returns a Paid order.
    pub fn pay(self, payment_id: String) -> Order<Paid> {
        tracing::info!(order_id = %self.id, "order paid");
        Order {
            id: self.id,
            customer_id: self.customer_id,
            total_cents: self.total_cents,
            _state: PhantomData,
        }
    }
}

impl Order<Paid> {
    /// Ship the order. Only available on paid orders.
    pub fn ship(self, tracking_number: String) -> Order<Shipped> {
        tracing::info!(order_id = %self.id, "order shipped");
        Order {
            id: self.id,
            customer_id: self.customer_id,
            total_cents: self.total_cents,
            _state: PhantomData,
        }
    }

    /// Refund the order. Only available on paid (not yet shipped) orders.
    pub fn refund(self) -> Order<Created> {
        tracing::info!(order_id = %self.id, "order refunded");
        Order {
            id: self.id,
            customer_id: self.customer_id,
            total_cents: self.total_cents,
            _state: PhantomData,
        }
    }
}

impl Order<Shipped> {
    pub fn tracking_number(&self) -> &str {
        // In a real implementation, this would be stored in the struct.
        "tracking info"
    }
}
```

ด้วยการออกแบบเช่นนี้ ในกรณีทำงานปกติ (happy path) โค้ดจะคอมไพล์ผ่านได้อย่างราบรื่น:

```rust
let order = Order::new(customer_id, 4999);
let paid_order = order.pay("pay_123".into());
let shipped_order = paid_order.ship("TRACK456".into());
```

แต่หากคุณลองข้ามขั้นตอนใดขั้นตอนหนึ่งดู คอมไพเลอร์จะหยุดคุณไว้ทันที:

```rust
let order = Order::new(customer_id, 4999);
// Error: no method named `ship` found for `Order<Created>`
let shipped = order.ship("TRACK456".into());
```

คอมไพเลอร์สามารถดักจับการเปลี่ยนผ่านสถานะที่ไม่ถูกต้องได้ทันที เพราะเมธอด `ship()` ถูกนิยามไว้เฉพาะบน `Order<Paid>` เท่านั้น ไม่ได้มีอยู่บน `Order<Created>` คุณจึงไม่มีทางจัดส่งออร์เดอร์ที่ยังไม่ได้ชำระเงินได้เลย และระบบชนิดข้อมูลก็คอยบังคับใช้กฎนี้ให้โดยไม่ต้องพึ่งพาการตรวจสอบตอนรันไทม์แม้แต่น้อย ไม่ต้องเขียนคำสั่ง `if`, ไม่มีการแพนิก (panic), มีเพียงข้อความแจ้งเตือนจากคอมไพเลอร์ที่บอกคุณอย่างชัดเจนว่าคุณทำผิดพลาดตรงไหน

## การประยุกต์ในโลกจริง: ไลฟ์ไซเคิลการเชื่อมต่อ

จุดที่แพตเทิร์นนี้ฉายแววโดดเด่นอย่างแท้จริงคือ การพัฒนาโปรโตคอลเครือข่ายที่การเชื่อมต่อต้องเคลื่อนผ่านแต่ละเฟสที่มีขอบเขตความสามารถแตกต่างกัน ผมเคยมีส่วนร่วมในโปรเจกต์ [mozilla-services/autopush-rs](https://github.com/mozilla-services/autopush-rs) ซึ่งนำแนวทางนี้ไปประยุกต์ใช้กับการจัดการการเชื่อมต่อ WebSocket: โดย `UnidentifiedClient` จะทำหน้าที่จัดการขั้นตอน handshake เริ่มต้น และเมื่อได้รับข้อความ Hello ที่ถูกต้อง มันจะเปลี่ยนผ่านสถานะไปเป็น `WebPushClient` ซึ่งมีสิทธิ์เข้าถึงข้อมูลการสมัครรับข้อมูล (subscription) และแชนเนลสำหรับส่ง notification ของผู้ใช้

นี่คือตัวอย่างแบบย่อของแพตเทิร์นดังกล่าว:

```rust
pub struct Unauthenticated;
pub struct Authenticated;

pub struct Connection<State> {
    stream: WebSocketStream,
    remote_addr: SocketAddr,
    _state: PhantomData<State>,
}

impl Connection<Unauthenticated> {
    pub fn new(stream: WebSocketStream, remote_addr: SocketAddr) -> Self {
        Self {
            stream,
            remote_addr,
            _state: PhantomData,
        }
    }

    /// Perform the authentication handshake.
    /// Consumes the unauthenticated connection and returns
    /// an authenticated one, or an error if auth fails.
    pub async fn authenticate(
        mut self,
        timeout: Duration,
    ) -> Result<(Connection<Authenticated>, UserId), AuthError> {
        let hello = tokio::time::timeout(timeout, self.read_hello())
            .await
            .map_err(|_| AuthError::Timeout)?
            .map_err(AuthError::Protocol)?;

        let user_id = validate_credentials(&hello)?;

        Ok((
            Connection {
                stream: self.stream,
                remote_addr: self.remote_addr,
                _state: PhantomData,
            },
            user_id,
        ))
    }
}

impl Connection<Authenticated> {
    /// Send a push notification. Only available on authenticated connections.
    pub async fn send_notification(&mut self, notif: &Notification) -> Result<(), SendError> {
        self.stream.send(notif.to_message()).await?;
        Ok(())
    }

    /// Graceful close with notification draining.
    pub async fn shutdown(mut self, reason: CloseReason) {
        // Drain any remaining notifications before closing.
        self.drain_pending_notifications().await;
        self.stream.close(reason.into()).await.ok();
    }
}
```

ข้อคิดสำคัญที่ได้จาก autopush-rs คือ กลยุทธ์การจัดการข้อผิดพลาดจะมีความแตกต่างกันอย่างสิ้นเชิงระหว่างสองเฟสนี้ โดยในระหว่างเฟสที่ยังไม่ผ่านการยืนยันตัวตน (unauthenticated) หากเกิดข้อผิดพลาดของโปรโตคอลขึ้น เราก็เพียงแค่ตัดการเชื่อมต่อของไคลเอนต์ทิ้งไป (เนื่องจากยังไม่มีรีซอร์สใดที่ต้องทำความสะอาด) แต่เมื่อเข้าสู่เฟสที่ยืนยันตัวตนสำเร็จแล้ว (authenticated) หากเกิดข้อผิดพลาดขึ้น ระบบจะต้องกระตุ้นให้เกิด graceful shutdown เพื่อระบาย notification ที่ยังค้างอยู่ทั้งหมดออกไปให้ครบก่อนที่จะปิดการเชื่อมต่อ ซึ่งแพตเทิร์น typestate ช่วยแปลงความแตกต่างทางพฤติกรรมนี้ให้กลายเป็นกฎเชิงโครงสร้างได้อย่างสมบูรณ์แบบ: เพราะเมธอด `shutdown` พร้อมตรรกะระบายข้อความจะมีอยู่เฉพาะบน `Connection<Authenticated>` เท่านั้น ทำให้คุณไม่มีทางเผลอเรียกใช้งานมันผิดเฟสได้อย่างแน่นอน

## แพตเทิร์นบิลเดอร์ในฐานะไทป์สเตตแบบเสื่อม

คุณอาจกำลังใช้งาน typestate ในรูปแบบที่เรียบง่ายอยู่แล้วโดยไม่รู้ตัว: นั่นคือ Builder Pattern ที่มีฟิลด์บังคับ (mandatory fields) โดยการใช้ type parameter ที่แตกต่างกันในแต่ละสเตจของบิลเดอร์ เราจะสามารถรับประกันได้ว่าฟิลด์ที่จำเป็นทั้งหมดจะต้องถูกตั้งค่าให้เรียบร้อยเสียก่อน เมธอด `build()` จึงจะปรากฏขึ้นมาให้เรียกใช้งานได้

```rust
pub struct NoAddr;
pub struct HasAddr;

pub struct ServerBuilder<AddrState> {
    addr: Option<SocketAddr>,
    max_connections: usize,
    _state: PhantomData<AddrState>,
}

impl ServerBuilder<NoAddr> {
    pub fn new() -> Self {
        Self {
            addr: None,
            max_connections: 100,
            _state: PhantomData,
        }
    }

    pub fn bind(self, addr: SocketAddr) -> ServerBuilder<HasAddr> {
        ServerBuilder {
            addr: Some(addr),
            max_connections: self.max_connections,
            _state: PhantomData,
        }
    }
}

impl ServerBuilder<HasAddr> {
    /// build() is only available after bind() has been called.
    pub fn build(self) -> Server {
        Server {
            addr: self.addr.unwrap(), // Safe: guaranteed by typestate.
            max_connections: self.max_connections,
        }
    }
}

// Optional settings are available in any state.
impl<S> ServerBuilder<S> {
    pub fn max_connections(mut self, n: usize) -> Self {
        self.max_connections = n;
        self
    }
}
```

สิ่งนี้ช่วยรับประกันในระดับคอมไพล์ไทม์ว่าคุณจะไม่สามารถเรียก `build()` ได้เลยหากยังไม่ได้เรียก `bind()` ก่อน และหากคุณฝืนลองทำ คอมไพเลอร์จะฟ้องข้อผิดพลาดอย่างชัดเจนว่า: "no method named `build` found for `ServerBuilder<NoAddr>`" นี่คือเสน่ห์ที่ผมประทับใจใน Rust ที่สามารถเปลี่ยนสิ่งที่ในภาษาอื่นๆ มักจะกลายเป็น panic หรือแครชตอนรันไทม์ ให้กลายมาเป็นสิ่งที่คอมไพเลอร์ดักจับให้เราได้อย่างแม่นยำตั้งแต่แรก

## เมื่อไหร่ไทป์สเตตคุ้มกับความซับซ้อน

อย่างไรก็ดี ผมไม่อยากให้คุณเข้าใจผิดว่าเราควรหยิบ typestate ไปใช้ในทุกๆ ที่ เพราะมันย่อมเพิ่มความซับซ้อนให้กับ type signature ของคุณ และอาจทำให้การทำงานพื้นฐานบางอย่างทำได้ยากขึ้น (เช่น การจัดเก็บคอลเลกชันของเอนทิตีที่คละสถานะกัน) จากประสบการณ์ของผม typestate จะคุ้มค่าเป็นพิเศษเมื่อ:

- การเปลี่ยนผ่านสถานะที่ผิดพลาดอาจก่อให้เกิดช่องโหว่ด้านความปลอดภัยหรือทำให้ข้อมูลเสียหาย (data corruption)
- มีจำนวนสถานะค่อนข้างน้อย และการเปลี่ยนผ่านสถานะมีความชัดเจนในรูปแบบเส้นตรง (linear transitions)
- โค้ดที่จัดการการเปลี่ยนสถานะมีความสำคัญต่อประสิทธิภาพสูง จนคุณต้องการต้นทุนตอนรันไทม์เป็นศูนย์ (zero runtime overhead)
- ไทป์เหล่านั้นถูกจำกัดขอบเขตการใช้งานอยู่ภายในโมดูลหรือซับซิสเต็มเดียว ทำให้ generic parameter ไม่แพร่กระจายจนรกโค้ดส่วนอื่น

ในทางกลับกัน คุณควรเลือกใช้ State Machine แบบ `enum` ทั่วไปเมื่อ:

- คุณจำเป็นต้องเก็บเอนทิตีที่มีสถานะแตกต่างกันไว้ในคอลเลกชันเดียวกัน (เช่น `Vec<Order>` ที่บางตัวจ่ายเงินแล้วและบางตัวจัดส่งแล้ว)
- จำนวนสถานะมีมาก หรือกราฟการเปลี่ยนสถานะมีความซับซ้อนและวนลูปไปมา
- สถานะจำเป็นต้องถูก serialize ลงฐานข้อมูล หรือ deserialize จาก API response
- สถานะถูกกำหนดขึ้นในตอนรันไทม์จากข้อมูลภายนอกที่ไม่สามารถล่วงรู้ได้ในตอนคอมไพล์

สิ่งที่ผมพบในการทำงานจริงคือ หลายระบบเลือกใช้งานร่วมกันทั้งสองรูปแบบ: ใช้ typestate สำหรับตรรกะแกนกลางภายในที่การเปลี่ยนสถานะมีความสำคัญต่อความถูกต้องอย่างยิ่งยวด และห่อหุ้มด้วย enum สำหรับการจัดเก็บข้อมูลถาวร (persistence) และการเชื่อมต่อกับระบบภายนอก โดย typestate จะช่วยคุมความถูกต้องในโค้ดตรรกะ ส่วน enum จะมอบความยืดหยุ่นสำหรับการจัดเก็บและการ serialize ซึ่งเราจะได้เห็นการประยุกต์ใช้สิ่งนี้กันมากขึ้นเมื่อเข้าสู่เลเยอร์การจัดเก็บข้อมูล

## การเชื่อมโยงกลับสู่การสร้างแบบจำลองโดเมน

หากคุณเริ่มสังเกตเห็นทิศทางบางอย่างที่สอดคล้องกันที่นี่ คุณคิดถูกแล้ว เพราะแพตเทิร์น typestate แท้จริงแล้วก็คือการต่อยอดปรัชญา "parse, don't validate" จากบท [การสร้างแบบจำลองโดเมน](./domain-modeling.md) ออกไปอย่างเป็นธรรมชาตินั่นเอง ในขณะที่ newtype ช่วยทำให้ค่าที่ไม่ถูกต้องไม่สามารถเกิดขึ้นได้ในระบบ (`Email` เก็บได้เฉพาะสตริงที่ถูกต้องเท่านั้น) ตัว typestate ก็ช่วยทำให้การเปลี่ยนผ่านสถานะที่ไม่ถูกต้องไม่สามารถเกิดขึ้นได้ในระบบเช่นเดียวกัน (`Order<Created>` จะไม่มีเมธอด `ship()` ให้เรียก) ทั้งสองแพตเทิร์นต่างอาศัยระบบชนิดข้อมูลอันทรงพลังของ Rust เพื่อย้ายการการันตีความถูกต้องจากการตรวจสอบตอนรันไทม์ มาเป็นการบังคับใช้ตั้งแต่ตอนคอมไพล์ และทั้งคู่ต่างให้ผลตอบแทนที่คุ้มค่าสูงสุดในส่วนของโค้ดที่หากเกิดข้อผิดพลาดขึ้นมาจะสร้างความเสียหายอย่างรุนแรง ในบทถัดไป เราจะดูวิธีจัดโครงสร้างไทป์ข้อผิดพลาดของเรา เพื่อที่ว่าเมื่อมีอะไรผิดพลาดขึ้นมาจริงๆ ในตอนรันไทม์ เราจะสามารถรับมือและจัดการกับมันได้อย่างเป็นระบบและหมดจด
