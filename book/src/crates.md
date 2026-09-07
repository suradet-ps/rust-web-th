# ตารางอ้างอิงเครต

ตลอดทั้งเล่มนี้ เราดึงเครตเข้ามาใช้งานอยู่ไม่น้อย หากคุณเคยนึกสงสัยว่า "เดี๋ยว เครตตัวนั้นชื่ออะไรนะ" หน้านี้คือคู่มืออ้างอิงที่คุณสามารถย้อนกลับมาดูได้เสมอ ผมได้จัดหมวดหมู่ทุกอย่างตามขอบเขตการใช้งาน (concern) เพื่อให้คุณค้นหาสิ่งที่ต้องการได้อย่างรวดเร็ว พร้อมทั้งเข้าใจว่าเหตุใดเครตเหล่านี้จึงถูกเลือกเข้ามาอยู่ในสแตกของเรา

## เฟรมเวิร์กหลัก

| Crate | Purpose | Notes |
|-------|---------|-------|
| [axum](https://crates.io/crates/axum) | เฟรมเวิร์กสำหรับการเราต์ HTTP, ตัวแยกข้อมูล (extractors) และแฮนด์เลอร์ | รากฐานหลักของระบบ ใช้ร่วมกับฟีเจอร์ `macros` สำหรับ `#[debug_handler]` |
| [tokio](https://crates.io/crates/tokio) | รันไทม์ async | ใช้ `features = ["full"]` ยกเว้นในกรณีที่คุณต้องการลดขนาดดีเพนเดนซีให้เหลือน้อยที่สุด |
| [tower](https://crates.io/crates/tower) | นามธรรมและยูทิลิตี้สำหรับมิดเดิลแวร์ | จัดเตรียม `ServiceBuilder`, `ServiceExt` (สำหรับ `oneshot` ในการทดสอบ) และเลเยอร์ที่ประกอบต่อกันได้ |
| [tower-http](https://crates.io/crates/tower-http) | มิดเดิลแวร์เฉพาะสำหรับ HTTP | CORS, การบีบอัดข้อมูล, tracing, การหมดเวลา (timeouts), หมายเลขคำขอ (request IDs), การจำกัดขนาดบอดี้ และอื่นๆ โดยเปิดใช้ฟีเจอร์ได้ตามต้องการ |
| [hyper](https://crates.io/crates/hyper) | อิมพลีเมนเทชันพื้นฐานของ HTTP | แทบจะไม่ได้เรียกใช้ hyper โดยตรงเมื่อพัฒนาบน Axum แต่มันคือเอ็นจิน HTTP ตัวจริงที่ขับเคลื่อนอยู่เบื้องหลัง |

## การซีเรียลไลซ์และข้อมูล

| Crate | Purpose | Notes |
|-------|---------|-------|
| [serde](https://crates.io/crates/serde) | เฟรมเวิร์กสำหรับการซีเรียลไลซ์ | ใช้ `features = ["derive"]` สำหรับแมโคร `#[derive(Serialize, Deserialize)]` |
| [serde_json](https://crates.io/crates/serde_json) | การซีเรียลไลซ์และดีซีเรียลไลซ์ JSON | ตัวแยกข้อมูล `Json` ของ Axum ทำงานโดยใช้ตัวนี้อยู่เบื้องหลัง |
| [uuid](https://crates.io/crates/uuid) | การสร้างและการพาร์ส UUID | ใช้ `features = ["v4", "serde"]` สำหรับการสุ่ม UUID ที่รองรับการทำงานร่วมกับ serde |
| [chrono](https://crates.io/crates/chrono) | การจัดการวันและเวลา | ใช้ `features = ["serde"]` สำหรับการซีเรียลไลซ์ แนะนำให้ใช้ `DateTime<Utc>` สำหรับการเก็บ timestamp |

## ฐานข้อมูล

| Crate | Purpose | Notes |
|-------|---------|-------|
| [sqlx](https://crates.io/crates/sqlx) | การทำงานกับ SQL แบบ async พร้อมการตรวจสอบความถูกต้องตั้งแต่ตอนคอมไพล์ | ตัวเลือกอันดับหนึ่งสำหรับโปรเจกต์ Axum ส่วนใหญ่ รองรับทั้ง PostgreSQL, MySQL และ SQLite |
| [diesel](https://crates.io/crates/diesel) | ORM และตัวสร้างคิวรีที่ปลอดภัยต่อชนิดข้อมูล (type-safe) | เติบโตเต็มที่และผ่านการทดสอบมาอย่างยาวนาน ใช้ `diesel-async` สำหรับการรองรับ async |
| [sea-orm](https://crates.io/crates/sea-orm) | ORM แบบ async สไตล์ ActiveRecord | น่าสนใจเป็นอย่างยิ่งหากการเขียน Raw SQL ดูยุ่งยากซับซ้อนเกินไปสำหรับความต้องการของคุณ |
| [axum-sqlx-tx](https://crates.io/crates/axum-sqlx-tx) | ทรานแซกชัน SQLx ที่ผูกขอบเขตกับแต่ละคำขอ (request-scoped) | เปิดทรานแซกชันให้อัตโนมัติในแต่ละคำขอ จากนั้นจะ commit หรือ rollback ตามสถานะการตอบกลับของการร้องขอนั้น |

## การจัดการข้อผิดพลาด

| Crate | Purpose | Notes |
|-------|---------|-------|
| [thiserror](https://crates.io/crates/thiserror) | แมโคร derive สำหรับสร้างชนิดข้อมูลข้อผิดพลาดที่กำหนดขึ้นเอง | เราใช้สิ่งนี้สำหรับข้อผิดพลาดในฝั่งโดเมนและ enum `AppError` ของเราที่จำเป็นต้อง pattern match แยกตามวาเรียนต์ |
| [anyhow](https://crates.io/crates/anyhow) | ชนิดข้อมูลข้อผิดพลาดที่ยืดหยุ่นพร้อมการต่อบริบท (context chaining) | เหมาะอย่างยิ่งสำหรับวาเรียนต์แบบครอบจักรวาลอย่าง `Internal` และในโค้ดส่วนโครงสร้างพื้นฐาน อย่าลังเลที่จะใช้ `.context()` เพื่อบอกที่มาที่ไป |

## การตรวจสอบความถูกต้อง

| Crate | Purpose | Notes |
|-------|---------|-------|
| [validator](https://crates.io/crates/validator) | การตรวจสอบความถูกต้องของอินพุตโดยใช้ derive | รองรับ `email`, `url`, `length`, `range` ตลอดจนตัวตรวจสอบแบบกำหนดเอง (custom validators) |
| [garde](https://crates.io/crates/garde) | ตัวเลือกการตรวจสอบความถูกต้องทางเลือกที่ใช้ const generics | มิติใหม่ที่ต่อยอดจาก `validator` พร้อมรูปแบบ API ที่ทันสมัยและแตกต่างออกไป |
| [axum-valid](https://crates.io/crates/axum-valid) | ตัวแยกข้อมูล (extractors) ที่ตรวจสอบความถูกต้องสำเร็จรูปสำหรับ Axum | ทำงานร่วมกับ `validator`, `garde` และ `validify` ได้อย่างแนบเนียน ช่วยให้คุณไม่ต้องเขียนตัวแยกข้อมูลเอง |

## การยืนยันตัวตนและความปลอดภัย

| Crate | Purpose | Notes |
|-------|---------|-------|
| [jsonwebtoken](https://crates.io/crates/jsonwebtoken) | การเข้ารหัสและถอดรหัส JWT | ตัวเลือกมาตรฐานสำหรับการยืนยันตัวตนด้วย JWT ใน Rust |
| [argon2](https://crates.io/crates/argon2) | การแฮชรหัสผ่าน | สิ่งที่ผมแนะนำสำหรับการแฮชรหัสผ่านในปัจจุบัน เหมาะสำหรับใช้แทน bcrypt ในโปรเจกต์ยุคใหม่ |
| [axum-login](https://crates.io/crates/axum-login) | การยืนยันตัวตนผ่านระบบเซสชัน | เหมาะสำหรับเว็บแอปพลิเคชันแบบดั้งเดิมที่ใช้การจัดการเซสชันที่ฝั่งเซิร์ฟเวอร์ |
| [axum-csrf-sync-pattern](https://crates.io/crates/axum-csrf-sync-pattern) | การป้องกัน CSRF | อิมพลีเมนต์ตามมาตรฐาน OWASP Synchronizer Token Pattern |
| [tower-governor](https://crates.io/crates/tower-governor) | การจำกัดอัตราการเรียกใช้งาน (rate limiting) | การจำกัดอัตราการเรียกใช้งานแบบราย IP โดยใช้อัลกอริทึม governor |
| [tower-sessions](https://crates.io/crates/tower-sessions) | มิดเดิลแวร์สำหรับจัดการเซสชัน | จัดการเซสชันฝั่งเซิร์ฟเวอร์พร้อมแบ็กเอนด์ที่สามารถสลับเปลี่ยนได้ตามต้องการ |

## การตั้งค่า

| Crate | Purpose | Notes |
|-------|---------|-------|
| [config](https://crates.io/crates/config) | การโหลดการตั้งค่าแบบแบ่งเลเยอร์ (layered configuration) | รองรับทั้งการอ่านจากไฟล์, ตัวแปรสภาพแวดล้อม และหลากหลายรูปแบบไฟล์ |
| [dotenvy](https://crates.io/crates/dotenvy) | การโหลดค่าจากไฟล์ `.env` | เครตที่ฟอร์กมาจาก `dotenv` ดั้งเดิม ควรเรียกใช้ `.ok()` แทน `.unwrap()` เพื่อไม่ให้ระบบหยุดทำงานเมื่อขึ้น production |
| [secrecy](https://crates.io/crates/secrecy) | การปกป้องข้อมูลที่ละเอียดอ่อน | ห่อหุ้มข้อมูลลับด้วย `SecretString` ซึ่งจะช่วยซ่อนค่าดังกล่าวใน debug log และล้างข้อมูลออกจากหน่วยความจำทันทีเมื่อถูก drop |

## การสังเกตการณ์ (Observability)

| Crate | Purpose | Notes |
|-------|---------|-------|
| [tracing](https://crates.io/crates/tracing) | การบันทึกข้อมูลแบบมีโครงสร้างและสแปน (structured logging and spans) | หากคุณต้องการทำ structured logging ใน Rust นี่คือเครื่องมือมาตรฐานที่ทุกคนเลือกใช้ |
| [tracing-subscriber](https://crates.io/crates/tracing-subscriber) | การกำหนดค่าเอาต์พุตสำหรับ tracing | ใช้ `features = ["env-filter", "json"]` สำหรับการกรองล็อกตามตัวแปรสภาพแวดล้อมและการส่งออกในรูปแบบ JSON |
| [tracing-opentelemetry](https://crates.io/crates/tracing-opentelemetry) | สะพานเชื่อมระหว่าง tracing กับ OpenTelemetry | แปลงสแปนของ tracing ให้กลายเป็นสแปนของ OpenTelemetry สำหรับ distributed tracing |
| [opentelemetry](https://crates.io/crates/opentelemetry) | OpenTelemetry API | API แกนหลักสำหรับระบบ distributed tracing และเมตริก |
| [opentelemetry-otlp](https://crates.io/crates/opentelemetry-otlp) | ตัวส่งออกข้อมูล (exporter) OTLP | ส่งออกข้อมูลเทรซไปยัง Jaeger, Tempo, Datadog และแบ็กเอนด์อื่นๆ ที่รองรับมาตรฐาน OTLP |
| [axum-tracing-opentelemetry](https://crates.io/crates/axum-tracing-opentelemetry) | การผสานการทำงานระหว่าง OpenTelemetry กับ Axum | กระจาย trace context ไปตามคำขอต่างๆ ของ Axum โดยอัตโนมัติ |

## เอกสารประกอบ API

| Crate | Purpose | Notes |
|-------|---------|-------|
| [utoipa](https://crates.io/crates/utoipa) | การสร้างสเปก OpenAPI ตั้งแต่ตอนคอมไพล์ | สร้างสเปก OpenAPI 3.0 โดยอัตโนมัติจากแอตทริบิวต์ในโค้ด |
| [utoipa-swagger-ui](https://crates.io/crates/utoipa-swagger-ui) | Swagger UI สำหรับ utoipa | ให้บริการหน้าเว็บ UI เอกสาร API แบบโต้ตอบได้ผ่านเส้นทางที่สามารถกำหนดค่าได้ |

## การทดสอบ

| Crate | Purpose | Notes |
|-------|---------|-------|
| tower (ServiceExt) | การทดสอบการผสานระบบโดยไม่ต้องสตาร์ตเซิร์ฟเวอร์ | ใช้ `oneshot()` เพื่อส่งคำขอทดสอบผ่านเราเตอร์โดยตรง |
| [mockall](https://crates.io/crates/mockall) | การสร้าง mock อ็อบเจกต์อัตโนมัติ | สร้าง mock implementation ของเทรตต่างๆ สำหรับการทำยูนิตเทสต์ |
| [axum-test](https://crates.io/crates/axum-test) | ไลบรารีการทดสอบสำหรับ Axum | จัดเตรียม `TestClient` ที่ใช้งานง่ายและมี API สะดวกกว่าการเรียก `oneshot` เปล่าๆ |

## ไคลเอนต์ HTTP

| Crate | Purpose | Notes |
|-------|---------|-------|
| [reqwest](https://crates.io/crates/reqwest) | ไคลเอนต์ HTTP แบบ async | ไคลเอนต์ HTTP ที่พบได้บ่อยที่สุดในโปรเจกต์ Rust รองรับ async โดยกำเนิดพร้อมระบบ connection pooling |

## gRPC

| Crate | Purpose | Notes |
|-------|---------|-------|
| [tonic](https://crates.io/crates/tonic) | เฟรมเวิร์ก gRPC | ไคลเอนต์และเซิร์ฟเวอร์ gRPC แบบ async โดยสมบูรณ์ เชื่อมต่อกับมิดเดิลแวร์ของ Tower ได้อย่างไร้รอยต่อ |
| [tonic-prost](https://crates.io/crates/tonic-prost) | รันไทม์ Tonic + Prost | รองรับการทำงานในระดับรันไทม์สำหรับเซอร์วิสของ tonic ที่ใช้ชนิดข้อมูลที่สร้างจาก prost |
| [prost](https://crates.io/crates/prost) | Protocol Buffers | การซีเรียลไลซ์และดีซีเรียลไลซ์ Protobuf ที่ tonic เลือกใช้สำหรับชนิดข้อมูลของข้อความ |
| [tonic-prost-build](https://crates.io/crates/tonic-prost-build) | การสร้างโค้ดจากไฟล์ proto | คอมไพล์ไฟล์ `.proto` ออกมาเป็นโค้ด Rust ในช่วงบิลด์ โดยระบุไว้ใน `[build-dependencies]` (เข้ามาแทนที่การใช้ `tonic-build` โดยตรงตั้งแต่ tonic 0.14) |
| [tonic-reflection](https://crates.io/crates/tonic-reflection) | ระบบ reflection บนเซิร์ฟเวอร์ gRPC | ช่วยให้เครื่องมืออย่าง `grpcurl` สามารถค้นหาและตรวจสอบ API ของเซอร์วิสได้โดยตรง |

## ยูทิลิตี้แอซิงก์

| Crate | Purpose | Notes |
|-------|---------|-------|
| [tokio-util](https://crates.io/crates/tokio-util) | ยูทิลิตี้เสริมสำหรับ Tokio | จัดเตรียม `CancellationToken` สำหรับการปิดระบบอย่างเป็นระเบียบ พร้อมทั้ง codecs และตัวช่วยอำนวยความสะดวกอื่นๆ |
| [futures](https://crates.io/crates/futures) | ตัวเชื่อมและประมวลผล future (combinators) | จัดเตรียม `FuturesUnordered`, `StreamExt` และยูทิลิตี้อื่นๆ สำหรับการทำงานกับ async streams |

## งานเบื้องหลัง

| Crate | Purpose | Notes |
|-------|---------|-------|
| [apalis](https://crates.io/crates/apalis) | การประมวลผลงานเบื้องหลัง | ปลอดภัยต่อชนิดข้อมูล (type-safe), ขยายระบบได้ง่าย รองรับแบ็กเอนด์ทั้ง PostgreSQL, Redis และ SQLite พร้อมระบบมอนิเตอร์และการทำ graceful shutdown ในตัว |
| [fang](https://crates.io/crates/fang) | คิวงานแบบคงทนถาวร (persistent) | แยกเวิร์กเกอร์ทำงานบนทาสก์ Tokio ต่างหาก พร้อมระบบรีสตาร์ตอัตโนมัติเมื่อเกิด panic, การตั้งเวลาแบบ cron และระบบหน่วงเวลาก่อนลองใหม่ (backoff) |
| [backie](https://crates.io/crates/backie) | คิวทาสก์แบบ async | ขับเคลื่อนด้วย PostgreSQL ออกแบบมาสำหรับการสเกลในแนวนอนข้ามหลายโพรเซส |

