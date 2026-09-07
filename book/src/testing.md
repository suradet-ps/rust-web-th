# การทดสอบ

ถ้าคุณเคย deploy เว็บเซอร์วิสขึ้น production แล้วต้องใช้เวลาตลอดสัปดาห์ถัดมานั่งจ้อง log ด้วยความกังวลใจ คุณคงเข้าใจความรู้สึกนั้นเป็นอย่างดี การทดสอบ (Testing) คือสิ่งที่ช่วยให้เรานอนหลับได้อย่างสบายใจในตอนกลางคืน ทว่าการทดสอบเว็บแอปพลิเคชันไม่ได้มีเพียงมิติเดียว เราต้องการทั้ง unit test เพื่อตรวจสอบ business logic แบบแยกเดี่ยว (in isolation), integration test ที่วิ่งทดสอบตลอดทั้ง pipeline ตั้งแต่ request ไปจนถึง response รวมถึงกลยุทธ์ที่มั่นคงในการจัดการฐานข้อมูลสำหรับทดสอบและ dependency ภายนอก ในบทนี้ ผมจะพาคุณสำรวจแพตเทิร์นและเครื่องมือต่างๆ ที่ทำให้การทดสอบแอปพลิเคชัน Axum ใช้งานได้จริงในชีวิตประจำวัน และเอาเข้าจริงแล้ว มันค่อนข้างสนุกทีเดียว

## พีระมิดการทดสอบ

คุณคงเคยได้ยินเกี่ยวกับพีระมิดการทดสอบ (Testing Pyramid) มาก่อน แม้จะเป็นแนวคิดเรียบง่าย แต่มันกลับใช้งานได้ดีเยี่ยมในทางปฏิบัติ ที่ฐานล่างสุด เราจะเขียน unit test จำนวนมากที่ทำงานได้รวดเร็ว เพื่อตรวจสอบการทำงานของแต่ละฟังก์ชันและ domain logic ถัดขึ้นมาตรงกลาง เรามี integration test ที่ครอบคลุมทั้ง HTTP handler pipeline ตั้งแต่มิดเดิลแวร์, extractor, serialization ไปจนถึงการเข้าถึงฐานข้อมูล และที่ยอดบนสุด เราจะสงวนไว้สำหรับ end-to-end test ในจำนวนไม่มาก เพื่อตรวจสอบ user flow ที่สำคัญกับเซิร์ฟเวอร์ที่รันอยู่จริงๆ

จากประสบการณ์ของผม ความพยายามในการทดสอบส่วนใหญ่ควรทุ่มเทให้กับสองชั้นล่าง Unit test ช่วยดักจับบั๊กเชิงตรรกะได้อย่างรวดเร็วและใช้ต้นทุนต่ำ ส่วน integration test จะช่วยยืนยันว่าเลเยอร์ทั้งหมดถูกร้อยเรียงเข้าด้วยกันอย่างถูกต้องจริงๆ สำหรับ end-to-end test แม้จะมีประโยชน์อย่างยิ่งกับ critical path แต่การทดสอบระดับนี้ทำงานช้าและเปราะบางกว่ามาก ผมจึงแนะนำให้ใช้เท่าที่จำเป็นจริงๆ

## การทดสอบหน่วยตรรกะโดเมน

นี่คือจุดที่การลงทุนสร้าง clean architecture ในบทก่อนหน้าเริ่มออกดอกออกผลอย่างแท้จริง เพราะเลเยอร์โดเมนไม่มี dependency ผูกติดกับ Axum, SQLx หรือเฟรมเวิร์กใดๆ เลย การทดสอบจึงเรียบง่ายอย่างน่าประทับใจ เราแค่สร้าง domain type เรียกใช้ service method แล้ว assert ตรวจสอบผลลัพธ์ ไม่ต้องมี HTTP server ไม่ต้องต่อฐานข้อมูล และไม่มีอะไรซับซ้อนยุ่งยาก

หากเซอร์วิสของคุณใช้งาน repository ผ่าน trait (ตามที่เราออกแบบไว้ในบท [แพตเทิร์นสถาปัตยกรรม](./architecture.md)) คุณก็สามารถส่ง in-memory implementation เข้าไปสำหรับการทดสอบได้อย่างง่ายดาย:

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

การทดสอบเหล่านี้ทำงานเสร็จสิ้นภายในเสี้ยววินาที (ระดับมิลลิวินาที) เพราะไม่มีการแตะต้องเน็ตเวิร์กหรือระบบไฟล์เลย เป็นการยืนยันว่า business logic ของคุณทำงานถูกต้อง โดยไม่ขึ้นกับวิธีการเรียกใช้หรือตำแหน่งที่จัดเก็บข้อมูล ความเร็วนั้นสำคัญมาก เพราะเมื่อ test suite ทำงานได้รวดเร็ว คุณและทีมก็พร้อมที่จะรันมันบ่อยๆ จริงๆ

หากการเขียน in-memory implementation เหล่านี้ดูมี boilerplate มากเกินไป (ซึ่งก็เป็นไปได้) crate อย่าง `mockall` สามารถสร้าง mock implementation สำหรับ repository trait ของคุณได้โดยอัตโนมัติ โดยส่วนตัวผมมักชอบเขียน fake ขึ้นมาเองสำหรับการทดสอบ core domain เพราะไล่เรียงทำความเข้าใจได้ง่ายกว่า แต่ `mockall` ก็เป็นตัวเลือกที่ยอดเยี่ยมเช่นกัน โดยเฉพาะอย่างยิ่งเมื่อขนาดและจำนวนเมธอดของ trait เริ่มขยายใหญ่ขึ้น

## การทดสอบการผสานด้วย oneshot

นี่คือจุดเด่นที่น่าประทับใจอย่างยิ่ง การที่ Axum ผสานการทำงานร่วมกับ Tower อย่างแนบแน่น ทำให้เราสามารถทดสอบ HTTP pipeline ทั้งหมดได้โดยไม่ต้องสตาร์ตเซิร์ฟเวอร์จริงๆ เลย เมธอด `tower::ServiceExt::oneshot` จะส่ง request หนึ่งคำขอผ่านเราเตอร์แล้วคืนค่า response กลับมา โดยคำขอนี้จะวิ่งผ่านทั้งมิดเดิลแวร์, extractor, serialization และกลไกจัดการ error ของคุณอย่างครบถ้วน ไม่ต่างจากคำขอจริงที่เข้ามาทางเน็ตเวิร์กแม้แต่น้อย

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

จุดสำคัญในที่นี้คือ `test_app()` ประกอบ router ขึ้นมาด้วยฟังก์ชัน `create_app` ตัวเดียวกับที่ใช้งานบน production (หรือใกล้เคียงกันมากที่สุด) นั่นหมายความว่า integration test ของเราจะวิ่งผ่าน middleware stack เดียวกัน, extractor ชุดเดียวกัน และการจัดการ error แบบเดียวกันกับบน production หากมีจุดผิดพลาดจากการประกอบชิ้นส่วนเหล่านี้เข้าด้วยกัน เราก็จะตรวจพบได้ทันทีตั้งแต่ขั้นตอนนี้

อย่างไรก็ดี เราต้องเข้าใจข้อจำกัดด้วยว่าการทดสอบแบบ in-process เช่นนี้ไม่ได้ครอบคลุมทุกเรื่อง เนื่องจาก `oneshot` ส่งคำขอเข้าไปยังเราเตอร์โดยตรงโดยไม่ผ่าน socket จริง เราจึงไม่ได้ทดสอบการทำ TLS termination, พฤติกรรมของ reverse proxy, health check ของ load balancer หรือโครงสร้างการ deploy (deployment topology) แต่อย่างใด การทดสอบลักษณะนี้ยอดเยี่ยมมากสำหรับการตรวจสอบ logic ของแอปพลิเคชัน แต่มันไม่อาจทดแทน smoke test กับเซิร์ฟเวอร์ที่รันอยู่จริงๆ บนสภาพแวดล้อม staging ได้

## การจัดการฐานข้อมูลสำหรับทดสอบ

Integration test ที่ต้องต่อเข้ากับฐานข้อมูลจริงจำเป็นต้องมีกลยุทธ์การแยกชุดข้อมูล (Test Isolation) ที่ชัดเจน เพราะคุณคงไม่อยากให้ข้อมูลที่คั่งค้างจากการทดสอบหนึ่งไปรบกวนผลลัพธ์ของการทดสอบอีกตัวหนึ่ง ซึ่งผมเองเคยเจอปัญหานี้บ่อยครั้งจนนับไม่ถ้วน

**แยกฐานข้อมูลต่อหนึ่งเทสต์ด้วย SQLx (Per-test databases with SQLx)** นี่คือแนวทางหลักที่ผมเลือกใช้ประจำ โดย SQLx มี attribute `#[sqlx::test]` ที่จะสร้างฐานข้อมูลใหม่พร้อมตั้งชื่อไม่ให้ซ้ำกันสำหรับการทดสอบแต่ละเคสโดยเฉพาะ แล้วรัน migration ให้โดยอัตโนมัติ และเมื่อการทดสอบเสร็จสิ้น ตัวฐานข้อมูลก็จะถูกลบทิ้งไปทันที มอบ isolation ที่สมบูรณ์แบบโดยแทบไม่ต้องออกแรงเพิ่ม:

```rust
#[sqlx::test(migrations = "./migrations")]
async fn test_user_creation(pool: PgPool) {
    let repo = PostgresUserRepo::new(pool);
    let req = CreateUserRequest { /* ... */ };

    let user = repo.create(&req).await.unwrap();
    assert_eq!(user.email().as_str(), "alice@example.com");
}
```

**ใช้ฐานข้อมูลทดสอบร่วมกันพร้อมเคลียร์ข้อมูล (Shared test database with cleanup)** อีกทางเลือกหนึ่งคือการใช้ฐานข้อมูลทดสอบร่วมกันเพียงตัวเดียว แล้วทำการล้างข้อมูลระหว่างการทดสอบแต่ละเคส ไม่ว่าจะใช้วิธี truncate ข้อมูลในตาราง หรือครอบการทดสอบแต่ละรายการไว้ใน database transaction แล้วสั่ง rollback เมื่อทดสอบเสร็จสิ้น วิธีนี้จะเร็วกว่าการสร้างและลบฐานข้อมูลใหม่ทุกครั้ง ทว่าจำเป็นต้องมีการจัดการที่รัดกุมรอบคอบ คุณอาจสงสัยว่าความเร็วที่ได้มานั้นคุ้มค่ากับความซับซ้อนที่เพิ่มขึ้นหรือไม่ จากประสบการณ์ของผม สำหรับทีมส่วนใหญ่มักไม่ค่อยคุ้มค่านัก แต่หาก test suite ของคุณเริ่มใช้เวลารันนานหลายนาที ทางเลือกนี้ก็นับว่าคุ้มค่าที่จะพิจารณา

**In-memory SQLite เพื่อการทดสอบที่รวดเร็วเป็นพิเศษ** หากคำสั่ง SQL ของคุณเข้ากันได้กับ SQLite (ซึ่งมักจะเข้ากันได้ดีกับการทำ CRUD ทั่วไป) คุณสามารถใช้ in-memory SQLite เพื่อให้การรันเทสต์ทำได้อย่างรวดเร็วสูงสุด วิธีนี้มีประโยชน์อย่างยิ่งสำหรับการทดสอบระดับ repository ที่คุณต้องการเพียงตรวจสอบ logic ของ query โดยไม่ต้องแบกรับ overhead จากการรัน PostgreSQL เต็มรูปแบบ

## ตัวช่วยทดสอบ

เมื่อ test suite ของคุณเติบโตขึ้นเรื่อยๆ คุณจะเริ่มสังเกตเห็นโค้ด setup ซ้ำๆ กระจายอยู่ทั่วทุกแห่ง ไม่ว่าจะเป็นการสร้าง request, การสร้าง test user หรือการแกะ parse response body ในตอนแรกคุณอาจรู้สึกว่าเป็นเรื่องเล็กน้อย แต่การสละเวลาสกัดโค้ดเหล่านั้นออกมาเป็น test helper กลาง จะช่วยยกระดับความสะดวกในการพัฒนาได้อย่างมหาศาล และนี่คือแพตเทิร์นที่ผมพบว่าทำงานได้ดีมาก:

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

แล้วในทางปฏิบัติ คุณควรทุ่มเทเวลาให้กับการทดสอบส่วนไหนบ้าง? มาโฟกัสที่สิ่งที่สำคัญที่สุดกันครับ:

**ทดสอบ Happy Path ของทุก endpoint** ตรวจสอบว่า input ที่ถูกต้องจะส่ง response ที่ตรงตามคาดหวังกลับมา ทั้ง status code และโครงสร้างของ body นี่คือบรรทัดฐานขั้นต่ำที่ต้องมีเสมอ

**ทดสอบกรณี Validation ล้มเหลว** ลองส่งข้อมูลที่ไม่ถูกต้องเข้าไป แล้วตรวจสอบว่า API คืน error response ที่เหมาะสมกลับมาหรือไม่ การทดสอบนี้จะช่วยดักจับ regression เมื่อมีใครเผลอลบหรือผ่อนปรน validation rule โดยไม่ตั้งใจ ซึ่งเป็นปัญหาที่เกิดขึ้นบ่อยกว่าที่คุณคิด

**ทดสอบ Authorization และสิทธิ์การเข้าถึง** ยืนยันว่าคำขอที่ไม่ผ่าน authentication จะต้องถูกปฏิเสธเสมอ, ผู้ใช้คนหนึ่งไม่สามารถแอบดูหรือแก้ไขข้อมูลของผู้ใช้คนอื่นได้ และบทบาท (role) ต่างๆ ถูกบังคับใช้อย่างเคร่งครัด เพราะช่องโหว่ด้านความปลอดภัยคือสิ่งที่จะทำให้คุณนอนไม่หลับในยามค่ำคืน

**ทดสอบ Error Mapping** ยืนยันว่า domain error (เช่น อีเมลซ้ำ) ถูกแปลงออกมาเป็น HTTP status code และ error message ที่ถูกต้องเหมาะสม ไม่ใช่ตอบกลับด้วย 500 Internal Server Error ทั่วไป เราได้ลงทุนลงแรงออกแบบ error type ไว้อย่างดีในบทก่อนหน้าแล้ว จึงควรตรวจสอบให้แน่ใจว่าพวกมันถูกสื่อสารไปยัง client ได้อย่างถูกต้องสมบูรณ์

**ทดสอบ Edge Case ใน domain logic** ไม่ว่าจะเป็นสตริงว่าง, สตริงขนาดยาวเป็นพิเศษ, ค่าที่ขอบเขต (boundary values) หรือการส่งอินพุตประหลาดๆ มารวมกัน บั๊กมักชอบแอบซ่อนอยู่ในจุดเหล่านี้ ซึ่งกรณีเหล่านี้เหมาะที่สุดที่จะทดสอบในระดับ unit test เพราะทำงานได้รวดเร็วและโฟกัสได้อย่างตรงจุด

และข้อคิดสุดท้าย: อย่าหลงหมกมุ่นกับตัวเลข Code Coverage จนเกินไป Test suite ที่ผ่านการคิดใคร่ครวญจนครอบคลุมพฤติกรรมสำคัญและ edge case ต่างๆ มีคุณค่ามากกว่าชุดทดสอบที่วิ่งไล่ตามตัวเลข coverage 90% โดยการทดสอบ getter และ setter จุกจิก สิ่งที่ผมพบเสมอคือ ตัวเลข coverage อาจช่วยให้คุณรู้สึกสบายใจ แต่ชุดการทดสอบที่คัดสรรมาอย่างรอบคอบต่างหากที่จะช่วยดักจับบั๊กได้จริงก่อนขึ้นระบบ เมื่อกลยุทธ์การทดสอบของเราพร้อมแล้ว ต่อไปเราจะไปดูเรื่องการนำแอปพลิเคชันไป deploy และรันบน production กันครับ
