# การจัดการข้อผิดพลาด

ถ้าคุณเคยทำงานกับเว็บเซอร์วิสมาระยะหนึ่ง คุณจะรู้ว่าการจัดการข้อผิดพลาดจริงๆ แล้วคือการรับมือกับผู้ชมสองกลุ่มที่แตกต่างกันโดยสิ้นเชิง ผู้ใช้ API ของคุณต้องการคำติชมที่ชัดเจนเมื่อมีอะไรผิดพลาด นั่นคือรหัสสถานะ HTTP ที่ถูกต้องและข้อความที่ช่วยให้พวกเขาแก้ปัญหาได้จริง ส่วนทีมของคุณเองต้องการภาพรวมทั้งหมด ไม่ว่าจะเป็นสแตกเทรซ ห่วงโซ่ของข้อผิดพลาด และบริบทที่พอจะไล่ตามบั๊กได้ กลเม็ดคือการเสิร์ฟทั้งสองกลุ่มพร้อมกันโดยไม่รั่วไหลรายละเอียดภายในออกไปสู่โลกภายนอก

Axum ตัดสินใจออกแบบที่น่าสนใจตรงนี้ มันกำหนดให้แฮนด์เลอร์ทุกตัวต้องไม่ล้มเหลวในระดับเฟรมเวิร์ก ซึ่งหมายความว่าพวกมันต้องคืนการตอบกลับ HTTP ที่ถูกต้องเสมอ แม้เมื่อสถานการณ์พลิกผัน ในทางปฏิบัติ คุณทำได้โดยคืน `Result<T, E>` โดยที่ `E` ต้อง implement `IntoResponse` เมื่อแฮนด์เลอร์ของคุณคืน `Err(e)` Axum จะเรียก `e.into_response()` เพื่อสร้างการตอบกลับข้อผิดพลาด สิ่งนี้ทำให้เราควบคุมได้เต็มที่ว่าข้อผิดพลาดจะมีหน้าตาอย่างไรต่อผู้ใช้ ซึ่งก็คือสิ่งที่เราต้องการพอดี

## แพตเทิร์น AppError

แนวคิดตรงไปตรงมา: เราสร้าง error enum กลางหนึ่งตัวที่ครอบคลุมทุกกรณีข้อผิดพลาดที่ API ของเราสร้างได้ แฮนด์เลอร์ทุกตัวคืน `Result<T, AppError>` และอิมพลีเมนเทชันของ `IntoResponse` บน `AppError` จะจัดการจับคู่แต่ละวาเรียนต์ให้เข้ากับรหัสสถานะ HTTP และบอดี้ของการตอบกลับที่ถูกต้อง มาดูกันว่าหน้าตาเป็นอย่างไรในทางปฏิบัติ

```rust
use std::collections::HashMap;
use axum::http::StatusCode;
use axum::response::{IntoResponse, Response};
use axum::Json;

#[derive(Debug, thiserror::Error)]
pub enum AppError {
    #[error("resource not found")]
    NotFound,

    #[error("{0}")]
    Validation(String),

    #[error("validation failed")]
    ValidationFields(HashMap<String, Vec<String>>),

    #[error("authentication required")]
    Unauthorized,

    #[error("insufficient permissions")]
    Forbidden,

    #[error("{0}")]
    Conflict(String),

    #[error(transparent)]
    Internal(#[from] anyhow::Error),
}

impl IntoResponse for AppError {
    fn into_response(self) -> Response {
        let (status, error_type, message) = match &self {
            AppError::NotFound => (
                StatusCode::NOT_FOUND,
                "not_found",
                self.to_string(),
            ),
            AppError::Validation(msg) => (
                StatusCode::BAD_REQUEST,
                "validation_error",
                msg.clone(),
            ),
            AppError::ValidationFields(ref fields) => {
                let body = serde_json::json!({
                    "error": {
                        "type": "validation_error",
                        "message": "request validation failed",
                        "fields": fields,
                    }
                });
                return (StatusCode::BAD_REQUEST, Json(body)).into_response();
            }
            AppError::Unauthorized => (
                StatusCode::UNAUTHORIZED,
                "unauthorized",
                self.to_string(),
            ),
            AppError::Forbidden => (
                StatusCode::FORBIDDEN,
                "forbidden",
                self.to_string(),
            ),
            AppError::Conflict(msg) => (
                StatusCode::CONFLICT,
                "conflict",
                msg.clone(),
            ),
            AppError::Internal(err) => {
                // Log the full error chain for debugging. This is the only
                // place where the real error details are visible.
                tracing::error!(error = ?err, "internal server error");
                (
                    StatusCode::INTERNAL_SERVER_ERROR,
                    "internal_error",
                    "an internal error occurred".to_string(),
                )
            }
        };

        let body = serde_json::json!({
            "error": {
                "type": error_type,
                "message": message,
            }
        });

        (status, Json(body)).into_response()
    }
}
```

ชิ้นส่วนที่สำคัญที่สุดตรงนี้คือวาเรียนต์ `Internal` มันห่อหุ้ม `anyhow::Error` ซึ่งบรรจุชนิดข้อมูลข้อผิดพลาดใดๆ ได้พร้อมกับห่วงโซ่ของข้อความบริบท เมื่อเกิดข้อผิดพลาดภายใน เราจะบันทึกข้อมูลเต็มรูปแบบ (ห่วงโซ่ของข้อผิดพลาดและแบ็กเทรซถ้ามี) แต่คืนให้ผู้ใช้เพียงข้อความทั่วไปเท่านั้น นี่คือวิธีที่เราป้องกันการรั่วไหลของข้อมูล คุณไม่ต้องการจริงๆ หรอกที่รายละเอียดสกีมาฐานข้อมูลหรือเส้นทางไฟล์ภายในจะไปโผล่ในการตอบกลับ API ผมเคยเห็นเหตุการณ์แบบนั้นใน production และมันไม่ใช่บทสนทนาที่สนุกกับทีมความปลอดภัยเลย

## type alias เพื่อความสะดวก

นี่อาจดูเหมือนเรื่องเล็กน้อย แต่มันสร้างความแตกต่างจริงๆ ในแง่ความสามารถในการอ่าน เรากำหนด type alias เพื่อให้ลายเซ็นของแฮนด์เลอร์สะอาด:

```rust
pub type AppResult<T> = Result<T, AppError>;
```

ตอนนี้แฮนด์เลอร์ของเรามีหน้าตาแบบนี้:

```rust
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
```

สังเกตว่าตัวดำเนินการ `?` ทำงานได้ทันทีตรงนี้ เพราะอิมพลีเมนเทชันของ `From` บน `AppError` ซึ่งเราจะดูกันต่อไป

## ห่วงโซ่การแปลงข้อผิดพลาด

ในสถาปัตยกรรมแบบเลเยอร์ของเรา ข้อผิดพลาดเริ่มต้นจากชั้นล่างสุด (เลเยอร์อินฟราสตรัคเจอร์) ทะลุผ่านเลเยอร์โดเมน และสุดท้ายมาถึงเลเยอร์ API ซึ่งกลายเป็นการตอบกลับ HTTP แต่ละเลเยอร์มีชนิดข้อมูลข้อผิดพลาดของตัวเอง และเราใช้การ implement `From` เพื่อแปลงระหว่างกัน

นี่คือหน้าตาของห่วงโซ่สำหรับการดำเนินการ "สร้างผู้ใช้" (create user):

```
sqlx::Error
  → CreateUserError (domain)
      → AppError (api)
          → HTTP Response
```

เลเยอร์อินฟราสตรัคเจอร์จับข้อผิดพลาดฐานข้อมูลแล้วแปลงเป็นสิ่งที่โดเมนเข้าใจ:

```rust
// In the repository implementation
.map_err(|e| match e {
    sqlx::Error::Database(ref db_err) if db_err.is_unique_violation() => {
        CreateUserError::Duplicate { email: req.email.clone() }
    }
    other => CreateUserError::Unknown(other.into()),
})
```

จากนั้นเลเยอร์ API ก็แปลงข้อผิดพลาดระดับโดเมนนั้นให้เป็น `AppError`:

```rust
impl From<CreateUserError> for AppError {
    fn from(err: CreateUserError) -> Self {
        match err {
            CreateUserError::Duplicate { email } => {
                AppError::Conflict(
                    format!("a user with email {} already exists", email.as_str())
                )
            }
            CreateUserError::Unknown(inner) => AppError::Internal(inner),
        }
    }
}
```

เมื่อมีการ implement `From` ครบแล้ว แฮนด์เลอร์ของเราสามารถใช้ `?` ได้เลยและปล่อยให้คอมไพเลอร์จัดการเรื่องการแปลงให้ ไม่มีการแมปด้วยมือ ไม่มีโบยเลอร์เพลต:

```rust
async fn create_user(
    State(state): State<AppState>,
    ValidatedJson(payload): ValidatedJson<CreateUserDto>,
) -> AppResult<(StatusCode, Json<UserResponse>)> {
    let user = state.user_service.register(payload).await?;  // ? handles the full chain
    Ok((StatusCode::CREATED, Json(user.into())))
}
```

## thiserror กับ anyhow

คุณอาจสงสัยว่าทำไมเราถึงใช้ครีตจัดการข้อผิดพลาดสองตัว ครีตทั้งสองทำหน้าที่เสริมกันจริงๆ และจากประสบการณ์ของผม แอปพลิเคชันที่จัดโครงสร้างอย่างดีควรใช้ทั้งสองตัว

**thiserror** ใช้สำหรับข้อผิดพลาดที่โค้ดของคุณต้อง match กับมัน มันสร้างอิมพลีเมนเทชันของเทรต `Display` และ `Error` จากนิยาม enum ของคุณ เราใช้มันกับข้อผิดพลาดระดับโดเมน (`CreateUserError`, `AuthError`) กับ enum `AppError` และกับชนิดข้อมูลข้อผิดพลาดใดๆ ที่ผู้เรียกต้องแยกแยะระหว่างวาเรียนต์และตอบสนองต่างกัน

**anyhow** ใช้สำหรับข้อผิดพลาดที่โค้ดของคุณแค่ต้องส่งต่อ (propagate) มันให้ชนิดข้อมูล `anyhow::Error` ตัวเดียวที่บรรจุข้อผิดพลาดใดก็ได้ พร้อมกับข้อความบริบทที่รวมกันเป็นห่วงโซ่อธิบายว่าเกิดอะไรขึ้น เราใช้มันกับวาเรียนต์ `Internal` แบบ catch-all ของ `AppError` และในโค้ดอินฟราสตรัคเจอร์ที่เราต้องการเพิ่มบริบทโดยไม่ต้องนิยามวาเรียนต์ข้อผิดพลาดใหม่สำหรับทุกโหมดความล้มเหลวที่เป็นไปได้

หลักสังเขปที่ผมยึดถือคือ: ใช้ `thiserror` ตรงขอบเขตที่ผู้เรียกต้องตัดสินใจตามวาเรียนต์ของข้อผิดพลาด และใช้ `anyhow` สำหรับกรณี "ที่เหลือทั้งหมด" ที่ข้อผิดพลาดแค่ต้องถูกล็อกและรายงาน

## การเพิ่มบริบทด้วย anyhow

เทรต `anyhow::Context` ช่วยให้คุณผูกบริบทที่มนุษย์อ่านเข้าใจเข้ากับข้อผิดพลาดขณะที่มันถูกส่งต่อขึ้นไปตามคอลสแตก นี่เป็นหนึ่งในสิ่งที่ดูเหมือนทำงานเพิ่มตอนเขียนโค้ด แต่มีประโยชน์มหาศาลตอนดีบัก มันบอกคุณไม่เพียงแค่ว่าอะไรล้มเหลว แต่บอกว่าทำไมโค้ดถึงพยายามทำสิ่งนั้นตั้งแต่แรก

```rust
use anyhow::Context;

pub async fn create_pool(database_url: &str) -> anyhow::Result<PgPool> {
    PgPoolOptions::new()
        .max_connections(10)
        .acquire_timeout(Duration::from_secs(3))
        .connect(database_url)
        .await
        .context("failed to connect to the database")
}
```

เมื่อข้อผิดพลาดนี้มาถึงวาเรียนต์ `Internal` ของ `AppError` และถูกล็อก เอาต์พุตจะรวมทั้งข้อผิดพลาดต้นฉบับ ("connection refused") และบริบท ("failed to connect to the database") นี่คือความแตกต่างระหว่างการจ้องข้อความข้อผิดพลาดที่งงวยกับการรู้ทันทีว่าควรไปดูตรงไหน

## หลักสังเขป (Rules of thumb)

**ห้ามเรียก `unwrap()` หรือ `expect()` ในโค้ดที่จัดการคำขอ HTTP โดยเด็ดขาด** แพนิกในแฮนด์เลอร์ไม่ได้กระทบแค่คำขอนั้นคำขอเดียว ถ้าแพนิกเกิดขึ้นขณะถือ mutex หรือแหล่งข้อมูลร่วมอื่นๆ มันอาจทำให้แหล่งข้อมูลนั้นเป็นพิษ (poison) และลุกลามไปยังคำขออื่นๆ ผมเคยเห็นบั๊กจาก `unwrap()` ที่สะเพร่ามามากพอจะยืนกรานเรื่องนี้ค่อนข้างหนัก แปลงข้อผิดพลาดผ่านชนิดข้อมูล `Result` เสมอ

**อย่าเปิดเผยข้อความข้อผิดพลาดภายในให้ผู้ใช้เห็นโดยเด็ดขาด** ข้อผิดพลาดฐานข้อมูล เส้นทางไฟล์ สแตกเทรซ และชื่อเซอร์วิสภายใน ล้วนเป็นข้อมูลที่ผู้โจมตีนำไปใช้ได้ ล็อกพวกมันที่ระดับ `error` สำหรับทีมของคุณ แล้วคืนข้อความ "internal error" ทั่วไปให้ผู้ใช้

**ใช้ `thiserror` สำหรับข้อผิดพลาดแบบมีโครงสร้าง และใช้ `anyhow` สำหรับการส่งต่อแบบ catch-all** อย่าใช้ `anyhow` เป็นชนิดข้อมูลผลลัพธ์ของแฮนด์เลอร์โดยตรง เพราะคุณจะเสียความสามารถในการจับคู่ข้อผิดพลาดต่างๆ กับรหัสสถานะ HTTP ที่ต่างกัน ให้ใช้มันภายในวาเรียนต์ `AppError::Internal` แทน

**ใช้ `#[from]` สำหรับการแปลงอัตโนมัติ** แอตทริบิวต์ `#[from]` ของ `thiserror` สร้างการ implement `From` ที่ให้ตัวดำเนินการ `?` แปลงข้อผิดพลาดได้อัตโนมัติ สิ่งนี้ทำให้โค้ดแฮนด์เลอร์ของคุณสะอาดและให้คุณโฟกัสกับเส้นทางปกติ (happy path)

**เพิ่มบริบทด้วย `.context()` อย่างเต็มที่ในโค้ดอินฟราสตรัคเจอร์** ต้นทุนเล็กน้อยของการเขียนสตริงบริบทให้ผลตอบแทนมหาศาลเมื่อคุณกำลังดีบักอะไรบางอย่างใน production ตอนตีสองและล็อกข้อผิดพลาดบอกว่า "failed to persist user registration" แทนที่จะเป็นแค่ "connection reset by peer" เชื่อผมเถอะ
