# การสร้างแบบจำลองโดเมน

ถ้าคุณเคยทำงานบนโค้ดเบสที่มีขนาดจริงจังสักหน่อย คุณอาจเคยเจอเหตุการณ์แบบนี้: ฟังก์ชันหนึ่งรับพารามิเตอร์ `String` สามตัว มีคนสลับตำแหน่งสองตัวเข้าด้วยกัน และคุณก็ไม่รู้ตัวจนกว่าผู้ใช้คนหนึ่งจะได้รับอีเมลที่สับสนมาก ผมเคยเจอบั๊กแบบนี้ในระบบ production มากกว่าหนึ่งครั้ง และมันเป็นเรื่องแบบที่ทำให้คุณอยากให้คอมไพเลอร์จับมันได้เอง

ข่าวดีก็คือ ใน Rust มันทำได้ ระบบชนิดข้อมูลของ Rust มีพลังมากพอที่เราจะเข้ารหัสกฎของโดเมนลงในชนิดข้อมูลได้โดยตรง เพื่อให้คอมไพเลอร์ปฏิเสธข้อมูลที่ไม่ถูกต้องก่อนที่โค้ดของเราจะได้รันเสียอีก บทนี้จะพาคุณเดินผ่านแพตเทิร์นต่างๆ ที่ทำให้สิ่งนี้เป็นจริง

แนวคิดหลักมาจากโลกการเขียนโปรแกรมเชิงฟังก์ชัน: **parse, don't validate** (แยกวิเคราะห์ อย่าแค่ตรวจสอบ) แทนที่จะยอมรับสตริงดิบๆ แล้วโปรยการตรวจสอบแบบ boolean ไปทั่วทุกที่ เรากำหนดชนิดข้อมูลที่สร้างขึ้นจากข้อมูลที่ถูกต้องเท่านั้น เมื่อคุณมีค่าในชนิดข้อมูลนั้นแล้ว คุณก็รู้ว่ามันถูกต้อง ไม่ต้องตรวจสอบซ้ำอีก

## แพตเทิร์นนิวนิวไทป์

นิวนิวไทป์ก็คือ struct ที่ห่อค่าเพียงค่าเดียวเท่านั้น ในตอนรันไทม์มันมีโอเวอร์เฮดเป็นศูนย์ คอมไพเลอร์ปฏิบัติต่อมันเหมือนกับค่าที่อยู่ข้างใน แต่ในตอนคอมไพล์มันเป็นชนิดข้อมูลที่แตกต่างกันโดยสิ้นเชิง ซึ่งหมายความว่าคอมไพเลอร์จะปฏิเสธความพยายามใช้ชนิดหนึ่งในที่ที่คาดหวังอีกชนิดหนึ่ง นั่นเป็นข้อตกลงที่คุ้มมาก

ให้ผมแสดงให้คุณเห็นว่าผมหมายถึงอะไร สมมติว่าแอปพลิเคชันของคุณทำงานกับที่อยู่อีเมล คุณอาจแทนมันด้วย `String` ไปทุกที่ แต่แบบนั้นไม่ได้บอกคอมไพเลอร์ (และผู้อ่านโค้ด) ว่ามันเป็นสตริงประเภทไหน ฟังก์ชันที่รับ `(String, String)` สำหรับชื่อและอีเมลสามารถถูกเรียกโดยสลับอาร์กิวเมนต์ได้ และจะไม่มีใครสังเกตจนกว่าผู้ใช้จะได้รับอีเมลที่ส่งถึง "alice@example.com" โดยมีหัวข้อว่า "Dear Alice Johnson" ถามผมดูสิว่าผมรู้ได้ยังไง

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

มีสองสามจุดที่ควรชี้ให้เห็นตรงนี้

ฟิลด์ `String` ด้านในเป็นแบบ **private** ไม่มีทางสร้าง `Email` ได้นอกจากผ่าน `parse` ซึ่งเป็นตัวบังคับใช้ค่าคงที่ (invariant) ของเรา และไม่มีทางได้การอ้างอิงแบบ mut ได้ไปยังสตริงด้านใน ดังนั้นค่าคงที่จึงไม่สามารถถูกละเมิดได้หลังจากการสร้างเสร็จ นั่นคือเคล็ดลับทั้งหมด

เมธอด `parse` คืนค่าเป็น `Result` และนี่คือคำว่า "parse" ในคำว่า "parse, don't validate" มันจะให้ `Email` ที่ถูกต้องกลับคืนมาหรือไม่ก็ข้อผิดพลาดที่อธิบายว่าทำไมอินพุตถึงถูกปฏิเสธ เมื่อคุณมี `Email` แล้ว คุณก็รู้ว่ามันถูกต้อง คุณไม่จำเป็นต้องตรวจสอบมันซ้ำอีกเมื่อส่งต่อไปยังฟังก์ชันอื่น ซึ่งเป็นคุณสมบัติที่ดีมาก

การอิมพลีเมนต์ `AsRef<str>` ทำให้ชนิดข้อมูลนี้ใช้งานง่ายในบริบทที่รับการอ้างอิงสตริง เช่น การจัดรูปแบบหรือควิวรีฐานข้อมูล โดยไม่เปิดเผยความสามารถในการแก้ไขค่าด้านใน

## การสร้างคำศัพท์ของชนิดข้อมูลโดเมน

เมื่อคุณจับแพตเทิร์นนิวนิวไทป์ได้แล้ว ผมอยากให้คุณนำไปใช้กับทุกแนวคิดที่มีความหมายในโดเมนของคุณ ตอนแรกอาจรู้สึกเป็นพิธีกรรมเยอะไปหน่อย แต่ก็ให้ผลตอบแทนเร็วมาก นี่คือหน้าตาของชุดชนิดข้อมูลโดเมนสำหรับระบบจัดการผู้ใช้:

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

ทีนี้ลองดูว่าเกิดอะไรขึ้นกับลายเซ็นฟังก์ชันของเรา:

```rust
// Before: what is the first String? The second? Who knows.
fn create_user(name: String, email: String) -> Result<User, Error> { ... }

// After: the types make it self-documenting and impossible to mix up.
fn create_user(name: UserName, email: Email) -> Result<User, CreateUserError> { ... }
```

เวอร์ชันที่สองไม่ได้แค่อ่านง่ายขึ้น มันเป็นไปไม่ได้ในเชิงกายภาพที่จะเรียกมันโดยเรียงอาร์กิวเมนต์ผิดลำดับ คอมไพเลอร์จะปฏิเสธมัน ผมรักเรื่องนี้ของ Rust: คุณสามารถทำให้บั๊กทั้งหมวดหมู่กลายเป็นสิ่งที่ไม่สามารถแทนค่าได้ (unrepresentable) ไม่ใช่ "ถูกจับได้โดยการทดสอบ" ไม่ใช่ "ถูกจับได้ในการรีวิวโค้ด" แต่เป็นสิ่งที่ไม่สามารถเขียนออกมาได้จริงๆ

## เอนทิตีของโดเมน

เอนทิตีคือออบเจกต์ของโดเมนที่มีเอกลักษณ์ (โดยปกติคือ ID) และไลฟ์ไซเคิล ลองนึกถึงสิ่งที่คงอยู่ในระบบของคุณ: ผู้ใช้หนึ่งคน คำสั่งซื้อหนึ่งรายการ โพสต์บล็อกหนึ่งโพสต์ สิ่งเหล่านี้คือเอนทิตีของคุณ และมันมักเป็นคำนามที่ทีมผลิตภัณฑ์ของคุณพูดถึงอยู่แล้ว

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

สังเกตว่าฟิลด์เป็นแบบ private และ struct เปิดเผยเฉพาะเมธอด getter ที่คืนการอ้างอิงเท่านั้น นี่เป็นความตั้งใจ ถ้าเราต้องการอัปเดตชื่อของผู้ใช้ สิ่งนั้นควรผ่านเมธอดบนเอนทิตี (หรือเซอร์วิส) ที่สามารถบังคับใช้กฎใดๆ ก็ตามที่เกี่ยวข้องกับการเปลี่ยนชื่อ เราไม่ต้องการให้โค้ดตามอำเภอใจเอื้อมเข้ามาแล้วแก้ไขฟิลด์โดยตรง ผมโดนแบบนั้นมามากพอในภาษาอื่นจนรู้สึกระแวงนิดหน่อย

## ชนิดข้อมูลคำขอกับชนิดข้อมูลเอนทิตี

นี่คือแพตเทิร์นที่พอเห็นแล้วอาจดูชัดเจน แต่ผมเคยเห็นทีมข้ามมันไปแล้วมานั่งเสียใจทีหลัง ข้อมูลที่คุณต้องใช้เพื่อ **สร้าง** บางสิ่งไม่เหมือนกับตัวสิ่งนั้นเอง `CreateUserRequest` ประกอบด้วยชื่อ อีเมล และรหัสผ่าน ส่วน `User` มี ID ตัวบอกเวลา และไม่มีรหัสผ่าน (มันเก็บแฮชแทน) สิ่งเหล่านี้เป็นแนวคิดที่ต่างกัน ดังนั้นจึงควรเป็นชนิดข้อมูลที่ต่างกัน

```rust
/// The data needed to register a new user.
/// All fields have already been parsed into domain types.
pub struct CreateUserRequest {
    pub name: UserName,
    pub email: Email,
    pub password_hash: String,
}
```

ชนิดข้อมูลนี้อยู่ในเลเยอร์โดเมน มันแยกจาก DTO ของคำขอ HTTP (ซึ่งอยู่ในเลเยอร์ API) และแยกจากแถวฐานข้อมูล (ซึ่งอยู่ในเลเยอร์อินฟราสตรัคเจอร์) แต่ละเลเยอร์ได้ชนิดข้อมูลของตัวเอง และการแปลงอย่างชัดเจนระหว่างมันช่วยให้ขอบเขตสะอาด ใช่ มันมีชนิดข้อมูลให้ดูแลมากขึ้น แต่คุณจะขอบคุณตัวเองในครั้งแรกที่ต้องเปลี่ยนการตอบกลับของ API โดยไม่ต้องแตะสกีมาฐานข้อมูล

## การแปลงระหว่างเลเยอร์

เราจึงมีชนิดข้อมูลที่ต่างกันในแต่ละเลเยอร์ ซึ่งหมายความว่าเราจำเป็นต้องแปลงระหว่างมันที่ขอบเขต เทรต `From` และ `TryFrom` คือวิธีที่เป็นธรรมชาติที่สุดในการทำสิ่งนี้ใน Rust และมันทำงานได้ดีมากสำหรับจุดประสงค์นี้

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

สังเกตว่าชนิดข้อมูลการตอบกลับ **ไม่รวมแฮชของรหัสผ่าน** นี่คือหนึ่งในสิ่งที่ผมชอบที่สุดเกี่ยวกับการมีชนิดข้อมูลแยกกันสำหรับแต่ละขอบเขต: คุณไม่สามารถรั่วข้อมูลอ่อนไหวเข้าไปในการตอบกลับของ API ได้จริงๆ เพราะชนิดข้อมูลการตอบกลับไม่มีฟิลด์นั้น ไม่ต้องรีวิวโค้ดเพื่อจับมัน ไม่มีกฎของ linter ที่ต้องคอยจำ struct แค่ไม่มีฟิลด์นั้นอยู่แล้ว

## ข้อผิดพลาดของโดเมน

ข้อผิดพลาดของโดเมนของเราควรอธิบายความล้มเหลวระดับธุรกิจ ไม่ใช่ระดับอินฟราสตรัคเจอร์ โดเมนรู้จัก "ผู้ใช้มีอยู่แล้ว" และ "รูปแบบอีเมลไม่ถูกต้อง" แต่มันไม่รู้ (และไม่ควรรู้) เกี่ยวกับ "การละเมิดคอนสเตรนต์ไม่ซ้ำของ SQL" หรือ "HTTP 409 Conflict" ถ้าคุณพบว่าตัวเองกำลัง import ชนิดข้อมูลของ `sqlx` หรือ `axum` ใน enum ข้อผิดพลาดของโดเมน แสดงว่าบางอย่างผิดเพี้ยนไปแล้ว

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

วาเรียนต์ `CreateUserError::Unknown` ใช้ `anyhow::Error` เป็นตัวรับทุกอย่าง (catch-all) สำหรับความล้มเหลวที่ไม่คาดคิด สิ่งนี้ทำให้เลเยอร์อินฟราสตรัคเจอร์แปลงข้อผิดพลาดตามอำเภอใจ (เช่น การหมดเวลาการเชื่อมต่อฐานข้อมูล) เป็นข้อผิดพลาดของโดเมนได้ โดยที่โดเมนไม่ต้องรู้ทุกโหมดความล้มเหลวที่เป็นไปได้ จากนั้นเลเยอร์ API จะแมป `Unknown` ไปเป็นการตอบกลับ 500 ทั่วไป พร้อมบันทึกรายละเอียดทั้งหมดไว้ฝั่งเซิร์ฟเวอร์ คุณอาจสงสัยว่านี่หลวมเกินไปไหม ในประสบการณ์ของผม มันสร้างสมดุลได้ดี: ข้อผิดพลาดที่คาดไว้ถูกกำหนดชนิดข้อมูล และข้อผิดพลาดที่ไม่คาดคิดก็ยังถูกจัดการอย่างนุ่มนวล

## การรวมทุกอย่างเข้าด้วยกัน

มาลองไล่เส้นทางข้อมูลที่สมบูรณ์จากคำขอ HTTP ไปยังฐานข้อมูลและย้อนกลับ เพื่อให้คุณเห็นว่าชนิดข้อมูลเปลี่ยนไปอย่างไรในแต่ละขอบเขต:

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

ในทุกขอบเขต ข้อมูลจะถูกแปลงเป็นชนิดข้อมูลที่อยู่ในเลเยอร์นั้น เลเยอร์ API ทำงานกับ DTO เลเยอร์โดเมนทำงานกับชนิดข้อมูลโดเมน เลเยอร์อินฟราสตรัคเจอร์ทำงานกับชนิดข้อมูลแถวฐานข้อมูล การแปลงระหว่างพวกมันชัดเจน ตรวจสอบย้อนกลับได้ และถูกบังคับโดยคอมไพเลอร์

ผมรู้ว่ามันอาจรู้สึกเหมือนพิธีกรรมเยอะไปหน่อยเมื่อเทียบกับการส่ง struct ตัวเดียวลุยไปตลอดทั้งทาง ผมก็รู้สึกแบบเดียวกันตอนเริ่มทำครั้งแรก แต่สิ่งที่ผมค้นพบในทางปฏิบัติคือ: เมื่อคุณต้องเพิ่มฟิลด์ในการตอบกลับของ API คุณเปลี่ยน DTO เมื่อคุณต้องเพิ่มคอลัมน์ในฐานข้อมูล คุณเปลี่ยนชนิดข้อมูลแถว เมื่อคุณต้องเพิ่มกฎทางธุรกิจ คุณเปลี่ยนชนิดข้อมูลโดเมน แต่ละการเปลี่ยนแปลงอยู่ในเลเยอร์ที่เป็นของมัน และการอิมพลีเมนต์ `From` จะบอกคุณอย่างชัดเจนว่าเลเยอร์เชื่อมต่อกันอย่างไร เมื่อคุณทำงานแบบนี้บนโปรเจกต์ที่โตเกินสองสามพันบรรทัดแล้ว มันยากที่จะหวนกลับไป