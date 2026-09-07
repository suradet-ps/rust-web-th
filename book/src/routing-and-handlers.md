# การกำหนดเส้นทางและแฮนด์เลอร์

คำขอ HTTP ทุกคำขอที่ส่งเข้ามายังแอปพลิเคชันของคุณจำเป็นต้องมีปลายทางสำหรับประมวลผล และใน Axum ปลายทางที่ว่านั้นก็คือ 'แฮนด์เลอร์ (Handler)' แฮนด์เลอร์เป็นเพียงฟังก์ชัน asynchronous ธรรมดาที่รับตัวแยกข้อมูล (extractor) ตั้งแต่ศูนย์ตัวขึ้นไปเป็นพารามิเตอร์ แล้วส่งคืนค่าชนิดใดก็ตามที่ implement เทรต `IntoResponse` โดย Axum จะคอยจัดการงานเบื้องหลัง (plumbing) ให้ทั้งหมด ไม่ว่าจะเป็นการ Deserialize ข้อมูลจากคำขอเข้ามาเป็นชนิดข้อมูลของ extractor และ Serialize ค่าที่ส่งคืนกลับออกไปเป็น HTTP Response

หลักการสำคัญประการแรกที่ผมอยากให้คุณยึดมั่นไว้ตั้งแต่ต้นบทคือ: **แฮนด์เลอร์ต้องบาง (Thin Handlers)** หน้าที่ของแฮนด์เลอร์มีเพียงการดึงข้อมูลออกจากคำขอ, ส่งต่องานไปให้เซอร์วิสหรือรีพอสิทอรี และแปลงผลลัพธ์ที่ได้ให้อยู่ในรูปของการตอบกลับ HTTP หากคุณพบว่าตัวเองเริ่มเขียน Business Logic, รันคิวรีฐานข้อมูล หรือมีเงื่อนไขแตกกิ่งซับซ้อนอยู่ภายในแฮนด์เลอร์ นั่นคือสัญญาณว่าโค้ดเหล่านั้นกำลังอยู่ผิดที่ผิดทาง เราจะมาคุยกันอย่างละเอียดว่าโค้ดแต่ละส่วนควรไปอยู่ที่ใดในบทว่าด้วยโดเมนและอินฟราสตรักเจอร์ แต่สำหรับตอนนี้ ขอให้จำกฎข้อนี้ไว้เสมอ: *แฮนด์เลอร์ต้องบางเสมอ*

## การนิยามเส้นทาง

เราเตอร์ (Router) ของ Axum ใช้รูปแบบการต่อเมธอดเป็นลูกโซ่ (Method Chaining) ซึ่งเมื่อใช้งานไปสักพักจะรู้สึกเป็นธรรมชาติและอ่านเข้าใจได้ง่ายมาก คุณสามารถกำหนดเส้นทางทีละเส้นด้วย `.route()`, จัดกลุ่มเส้นทางที่เกี่ยวข้องกันไว้ภายใต้ URL Prefix เดียวกันด้วย `.nest()` และผสานเราเตอร์หลายๆ ตัวเข้าด้วยกันด้วย `.merge()`

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

ผมชอบแยกคำนิยามของเส้นทางออกเป็นฟังก์ชันเฉพาะ (หรือแยกออกเป็นไฟล์ย่อยๆ เลย) เพราะจะช่วยให้เราเตอร์อ่านง่ายและเป็นระเบียบเมื่อแอปพลิเคชันเริ่มขยายตัวขึ้น โดยแต่ละฟังก์ชันจะคืนค่าเป็น `Router<AppState>` แล้วให้เราเตอร์หลักนำพวกมันมาประกอบรวมกัน และจุดนี้เองก็เป็นตำแหน่งที่คุณสามารถผูกมิดเดิลแวร์เฉพาะเส้นทางได้ด้วย ซึ่งเราจะไปพูดถึงกันในบท [มิดเดิลแวร์](./middleware.md)

## การเขียนแฮนด์เลอร์

แล้วแฮนด์เลอร์ที่มีโครงสร้างที่ดีจริงๆ มีหน้าตาเป็นอย่างไร? จากประสบการณ์ของผม แฮนด์เลอร์ที่ดีล้วนมีจังหวะการทำงานแบบเดียวกันทั้งสิ้น: ดึงข้อมูลออกมา (extract), ส่งต่องาน (delegate) และส่งการตอบกลับ (respond)

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

ลองสังเกตแบบแผน (conventions) ที่ใช้ในโค้ดชุดนี้: เมื่อสร้างข้อมูลสำเร็จ เราจะส่งคืน `StatusCode::CREATED` (201) พร้อมกับทรัพยากรที่เพิ่งสร้างใหม่ใน Response Body, เมื่อลบข้อมูลสำเร็จ เราจะส่งคืน `StatusCode::NO_CONTENT` (204) โดยไม่มี Body เพราะไม่มีข้อมูลใดต้องแสดงผลอีก และหากค้นหาข้อมูลไม่พบ เราจะส่งคืน `AppError::NotFound` ซึ่งโค้ดการอิมพลีเมนต์ `IntoResponse` บน `AppError` ของเราจะแปลงค่านั้นเป็น HTTP 404 ที่สมบูรณ์ให้โดยอัตโนมัติ คุณจะเห็นได้ว่าแฮนด์เลอร์แต่ละตัวมีโค้ดสั้นและทำงานน้อยมาก ซึ่งนั่นคือเป้าหมายหลักที่เราต้องการ

## ตัวแยกข้อมูล (Extractors)

ตัวแยกข้อมูล (extractor) คือกลไกที่ Axum ใช้เพื่อดึงข้อมูลจากคำขอขาเข้ามาให้กับฟังก์ชันของคุณ เบื้องหลังการทำงาน Extractor จะอิมพลีเมนต์เทรต `FromRequest` (หากต้องอ่านข้อมูลจาก Request Body) หรือเทรต `FromRequestParts` (หากต้องการอ่านเพียง Headers, Query Parameters, Path Parameters หรือ Metadata อื่นๆ โดยไม่แตะต้อง Body)

ตัวแยกข้อมูลที่มาพร้อมกับ Axum ในตัวนั้นครอบคลุมรูปแบบการใช้งานส่วนใหญ่ในชีวิตประจำวันอย่างครบถ้วน:

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

คุณสามารถใส่ตัวแยกข้อมูลหลายตัวในฟังก์ชันแฮนด์เลอร์เดียวกันได้อย่างแน่นอน โดยมีข้อจำกัดสำคัญเพียงข้อเดียวที่ต้องจำไว้คือ: ตัวแยกข้อมูลที่ต้องอ่านข้อมูลจาก Request Body (เช่น `Json`) จะมีได้มากที่สุดเพียงตัวเดียว และต้องวางไว้เป็นพารามิเตอร์ตัวสุดท้ายในรายการเสมอ หากคุณวางลำดับผิด คอมไพเลอร์จะแจ้งเตือนข้อผิดพลาดทันที

## มาโคร `#[debug_handler]`

หากคุณเคยพบปัญหาคอมไพล์ฟังก์ชันแฮนด์เลอร์ไม่ผ่านเนื่องจากติด Trait Bound คุณคงรู้ดีว่ามันชวนปวดหัวขนาดไหน ข้อความ Error จากคอมไพเลอร์ในสถานการณ์นี้มักจะอ่านยากและเข้าใจซับซ้อนมาก และผมเองก็เคยเสียเวลาไปกับการนั่งแกะ Error เหล่านี้มานับไม่ถ้วน แต่ Axum มีแมโคร `#[debug_handler]` ที่จะช่วยให้ทุกอย่างชัดเจนและเข้าใจง่ายขึ้นอย่างมาก:

```rust
#[axum::debug_handler]
async fn my_handler(
    State(state): State<AppState>,
    Json(body): Json<CreateUserDto>,
) -> AppResult<Json<UserResponse>> {
    // ...
}
```

สิ่งที่แมโครนี้ทำคือการเพิ่มการตรวจสอบชนิดข้อมูลแบบเจาะจง ซึ่งจะแสดงข้อความแจ้งเตือนที่มนุษย์อ่านเข้าใจได้ง่าย เช่น "argument #2 must implement FromRequest" แทนที่จะพ่นกำแพงข้อความข้อผิดพลาดของ Trait Bound ออกมาเต็มหน้าจอ แมโครนี้ไม่มีต้นทุนใดๆ ณ เวลารันไทม์ (Zero Runtime Cost) คุณจึงสามารถเปิดทิ้งไว้บน Production ได้โดยไม่มีผลกระทบ แม้บางทีมจะนิยมลบมันออกหลังจากโค้ดคอมไพล์ผ่านแล้ว แต่โดยส่วนตัวผมแนะนำให้คงไว้ เพราะนี่คือหนึ่งในตัวช่วยเล็กๆ ที่จะช่วยประหยัดเวลาของคุณได้อย่างมหาศาลเมื่อต้องกลับมาแก้ไขแฮนด์เลอร์ในอีกหกเดือนข้างหน้า

## ชนิดข้อมูลการตอบกลับ

Axum มีความยืดหยุ่นสูงมากเกี่ยวกับชนิดข้อมูลที่แฮนด์เลอร์สามารถส่งคืนกลับไปได้ โดยค่าใดก็ตามที่ implement เทรต `IntoResponse` จะสามารถนำมาใช้ได้ทันที ซึ่งมีชนิดข้อมูลมาตรฐานที่รองรับมาในตัวมากมาย นี่คือแพตเทิร์นที่ผมหยิบมาใช้งานบ่อยที่สุด:

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

ในความเป็นจริง คุณมักจะใช้ `Result` เป็นชนิดข้อมูลสำหรับส่งคืนกลับเกือบตลอดเวลา เพราะการทำงานของแฮนด์เลอร์ส่วนใหญ่ย่อมมีโอกาสเกิดข้อผิดพลาดได้เสมอ การเลือกใช้ `Result<T, AppError>` ร่วมกับการแปลง Error อย่างเป็นระบบที่เราจะไปสร้างกันในบท [การจัดการข้อผิดพลาด](./error-handling.md) จะช่วยให้โค้ดภายในแฮนด์เลอร์ของคุณสะอาดและมุ่งเน้นไปที่เส้นทางการทำงานปกติ (happy path) ได้อย่างเต็มที่

## การทำให้แฮนด์เลอร์บาง

แม้ผมจะได้กล่าวถึงเรื่องนี้ไปแล้วในตอนต้น แต่ก็คุ้มค่าอย่างยิ่งที่จะย้ำเตือนอีกครั้ง เพราะผมเห็นปัญหานี้เกิดขึ้นซ้ำๆ มานับไม่ถ้วนในหลากหลายภาษาและเฟรมเวิร์ก เมื่อใดก็ตามที่ฟังก์ชันแฮนด์เลอร์ของคุณเริ่มมีความยาวเกิน 15 หรือ 20 บรรทัด นั่นมักเป็นสัญญาณเตือนว่าเริ่มมีตรรกะทางธุรกิจแอบแฝงเข้ามาอยู่ในจุดที่ไม่ถูกต้องแล้ว

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
