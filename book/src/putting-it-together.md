# การรวมทุกอย่างเข้าด้วยกัน

ถ้าคุณอ่านบทก่อนๆ มาตลอด คุณคงซึมซับแนวคิดไปเยอะแล้ว: สถาปัตยกรรมแบบเลเยอร์ การสร้างแบบจำลองโดเมน การแยกเลเยอร์ออกจากกันอย่างเหมาะสม ทฤษฎีทั้งหมดนั้นฟังดูดี แต่เมื่อคุณนั่งลงและลงมือสร้างของจริง มันจะมีหน้าตาเป็นแบบไหนกันแน่? นั่นคือสิ่งที่บทนี้มีไว้ เราจะพาคุณเดินผ่านฟีเจอร์เดียวตั้งแต่ต้นจนจบ ทุกไฟล์ ทุกชนิดข้อมูล ทุกความเชื่อมโยงระหว่างเลเยอร์ เมื่อจบบท คุณจะได้เห็นชิ้นแนวตั้ง (vertical slice) ที่สมบูรณ์หนึ่งชิ้นตัดผ่านทั้งแอปพลิเคชัน ตั้งแต่คำขอ HTTP ที่มาถึงแฮนด์เลอร์ ผ่านเซอร์วิสของโดเมนและพอร์ตของรีพอสิทอรี ลงไปถึงฐานข้อมูล และย้อนกลับขึ้นมาสู่การตอบกลับของ API

ฟีเจอร์ที่เราจะสร้างคือการลงทะเบียนผู้ใช้: เอนด์พอยต์ `POST /api/v1/users` ที่รับชื่อ อีเมล และรหัสผ่าน ตรวจสอบความถูกต้อง แฮชรหัสผ่าน เก็บผู้ใช้ลงในฐานข้อมูล และคืนผู้ใช้ที่สร้างขึ้นกลับมา ไม่มีอะไรแปลกใหม่ แต่ฟีเจอร์นี้แตะทุกเลเยอร์ ซึ่งเป็นเหตุผลที่ผมเลือกมันพอดี

## ไฟล์ที่เราจะสร้าง

ก่อนจะดำดิ่งลงไป นี่คือตำแหน่งที่แต่ละส่วนอยู่ในโครงสร้างโปรเจกต์ของเรา:

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

เราจะสร้างแต่ละส่วนโดยเริ่มจากด้านใน (โดเมน) แล้วค่อยๆ ขยายออกไปด้านนอก ผมพบว่าลำดับแบบนี้ช่วยได้มากที่สุด เพราะเมื่อคุณไปถึงแฮนด์เลอร์ ชนิดข้อมูลทั้งหมดที่มันพึ่งพานั้นมีอยู่แล้ว

## ขั้นตอนที่ 1: แบบจำลองโดเมนและวัตถุค่า

ชนิดข้อมูลเหล่านี้อยู่ใน `src/domain/models/user.rs` สิ่งสำคัญคือมันไม่มีดีเพนเดนซีใดๆ กับ Axum SQLx หรือครีตเฟรมเวิร์กใดๆ เลย พวกมันบังคับใช้ค่าคงที่ของตัวเองผ่านฟิลด์แบบ private และคอนสตรักเตอร์ที่ตรวจสอบความถูกต้อง ซึ่งหมายความว่าคุณไม่สามารถสร้าง `Email` ปลอมๆ หรือ `UserName` ว่างเปล่าได้โดยบังเอิญ

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

สังเกตว่า `User` ไม่มีฟิลด์ `password_hash` นั่นเป็นความตั้งใจ เอนทิตีแทนมุมมองสาธารณะของผู้ใช้ ซึ่งเป็นสิ่งที่เราสบายใจจะส่งกลับผ่าน API ส่วน `NewUser` เป็น struct แยกต่างหากที่บรรทุกข้อมูลที่จำเป็นสำหรับการ *สร้าง* ผู้ใช้หนึ่งคน รวมถึงแฮชด้วย คุณอาจสงสัยว่าทำไมเราไม่แค่เติม `Option<String>` ลงบน `User` สำหรับรหัสผ่าน ในประสบการณ์ของผม แนวทางนั้นนำไปสู่บั๊กแบบที่ใครบางคนเผลอซีเรียลไลซ์แฮชลงในการตอบกลับ JSON โดยบังเอิญ ชนิดข้อมูลสองชนิด วัตถุประสงค์สองอย่าง ไม่มีอุบัติเหตุ

## ขั้นตอนที่ 2: ข้อผิดพลาดของโดเมน

ข้อผิดพลาดเหล่านี้อยู่ใน `src/domain/errors.rs` พวกมันอธิบายความล้มเหลวระดับธุรกิจ ซึ่งเป็นเรื่องแบบที่ผู้จัดการผลิตภัณฑ์ของคุณจะเข้าใจ ไม่ใช่รายละเอียดเชิงอินฟราสตรัคเจอร์อย่าง "การเชื่อมต่อ TCP หมดเวลา"

```rust
#[derive(Debug, thiserror::Error)]
pub enum CreateUserError {
    #[error("a user with email {email} already exists")]
    Duplicate { email: Email },

    #[error(transparent)]
    Unknown(#[from] anyhow::Error),
}
```

`CreateUserError::Duplicate` คือการละเมิดกฎทางธุรกิจ: มีคนพยายามลงทะเบียนด้วยอีเมลที่ถูกใช้ไปแล้ว `CreateUserError::Unknown` คือช่องทางหลบหนี (escape hatch) ของเราสำหรับความล้มเหลวเชิงอินฟราสตรัคเจอร์ที่ไม่คาดคิด (ฐานข้อมูลหมดเวลา ข้อผิดพลาดการเชื่อมต่อ ประเภทนั้นๆ) โดเมนไม่รู้และไม่สนใจว่าความล้มเหลวเชิงอินฟราสตรัคเจอร์แบบเฉพาะเจาะจงเกิดขึ้นแบบไหน มันแค่รู้ว่าบางอย่างผิดเพี้ยนไป

## ขั้นตอนที่ 3: พอร์ต (เทรตของรีพอสิทอรี)

นี่คือแนวคิดที่ทำให้แนวทางแบบเลเยอร์ทั้งหมดทำงานได้จริง ถ้าคุณจะจำสิ่งเดียวจากบทนี้ ให้จำส่วนนี้ไว้ **พอร์ต** คือเทรตที่นิยามในเลเยอร์โดเมน ซึ่งอธิบายปฏิบัติการที่โดเมนต้องการจากโลกภายนอก โดเมนพูดว่า "ผมต้องการบางอย่างที่บันทึกผู้ใช้และค้นหาผู้ใช้ได้" แต่มันไม่ได้บอก *ว่าอย่างไร* เทรตนี้อยู่ใน `src/domain/ports/user_repository.rs`

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

ลองดูส่วน import เทรตนี้ import เฉพาะชนิดข้อมูลของโดเมน ไม่มี `PgPool` ไม่มี `sqlx::query` ไม่มี `axum::State` นั่นคือสิ่งที่ทำให้มันเป็นพอร์ต: มันนิยามขอบเขตระหว่างโดเมนและอินฟราสตรัคเจอร์โดยไม่คัปปลิ้งกับฝั่งใดฝั่งหนึ่ง

ขอบเขต `Send + Sync + 'static` อยู่ตรงนั้นเพราะ Axum แชร์สถานะข้ามทาสก์แอซิงก์บนหลายเธรด เทรตใช้ `impl Future<...> + Send` เป็นชนิดข้อมูลที่คืน ซึ่งทำงานร่วมกับ async-in-traits ดั้งเดิมของ Rust (เสถียรตั้งแต่ 1.75) สำหรับการเรียกแบบสแตติก ถ้าคุณต้องการการเรียกแบบไดนามิก (`Arc<dyn UserRepository>`) ในภายหลัง คุณจะเปลี่ยนไปใช้ครีต `async_trait` ตามที่ผมอธิบายไว้ในบท [แพตเทิร์นสถาปัตยกรรม](./architecture.md)

**ทำไมต้องยุ่งยากกับพอร์ตเลยล่ะ?** ผมมองว่ามันให้ผลตอบแทนสองอย่าง อย่างแรก มันให้คุณทดสอบเลเยอร์เซอร์วิสได้โดยไม่ต้องมีฐานข้อมูล คุณเขียนอิมพลีเมนเทชัน `UserRepository` แบบง่ายๆ ในหน่วยความจำสำหรับการทดสอบของคุณ และเซอร์วิสก็ไม่รู้ความแตกต่าง อย่างที่สอง มันบังคับใช้กฎของดีเพนเดนซีในระดับโมดูล: โดเมนไม่สามารถ import SQLx ได้โดยบังเอิญ เพราะเทรตไม่ได้อ้างถึงมัน ถ้าใครพยายามเพิ่มพารามิเตอร์ `PgPool` ลงในไฟล์นี้ พวกเขาจะตระหนักได้อย่างรวดเร็วว่ามันไม่ควรอยู่ที่นี่

**เมื่อไหร่ที่คุณไม่จำเป็นต้องใช้พอร์ต:** ถ้าแอปพลิเคชันของคุณเล็ก เป็น CRUD เป็นส่วนใหญ่ และไม่น่ามีอิมพลีเมนเทชันที่สองของรีพอสิทอรี คุณก็ข้ามเทรตไปได้ แล้วให้เซอร์วิสเรียก struct รีพอสิทอรีรูปธรรมโดยตรง ผมทำแบบนี้หลายครั้งสำหรับโปรเจกต์ข้างและเครื่องมือภายใน บท [แอนติแพตเทิร์น](./anti-patterns.md) กล่าวถึงว่าการทำให้ง่ายแบบนั้นสมเหตุสมผลเมื่อไหร่ พอร์ตเริ่มคุ้มค่ากับการดูแลเมื่อคุณมีตรรกะทางธุรกิจจริงให้ทดสอบ เมื่อคุณต้องการนำโดเมนไปใช้ซ้ำจากหลายจุดเริ่มต้น หรือเมื่อทีมใหญ่พอที่ราวกั้นทางสถาปัตยกรรม (architectural guardrails) มีความสำคัญ

## ขั้นตอนที่ 4: เซอร์วิส

เซอร์วิสอยู่ใน `src/domain/services/user_service.rs` นี่คือจุดที่ตรรกะทางธุรกิจที่แท้จริงเกิดขึ้น มันเรียกรีพอสิทอรีผ่านเทรตพอร์ตที่เราเพิ่งนิยาม

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

เซอร์วิสเป็นเจนเนอริกเหนือ `R: UserRepository` มันไม่รู้ว่า `R` เป็นรีพอสิทอรี PostgreSQL จริงหรือตัวปลอมสำหรับทดสอบ มันแค่เรียกเมธอดของเทรตและทำหน้าที่ของมันไปเรื่อยๆ เมธอด `register` คือจุดที่สิ่งน่าสนใจเกิดขึ้น: มันแฮชรหัสผ่านบนเธรดแบบ blocking (คุณไม่อยากให้ bcrypt มัดแขนขารันไทม์แอซิงก์ของคุณเอาไว้จริงๆ) และสร้าง struct `NewUser` ที่รีพอสิทอรีจะเก็บลงฐานข้อมูล

และสังเกตด้วยว่าเซอร์วิส *ไม่รู้* เรื่องอะไรบ้าง มันไม่มีแนวคิดเรื่องรหัสสถานะ HTTP การซีเรียลไลซ์ JSON หรือชนิดข้อมูลคำขอ/การตอบกลับ มันรับชนิดข้อมูลโดเมน (`UserName`, `Email`) และคืนชนิดข้อมูลโดเมน (`User`, `CreateUserError`) การแปลระหว่างแนวคิด HTTP กับแนวคิดโดเมน? นั่นคืองานของแฮนด์เลอร์ และเราจะไปถึงมันในเร็วๆ นี้

## ขั้นตอนที่ 5: การนำรีพอสิทอรีไปใช้

ตอนนี้เราข้ามขอบเขตเข้าสู่อินฟราสตรัคเจอร์ ไฟล์นี้อยู่ใน `src/infra/repositories/user_repo.rs` และอิมพลีเมนต์เทรตพอร์ตด้วย SQLx นี่คือที่ที่ SQL อาศัยอยู่จริงๆ

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

ไฟล์นี้พร้อมกับการต่อสายใน `main.rs` (ซึ่งใช้ `PgPool` และ `sqlx::migrate!`) เป็นเพียงสองจุดเดียวในแอปพลิเคชันทั้งหมดของเราที่ import `sqlx` ผมอยากเน้นสิ่งนี้เพราะมันคือประเด็นสำคัญทั้งหมด: **เลเยอร์โดเมนและ API** ไม่เคยเห็นชนิดข้อมูลของ SQLx แฮนด์เลอร์ไม่เคยแตะ `UserRow` หรือ `sqlx::Error` รายละเอียดพวกนั้นถูกขังไว้ในเลเยอร์อินฟราสตรัคเจอร์ซึ่งเป็นที่ที่มันควรอยู่ ถ้าคุณตัดสินใจเปลี่ยน Postgres เป็นอย่างอื่น (ไม่น่าเกิดขึ้น แต่มันก็เกิดขึ้นได้) คุณจะแก้แค่ไฟล์นี้ และโดเมนจะไม่สะดุ้งสะเทือนแม้แต่น้อย

## ขั้นตอนที่ 6: DTO และ AppError

ชนิดข้อมูลคำขอและการตอบกลับอยู่ใน `src/api/dtos/user_dto.rs` สิ่งเหล่านี้คือรูปร่างที่โลกภายนอกเห็น และพวกมันแยกจากชนิดข้อมูลโดเมนของเราโดยตั้งใจ:

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

จากนั้นเรามี `AppError` ใน `src/error.rs` ซึ่งเป็นกาวเชื่อมระหว่างข้อผิดพลาดของโดเมนกับ HTTP สิ่งนี้อาจดูเหมือนโบยเลอร์เพลต และตามตรงมันก็ค่อนข้างเป็นแบบนั้นจริงๆ แต่มันให้จุดเดียวแก่คุณที่คุณตัดสินใจว่า "ข้อผิดพลาดทางธุรกิจนี้กลายเป็นรหัสสถานะ HTTP นั้น":

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

แฮนด์เลอร์คืน `AppResult<T>` และเมื่อมันมีค่า `Err` Axum จะเรียก `into_response()` เพื่อสร้างข้อผิดพลาด HTTP สิ่งที่ผมชอบเกี่ยวกับแพตเทิร์นนี้คือตัวแฮนด์เลอร์เองไม่ต้องคิดเรื่องรหัสสถานะสำหรับกรณีข้อผิดพลาดเลย มันแค่ใช้ `?` และการอิมพลีเมนต์ `From` ก็จัดการส่วนที่เหลือ

## ขั้นตอนที่ 7: แฮนด์เลอร์

แฮนด์เลอร์อยู่ใน `src/api/handlers/users.rs` ถ้าคุณอ่านมาอย่างละเอียด คุณอาจคาดว่ามันจะเป็นไฟล์ที่ง่ายที่สุดเท่าที่เคยมีมา และมันก็เป็นเช่นนั้นจริงๆ แพตเทิร์นคือ: แยกข้อมูลออกมา (extract), แยกวิเคราะห์ (parse), มอบหมายงาน (delegate), ตอบกลับ (respond)

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

ตรรกะจริงๆ สิบสี่บรรทัด เท่านั้นแหละ ไม่มี SQL ไม่มีการแฮชรหัสผ่าน ไม่มีกฎทางธุรกิจ มันแยกข้อมูลจากคำขอ แยกวิเคราะห์ฟิลด์เป็นชนิดข้อมูลโดเมน เรียกเซอร์วิส และคืนการตอบกลับ ถ้ามีอะไรล้มเหลว โอเปอเรเตอร์ `?` จะแพร่ข้อผิดพลาดผ่านสายโซ่ `From` ไปจนกระทั่งมันกลายเป็นการตอบกลับ HTTP ผมพบว่าเมื่อแฮนด์เลอร์บางแบบนี้ มันแทบเป็นไปไม่ได้ที่จะทำผิด และการรีวิวโค้ดก็แทบเขียนให้ตัวเองเสร็จ

## ขั้นตอนที่ 8: AppState และการต่อสาย

`AppState` ใน `src/api/state.rs` ถือดีเพนเดนซีที่แชร์ร่วมกันทั้งหมด ลองนึกถึงมันเป็นถุงของใช้ที่แฮนด์เลอร์ของเราต้องการเพื่อทำงานให้เสร็จ:

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

จากนั้น `main.rs` ก็ต่อสายทุกอย่างเข้าด้วยกัน นี่คือช่วงเวลาที่นามธรรมทั้งหมดของเรามาบรรจบกับโลกแห่งความเป็นจริง:

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

นี่คือ **composition root** ของเรา: จุดเดียวในแอปพลิเคชันที่เราเลือกชนิดข้อมูลรูปธรรมและต่อสายมันเข้าด้วยกัน เซอร์วิสโดเมนได้รับ `PostgresUserRepo` แต่มันรู้จักมันเพียงแค่ "บางสิ่งที่อิมพลีเมนต์ `UserRepository`" ถ้าคุณอยากสลับฐานข้อมูลอื่น (หรือแม้แต่ที่เก็บข้อมูลสำรองที่ต่างออกไปโดยสิ้นเชิง) คุณจะแก้ไฟล์นี้และโมดูล `infra/` เลเยอร์โดเมนและ API ไม่ต้องเปลี่ยนเลย ซึ่งเป็นคุณสมบัติที่ดีมากเมื่อแอปพลิเคชันของคุณเริ่มโตขึ้น

## เส้นทางข้อมูลที่สมบูรณ์

มาลองไล่ทั้งกระบวนการตั้งแต่ต้นจนจบ นี่คือสิ่งที่เกิดขึ้นเมื่อไคลเอนต์ส่ง `POST /api/v1/users`:

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

ทุกขอบเขตชัดเจน และผมคิดว่านั่นคือสิ่งที่ทำให้แนวทางนี้คุ้มค่ากับไฟล์ที่เพิ่มขึ้น แฮนด์เลอร์ทำงานกับ DTO และชนิดข้อมูลโดเมน เซอร์วิสทำงานกับชนิดข้อมูลโดเมนและพอร์ต รีพอสิทอรีทำงานกับ SQL และชนิดข้อมูลแถว และการอิมพลีเมนต์ `From` / `TryFrom` ก็เชื่อมช่องว่างทั้งหลาย ไม่มีเลเยอร์ใดล้วงเข้าไปในส่วนภายในของเลเยอร์อื่น ถ้าฟังดูเหมือนพิธีกรรมเยอะไปสำหรับเอนด์พอยต์เดียว คุณก็ไม่ได้คิดผิด แต่เมื่อคุณทำมันสำเร็จครั้งหนึ่งแล้ว ฟีเจอร์ถัดไปทุกตัวจะเดินตามรูปร่างเดียวกัน และความสม่ำเสมอนั้นก็จ่ายคืนให้ตัวเองอย่างรวดเร็ว

## การขยายขนาด: ฟีเจอร์ที่ใหญ่ขึ้น เซอร์วิสมากขึ้น

เมื่อแอปพลิเคชันของคุณเติบโต คุณจะเพิ่มฟีเจอร์มากขึ้น แต่ละฟีเจอร์เดินตามแพตเทิร์นเดียวกัน: ชนิดข้อมูลโดเมน พอร์ตถ้าจำเป็น เซอร์วิส รีพอสิทอรี DTO และแฮนด์เลอร์ เมื่อคุณสร้างฟีเจอร์สองสามตัวด้วยวิธีนี้แล้ว โครงสร้างก็จะกลายเป็นเรื่องธรรมชาติที่ทำได้เองโดยไม่ต้องคิด

เมื่อถึงจุดหนึ่ง คุณจะสังเกตว่าไดเรกทอรีราบๆ อย่าง `models/`, `services/`, และ `repositories/` เริ่มแน่นขึ้น เมื่อถึงตอนนั้น คุณก็จัดกลุ่มใหม่ตามฟีเจอร์แทนได้:

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

ทั้งสองโครงสร้างเดินตามหลักการเดียวกันกับที่เราใช้มาตลอดทั้งบท ทางเลือกระหว่างมันเกี่ยวกับจำนวนไฟล์และความง่ายในการหาสิ่งของ ไม่ใช่เกี่ยวกับสถาปัตยกรรม คำแนะนำของผม: เริ่มจากโครงสร้างแบบราบ แล้วจัดกลุ่มตามฟีเจอร์เมื่อการเดินสำรวจไดเรกทอรีราบๆ เริ่มสร้างความรำคาญให้คุณ ในประสบการณ์ของผม จุดเปลี่ยนนั้นอยู่แถวๆ แนวคิดโดเมน 5 ถึง 10 แนวคิด แต่คุณจะรู้สึกได้เมื่อไปถึงจุดนั้น
