# ไทป์สเตตและแพตเทิร์นระบบชนิดข้อมูลขั้นสูง

ในบท [การสร้างแบบจำลองโดเมน](./domain-modeling.md) เราใช้นิวนิวไทป์เพื่อบังคับค่าคงที่ (invariant) บนค่าแต่ละค่า: `Email` สามารถถูกสร้างจากสตริงอีเมลที่ถูกต้องเท่านั้น และเมื่อคุณมีมันแล้ว ความถูกต้องของมันก็ถูกการันตี ตอนนี้เราจะนำแนวคิดนั้นไปต่อ แทนที่จะเข้ารหัสว่าค่า **คือ** อะไร เราจะเข้ารหัสว่าเอนทิตีอยู่ **ใน** สถานะใด และใช้ระบบชนิดข้อมูลเพื่อควบคุมว่าปฏิบัติการใดบ้างที่พร้อมใช้งานในแต่ละสถานะ

แล้วได้อะไรล่ะ? การเปลี่ยนสถานะที่ไม่ถูกต้องกลายเป็นข้อผิดพลาดตอนคอมไพล์ แทนที่จะเป็นบั๊กตอนรันไทม์

## แพตเทิร์นไทป์สเตต

แนวคิดหลักตรงไปตรงมา: เราแทนสถานะของเอนทิตีเป็นพารามิเตอร์ชนิดข้อมูล แล้วนิยามเมธอดที่พร้อมใช้งานเฉพาะเมื่อเอนทิตีอยู่ในสถานะที่ถูกต้อง เมื่อคุณเปลี่ยนไปสู่สถานะใหม่ ค่าเก่าจะถูกบริโภคและคุณได้ค่าใหม่ที่มีพารามิเตอร์ชนิดข้อมูลต่างกัน มาดูกันว่าสิ่งนี้มีหน้าตาอย่างไรในทางปฏิบัติ

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

ด้วยการออกแบบนี้ เส้นทางปกติ (happy path) คอมไพล์ได้อย่างราบรื่น:

```rust
let order = Order::new(customer_id, 4999);
let paid_order = order.pay("pay_123".into());
let shipped_order = paid_order.ship("TRACK456".into());
```

แต่ลองข้ามขั้นตอนหนึ่งดู แล้วคุณจะไม่ผ่านคอมไพเลอร์:

```rust
let order = Order::new(customer_id, 4999);
// Error: no method named `ship` found for `Order<Created>`
let shipped = order.ship("TRACK456".into());
```

คอมไพเลอร์จับการเปลี่ยนสถานะที่ไม่ถูกต้องได้ เพราะ `ship()` ถูกนิยามบน `Order<Paid>` เท่านั้น ไม่ใช่บน `Order<Created>` คุณไม่สามารถส่งออร์เดอร์ที่ยังไม่ได้ชำระ และระบบชนิดข้อมูลบังคับสิ่งนี้โดยไม่ต้องมีการตรวจสอบตอนรันไทม์ ไม่มีคำสั่ง `if` ไม่มี panic แค่ข้อผิดพลาดตอนคอมไพล์ที่บอกคุณชัดเจนว่าอะไรผิดพลาด

## การประยุกต์ในโลกจริง: ไลฟ์ไซเคิลการเชื่อมต่อ

จุดที่แพตเทิร์นนี้เปล่งประกายจริงๆ คือการอิมพลีเมนเทชันโปรโตคอลที่การเชื่อมต่อเคลื่อนผ่านเฟสที่แตกต่างกันซึ่งมีความสามารถต่างกัน ผมเคยทำงานในโปรเจกต์ [mozilla-services/autopush-rs](https://github.com/mozilla-services/autopush-rs) ซึ่งใช้แนวทางนี้กับการเชื่อมต่อ WebSocket: `UnidentifiedClient` จัดการการจับมือเริ่มต้น และเมื่อข้อความ Hello ที่ถูกต้องมาถึง มันก็เปลี่ยนไปเป็น `WebPushClient` ที่เข้าถึงข้อมูลการสมัครสมาชิกและแชนเนลการแจ้งเตือนของผู้ใช้ได้

นี่คือเวอร์ชันที่เรียบง่ายลงของแพตเทิร์นนั้น:

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

ข้อมูลเชิงลึกที่สำคัญจาก autopush-rs คือการจัดการข้อผิดพลาดแตกต่างกันระหว่างสองเฟส ในระหว่างเฟสที่ยังไม่ผ่านการยืนยันตัวตน ข้อผิดพลาดของโปรโตคอลแค่ตัดการเชื่อมต่อไคลเอนต์ (ไม่มีอะไรต้องทำความสะอาด) แต่ในระหว่างเฟสที่ผ่านการยืนยันตัวตนแล้ว ข้อผิดพลาดของโปรโตคอลต้องกระตุ้นการปิดระบบอย่างนุ่มนวลที่ระบายการแจ้งเตือนที่ค้างอยู่ก่อนจะปิด แพตเทิร์นไทป์สเตตทำให้ความแตกต่างนี้เป็นเชิงโครงสร้าง: เมธอด `shutdown` ที่มีการระบายการแจ้งเตือนมีอยู่บน `Connection<Authenticated>` เท่านั้น คุณจะเรียกมันในเฟสผิดไม่ได้จริงๆ

## แพตเทิร์นบิลเดอร์ในฐานะไทป์สเตตแบบเสื่อม

คุณอาจกำลังใช้ไทป์สเตตเวอร์ชันที่เรียบง่ายอยู่แล้วโดยไม่รู้ตัว: แพตเทิร์นบิลเดอร์ที่มีฟิลด์บังคับ โดยใช้พารามิเตอร์ชนิดข้อมูลที่แตกต่างกันสำหรับแต่ละสเตจของบิลเดอร์ เราสามารถมั่นใจได้ว่าฟิลด์ที่จำเป็นถูกตั้งค่าแล้วก่อนที่ `build()` จะพร้อมใช้งาน

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

สิ่งนี้การันตีตอนคอมไพล์ว่าคุณไม่สามารถเรียก `build()` โดยไม่เรียก `bind()` ก่อน ถ้าคุณลอง ข้อผิดพลาดของคอมไพเลอร์ชัดเจน: "no method named `build` found for `ServerBuilder<NoAddr>`" ผมชอบที่ Rust เปลี่ยนสิ่งที่ในภาษาส่วนใหญ่จะกลายเป็น panic ตอนรันไทม์ ให้กลายเป็นสิ่งที่คอมไพเลอร์จับได้ให้คุณ

## เมื่อไหร่ไทป์สเตตคุ้มกับความซับซ้อน

ตอนนี้ ผมไม่อยากให้คุณติดภาพว่าควรหยิบไทป์สเตตมาใช้ทุกที่ มันเพิ่มความซับซ้อนให้ลายเซ็นชนิดข้อมูลของคุณและทำให้ปฏิบัติการทั่วไปบางอย่างยากขึ้น (เช่นการเก็บคอลเล็กชันแบบต่างชนิดของเอนทิตีที่อยู่ในสถานะต่างกัน) จากประสบการณ์ของผม มันคุ้มค่าเมื่อ:

- การเปลี่ยนสถานะที่ไม่ถูกต้องจะก่อให้เกิดช่องโหว่ด้านความปลอดภัยหรือการทุจริตของข้อมูล (data corruption)
- มีสถานะค่อนข้างน้อยพร้อมการเปลี่ยนสถานะที่ชัดเจนและเป็นเส้นตรง
- โค้ดที่จัดการการเปลี่ยนสถานะไวต่อประสิทธิภาพพอที่คุณต้องการค่าใช้จ่ายตอนรันไทม์เป็นศูนย์
- ไทป์ถูกใช้ภายในโมดูลหรือซับซิสเต็มเดียว ดังนั้นพารามิเตอร์เจนเนอริกไม่แพร่กระจายในวงกว้าง

คุณจะต้องการเลือกใช้เครื่องจักรสถานะแบบ enum เมื่อ:

- คุณต้องเก็บเอนทิตีที่อยู่ในสถานะต่างกันไว้ด้วยกัน (เช่น `Vec<Order>` ที่บางตัวชำระแล้วและบางตัวส่งแล้ว)
- จำนวนสถานะมากหรือกราฟการเปลี่ยนสถานะซับซ้อน
- สถานะต้องถูกซีเรียลไลซ์ไปยังหรือดีซีเรียลไลซ์จากฐานข้อมูลหรือการตอบกลับ API
- สถานะถูกกำหนดตอนรันไทม์ด้วยข้อมูลภายนอกที่คุณไม่รู้ตอนคอมไพล์

สิ่งที่ผมพบในทางปฏิบัติคือหลายระบบใช้ทั้งสองอย่าง: ไทป์สเตตสำหรับตรรกะภายในแกนกลางที่การเปลี่ยนสถานะสำคัญต่อความปลอดภัย และตัวห่อ enum สำหรับความคงอยู่และการอินเทอร์เฟซภายนอก ไทป์สเตตบังคับความถูกต้องในโค้ดที่จัดการการเปลี่ยนสถานะ ในขณะที่ enum ให้ความยืดหยุ่นที่คุณต้องการสำหรับการจัดเก็บและการซีเรียลไลซ์ เราจะเห็นเรื่องนี้มากขึ้นเมื่อไปถึงเลเยอร์ความคงอยู่

## การเชื่อมโยงกลับสู่การสร้างแบบจำลองโดเมน

ถ้าคุณเห็นธีมบางอย่างที่นี่ คุณคิดถูกแล้ว แพตเทิร์นไทป์สเตตคือการขยายตามธรรมชาติของปรัชญา "parse, don't validate" จากบท [การสร้างแบบจำลองโดเมน](./domain-modeling.md) ในที่ที่นิวนิวไทป์ทำให้ค่าที่ไม่ถูกต้องไม่สามารถแทนค่าได้ (`Email` เก็บได้เฉพาะอีเมลที่ถูกต้อง) ไทป์สเตตทำให้การเปลี่ยนสถานะที่ไม่ถูกต้องไม่สามารถแทนค่าได้ (`Order<Created>` ไม่มีเมธอด `ship()`) แพตเทิร์นทั้งสองใช้ระบบชนิดข้อมูลของ Rust เพื่อย้ายการการันตีความถูกต้องจากการตรวจสอบตอนรันไทม์ไปสู่การบังคับตอนคอมไพล์ และทั้งสองให้ผลตอบแทนมากที่สุดในโค้ดที่การทำผิดจะสร้างความเสียหาย ในบทถัดไป เราจะดูวิธีจัดโครงสร้างไทป์ข้อผิดพลาดของเรา เพื่อที่ว่าเมื่อมีอะไรผิดพลาดจริงๆ ตอนรันไทม์ เราจะจัดการมันอย่างสะอาด
