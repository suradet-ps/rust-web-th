# การทดสอบ

ถ้าคุณเคยส่งเว็บเซอร์วิสขึ้นจริงแล้วใช้เวลาทั้งสัปดาห์ถัดไปนั่งจ้องล็อกอย่างใจจดใจจ่อ คุณจะรู้จักความรู้สึกนั้น การทดสอบคือสิ่งที่ทำให้เรานอนหลับได้ตอนกลางคืน แต่การทดสอบเว็บแอปพลิเคชันไม่ใช่แค่เรื่องเดียว เราต้องการการทดสอบหน่วยที่ตรวจสอบตรรกะทางธุรกิจของเราแบบแยกเดี่ยว การทดสอบการผสานที่วิ่งผ่านไปป์ไลน์เต็มรูปแบบจากคำขอถึงการตอบกลับ และกลยุทธ์ที่มั่นคงสำหรับการจัดการฐานข้อมูลสำหรับทดสอบและดีเพนเดนซีภายนอก ในบทนี้ ผมจะพาคุณผ่านแพตเทิร์นและเครื่องมือที่ทำให้การทดสอบแอปพลิเคชัน Axum ทำได้จริง และพูดตรงๆ ว่าน่าจะสนุกทีเดียว

## พีระมิดการทดสอบ

คุณคงเคยได้ยินเรื่องพีระมิดการทดสอบมาก่อน มันเป็นแนวคิดง่ายๆ แต่มันใช้ได้ดีในทางปฏิบัติ ที่ฐาน เราจะเขียนการทดสอบหน่วยจำนวนมากที่รันเร็วเพื่อตรวจสอบฟังก์ชันแต่ละตัวและตรรกะโดเมน ตรงกลาง เรามีการทดสอบการผสานที่วิ่งผ่านไปป์ไลน์แฮนด์เลอร์ HTTP ทั้งหมด รวมถึงมิดเดิลแวร์ ตัวแยกข้อมูล การซีเรียลไลซ์ และการเข้าถึงฐานข้อมูล และที่ยอด เราจะเก็บการทดสอบแบบ end-to-end จำนวนน้อยลงเพื่อตรวจสอบโฟลว์สำคัญของผู้ใช้กับเซิร์ฟเวอร์ที่รันจริง

จากประสบการณ์ของผม ความพยายามทดสอบส่วนใหญ่ของคุณควรไปที่สองชั้นล่าง การทดสอบหน่วยจับบั๊กตรรกะได้เร็วและถูก การทดสอบการผสานยืนยันว่าเลเยอร์ทั้งหมดถูกต่อสายเข้าหากันอย่างถูกต้องจริงๆ การทดสอบ end-to-end มีประโยชน์กับเส้นทางวิกฤต แต่มันช้ากว่าและเปราะกว่า ผมจึงใช้มันแบบประหยัด

## การทดสอบหน่วยตรรกะโดเมน

นี่คือจุดที่การลงทุนในสถาปัตยกรรมที่สะอาดของเราก่อนหน้านี้คืนกำไรจริงๆ เพราะเลเยอร์โดเมนไม่มีดีเพนเดนซีกับ Axum, SQLx หรือเฟรมเวิร์กใดๆ การทดสอบมันจึงง่ายอย่างน่าชื่นใจ เราแค่สร้างชนิดข้อมูลโดเมน เรียกเมธอดของเซอร์วิส และยืนยันผลลัพธ์ ไม่มีเซิร์ฟเวอร์ HTTP ไม่มีฐานข้อมูล ไม่มีเรื่องยุ่งยาก

ถ้าเซอร์วิสของคุณใช้รีพอสิทอรีแบบเทรต (ตามที่เราตั้งไว้ในบท [แพตเทิร์นสถาปัตยกรรม](./architecture.md)) คุณสามารถส่งอิมพลีเมนเทชันในหน่วยความจำให้มันสำหรับการทดสอบได้:

```rust
#[derive(Clone)]
struct InMemoryUserRepo {
    users: Arc<Mutex<Vec<User>>>,
}

impl InMemoryUserRepo {
    fn new() -> Self {
        Self {
            users: Arc::new(Mutex::new(Vec::new())),
        }
    }
}

impl UserRepository for InMemoryUserRepo {
    async fn create(&self, req: &CreateUserRequest) -> Result<User, CreateUserError> {
        let mut users = self.users.lock().await;

        // Check for duplicates
        if users.iter().any(|u| u.email() == &req.email) {
            return Err(CreateUserError::Duplicate { email: req.email.clone() });
        }

        let user = User::hydrate(
            UserId::new(),
            req.name.clone(),
            req.email.clone(),
            Utc::now(),
            Utc::now(),
        );

        users.push(user.clone());
        Ok(user)
    }

    async fn find_by_id(&self, id: UserId) -> anyhow::Result<Option<User>> {
        let users = self.users.lock().await;
        Ok(users.iter().find(|u| u.id() == &id).cloned())
    }

    // ... other methods
}

#[tokio::test]
async fn registering_a_user_returns_the_user() {
    let repo = InMemoryUserRepo::new();
    let service = UserService::new(repo);

    let name = UserName::parse("Alice").unwrap();
    let email = Email::parse("alice@example.com").unwrap();

    let user = service.register(name, email, "password123").await.unwrap();

    assert_eq!(user.name().as_str(), "Alice");
    assert_eq!(user.email().as_str(), "alice@example.com");
}

#[tokio::test]
async fn registering_duplicate_email_fails() {
    let repo = InMemoryUserRepo::new();
    let service = UserService::new(repo);

    let name = UserName::parse("Alice").unwrap();
    let email = Email::parse("alice@example.com").unwrap();

    service.register(name.clone(), email.clone(), "password123").await.unwrap();

    let result = service.register(name, email, "password456").await;
    assert!(matches!(result, Err(CreateUserError::Duplicate { .. })));
}
```

การทดสอบเหล่านี้รันจบในระดับมิลลิวินาทีเพราะมันไม่แตะเน็ตเวิร์กหรือระบบไฟล์ พวกมันยืนยันว่าตรรกะทางธุรกิจของคุณถูกต้อง เป็นอิสระจากว่ามันถูกเรียกอย่างไรหรือข้อมูลอาศัยอยู่ที่ไหน ความเร็วนั้นสำคัญ เมื่อการทดสอบเร็ว คุณจะรันมันจริงๆ

ถ้าการเขียนอิมพลีเมนเทชันในหน่วยความจำพวกนั้นรู้สึกเหมือนโบยเลอร์เพลตเยอะไป (และมันก็เป็นได้) ครีต `mockall` สามารถสร้างอิมพลีเมนเทชันม็อกของเทรตรีพอสิทอรีของคุณให้อัตโนมัติ ผมมักชอบเขียน fake ด้วยมือสำหรับการทดสอบคอร์โดเมน เพราะมันใช้เหตุผลตามได้ง่ายกว่า แต่ `mockall` ก็เป็นตัวเลือกที่ใช้ได้สมบูรณ์ โดยเฉพาะเมื่อพื้นผิวเทรตของคุณโตขึ้น

## การทดสอบการผสานด้วย oneshot

นี่คือจุดที่ทุกอย่างเข้าล็อกจริงๆ การผสานของ Axum กับ Tower หมายความว่าเราสามารถทดสอบไปป์ไลน์ HTTP ทั้งหมดของเราได้โดยไม่ต้องสตาร์ตเซิร์ฟเวอร์จริงเลย เมธอด `tower::ServiceExt::oneshot` ส่งคำขอหนึ่งคำขอผ่านเราเตอร์แล้วคืนการตอบกลับ มันวิ่งผ่านมิดเดิลแวร์ ตัวแยกข้อมูล การซีเรียลไลซ์ และการจัดการข้อผิดพลาดของคุณทั้งหมด เหมือนกับที่คำขอจริงจะถูกวิ่งผ่าน

```rust
use axum::body::Body;
use http::Request;
use tower::ServiceExt;
use http_body_util::BodyExt;

/// Build the application the same way production does, but with a test database.
async fn test_app() -> Router {
    let pool = create_test_pool().await;
    create_app_with_pool(pool).await
}

#[tokio::test]
async fn health_check_returns_200() {
    let app = test_app().await;

    let response = app
        .oneshot(
            Request::builder()
                .uri("/health")
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();

    assert_eq!(response.status(), StatusCode::OK);
}

#[tokio::test]
async fn creating_a_user_returns_201() {
    let app = test_app().await;

    let response = app
        .oneshot(
            Request::builder()
                .method("POST")
                .uri("/api/v1/users")
                .header("Content-Type", "application/json")
                .body(Body::from(serde_json::to_string(&serde_json::json!({
                    "name": "Alice",
                    "email": "alice@example.com",
                    "password": "securepassword"
                })).unwrap()))
                .unwrap(),
        )
        .await
        .unwrap();

    assert_eq!(response.status(), StatusCode::CREATED);

    let body = response.into_body().collect().await.unwrap().to_bytes();
    let user: serde_json::Value = serde_json::from_slice(&body).unwrap();
    assert_eq!(user["data"]["name"], "Alice");
    assert_eq!(user["data"]["email"], "alice@example.com");
}

#[tokio::test]
async fn creating_a_user_with_invalid_email_returns_400() {
    let app = test_app().await;

    let response = app
        .oneshot(
            Request::builder()
                .method("POST")
                .uri("/api/v1/users")
                .header("Content-Type", "application/json")
                .body(Body::from(r#"{"name":"Alice","email":"not-an-email","password":"securepassword"}"#))
                .unwrap(),
        )
        .await
        .unwrap();

    assert_eq!(response.status(), StatusCode::BAD_REQUEST);
}
```

สิ่งที่สำคัญตรงนี้คือ `test_app()` สร้างเราเตอร์ด้วยฟังก์ชัน `create_app` เดียวกัน (หรือใกล้เคียงมาก) กับที่ production ใช้ นั่นหมายความว่าการทดสอบการผสานของเราวิ่งผ่านสแตกมิดเดิลแวร์เดียวกัน ตัวแยกข้อมูลเดียวกัน และการจัดการข้อผิดพลาดเดียวกันกับ production ถ้ามีอะไรพังในวิธีที่ชิ้นส่วนเหล่านี้ประกอบเข้าด้วยกัน เราจะจับมันได้ที่นี่

ทีนี้ ขอพูดตรงๆ ว่าการทดสอบในโพรเซสเหล่านี้ไม่ได้ครอบคลุมอะไรบ้าง เพราะ `oneshot` ส่งคำขอผ่านเราเตอร์โดยตรงโดยไม่ผ่านซ็อกเก็ตจริง เราไม่ได้ทดสอบการยุติ TLS พฤติกรรมรีเวิร์สพร็อกซี การตรวจสุขภาพของโหลดบาลานเซอร์ หรืออะไรก็ตามที่เกี่ยวกับโทโพโลยีการดีพลอยต์ของคุณ การทดสอบเหล่านี้ยอดเยี่ยมสำหรับการตรวจสอบตรรกะของแอปพลิเคชัน แต่มันไม่ใช่สิ่งทดแทนการทดสอบควัน (smoke test) กับเซิร์ฟเวอร์ที่รันจริงในสเตจิง

## การจัดการฐานข้อมูลสำหรับทดสอบ

การทดสอบการผสานที่ตีฐานข้อมูลจริงจำเป็นต้องมีกลยุทธ์สำหรับการแยกขาดจากกัน คุณคงไม่ต้องการให้ข้อมูลค้างของการทดสอบหนึ่งไปกวนความคาดหมายของการทดสอบอีกอันหนึ่ง ผมโดนกัดเรื่องนี้มากครั้งเกินกว่าจะยอมรับ

**ฐานข้อมูลแยกต่อการทดสอบด้วย SQLx** นี่คือแนวทางที่ผมใช้ประจำ SQLx มีแอตทริบิวต์ `#[sqlx::test]` ที่สร้างฐานข้อมูลใหม่ชื่อไม่ซ้ำสำหรับการทดสอบแต่ละรายการและรันไมเกรชันของคุณกับมัน เมื่อการทดสอบจบ ฐานข้อมูลจะถูกลบทิ้ง การแยกขาดที่สมบูรณ์แบบ ด้วยความพยายามน้อยที่สุด:

```rust
#[sqlx::test(migrations = "./migrations")]
async fn test_user_creation(pool: PgPool) {
    let repo = PostgresUserRepo::new(pool);
    let req = CreateUserRequest { /* ... */ };

    let user = repo.create(&req).await.unwrap();
    assert_eq!(user.email().as_str(), "alice@example.com");
}
```

**ฐานข้อมูลสำหรับทดสอบร่วมกันพร้อมการทำความสะอาด** อีกทางเลือกคือใช้ฐานข้อมูลสำหรับทดสอบตัวเดียวและทำความสะอาดระหว่างการทดสอบ ไม่ว่าจะโดยการตัด (truncate) ตาราง หรือห่อการทดสอบแต่ละรายการในธุรกรรมที่คุณโรลแบ็กตอนจบ วิธีนี้เร็วกว่าการสร้างและลบฐานข้อมูล แต่มันต้องการการจัดการที่ระมัดระวังกว่า คุณอาจสงสัยว่าการแลกความเร็วนั้นคุ้มกับความซับซ้อนหรือไม่ จากประสบการณ์ของผม มันมักไม่คุ้มสำหรับทีมส่วนใหญ่ แต่ถ้าชุดทดสอบของคุณใช้เวลารันหลายนาที มันก็คุ้มที่จะพิจารณา

**SQLite ในหน่วยความจำสำหรับการทดสอบที่เร็ว** ถ้า SQL ของคุณเข้ากันได้กับ SQLite (และมันมักเข้ากันได้สำหรับการดำเนินการ CRUD ง่ายๆ) คุณสามารถใช้ฐานข้อมูล SQLite แบบในหน่วยความจำเพื่อให้การรันทดสอบเร็วสุดขีด นี่มีประโยชน์เป็นพิเศษสำหรับการทดสอบระดับรีพอสิทอรีที่คุณต้องการตรวจสอบตรรกะควิวรีโดยไม่ต้องแบกโอเวอร์เฮดของ PostgreSQL

## ตัวช่วยทดสอบ

เมื่อชุดทดสอบของคุณโตขึ้น คุณจะเริ่มสังเกตเห็นโค้ดตั้งค่าแบบเดียวกันโผล่มาทั่วทุกที่ การสร้างคำขอ การสร้างผู้ใช้ทดสอบ การแยกวิเคราะห์บอดี้การตอบกลับ ตอนแรกมันอาจดูน่าเบื่อ แต่การสละเวลาเพื่อสกัดตัวช่วยร่วมกันออกมาสร้างความแตกต่างจริงๆ นี่คือแพตเทิร์นที่ผมพบว่าใช้ได้ดี:

```rust
// tests/common/mod.rs

pub async fn test_app() -> Router {
    let pool = PgPool::connect(&test_database_url()).await.unwrap();
    sqlx::migrate!("./migrations").run(&pool).await.unwrap();
    create_app_with_pool(pool).await
}

pub fn test_database_url() -> String {
    std::env::var("TEST_DATABASE_URL")
        .unwrap_or_else(|_| "postgres://localhost/myapp_test".to_string())
}

pub async fn create_test_user(app: &Router) -> (Uuid, String) {
    // Helper that creates a user and returns (user_id, auth_token)
    // Reduces boilerplate in tests that need an authenticated user
    // ...
}

pub async fn response_json(response: Response) -> serde_json::Value {
    let body = response.into_body().collect().await.unwrap().to_bytes();
    serde_json::from_slice(&body).unwrap()
}
```

## สิ่งที่ควรทดสอบ

แล้วจริงๆ แล้วคุณควรใช้เวลาทดสอบกับอะไรล่ะ? มาสนใจสิ่งที่สำคัญที่สุดกัน

**ทดสอบเส้นทางแห่งความสำเร็จ (happy path)** ของทุกเอนด์พอยต์ ตรวจสอบว่าอินพุตที่ถูกต้องให้การตอบกลับที่คาดหวังพร้อมรหัสสถานะและรูปทรงบอดี้ที่ถูกต้อง นี่คือเส้นฐาน

**ทดสอบความล้มเหลวจากการตรวจสอบความถูกต้อง** ส่งอินพุตที่ไม่ถูกต้องและตรวจสอบว่า API คืนการตอบกลับข้อผิดพลาดที่เหมาะสม นี่จับรีเกรสชันที่กฎการตรวจสอบถูกเอาออกหรือถูกทำให้อ่อนลงโดยไม่ตั้งใจ ซึ่งเกิดขึ้นบ่อยกว่าที่คุณคิด

**ทดสอบการอนุญาตสิทธิ์** ตรวจสอบว่าคำขอที่ไม่ผ่านการยืนยันตัวตนถูกปฏิเสธ ผู้ใช้ไม่สามารถเข้าถึงข้อมูลของผู้ใช้อื่น และข้อจำกัดตามบทบาทถูกบังคับใช้ บั๊กด้านความปลอดภัยคือสิ่งที่ทำให้คุณนอนไม่หลับตอนกลางคืน

**ทดสอบการแปลงข้อผิดพลาด** ตรวจสอบว่าข้อผิดพลาดของโดเมน (เช่น อีเมลซ้ำ) ให้รหัสสถานะ HTTP และข้อความข้อผิดพลาดที่ถูกต้อง ไม่ใช่การตอบกลับ 500 ทั่วไป เราทุ่มเทกับชนิดข้อมูลข้อผิดพลาดของเรามามากในบทก่อนหน้า มาทำให้แน่ใจว่ามันไปถึงไคลเอนต์อย่างถูกต้องจริงๆ

**ทดสอบกรณีขอบในตรรกะโดเมน** สตริงว่าง สตริงยาวมาก ค่าขอบเขต การรวมกันของอินพุตที่ผิดปกติ บั๊กชอบซ่อนตัวอยู่ตรงนี้ สิ่งเหล่านี้เหมาะที่จะทดสอบที่ระดับหน่วย ซึ่งการทดสอบเร็วและพุ่งเป้า

อีกเรื่องสุดท้าย: อย่าหมกมุ่นกับความครอบคลุมโค้ดในฐานะเมตริก ชุดทดสอบที่ครอบคลุมพฤติกรรมสำคัญและกรณีขอบอย่างไตร่ตรองมีค่ายิ่งกว่าชุดที่ไล่ตามความครอบคลุม 90% ด้วยการทดสอบเก็ตเตอร์และเซ็ตเตอร์จิ๊บจ๊อย สิ่งที่ผมพบคือตัวเลขความครอบคลุมทำให้คุณรู้สึกดี แต่การทดสอบที่เลือกมาอย่างดีต่างหากที่จับบั๊กได้จริงก่อนที่มันจะถูกส่งออกไป เมื่อกลยุทธ์การทดสอบของเราเข้าที่แล้ว มาต่อกันที่การนำแอปพลิเคชันของเราไปดีพลอยต์และรันใน production กัน
