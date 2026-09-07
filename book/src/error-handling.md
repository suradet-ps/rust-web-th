# การจัดการข้อผิดพลาด

ถ้าคุณเคยพัฒนาเว็บเซอร์วิสมาระยะหนึ่ง คุณจะตระหนักได้ว่าการจัดการข้อผิดพลาดแท้จริงแล้วคือการตอบสนองความต้องการของผู้รับข้อมูล 2 กลุ่มที่แตกต่างกันโดยสิ้นเชิง: ฝั่งผู้ใช้งาน API ต้องการข้อความแจ้งเตือนที่เข้าใจง่ายเมื่อมีสิ่งใดผิดพลาด นั่นคือรหัสสถานะ HTTP ที่ถูกต้องและคำอธิบายที่ช่วยให้แก้ไขปัญหาได้จริง ขณะที่ฝั่งทีมงานผู้พัฒนาของคุณต้องการภาพรวมเชิงลึกทั้งหมด ไม่ว่าจะเป็น stack trace, สายโซ่ของข้อผิดพลาด (error chain) และบริบทแวดล้อมที่เพียงพอต่อการสืบค้นต้นตอของบั๊ก เคล็ดลับสำคัญจึงอยู่ที่การตอบโจทย์ทั้งสองกลุ่มนี้ไปพร้อมกัน โดยไม่เปิดเผยรายละเอียดการทำงานภายในให้รั่วไหลออกสู่โลกภายนอก

Axum มีแนวทางการออกแบบที่น่าสนใจมากตรงจุดนี้ กล่าวคือ เฟรมเวิร์กกำหนดให้แฮนด์เลอร์ทุกตัวต้องไม่มีวันล้มเหลว (infallible) ในระดับของเฟรมเวิร์ก ซึ่งหมายความว่าแฮนด์เลอร์จะต้องส่งคืน HTTP response ที่สมบูรณ์กลับมาเสมอ ไม่ว่าจะเกิดข้อผิดพลาดใดๆ ขึ้นก็ตาม ในทางปฏิบัติ เราทำได้โดยการคืนค่าเป็น `Result<T, E>` โดยที่ `E` จะต้องอิมพลีเมนต์ trait `IntoResponse` เมื่อใดก็ตามที่แฮนด์เลอร์คืนค่าเป็น `Err(e)` ทาง Axum จะเรียกใช้ `e.into_response()` อัตโนมัติเพื่อสร้าง HTTP response สำหรับข้อผิดพลาดนั้นขึ้นมา กลไกนี้เปิดโอกาสให้เราควบคุมรูปแบบของการตอบกลับได้อย่างเบ็ดเสร็จ ซึ่งเป็นสิ่งที่ตรงกับความต้องการของเราอย่างยิ่ง

## แพตเทิร์น AppError

แนวคิดนี้มีความตรงไปตรงมา: เราจะสร้าง enum ข้อผิดพลาดส่วนกลางขึ้นมาหนึ่งตัวเพื่อรวบรวมทุกกรณีข้อผิดพลาดที่ API สามารถสร้างขึ้นได้ โดยแฮนด์เลอร์ทุกตัวจะคืนค่าเป็น `Result<T, AppError>` และโค้ดการอิมพลีเมนต์ `IntoResponse` บน `AppError` จะทำหน้าที่จับคู่วาเรียนต์แต่ละตัวเข้ากับรหัสสถานะ HTTP และโครงสร้างบอดี้ของการตอบกลับที่เหมาะสม เรามาดูตัวอย่างการใช้งานจริงกันครับ:

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

ชิ้นส่วนที่สำคัญที่สุดในโค้ดชุดนี้คือวาเรียนต์ `Internal` ซึ่งทำหน้าที่ห่อหุ้ม `anyhow::Error` เอาไว้ ทำให้สามารถรองรับชนิดข้อมูลข้อผิดพลาดรูปแบบใดก็ได้พร้อมสายโซ่ของบริบท (context chain) เมื่อเกิดข้อผิดพลาดภายในระบบ เราจะบันทึกรายละเอียดทั้งหมดลงในระบบล็อก (ทั้ง error chain และ backtrace หากมี) แต่จะส่งกลับไปยังผู้ใช้งานภายนอกเพียงแค่ข้อความทั่วไปเท่านั้น นี่คือวิธีป้องกันข้อมูลภายในรั่วไหลที่มีประสิทธิภาพสูง คุณคงไม่อยากให้โครงสร้างสกีมาของฐานข้อมูลหรือเส้นทางไฟล์ภายในเซิร์ฟเวอร์หลุดรอดออกไปใน API response เพราะผมเคยเห็นเหตุการณ์นั้นเกิดขึ้นบน production มาแล้ว และไม่ใช่เรื่องน่าอภิรมย์เลยในการต้องตอบคำถามกับทีมดูแลความปลอดภัย (security team)

## type alias เพื่อความสะดวก

แม้จะดูเหมือนเป็นเรื่องเล็กน้อย แต่วิธีนี้ช่วยเพิ่มความสบายตาและทำให้อ่านโค้ดได้ง่ายขึ้นอย่างมาก เราจะสร้าง type alias ขึ้นมาเพื่อช่วยให้ signature ของแฮนด์เลอร์มีความกระชับ:

```rust
pub type AppResult<T> = Result<T, AppError>;
```

ทำให้แฮนด์เลอร์ของเราสามารถเขียนได้อย่างสะอาดตาเช่นนี้:

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

สังเกตว่าโอเปอเรเตอร์ `?` สามารถทำงานร่วมกันได้อย่างราบรื่นทันที ผ่านทางการอิมพลีเมนต์ `From` บน `AppError` ซึ่งเราจะไปดูกันในหัวข้อถัดไป

## ห่วงโซ่การแปลงข้อผิดพลาด

ในสถาปัตยกรรมแบบเลเยอร์ ข้อผิดพลาดจะเริ่มต้นจากชั้นล่างสุด (เลเยอร์อินฟราสตรักเจอร์) ส่งผ่านขึ้นมายังเลเยอร์โดเมน และสุดท้ายเดินทางมาถึงเลเยอร์ API เพื่อแปลงรูปไปเป็น HTTP response แต่ละเลเยอร์จะมีชนิดข้อมูลข้อผิดพลาดเป็นของตัวเอง และเราจะใช้การอิมพลีเมนต์ trait `From` ในการแปลงข้อมูลข้ามขอบเขตระหว่างกัน

ภาพรวมของสายโซ่การแปลงข้อผิดพลาดสำหรับการดำเนินการ "สร้างผู้ใช้ใหม่" (create user):

```
sqlx::Error
  → CreateUserError (domain)
      → AppError (api)
          → HTTP Response
```

เลเยอร์อินฟราสตรักเจอร์จะดักจับข้อผิดพลาดของฐานข้อมูล แล้วแปลงให้อยู่ในรูปที่เลเยอร์โดเมนเข้าใจ:

```rust
// In the repository implementation
.map_err(|e| match e {
    sqlx::Error::Database(ref db_err) if db_err.is_unique_violation() => {
        CreateUserError::Duplicate { email: req.email.clone() }
    }
    other => CreateUserError::Unknown(other.into()),
})
```

จากนั้นเลเยอร์ API จะทำหน้าที่แปลงข้อผิดพลาดระดับโดเมนนั้นให้กลายเป็น `AppError`:

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

เมื่อมีการอิมพลีเมนต์ `From` ไว้อย่างครบถ้วน แฮนด์เลอร์ของเราจะสามารถใช้โอเปอเรเตอร์ `?` ได้ทันที และปล่อยให้คอมไพเลอร์จัดการกระบวนการแปลงข้อมูลทั้งหมดให้โดยอัตโนมัติ โดยไม่ต้องมานั่งแปลงค่าด้วยตัวเองให้รกโค้ด:

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

คุณอาจสงสัยว่าเหตุใดเราจึงเลือกใช้เครตจัดการข้อผิดพลาดถึง 2 ตัวคู่กัน ในความเป็นจริง เครตทั้งสองถูกออกแบบมาเพื่อทำหน้าที่เสริมซึ่งกันและกันอย่างสมบูรณ์ และจากประสบการณ์ของผม แอปพลิเคชันที่มีโครงสร้างที่ดีควรนำทั้งสองตัวมาใช้งานร่วมกันอย่างถูกจุด:

**thiserror** เหมาะสำหรับข้อผิดพลาดที่โค้ดของคุณจำเป็นต้องนำไป match หรือตรวจสอบเงื่อนไข เครตนี้จะช่วยสร้างโค้ดการอิมพลีเมนต์ trait `Display` และ `Error` ให้จากนิยาม enum ของคุณโดยอัตโนมัติ เราจึงเลือกใช้มันกับข้อผิดพลาดในระดับโดเมน (`CreateUserError`, `AuthError`), ใช้กับ enum `AppError`, รวมถึงชนิดข้อมูลข้อผิดพลาดใดๆ ที่ฝั่งผู้เรียกจำเป็นต้องแยกแยะวาเรียนต์เพื่อจัดการต่ออย่างจำเพาะเจาะจง

**anyhow** เหมาะสำหรับข้อผิดพลาดที่โค้ดของคุณต้องการเพียงแค่ส่งต่อ (propagate) ขึ้นไปด้านบน โดยมอบชนิดข้อมูล `anyhow::Error` ตัวเดียวที่สามารถบรรจุข้อผิดพลาดรูปแบบใดก็ได้ พร้อมแนบข้อความบริบทแวดล้อมเพื่อร้อยเรียงเป็นคำอธิบายสิ่งที่เกิดขึ้น เราจึงใช้มันกับวาเรียนต์ `Internal` ซึ่งเป็น catch-all ของ `AppError` และใช้ในโค้ดอินฟราสตรักเจอร์เมื่อเราต้องการเพิ่มบริบทโดยไม่ต้องมานั่งประกาศ enum วาเรียนต์ใหม่สำหรับทุกๆ ความผิดพลาดที่เป็นไปได้

หลักคิดง่ายๆ (rule of thumb) ที่ผมยึดถือเสมอคือ: ใช้ `thiserror` บริเวณขอบเขตที่ผู้เรียกจำเป็นต้องตัดสินใจตามวาเรียนต์ของข้อผิดพลาด และใช้ `anyhow` สำหรับกรณี "ข้อผิดพลาดส่วนที่เหลือทั้งหมด" ที่ต้องการเพียงบันทึกลงในระบบล็อกและรายงานผลเท่านั้น

## การเพิ่มบริบทด้วย anyhow

Trait `anyhow::Context` ช่วยให้คุณสามารถแนบข้อความบริบทที่มนุษย์อ่านเข้าใจง่ายเข้ากับข้อผิดพลาดในระหว่างที่มันถูกส่งต่อขึ้นไปตาม call stack แม้จะดูเหมือนเป็นงานที่ต้องเขียนเพิ่มขึ้นเล็กน้อยในตอนพัฒนา แต่มันมีประโยชน์มหาศาลในยามที่ต้องดีบั๊ก เพราะมันไม่ได้บอกแค่ว่าอะไรล้มเหลว แต่บอกว่าทำไมโค้ดถึงพยายามทำสิ่งนั้นตั้งแต่แรก

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

เมื่อข้อผิดพลาดนี้เดินทางมาถึงวาเรียนต์ `Internal` ของ `AppError` และถูกบันทึกลงล็อก เอาต์พุตที่ได้จะประกอบด้วยทั้งข้อผิดพลาดตั้งต้น ("connection refused") และข้อความบริบท ("failed to connect to the database") ซึ่งนี่คือความแตกต่างระหว่างการนั่งมองข้อความแจ้งเตือนที่ชวนสับสน กับการรู้ได้ทันทีว่าควรเริ่มตรวจสอบที่จุดใด

## หลักสังเขป (Rules of thumb)

**ห้ามเรียกใช้ `unwrap()` หรือ `expect()` ในโค้ดเส้นทางประมวลผลคำขอ HTTP โดยเด็ดขาด** อาการ panic ในแฮนด์เลอร์ไม่ได้ส่งผลกระทบต่อคำขอนั้นเพียงคำขอเดียว หาก panic เกิดขึ้นในระหว่างที่กำลังถือ mutex หรือทรัพยากรส่วนกลางอื่นๆ มันอาจทำให้ทรัพยากรนั้นกลายสภาพเป็นพิษ (poisoned) และลุกลามสร้างความเสียหายไปยังคำขออื่นๆ ในระบบ ผมเคยเห็นบั๊กที่เกิดจากการใช้ `unwrap()` อย่างประมาทมามากพอ จนต้องขอย้ำเตือนเรื่องนี้อย่างจริงจัง: จงส่งผ่านข้อผิดพลาดด้วยชนิดข้อมูล `Result` เสมอ

**อย่าเปิดเผยข้อความข้อผิดพลาดภายในให้ผู้ใช้ภายนอกเห็นโดยเด็ดขาด** ข้อผิดพลาดของฐานข้อมูล, เส้นทางไดเรกทอรีไฟล์, stack trace และชื่อเซอร์วิสภายใน ล้วนเป็นข้อมูลที่มีมูลค่าสำหรับผู้ไม่ประสงค์ดี จงบันทึกข้อมูลเหล่านี้ลงในระบบล็อกที่ระดับ `error` สำหรับทีมงานของคุณ และส่งคืนเพียงข้อความทั่วไปอย่าง "internal error" ให้แก่ผู้ใช้งานภายนอก

**ใช้ `thiserror` สำหรับข้อผิดพลาดที่มีโครงสร้างชัดเจน และใช้ `anyhow` สำหรับการส่งต่อแบบ catch-all** หลีกเลี่ยงการใช้ `anyhow` เป็นชนิดข้อมูลผลลัพธ์ของแฮนด์เลอร์โดยตรง เพราะจะทำให้คุณสูญเสียความสามารถในการจับคู่ข้อผิดพลาดแต่ละประเภทเข้ากับรหัสสถานะ HTTP ที่เหมาะสม แต่ควรนำมาใช้ภายในวาเรียนต์ `AppError::Internal` แทน

**ใช้ประโยชน์จาก `#[from]` เพื่อการแปลงชนิดข้อมูลอัตโนมัติ** แอตทริบิวต์ `#[from]` ของ `thiserror` จะช่วยสร้างโค้ดการอิมพลีเมนต์ `From` ให้โดยอัตโนมัติ ทำให้โอเปอเรเตอร์ `?` สามารถแปลงข้อผิดพลาดข้ามชนิดข้อมูลได้ทันที ช่วยให้โค้ดในแฮนด์เลอร์ของคุณมีความกระชับและมุ่งเน้นไปที่เส้นทางการทำงานปกติ (happy path) ได้อย่างเต็มที่

**เพิ่มข้อความบริบทด้วย `.context()` อย่างสม่ำเสมอในโค้ดเลเยอร์อินฟราสตรักเจอร์** ต้นทุนเพียงเล็กน้อยในการเขียนข้อความบริบทกำกับ จะมอบผลตอบแทนที่คุ้มค่าอย่างมหาศาลเวลาที่คุณต้องตื่นขึ้นมาดีบั๊กระบบ production ตอนตีสอง แล้วล็อกของระบบระบุชัดเจนว่า "failed to persist user registration" แทนที่จะเป็นเพียงแค่ข้อความแห้งๆ อย่าง "connection reset by peer" เชื่อผมเถอะครับว่ามันคุ้มค่าจริงๆ
