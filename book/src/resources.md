# แหล่งข้อมูล

ผมตั้งใจรวบรวมหนังสือ, บทความ, รีโพสิทอรี และแหล่งข้อมูลต่างๆ จากคอมมูนิตี้ ที่มีอิทธิพลต่อวิธีคิดของผมในการนำเสนอหัวข้อต่างๆ ในคู่มือเล่มนี้ หากคุณต้องการศึกษาเจาะลึกเพิ่มเติมในเนื้อหาส่วนใดก็ตามที่เราได้กล่าวถึงไป นี่คือจุดเริ่มต้นที่ดีที่สุดที่ผมอยากแนะนำ

## หนังสือ

**[Design Patterns and Best Practices in Rust](https://www.amazon.com/Design-Patterns-Best-Practices-Rust/dp/1836209479)** โดย Evan Williams (2025) เป็นหนังสือที่พาสำรวจดีไซน์แพตเทิร์นแบบ idiomatic ใน Rust ไว้อย่างเข้มข้น ครอบคลุมทั้งแพตเทิร์นของ GoF ที่นำมาปรับใช้ให้เข้ากับธรรมชาติของ Rust, แพตเทิร์นเชิงฟังก์ชัน (functional patterns) ตลอดจนแพตเทิร์นด้านสถาปัตยกรรมที่คุณจะได้นำไปประยุกต์ใช้งานจริงในโปรเจกต์

**[The Rust Spellbook](https://bitfieldconsulting.com/posts/best-rust-books)** (2026) อัดแน่นไปด้วยเคล็ดลับและเทคนิคของ Rust หลายร้อยข้อ เหมาะอย่างยิ่งสำหรับการค้นพบฟีเจอร์ที่ไม่ค่อยมีใครรู้จักของภาษา ไลบรารีมาตรฐาน และทูลเชน ซึ่งคุณอาจไม่มีโอกาสได้พบเห็นด้วยตนเองในชีวิตประจำวัน

**[Rust Web Development](https://www.manning.com/books/rust-web-development)** เขียนโดยตัวผมเอง (จัดพิมพ์โดย Manning) เล่มนี้คือผลงานเล่มก่อนหน้าของผมที่ว่าด้วยการสร้างเว็บเซอร์วิสใน Rust โดยเน้น Warp และระบบนิเวศโดยรวม หากคุณต้องการทำความเข้าใจบริบทเพิ่มเติมเกี่ยวกับมุมมองและวิธีคิดของผมที่มีต่อปัญหาเหล่านี้ นี่คือจุดเริ่มต้นที่ดีในการศึกษาค้นคว้า

## บทความด้านสถาปัตยกรรมและการออกแบบ

**[Master Hexagonal Architecture in Rust](https://www.howtocodeit.com/guides/master-hexagonal-architecture-in-rust)** จากประสบการณ์ของผม นี่คือคู่มือที่เจาะลึกและละเอียดถี่ถ้วนที่สุดเกี่ยวกับการอิมพลีเมนต์สถาปัตยกรรม Hexagonal (Ports and Adapters) ใน Rust โดยพาไล่เรียงตั้งแต่การสร้างแบบจำลองโดเมน, การนิยามพอร์ตผ่านเทรต, การเขียนอะแดปเตอร์, การทำ dependency injection, กลยุทธ์การทดสอบ ไปจนถึงข้อดีข้อเสีย (trade-offs) ที่คุณต้องเผชิญระหว่างทาง ซึ่งผมได้หยิบยืมแนวคิดจากบทความนี้มาใช้อย่างมากในการเขียนบทสถาปัตยกรรมของคู่มือนี้

**[A Rustacean Clean Architecture Approach to Web Development](https://kigawas.me/posts/rustacean-clean-architecture-approach/)** อธิบายสถาปัตยกรรม 4 เลเยอร์ (โมเดล, เลเยอร์การจัดเก็บข้อมูล, เราเตอร์, เอกสารประกอบ) พร้อมมุมมองเชิงปฏิบัติในการลดการพึ่งพาเฟรมเวิร์ก ผมคิดว่าบทความนี้ช่วยเสริมบทความ Hexagonal ได้อย่างลงตัว เพราะแสดงให้เห็นแนวทางที่เรียบง่ายกว่าและทำงานได้ดีเยี่ยมเมื่อระบบของคุณเน้นงานสไตล์ CRUD เป็นหลัก

**[Rust, Axum, and Onion Architecture](https://medium.com/@jonathan.el.baz/rust-axum-and-onion-architecture-escaping-the-tech-debt-spiral-14df5db946df)** พาเดินชมขั้นตอนการนำ Onion Architecture ไปประยุกต์ใช้จริงร่วมกับ Axum ครอบคลุมทั้งเลเยอร์ Presentation, Application, Domain และ Infrastructure พร้อมตัวอย่างโค้ดที่เป็นรูปธรรมซึ่งคุณสามารถทำตามได้ทันที

**[Building a Clean Rust Backend with Axum, Diesel, PostgreSQL and DDD](https://medium.com/@qkpiot/building-a-robust-rust-backend-with-axum-diesel-postgresql-and-ddd-from-concept-to-deployment-b25cf5c65bc8)** นำเสนอแพตเทิร์นการออกแบบเชิงโดเมน (Domain-Driven Design หรือ DDD) ร่วมกับ Axum และ Diesel คุณจะได้เห็นตัวอย่างการนำ Repository Pattern, การจัดการข้อผิดพลาดแบบแบ่งเลเยอร์ และการเขียนตัวแยกข้อมูลเฉพาะตัว (custom extractors) มารวมไว้ในที่เดียวกัน

**[The Best Way to Structure Rust Web Services](https://blog.logrocket.com/best-way-structure-rust-web-services/)** ครอบคลุมแพตเทิร์นการจัดโครงสร้างโปรเจกต์ ตั้งแต่แบบโมดูลระนาบเดียว (flat modules) ไปจนถึง Clean Architecture ที่แยกเป็น Cargo Workspace สิ่งที่ผมชอบเป็นพิเศษคือคำแนะนำเชิงปฏิบัติว่าสถานการณ์ใดควรเลือกใช้แนวทางไหน

## คู่มือเฉพาะของ Axum

**[The Ultimate Guide to Axum (Shuttle)](https://www.shuttle.dev/blog/2023/12/06/using-axum-rust)** ครอบคลุมเนื้อหาสำคัญไว้ครบถ้วนรอบด้าน: ทั้งแฮนด์เลอร์, การเราต์, การจัดการสถานะ, ตัวแยกข้อมูลแบบกำหนดเอง, มิดเดิลแวร์, การทดสอบด้วย `oneshot` ไปจนถึงการดีพลอยต์ หากคุณต้องการอ่านบทความเดียวที่ปูพื้นฐาน Axum ได้ครบทุกมิติ นี่คือตัวเลือกที่ยอดเยี่ยม

**[How to Build Production-Ready REST APIs in Rust with Axum](https://oneuptime.com/blog/post/2026-01-07-rust-axum-rest-api/view)** นำพาคุณผ่านวงจรชีวิตทั้งหมดของการพัฒนา API ระดับ production: ตั้งแต่การเริ่มต้นโปรเจกต์, การจัดการข้อผิดพลาด, การตรวจสอบความถูกต้อง, การยืนยันตัวตน, การประกอบมิดเดิลแวร์, การทำ graceful shutdown ไปจนถึงการดีพลอยต์ด้วย Docker จัดว่าเป็นคู่มืออ้างอิงแบบครบวงจรที่ดีมาก

**[Building High-Performance APIs with Axum and Rust](https://dasroot.net/posts/2026/04/building-high-performance-apis-axum-rust/)** มุ่งเน้นไปที่การรีดประสิทธิภาพขั้นสูง ซึ่งเป็นจุดที่เราไม่ได้เจาะลึกมากนักในคู่มือนี้ โดยจะครอบคลุมทั้งการวัดประสิทธิภาพ (benchmarking) และกลยุทธ์การปรับแต่งความเร็วที่เจาะจงกับ Axum โดยเฉพาะ

**[Error Handling in Axum (LogRocket)](https://blog.logrocket.com/rust-axum-error-handling/)** พาสำรวจแนวทางต่างๆ ในการจัดการข้อผิดพลาดบน Axum ตั้งแต่การส่งคืนสถานะ HTTP แบบง่ายๆ ไปจนถึงการสร้างชนิดข้อมูลข้อผิดพลาดเฉพาะตัวร่วมกับเทรต `IntoResponse` หากบทการจัดการข้อผิดพลาดของเราทำให้คุณอยากเห็นทางเลือกที่หลากหลายขึ้น ขอแนะนำให้เริ่มจากที่นี่

**[Elegant Error Handling with IntoResponse (Leapcell)](https://leapcell.io/blog/elegant-error-handling-in-axum-actix-web-with-intoresponse)** นำเสนอแพตเทิร์นการจับคู่ระหว่าง `thiserror` กับ `IntoResponse` เพื่อรวมศูนย์การจัดการข้อผิดพลาด เป็นแนวทางที่สะอาดและทำงานได้ผลดีเยี่ยมในทางปฏิบัติจริง

## การสร้างแบบจำลองโดเมนและการออกแบบเชิงชนิดข้อมูล

**[Using Types to Guarantee Domain Invariants](https://lpalmieri.com/posts/2020-12-11-zero-to-production-6-domain-modelling/)** โดย Luca Palmieri เป็นหนึ่งในบทความโปรดของผมว่าด้วยแพตเทิร์น newtype และหลักการ "parse, don't validate" ที่นำมาประยุกต์ใช้กับเว็บแอปพลิเคชันใน Rust หากคุณประทับใจกับแนวคิดเหล่านี้ในบทก่อนๆ บทความนี้จะพาคุณดำดิ่งลงไปลึกยิ่งขึ้น

**[Type-Driven Design in Rust and TypeScript](https://www.luiscardoso.dev/blog/parsing-data-with-rust-typescript)** เปรียบเทียบแนวทางการออกแบบโดยขับเคลื่อนด้วยระบบชนิดข้อมูล (type-driven design) ระหว่างภาษา Rust และ TypeScript หากคุณมีพื้นฐานมาจาก TypeScript (ซึ่งพวกเราหลายคนเป็นเช่นนั้น) บทความนี้จะช่วยเชื่อมต่อภาพความคิดในหัวของคุณได้อย่างดี

**[Rust Design Patterns](https://rust-unofficial.github.io/patterns/)** แคตตาล็อกที่รวบรวมและดูแลโดยคอมมูนิตี้ ซึ่งบรรจุดีไซน์แพตเทิร์น, แอนติแพตเทิร์น และสำนวนภาษา (idioms) ของ Rust ไว้อย่างครบถ้วน รวมถึงแพตเทิร์น newtype และแพตเทิร์นอื่นๆ ที่พบได้บ่อยในงานพัฒนาเว็บ ผมมักจะย้อนกลับมาเปิดอ่านหน้านี้อยู่เป็นประจำ

## หัวข้อเฉพาะ

**[Secure Configuration and Secrets Management in Rust](https://leapcell.io/blog/secure-configuration-and-secrets-management-in-rust-with-secrecy-and-environment-variables)** เจาะลึกการใช้เครต `secrecy`, การจัดการตัวแปรสภาพแวดล้อม และการปกป้องข้อมูลลับในหน่วยความจำ หากคุณต้องการยกระดับความปลอดภัยให้ไกลกว่าที่เรากล่าวถึงในบทการตั้งค่า นี่คือก้าวต่อไปที่เหมาะสมอย่างยิ่ง

**[How to Add Structured Logging to Rust HTTP APIs (techbuddies)](https://www.techbuddies.io/2026/04/04/how-to-add-structured-logging-to-rust-http-apis-with-axum-middleware/)** อธิบายขั้นตอนการสร้างไปป์ไลน์ structured logging อย่างสมบูรณ์แบบ พร้อม correlation ID และการส่งออกข้อมูลเป็น JSON ใช้งานได้จริงและสามารถทำตามได้ทีละสเต็ป

**[Instrument Rust Axum with OpenTelemetry](https://oneuptime.com/blog/post/2026-02-06-instrument-rust-axum-opentelemetry/view)** ครอบคลุมการตั้งค่า OpenTelemetry อย่างเต็มรูปแบบสำหรับ Axum ตั้งแต่การกระจายเทรซไปจนถึงการกำหนดค่า exporter เนื่องจากการตั้งค่า OTel ให้ถูกต้องนั้นค่อนข้างละเอียดอ่อน การมีคู่มืออ้างอิงที่สมบูรณ์จึงช่วยได้มาก

**[JWT Authentication in Rust (Shuttle)](https://www.shuttle.dev/blog/2024/02/21/using-jwt-auth-rust)** นำคุณผ่านการอิมพลีเมนต์การยืนยันตัวตนด้วย JWT โดยใช้ตัวแยกข้อมูล (extractor) แบบกำหนดขึ้นเองทีละขั้นตอน

**[Graceful Shutdown for Axum Servers](https://medium.com/@wedevare/rust-async-graceful-shutdown-for-axum-servers-signals-draining-cleanup-done-right-3b52375412ec)** ครอบคลุมเรื่องการดักจับสัญญาณระบบ, การเคลียร์การเชื่อมต่อที่ค้างอยู่ (connection draining) และแบบแผนการคืนทรัพยากร (cleanup patterns) การทำ graceful shutdown เป็นสิ่งที่เรามักไม่ค่อยนึกถึงจนกว่าจะเจอปัญหาจริง และเมื่อถึงตอนนั้นมันคือสิ่งจำเป็นอย่างยิ่งยวด

**[Health Checks and Readiness Probes in Rust for Kubernetes](https://oneuptime.com/blog/post/2026-01-07-rust-kubernetes-health-checks/view)** ครอบคลุมการสร้าง liveness probe และ readiness probe สำหรับ container orchestrator หากคุณเตรียมดีพลอยต์ระบบขึ้นบน Kubernetes คุณจำเป็นต้องใช้สิ่งเหล่านี้แน่นอน

**[Axum Backend Series: Models, Migrations, DTOs and Repository Pattern](https://blog.0xshadow.dev/posts/backend-engineering-with-axum/axum-model-setup/)** การสาธิตเชิงปฏิบัติในการวางเลเยอร์ฐานข้อมูลด้วย SQLx โค้ดกระชับ นำไปปฏิบัติจริงได้รวดเร็ว

**[An Ergonomic Pattern for SQLx Queries in Axum](https://www.joshka.net/axum-sqlx-queries-pattern/)** อธิบายแพตเทิร์น `FromRef` สำหรับเข้าถึงฐานข้อมูลในแฮนด์เลอร์อย่างสะอาดตา ใช้เวลาอ่านสั้นๆ แต่เป็นแพตเทิร์นที่ผมหยิบมาใช้งานอยู่เสมอ

## รีโพสิทอรีตัวอย่าง

**[rust10x/rust-web-app](https://github.com/rust10x/rust-web-app)** พิมพ์เขียวสำหรับเว็บแอปพลิเคชันบน Axum ระดับ production ดูแลรักษาในฐานะโปรเจกต์อ้างอิงมาตรฐาน และมีฟีเจอร์ขั้นสูงอย่างระบบ multi-tenancy ซึ่งหาดูได้ยากในตัวอย่างทั่วไป

**[launchbadge/realworld-axum-sqlx](https://github.com/launchbadge/realworld-axum-sqlx)** โปรเจกต์ที่อิมพลีเมนต์ตามสเปกของ RealWorld (API จำลองของ Medium) โดยใช้ Axum และ SQLx ผมชอบโปรเจกต์นี้เพราะเป็นตัวอย่างที่สมบูรณ์และใช้งานได้จริงของ API ที่มีความซับซ้อนระดับหนึ่ง ซึ่งหาตัวอย่างแบบนี้ได้ยาก

**[JoeyMckenzie/realworld-rust-axum-sqlx](https://github.com/JoeyMckenzie/realworld-rust-axum-sqlx)** อีกหนึ่งโปรเจกต์ RealWorld แต่เลือกใช้แนวคิดทางสถาปัตยกรรมที่แตกต่างออกไป การนำสองตัวอย่างนี้มาเปรียบเทียบกันเคียงข้างกัน เป็นวิธีที่ยอดเยี่ยมในการทำความเข้าใจว่าการตัดสินใจออกแบบในแต่ละแบบส่งผลอย่างไรในทางปฏิบัติจริง

**[jeremychone-channel/rust-axum-course](https://github.com/jeremychone-channel/rust-axum-course)** รวบรวมโค้ดตัวอย่างจากคอร์สวิดีโอสอน Axum ที่ลงลึกและครอบคลุมทุกเรื่องตั้งแต่พื้นฐานไปจนถึงแพตเทิร์นสำหรับ production พร้อมประวัติคอมมิตที่เป็นระบบระเบียบ เหมาะสำหรับการฝึกทำตามทีละขั้น

**[tokio-rs/axum/examples](https://github.com/tokio-rs/axum/tree/main/examples)** รวบรวมตัวอย่างทางการมากกว่า 30 รายการที่ดูแลโดยทีมพัฒนา Axum โดยตรง เมื่อใดก็ตามที่ผมไม่แน่ใจว่าฟีเจอร์ใดควรเขียนอย่างไร ที่นี่คือที่แรกที่ผมจะเข้าไปตรวจสอบ ครอบคลุมตั้งแต่การเราต์พื้นฐาน ไปจนถึง WebSockets, การทดสอบ และการทำ graceful shutdown

## อ้างอิงระบบนิเวศ

**[Axum ECOSYSTEM.md](https://github.com/tokio-rs/axum/blob/main/ECOSYSTEM.md)** แคตตาล็อกทางการที่รวบรวมเครตจากคอมมูนิตี้มากกว่า 70 เครตสำหรับใช้งานร่วมกับ Axum ก่อนที่คุณจะเริ่มเขียนอะไรขึ้นมาเอง ขอแนะนำให้แวะมาสำรวจที่นี่ก่อน ครอบคลุมตั้งแต่ระบบยืนยันตัวตน, มิดเดิลแวร์, การตรวจสอบความถูกต้อง, การสังเกตการณ์ ไปจนถึงฟังก์ชันเฉพาะทางอีกมากมาย

**[Idiomatic Rust (mre)](https://github.com/mre/idiomatic-rust)** คอลเลกชันที่ผ่านการคัดสรรจากผู้เชี่ยวชาญ รวบรวมบทความ, วิดีโอบรรยาย และรีโพสิทอรีที่สอนการเขียน Rust แบบ idiomatic ไว้อย่างกระชับและตรงประเด็น แม้เนื้อหาจะลึกมากแต่ก็คุ้มค่าแก่การศึกษาอย่างยิ่ง

**[Rust API Guidelines](https://rust-lang.github.io/api-guidelines/)** รายการคำแนะนำและข้อปฏิบัติสำหรับการออกแบบ API สไตล์ idiomatic ใน Rust ซึ่งมีประโยชน์ทั้งการออกแบบ API ของโมดูลภายในโปรเจกต์ ตลอดจน Public HTTP API ของคุณ และเป็นแหล่งอ้างอิงแรกที่ผมจะแนะนำให้ทุกคนที่ถามว่า "ผมควรออกแบบอินเทอร์เฟซนี้อย่างไร?"

