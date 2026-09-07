# การรวมทุกอย่างเข้าด้วยกัน

ถ้าคุณอ่านบทก่อนๆ มาตลอด คุณคงได้เรียนรู้แนวคิดไปมากมาย ไม่ว่าจะเป็นสถาปัตยกรรมแบบเลเยอร์, การสร้างแบบจำลองโดเมน และการแยกเลเยอร์ออกจากกันอย่างเหมาะสม ทฤษฎีทั้งหมดนั้นฟังดูดี แต่เมื่อถึงเวลาที่เราต้องลงมือพัฒนาแอปพลิเคชันจริง โค้ดจะมีหน้าตาเป็นอย่างไรกันแน่? นั่นคือเป้าหมายหลักของบทนี้ครับ เราจะมาเจาะลึกการพัฒนาฟีเจอร์หนึ่งฟีเจอร์อย่างครบวงจรตั้งแต่ต้นจนจบ ไล่เรียงทีละไฟล์ ทีละชนิดข้อมูล และแสดงให้เห็นถึงการเชื่อมต่อระหว่างแต่ละเลเยอร์ เมื่อจบบทนี้ คุณจะได้เห็นชิ้นส่วนแนวตั้ง (vertical slice) ที่สมบูรณ์แบบหนึ่งชิ้นที่ตัดผ่านทั้งแอปพลิเคชัน ตั้งแต่คำขอ HTTP ที่เดินทางมาถึงแฮนด์เลอร์ ส่งผ่านไปยังเซอร์วิสของโดเมนและพอร์ตของรีพอสิทอรี ลงไปจนถึงฐานข้อมูล และส่งผลลัพธ์ย้อนกลับขึ้นมาเป็นการตอบกลับของ API

ฟีเจอร์ที่เราจะร่วมกันสร้างคือระบบลงทะเบียนผู้ใช้: เอนด์พอยต์ `POST /api/v1/users` ที่รับชื่อ, อีเมล และรหัสผ่านดิบเข้ามา ทำการตรวจสอบความถูกต้อง, แฮชรหัสผ่าน, บันทึกข้อมูลผู้ใช้ลงในฐานข้อมูล และส่งคืนข้อมูลผู้ใช้ที่สร้างขึ้นกลับไป แม้จะเป็นฟีเจอร์พื้นฐานที่พบได้ทั่วไป แต่มันครอบคลุมการทำงานของทุกเลเยอร์ในระบบ ซึ่งนั่นคือเหตุผลที่ผมเลือกนำฟีเจอร์นี้มาเป็นตัวอย่าง

## ไฟล์ที่เราจะสร้าง

ก่อนที่เราจะลงมือเขียนโค้ด นี่คือภาพรวมตำแหน่งของแต่ละไฟล์ในโครงสร้างโปรเจกต์ของเรา:

```
src/
├── domain/
│   ├── models/
│   │   └── user.rs          # Entity, value objects (Email, UserName, UserId)
│   ├── errors.rs             # CreateUserError
│   ├── ports/
│   │   └── user_repository.rs  # The trait (port)
│   └── services/
│       └── user_service.rs   # Business logic
│
├── infra/
│   └── repositories/
│       └── user_repo.rs      # PostgresUserRepo (implements the port)
│
├── api/
│   ├── dtos/
│   │   └── user_dto.rs       # CreateUserDto, UserResponse
│   ├── handlers/
│   │   └── users.rs          # The HTTP handler
│   ├── routes.rs              # Route registration
│   └── state.rs               # AppState
│
├── error.rs                   # AppError (HTTP error mapping)
└── main.rs                    # Wiring everything together
```

เราจะเริ่มสร้างทีละส่วนโดยเริ่มจากแกนในสุด (เลเยอร์โดเมน) แล้วค่อยๆ ขยายออกสู่เลเยอร์รอบนอก ผมพบว่าการสร้างตามลำดับนี้ช่วยให้ทำงานได้ง่ายที่สุด เพราะเมื่อเราเขียนมาถึงเลเยอร์แฮนด์เลอร์ ชนิดข้อมูลทั้งหมดที่จำเป็นต้องใช้งานก็จะถูกเตรียมไว้พร้อมอยู่แล้ว

## ขั้นตอนที่ 1: แบบจำลองโดเมนและวัตถุค่า

ชนิดข้อมูลเหล่านี้จะถูกเก็บไว้ที่ `src/domain/models/user.rs` สิ่งสำคัญที่สุดคือไฟล์นี้ต้องไม่มี dependency ใดๆ ต่อ Axum, SQLx หรือเฟรมเวิร์กภายนอกเลยแม้แต่น้อย ชนิดข้อมูลเหล่านี้จะบังคับใช้เงื่อนไขคงสภาพ (invariant) ของตัวเองผ่านทางฟิลด์ที่เป็น private และคอนสตรักเตอร์ที่มีการตรวจสอบความถูกต้อง ทำให้คุณไม่มีทางเผลอสร้าง `Email` ที่ผิดรูปแบบ หรือ `UserName` ที่เป็นค่าว่างขึ้นมาได้อย่างแน่นอน

```rust
use uuid::Uuid;

#[derive(Debug, Clone, PartialEq, Eq, Hash)]
pub struct UserId(Uuid);

impl UserId {
    pub fn new() -> Self { Self(Uuid::new_v4()) }
    pub fn from_uuid(id: Uuid) -> Self { Self(id) }
    pub fn as_uuid(&self) -> &Uuid { &self.0 }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Email(String);

impl Email {
    pub fn parse(raw: &str) -> Result<Self, String> {
        let trimmed = raw.trim().to_lowercase();
        if trimmed.contains('@') && trimmed.len() >= 3 {
            Ok(Self(trimmed))
        } else {
            Err(format!("'{}' is not a valid email", raw))
        }
    }
    pub fn as_str(&self) -> &str { &self.0 }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct UserName(String);

impl UserName {
    pub fn parse(raw: &str) -> Result<Self, String> {
        let trimmed = raw.trim();
        if trimmed.is_empty() {
            return Err("name cannot be empty".into());
        }
        if trimmed.len() > 100 {
            return Err("name cannot exceed 100 characters".into());
        }
        Ok(Self(trimmed.to_string()))
    }
    pub fn as_str(&self) -> &str { &self.0 }
}

/// The domain entity. Fields are private; access is through getters.
#[derive(Debug, Clone)]
pub struct User {
    id: UserId,
    name: UserName,
    email: Email,
    created_at: chrono::DateTime<chrono::Utc>,
}

impl User {
    /// Used by the repository when hydrating from the database.
    pub fn hydrate(
        id: UserId,
        name: UserName,
        email: Email,
        created_at: chrono::DateTime<chrono::Utc>,
    ) -> Self {
        Self { id, name, email, created_at }
    }

    pub fn id(&self) -> &UserId { &self.id }
    pub fn name(&self) -> &UserName { &self.name }
    pub fn email(&self) -> &Email { &self.email }
    pub fn created_at(&self) -> chrono::DateTime<chrono::Utc> { self.created_at }
}

/// The data needed to create a new user.
/// By the time this struct exists, all fields have been validated
/// and the password has been hashed.
pub struct NewUser {
    pub name: UserName,
    pub email: Email,
    pub password_hash: String,
}
```

สังเกตว่า `User` ไม่มีฟิลด์ `password_hash` รวมอยู่ด้วย ซึ่งนี่คือความตั้งใจในการออกแบบ เอนทิตีตัวนี้ทำหน้าที่เป็นตัวแทนมุมมองสาธารณะของผู้ใช้ ซึ่งปลอดภัยที่จะส่งกลับผ่าน API ได้ ส่วน `NewUser` เป็น struct แยกต่างหากสำหรับบรรจุข้อมูลที่จำเป็นในขั้นตอนการ *สร้าง* ผู้ใช้ใหม่ ซึ่งรวมถึงค่าแฮชของรหัสผ่านด้วย คุณอาจสงสัยว่าทำไมเราไม่ใช้ `Option<String>` ใน struct `User` เดียวกันไปเลย คำตอบจากประสบการณ์จริงของผมคือ แนวทางนั้นมักนำไปสู่บั๊กประเภทเผลอ serialize ค่าแฮชของรหัสผ่านหลุดเข้าไปในการตอบกลับ JSON โดยไม่ตั้งใจ การแยกเป็นสองชนิดข้อมูลสำหรับสองวัตถุประสงค์ จึงช่วยตัดโอกาสที่จะเกิดอุบัติเหตุเช่นนี้ได้อย่างเด็ดขาด

## ขั้นตอนที่ 2: ข้อผิดพลาดของโดเมน

ชนิดข้อมูลข้อผิดพลาดเหล่านี้จะอยู่ใน `src/domain/errors.rs` เพื่ออธิบายความล้มเหลวในระดับตรรกะทางธุรกิจ ซึ่งเป็นสิ่งที่ทุกคนในทีมเข้าใจตรงกันได้ ไม่ใช่รายละเอียดทางเทคนิคของโครงสร้างพื้นฐานอย่าง "การเชื่อมต่อ TCP หมดเวลา"

```rust
#[derive(Debug, thiserror::Error)]
pub enum CreateUserError {
    #[error("a user with email {email} already exists")]
    Duplicate { email: Email },

    #[error(transparent)]
    Unknown(#[from] anyhow::Error),
}
```

`CreateUserError::Duplicate` สะท้อนถึงการละเมิดกฎทางธุรกิจ: มีผู้ใช้พยายามลงทะเบียนด้วยอีเมลที่มีอยู่ในระบบแล้ว ส่วน `CreateUserError::Unknown` ทำหน้าที่เป็นกลไกรับมือ (escape hatch) สำหรับความล้มเหลวในระดับอินฟราสตรักเจอร์ที่ไม่คาดคิด (เช่น ฐานข้อมูลหมดเวลาเชื่อมต่อ หรือระบบเครือข่ายขัดข้อง) โดเมนไม่มีความจำเป็นต้องรับรู้รายละเอียดทางเทคนิคเหล่านั้น รู้เพียงแค่ว่าเกิดข้อผิดพลาดขึ้นในกระบวนการทำงาน

## ขั้นตอนที่ 3: พอร์ต (เทรตของรีพอสิทอรี)

นี่คือแนวคิดสำคัญที่ทำให้สถาปัตยกรรมแบบเลเยอร์ทำงานร่วมกันได้อย่างสมบูรณ์แบบ หากคุณจะจดจำสิ่งสำคัญที่สุดเพียงข้อเดียวจากบทนี้ ขอให้จำส่วนนี้ไว้ครับ: **พอร์ต (Port)** คือ trait ที่กำหนดขึ้นในเลเยอร์โดเมน เพื่ออธิบายการดำเนินการที่โดเมนต้องการจากโลกภายนอก โดยโดเมนจะระบุว่า "ฉันต้องการระบบที่สามารถบันทึกและค้นหาข้อมูลผู้ใช้ได้" แต่จะไม่บอกว่า *ทำอย่างไร* trait นี้จะอยู่ใน `src/domain/ports/user_repository.rs`

```rust
use std::future::Future;
use crate::domain::models::{User, UserId, Email, NewUser};
use crate::domain::errors::CreateUserError;

pub trait UserRepository: Send + Sync + 'static {
    fn create(
        &self,
        new_user: &NewUser,
    ) -> impl Future<Output = Result<User, CreateUserError>> + Send;

    fn find_by_id(
        &self,
        id: &UserId,
    ) -> impl Future<Output = Result<Option<User>, anyhow::Error>> + Send;

    fn find_by_email(
        &self,
        email: &Email,
    ) -> impl Future<Output = Result<Option<User>, anyhow::Error>> + Send;
}
```

ลองสังเกตส่วนของคำสั่ง import ให้ดี trait นี้จะ import เฉพาะชนิดข้อมูลของโดเมนเท่านั้น ไม่มีการเรียกใช้ `PgPool`, `sqlx::query` หรือ `axum::State` เลย นั่นคือคุณสมบัติที่ทำให้มันทำหน้าที่เป็นพอร์ตได้อย่างแท้จริง: มันทำหน้าที่ขีดเส้นแบ่งขอบเขตระหว่างโดเมนกับอินฟราสตรักเจอร์โดยไม่ผูกมัดกับฝั่งใดฝั่งหนึ่ง

ขอบเขต `Send + Sync + 'static` ถูกกำหนดไว้เพราะ Axum ต้องแชร์สถานะการทำงานข้าม async task บนหลากหลายเธรด และ trait ใช้ `impl Future<...> + Send` เป็นชนิดข้อมูลขากลับ ซึ่งทำงานร่วมกับฟีเจอร์ async fn in traits ของ Rust (เป็น stable ตั้งแต่ 1.75) สำหรับการเรียกใช้งานแบบ static dispatch ได้อย่างสมบูรณ์แบบ หากในอนาคตคุณต้องการเปลี่ยนไปใช้ dynamic dispatch (`Arc<dyn UserRepository>`) คุณก็สามารถสลับไปใช้เครต `async_trait` ได้ตามที่เราอธิบายไว้ในบท [แพตเทิร์นสถาปัตยกรรม](./architecture.md)

**ทำไมเราต้องยอมเสียเวลาสร้างพอร์ตด้วย?** ผมมองว่ามันมอบผลตอบแทนที่คุ้มค่า 2 ประการหลัก อย่างแรกคือ ช่วยให้คุณสามารถทดสอบเลเยอร์เซอร์วิสได้โดยไม่ต้องพึ่งพาฐานข้อมูลจริง คุณเพียงแค่เขียนอิมพลีเมนเทชันจำลองของ `UserRepository` ในหน่วยความจำเพื่อใช้ในการทดสอบ และตัวเซอร์วิสก็ทำงานได้ทันทีโดยไม่เห็นความแตกต่าง ประการที่สองคือ ช่วยบังคับใช้กฎของ dependency ในระดับโมดูล โดเมนจะไม่มีทางเผลอ import SQLx เข้ามาได้โดยบังเอิญ เพราะใน trait ไม่ได้มีการอ้างอิงถึง หากใครพยายามจะเพิ่มพารามิเตอร์ `PgPool` เข้ามาในไฟล์นี้ พวกเขาจะตระหนักได้ทันทีว่ามันไม่ควรอยู่ที่นี่

**เมื่อใดที่คุณไม่จำเป็นต้องใช้พอร์ต:** หากแอปพลิเคชันของคุณมีขนาดเล็ก เป็นเพียงระบบ CRUD ทั่วไป และไม่มีแนวโน้มที่จะต้องมี repository implementation รูปแบบที่สอง คุณสามารถข้ามการสร้าง trait ไปได้เลย และให้เซอร์วิสเรียกใช้ struct ของรีพอสิทอรีจริงโดยตรง ซึ่งผมเองก็ใช้วิธีนี้อยู่บ่อยครั้งสำหรับโปรเจกต์งานอดิเรกหรือเครื่องมือใช้งานภายใน บท [แอนติแพตเทิร์น](./anti-patterns.md) จะอธิบายเพิ่มเติมว่าเมื่อใดที่การลดทอนความซับซ้อนเช่นนั้นจึงจะสมเหตุสมผล การใช้พอร์ตจะเริ่มคุ้มค่าเมื่อคุณมีตรรกะทางธุรกิจที่จริงจังซึ่งจำเป็นต้องได้รับการทดสอบ, เมื่อคุณต้องการนำโดเมนไปใช้ซ้ำจากหลายช่องทาง หรือเมื่อทีมมีขนาดใหญ่ขึ้นจนราวกั้นทางสถาปัตยกรรม (architectural guardrails) เริ่มมีความสำคัญ

## ขั้นตอนที่ 4: เซอร์วิส

เลเยอร์เซอร์วิสจะอยู่ใน `src/domain/services/user_service.rs` ซึ่งเป็นจุดที่ตรรกะทางธุรกิจที่แท้จริงทำงาน เซอร์วิสจะเรียกใช้งานรีพอสิทอรีผ่านทาง trait พอร์ตที่เราเพิ่งกำหนดขึ้น

```rust
use crate::domain::models::{User, UserId, Email, UserName, NewUser};
use crate::domain::errors::CreateUserError;
use crate::domain::ports::UserRepository;

#[derive(Clone)]
pub struct UserService<R: UserRepository> {
    repo: R,
}

impl<R: UserRepository> UserService<R> {
    pub fn new(repo: R) -> Self {
        Self { repo }
    }

    pub async fn register(
        &self,
        name: UserName,
        email: Email,
        password: &str,
    ) -> Result<User, CreateUserError> {
        // Hash the password on a blocking thread so we do not
        // tie up the async runtime with CPU-intensive work.
        let password = password.to_string();
        let password_hash = tokio::task::spawn_blocking(move || {
            hash_password(&password)
        })
        .await
        .map_err(|e| CreateUserError::Unknown(e.into()))?
        .map_err(|e| CreateUserError::Unknown(e.into()))?;

        let new_user = NewUser { name, email, password_hash };
        self.repo.create(&new_user).await
    }

    pub async fn get_by_id(&self, id: &UserId) -> Result<Option<User>, anyhow::Error> {
        self.repo.find_by_id(id).await
    }
}
```

ตัวเซอร์วิสถูกออกแบบให้เป็นเจเนอริกเหนือ `R: UserRepository` ทำให้ไม่ต้องรับรู้เลยว่า `R` คือรีพอสิทอรี PostgreSQL ของจริง หรือเป็นเพียง mock repository สำหรับการทดสอบ มันเพียงแค่เรียกใช้เมธอดตามสัญญาที่ trait ระบุไว้ เมธอด `register` คือจุดที่ตรรกะสำคัญเกิดขึ้น: มันทำการแฮชรหัสผ่านบนเธรดแบบ blocking (เพราะคุณคงไม่อยากให้งานคำนวณหนักๆ อย่าง bcrypt ไปขัดขวางหรือหน่วงการทำงานของ async runtime) แล้วสร้าง struct `NewUser` ขึ้นมาเพื่อส่งต่อไปให้รีพอสิทอรีบันทึกลงฐานข้อมูล

และสังเกตว่าสิ่งที่เซอร์วิส *ไม่รู้* มีอะไรบ้าง: มันไม่มีแนวคิดเกี่ยวกับรหัสสถานะ HTTP, การแปลงข้อมูล JSON หรือรูปแบบของ request/response DTO เลย มันรับเฉพาะชนิดข้อมูลของโดเมน (`UserName`, `Email`) และส่งคืนเฉพาะชนิดข้อมูลของโดเมน (`User`, `CreateUserError`) ส่วนการแปลงระหว่างโลกของ HTTP กับโลกของโดเมนนั้น คือหน้าที่ความรับผิดชอบของแฮนด์เลอร์ ซึ่งเราจะไปดูกันต่อไป

## ขั้นตอนที่ 5: การนำรีพอสิทอรีไปใช้

ตอนนี้เราจะก้าวข้ามขอบเขตเข้าสู่เลเยอร์อินฟราสตรักเจอร์ โค้ดส่วนนี้จะอยู่ใน `src/infra/repositories/user_repo.rs` และทำหน้าที่อิมพลีเมนต์ trait พอร์ตโดยใช้ SQLx นี่คือพื้นที่ที่โค้ด SQL อาศัยอยู่อย่างแท้จริง

```rust
use anyhow::Context;
use sqlx::PgPool;

use crate::domain::models::{User, UserId, Email, UserName, NewUser};
use crate::domain::errors::CreateUserError;
use crate::domain::ports::UserRepository;

/// The database row type. This is separate from the domain entity
/// because it maps to the database schema, which may differ from
/// the domain's representation.
#[derive(sqlx::FromRow)]
struct UserRow {
    id: uuid::Uuid,
    name: String,
    email: String,
    password_hash: String,
    created_at: chrono::DateTime<chrono::Utc>,
}

/// Convert a database row to a domain entity.
/// Uses TryFrom because stored data may not satisfy current
/// domain invariants (legacy rows, manual SQL fixes, migrations).
impl TryFrom<UserRow> for User {
    type Error = anyhow::Error;

    fn try_from(row: UserRow) -> Result<Self, Self::Error> {
        Ok(User::hydrate(
            UserId::from_uuid(row.id),
            UserName::parse(&row.name)
                .map_err(|e| anyhow::anyhow!("corrupt name in row {}: {}", row.id, e))?,
            Email::parse(&row.email)
                .map_err(|e| anyhow::anyhow!("corrupt email in row {}: {}", row.id, e))?,
            row.created_at,
        ))
    }
}

#[derive(Clone)]
pub struct PostgresUserRepo {
    pool: PgPool,
}

impl PostgresUserRepo {
    pub fn new(pool: PgPool) -> Self {
        Self { pool }
    }
}

impl UserRepository for PostgresUserRepo {
    async fn create(&self, new_user: &NewUser) -> Result<User, CreateUserError> {
        let row = sqlx::query_as!(
            UserRow,
            r#"
            INSERT INTO users (id, email, name, password_hash)
            VALUES ($1, $2, $3, $4)
            RETURNING id, email, name, password_hash, created_at
            "#,
            uuid::Uuid::new_v4(),
            new_user.email.as_str(),
            new_user.name.as_str(),
            &new_user.password_hash,
        )
        .fetch_one(&self.pool)
        .await
        .map_err(|e| match e {
            sqlx::Error::Database(ref db_err) if db_err.is_unique_violation() => {
                CreateUserError::Duplicate { email: new_user.email.clone() }
            }
            other => CreateUserError::Unknown(
                anyhow::anyhow!(other).context("failed to insert user")
            ),
        })?;

        row.try_into()
            .map_err(|e: anyhow::Error| CreateUserError::Unknown(e))
    }

    async fn find_by_id(&self, id: &UserId) -> Result<Option<User>, anyhow::Error> {
        let row = sqlx::query_as!(
            UserRow,
            "SELECT id, email, name, password_hash, created_at FROM users WHERE id = $1",
            id.as_uuid(),
        )
        .fetch_optional(&self.pool)
        .await
        .context("failed to fetch user by id")?;

        row.map(TryInto::try_into).transpose()
    }

    async fn find_by_email(&self, email: &Email) -> Result<Option<User>, anyhow::Error> {
        let row = sqlx::query_as!(
            UserRow,
            "SELECT id, email, name, password_hash, created_at FROM users WHERE email = $1",
            email.as_str(),
        )
        .fetch_optional(&self.pool)
        .await
        .context("failed to fetch user by email")?;

        row.map(TryInto::try_into).transpose()
    }
}
```

ไฟล์นี้ร่วมกับโค้ดประกอบระบบใน `main.rs` (ซึ่งเรียกใช้ `PgPool` และ `sqlx::migrate!`) เป็นเพียง 2 จุดในทั้งแอปพลิเคชันที่มีการ import `sqlx` ผมอยากเน้นย้ำประเด็นนี้เป็นพิเศษ เพราะนี่คือหัวใจของสถาปัตยกรรม: **เลเยอร์โดเมนและเลเยอร์ API** จะไม่มีทางพบเห็นชนิดข้อมูลของ SQLx เลย แฮนด์เลอร์จะไม่ต้องแตะต้อง `UserRow` หรือ `sqlx::Error` รายละเอียดทางเทคนิคเหล่านั้นจะถูกจำกัดไว้ให้อยู่เฉพาะในเลเยอร์อินฟราสตรักเจอร์ตามที่ควรจะเป็น หากในอนาคตคุณตัดสินใจเปลี่ยนจาก Postgres ไปเป็นระบบอื่น คุณจะแก้ไขเพียงแค่ไฟล์นี้ไฟล์เดียว โดยที่เลเยอร์โดเมนจะไม่ได้รับผลกระทบใดๆ เลยแม้แต่น้อย

## ขั้นตอนที่ 6: DTO และ AppError

ชนิดข้อมูลสำหรับคำขอและการตอบกลับจะอยู่ที่ `src/api/dtos/user_dto.rs` สิ่งเหล่านี้คือโครงสร้างข้อมูลที่โลกภายนอกมองเห็น และถูกแยกออกจากชนิดข้อมูลโดเมนอย่างตั้งใจ:

```rust
use serde::{Deserialize, Serialize};
use validator::Validate;

/// What the client sends. Raw strings, validated by the validator crate.
#[derive(Debug, Deserialize, Validate)]
pub struct CreateUserDto {
    #[validate(length(min = 1, max = 100))]
    pub name: String,

    #[validate(email)]
    pub email: String,

    #[validate(length(min = 8))]
    pub password: String,
}

/// What the client receives. No password_hash, no internal IDs.
#[derive(Debug, Serialize)]
pub struct UserResponse {
    pub id: uuid::Uuid,
    pub name: String,
    pub email: String,
    pub created_at: chrono::DateTime<chrono::Utc>,
}

impl From<crate::domain::models::User> for UserResponse {
    fn from(user: crate::domain::models::User) -> Self {
        Self {
            id: *user.id().as_uuid(),
            name: user.name().as_str().to_string(),
            email: user.email().as_str().to_string(),
            created_at: user.created_at(),
        }
    }
}
```

ถัดมาคือ `AppError` ใน `src/error.rs` ซึ่งทำหน้าที่เป็นสะพานเชื่อมระหว่างข้อผิดพลาดของโดเมนกับโปรโตคอล HTTP แม้โค้ดส่วนนี้อาจดูเหมือนมี boilerplate อยู่บ้าง แต่มันมอบจุดศูนย์กลางเพียงจุดเดียวที่คุณสามารถกำหนดได้อย่างชัดเจนว่า "ข้อผิดพลาดทางธุรกิจข้อนี้ จะถูกแปลงเป็นรหัสสถานะ HTTP ใด":

```rust
use std::collections::HashMap;
use axum::http::StatusCode;
use axum::response::{IntoResponse, Response};
use axum::Json;

#[derive(Debug, thiserror::Error)]
pub enum AppError {
    #[error("not found")]
    NotFound,
    #[error("{0}")]
    Validation(String),
    #[error("unauthorized")]
    Unauthorized,
    #[error("{0}")]
    Conflict(String),
    #[error(transparent)]
    Internal(#[from] anyhow::Error),
}

pub type AppResult<T> = Result<T, AppError>;

impl IntoResponse for AppError {
    fn into_response(self) -> Response {
        let (status, message) = match &self {
            Self::NotFound => (StatusCode::NOT_FOUND, self.to_string()),
            Self::Validation(msg) => (StatusCode::BAD_REQUEST, msg.clone()),
            Self::Unauthorized => (StatusCode::UNAUTHORIZED, self.to_string()),
            Self::Conflict(msg) => (StatusCode::CONFLICT, msg.clone()),
            Self::Internal(e) => {
                tracing::error!(error = ?e, "internal error");
                (StatusCode::INTERNAL_SERVER_ERROR, "internal error".into())
            }
        };
        let body = serde_json::json!({ "error": { "message": message } });
        (status, Json(body)).into_response()
    }
}

// Domain error -> AppError conversion
impl From<crate::domain::errors::CreateUserError> for AppError {
    fn from(err: crate::domain::errors::CreateUserError) -> Self {
        use crate::domain::errors::CreateUserError;
        match err {
            CreateUserError::Duplicate { email } => {
                AppError::Conflict(format!("user with email {} already exists", email.as_str()))
            }
            CreateUserError::Unknown(e) => AppError::Internal(e),
        }
    }
}
```

แฮนด์เลอร์จะส่งผลลัพธ์กลับมาเป็น `AppResult<T>` และหากเกิดกรณีที่เป็น `Err` ทาง Axum จะเรียกใช้ `into_response()` อัตโนมัติเพื่อแปลงเป็น HTTP response ข้อผิดพลาด จุดเด่นของแพตเทิร์นนี้คือตัวแฮนด์เลอร์เองไม่ต้องมาพะวงเรื่องรหัสสถานะ HTTP สำหรับกรณี error เลย เพียงแค่ใช้เครื่องหมาย `?` แล้วการอิมพลีเมนต์ `From` จะดูแลรายละเอียดที่เหลือให้ทั้งหมด

## ขั้นตอนที่ 7: แฮนด์เลอร์

โค้ดของแฮนด์เลอร์จะอยู่ที่ `src/api/handlers/users.rs` หากคุณติดตามเนื้อหามาตั้งแต่ต้น คุณคงเดาได้ว่านี่จะเป็นไฟล์ที่เรียบง่ายที่สุดไฟล์หนึ่ง และมันก็เป็นเช่นนั้นจริงๆ โดยแฮนด์เลอร์จะทำงานตามแพตเทิร์น: สกัดข้อมูล (extract), แปลงชนิดข้อมูล (parse), มอบหมายงานให้เซอร์วิส (delegate), และส่งการตอบกลับ (respond)

```rust
use axum::{extract::State, http::StatusCode, Json};

use crate::api::dtos::user_dto::{CreateUserDto, UserResponse};
use crate::api::extractors::ValidatedJson;
use crate::api::state::AppState;
use crate::domain::models::{UserName, Email};
use crate::error::{AppError, AppResult};

pub async fn create_user(
    State(state): State<AppState>,
    ValidatedJson(payload): ValidatedJson<CreateUserDto>,
) -> AppResult<(StatusCode, Json<UserResponse>)> {
    // Parse raw strings into domain types.
    // If parsing fails, it becomes a validation error.
    let name = UserName::parse(&payload.name)
        .map_err(|e| AppError::Validation(e))?;
    let email = Email::parse(&payload.email)
        .map_err(|e| AppError::Validation(e))?;

    // Delegate to the service. The ? operator converts
    // CreateUserError -> AppError automatically via the From impl.
    let user = state.user_service
        .register(name, email, &payload.password)
        .await?;

    // Convert the domain entity to a response DTO.
    Ok((StatusCode::CREATED, Json(user.into())))
}
```

มีโค้ดตรรกะเพียง 14 บรรทัดเท่านั้นจริงๆ ไม่มี SQL, ไม่มีการแฮชรหัสผ่าน, และไม่มีกฎทางธุรกิจปะปน หน้าที่ของมันมีเพียงดึงข้อมูลจากคำขอ แปลงฟิลด์ต่างๆ ให้เป็นชนิดข้อมูลโดเมน เรียกใช้เซอร์วิส และส่งคืนการตอบกลับ หากมีขั้นตอนใดล้มเหลว โอเปอเรเตอร์ `?` จะส่งต่อข้อผิดพลาดผ่านสายโซ่ของ `From` จนกระทั่งกลายเป็นการตอบกลับแบบ HTTP ที่เหมาะสม ผมพบว่าเมื่อแฮนด์เลอร์มีความบางและกระชับเช่นนี้ แทบจะเป็นไปไม่ได้เลยที่จะเขียนโค้ดผิดพลาด และการตรวจทานโค้ด (code review) ก็ดำเนินไปได้อย่างรวดเร็วและง่ายดาย

## ขั้นตอนที่ 8: AppState และการต่อสาย

`AppState` ใน `src/api/state.rs` ทำหน้าที่เก็บ dependency ส่วนกลางที่ต้องแชร์ร่วมกัน เปรียบเสมือนศูนย์รวม dependency ต่างๆ ที่แฮนด์เลอร์จำเป็นต้องใช้ในการปฏิบัติงาน:

```rust
use axum::extract::FromRef;
use sqlx::PgPool;
use std::sync::Arc;

use crate::config::Config;
use crate::domain::services::UserService;
use crate::infra::repositories::PostgresUserRepo;

#[derive(Clone, FromRef)]
pub struct AppState {
    pub config: Arc<Config>,
    pub db: PgPool,
    pub user_service: UserService<PostgresUserRepo>,
}
```

จากนั้น ไฟล์ `main.rs` จะทำหน้าที่เชื่อมต่อ (wiring) ทุกอย่างเข้าด้วยกัน นี่คือจังหวะที่นามธรรมทั้งหมดที่เราออกแบบไว้ เชื่อมโยงเข้ากับความเป็นจริงในทางปฏิบัติ:

```rust
use crate::api::state::AppState;
use crate::config::Config;
use crate::infra::repositories::PostgresUserRepo;
use crate::domain::services::UserService;

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    let config = Config::from_env()?;
    init_tracing(&config.log_level);

    // Infrastructure: create the database pool.
    let pool = create_pool(config.database_url.expose_secret()).await?;
    sqlx::migrate!("./migrations").run(&pool).await?;

    // Infrastructure: create the repository (implements the port).
    let user_repo = PostgresUserRepo::new(pool.clone());

    // Domain: create the service, injecting the repository.
    let user_service = UserService::new(user_repo);

    // API: assemble the state and router.
    let state = AppState {
        config: Arc::new(config.clone()),
        db: pool,
        user_service,
    };

    let app = api::routes::router(state);

    let addr = format!("0.0.0.0:{}", config.port);
    let listener = tokio::net::TcpListener::bind(&addr).await?;
    tracing::info!("listening on {}", listener.local_addr()?);
    axum::serve(listener, app)
        .with_graceful_shutdown(shutdown_signal())
        .await?;

    Ok(())
}
```

นี่คือ **composition root** ของแอปพลิเคชัน: จุดศูนย์กลางเพียงจุดเดียวที่เราเลือก concrete type และประกอบเชื่อมต่อ (wiring) dependency ต่างๆ เข้าด้วยกัน เซอร์วิสของโดเมนจะได้รับ `PostgresUserRepo` เข้าไปใช้งาน แต่รับรู้เพียงว่ามันคือ "สิ่งใดก็ตามที่อิมพลีเมนต์ `UserRepository`" หากคุณต้องการสลับไปใช้ฐานข้อมูลอื่น คุณจะแก้ไขเพียงแค่ไฟล์นี้และโมดูล `infra/` เท่านั้น โดยที่เลเยอร์โดเมนและเลเยอร์ API ไม่ต้องแตะต้องเลยแม้แต่น้อย ซึ่งเป็นคุณสมบัติที่ยอดเยี่ยมอย่างยิ่งเมื่อระบบเติบโตขึ้น

## เส้นทางข้อมูลที่สมบูรณ์

เราลองมาติดตามการทำงานตั้งแต่ต้นจนจบแบบเป็นขั้นเป็นตอน นี่คือสิ่งที่เกิดขึ้นเมื่อไคลเอนต์ส่งคำขอ `POST /api/v1/users` เข้ามา:

```
Client sends:  { "name": "Alice", "email": "alice@example.com", "password": "secret123" }

  1. Axum deserializes into CreateUserDto (api/dtos)
  2. ValidatedJson checks: name length, email format, password length
  3. Handler parses fields into domain types: UserName, Email
  4. Handler calls user_service.register(name, email, &password)
  5. Service hashes password on blocking thread
  6. Service builds NewUser and calls repo.create(&new_user)
  7. Repository executes INSERT via sqlx::query_as!
  8. If email is duplicate: sqlx returns unique violation
     → Repository maps to CreateUserError::Duplicate
     → Handler's ? maps to AppError::Conflict
     → Axum returns 409 with error message
  9. If successful: repository gets UserRow back from RETURNING clause
     → TryFrom<UserRow> converts to User (domain entity)
  10. Service returns User to handler
  11. Handler converts User to UserResponse via From trait
  12. Axum serializes to JSON and returns 201 Created

Client receives:  { "id": "...", "name": "Alice", "email": "alice@example.com", "created_at": "..." }
```

ทุกขอบเขตถูกแบ่งแยกอย่างเด็ดขาด และนั่นคือสิ่งที่ทำให้แนวทางนี้คุ้มค่ากับจำนวนไฟล์ที่เพิ่มขึ้น แฮนด์เลอร์จัดการเฉพาะ DTO และชนิดข้อมูลโดเมน, เซอร์วิสจัดการเฉพาะชนิดข้อมูลโดเมนและพอร์ต, รีพอสิทอรีจัดการเฉพาะ SQL และชนิดข้อมูลแถวข้อมูลในฐานข้อมูล และการอิมพลีเมนต์ `From` / `TryFrom` จะทำหน้าที่เชื่อมผสานข้อมูลระหว่างกัน ไม่มีเลเยอร์ใดก้าวก่ายเข้าไปในรายละเอียดภายในของเลเยอร์อื่น หากรู้สึกเหมือนมีขั้นตอนหลายขั้นตอนสำหรับเอนด์พอยต์เพียงตัวเดียว คุณก็คิดไม่ผิดครับ แต่เมื่อคุณวางโครงสร้างนี้สำเร็จเป็นแบบอย่างได้แล้ว ฟีเจอร์ต่อๆ ไปทุกตัวจะดำเนินไปตามรูปแบบเดียวกันทั้งหมด และความสม่ำเสมอเป็นระเบียบเรียบร้อยนี้จะมอบความคุ้มค่ากลับคืนมาให้อย่างมหาศาล

## การขยายขนาด: ฟีเจอร์ที่ใหญ่ขึ้น เซอร์วิสมากขึ้น

เมื่อแอปพลิเคชันของคุณเติบโตและมีฟีเจอร์เพิ่มขึ้น แต่ละฟีเจอร์จะดำเนินรอยตามแพตเทิร์นเดียวกันเสมอ ได้แก่ ชนิดข้อมูลโดเมน, พอร์ต (หากจำเป็น), เซอร์วิส, รีพอสิทอรี, DTO และแฮนด์เลอร์ เมื่อคุณสร้างฟีเจอร์ตามแนวทางนี้ไปสัก 2-3 ฟีเจอร์ โครงสร้างนี้จะกลายเป็นความคุ้นเคยที่คุณสามารถเขียนได้อย่างเป็นธรรมชาติโดยแทบไม่ต้องหยุดคิด

เมื่อถึงจุดหนึ่ง คุณอาจสังเกตเห็นว่าไดเรกทอรีที่รวมศูนย์อย่าง `models/`, `services/`, และ `repositories/` เริ่มมีความหนาแน่นของไฟล์มากเกินไป ในจังหวะนั้น คุณสามารถจัดกลุ่มโค้ดใหม่ตามแนวฟีเจอร์ (feature slice) ได้ทันที:

```
src/domain/
├── users/
│   ├── mod.rs
│   ├── model.rs        # User, UserId, Email, UserName, NewUser
│   ├── errors.rs       # CreateUserError
│   ├── port.rs         # UserRepository trait
│   └── service.rs      # UserService
├── posts/
│   ├── mod.rs
│   ├── model.rs
│   ├── errors.rs
│   ├── port.rs
│   └── service.rs
```

ทั้งสองรูปแบบต่างตั้งอยู่บนหลักการพื้นฐานเดียวกันกับที่เราใช้มาตลอดทั้งบท การเลือกระหว่างสองแนวทางนี้จึงเป็นเพียงเรื่องของจำนวนไฟล์และความสะดวกในการค้นหาโค้ด ไม่ใช่เรื่องของความแตกต่างทางสถาปัตยกรรม คำแนะนำของผมคือ: เริ่มต้นด้วยโครงสร้างแบบรวมศูนย์ก่อน แล้วค่อยปรับเป็นโครงสร้างตามแนวฟีเจอร์เมื่อการค้นหาไฟล์ในโฟลเดอร์เดิมเริ่มทำให้คุณรู้สึกเสียเวลา จุดเปลี่ยนที่เหมาะสมมักอยู่ที่ราวๆ 5 ถึง 10 โดเมนคอนเซปต์ แต่เมื่อถึงจุดนั้น คุณจะสัมผัสได้ด้วยตัวเองอย่างแน่นอนครับ
