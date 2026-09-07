# พจนานุกรมศัพท์ (Glossary) — Bulletproof Rust Web ฉบับภาษาไทย

ตารางนี้เป็นคำศัพท์ที่ใช้อย่างสม่ำเสมอตลอดทั้งเล่ม เพื่อให้การแปลทุกบทใช้คำเดียวกัน

| ศัพท์ต้นฉบับ | คำแปลไทย | หมายเหตุ |
|---|---|---|
| application | แอปพลิเคชัน | |
| web application | เว็บแอปพลิเคชัน | |
| backend | แบ็กเอนด์ | |
| architecture | สถาปัตยกรรม | |
| layered architecture | สถาปัตยกรรมแบบเลเยอร์ | |
| hexagonal architecture | สถาปัตยกรรมเฮกซะโกนัล | |
| onion architecture | สถาปัตยกรรมแบบหัวหอม | |
| layer | เลเยอร์ | ชั้นของสถาปัตยกรรม |
| dependency | ดีเพนเดนซี | |
| dependency rule | กฎของดีเพนเดนซี | ทิศทางของดีเพนเดนซีไหลเข้าหาโดเมน |
| crate | เครต | |
| workspace | เวิร์กสเปซ | Cargo workspace |
| module | โมดูล | Rust module (`mod`) |
| project structure | โครงสร้างโปรเจกต์ | |
| single-crate layout | โครงสร้างเครตเดียว | |
| entry point | จุดเริ่มต้น | ไฟล์ `main.rs` |
| port | พอร์ต | อินเทอร์เฟซที่โดเมนกำหนด (trait) |
| adapter | อะแดปเตอร์ | การนำพอร์ตไปปฏิบัติจริง |
| service | เซอร์วิส | เลเยอร์ที่เก็บ business logic |
| business logic | ตรรกะทางธุรกิจ | |
| domain | โดเมน | |
| domain model | แบบจำลองโดเมน | |
| domain modeling | การสร้างแบบจำลองโดเมน | |
| domain entity | เอนทิตีของโดเมน | |
| value object | วัตถุค่า (value object) | |
| newtype | นิวไทป์ (newtype) | แพตเทิร์นการห่อชนิดข้อมูลเพื่อสร้าง type ใหม่ |
| invariant | เงื่อนไขคงสภาพ (invariant) | กฎความถูกต้องที่ต้องเป็นจริงเสมอในโดเมน |
| type system | ระบบชนิดข้อมูล | |
| trait | เทรต | |
| trait-based abstraction | การแยกชั้นเชิงนามธรรมด้วยเทรต | |
| abstraction | นามธรรม / การแยกเชิงนามธรรม | |
| implementation | การนำไปใช้ / อิมพลีเมนเทชัน | |
| static dispatch | การเรียกแบบสแตติก (static dispatch) | |
| dynamic dispatch | การเรียกแบบไดนามิก (dynamic dispatch) | |
| state | สถานะ | |
| state management | การจัดการสถานะ | |
| AppState | AppState (คงชื่อเดิม) | struct เก็บสถานะของแอปพลิเคชัน |
| extractor | ตัวแยกข้อมูล (extractor) | กลไกของ Axum ในการดึงข้อมูลจากคำขอ |
| handler | แฮนด์เลอร์ | ฟังก์ชันจัดการคำขอ |
| fat handler | แฮนด์เลอร์อ้วน (fat handler) | แฮนด์เลอร์ที่ทำงานมากเกินไป |
| router | เราเตอร์ | |
| route | เส้นทาง | |
| routing | การกำหนดเส้นทาง | |
| middleware | มิดเดิลแวร์ | |
| request | คำขอ | |
| response | การตอบกลับ | |
| status code | รหัสสถานะ | HTTP status code |
| header | ส่วนหัว | HTTP header |
| body | บอดี้ | เนื้อความของคำขอ/การตอบกลับ |
| JSON | JSON (คงชื่อเดิม) | |
| serialization | การซีเรียลไลซ์ | |
| validation | การตรวจสอบความถูกต้อง | |
| input validation | การตรวจสอบความถูกต้องของอินพุต | |
| query parameter | พารามิเตอร์ควิวรี | |
| error handling | การจัดการข้อผิดพลาด | |
| error type | ชนิดข้อมูลข้อผิดพลาด | |
| error context | บริบทของข้อผิดพลาด | |
| error mapping | การแปลงข้อผิดพลาด | |
| database | ฐานข้อมูล | |
| database layer | เลเยอร์ฐานข้อมูล | |
| repository | รีพอสิทอรี | แพตเทิร์นการเข้าถึงข้อมูล |
| repository pattern | แพตเทิร์นรีพอสิทอรี | |
| connection pool | พูลการเชื่อมต่อ | |
| migration | ไมเกรชัน | |
| transaction | ธุรกรรม | |
| query | ควิวรี | คำสั่งค้นข้อมูล |
| schema | สกีมา | โครงสร้างตารางในฐานข้อมูล |
| row | แถว | แถวข้อมูลในตาราง |
| column | คอลัมน์ | |
| configuration | การตั้งค่า | |
| config struct | struct การตั้งค่า | |
| environment variable | ตัวแปรสภาพแวดล้อม | |
| secret | ความลับ (secret) | ข้อมูลลับ เช่น รหัสผ่าน, API key |
| secrets protection | การปกป้องความลับ | |
| authentication | การยืนยันตัวตน | |
| authorization | การอนุญาตสิทธิ์ | |
| role-based authorization | การอนุญาตสิทธิ์ตามบทบาท | |
| token | โทเคน | |
| JWT | JWT (คงชื่อเดิม) | JSON Web Token |
| password hashing | การแฮชรหัสผ่าน | |
| API | API (คงชื่อเดิม) | |
| API design | การออกแบบ API | |
| API versioning | การกำหนดเวอร์ชัน API | |
| pagination | การแบ่งหน้า | |
| filtering | การกรอง | |
| sorting | การเรียงลำดับ | |
| OpenAPI | OpenAPI (คงชื่อเดิม) | |
| health check | การตรวจสุขภาพ | health check endpoint |
| observability | การสังเกตการณ์ (observability) | |
| structured logging | การบันทึกข้อมูลแบบมีโครงสร้าง | |
| log | บันทึกข้อมูล / ล็อก | |
| span | สแปน | หน่วยของ tracing |
| trace | เทรซ | |
| subscriber | ซับสไครเบอร์ | ตัวรับเอาต์พุตของ tracing |
| metric | เมตริก | |
| OpenTelemetry | OpenTelemetry (คงชื่อเดิม) | |
| security | ความปลอดภัย | |
| security hardening | การเสริมความปลอดภัย | |
| CORS | CORS (คงชื่อเดิม) | |
| CSRF | CSRF (คงชื่อเดิม) | |
| rate limiting | การจำกัดอัตราการเรียก | |
| security header | ส่วนหัวด้านความปลอดภัย | |
| dependency auditing | การตรวจสอบดีเพนเดนซี | |
| testing | การทดสอบ | |
| testing pyramid | พีระมิดการทดสอบ | |
| unit test | การทดสอบหน่วย (unit test) | |
| integration test | การทดสอบการผสาน (integration test) | |
| test database | ฐานข้อมูลสำหรับทดสอบ | |
| test helper | ตัวช่วยทดสอบ | |
| performance | ประสิทธิภาพ | |
| benchmarking | การวัดประสิทธิภาพ (benchmark) | |
| profiling | การวิเคราะห์ประสิทธิภาพ (profiling) | |
| compression | การบีบอัด | |
| deployment | การดีพลอยต์ (deployment) | การนำขึ้นระบบจริง |
| Docker | Docker (คงชื่อเดิม) | |
| multi-stage build | บิลด์แบบหลายสเตจ | |
| graceful shutdown | การปิดระบบอย่างนุ่มนวล | |
| async | แอซิงก์ (async) | |
| async runtime | รันไทม์แอซิงก์ | เช่น Tokio |
| cancellation safety | ความปลอดภัยในการยกเลิก | |
| cancellation | การยกเลิก | |
| concurrency | การทำงานพร้อมกัน (concurrency) | |
| actor model | โมเดลแอ็กเตอร์ | |
| channel | แชนเนล | |
| mpsc | mpsc (คงชื่อเดิม) | many producers, single consumer |
| oneshot | oneshot (คงชื่อเดิม) | |
| broadcast | broadcast (คงชื่อเดิม) | |
| message passing | การส่งข้อความ | |
| background job | งานเบื้องหลัง | |
| job queue | คิวงาน | |
| task | ทาสก์ / งาน | |
| graceful shutdown | การปิดระบบอย่างนุ่มนวล | |
| lifecycle | ไลฟ์ไซเคิล | วงจรชีวิตของระบบ |
| gRPC | gRPC (คงชื่อเดิม) | |
| Tonic | Tonic (คงชื่อเดิม) | |
| protobuf | Protobuf (คงชื่อเดิม) | |
| outbound HTTP | HTTP ขาออก | |
| resilience | ความทนทาน | |
| timeout | การหมดเวลา (timeout) | |
| retry | การลองใหม่ (retry) | |
| backoff | การถอยหน่วง (backoff) | |
| circuit breaker | เซอร์กิตเบรกเกอร์ | |
| idempotency | การทำซ้ำแล้วได้ผลเหมือนเดิม (idempotency) | |
| typestate | ไทป์สเตต (typestate) | |
| builder pattern | แพตเทิร์นบิลเดอร์ | |
| compile time | เวลาคอมไพล์ | |
| compile-time checking | การตรวจสอบตอนคอมไพล์ | |
| runtime | รันไทม์ | |
| thread | เธรด | |
| borrow checker | บอร์โรว์เช็กเกอร์ (borrow checker) | |
| lifetime | ไลฟ์ไทม์ | |
| anti-pattern | แอนติแพตเทิร์น | |
| resource | แหล่งข้อมูล / ทรัพยากร | ตามบริบท |
| upstream | ต้นทาง (upstream) | |
| boilerplate | โบยเลอร์เพลต (boilerplate) | โค้ดซ้ำๆ ที่ต้องเขียนซ้ำ |
| feature | ฟีเจอร์ | ความสามารถของระบบ |
| scaffolding | การจัดโครงไฟล์เริ่มต้น | |
| refactor | รีแฟกเตอร์ | |
| codebase | โค้ดเบส | |
| out of the box | ใช้ได้ทันที | |

## หลักการทั่วไป

- ชื่อเครื่องมือ คำสั่ง CLI ชื่อเครต ชื่อไลบรารี ชื่อ struct/ฟังก์ชัน และ URL **ไม่แปล** เช่น `axum`, `sqlx`, `tower`, `#[tokio::main]`, `AppState`, `ValidatedJson`, `DebugHandler`
- โค้ดทุกบล็อก (``` ... ```) เก็บไว้ตามต้นฉบับทุกตัวอักษร รวมถึงคอมเมนต์ภายในโค้ด
- ลิงก์ (ทั้ง inline และ reference-style) คง path เดิม เพื่อให้ mdbook ยัง build ได้
- ชื่อตัวเลือก/แฟล็ก CLI อ้างถึงด้วยชื่อเดิมเสมอ เช่น `features = ["full"]`, `#[derive(Serialize)]`
- การเขียนหัวข้อ (heading) เป็นภาษาไทย แต่ระดับของหัวข้อต้องเท่าเดิม และแองเคอร์ภายในหน้าตามกฎ slug ของ mdbook (เครื่องหมายวรรณยุกต์ถูกตัดทิ้ง เช่น `#การตรวจสอบรีเกรสชัน` → `#การตรวจสอบรีเกรสชน`)
- คำศัพท์เทคนิคที่กลายเป็นศัพท์ไทยที่ใช้กันแพร่หลายแล้ว ใช้คำไทยได้เลย เช่น เธรด, มิดเดิลแวร์, แฮนด์เลอร์, เราเตอร์
