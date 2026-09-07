# การตรวจสอบความถูกต้องของคำขอ

ถ้าคุณเคยส่งฟอร์มขึ้น production โดยไม่มีการตรวจสอบความถูกต้องฝั่งเซิร์ฟเวอร์ เพราะฟรอนต์เอนด์ "ตรวจสอบให้แล้ว" คุณจะรู้ว่าจุดจบของเรื่องแบบนั้นเป็นอย่างไร การตรวจสอบความถูกต้องฝั่งไคลเอนต์เป็นลูกเล่น UX ที่ดี แต่มันไม่ใช่ขอบเขตด้านความปลอดภัย ใครสักคนที่มี curl ไม่สนใจเช็ก JavaScript ของคุณ เราตรวจสอบความถูกต้องฝั่งเซิร์ฟเวอร์เสมอ

จากประสบการณ์ของผม การตรวจสอบความถูกต้องในแอปพลิเคชันที่มีโครงสร้างดีแยกเป็นสองระดับโดยธรรมชาติ ที่เลเยอร์ API เราตรวจสอบรูปร่างและรูปแบบของสิ่งที่เข้ามา: ฟิลด์ที่ต้องมีครบไหม? ฟิลด์อีเมลดูเหมือนอีเมลจริงไหม? รหัสผ่านยาวพอไหม? จากนั้นที่เลเยอร์โดเมน เราบังคับใช้ค่าคงที่ของธุรกิจผ่านระบบชนิดข้อมูล ซึ่งผมกล่าวถึงในบท [การสร้างแบบจำลองโดเมน](./domain-modeling.md)

บทนี้โฟกัสที่ระดับแรก นั่นคือการตรวจสอบความถูกต้องที่เลเยอร์ API เราจะใช้ครีต `validator` และสร้างตัวแยกข้อมูลของ Axum เองเพื่อให้ทุกอย่างลื่นไหลไร้รอยต่อ

## การตรวจสอบความถูกต้องด้วยครีต validator

ครีต `validator` ให้มาโคร derive สำหรับระบุกฎการตรวจสอบความถูกต้องลงบนฟิลด์ของ struct คุณเรียก `.validate()` บนอินสแตนซ์ มันจะเช็กทุกกฎ และส่งคืนข้อผิดพลาดแบบมีโครงสร้างกลับมาถ้ามีอะไรล้มเหลว มาดูกันว่าหน้าตาในทางปฏิบัติเป็นอย่างไร

```rust
use serde::Deserialize;
use validator::Validate;

#[derive(Debug, Deserialize, Validate)]
pub struct CreateUserDto {
    #[validate(length(min = 2, max = 50, message = "name must be between 2 and 50 characters"))]
    pub name: String,

    #[validate(email(message = "must be a valid email address"))]
    pub email: String,

    #[validate(length(min = 8, message = "password must be at least 8 characters"))]
    pub password: String,
}

#[derive(Debug, Deserialize, Validate)]
pub struct UpdateUserDto {
    #[validate(length(min = 2, max = 50, message = "name must be between 2 and 50 characters"))]
    pub name: Option<String>,

    #[validate(length(max = 500, message = "bio cannot exceed 500 characters"))]
    pub bio: Option<String>,

    #[validate(url(message = "must be a valid URL"))]
    pub avatar_url: Option<String>,
}
```

ครีต `validator` มาพร้อมชุดการตรวจสอบความถูกต้องในตัวที่แข็งแกร่ง: `email`, `url`, `length`, `range`, `contains`, `must_match` (สะดวกสำหรับการยืนยันรหัสผ่าน) และอื่นๆ อีกมาก ถ้าคุณต้องการอะไรที่ไม่เข้ากับตัวตรวจสอบในตัวเหล่านี้ คุณก็เขียนฟังก์ชันตรวจสอบความถูกต้องเองได้เช่นกัน

## extractor ValidatedJson ที่กำหนดเอง

ตัวแยกข้อมูล `Json` ในตัวของ Axum จัดการดีซีเรียลไลซ์ให้เรา แต่มันไม่รันการตรวจสอบความถูกต้องใดๆ คุณอาจเรียก `.validate()` ด้วยมือตอนต้นของทุกแฮนด์เลอร์ แต่พูดตรงๆ ว่าแบบนั้นเริ่มน่าเบื่อเร็ว และง่ายที่จะลืมทำตรงจุดใดจุดหนึ่ง สิ่งที่ผมพบว่าได้ผลดีกว่ามากคือการสร้างตัวแยกข้อมูลเองที่รวมดีซีเรียลไลซ์และการตรวจสอบความถูกต้องเข้าเป็นขั้นตอนเดียว

```rust
use axum::{
    extract::{FromRequest, Request},
    Json,
};
use validator::Validate;

pub struct ValidatedJson<T>(pub T);

impl<T, S> FromRequest<S> for ValidatedJson<T>
where
    T: serde::de::DeserializeOwned + Validate,
    S: Send + Sync,
{
    type Rejection = AppError;

    async fn from_request(req: Request, state: &S) -> Result<Self, Self::Rejection> {
        let Json(value) = Json::<T>::from_request(req, state)
            .await
            .map_err(|e| AppError::Validation(format!("invalid JSON: {e}")))?;

        value.validate().map_err(|e| {
            AppError::ValidationFields(format_validation_errors(&e))
        })?;

        Ok(Self(value))
    }
}

fn format_validation_errors(
    errors: &validator::ValidationErrors,
) -> HashMap<String, Vec<String>> {
    errors
        .field_errors()
        .iter()
        .map(|(field, errs)| {
            let messages = errs
                .iter()
                .map(|e| {
                    e.message
                        .as_ref()
                        .map(|m| m.to_string())
                        .unwrap_or_else(|| format!("{} is invalid", field))
                })
                .collect();
            (field.to_string(), messages)
        })
        .collect()
}
```

ตอนนี้แฮนด์เลอร์ของเรารับ `ValidatedJson<CreateUserDto>` แทน `Json<CreateUserDto>` ได้ และการตรวจสอบความถูกต้องจะเกิดขึ้นก่อนที่บอดี้ของแฮนด์เลอร์จะได้รัน ถ้าการตรวจสอบความถูกต้องล้มเหลว ไคลเอนต์จะได้รับการตอบกลับ 400 พร้อมข้อความข้อผิดพลาดที่ชัดเจนซึ่งบอกว่า ฟิลด์ไหนบ้างที่ล้มเหลวและเพราะอะไร ไม่ต้องทำงานเพิ่มจากฝั่งเราเลย

```rust
async fn create_user(
    State(state): State<AppState>,
    ValidatedJson(payload): ValidatedJson<CreateUserDto>,
) -> AppResult<(StatusCode, Json<UserResponse>)> {
    // By this point, we know:
    // - The JSON was well-formed
    // - name is between 2 and 50 characters
    // - email is a valid email format
    // - password is at least 8 characters
    //
    // The handler can focus on business logic.
    let user = state.user_service.register(payload).await?;
    Ok((StatusCode::CREATED, Json(user.into())))
}
```

## การตรวจสอบความถูกต้องของพารามิเตอร์ควิวรี

เราใช้แนวทางเดียวกันกับพารามิเตอร์ควิวรีได้ มาสร้าง extractor `ValidatedQuery` ที่รวมการแยกข้อมูล `Query` เข้ากับการตรวจสอบความถูกต้อง:

```rust
use axum::extract::Query;

pub struct ValidatedQuery<T>(pub T);

impl<T, S> FromRequestParts<S> for ValidatedQuery<T>
where
    T: serde::de::DeserializeOwned + Validate,
    S: Send + Sync,
{
    type Rejection = AppError;

    async fn from_request_parts(
        parts: &mut http::request::Parts,
        state: &S,
    ) -> Result<Self, Self::Rejection> {
        let Query(value) = Query::<T>::from_request_parts(parts, state)
            .await
            .map_err(|e| AppError::Validation(format!("invalid query parameters: {e}")))?;

        value.validate().map_err(|e| {
            AppError::ValidationFields(format_validation_errors(&e))
        })?;

        Ok(Self(value))
    }
}
```

## การตอบกลับข้อผิดพลาดแบบมีโครงสร้าง

ถ้านักพัฒนาคนอื่นบริโภค API ของคุณ (และส่วนใหญ่ก็เป็นเช่นนั้น) คุณจะต้องการคืนข้อผิดพลาดการตรวจสอบความถูกต้องในรูปแบบที่มีโครงสร้างซึ่งพวกเขาแยกวิเคราะห์ได้จริง ไม่ใช่สตริงต่อกันเป็นเส้นเดียว ผมชอบคืนข้อผิดพลาดเป็นออบเจกต์ JSON ที่มีลิสต์ข้อผิดพลาดรายฟิลด์:

```json
{
    "error": {
        "type": "validation_error",
        "message": "request validation failed",
        "fields": {
            "email": ["must be a valid email address"],
            "password": ["password must be at least 8 characters"]
        }
    }
}
```

เพื่อให้สิ่งนี้ทำงาน เราต้องขยาย enum `AppError` ของเราให้พกข้อผิดพลาดรายฟิลด์ที่มีโครงสร้าง และปรับอิมพลีเมนเทชัน `IntoResponse` ให้จัดรูปแบบมัน รูปทรงที่แน่นอนขึ้นอยู่กับข้อตกลงที่ API ของคุณใช้ แต่แนวคิดเหมือนกัน: ให้ข้อมูลกับไคลเอนต์มากพอที่จะแก้ทุกอย่างได้ในรอบเดียว ไม่มีใครอยากแก้ฟิลด์เดียว ส่งใหม่ แล้วเพิ่งเจอความล้มเหลวถัดไป

## extractor การตรวจสอบความถูกต้องที่สร้างไว้แล้ว

ถ้าการเขียน extractor ของตัวเองรู้สึกเป็นพิธีรีตองเกินกว่าที่ต้องการ ระบบนิเวศมีทางเลือกให้:

- **axum-valid** ผสานกับ `validator`, `garde` และ `validify` โดยมี extractor `Valid<Json<T>>`, `Valid<Query<T>>` และ `Valid<Form<T>>` ให้ใช้
- **axum-validated-extractors** มี `ValidatedJson`, `ValidatedQuery` และ `ValidatedForm` พร้อมใช้ได้ทันที

ครีตพวกนี้ช่วยคุณประหยัดโบยเลอร์เพลตที่เราเขียนข้างบน ถึงอย่างนั้น ผมมักชอบเขียนเองเพราะมันให้ควบคุมรูปแบบและพฤติกรรมของข้อผิดพลาดได้เต็มที่ ซึ่งสำคัญเมื่อคุณมีความเห็นเรื่องการตอบกลับข้อผิดพลาดของ API (และคุณจะมีแน่นอน)

## การตรวจสอบความถูกต้องสองระดับ

ก่อนไปต่อ ผมอยากทำให้ความแตกต่างระหว่างการตรวจสอบความถูกต้องที่เลเยอร์ API กับที่เลเยอร์โดเมนชัดเจนมาก เพราะการปนกันของทั้งสองนำไปสู่ตรรกะซ้ำซ้อนหรือช่องโหว่ในแนวป้องกันของคุณ ผมเห็นทั้งสองแบบมาแล้ว และไม่มีแบบไหนที่แก้ออกมาได้สนุก

**การตรวจสอบความถูกต้องที่เลเยอร์ API** (สิ่งที่เรากล่าวถึงในบทนี้) ตรวจสอบรูปร่างของอินพุต: ฟิลด์ที่ต้องมีครบไหม? สตริงยาวพอดีไหม? ฟิลด์อีเมลดูเหมือนอีเมลจริงไหม? นี่คือเรื่องของรูปแบบของข้อมูลตอนที่มันเดินทางมาถึงผ่านสายส่งข้อมูล (over the wire)

**การตรวจสอบความถูกต้องที่เลเยอร์โดเมน** (ซึ่งเรากล่าวถึงในบท [การสร้างแบบจำลองโดเมน](./domain-modeling.md)) บังคับใช้ค่าคงที่ของธุรกิจ: ชื่อผู้ใช้ต้องไม่มีอักขระต้องห้าม อีเมลถูกทำให้เป็นตัวพิมพ์เล็กทั้งหมด ยอดเงินของออเดอร์ต้องเป็นบวก การตรวจสอบความถูกต้องนี้เกิดขึ้นตอนคุณสร้างชนิดข้อมูลโดเมน เช่น `UserName::parse()` หรือ `Email::parse()`

สองระดับนี้ทำงานด้วยกันอย่างลงตัว เลเยอร์ API ของเราจับอินพุตที่ผิดรูปอย่างชัดเจนได้ตั้งแต่เนิ่นๆ และคืนข้อความข้อผิดพลาดที่เป็นประโยชน์ เลเยอร์โดเมนของเราทำให้กฎธุรกิจถูกบังคับใช้อย่างสม่ำเสมอ ไม่ว่าข้อมูลจะมาจากคำขอ HTTP คิวข้อความ การนำเข้า CSV หรือชุดทดสอบ เมื่อมีครบทั้งสอง เราก็มีรากฐานที่แข็งแรงสำหรับแพตเทิร์นการจัดการข้อผิดพลาดซึ่งเราจะดูกันต่อไป
