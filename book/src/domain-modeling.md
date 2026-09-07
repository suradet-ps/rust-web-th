# การสร้างแบบจำลองโดเมน

ถ้าคุณเคยทำงานบนโค้ดเบสที่มีขนาดจริงจังสักหน่อย คุณอาจเคยเจอเหตุการณ์ทำนองนี้: ฟังก์ชันหนึ่งรับพารามิเตอร์ประเภท `String` 3 ตัว แต่มีคนเผลอสลับตำแหน่งของ 2 ตัวเข้าด้วยกัน และไม่มีใครสังเกตเห็นจนกระทั่งผู้ใช้ได้รับอีเมลที่มีเนื้อหาสับสนปนเป ผมเคยเจอบั๊กแบบนี้บนระบบ production มามากกว่าหนึ่งครั้ง และมันเป็นความผิดพลาดประเภทที่ทำให้คุณนึกอยากให้คอมไพเลอร์ช่วยตรวจจับให้ได้ตั้งแต่แรก

ข่าวดีก็คือ ในภาษา Rust เราสามารถทำเช่นนั้นได้จริง ระบบชนิดข้อมูลของ Rust มีพลังมากพอที่เราจะฝังกฎเกณฑ์ของโดเมนลงไปในชนิดข้อมูลได้โดยตรง เพื่อให้คอมไพเลอร์ปฏิเสธข้อมูลที่ไม่ถูกต้องตั้งแต่ก่อนที่โค้ดจะได้เริ่มทำงานเสียด้วยซ้ำ บทนี้จะพาคุณไปดูแพตเทิร์นต่างๆ ที่จะช่วยเปลี่ยนแนวคิดนี้ให้กลายเป็นจริงในทางปฏิบัติ

แนวคิดหลักนี้หยิบยืมมาจากโลกของการเขียนโปรแกรมเชิงฟังก์ชัน (functional programming): **parse, don't validate** (แยกวิเคราะห์เพื่อสร้างชนิดข้อมูล แทนที่จะเป็นเพียงแค่การตรวจเช็ก) แทนที่จะยอมรับสตริงดิบๆ เข้ามาแล้วโปรยคำสั่งตรวจเช็กแบบ boolean กระจายอยู่ทั่วทุกที่ เราจะนิยามชนิดข้อมูลขึ้นมาใหม่ที่รับประกันว่าจะถูกสร้างขึ้นมาจากข้อมูลที่ถูกต้องเท่านั้น และเมื่อคุณถือตัวแปรชนิดนั้นไว้ในมือ คุณก็มั่นใจได้ทันทีว่ามันถูกต้องเสมอโดยไม่ต้องเสียเวลาตรวจสอบซ้ำอีกต่อไป

## แพตเทิร์น newtype

นิวไทป์ (newtype) คือ struct ที่ทำหน้าที่ห่อหุ้มค่าเพียงค่าเดียวไว้ข้างใน ในระหว่างรันไทม์มันมี overhead เป็นศูนย์อย่างแท้จริง เพราะคอมไพเลอร์จะจัดการกับมันเหมือนกับค่าที่อยู่ข้างในโดยตรง แต่ในขั้นตอนการคอมไพล์ มันจะถูกมองว่าเป็นชนิดข้อมูลที่แตกต่างกันโดยสิ้นเชิง ซึ่งหมายความว่าคอมไพเลอร์จะปฏิเสธทันทีหากมีความพยายามนำค่าชนิดหนึ่งไปใส่ในตำแหน่งที่คาดหวังอีกชนิดหนึ่ง ซึ่งถือเป็นข้อแลกเปลี่ยนที่คุ้มค่าอย่างยิ่ง

ผมขอแสดงตัวอย่างให้เห็นภาพชัดเจนขึ้น สมมติว่าแอปพลิเคชันของคุณต้องทำงานกับที่อยู่อีเมล คุณอาจเลือกใช้ `String` แทนค่าอีเมลในทุกๆ ที่ แต่วิธีนั้นไม่ได้บอกอะไรแก่คอมไพเลอร์ (และเพื่อนร่วมทีมที่มาอ่านโค้ด) เลยว่าสตริงนั้นคือข้อมูลประเภทใด ฟังก์ชันที่รับพารามิเตอร์ `(String, String)` สำหรับชื่อและอีเมลจึงอาจถูกเรียกใช้งานโดยสลับลำดับอาร์กิวเมนต์ได้ง่ายดาย และคงไม่มีใครรู้ตัวจนกระทั่งผู้ใช้ได้รับอีเมลที่ส่งถึง "alice@example.com" พร้อมคำขึ้นต้นว่า "Dear Alice Johnson" ซึ่งผมเองก็เคยเจอปัญหานี้มาแล้วกับตัว

```rust
#[derive(Debug, Clone, PartialEq, Eq, Hash)]
pub struct Email(String);

impl Email {
    /// WARNING: This is a simplified validator for illustration only.
    /// In production, use a proper email validation library or at minimum
    /// a well-tested regex. The `validator` crate's `#[validate(email)]`
    /// attribute handles this at the DTO layer; this constructor is for
    /// the domain layer where you want the type itself to guarantee validity.
    pub fn parse(raw: &str) -> Result<Self, DomainError> {
        let trimmed = raw.trim().to_lowercase();
        if trimmed.contains('@') && trimmed.len() >= 3 {
            Ok(Self(trimmed))
        } else {
            Err(DomainError::InvalidEmail(raw.to_string()))
        }
    }

    pub fn as_str(&self) -> &str {
        &self.0
    }
}

impl AsRef<str> for Email {
    fn as_ref(&self) -> &str {
        &self.0
    }
}
```

มีประเด็นสำคัญหลายจุดที่ควรสังเกตจากโค้ดข้างต้น:

ฟิลด์ `String` ภายในถูกกำหนดให้เป็น **private** ทำให้ไม่มีทางสร้าง instance ของ `Email` ขึ้นมาได้เลยนอกจากต้องผ่านคอนสตรักเตอร์ `parse` เท่านั้น ซึ่งจุดนี้ทำหน้าที่เป็นตัวบังคับใช้เงื่อนไขคงสภาพ (invariant) ของเรา และไม่มีทางที่จะขอ mutable reference เข้าไปแก้ไขสตริงด้านในได้โดยตรง เงื่อนไขความถูกต้องจึงไม่มีทางถูกละเมิดหลังจากที่ออบเจกต์ถูกสร้างขึ้นมาแล้ว และนั่นคือหัวใจสำคัญของเทคนิคนี้

เมธอด `parse` จะส่งผลลัพธ์กลับมาเป็น `Result` ซึ่งสะท้อนถึงคำว่า "parse" ในหลักการ "parse, don't validate" กล่าวคือ มันจะส่งคืน instance ของ `Email` ที่ผ่านการรับประกันความถูกต้องแล้ว หรือไม่ก็ส่งคืนข้อผิดพลาดที่ระบุชัดเจนว่าเหตุใดข้อมูลอินพุตจึงถูกปฏิเสธ เมื่อคุณมีออบเจกต์ `Email` อยู่ในมือแล้ว คุณจึงมั่นใจได้ทันทีในความถูกต้องของมันโดยไม่จำเป็นต้องตรวจสอบซ้ำอีกเมื่อส่งต่อไปยังฟังก์ชันอื่น ซึ่งเป็นคุณสมบัติที่ช่วยลดความผิดพลาดได้อย่างมหาศาล

การอิมพลีเมนต์ `AsRef<str>` ช่วยให้ชนิดข้อมูลนี้สามารถนำไปใช้งานร่วมกับฟังก์ชันต่างๆ ที่ต้องการสตริงอ้างอิงได้อย่างสะดวก เช่น การจัดรูปแบบข้อความ หรือการนำไปใช้ในคิวรีฐานข้อมูล โดยยังคงความปลอดภัยและไม่เปิดโอกาสให้มีการแก้ไขค่าภายในได้

## การสร้างคำศัพท์ของชนิดข้อมูลโดเมน

เมื่อคุณเริ่มคุ้นเคยกับแพตเทิร์น newtype แล้ว ผมแนะนำให้นำไปปรับใช้กับทุกแนวคิดที่มีความหมายในโดเมนของคุณ ในช่วงแรกอาจรู้สึกเหมือนมีขั้นตอนพิธีรีตองเพิ่มขึ้นมาบ้าง แต่เชื่อเถอะว่ามันจะให้ผลตอบแทนที่คุ้มค่าอย่างรวดเร็วแน่นอน นี่คือตัวอย่างชุดชนิดข้อมูลโดเมนสำหรับระบบบริหารจัดการผู้ใช้:

```rust
#[derive(Debug, Clone, PartialEq, Eq, Hash)]
pub struct UserId(Uuid);

impl UserId {
    pub fn new() -> Self {
        Self(Uuid::new_v4())
    }

    pub fn from_uuid(id: Uuid) -> Self {
        Self(id)
    }

    pub fn as_uuid(&self) -> &Uuid {
        &self.0
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct UserName(String);

impl UserName {
    pub fn parse(raw: &str) -> Result<Self, DomainError> {
        let trimmed = raw.trim();
        if trimmed.is_empty() {
            return Err(DomainError::EmptyName);
        }
        if trimmed.len() > 100 {
            return Err(DomainError::NameTooLong);
        }
        // Reject characters that could cause problems in downstream systems
        let forbidden = ['/', '(', ')', '"', '<', '>', '\\', '{', '}'];
        if trimmed.chars().any(|c| forbidden.contains(&c)) {
            return Err(DomainError::NameContainsForbiddenCharacters);
        }
        Ok(Self(trimmed.to_string()))
    }

    pub fn as_str(&self) -> &str {
        &self.0
    }
}
```

ทีนี้ลองมาดูความเปลี่ยนแปลงที่เกิดขึ้นกับ function signature ของเรากันครับ:

```rust
// Before: what is the first String? The second? Who knows.
fn create_user(name: String, email: String) -> Result<User, Error> { ... }

// After: the types make it self-documenting and impossible to mix up.
fn create_user(name: UserName, email: Email) -> Result<User, CreateUserError> { ... }
```

ฟังก์ชันในเวอร์ชันหลังไม่เพียงแค่อ่านเข้าใจได้ง่ายและชัดเจนขึ้นเท่านั้น แต่ยังเป็นไปไม่ได้เลยในทางกายภาพที่จะส่งอาร์กิวเมนต์สลับลำดับกัน เพราะคอมไพเลอร์จะปฏิเสธโค้ดนั้นในทันที นี่คือสิ่งที่ผมหลงรักในภาษา Rust: คุณสามารถทำให้บั๊กทั้งหมวดหมู่กลายเป็นสิ่งที่ไม่สามารถเกิดขึ้นได้ในโค้ด (unrepresentable) โดยไม่ต้องรอให้ "ถูกตรวจพบโดยชุดทดสอบ" หรือ "ถูกทักท้วงในการรีวิวโค้ด" แต่มันไม่สามารถถูกเขียนออกมาได้ตั้งแต่แรกเลยต่างหาก

## เอนทิตีของโดเมน

เอนทิตี (Entity) คือออบเจกต์ของโดเมนที่มีเอกลักษณ์ประจำตัวชัดเจน (โดยทั่วไปคือรหัส ID) และมีวงจรชีวิต (lifecycle) ของตัวเอง ลองนึกถึงสิ่งที่มีตัวตนคงอยู่ในระบบของคุณ เช่น ผู้ใช้หนึ่งคน, คำสั่งซื้อหนึ่งรายการ หรือบทความบล็อกหนึ่งเรื่อง สิ่งเหล่านี้คือเอนทิตีของระบบ และมักจะเป็นคำนามเดียวกับที่ทีมงานฝ่ายผลิตภัณฑ์ใช้เรียกในการพูดคุยกันอยู่เสมอ

```rust
#[derive(Debug, Clone)]
pub struct User {
    id: UserId,
    name: UserName,
    email: Email,
    created_at: DateTime<Utc>,
    updated_at: DateTime<Utc>,
}

impl User {
    /// Used by the repository layer when hydrating from the database.
    pub fn hydrate(
        id: UserId,
        name: UserName,
        email: Email,
        created_at: DateTime<Utc>,
        updated_at: DateTime<Utc>,
    ) -> Self {
        Self { id, name, email, created_at, updated_at }
    }

    pub fn id(&self) -> &UserId { &self.id }
    pub fn name(&self) -> &UserName { &self.name }
    pub fn email(&self) -> &Email { &self.email }
    pub fn created_at(&self) -> DateTime<Utc> { self.created_at }
    pub fn updated_at(&self) -> DateTime<Utc> { self.updated_at }
}
```

สังเกตว่าฟิลด์ทั้งหมดถูกตั้งค่าให้เป็นแบบ private และ struct จะเปิดเผยเพียงเมธอดประเภท getter ที่คืนการอ้างอิงเท่านั้น ซึ่งนี่เป็นความตั้งใจในการออกแบบ เพราะหากเราต้องการปรับปรุงชื่อของผู้ใช้ การกระทำนั้นควรเกิดขึ้นผ่านเมธอดบนตัวเอนทิตี (หรือผ่านเซอร์วิส) ที่สามารถบังคับใช้กฎเกณฑ์ใดๆ ที่เกี่ยวข้องกับการเปลี่ยนชื่อได้อย่างครบถ้วน เราไม่ต้องการเปิดโอกาสให้โค้ดส่วนอื่นตามใจชอบสามารถเอื้อมเข้ามาแก้ไขค่าของฟิลด์ได้โดยตรง เพราะผมเคยเจ็บปวดกับพฤติกรรมลักษณะนี้ในภาษาอื่นมามากพอจนเกิดความระมัดระวังเป็นพิเศษ

## ชนิดข้อมูลคำขอกับชนิดข้อมูลเอนทิตี

นี่คือแพตเทิร์นที่เมื่อเห็นแล้วอาจดูเหมือนเป็นเรื่องธรรมดา แต่ผมเคยเห็นหลายทีมมองข้ามแล้วต้องมานั่งเสียใจในภายหลัง ข้อมูลที่คุณจำเป็นต้องใช้ในการ **สร้าง** สิ่งของชิ้นหนึ่ง ย่อมไม่เหมือนกับตัวตนของสิ่งของชิ้นนั้นเอง เช่น `CreateUserRequest` จะประกอบด้วย ชื่อ, อีเมล และรหัสผ่านดิบ ขณะที่ตัวตนของ `User` จะมีรหัส ID, ข้อมูลเวลา และไม่มีรหัสผ่านดิบอยู่เลย (จะเก็บเพียงค่าแฮชเท่านั้น) ข้อมูลทั้งสองชุดนี้เป็นแนวคิดที่แตกต่างกันโดยสิ้นเชิง จึงควรแยกเป็นชนิดข้อมูลคนละตัวกัน

```rust
/// The data needed to register a new user.
/// All fields have already been parsed into domain types.
pub struct CreateUserRequest {
    pub name: UserName,
    pub email: Email,
    pub password_hash: String,
}
```

ชนิดข้อมูลนี้จะอาศัยอยู่ในเลเยอร์โดเมน โดยแยกขาดจาก DTO ของคำขอ HTTP (ซึ่งอยู่ในเลเยอร์ API) และแยกจากโครงสร้างแถวข้อมูลในฐานข้อมูล (ซึ่งอยู่ในเลเยอร์อินฟราสตรักเจอร์) แต่ละเลเยอร์จะมีชนิดข้อมูลเป็นของตัวเองอย่างชัดเจน และการแปลงข้อมูลข้ามขอบเขตอย่างเปิดเผยจะช่วยรักษาให้เส้นแบ่งเลเยอร์มีความสะอาดหมดจด จริงอยู่ที่วิธีนี้อาจทำให้มี struct ให้ต้องดูแลเพิ่มขึ้น แต่คุณจะรู้สึกขอบคุณตัวเองทันที เมื่อถึงวันที่ต้องปรับแก้รูปแบบการตอบกลับของ API โดยไม่ต้องไปแตะต้องสกีมาของฐานข้อมูลเลยแม้แต่น้อย

## การแปลงระหว่างเลเยอร์

เมื่อเรามีชนิดข้อมูลที่แยกเฉพาะในแต่ละเลเยอร์ เราจึงจำเป็นต้องแปลงข้อมูลข้ามไปมาระหว่างเลเยอร์ที่บริเวณขอบเขตของมัน ในภาษา Rust การอิมพลีเมนต์ trait มาตรฐานอย่าง `From` และ `TryFrom` ถือเป็นแนวทางที่เป็นธรรมชาติและทรงพลังที่สุดในการจัดการเรื่องนี้

```rust
// Database row type (lives in infra layer)
#[derive(sqlx::FromRow)]
pub struct UserRow {
    pub id: Uuid,
    pub name: String,
    pub email: String,
    pub password_hash: String,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

// Convert from database row to domain entity.
// Using TryFrom rather than From because database values may not satisfy
// current domain invariants: legacy rows, manual SQL fixes, schema migrations,
// and previous bugs can all produce data that would fail validation today.
impl TryFrom<UserRow> for User {
    type Error = anyhow::Error;

    fn try_from(row: UserRow) -> Result<Self, Self::Error> {
        Ok(User::hydrate(
            UserId::from_uuid(row.id),
            UserName::parse(&row.name)
                .map_err(|e| anyhow::anyhow!("corrupt user name in row {}: {}", row.id, e))?,
            Email::parse(&row.email)
                .map_err(|e| anyhow::anyhow!("corrupt email in row {}: {}", row.id, e))?,
            row.created_at,
            row.updated_at,
        ))
    }
}

// API response type (lives in api layer)
#[derive(Serialize)]
pub struct UserResponse {
    pub id: Uuid,
    pub name: String,
    pub email: String,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

// Convert from domain entity to API response
impl From<User> for UserResponse {
    fn from(user: User) -> Self {
        Self {
            id: *user.id().as_uuid(),
            name: user.name().as_str().to_string(),
            email: user.email().as_str().to_string(),
            created_at: user.created_at(),
            updated_at: user.updated_at(),
        }
    }
}
```

สังเกตว่าชนิดข้อมูลในการตอบกลับของ API นั้น **ไม่ได้รวมฟิลด์แฮชของรหัสผ่านเข้าไปด้วย** นี่คือหนึ่งในจุดเด่นที่ผมประทับใจที่สุดของการแยกชนิดข้อมูลตามขอบเขต: คุณไม่มีทางที่จะเผลอทำข้อมูลที่มีความอ่อนไหวรั่วไหลออกไปสู่การตอบกลับของ API ได้เลย เพราะ struct นั้นไม่มีฟิลด์ดังกล่าวตั้งแต่แรกแล้วนั่นเอง โดยไม่ต้องคอยพึ่งพาการรีวิวโค้ด หรือต้องคอยจำกฎของ linter แต่อย่างใด

## ข้อผิดพลาดของโดเมน

ข้อผิดพลาดที่เกิดขึ้นในระดับโดเมนควรอธิบายความล้มเหลวในเชิงของตรรกะทางธุรกิจ ไม่ใช่ความล้มเหลวในระดับอินฟราสตรักเจอร์ โดเมนควรเข้าใจความหมายของ "ผู้ใช้นี้มีอยู่ในระบบแล้ว" หรือ "รูปแบบของอีเมลไม่ถูกต้อง" แต่ไม่ควร (และไม่มีความจำเป็นต้อง) ไปรับรู้เรื่อง "SQL unique constraint violation" หรือ "HTTP 409 Conflict" หากคุณพบว่าตัวเองกำลัง import ชนิดข้อมูลของ `sqlx` หรือ `axum` เข้ามาใน enum ข้อผิดพลาดของโดเมน แสดงว่าโครงสร้างสถาปัตยกรรมเริ่มมีจุดผิดเพี้ยนเกิดขึ้นแล้ว

```rust
#[derive(Debug, thiserror::Error)]
pub enum DomainError {
    #[error("invalid email address: {0}")]
    InvalidEmail(String),

    #[error("name cannot be empty")]
    EmptyName,

    #[error("name exceeds maximum length")]
    NameTooLong,

    #[error("name contains forbidden characters")]
    NameContainsForbiddenCharacters,
}

#[derive(Debug, thiserror::Error)]
pub enum CreateUserError {
    #[error("a user with email {email} already exists")]
    Duplicate { email: Email },

    #[error(transparent)]
    Unknown(#[from] anyhow::Error),
}
```

วาเรียนต์ `CreateUserError::Unknown` ใช้ `anyhow::Error` เป็นตัวรับข้อผิดพลาดแบบครอบคลุม (catch-all) สำหรับความล้มเหลวที่ไม่คาดคิด ช่วยให้เลเยอร์อินฟราสตรักเจอร์สามารถแปลงข้อผิดพลาดทั่วไป (เช่น ฐานข้อมูลเกิด connection timeout) ให้กลายเป็นข้อผิดพลาดของโดเมนได้ โดยที่โดเมนไม่จำเป็นต้องระบุรายการข้อผิดพลาดที่เป็นไปได้ทั้งหมด จากนั้นเลเยอร์ API จะทำหน้าที่แมป `Unknown` ไปเป็นการตอบกลับ HTTP 500 สำหรับฝั่งผู้ใช้ พร้อมทั้งบันทึกรายละเอียดข้อผิดพลาดทั้งหมดไว้ในล็อกฝั่งเซิร์ฟเวอร์ คุณอาจสงสัยว่าการทำเช่นนี้จะหลวมเกินไปหรือไม่ แต่จากประสบการณ์ของผม นี่คือจุดที่ช่วยสร้างสมดุลได้อย่างลงตัว: ข้อผิดพลาดที่คาดการณ์ได้จะถูกระบุชนิดข้อมูลอย่างชัดเจน ขณะที่ข้อผิดพลาดที่ไม่คาดคิดก็ยังคงได้รับการจัดการอย่างนุ่มนวล

## การรวมทุกอย่างเข้าด้วยกัน

เราลองมาติดตามเส้นทางการเดินทางของข้อมูลแบบสมบูรณ์ ตั้งแต่คำขอ HTTP ถูกส่งเข้ามา เดินทางไปยังฐานข้อมูล และส่งผลลัพธ์กลับออกไป เพื่อให้เห็นว่าชนิดข้อมูลมีการแปลงรูปข้ามแต่ละขอบเขตอย่างไร:

```
HTTP POST /api/users
  { "name": "Alice", "email": "alice@example.com", "password": "hunter2" }

  ↓ Axum deserializes into CreateUserDto (api/dtos)
  ↓ Handler parses fields into domain types: UserName, Email
  ↓ Handler calls user_service.register(name, email, &password)

  ↓ Service hashes password, builds CreateUserRequest (domain)
  ↓ Service calls repo.create(&request)

  ↓ Repository converts to SQL, executes INSERT
  ↓ Repository gets UserRow back from the database
  ↓ Repository converts UserRow into User (domain entity)

  ↑ Service returns User to handler
  ↑ Handler converts User into UserResponse (api/dtos)
  ↑ Handler returns (StatusCode::CREATED, Json(response))

HTTP 201 Created
  { "id": "...", "name": "Alice", "email": "alice@example.com", ... }
```

ในทุกๆ ขอบเขต ข้อมูลจะถูกแปลงไปเป็นชนิดข้อมูลที่สังกัดอยู่ในเลเยอร์นั้นๆ เลเยอร์ API จัดการเฉพาะ DTO, เลเยอร์โดเมนจัดการเฉพาะชนิดข้อมูลโดเมน, และเลเยอร์อินฟราสตรักเจอร์จัดการเฉพาะโครงสร้างแถวข้อมูลของฐานข้อมูล การแปลงข้อมูลระหว่างเลเยอร์เหล่านี้มีความโปร่งใส ตรวจสอบย้อนกลับได้ และถูกตรวจสอบอย่างเข้มงวดโดยคอมไพเลอร์

ผมเข้าใจดีว่าแนวทางนี้อาจรู้สึกเหมือนมีขั้นตอนซ้ำซ้อนเมื่อเทียบกับการใช้ struct ตัวเดียวส่งต่อลุยไปตลอดทั้งกระบวนการ ซึ่งผมเองก็เคยรู้สึกเช่นนั้นในตอนเริ่มต้น แต่สิ่งที่ผมได้เรียนรู้จากการทำงานจริงคือ: เวลาที่คุณต้องการเพิ่มฟิลด์ใน API response คุณแค่แก้ที่ DTO, เวลาที่คุณต้องการเพิ่มคอลัมน์ในฐานข้อมูล คุณแค่แก้ที่ row type, และเวลาที่คุณมีกฎทางธุรกิจใหม่ๆ คุณก็ปรับที่ชนิดข้อมูลของโดเมน การเปลี่ยนแปลงแต่ละอย่างจะถูกจำกัดวงอยู่เฉพาะในเลเยอร์ของตัวเองอย่างชัดเจน และโค้ดการอิมพลีเมนต์ `From` จะทำหน้าที่เป็นเอกสารบอกเราอย่างตรงไปตรงมาว่าแต่ละเลเยอร์เชื่อมโยงกันอย่างไร เมื่อคุณได้สัมผัสกับความสงบเรียบร้อยแบบนี้ในโปรเจกต์ที่มีขนาดเกินสองสามพันบรรทัดขึ้นไปแล้ว คุณจะไม่อยากหวนกลับไปใช้วิธีเดิมๆ อีกเลยครับ
