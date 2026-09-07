# มิดเดิลแวร์

เว็บแอปพลิเคชันแทบทุกตัวล้วนต้องมีตรรกะกลุ่มหนึ่งที่ไม่ใช่ความรับผิดชอบของแฮนด์เลอร์ตัวใดตัวหนึ่งโดยเฉพาะ แต่จำเป็นต้องทำงานครอบคลุมหลายคำขอ (หรือแทบทุกคำขอ) เช่น การบันทึก Log, การยืนยันตัวตน (Authentication), การบีบอัดข้อมูล (Compression), การจำกัดอัตราการเรียกใช้ (Rate Limiting), การกำหนด Request ID และการจำกัดเวลาประมวลผล (Timeout) ใน Axum เราจัดการงานเหล่านี้ทั้งหมดผ่าน 'มิดเดิลแวร์ (Middleware)' และด้วยความที่ระบบมิดเดิลแวร์ของ Axum ถูกสร้างขึ้นบน Tower เราจึงสามารถเข้าถึงระบบนิเวศอันกว้างใหญ่ของคอมโพเนนต์สำเร็จรูป พร้อมทั้งมีวิธีที่สะอาดและเป็นระเบียบในการสร้างมิดเดิลแวร์ขึ้นใช้งานเอง

จุดที่มักทำให้นักพัฒนาสะดุดบ่อยที่สุดไม่ใช่ขั้นตอนการเขียนมิดเดิลแวร์ แต่เป็นการจัดเรียงลำดับมิดเดิลแวร์ให้ถูกต้อง เราจึงจะมาเริ่มต้นทำความเข้าใจจากจุดนี้กันก่อน

## โมเดลเลเยอร์ของ Tower

Tower มองมิดเดิลแวร์ในรูปแบบของ 'เลเยอร์ (Layer)' ที่ซ้อนห่อหุ้มเซอร์วิสไว้ เมื่อมีคำขอส่งเข้ามา คำขอนั้นจะเดินทางผ่านแต่ละเลเยอร์ตามลำดับ จากชั้นนอกสุดเข้าไปยังชั้นในสุด (ซึ่งก็คือฟังก์ชันแฮนด์เลอร์ของคุณ) จากนั้นข้อมูลการตอบกลับ (Response) ก็จะเดินทางย้อนกลับออกมาผ่านเลเยอร์เดิมในลำดับย้อนกลับ ดังนั้นเลเยอร์แรกที่คุณเพิ่มเข้าไปจึงเป็นด่านแรกที่ได้รับ Request ขาเข้า และเป็นด่านสุดท้ายที่ได้ประมวลผล Response ขาออก

```
Request → Compression → Tracing → Timeout → Auth → Handler
Response ← Compression ← Tracing ← Timeout ← Auth ← Handler
```

การจัดเรียงลำดับนี้มีความสำคัญมากกว่าที่คุณคิด หากคุณต้องการให้ Tracing บันทึกระยะเวลาการประมวลผลทั้งหมดของคำขอ ซึ่งรวมถึงเวลาที่ใช้ในการยืนยันตัวตนด้วย เลเยอร์ Tracing จะต้องอยู่ด้านนอกของเลเยอร์ Auth เสมอ หากวางสลับลำดับกัน ข้อมูลระยะเวลาของคุณจะคลาดเคลื่อนไปในแบบที่สังเกตได้ยากและชวนปวดหัวอย่างยิ่งในการตรวจสอบปัญหา

## สแตกมิดเดิลแวร์ที่แนะนำ

ลองมาดูชุดมิดเดิลแวร์ (Middleware Stack) ตัวอย่างที่ผมมักเลือกใช้ในแอปพลิเคชันระดับ Production ซึ่งประกอบขึ้นอย่างเป็นระเบียบด้วย `ServiceBuilder`:

```rust
use tower::ServiceBuilder;
use tower_http::{
    compression::CompressionLayer,
    cors::CorsLayer,
    limit::RequestBodyLimitLayer,
    request_id::{MakeRequestUuid, SetRequestIdLayer, PropagateRequestIdLayer},
    timeout::TimeoutLayer,
    trace::TraceLayer,
};
use std::time::Duration;

let app = Router::new()
    .merge(api_routes())
    .layer(
        ServiceBuilder::new()
            // Layers execute top-to-bottom on the request path.
            .layer(CompressionLayer::new())
            .layer(SetRequestIdLayer::x_request_id(MakeRequestUuid))
            .layer(TraceLayer::new_for_http())
            .layer(PropagateRequestIdLayer::x_request_id())
            .layer(TimeoutLayer::new(Duration::from_secs(30)))
            .layer(RequestBodyLimitLayer::new(1024 * 1024)) // 1 MB
            .layer(cors_layer())
    )
    .with_state(state);
```

เรามาไล่ดูแต่ละเลเยอร์ว่ามีหน้าที่อะไร และเพราะเหตุใดจึงต้องวางไว้ในตำแหน่งนั้นๆ:

**CompressionLayer** ทำหน้าที่บีบอัดข้อมูลใน Response Body ด้วย gzip (หรือ brotli หรือ deflate ขึ้นอยู่กับสิ่งที่ไคลเอนต์ระบุว่ารองรับ) พร้อมทั้งกำหนด Header `Content-Encoding` ให้โดยอัตโนมัติ เราวางไว้ในตำแหน่งนอกสุดเพื่อให้ทำหน้าที่บีบอัด Response Body ในขั้นตอนสุดท้าย หลังจากที่เลเยอร์ชั้นในทั้งหมดประมวลผลข้อมูลเสร็จสิ้นเรียบร้อยแล้ว (ข้อควรสังเกต: การบีบอัดจะกระทำกับ Body เท่านั้น โดยไม่แตะต้อง HTTP Headers)

**SetRequestIdLayer** ทำหน้าที่สร้าง UUID เฉพาะตัวและแนบเข้าไปกับคำขอขาเข้า เราวางเลเยอร์นี้ไว้ก่อนหน้า `TraceLayer` เพื่อให้มั่นใจว่า Request ID จะพร้อมใช้งานทันทีในจังหวะที่ Tracing Span ถูกสร้างขึ้น

**TraceLayer** ทำหน้าที่บันทึก Structured Logs สำหรับทุกๆ คำขอ ไม่ว่าจะเป็น HTTP Method, URL Path, Status Code และระยะเวลาที่ใช้ในการประมวลผล เนื่องจากเลเยอร์นี้ทำงานหลังจากมีการกำหนด Request ID แล้ว Tracing Span จึงมีข้อมูล Request ID ผูกติดไปด้วยเสมอ ซึ่งมีประโยชน์อย่างยิ่งในการสืบค้น Log ในภายหลัง

**PropagateRequestIdLayer** ทำหน้าที่คัดลอก Request ID ไปใส่ไว้ใน Response Header ขาออก เลเยอร์นี้จะอยู่ถัดจาก `TraceLayer` เพื่อให้ Response Header ได้รับการตั้งค่าเรียบร้อยก่อนที่ Tracing จะปิด Span ของฝั่งการตอบกลับ การเรียงลำดับในรูปแบบนี้ (สร้าง ID -> Tracing -> ส่งต่อ ID) เป็นไปตามแนวทางปฏิบัติที่แนะนำในเอกสารของ tower-http เพื่อให้ Request ID ปรากฏตรงกันอย่างสม่ำเสมอทั้งใน Log ของคำขอและใน Response Header

**TimeoutLayer** ทำหน้าที่ยกเลิกคำขอที่ใช้เวลาประมวลผลนานเกินกว่าที่กำหนดไว้ ซึ่งเป็นกลไกป้องกันสำคัญสำหรับรับมือกับไคลเอนต์ที่ส่งข้อมูลช้าผิดปกติ, คิวรีฐานข้อมูลที่ค้างหรือไม่คืนผลลัพธ์ หรือคำขอที่ติดบล็อกจนทำให้ระบบค้างคา

**RequestBodyLimitLayer** ทำหน้าที่ปฏิเสธ Request Body ที่มีขนาดเกินกว่าที่ระบบอนุญาต ซึ่งทำหน้าที่เป็นปราการด่านแรกในการป้องกันการโจมตีแบบ Denial-of-Service (DoS) จากการที่ผู้ไม่หวังดีส่งเพย์โหลดขนาดใหญ่เกินไปเข้ามาบั่นทอนทรัพยากรของเซิร์ฟเวอร์

**CorsLayer** ทำหน้าที่จัดการ Headers ที่เกี่ยวข้องกับ Cross-Origin Resource Sharing (CORS) แม้ตำแหน่งที่แน่นอนในสแตกจะไม่เคร่งครัดเท่าตัวอื่นๆ แต่จำเป็นต้องนำไปผูกไว้กับทุกเส้นทางที่ให้บริการ API

## การตั้งค่า CORS

เรื่อง CORS สมควรที่จะแยกอธิบายเป็นหัวข้อเฉพาะ เพราะการตั้งค่า CORS ผิดพลาดคือหนึ่งในปัญหาที่ชวนปวดหัวที่สุดสำหรับนักพัฒนาเว็บ คุณคงคุ้นเคยกับอาการนี้ดี: การส่งคำขอผ่าน Postman ทำงานได้ราบรื่นสมบูรณ์ แต่กลับพังอย่างลึกลับเมื่อเรียกผ่านเว็บเบราว์เซอร์ และในทางตรงกันข้าม การเปิดอนุญาตทุก Origin อย่างหละหลวมบน Production ก็ถือเป็นช่องโหว่ด้านความปลอดภัยร้ายแรง

```rust
use tower_http::cors::CorsLayer;
use http::{Method, header};

fn cors_layer(config: &Config) -> CorsLayer {
    if config.environment == Environment::Development {
        CorsLayer::permissive()
    } else {
        let origins: Vec<HeaderValue> = config.cors_origins
            .iter()
            .map(|o| o.parse().expect("invalid CORS origin in config"))
            .collect();

        CorsLayer::new()
            .allow_origin(origins)
            .allow_methods([
                Method::GET,
                Method::POST,
                Method::PUT,
                Method::DELETE,
            ])
            .allow_headers([
                header::CONTENT_TYPE,
                header::AUTHORIZATION,
            ])
            .allow_credentials(true)
    }
}
```

มีประเด็นสำคัญจุดหนึ่งที่ผมอยากเน้นย้ำ: เราควรกำหนดนโยบาย CORS จากค่าคอนฟิก ณ เวลารันไทม์เสมอ ไม่ใช่กำหนดตามบิลด์โปรไฟล์ของคอมไพเลอร์ การใช้เงื่อนไขอย่าง `cfg!(debug_assertions)` ในจุดนี้ถือว่าไม่ถูกต้อง เพราะในความเป็นจริง ไบนารีที่เป็น Release Build ที่ถูกนำไปดีพลอยต์บนสภาพแวดล้อม Staging ก็อาจยังต้องการนโยบาย CORS ที่ผ่อนปรน ในขณะที่ Debug Build ที่ใช้รันทดสอบเทียบกับข้อมูล Production ก็ควรต้องใช้นโยบายที่เข้มงวด ข้อมูลสภาพแวดล้อมและรายชื่อ Origin ที่ได้รับอนุญาตจึงควรมาจาก struct `Config` ที่เราสร้างขึ้นในบท [การตั้งค่า](./configuration.md)

## การเขียนมิดเดิลแวร์เองด้วย `from_fn`

ในหลายๆ กรณี คุณอาจไม่จำเป็นต้องสร้างมิดเดิลแวร์ที่ซับซ้อนเพื่อนำไปแชร์ข้ามหลายๆ โปรเจกต์ แต่เพียงแค่ต้องการตรรกะบางอย่างให้ทำงานกับคำขอในแอปพลิเคชันนี้เท่านั้น สำหรับโจทย์ดังกล่าว Axum มีฟังก์ชัน `middleware::from_fn` ที่ช่วยให้คุณสามารถเขียนมิดเดิลแวร์ขึ้นมาเป็นฟังก์ชัน async ธรรมดาๆ ได้ทันที ซึ่งง่ายกว่าการเขียนอิมพลีเมนต์เทรต `Layer` และ `Service` ของ Tower แบบเต็มรูปแบบมาก และจากประสบการณ์ของผม วิธีนี้ครอบคลุมความต้องการมิดเดิลแวร์ที่สร้างขึ้นเองได้เกือบทั้งหมด

```rust
use axum::{
    extract::Request,
    middleware::Next,
    response::Response,
};

async fn timing_middleware(req: Request, next: Next) -> Response {
    let start = std::time::Instant::now();
    let method = req.method().clone();
    let uri = req.uri().clone();

    let response = next.run(req).await;

    let duration = start.elapsed();
    tracing::info!(
        method = %method,
        uri = %uri,
        status = %response.status(),
        duration_ms = %duration.as_millis(),
        "request completed"
    );

    response
}
```

การนำมิดเดิลแวร์นี้ไปผูกกับเราเตอร์ของคุณก็ทำได้อย่างตรงไปตรงมา:

```rust
use axum::middleware;

let app = Router::new()
    .merge(api_routes())
    .layer(middleware::from_fn(timing_middleware))
    .with_state(state);
```

แต่หากมิดเดิลแวร์ของคุณจำเป็นต้องเข้าถึง State ของแอปพลิเคชันด้วยล่ะ เช่น ต้องการดึง JWT Secret ออกมาใช้ในการตรวจสอบยืนยันตัวตน? นั่นคือจังหวะที่ฟังก์ชัน `from_fn_with_state` จะเข้ามาช่วย:

```rust
async fn auth_middleware(
    State(state): State<AppState>,
    mut req: Request,
    next: Next,
) -> Result<Response, AppError> {
    let token = req.headers()
        .get(header::AUTHORIZATION)
        .and_then(|v| v.to_str().ok())
        .and_then(|v| v.strip_prefix("Bearer "))
        .ok_or(AppError::Unauthorized)?;

    let claims = decode_jwt(token, state.config.jwt_secret.expose_secret())
        .map_err(|_| AppError::Unauthorized)?;

    // Store the authenticated user in request extensions so handlers can access it
    req.extensions_mut().insert(AuthUser::from(claims));

    Ok(next.run(req).await)
}

// Apply to specific routes
let protected_routes = Router::new()
    .route("/profile", get(get_profile))
    .route("/settings", put(update_settings))
    .route_layer(middleware::from_fn_with_state(state.clone(), auth_middleware));
```

## `route_layer` เทียบกับ `layer`

ความแตกต่างตรงนี้เป็นจุดที่หลายคนมักพลาดบ่อยมาก และมันส่งผลต่อความถูกต้องของการทำงานโดยตรง

**`.layer()`** จะครอบมิดเดิลแวร์กับทุกเส้นทางบนเราเตอร์ รวมถึง fallback handler สำหรับ path ที่ไม่ตรงกับ route ใดๆ ด้วย หากคุณใส่ middleware ยืนยันตัวตนไว้ตรงนี้ แม้แต่การตอบกลับ 404 สำหรับ path ที่ไม่มีอยู่จริงก็ยังต้องผ่านการยืนยันตัวตนก่อน ซึ่งแทบไม่เคยเป็นสิ่งที่คุณต้องการ และจะทำให้เกิดพฤติกรรมที่ชวนสับสนตรงที่ผู้ใช้ที่ยังไม่ได้ยืนยันตัวตนจะได้รับ 401 แทนที่จะเป็น 404 เมื่อเรียก path ที่ไม่มีอยู่จริง

**`.route_layer()`** จะครอบมิดเดิลแวร์เฉพาะกับเส้นทางที่จับคู่ route ได้สำเร็จเท่านั้น ส่วน path ที่ไม่ตรงกับ route ใดๆ จะส่งต่อไปยัง fallback handler โดยไม่ผ่าน middleware นี้เลย ซึ่งนี่คือสิ่งที่คุณต้องการสำหรับการยืนยันตัวตน (Authentication) และการตรวจสอบสิทธิ์ (Authorization)

```rust
let app = Router::new()
    // Public routes
    .route("/health", get(health_check))
    .route("/api/v1/auth/login", post(login))
    // Protected routes
    .nest("/api/v1", protected_routes)
    // Global middleware (applied to everything)
    .layer(TraceLayer::new_for_http())
    .with_state(state);

let protected_routes = Router::new()
    .nest("/users", user_routes())
    .nest("/posts", post_routes())
    // Auth middleware only applies to matched routes
    .route_layer(middleware::from_fn_with_state(state, auth_middleware));
```

## เครตมิดเดิลแวร์ที่มีให้ใช้

ก่อนที่คุณจะเริ่มลงมือเขียน middleware ขึ้นมาเอง แนะนำให้ลองเช็กดูก่อนว่ามีคนแก้ปัญหานี้ไว้แล้วหรือยัง เพราะ ecosystem ของ Tower และ tower-http นั้นมีเครื่องมือให้ใช้อย่างครบครันมาก:

- **tower-http** มี `CorsLayer`, `CompressionLayer`, `TraceLayer`, `TimeoutLayer`, `RequestBodyLimitLayer`, `SetRequestIdLayer` และอื่นๆ อีกมากมาย
- **tower-governor** รองรับ rate limiting โดยอิงตามอัลกอริทึม governor
- **tower-sessions** จัดการ session ฝั่งเซิร์ฟเวอร์
- **tower-cookies** จัดการ cookie
- **axum-csrf-sync-pattern** อิมพลีเมนต์ OWASP CSRF Synchronizer Token Pattern

จากประสบการณ์ของผม ระบบนิเวศ Tower ครอบคลุมสิ่งที่จำเป็นต่อการใช้งานส่วนใหญ่แบบพร้อมใช้ทันที ซึ่งนี่เป็นหนึ่งในเหตุผลที่ดีที่สุดในการเลือกใช้ Axum ตั้งแต่แรก เมื่อเราไปถึงบท [การรวมทุกอย่างเข้าด้วยกัน](./putting-it-together.md) คุณจะได้เห็นว่ามิดเดิลแวร์ทุกเลเยอร์เหล่านี้ประกอบเข้าด้วยกันในแอปพลิเคชันที่สมบูรณ์ได้อย่างไร
