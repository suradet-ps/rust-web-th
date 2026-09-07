# การตรวจสอบความถูกต้องของคำขอ

ถ้าคุณเคยส่งฟอร์มขึ้น production โดยไม่มีการ validation ฝั่งเซิร์ฟเวอร์เพราะคิดว่าฝั่งฟรอนต์เอนด์ "ตรวจให้แล้ว" คุณคงรู้ดีว่าจุดจบมักเป็นอย่างไร การทำ client-side validation ช่วยเรื่อง UX ให้ใช้งานได้ลื่นไหล แต่มันไม่ใช่แนวป้องกันด้านความปลอดภัย (security boundary) เลย เพราะใครก็ตามที่ใช้ curl ย่อมไม่สนใจโค้ด JavaScript ของคุณอยู่แล้ว ดังนั้นเราจึงต้องทำ validation ฝั่งเซิร์ฟเวอร์เสมอ

จากประสบการณ์ของผม การ validation ในแอปพลิเคชันที่มีโครงสร้างดีจะแบ่งออกเป็น 2 ระดับอย่างเป็นธรรมชาติ ที่ API layer เราจะตรวจสอบโครงสร้างและรูปแบบของข้อมูลที่ส่งเข้ามา: มีฟิลด์ที่จำเป็นครบถ้วนไหม? ฟิลด์อีเมลดูเหมือนอีเมลจริงไหม? รหัสผ่านยาวพอไหม? จากนั้นที่ Domain layer เราจะบังคับใช้กฎทางธุรกิจ (business invariants) ผ่านระบบ type system ซึ่งผมได้อธิบายไว้แล้วในบท [การสร้างแบบจำลองโดเมน](./domain-modeling.md)

บทนี้จะเน้นไปที่ระดับแรก นั่นคือการ validation ที่ API layer โดยเราจะใช้ crate `validator` และสร้าง custom extractor ของ Axum ขึ้นมาเพื่อให้ทุกอย่างทำงานประสานกันได้อย่างไร้รอยต่อ

## การตรวจสอบความถูกต้องด้วยเครต validator

crate `validator` มี derive macro ที่ช่วยให้เรากำหนดกฎ validation บนฟิลด์ของ struct ได้โดยตรง เพียงคุณเรียก `.validate()` บน instance ของ struct ตัว crate จะตรวจสอบทุกกฎที่กำหนดไว้ และส่ง structured error กลับมาหากมีจุดใดไม่ผ่านเกณฑ์ มาดูกันว่าเวลาใช้งานจริงมีหน้าตาเป็นอย่างไร


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

crate `validator` มาพร้อมตัวตรวจสอบ (validators) ในตัวที่ครอบคลุมมาก: `email`, `url`, `length`, `range`, `contains`, `must_match` (สะดวกมากสำหรับการยืนยันรหัสผ่าน) และอื่นๆ อีกมากมาย แต่หากคุณต้องการเงื่อนไขเฉพาะทางที่ไม่ตรงกับตัวตรวจสอบที่มีให้ คุณก็เขียนฟังก์ชัน validation ขึ้นมาเองได้เช่นกัน

## extractor ValidatedJson ที่กำหนดเอง

ตัวแยกข้อมูล `Json` ในตัวของ Axum จัดการเรื่อง deserialization ให้เราก็จริง แต่มันไม่ได้รัน validation ใดๆ ให้เลย คุณอาจเลือกเรียก `.validate()` ด้วยตนเองที่จุดเริ่มต้นของทุก handler แต่วิธีนี้จะกลายเป็นเรื่องน่าเบื่ออย่างรวดเร็ว และมีโอกาสเผลอลืมได้ง่ายมาก สิ่งที่ผมพบว่าได้ผลดีกว่ามากคือการสร้าง custom extractor ที่รวมทั้งการ deserialize และ validate เข้าด้วยกันในขั้นตอนเดียว

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

ตอนนี้ handler ของเราสามารถรับ `ValidatedJson<CreateUserDto>` แทน `Json<CreateUserDto>` ได้แล้ว และการ validation จะเกิดขึ้นก่อนที่ body ของ handler จะเริ่มทำงานด้วยซ้ำ หากการตรวจสอบล้มเหลว ไคลเอนต์จะได้รับ response 400 พร้อมข้อความข้อผิดพลาดที่ชัดเจนซึ่งระบุว่าฟิลด์ไหนบ้างที่ผิดพลาดและผิดเพราะอะไร โดยที่เราไม่ต้องเขียนโค้ดเพิ่มใน handler เลย


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

เราสามารถนำแนวทางเดียวกันนี้มาใช้กับ query parameters ได้เช่นกัน โดยสร้าง extractor `ValidatedQuery` ที่รวมการดึงข้อมูล `Query` เข้ากับการตรวจสอบความถูกต้อง:

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

หาก API ของคุณมีนักพัฒนาคนอื่นนำไปใช้งานต่อ (ซึ่งโดยทั่วไปก็เป็นเช่นนั้น) คุณย่อมต้องการส่ง validation error กลับไปในรูปแบบที่มีโครงสร้างชัดเจนเพื่อให้ฝั่งผู้เรียกสามารถ parse ข้อมูลไปใช้งานต่อได้จริง ไม่ใช่สตริงข้อความเดี่ยวยาวๆ ผมชอบส่งข้อผิดพลาดกลับไปเป็น JSON object ที่แจกแจงรายการข้อผิดพลาดแยกตามรายฟิลด์:

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

เพื่อให้ใช้งานแบบนี้ได้ เราต้องขยาย enum `AppError` ของเราให้เก็บข้อผิดพลาดรายฟิลด์แบบมีโครงสร้าง และปรับการอิมพลีเมนต์ `IntoResponse` เพื่อจัดรูปแบบข้อมูล รูปแบบที่แน่นอนขึ้นอยู่กับข้อตกลงที่ API ของคุณใช้ แต่หลักการสำคัญเหมือนกัน: ให้ข้อมูลกับไคลเอนต์มากพอที่จะแก้ไขทุกอย่างได้จบในรอบเดียว ไม่มีใครอยากแก้ทีละฟิลด์ ส่งใหม่ แล้วเพิ่งมาเจอข้อผิดพลาดของฟิลด์ถัดไปเรื่อยๆ

## extractor การตรวจสอบความถูกต้องที่สร้างไว้แล้ว

หากคุณรู้สึกว่าการเขียน custom extractor ขึ้นมาเองดูมี boilerplate มากเกินไป ใน ecosystem ก็มี crate ทางเลือกให้พร้อมใช้:

- **axum-valid** รองรับการผสานงานกับทั้ง `validator`, `garde` และ `validify` โดยมี extractor อย่าง `Valid<Json<T>>`, `Valid<Query<T>>` และ `Valid<Form<T>>` ให้ใช้
- **axum-validated-extractors** มี `ValidatedJson`, `ValidatedQuery` และ `ValidatedForm` ให้พร้อมใช้ได้ทันที

crate เหล่านี้ช่วยคุณประหยัด boilerplate ที่เราเขียนกันข้างบนได้ ถึงอย่างนั้น ผมมักจะชอบเขียนเองมากกว่า เพราะช่วยให้เราควบคุมรูปแบบและพฤติกรรมของข้อผิดพลาดได้เต็มที่ ซึ่งสำคัญมากเมื่อคุณต้องการกำหนดมาตรฐานการตอบกลับข้อผิดพลาดของ API ให้ตรงใจ (และเชื่อเถอะว่าคุณจะต้องอยากปรับแน่นอน)

## การตรวจสอบความถูกต้องสองระดับ

ก่อนจะไปต่อ ผมอยากเน้นย้ำความแตกต่างระหว่างการตรวจสอบความถูกต้องที่ระดับ API layer กับ Domain layer ให้ชัดเจนมาก เพราะการเอาทั้งสองมารวมปนกันมักนำไปสู่ตรรกะซ้ำซ้อนหรือเกิดช่องโหว่ในระบบรักษาความปลอดภัยของคุณ ผมเคยเห็นทั้งสองแบบมาแล้ว และไม่มีแบบไหนที่ตามแก้ได้สนุกเลย

**การตรวจสอบความถูกต้องที่ระดับ API layer** (สิ่งที่เรากล่าวถึงในบทนี้) จะตรวจสอบโครงสร้างและรูปแบบของอินพุต: ฟิลด์ที่จำเป็นมีครบไหม? ความยาวสตริงถูกต้องตามเกณฑ์ไหม? ฟิลด์อีเมลดูเหมือนอีเมลจริงไหม? ทั้งหมดนี้เป็นเรื่องของรูปแบบข้อมูลตอนที่เดินทางมาถึงผ่านเครือข่าย (over the wire)

**การตรวจสอบความถูกต้องที่ระดับ Domain layer** (ซึ่งเรากล่าวถึงในบท [การสร้างแบบจำลองโดเมน](./domain-modeling.md)) จะทำหน้าที่บังคับใช้กฎเกณฑ์และเงื่อนไขทางธุรกิจ (business invariants): เช่น ชื่อผู้ใช้ต้องไม่มีอักขระต้องห้าม, อีเมลต้องถูกแปลงเป็นตัวพิมพ์เล็กทั้งหมด, ยอดเงินของออเดอร์ต้องเป็นบวก การตรวจสอบความถูกต้องนี้จะเกิดขึ้นตอนที่คุณสร้างชนิดข้อมูลโดเมน เช่น `UserName::parse()` หรือ `Email::parse()`

การตรวจสอบทั้งสองระดับนี้ทำงานประสานกันได้อย่างลงตัว API layer จะช่วยสกัดอินพุตที่ผิดรูปแบบอย่างชัดเจนได้ตั้งแต่เนิ่นๆ พร้อมส่งข้อความแจ้งข้อผิดพลาดที่เป็นประโยชน์ ส่วน Domain layer จะรับประกันว่ากฎทางธุรกิจถูกบังคับใช้อย่างสม่ำเสมอ ไม่ว่าข้อมูลจะมาจากคำขอ HTTP, คิวข้อความ, การนำเข้าไฟล์ CSV หรือชุดทดสอบ และเมื่อมีครบทั้งสองระดับ เราก็จะมีรากฐานที่แข็งแกร่งสำหรับแพตเทิร์นการจัดการข้อผิดพลาดที่เราจะดูกันต่อไป

