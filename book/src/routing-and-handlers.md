# การกำหนดเส้นทางและแฮนด์เลอร์

คำขอ HTTP ทุกคำขอที่เข้ามาถึงแอปพลิเคชันของคุณต้องมีที่ลงจอด และใน Axum ที่ที่ว่านั้นคือแฮนด์เลอร์ แฮนด์เลอร์ก็แค่ฟังก์ชัน async ที่รับตัวแยกข้อมูล (extractor) ศูนย์ตัวหรือมากกว่าเป็นอาร์กิวเมนต์ แล้วส่งคืนอะไรก็ตามที่อิมพลีเมนต์ `IntoResponse` Axum จัดการงานระบบท่อให้คุณเอง: มันดีซีเรียลไลซ์ข้อมูลของคำขอให้เป็นชนิดข้อมูลของตัวแยกข้อมูล และซีเรียลไลซ์ค่าที่คุณส่งคืนกลับไปเป็นการตอบกลับ HTTP

สิ่งแรกที่ผมอยากให้คุณเก็บติดตัวตั้งแต่หัวบทคือ แฮนด์เลอร์ควรบาง หน้าที่ของมันคือดึงข้อมูลออกจากคำขอ ส่งต่อให้เซอร์วิสหรือรีพอสิทอรี แล้วเปลี่ยนผลลัพธ์ให้เป็นการตอบกลับ ถ้าคุณพบว่าตัวเองกำลังเขียนตรรกะทางธุรกิจ ควิวรีฐานข้อมูล หรือการแตกกิ่งเงื่อนไขที่ซับซ้อนไว้ในแฮนด์เลอร์ โค้ดชิ้นนั้นควรอยู่ที่อื่น เราจะพูดกันว่าต้องอยู่ตรงไหนแน่ๆ ในบทว่าด้วยโดเมนและอินฟราสตรักเจอร์ แต่ตอนนี้ขอแค่จำไว้ว่า: แฮนด์เลอร์บางเสมอ

## การนิยามเส้นทาง

เราเตอร์ของ Axum ใช้การเรียกเมธอดต่อเนื่องกันแบบลูกโซ่ (method chaining) ซึ่งพอดูไปสองสามครั้งก็รู้สึกเป็นธรรมชาติมาก คุณนิยามเส้นทางทีละเส้นด้วย `.route()` จัดกลุ่มเส้นทางที่เกี่ยวข้องกันไว้ใต้คำนำหน้าร่วมด้วย `.nest()` และรวมกลุ่มเส้นทางที่แยกจากกันเข้าด้วยกันด้วย `.merge()`

```rust
use axum::{routing::{get, post, put, delete}, Router};

pub fn router(state: AppState) -> Router {
    Router::new()
        .nest("/api/v1", api_routes())
        .route("/health", get(health_check))
        .route("/health/ready", get(readiness_check))
        .with_state(state)
}

fn api_routes() -> Router<AppState> {
    Router::new()
        .nest("/users", user_routes())
        .nest("/posts", post_routes())
}

fn user_routes() -> Router<AppState> {
    Router::new()
        .route("/", get(list_users).post(create_user))
        .route("/{id}", get(get_user).patch(update_user).delete(delete_user))
}

fn post_routes() -> Router<AppState> {
    Router::new()
        .route("/", get(list_posts).post(create_post))
        .route("/{id}", get(get_post).patch(update_post).delete(delete_post))
}
```

ผมชอบแยกเส้นทางออกเป็นฟังก์ชันต่างหาก (หรือจะแยกไฟล์เลยก็ได้) เพราะมันทำให้คำนิยามเราเตอร์อ่านง่ายเมื่อแอปพลิเคชันของคุณโตขึ้น แต่ละฟังก์ชันคืนค่า `Router<AppState>` และเราเตอร์หลักประกอบพวกมันเข้าด้วยกัน นี่คือจุดที่คุณจะติดมิดเดิลแวร์เฉพาะเส้นทาง ซึ่งเราจะกล่าวถึงในบท [มิดเดิลแวร์](./middleware.md)

## การเขียนแฮนด์เลอร์

แล้วแฮนด์เลอร์ที่มีโครงสร้างดีจริงๆ หน้าตาเป็นอย่างไร? จากประสบการณ์ของผม พวกมันเดินตามจังหวะเดียวกันหมด: แยกข้อมูลออกมา มอบงานต่อ แล้วตอบกลับ

```rust
use axum::{extract::{State, Path}, http::StatusCode, Json};

async fn create_user(
    State(state): State<AppState>,
    ValidatedJson(payload): ValidatedJson<CreateUserDto>,
) -> AppResult<(StatusCode, Json<UserResponse>)> {
    let name = UserName::parse(&payload.name)
        .map_err(|e| AppError::Validation(e.to_string()))?;
    let email = Email::parse(&payload.email)
        .map_err(|e| AppError::Validation(e.to_string()))?;

    let user = state.user_service
        .register(name, email, &payload.password)
        .await?;

    Ok((StatusCode::CREATED, Json(user.into())))
}

async fn get_user(
    State(state): State<AppState>,
    Path(id): Path<Uuid>,
) -> AppResult<Json<UserResponse>> {
    let user = state.user_service
        .get_by_id(UserId::from_uuid(id))
        .await?
        .ok_or(AppError::NotFound)?;

    Ok(Json(user.into()))
}

async fn list_users(
    State(state): State<AppState>,
    Query(pagination): Query<PaginationParams>,
) -> AppResult<Json<PaginatedResponse<UserResponse>>> {
    let (users, total) = state.user_service
        .list(pagination.page, pagination.per_page)
        .await?;

    let response = PaginatedResponse {
        data: users.into_iter().map(Into::into).collect(),
        meta: PaginationMeta {
            page: pagination.page,
            per_page: pagination.per_page,
            total,
            total_pages: (total as f64 / pagination.per_page as f64).ceil() as u32,
        },
    };

    Ok(Json(response))
}

async fn delete_user(
    State(state): State<AppState>,
    Path(id): Path<Uuid>,
) -> AppResult<StatusCode> {
    state.user_service
        .delete(UserId::from_uuid(id))
        .await?;

    Ok(StatusCode::NO_CONTENT)
}
```

ลองดูข้อตกลงที่ใช้ตรงนี้ เมื่อเราสร้างอะไรสำเร็จ เราคืน `StatusCode::CREATED` (201) พร้อมทรัพยากรที่สร้างใหม่ในบอดี้ การลบที่สำเร็จคืน `StatusCode::NO_CONTENT` (204) โดยไม่มีบอดี้ เพราะไม่มีอะไรเหลือให้แสดง และเมื่อการค้นหาไม่พบอะไร เราคืน `AppError::NotFound` ซึ่งอิมพลีเมนเทชัน `IntoResponse` ของเราบน `AppError` จะเปลี่ยนมันให้เป็นการตอบกลับ 404 ที่สมบูรณ์ คุณอาจสังเกตว่าแฮนด์เลอร์แต่ละตัวทำงานน้อยแค่ไหน นั่นคือเป้าหมาย

## ตัวแยกข้อมูล (Extractors)

ตัวแยกข้อมูล (extractor) คือวิธีที่ Axum ดึงข้อมูลออกจากคำขอขาเข้าให้คุณ ภายใต้ฝา พวกมันอิมพลีเมนต์ `FromRequest` (ถ้าต้องบริโภคบอดี้คำขอ) หรือ `FromRequestParts` (ถ้าต้องการแค่ส่วนหัว พารามิเตอร์ควิวรี เซ็กเมนต์ของพาธ หรือเมทาดาทาอื่นๆ โดยไม่แตะบอดี้)

ตัวแยกข้อมูลที่สร้างไว้ในตัวครอบคลุมสิ่งที่คุณต้องใช้ในชีวิตประจำวันส่วนใหญ่:

```rust
use axum::extract::{State, Path, Query, Json};

// Path parameters: /users/{id}
async fn get_user(Path(id): Path<Uuid>) -> ... { }

// Query parameters: /users?page=2&per_page=20
async fn list_users(Query(params): Query<PaginationParams>) -> ... { }

// JSON body
async fn create_user(Json(body): Json<CreateUserDto>) -> ... { }

// Application state
async fn handler(State(state): State<AppState>) -> ... { }
```

คุณใช้ตัวแยกข้อมูลหลายตัวในแฮนด์เลอร์เดียวกันได้แน่นอน ข้อจำกัดเดียวที่ต้องจำไว้คือ ตัวแยกข้อมูลที่บริโภคบอดี้ของคำขอมีได้อย่างมากหนึ่งตัว (เช่น `Json`) และมันต้องอยู่ท้ายสุดของลิสต์อาร์กิวเมนต์ ถ้าคุณสลับลำดับผิด คอมไพเลอร์จะเตือนคุณเอง

## มาโคร `#[debug_handler]`

ถ้าคุณเคยมีแฮนด์เลอร์ที่คอมไพล์ไม่ผ่านเพราะข้อผิดพลาดเรื่องเทรตบาวด์ คุณจะรู้ว่ามันเจ็บปวดแค่ไหน ข้อความข้อผิดพลาดจากคอมไพเลอร์ Rust ในบริบทนี้มืดมนจริงๆ และผมเสียเวลาจ้องมันมากเกินกว่าจะยอมรับ Axum มีมาโคร `#[debug_handler]` ที่ทำให้ทุกอย่างชัดเจนขึ้นมาก:

```rust
#[axum::debug_handler]
async fn my_handler(
    State(state): State<AppState>,
    Json(body): Json<CreateUserDto>,
) -> AppResult<Json<UserResponse>> {
    // ...
}
```

สิ่งที่มันทำคือเพิ่มการตรวจสอบชนิดข้อมูลพิเศษที่ให้ข้อความข้อผิดพลาดที่มนุษย์อ่านเข้าใจ เช่น "argument #2 must implement FromRequest" แทนที่จะเป็นกำแพงของความล้มเหลวเรื่องเทรตบาวด์ มันไม่มีค่าใช้จ่ายตอนรันไทม์ คุณจะปล่อยมันไว้ใน production ก็ได้ถ้าต้องการ บางทีมชอบลบมันออกเมื่อแฮนด์เลอร์คอมไพล์ผ่านแล้ว แต่พูดตรงๆ ผมไม่ใส่ใจ เรื่องนี้เป็นหนึ่งในสิ่งเล็กๆ ที่ช่วยประหยัดเวลาจริงๆ เมื่อคุณกลับมาแก้แฮนด์เลอร์อีกครั้งในอีกหกเดือนต่อมา

## ชนิดข้อมูลการตอบกลับ

Axum ค่อนข้างยืดหยุ่นเรื่องที่แฮนด์เลอร์ของคุณจะคืนกลับได้ อะไรก็ตามที่อิมพลีเมนต์ `IntoResponse` ใช้ได้ และก็มีอิมพลีเมนเทชันในตัวอยู่ไม่น้อย นี่คือแพตเทิร์นที่ผมใช้บ่อยที่สุด:

```rust
// Just a status code
async fn health_check() -> StatusCode {
    StatusCode::OK
}

// A tuple of status code and body
async fn create_resource() -> (StatusCode, Json<Resource>) {
    (StatusCode::CREATED, Json(resource))
}

// A Result for fallible operations
async fn get_resource() -> Result<Json<Resource>, AppError> {
    Ok(Json(resource))
}

// Headers and body together
async fn with_headers() -> (StatusCode, [(HeaderName, &'static str); 1], Json<Data>) {
    (
        StatusCode::OK,
        [(header::CACHE_CONTROL, "max-age=3600")],
        Json(data),
    )
}
```

ในทางปฏิบัติ คุณจะใช้ชนิดข้อมูลผลตอบกลับ `Result` เกือบตลอด เพราะแฮนด์เลอร์ส่วนใหญ่ล้มเหลวได้ไม่ทางใดก็ทางหนึ่ง การใช้ `Result<T, AppError>` ให้การแปลงข้อผิดพลาดที่สะอาดซึ่งเราจะสร้างกันในบท [การจัดการข้อผิดพลาด](./error-handling.md) และมันทำให้โค้ดแฮนด์เลอร์ของคุณจดจ่ออยู่กับเส้นทางแห่งความสำเร็จ (happy path)

## การทำให้แฮนด์เลอร์บาง

ผมรู้ว่ากล่าวถึงไปแล้ว แต่มันคุ้มค่าที่จะย้ำ เพราะผมเห็นเรื่องนี้พลาดมาแล้วหลายครั้งในหลายภาษาและหลายเฟรมเวิร์ก เมื่อแฮนด์เลอร์เริ่มยาวเกิน 15 หรือ 20 บรรทัด นั่นมักเป็นสัญญาณว่าตรรกะคืบคลานเข้ามาอยู่ผิดที่

อะไรที่ควรอยู่ในแฮนด์เลอร์:
- การดึงข้อมูลจากคำขอ (ผ่านตัวแยกข้อมูลของ Axum)
- การแปลงอินพุตดิบให้เป็นชนิดข้อมูลโดเมน (เรียก `UserName::parse()`, `Email::parse()` ฯลฯ)
- การเรียกเมธอดของเซอร์วิสเพียงหนึ่งเมธอด
- การเปลี่ยนผลลัพธ์ให้เป็นการตอบกลับ HTTP

อะไรที่ไม่ควรอยู่ในแฮนด์เลอร์:
- ควิวรีฐานข้อมูล
- การบังคับใช้กฎทางธุรกิจ
- การเรียกเซอร์วิสหลายตัวที่ต้องประสานงานกัน
- ตรรกะเงื่อนไขที่ซับซ้อน
- การส่งอีเมล การเผยแพร่อีเวนต์ หรือไซด์เอฟเฟกต์อื่นๆ

ถ้าแฮนด์เลอร์ของคุณต้องทำหลายสิ่งแบบประสานงานกัน ตรรกะการประสานงานนั้นควรอยู่ในเมธอดของเซอร์วิส เราจะดูวิธีจัดโครงสร้างเซอร์วิสพวกนั้นในบทถัดไป
