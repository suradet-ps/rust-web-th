# ตารางอ้างอิงครีต

ตลอดทั้งเล่มนี้ เราดึงครีตเข้ามาใช้อยู่ไม่น้อย ถ้าคุณเคยคิดว่า "เดี๋ยว นั่นมันครีตอะไรนะ" นี่คือหน้าที่คุณควรกลับมาดู ผมจัดระเบียบทุกอย่างตามความกังวล (concern) เพื่อให้คุณค้นหาสิ่งที่ต้องการได้เร็วและเข้าใจว่าทำไมมันถึงอยู่ในสแตกของเรา

## เฟรมเวิร์กหลัก

| Crate | Purpose | Notes |
|-------|---------|-------|
| [axum](https://crates.io/crates/axum) | เฟรมเวิร์กสำหรับการกำหนดเส้นทาง HTTP ตัวแยกข้อมูล และแฮนด์เลอร์ | รากฐานของทั้งหมด ใช้ร่วมกับฟีเจอร์ `macros` สำหรับ `#[debug_handler]` |
| [tokio](https://crates.io/crates/tokio) | รันไทม์แอซิงก์ | ใช้ `features = ["full"]` เว้นแต่คุณจำเป็นต้องลดดีเพนเดนซีให้เหลือน้อยที่สุด |
| [tower](https://crates.io/crates/tower) | นามธรรมและยูทิลิตี้สำหรับมิดเดิลแวร์ | ให้ `ServiceBuilder`, `ServiceExt` (สำหรับ `oneshot` ในเทสต์) และเลเยอร์ที่ประกอบเข้าด้วยกันได้ |
| [tower-http](https://crates.io/crates/tower-http) | มิดเดิลแวร์เฉพาะ HTTP | CORS, การบีบอัด, tracing, การหมดเวลา, หมายเลขคำขอ, ขีดจำกัดของบอดี้ และอื่นๆ เปิดใช้ฟีเจอร์แบบเลือกได้ |
| [hyper](https://crates.io/crates/hyper) | อิมพลีเมนเทชันของ HTTP | คุณแทบจะไม่ได้โต้ตอบกับ hyper โดยตรงเมื่อใช้ Axum แต่มันคือเอ็นจิน HTTP ที่ทำงานอยู่เบื้องหลัง |

## การซีเรียลไลซ์และข้อมูล

| Crate | Purpose | Notes |
|-------|---------|-------|
| [serde](https://crates.io/crates/serde) | เฟรมเวิร์กการซีเรียลไลซ์ | ใช้ `features = ["derive"]` สำหรับ `#[derive(Serialize, Deserialize)]` |
| [serde_json](https://crates.io/crates/serde_json) | การซีเรียลไลซ์ JSON | ตัวแยกข้อมูล `Json` ของ Axum ใช้สิ่งนี้อยู่เบื้องหลัง |
| [uuid](https://crates.io/crates/uuid) | การสร้างและการแยกวิเคราะห์ UUID | ใช้ `features = ["v4", "serde"]` สำหรับ UUID แบบสุ่มที่รองรับ serde |
| [chrono](https://crates.io/crates/chrono) | การจัดการวันที่และเวลา | ใช้ `features = ["serde"]` สำหรับการซีเรียลไลซ์ นิยมใช้ `DateTime<Utc>` สำหรับการประทับเวลา |

## ฐานข้อมูล

| Crate | Purpose | Notes |
|-------|---------|-------|
| [sqlx](https://crates.io/crates/sqlx) | SQL แบบแอซิงก์พร้อมการตรวจสอบตอนคอมไพล์ | ตัวเลือกหลักของเราสำหรับโปรเจกต์ Axum ส่วนใหญ่ รองรับ PostgreSQL, MySQL และ SQLite |
| [diesel](https://crates.io/crates/diesel) | ORM และตัวสร้างควิวรีที่ปลอดภัยต่อชนิดข้อมูล | เติบโตเต็มที่และผ่านการทดสอบอย่างดี ใช้ `diesel-async` สำหรับการรองรับ async |
| [sea-orm](https://crates.io/crates/sea-orm) | ORM แบบแอซิงก์สไตล์ ActiveRecord | น่าพิจารณาถ้า SQL เปล่าๆ รู้สึกเหมือนพิธีการมากเกินไปสำหรับเคสใช้งานของคุณ |
| [axum-sqlx-tx](https://crates.io/crates/axum-sqlx-tx) | ธุรกรรม SQLx ที่จำกัดขอบเขตตามคำขอ | เริ่มธุรกรรมให้อัตโนมัติสำหรับแต่ละคำขอ จากนั้น commit หรือ rollback ตามสถานะการตอบกลับ |

## การจัดการข้อผิดพลาด

| Crate | Purpose | Notes |
|-------|---------|-------|
| [thiserror](https://crates.io/crates/thiserror) | แมโคร derive สำหรับชนิดข้อมูลข้อผิดพลาดที่กำหนดเอง | เราใช้สิ่งนี้สำหรับข้อผิดพลาดของโดเมนและ enum `AppError` ของเราที่ต้อง match กับวาเรียนต์ |
| [anyhow](https://crates.io/crates/anyhow) | ชนิดข้อมูลข้อผิดพลาดที่ยืดหยุ่นพร้อมการต่อบริบท | เหมาะมากสำหรับวาเรียนต์ `Internal` แบบจับหมด และในโค้ดโครงสร้างพื้นฐาน อย่าอายที่จะใช้ `.context()` |

## การตรวจสอบความถูกต้อง

| Crate | Purpose | Notes |
|-------|---------|-------|
| [validator](https://crates.io/crates/validator) | การตรวจสอบความถูกต้องของอินพุตแบบใช้ derive | รองรับ `email`, `url`, `length`, `range` และตัวตรวจสอบแบบกำหนดเอง |
| [garde](https://crates.io/crates/garde) | การตรวจสอบความถูกต้องทางเลือกพร้อม const generics | มุมมองใหม่กว่าบน `validator` พร้อมสไตล์ API ที่ต่างออกไป |
| [axum-valid](https://crates.io/crates/axum-valid) | ตัวแยกข้อมูลที่ตรวจสอบความถูกต้องแล้วแบบสำเร็จรูปสำหรับ Axum | ผสานกับ `validator`, `garde` และ `validify` ช่วยให้คุณไม่ต้องเขียนตัวแยกข้อมูลเอง |

## การยืนยันตัวตนและความปลอดภัย

| Crate | Purpose | Notes |
|-------|---------|-------|
| [jsonwebtoken](https://crates.io/crates/jsonwebtoken) | การเข้ารหัสและถอดรหัส JWT | ตัวเลือกหลักสำหรับการยืนยันตัวตนแบบ JWT ใน Rust |
| [argon2](https://crates.io/crates/argon2) | การแฮชรหัสผ่าน | สิ่งที่ผมแนะนำสำหรับการแฮชรหัสผ่านในปัจจุบัน นิยมใช้มันมากกว่า bcrypt สำหรับโปรเจกต์ใหม่ |
| [axum-login](https://crates.io/crates/axum-login) | การยืนยันตัวตนแบบใช้เซสชัน | เข้ากันได้ดีกับเว็บแอปพลิเคชันแบบดั้งเดิมที่มีเซสชันฝั่งเซิร์ฟเวอร์ |
| [axum-csrf-sync-pattern](https://crates.io/crates/axum-csrf-sync-pattern) | การป้องกัน CSRF | อิมพลีเมนต์ OWASP Synchronizer Token Pattern |
| [tower-governor](https://crates.io/crates/tower-governor) | การจำกัดอัตราการเรียก | การจำกัดอัตราการเรียกแบบต่อ IP โดยใช้อัลกอริทึม governor |
| [tower-sessions](https://crates.io/crates/tower-sessions) | มิดเดิลแวร์เซสชัน | การจัดการเซสชันฝั่งเซิร์ฟเวอร์พร้อมแบ็กเอนด์ที่เปลี่ยนแทนกันได้ |

## การตั้งค่า

| Crate | Purpose | Notes |
|-------|---------|-------|
| [config](https://crates.io/crates/config) | การโหลดการตั้งค่าแบบเลเยอร์ | รองรับไฟล์ ตัวแปรสภาพแวดล้อม และหลายรูปแบบ |
| [dotenvy](https://crates.io/crates/dotenvy) | โหลดไฟล์ `.env` | ฟอร์กจากครีต `dotenv` ดั้งเดิม เรียก `.ok()` แทน `.unwrap()` เพื่อไม่ให้มันระเบิดใน production |
| [secrecy](https://crates.io/crates/secrecy) | การปกป้องค่าที่ละเอียดอ่อน | ห่อความลับด้วย `SecretString` มันจะปกปิดค่าเหล่านั้นในเอาต์พุต debug และล้างข้อมูลในหน่วยความจำทิ้งเมื่อ drop |

## การสังเกตการณ์ (Observability)

| Crate | Purpose | Notes |
|-------|---------|-------|
| [tracing](https://crates.io/crates/tracing) | การบันทึกข้อมูลแบบมีโครงสร้างและสแปน | ถ้าคุณจะทำการบันทึกข้อมูลแบบมีโครงสร้างใน Rust นี่คือสิ่งที่ทุกคนหยิบใช้ |
| [tracing-subscriber](https://crates.io/crates/tracing-subscriber) | การตั้งค่าเอาต์พุตของ tracing | ใช้ `features = ["env-filter", "json"]` สำหรับการกรองตามสภาพแวดล้อมและเอาต์พุตแบบ JSON |
| [tracing-opentelemetry](https://crates.io/crates/tracing-opentelemetry) | เชื่อม tracing เข้ากับ OpenTelemetry | แปลงสแปนของ tracing ให้เป็นสแปนของ OpenTelemetry สำหรับ distributed tracing |
| [opentelemetry](https://crates.io/crates/opentelemetry) | OpenTelemetry API | API หลักสำหรับ distributed tracing และเมตริก |
| [opentelemetry-otlp](https://crates.io/crates/opentelemetry-otlp) | เอ็กซ์พอร์ตเตอร์ OTLP | เอ็กซ์พอร์ตเทรซไปยัง Jaeger, Tempo, Datadog และแบ็กเอนด์อื่นๆ ที่เข้ากันได้กับ OTLP |
| [axum-tracing-opentelemetry](https://crates.io/crates/axum-tracing-opentelemetry) | การผสาน OpenTelemetry กับ Axum | การกระจายบริบทของเทรซอัตโนมัติสำหรับ Axum |

## เอกสารประกอบ API

| Crate | Purpose | Notes |
|-------|---------|-------|
| [utoipa](https://crates.io/crates/utoipa) | การสร้างสเปก OpenAPI ตอนคอมไพล์ | สร้างสเปก OpenAPI 3.0 จากแอนโนเทชันในโค้ด |
| [utoipa-swagger-ui](https://crates.io/crates/utoipa-swagger-ui) | Swagger UI สำหรับ utoipa | ให้บริการ UI เอกสารประกอบ API แบบโต้ตอบที่เส้นทางที่ตั้งค่าได้ |

## การทดสอบ

| Crate | Purpose | Notes |
|-------|---------|-------|
| tower (ServiceExt) | การทดสอบการผสานโดยไม่ต้องมีเซิร์ฟเวอร์ | ใช้ `oneshot()` เพื่อส่งคำขอผ่านเราเตอร์โดยตรง |
| [mockall](https://crates.io/crates/mockall) | การสร้าง mock อัตโนมัติ | สร้างอิมพลีเมนเทชัน mock ของเทรตของคุณสำหรับการทดสอบหน่วย |
| [axum-test](https://crates.io/crates/axum-test) | ไลบรารีการทดสอบสำหรับ Axum | ให้ `TestClient` ที่มี API ดีกว่า `oneshot` เปล่าๆ |

## ไคลเอนต์ HTTP

| Crate | Purpose | Notes |
|-------|---------|-------|
| [reqwest](https://crates.io/crates/reqwest) | ไคลเอนต์ HTTP แบบแอซิงก์ | ไคลเอนต์ HTTP ที่คุณจะเห็นในโปรเจกต์ Rust ส่วนใหญ่ เป็นแอซิงก์โดยธรรมชาติพร้อมพูลการเชื่อมต่อ |

## gRPC

| Crate | Purpose | Notes |
|-------|---------|-------|
| [tonic](https://crates.io/crates/tonic) | เฟรมเวิร์ก gRPC | ไคลเอนต์และเซิร์ฟเวอร์ gRPC แบบแอซิงก์โดยธรรมชาติ ผสานกับมิดเดิลแวร์ของ Tower |
| [tonic-prost](https://crates.io/crates/tonic-prost) | รันไทม์ของ Tonic + Prost | การรองรับรันไทม์สำหรับเซอร์วิส tonic ที่ใช้ชนิดข้อมูลที่สร้างโดย prost |
| [prost](https://crates.io/crates/prost) | Protocol Buffers | การซีเรียลไลซ์/ดีซีเรียลไลซ์ Protobuf ใช้โดย tonic สำหรับชนิดข้อมูลข้อความ |
| [tonic-prost-build](https://crates.io/crates/tonic-prost-build) | การสร้างโค้ดจาก proto | คอมไพล์ไฟล์ `.proto` เป็นโค้ด Rust ตอนบิลด์ ใส่ใน `[build-dependencies]` สิ่งนี้แทนที่การใช้ `tonic-build` โดยตรงตั้งแต่ tonic 0.14 |
| [tonic-reflection](https://crates.io/crates/tonic-reflection) | การรีเฟลกชันเซิร์ฟเวอร์ gRPC | ให้ `grpcurl` และเครื่องมืออื่นๆ ค้นพบ API ของเซอร์วิสคุณได้ |

## ยูทิลิตี้แอซิงก์

| Crate | Purpose | Notes |
|-------|---------|-------|
| [tokio-util](https://crates.io/crates/tokio-util) | ยูทิลิตี้ Tokio เพิ่มเติม | ให้ `CancellationToken` สำหรับการปิดระบบแบบมีโครงสร้าง พร้อม codec และตัวช่วยอื่นๆ |
| [futures](https://crates.io/crates/futures) | คอมไบเนเตอร์ของ future | ให้ `FuturesUnordered`, `StreamExt` และยูทิลิตี้อื่นๆ สำหรับการทำงานกับสตรีมแบบแอซิงก์ |

## งานเบื้องหลัง

| Crate | Purpose | Notes |
|-------|---------|-------|
| [apalis](https://crates.io/crates/apalis) | การประมวลผลงานเบื้องหลัง | ปลอดภัยต่อชนิดข้อมูล ขยายได้ รองรับแบ็กเอนด์ PostgreSQL/Redis/SQLite มีการตรวจสอบและการปิดระบบอย่างนุ่มนวลในตัว |
| [fang](https://crates.io/crates/fang) | คิวงานแบบคงอยู่ (persistent) | เวิร์กเกอร์ในทาสก์ Tokio แยกกันพร้อมรีสตาร์ทอัตโนมัติเมื่อ panic การจัดตารางแบบ cron และการถอยหน่วงสำหรับการลองใหม่ |
| [backie](https://crates.io/crates/backie) | คิวทาสก์แบบแอซิงก์ | ใช้ PostgreSQL เป็นฐาน ออกแบบมาสำหรับการปรับขนาดแนวนอนในหลายโพรเซส |
