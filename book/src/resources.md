# แหล่งข้อมูล

ผมอยากรวบรวมหนังสือ บทความ รีโพสิทอรี และแหล่งข้อมูลจากคอมมูนิตี้ที่หล่อหลอมวิธีคิดของผมเกี่ยวกับหัวข้อต่างๆ ในคู่มือนี้ ถ้าคุณอยากเจาะลึกอะไรก็ตามที่เราครอบคลุมไป นี่คือจุดที่ผมจะแนะนำให้เริ่ม

## หนังสือ

**[Design Patterns and Best Practices in Rust](https://www.amazon.com/Design-Patterns-Best-Practices-Rust/dp/1836209479)** โดย Evan Williams (2025) คือการพาเดินชมแพตเทิร์น Rust แบบ idiomatic อย่างแน่นหนา มันครอบคลุมแพตเทิร์นของ GoF ที่ปรับให้เข้ากับ Rust แพตเทิร์นเชิงฟังก์ชัน และแพตเทิร์นสถาปัตยกรรมที่คุณจะใช้จริงในโปรเจกต์จริง

**[The Rust Spellbook](https://bitfieldconsulting.com/posts/best-rust-books)** (2026) เต็มไปด้วยเคล็ดลับและเทคนิคของ Rust หลายร้อยข้อ มันยอดเยี่ยมสำหรับการค้นพบฟีเจอร์ที่รู้จักน้อยของภาษา ไลบรารีมาตรฐาน และทูลเชน ที่คุณอาจไม่สะดุดเจอด้วยตัวเอง

**[Rust Web Development](https://www.manning.com/books/rust-web-development)** โดยตัวผมเอง (Manning) นี่คือหนังสือเล่มก่อนของผมเกี่ยวกับการสร้างเว็บเซอร์วิสใน Rust ครอบคลุม Warp และระบบนิเวศโดยรวม ถ้าคุณอยากได้บริบทเพิ่มเติมเกี่ยวกับวิธีที่ผมคิดกับปัญหาเหล่านี้ นั่นคือที่ที่ดีที่จะไปดู

## บทความด้านสถาปัตยกรรมและการออกแบบ

**[Master Hexagonal Architecture in Rust](https://www.howtocodeit.com/guides/master-hexagonal-architecture-in-rust)** ในประสบการณ์ของผมคือคู่มือที่ละเอียดถี่ถ้วนที่สุดในการอิมพลีเมนต์สถาปัตยกรรมเฮกซะโกนัล (พอร์ตและอะแดปเตอร์) ใน Rust มันพาเดินผ่านการสร้างแบบจำลองโดเมน พอร์ตแบบใช้เทรต การอิมพลีเมนต์อะแดปเตอร์ การฉีดดีเพนเดนซี กลยุทธ์การทดสอบ และการแลกเปลี่ยน (trade-off) ที่คุณจะเจอระหว่างทาง ผมพึ่งพาบทความนี้อย่างมากตอนเขียนบทสถาปัตยกรรมในคู่มือนี้

**[A Rustacean Clean Architecture Approach to Web Development](https://kigawas.me/posts/rustacean-clean-architecture-approach/)** อธิบายสถาปัตยกรรมสี่เลเยอร์ (โมเดล, การคงอยู่, เราเตอร์, เอกสารประกอบ) พร้อมมุมมองเชิงปฏิบัติเกี่ยวกับการผูกกับเฟรมเวิร์ก ผมคิดว่ามันช่วยเสริมคู่มือสถาปัตยกรรมเฮกซะโกนัลได้ดี เพราะมันแสดงแนวทางที่ง่ายกว่าที่ทำงานได้ดีเมื่อแอปของคุณส่วนใหญ่เป็น CRUD

**[Rust, Axum, and Onion Architecture](https://medium.com/@jonathan.el.baz/rust-axum-and-onion-architecture-escaping-the-tech-debt-spiral-14df5db946df)** พาเดินชมการอิมพลีเมนต์สถาปัตยกรรมแบบหัวหอมด้วย Axum มันครอบคลุมเลเยอร์ presentation, application, domain และ infrastructure พร้อมตัวอย่างโค้ดรูปธรรมที่คุณทำตามได้

**[Building a Clean Rust Backend with Axum, Diesel, PostgreSQL and DDD](https://medium.com/@qkpiot/building-a-robust-rust-backend-with-axum-diesel-postgresql-and-ddd-from-concept-to-deployment-b25cf5c65bc8)** แสดงแพตเทิร์นการออกแบบเชิงโดเมน (domain-driven design) ร่วมกับ Axum และ Diesel คุณจะพบแพตเทิร์นรีพอสิทอรี การจัดการข้อผิดพลาดแบบเลเยอร์ และตัวแยกข้อมูลแบบกำหนดเองทั้งหมดในที่เดียว

**[The Best Way to Structure Rust Web Services](https://blog.logrocket.com/best-way-structure-rust-web-services/)** ครอบคลุมแพตเทิร์นการจัดระเบียบโปรเจกต์ ตั้งแต่โมดูลแบบราบไปจนถึง clean architecture แบบใช้เวิร์กสเปซ สิ่งที่ผมชอบเกี่ยวกับมันคือคำแนะนำเชิงปฏิบัติว่าเมื่อไหร่ควรเลือกแต่ละแนวทาง

## คู่มือเฉพาะของ Axum

**[The Ultimate Guide to Axum (Shuttle)](https://www.shuttle.dev/blog/2023/12/06/using-axum-rust)** ครอบคลุมพื้นที่เยอะมาก: แฮนด์เลอร์ การกำหนดเส้นทาง การจัดการสถานะ ตัวแยกข้อมูลแบบกำหนดเอง มิดเดิลแวร์ การทดสอบด้วย `oneshot` และการดีพลอยต์ ถ้าคุณต้องการบทความหนึ่งบทความที่แตะพื้นฐาน Axum ทั้งหมด นี่คือตัวเลือกที่ดี

**[How to Build Production-Ready REST APIs in Rust with Axum](https://oneuptime.com/blog/post/2026-01-07-rust-axum-rest-api/view)** พาคุณผ่านไลฟ์ไซเคิลทั้งหมดของ API สำหรับ production: การตั้งค่าโปรเจกต์ การจัดการข้อผิดพลาด การตรวจสอบความถูกต้อง การยืนยันตัวตน การประกอบมิดเดิลแวร์ การปิดระบบอย่างนุ่มนวล และการดีพลอยต์ด้วย Docker มันเป็นเอกสารอ้างอิงแบบครบวงจรที่ดี

**[Building High-Performance APIs with Axum and Rust](https://dasroot.net/posts/2026/04/building-high-performance-apis-axum-rust/)** เน้นที่ประสิทธิภาพ ซึ่งเราไม่ได้เจาะลึกมากนักในคู่มือนี้ มันครอบคลุมการวัดประสิทธิภาพ (benchmark) และกลยุทธ์การปรับให้เหมาะสมเฉพาะของ Axum

**[Error Handling in Axum (LogRocket)](https://blog.logrocket.com/rust-axum-error-handling/)** ไล่ดูแนวทางต่างๆ ในการจัดการข้อผิดพลาดใน Axum ตั้งแต่การคืนรหัสสถานะง่ายๆ ไปจนถึงชนิดข้อมูลข้อผิดพลาดแบบกำหนดเองกับ `IntoResponse` ถ้าบทการจัดการข้อผิดพลาดของเราทำให้คุณอยากได้ตัวเลือกเพิ่มเติม เริ่มจากที่นี่

**[Elegant Error Handling with IntoResponse (Leapcell)](https://leapcell.io/blog/elegant-error-handling-in-axum-actix-web-with-intoresponse)** แสดงแพตเทิร์น `thiserror` บวกกับ `IntoResponse` สำหรับการจัดการข้อผิดพลาดแบบรวมศูนย์ มันเป็นแนวทางที่สะอาดซึ่งผมพบว่าใช้ได้ผลดีในทางปฏิบัติ

## การสร้างแบบจำลองโดเมนและการออกแบบเชิงชนิดข้อมูล

**[Using Types to Guarantee Domain Invariants](https://lpalmieri.com/posts/2020-12-11-zero-to-production-6-domain-modelling/)** โดย Luca Palmieri เป็นหนึ่งในบทความโปรดของผมเกี่ยวกับแพตเทิร์น newtype และหลักการ "parse, don't validate" ที่ประยุกต์กับเว็บแอปพลิเคชัน Rust ถ้าแนวคิดเหล่านั้นคลิกกับคุณในบทก่อนหน้าของเรา บทความนี้เจาะลึกยิ่งขึ้น

**[Type-Driven Design in Rust and TypeScript](https://www.luiscardoso.dev/blog/parsing-data-with-rust-typescript)** เปรียบเทียบแนวทางเชิงชนิดข้อมูลทั้งสองภาษา ถ้าคุณมาจากฝั่ง TypeScript (และเราหลายคนก็เป็นแบบนั้น) บทความนี้ช่วยเชื่อมโมเดลความคิดได้

**[Rust Design Patterns](https://rust-unofficial.github.io/patterns/)** คือแคตตาล็อกที่ดูแลโดยคอมมูนิตี้ของแพตเทิร์นการออกแบบ แอนติแพตเทิร์น และสำนวนของ Rust มันรวมแพตเทิร์น newtype และแพตเทิร์นอื่นๆ อีกมากมายที่เกิดขึ้นในเว็บดีเวลลอปเมนต์ ผมพบว่าตัวเองกลับมาหาเล่มนี้เป็นประจำ

## หัวข้อเฉพาะ

**[Secure Configuration and Secrets Management in Rust](https://leapcell.io/blog/secure-configuration-and-secrets-management-in-rust-with-secrecy-and-environment-variables)** ครอบคลุมครีต `secrecy` การจัดการตัวแปรสภาพแวดล้อม และการปกป้องความลับในหน่วยความจำ ถ้าคุณอยากไปให้ไกลกว่าที่เราครอบคลุมในบทการตั้งค่าของเรา นี่คือก้าวถัดไปที่ดี

**[How to Add Structured Logging to Rust HTTP APIs (techbuddies)](https://www.techbuddies.io/2026/04/04/how-to-add-structured-logging-to-rust-http-apis-with-axum-middleware/)** พาเดินชมการสร้างไปป์ไลน์การบันทึกข้อมูลแบบมีโครงสร้างที่สมบูรณ์พร้อม correlation ID และเอาต์พุต JSON ปฏิบัติได้จริงมาก และคุณทำตามทีละขั้นได้

**[Instrument Rust Axum with OpenTelemetry](https://oneuptime.com/blog/post/2026-02-06-instrument-rust-axum-opentelemetry/view)** ครอบคลุมการตั้งค่า OpenTelemetry เต็มรูปแบบสำหรับ Axum รวมถึงการกระจายเทรซและการตั้งค่าเอ็กซ์พอร์ตเตอร์ การทำให้ OTel ถูกต้องอาจพิถีพิถัน การมีเอกสารอ้างอิงที่สมบูรณ์จึงช่วยได้

**[JWT Authentication in Rust (Shuttle)](https://www.shuttle.dev/blog/2024/02/21/using-jwt-auth-rust)** พาคุณผ่านการอิมพลีเมนต์การยืนยันตัวตนแบบ JWT ด้วยตัวแยกข้อมูลแบบกำหนดเอง ทีละขั้น

**[Graceful Shutdown for Axum Servers](https://medium.com/@wedevare/rust-async-graceful-shutdown-for-axum-servers-signals-draining-cleanup-done-right-3b52375412ec)** ครอบคลุมการจัดการสัญญาณ การระบายการเชื่อมต่อ และแพตเทิร์นการล้างข้อมูล การปิดระบบอย่างนุ่มนวลเป็นหนึ่งในสิ่งเหล่านั้นที่คุณไม่คิดถึงจนกว่าคุณจะต้องการมัน และตอนนั้นคุณต้องการมันจริงๆ

**[Health Checks and Readiness Probes in Rust for Kubernetes](https://oneuptime.com/blog/post/2026-01-07-rust-kubernetes-health-checks/view)** ครอบคลุมการอิมพลีเมนต์ลีฟเนสพรอบและเรดดิเนสพรอบสำหรับออร์เคสเตรเตอร์คอนเทนเนอร์ ถ้าคุณกำลังดีพลอยต์ไปยัง Kubernetes คุณจะต้องการสิ่งเหล่านี้

**[Axum Backend Series: Models, Migrations, DTOs and Repository Pattern](https://blog.0xshadow.dev/posts/backend-engineering-with-axum/axum-model-setup/)** คือการพาเดินชมเชิงปฏิบัติของการตั้งค่าเลเยอร์ฐานข้อมูลด้วย SQLx มันลงมือทำจริงและพาคุณไปถึงโค้ดที่ทำงานได้อย่างรวดเร็ว

**[An Ergonomic Pattern for SQLx Queries in Axum](https://www.joshka.net/axum-sqlx-queries-pattern/)** อธิบายแพตเทิร์น `FromRef` สำหรับการเข้าถึงฐานข้อมูลอย่างสะอาดในแฮนด์เลอร์ อ่านสั้นๆ แต่แพตเทิร์นที่มันแสดงคือสิ่งที่ผมใช้ตลอดเวลา

## รีโพสิทอรีตัวอย่าง

**[rust10x/rust-web-app](https://github.com/rust10x/rust-web-app)** คือพิมพ์เขียวสำหรับเว็บแอปพลิเคชัน Axum ระดับ production มันถูกดูแลในฐานะอิมพลีเมนเทชันอ้างอิงและรวมสิ่งที่อย่างการรองรับ multi-tenancy ที่คุณจะไม่พบในรีโพสิทอรีตัวอย่างส่วนใหญ่

**[launchbadge/realworld-axum-sqlx](https://github.com/launchbadge/realworld-axum-sqlx)** อิมพลีเมนต์สเปก RealWorld (API เลียนแบบ Medium) โดยใช้ Axum และ SQLx ผมชอบมันเพราะมันเป็นตัวอย่างที่สมบูรณ์และทำงานได้จริงของ API ที่ไม่ธรรมดา ซึ่งหายาก

**[JoeyMckenzie/realworld-rust-axum-sqlx](https://github.com/JoeyMckenzie/realworld-rust-axum-sqlx)** คืออีกหนึ่งอิมพลีเมนเทชัน RealWorld แต่มีแนวทางสถาปัตยกรรมที่ต่างกัน การเปรียบเทียบทั้งสองแบบเคียงข้างกันเป็นวิธีที่ยอดเยี่ยมในการเห็นว่าการตัดสินใจออกแบบที่ต่างกันให้ผลอย่างไรในทางปฏิบัติ

**[jeremychone-channel/rust-axum-course](https://github.com/jeremychone-channel/rust-axum-course)** มีโค้ดจากคอร์สวิดีโอ Axum ที่ละเอียดถี่ถ้วน มันครอบคลุมทุกอย่างตั้งแต่พื้นฐานไปจนถึงแพตเทิร์นสำหรับ production และประวัติคอมมิตมีโครงสร้างที่ดีถ้าคุณอยากทำตาม

**[tokio-rs/axum/examples](https://github.com/tokio-rs/axum/tree/main/examples)** มีตัวอย่างทางการกว่า 30 ตัวอย่างที่ดูแลโดยทีม Axum เมื่อผมไม่แน่ใจว่าบางอย่างควรทำงานอย่างไร นี่มักเป็นที่แรกที่ผมตรวจ มันครอบคลุมทุกอย่างตั้งแต่การกำหนดเส้นทางพื้นฐานไปจนถึง WebSockets การทดสอบ และการปิดระบบอย่างนุ่มนวล

## อ้างอิงระบบนิเวศ

**[Axum ECOSYSTEM.md](https://github.com/tokio-rs/axum/blob/main/ECOSYSTEM.md)** คือแคตตาล็อกทางการของครีตที่ดูแลโดยคอมมูนิตี้กว่า 70 ครีตสำหรับ Axum ก่อนที่คุณจะสร้างอะไรด้วยตัวเอง ตรวจดูที่นี่ก่อน มันครอบคลุมการยืนยันตัวตน มิดเดิลแวร์ การตรวจสอบความถูกต้อง การสังเกตการณ์ และฟีเจอร์เฉพาะทางอีกสารพัด

**[Idiomatic Rust (mre)](https://github.com/mre/idiomatic-rust)** คือคอลเลกชันที่ผ่านการรีวิวโดยเพื่อนร่วมวิชาชีพของบทความ การบรรยาย และรีโพสิทอรีที่สอน Rust แบบ idiomatic ที่กระชับ มันเป็นเหมือนโพรงกระต่ายที่ลึกล้ำ แต่ก็คุ้มค่าที่จะดำดิ่ง

**[Rust API Guidelines](https://rust-lang.github.io/api-guidelines/)** มีรายการคำแนะนำมากมายสำหรับการออกแบบ API Rust แบบ idiomatic มันมีประโยชน์ทั้งกับ API โมดูลภายในของคุณและ API HTTP สาธารณะของคุณ และมันคือที่ที่ผมจะชี้ให้ใครก็ตามที่ถามว่า "ฉันควรออกแบบอินเทอร์เฟซนี้อย่างไร?"
