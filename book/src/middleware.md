# มิดเดิลแวร์

เว็บแอปพลิเคชันทุกตัวลงเอยด้วยตรรกะกลุ่มหนึ่งที่ไม่ใช่งานของแฮนด์เลอร์ตัวใดตัวหนึ่ง แต่ต้องทำงานบนคำขอหลายคำขอ (หรือทุกคำขอ) การบันทึกข้อมูล การยืนยันตัวตน การบีบอัด การจำกัดอัตราการเรียก ไอดีของคำขอ การหมดเวลา คุณรู้จักลิสต์นี้ดี ใน Axum เราจัดการทั้งหมดนี้ผ่านมิดเดิลแวร์ และเพราะระบบมิดเดิลแวร์ของ Axum สร้างอยู่บน Tower เราจึงเข้าถึงระบบนิเวศขนาดใหญ่ของคอมโพเนนต์สำเร็จรูป พร้อมทั้งวิธีที่สะอาดในการประกอบมิดเดิลแวร์ของเราเอง

สิ่งที่ทำให้คนสะดุดบ่อยที่สุดไม่ใช่การเขียนมิดเดิลแวร์ แต่คือการเรียงลำดับให้ถูกต้อง เริ่มจากตรงนั้นกันก่อน

## โมเดลเลเยอร์ของ Tower

Tower มองมิดเดิลแวร์เป็น "เลเยอร์" ที่ห่อหุ้มเซอร์วิส เมื่อคำขอเข้ามา มันจะผ่านแต่ละเลเยอร์ตามลำดับ จากชั้นนอกสุดไปยังชั้นในสุด (ซึ่งก็คือแฮนด์เลอร์ของคุณ) จากนั้นการตอบกลับก็เดินทางย้อนกลับออกไปผ่านเลเยอร์ในลำดับกลับกัน ดังนั้นเลเยอร์แรกที่คุณเพิ่มคือตัวแรกที่เห็นคำขอ และตัวสุดท้ายที่เห็นการตอบกลับ

```
Request → Compression → Tracing → Timeout → Auth → Handler
Response ← Compression ← Tracing ← Timeout ← Auth ← Handler
```

การเรียงลำดับนี้สำคัญเกินกว่าที่คุณคาดคิด ถ้าคุณต้องการให้ tracing บันทึกว่าคำขอทั้งหมดใช้เวลาเท่าใด รวมถึงเวลาที่ใช้ในการยืนยันตัวตน เลเยอร์ tracing ต้องอยู่ด้านนอกเลเยอร์ auth ถ้าเรียงสลับกัน ข้อมูลเวลาของคุณจะผิดเพี้ยนไปในแบบที่ละเอียดอ่อนจนน่ารำคาญเวลาดีบัก

## สแตกมิดเดิลแวร์ที่แนะนำ

มาดูสแตกมิดเดิลแวร์ที่ผมจะหยิบใช้ในแอปพลิเคชัน production ซึ่งสร้างด้วย `ServiceBuilder`:

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

มาดูกันทีละเลเยอร์ว่ามันทำอะไร และทำไมมันถึงอยู่ตำแหน่งนั้น

**CompressionLayer** บีบอัดบอดี้ของการตอบกลับด้วย gzip (หรือ brotli หรือ deflate ขึ้นอยู่กับว่าไคลเอนต์รองรับแบบไหน) และตั้งส่วนหัว `Content-Encoding` เราใส่ไว้ตำแหน่งนอกสุดเพื่อให้มันบีบอัดบอดี้การตอบกลับสุดท้าย หลังจากเลเยอร์ชั้นในทั้งหมดผลิตมันเสร็จเรียบร้อย ข้อควรสังเกต: การบีบอัดใช้กับบอดี้เท่านั้น ไม่รวมส่วนหัว HTTP

**SetRequestIdLayer** สร้าง UUID เฉพาะตัวแล้วติดเข้ากับคำขอขาเข้า เราวางมันก่อน `TraceLayer` เพื่อให้ไอดีของคำขอพร้อมใช้งานอยู่แล้วตอนที่สแปนของ tracing ถูกสร้างขึ้น

**TraceLayer** บันทึกรายการล็อกแบบมีโครงสร้างสำหรับแต่ละคำขอ ทั้งเมธอด พาธ รหัสสถานะ และระยะเวลา เพราะมันทำงานหลังจากตั้งค่าไอดีคำขอแล้ว สแปน tracing ของเราจึงมีไอดีคำขอรวมอยู่ด้วย ซึ่งมีประโยชน์อย่างยิ่งเวลาคุณย้อนขุดดูบันทึกข้อมูลทีหลัง

**PropagateRequestIdLayer** คัดลอกไอดีคำขอลงบนการตอบกลับขาออก มันอยู่หลัง `TraceLayer` เพื่อให้ส่วนหัวของการตอบกลับถูกตั้งค่า ก่อนที่ tracing จะปิดท้ายฝั่งการตอบกลับของสแปน การเรียงลำดับนี้ (ตั้งค่า แล้วก็ tracing แล้วค่อย propagate) เป็นไปตามเอกสารของ tower-http เอง และทำให้ไอดีคำขอปรากฏอย่างสม่ำเสมอทั้งในล็อกของคำขอและส่วนหัวของการตอบกลับ

**TimeoutLayer** ยกเลิกคำขอที่ใช้เวลานานเกินระยะเวลาที่กำหนด นี่คือการป้องกันไคลเอนต์ที่ช้า ควิวรีที่หลุดการควบคุม และสถานการณ์อื่นๆ ที่คำขอค้างอยู่อย่างนั้นตลอดไป

**RequestBodyLimitLayer** ปฏิเสธบอดี้ของคำขอที่เกินขีดจำกัดขนาด มันคือแนวป้องกันพื้นฐานต่อการโจมตีแบบ denial-of-service ที่ไคลเอนต์ส่งเพย์โหลดขนาดมหึมา

**CorsLayer** จัดการส่วนหัว Cross-Origin Resource Sharing ตำแหน่งที่แม่นยำของมันในสแตกสำคัญน้อยกว่าตัวอื่น แต่ต้องถูกใช้กับเส้นทางที่ให้บริการ API ของคุณ

## การตั้งค่า CORS

CORS สมควรได้ส่วนของตัวเอง เพราะการตั้งค่ามันผิดคือหนึ่งในสิ่งที่ทำให้คุณควักหัวตัวเอง คุณรู้จักอาการดี: คำขอทำงานสมบูรณ์จาก Postman แต่ล้มเหลวอย่างลึกลับเมื่อเรียกจากเบราว์เซอร์ และในอีกด้าน การอนุญาตทุก origin ใน production คือรูโหว่ด้านความปลอดภัยตัวจริง

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

มีสิ่งหนึ่งที่ผมอยากชี้ให้เห็น: เราขับนโยบาย CORS จากการตั้งค่าตอนรันไทม์ ไม่ใช่จากโปรไฟล์การบิลด์ การใช้ `cfg!(debug_assertions)` ตรงนี้จะผิด ลองคิดดู: บิลด์ release ที่ดีพลอยต์ไปสภาพแวดล้อม staging ควรยังมี CORS แบบผ่อนปรน และบิลด์ debug ที่รันกับข้อมูล production ก็ควรยังเข้มงวด สภาพแวดล้อมและ origins ที่อนุญาตมาจาก struct `Config` ที่เราสร้างไว้ในบท [การตั้งค่า](./configuration.md)

## การเขียนมิดเดิลแวร์เองด้วย `from_fn`

ส่วนใหญ่แล้ว คุณไม่จำเป็นต้องมีมิดเดิลแวร์ที่ใช้ซ้ำข้ามโปรเจกต์ คุณแค่ต้องการอะไรสักอย่างที่รันบนคำขอในแอปพลิเคชันนี้ สำหรับกรณีนั้น Axum ให้ `middleware::from_fn` มา ซึ่งให้คุณเขียนมิดเดิลแวร์เป็นฟังก์ชัน async ธรรมดาๆ ได้ มันง่ายกว่าการอิมพลีเมนต์เทรต `Layer` และ `Service` ของ Tower แบบเต็มรูปแบบมาก และจากประสบการณ์ของผม มันครอบคลุมความต้องการมิดเดิลแวร์ที่เขียนเองส่วนใหญ่

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

การนำไปใช้กับเราเตอร์ของคุณตรงไปตรงมา:

```rust
use axum::middleware;

let app = Router::new()
    .merge(api_routes())
    .layer(middleware::from_fn(timing_middleware))
    .with_state(state);
```

แต่ถ้ามิดเดิลแวร์ของคุณต้องเข้าถึงสถานะของแอปพลิเคชันล่ะ เช่น เพื่อดึงความลับ JWT มาใช้ยืนยันตัวตน? นั่นคือจุดที่ `from_fn_with_state` เข้ามา:

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

ความแตกต่างนี้ทำให้คนสะดุดจำนวนมาก และมันสำคัญต่อความถูกต้องจริงๆ

**`.layer()`** ใช้มิดเดิลแวร์กับทุกเส้นทางบนเราเตอร์ รวมถึงแฮนด์เลอร์ fallback สำหรับพาธที่ไม่ตรงกับเส้นทางใด ถ้าคุณวางเลเยอร์การยืนยันตัวตนไว้ตรงนี้ แม้แต่การตอบกลับ 404 สำหรับพาธที่ไม่มีอยู่ก็จะต้องผ่านการยืนยันตัวตนด้วย นั่นมักไม่ใช่สิ่งที่คุณต้องการ และมันนำไปสู่พฤติกรรมที่ชวนสับสนตรงที่ผู้ใช้ที่ไม่ได้ยืนยันตัวตนจะได้รับ 401 แทนที่จะเป็น 404 สำหรับพาธที่ไม่มีอยู่จริง

**`.route_layer()`** ใช้มิดเดิลแวร์กับเส้นทางที่ตรงจริงๆ เท่านั้น พาธที่ไม่ตรงกับเส้นทางใดจะผ่านไปยังแฮนด์เลอร์ fallback โดยไม่ชนมิดเดิลแวร์เลย นี่คือสิ่งที่คุณต้องการสำหรับการยืนยันตัวตนและการอนุญาตสิทธิ์

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

## ครีตมิดเดิลแวร์ที่มีให้ใช้

ก่อนที่คุณจะเขียนมิดเดิลแวร์เอง คุ้มที่จะเช็กก่อนว่ามีคนแก้ปัญหาของคุณไปแล้วหรือยัง ระบบนิเวศของ Tower และ tower-http อุดมสมบูรณ์อย่างน่าประหลาดใจ:

- **tower-http** มี `CorsLayer`, `CompressionLayer`, `TraceLayer`, `TimeoutLayer`, `RequestBodyLimitLayer`, `SetRequestIdLayer` และอื่นๆ อีกมากมาย
- **tower-governor** ให้การจำกัดอัตราการเรียกโดยอิงอัลกอริทึม governor
- **tower-sessions** จัดการเซสชันฝั่งเซิร์ฟเวอร์
- **tower-cookies** ให้การจัดการคุกกี้
- **axum-csrf-sync-pattern** อิมพลีเมนต์ OWASP CSRF Synchronizer Token Pattern

จากประสบการณ์ของผม ระบบนิเวศ Tower ครอบคลุมสิ่งที่คุณต้องใช้ส่วนใหญ่แบบใช้ได้ทันที มันเป็นหนึ่งในเหตุผลที่ดีที่สุดในการเลือกใช้ Axum ตั้งแต่แรก เมื่อเราไปถึงบท [การรวมทุกอย่างเข้าด้วยกัน](./putting-it-together.md) คุณจะเห็นว่ามิดเดิลแวร์ทุกเลเยอร์เหล่านี้ประกอบเข้าด้วยกันในแอปพลิเคชันที่สมบูรณ์ได้อย่างไร
