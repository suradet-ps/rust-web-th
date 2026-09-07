# ความปลอดภัย

หากมีสิ่งหนึ่งที่ผมอยากให้คุณได้รับไปจากหนังสือเล่มนี้มากที่สุด นั่นคือ: ความปลอดภัยไม่ใช่ฟีเจอร์ที่คุณจะมาติดตั้งเพิ่มเติมทีหลังในตอนท้าย แต่เป็นชุดแนวทางปฏิบัติที่ต้องแทรกซึมอยู่ในทุกๆ เลเยอร์ของแอปพลิเคชัน ตั้งแต่วิธีการจัดการอินพุตจากผู้ใช้ ไปจนถึงขั้นตอนการตั้งค่าการ deploy เราได้แตะเรื่องความปลอดภัยกันมาเรื่อยๆ ในบทก่อนหน้า ดังนั้นบทนี้จึงรวบรวมประเด็นทั้งหมดมาไว้เป็นเอกสารอ้างอิงฉบับสมบูรณ์ในที่เดียว พร้อมทั้งเสริมหัวข้อสำคัญอื่นๆ ที่ยังไม่ได้กล่าวถึงก่อนหน้านี้ด้วย

## การจัดการอินพุต

แนวป้องกันด่านแรกของเรานั้นเรียบง่ายมาก: จงถือว่าอินพุตภายนอกทั้งหมดเป็นสิ่งที่ไม่น่าไว้วางใจ คุณอาจคิดว่านี่เป็นเรื่องที่รู้กันดีอยู่แล้ว แต่ในความเป็นจริงเรามักจะเผลอการ์ดตกได้ง่ายมาก โดยเฉพาะเมื่อเราเป็นผู้ควบคุมโค้ดทั้งฝั่งไคลเอนต์และเซิร์ฟเวอร์เอง อย่าทำเช่นนั้นเด็ดขาด

**ใช้ Parameterized Queries เท่านั้น** ห้ามสร้างคำสั่ง SQL ด้วยการต่อสตริงโดยเด็ดขาด ทุกๆ query ในฐานข้อมูลจะต้องใช้ parameter placeholders (`$1`, `$2`, ฯลฯ) ร่วมกับการ bind ค่าเสมอ ซึ่ง macro `query!` และ `query_as!` ของ SQLx จะบังคับเรื่องนี้ตั้งแต่ตอนคอมไพล์ และบอกตามตรงว่านี่คือหนึ่งในเหตุผลสำคัญที่สุดที่ควรเลือกใช้ SQLx

**ทำ Validation ที่ขอบเขตของ API เสมอ** เราได้อธิบายเรื่องนี้อย่างละเอียดในบท [การตรวจสอบความถูกต้องของคำขอ](./validation.md) ไปแล้ว หัวใจสำคัญคือการปฏิเสธอินพุตที่ผิดรูปแบบทิ้งไปทันทีก่อนที่มันจะหลุดเข้าไปถึง business logic: ตรวจสอบความยาวของสตริง, รูปแบบของข้อมูล และเช็กฟิลด์ที่จำเป็นต้องมีตั้งแต่ตรงขอบเขตของ API

**แปลงข้อมูลดิบให้เป็น Domain Type (Parse, don't validate)** หากคุณได้อ่านบท [การสร้างแบบจำลองโดเมน](./domain-modeling.md) แล้ว คุณคงคุ้นเคยกับหลักการนี้เป็นอย่างดี: จงแปลงอินพุตดิบให้กลายเป็น domain type โดยเร็วที่สุดเท่าที่จะทำได้ เช่น เมื่อสร้าง `UserName` ผ่านฟังก์ชัน `parse` สำเร็จแล้ว ค่าข้างในจะไม่มีวันมีอักขระต้องห้ามได้อย่างแน่นอนตามโครงสร้างของ type system ให้ระบบ type ทำงานหนักแทนเรา

**จำกัดขนาดของ Request Body** ใช้ `RequestBodyLimitLayer` เพื่อปฏิเสธ payload ที่มีขนาดใหญ่เกินไปตั้งแต่เนิ่นๆ ก่อนที่มันจะเข้ามาสูบหน่วยความจำจนหมด โดยขนาดจำกัดที่ 1 MB ถือว่าเหมาะสมอย่างยิ่งสำหรับ JSON API ส่วนใหญ่

## การยืนยันตัวตนและความลับ

**แฮชรหัสผ่านด้วย Argon2 เสมอ** เราได้พูดถึงเรื่องนี้ในบท [การยืนยันตัวตนและการอนุญาตสิทธิ์](./authentication.md) แล้ว แต่มันคุ้มค่าที่จะเน้นย้ำอีกครั้ง: Argon2 คือมาตรฐานที่ดีที่สุดในปัจจุบันสำหรับการ hash รหัสผ่าน และต้องสร้าง salt แบบสุ่มใหม่สำหรับรหัสผ่านทุกๆ รายการเสมอ

**ใช้ JWT Secret ที่มีความยาวและเป็นค่าสุ่มจริง** JWT secret ของคุณควรเป็นสตริงสุ่มที่มีความยาวอย่างน้อย 48 ตัวอักษร เพราะ secret ที่สั้นเกินไปจะเสี่ยงต่อการถูกโจมตีแบบ brute-force และคุณคงไม่อยากมารู้ตัวเมื่อสายเกินแก้ ควรเก็บ secret ไว้ใน `SecretString` จาก crate `secrecy` และตรวจสอบความยาวของมันตั้งแต่ตอนเริ่มต้นระบบ (startup)

**กำหนดอายุของ Token ให้เหมาะสม** การกำหนดให้ Access Token มีอายุสั้น (เช่น 15 นาทีถึงไม่กี่ชั่วโมง) จะช่วยจำกัดขอบเขตความเสียหายหาก token นั้นหลุดรอดไป หากระบบของคุณต้องการ session ที่ยาวนานขึ้น ให้ใช้กลไก Refresh Token ควบคู่กัน โดยจัดเก็บ refresh token ไว้อย่างปลอดภัยและสามารถสั่งเพิกถอนสิทธิ์ได้

**ห้ามเก็บ Token ใน localStorage เด็ดขาด** สำหรับไคลเอนต์บนเว็บเบราว์เซอร์ ให้ใช้ cookie ที่ตั้งค่า `HttpOnly`, `Secure` และ `SameSite=Strict` แทน เพราะ cookie เหล่านี้ JavaScript จะไม่สามารถเข้าถึงได้ ช่วยป้องกันการขโมย token ผ่านช่องโหว่ XSS ได้โดยตรง

## CORS

คุณอาจเคยพบเจอกับ CORS error มาบ้างในระหว่างการพัฒนา: Cross-Origin Resource Sharing เป็นกลไกความปลอดภัยของเบราว์เซอร์ที่ใช้ควบคุมว่ามี origin ใดบ้างที่ได้รับอนุญาตให้ส่งคำขอมายัง API ของเรา การตั้งค่านโยบาย CORS ผิดพลาดเป็นหนึ่งในปัญหาด้านความปลอดภัยที่พบบ่อยที่สุดในเว็บ API ส่วนหนึ่งเป็นเพราะทางแก้แบบด่วนๆ ในระหว่างพัฒนา ("เปิดอนุญาตให้หมดไปก่อน") มักจะเผลอหลุดรอดขึ้นไปอยู่บน production อยู่เป็นประจำ

```rust
// Production: explicit allow list
CorsLayer::new()
    .allow_origin([
        "https://myapp.com".parse().unwrap(),
    ])
    .allow_methods([Method::GET, Method::POST, Method::PUT, Method::DELETE])
    .allow_headers([header::CONTENT_TYPE, header::AUTHORIZATION])
    .allow_credentials(true)
```

ในระหว่างการพัฒนา การใช้ `CorsLayer::permissive()` นั้นสะดวกสบายก็จริง แต่ต้องตรวจสอบให้แน่ใจว่าจะไม่มีวันหลุดไปถึง production เด็ดขาด เพราะนโยบาย CORS แบบเปิดกว้างทั้งหมดจะยอมให้ origin ใดๆ ก็ตามสามารถยิงคำขอมาที่ API ของคุณได้ ไม่ว่าคำขอนั้นจะแนบ credentials (cookie หรือ Authorization header) มาด้วยหรือไม่ก็ตาม (ขึ้นอยู่กับโหมด credentials ของเบราว์เซอร์และการตั้งค่า `allow_credentials` ของคุณ) แต่ถึงแม้จะไม่มี credentials นโยบายที่เปิดกว้างเกินไปก็ทำให้ API surface ของคุณถูกสำรวจและโจมตีข้าม origin ได้ ยิ่งไปกว่านั้น `CorsLayer::very_permissive()` ยังอันตรายกว่ามากเพราะมันเปิดให้ส่ง credentials ได้ด้วย ดังนั้นจงจำกัด origin ให้ชัดเจนบน production เสมอ

## การป้องกัน CSRF

หาก API ของคุณใช้ cookie ในการยืนยันตัวตน (ต่างจากการใช้ Bearer token) คุณจำเป็นต้องป้องกันการโจมตีแบบ Cross-Site Request Forgery (CSRF) ด้วย crate `axum-csrf-sync-pattern` ได้อิมพลีเมนต์แพตเทิร์น Synchronizer Token Pattern ตามคำแนะนำของ OWASP ซึ่งมีหลักการทำงานดังนี้:

1. เซิร์ฟเวอร์จะสร้าง CSRF token แบบสุ่มขึ้นมา แล้วส่งกลับไปให้ไคลเอนต์ใน custom response header
2. ไคลเอนต์จะต้องแนบ token นั้นกลับมาใน custom request header สำหรับทุกๆ request ที่มีการเปลี่ยนแปลงสถานะ (state-changing requests)
3. เซิร์ฟเวอร์จะตรวจสอบว่า token ใน request header ตรงกับ token ที่เซิร์ฟเวอร์เป็นผู้ออกให้หรือไม่

ทำไมวิธีนี้ถึงได้ผล? เพราะเว็บไซต์ไม่ประสงค์ดีสามารถสั่งให้เบราว์เซอร์ส่ง cookie แนบไปโดยอัตโนมัติได้ก็จริง แต่มันจะไม่สามารถอ่านหรือกำหนด custom header ในการส่งคำขอข้าม origin ได้ (ตราบใดที่นโยบาย CORS ของคุณไม่ได้เปิดช่องให้ทำเช่นนั้น)

## การจำกัดอัตราการเรียก

Rate Limiting มักเป็นสิ่งที่เราคิดว่ายังไม่จำเป็น จนกระทั่งวันหนึ่งมีคนเริ่มยิงถล่ม endpoint ล็อกอินของเรา มันช่วยป้องกันการโจมตีแบบ brute-force, credential stuffing และความพยายามทำ Denial of Service (DoS) โดย crate `tower-governor` มี Tower middleware ที่ช่วยจำกัดคำขอโดยอิงตาม IP address ของไคลเอนต์:

```rust
use tower_governor::{GovernorConfigBuilder, GovernorLayer};

let governor_config = GovernorConfigBuilder::default()
    .per_second(2)
    .burst_size(10)
    .finish()
    .unwrap();

let app = Router::new()
    .merge(api_routes())
    .layer(GovernorLayer { config: governor_config })
    .with_state(state);
```

สำหรับ authentication endpoints (เช่น ล็อกอิน หรือรีเซ็ตรหัสผ่าน) ผมแนะนำให้ตั้งค่าขีดจำกัดที่เข้มงวดเป็นพิเศษ เช่น กำหนดไว้ที่ 5 ครั้งต่อนาทีต่อหนึ่ง IP ซึ่งจะช่วยตัดโอกาสการทำ credential stuffing ได้อย่างมีประสิทธิภาพ

ข้อสำคัญที่ต้องพึงระลึกไว้คือ: หากคุณรันแอปพลิเคชันหลาย instance บน production การทำ rate limiting ตาม IP ในระดับแอปพลิเคชันเพียงอย่างเดียวย่อมไม่เพียงพอ เพราะแต่ละ instance จะนับตัวเลขแยกจากกัน ในกรณีนี้คุณควรเลือกใช้ rate limiter ที่มี Redis อยู่เบื้องหลัง หรือย้ายการจัดการ rate limit ไปไว้ที่ระดับ Load Balancer หรือ API Gateway แทน


## ส่วนหัวด้านความปลอดภัย

HTTP Security Headers เป็นคำสั่งที่บอกให้เบราว์เซอร์เปิดใช้กลไกการป้องกันความปลอดภัยต่างๆ ส่วนหัวที่คุณจำเป็นต้องใช้นั้นขึ้นอยู่กับว่าแอปพลิเคชันของคุณทำหน้าที่เสิร์ฟ HTML หรือเป็นเพียง JSON API: สำหรับเว็บที่เสิร์ฟหน้า HTML ส่วนหัวอย่าง `Content-Security-Policy` และ `X-Frame-Options` ถือว่าขาดไม่ได้ ส่วนสำหรับ API ที่คืนค่าเป็น JSON ล้วน บางส่วนหัวอาจมีความจำเป็นน้อยลงเพราะไม่มีบริบทการ render ของเบราว์เซอร์ให้ต้องปกป้องโดยตรง แต่ถึงอย่างนั้นผมก็ยังแนะนำให้ตั้งค่าส่วนหัวเหล่านี้ไว้ในเชิงป้องกัน (defensive) เสมอ เพราะไม่มีผลเสียอะไรและช่วยป้องกันปัญหาในอนาคตได้ดีกว่า

มาดูตัวอย่างการนำไปใช้เป็น middleware layer กัน:

```rust
use axum::http::{HeaderName, HeaderValue};

async fn security_headers(req: Request, next: Next) -> Response {
    let mut response = next.run(req).await;
    let headers = response.headers_mut();

    // Prevent MIME-type sniffing
    headers.insert(
        HeaderName::from_static("x-content-type-options"),
        HeaderValue::from_static("nosniff"),
    );

    // Control framing (prefer CSP frame-ancestors for modern browsers,
    // but X-Frame-Options is still useful for older ones)
    headers.insert(
        HeaderName::from_static("x-frame-options"),
        HeaderValue::from_static("DENY"),
    );

    // Content Security Policy: the primary defense against XSS.
    // Adjust the directives to match your application's needs.
    headers.insert(
        HeaderName::from_static("content-security-policy"),
        HeaderValue::from_static("default-src 'none'; frame-ancestors 'none'"),
    );

    // Enforce HTTPS connections
    headers.insert(
        HeaderName::from_static("strict-transport-security"),
        HeaderValue::from_static("max-age=63072000; includeSubDomains"),
    );

    headers.insert(
        HeaderName::from_static("referrer-policy"),
        HeaderValue::from_static("strict-origin-when-cross-origin"),
    );

    response
}
```

มาดูกันว่ามีอะไรอยู่ในนี้บ้าง และมีส่วนหัวตัวไหนที่ผมจงใจไม่ใส่:

`Content-Security-Policy` (CSP) คือแนวป้องกันหลักในยุคใหม่ต่อช่องโหว่ Cross-Site Scripting (XSS) นโยบาย CSP ที่รัดกุมมีประสิทธิภาพเหนือกว่า header รุ่นเก่าอย่าง `X-XSS-Protection` ซึ่งทั้ง OWASP และ MDN ต่างประกาศเลิกใช้ (deprecated) ไปแล้ว โปรดอย่าตั้งค่า `X-XSS-Protection` เพราะในบาง edge case มันกลับสร้างช่องโหว่ใหม่ขึ้นมาเสียเอง ให้ใช้ CSP แทนเสมอ

`Strict-Transport-Security` (HSTS) ทำหน้าที่สั่งให้เบราว์เซอร์เชื่อมต่อผ่าน HTTPS เท่านั้น ช่วยป้องกันการโจมตีแบบ Protocol Downgrade และเป็นสิ่งที่ต้องมีเสมอสำหรับการ deploy บน production ที่อยู่หลัง TLS

`X-Frame-Options` ช่วยป้องกันการโจมตีแบบ Clickjacking สำหรับเบราว์เซอร์รุ่นเก่า ส่วนในเบราว์เซอร์สมัยใหม่ directive `frame-ancestors` ใน CSP จะเป็นกลไกหลักที่นิยมใช้มากกว่า แต่ทั้งสองตัวนี้ก็สามารถตั้งค่าควบคู่กันได้โดยไม่มีปัญหา

ส่วนหัวความปลอดภัยเหล่านี้ไม่ได้มาทดแทนการเขียนโค้ดที่ปลอดภัย แต่ช่วยเสริมการป้องกันแบบหลายชั้น (Defense-in-depth) โดยการเปิดใช้กลไกป้องกันฝั่งเบราว์เซอร์ต่อรูปแบบการโจมตีทั่วไป เปรียบเสมือนตาข่ายนิรภัยอีกชั้นหนึ่ง

## การตรวจสอบดีเพนเดนซี

Third-party dependencies สามารถนำช่องโหว่ด้านความปลอดภัยเข้ามาในระบบได้ และในโปรเจกต์ Rust คุณมักจะมี dependency มากกว่าที่คิดไว้เสมอ ดังนั้นจงรัน `cargo audit` เป็นประจำ (และที่สำคัญที่สุดคือควรใส่ไว้ใน CI pipeline) เพื่อตรวจหาช่องโหว่ที่มีรายงานไว้ใน dependency tree ของคุณ:

```
cargo install cargo-audit
cargo audit
```

คำสั่งนี้จะตรวจสอบไฟล์ `Cargo.lock` เทียบกับฐานข้อมูล RustSec Advisory Database และรายงานหากพบว่ามี dependency ตัวใดที่มีช่องโหว่ด้านความปลอดภัย จากประสบการณ์จริง การคอยอัปเดต dependency ให้ทันสมัยอยู่เสมอเป็นหนึ่งในแนวปฏิบัติด้านความปลอดภัยที่ง่ายที่สุดและให้ผลคุ้มค่าที่สุดที่คุณสามารถเริ่มต้นทำได้ทันที

## เช็กลิสต์ความปลอดภัย

นี่คือสรุปเช็กลิสต์แนวปฏิบัติด้านความปลอดภัยที่เราได้กล่าวถึงตลอดทั้งเล่ม ผมแนะนำให้ตรวจเช็กตามรายการเหล่านี้ให้ครบถ้วนก่อนที่คุณจะ deploy ระบบขึ้น production:

- [ ] คำสั่ง SQL ทั้งหมดใช้ Parameterized Queries (ไม่มีการต่อสตริง)
- [ ] จำกัดขนาดของ Request Body ด้วย `RequestBodyLimitLayer`
- [ ] ตั้งค่า Request Timeout ด้วย `TimeoutLayer`
- [ ] มีการทำ Validation ข้อมูลที่ขอบเขตของ API เสมอ
- [ ] กำหนดให้ Domain Types บังคับใช้ Business Invariants ผ่านระบบ Type System
- [ ] รหัสผ่านทั้งหมดถูก Hash ด้วย Argon2
- [ ] JWT Secret มีความยาวอย่างน้อย 48 ตัวอักษรและเป็นค่าสุ่มจริง
- [ ] JWT Secret ถูกจัดเก็บใน `SecretString` และไม่มีการบันทึกลงใน Log เด็ดขาด
- [ ] มีการกำหนดอายุ Token (Expiration Time) และบังคับใช้อย่างเคร่งครัด
- [ ] CORS ถูกจำกัดเฉพาะ Origin ที่กำหนดไว้อย่างชัดเจนบน Production
- [ ] เปิดใช้ระบบป้องกัน CSRF หากใช้การยืนยันตัวตนแบบ Cookie-based
- [ ] ใช้ Rate Limiting กับ Public Endpoints ทั้งหมด
- [ ] ใช้ Rate Limiting ที่เข้มงวดเป็นพิเศษกับ Authentication Endpoints
- [ ] ตั้งค่า Headers ด้านความปลอดภัยครบถ้วน: CSP, HSTS, X-Content-Type-Options และ Referrer-Policy
- [ ] ไม่ตั้งค่า X-XSS-Protection (ให้ใช้ CSP แทน)
- [ ] CORS ถูกควบคุมผ่านการตั้งค่าตอนรันไทม์ ไม่ใช่ขึ้นอยู่กับ Build Profile
- [ ] ไม่เปิดเผยรายละเอียดข้อผิดพลาดภายใน (Internal Errors) ใน Response ของ API
- [ ] การตรวจสอบ JWT ระบุ Algorithm, Issuer และ Audience ไว้อย่างชัดเจน
- [ ] ใช้ UUID เป็น Resource ID (ช่วยให้คาดเดายากขึ้น แต่ยังต้องมีการตรวจสอบสิทธิ์เป็นหลัก)
- [ ] รัน `cargo audit` เป็นประจำหรือใส่ไว้ในระบบ CI
- [ ] รัน `cargo sqlx prepare --check` ในระบบ CI
- [ ] ไฟล์ `.env` ถูกใส่ไว้ใน `.gitignore` และไม่ถูก Commit ขึ้น Git เด็ดขาด

