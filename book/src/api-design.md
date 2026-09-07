# การออกแบบ API

หากคุณเคยต้องเชื่อมต่อกับ API ที่แต่ละ endpoint ส่งข้อมูลกลับมาในรูปแบบที่แตกต่างกันคนละทิศคนละทาง คุณคงเข้าใจดีว่ามันน่าหงุดหงิดเพียงใด เพราะคุณต้องเสียเวลาไปกับการอ่านเอกสาร (หรือนั่งเดา) มากกว่าการลงมือพัฒนาฟีเจอร์จริงๆ เสียอีก แน่นอนว่าเราคงไม่อยากสร้างประสบการณ์แบบนั้นให้ใคร รวมถึงตัวเราเองในอนาคตด้วย ในบทนี้ เราจะมาดูข้อตกลงในการออกแบบ REST, แพตเทิร์นโครงสร้างของ response, กลยุทธ์การทำ pagination และแนวทางการทำ API documentation ที่จะช่วยให้ Axum API ของเรามีความสม่ำเสมอ คาดเดาได้ง่าย และน่าใช้งาน

## ข้อตกลงของ REST

REST ไม่ใช่มาตรฐานที่มีข้อกำหนดตายตัวแบบเป็นทางการ แต่เป็นชุดแนวปฏิบัติหรือข้อตกลงร่วม (conventions) ที่ผู้ใช้งาน API ส่วนใหญ่คุ้นเคยและคาดหวังว่าจะได้เห็น มาดูข้อตกลงสำคัญที่สุดกัน:

**ใช้คำนามพหูพจน์สำหรับ resource** เช่น `/api/v1/users` ไม่ใช่ `/api/v1/user` โดยชื่อ resource ควรเป็นตัวแทนของ collection และข้อมูลแต่ละรายการภายใน collection นั้นจะถูกเข้าถึงผ่าน ID ของมัน

**ใช้ HTTP methods สื่อความหมายของการกระทำ** เช่น `GET` สำหรับดึงข้อมูล, `POST` สำหรับสร้าง resource ใหม่, `PUT` สำหรับแทนที่ข้อมูลทั้งชุด, `PATCH` สำหรับอัปเดตข้อมูลบางฟิลด์ และ `DELETE` สำหรับลบข้อมูล แม้หลักการนี้จะฟังดูตรงไปตรงมา แต่ผมยังเห็น API จำนวนไม่น้อยที่ใช้ `POST` กับทุกสิ่งทุกอย่าง

**เลือกใช้ HTTP Status Code ให้ถูกต้องและเหมาะสม** บอกตามตรงว่านี่คือหนึ่งในจุดที่ยกระดับความน่าใช้งานของ API ได้มากที่สุด: เมื่อไคลเอนต์สร้าง resource สำเร็จ ควรส่ง `201 Created` กลับไป ไม่ใช่ `200 OK`, เมื่อลบข้อมูลสำเร็จ ควรตอบกลับด้วย `204 No Content`, เมื่อไคลเอนต์ส่งข้อมูลไม่ถูกต้อง ควรตอบด้วย `400 Bad Request` พร้อมระบุรายละเอียดข้อผิดพลาด และเมื่อค้นหาข้อมูลไม่พบ ควรใช้ `404 Not Found`

ตารางสรุป HTTP Status Codes ที่คุณจะได้ใช้งานบ่อยที่สุด:

| รหัส | ความหมาย | เมื่อใดควรใช้ |
|------|---------|------------|
| 200 | OK | อ่านหรืออัปเดตข้อมูลสำเร็จ |
| 201 | Created | สร้าง resource ใหม่สำเร็จ |
| 204 | No Content | ดำเนินการสำเร็จโดยไม่มีเนื้อหาใน response body (เช่น การลบข้อมูล) |
| 400 | Bad Request | ข้อมูล input ไม่ถูกต้อง หรือ validation ล้มเหลว |
| 401 | Unauthorized | ไม่ได้แนบข้อมูลยืนยันตัวตนมา หรือข้อมูลไม่ถูกต้อง |
| 403 | Forbidden | ยืนยันตัวตนผ่านแล้ว แต่ไม่มีสิทธิ์เข้าถึง resource นี้ |
| 404 | Not Found | ไม่พบ resource ที่ร้องขอ |
| 409 | Conflict | ขัดต่อกฎทางธุรกิจ (เช่น อีเมลซ้ำในระบบ) |
| 422 | Unprocessable Entity | รูปแบบข้อมูลถูกต้องตาม syntax แต่ผิดเงื่อนไขเชิงความหมาย (semantic) |
| 500 | Internal Server Error | เกิดข้อผิดพลาดที่ไม่คาดคิดขึ้นที่ฝั่งเซิร์ฟเวอร์ |

## การกำหนดเวอร์ชัน API

หากคุณกำลังพัฒนา Public API หรือ Platform Service แนะนำให้วางแผนเรื่องการทำ versioning ไว้ตั้งแต่เริ่มต้น เพราะการมาเพิ่ม version ทีหลังมักจะนำไปสู่ breaking changes หรือไม่ก็ต้องใช้วิธีแก้ปัญหาแบบชั่วคราวที่ไม่น่าดู ในขณะที่ต้นทุนของการใส่ prefix `/v1` ลงใน route ตั้งแต่วันแรกนั้นแทบจะเป็นศูนย์

แต่สำหรับ internal service ที่ deploy ไปพร้อมๆ กับระบบผู้เรียกใช้งาน การทำ path-based versioning อาจมีความจำเป็นน้อยกว่า จากประสบการณ์จริง การมีวินัยในการพัฒนา schema อย่างต่อเนื่อง (เช่น การเพิ่มฟิลด์ใหม่แบบ additive, การกำหนดระยะเวลา deprecation ที่ชัดเจน, การทำ contract testing) มักจะสำคัญกว่าการตั้ง version prefix เสียอีก ดังนั้นอย่าทำ versioning เพียงเพราะมีใครบอกให้ทำ แต่จงทำเมื่อผู้ใช้งานระบบของคุณต้องการการรับประกันความเสถียร (stability guarantees) ที่ไม่สามารถจัดการได้ด้วยการประสานงานภายในทีมเพียงอย่างเดียว

แนวทางที่ง่ายและนิยมใช้งานกันแพร่หลายที่สุดคือการกำหนดเวอร์ชันผ่าน URL path:

```rust
fn api_routes() -> Router<AppState> {
    Router::new()
        .nest("/api/v1", v1_routes())
}

fn v1_routes() -> Router<AppState> {
    Router::new()
        .nest("/users", user_routes())
        .nest("/posts", post_routes())
}
```

และเมื่อถึงวันที่คุณจำเป็นต้องปล่อย API v2 สำหรับบาง endpoint คุณก็สามารถเปิดใช้งานควบคู่ไปกับ v1 ได้ทันทีโดยไม่กระทบต่อผู้ใช้งานเดิม:

```rust
fn api_routes() -> Router<AppState> {
    Router::new()
        .nest("/api/v1", v1_routes())
        .nest("/api/v2", v2_routes())
}
```

ข้อควรระวังประการหนึ่งคือ: พยายามออกแบบ handler implementation ให้ decoupled ออกจาก version prefix เพื่อให้ route ของทั้ง v1 และ v2 สามารถแชร์ service logic เบื้องหลังร่วมกันได้ ในจุดที่พฤติกรรมการทำงานยังคงเหมือนเดิม

## รูปทรงการตอบกลับที่สม่ำเสมอ

คุณอาจสงสัยว่าทำไมเราต้องครอบทุก response ด้วยชนิดข้อมูลมาตรฐาน เหตุผลง่ายๆ คือ: เมื่อทุก endpoint ส่งข้อมูลกลับมาในโครงสร้างที่คาดเดาได้ ฝั่งไคลเอนต์จะสามารถเขียนโค้ด parsing กลางชุดเดียวมาประมวลผลได้ทันที แทนที่จะต้องเขียนโค้ดดักเคสพิเศษแยกเป็นราย endpoint มาลองกำหนด wrapper type มาตรฐานกันสัก 2-3 ตัว:

```rust
#[derive(Serialize)]
pub struct ApiResponse<T: Serialize> {
    pub data: T,
}

#[derive(Serialize)]
pub struct PaginatedResponse<T: Serialize> {
    pub data: Vec<T>,
    pub meta: PaginationMeta,
}

#[derive(Serialize)]
pub struct PaginationMeta {
    pub page: u32,
    pub per_page: u32,
    pub total: u64,
    pub total_pages: u32,
}
```

สำหรับ error response เราจะใช้รูปแบบเดียวกับที่อธิบายไว้ในบท [การจัดการข้อผิดพลาด](./error-handling.md) เพื่อให้ไคลเอนต์สามารถตรวจสอบฟิลด์ `error` เพื่อตัดสินได้เสมอว่าคำขอนั้นสำเร็จหรือไม่

## การแบ่งหน้า

endpoint ใดก็ตามที่คืนค่าเป็นรายการ resource ควรจะต้องรองรับการทำ pagination เสมอ หากไม่มีระบบนี้ เพียงแค่เจอชุดข้อมูลขนาดใหญ่เพียงครั้งเดียว เซิร์ฟเวอร์ของคุณก็อาจเจอปัญหา timeout, out-of-memory error หรือทำให้ผู้ใช้งานไม่พอใจได้ทันที เชื่อผมเถอะว่าการใส่ระบบ pagination ไว้ตั้งแต่ตอนนี้ ย่อมง่ายกว่าการตามมาแก้ไขทีหลังเมื่อตาราง users ของคุณเติบโตไปถึงระดับหลายแสนแถว

**การแบ่งหน้าแบบอิง Offset (Offset-based pagination)** เป็นวิธีที่เรียบง่ายที่สุด และทำงานได้ดีเมื่อปริมาณข้อมูลยังไม่มหาศาลมากนัก และไม่มีการเพิ่มหรือลบ record ถี่ๆ ในระหว่างที่ผู้ใช้กำลังเปิดดูหน้าถัดไป:

```rust
#[derive(Debug, Deserialize)]
pub struct PaginationParams {
    #[serde(default = "default_page")]
    pub page: u32,
    #[serde(default = "default_per_page")]
    pub per_page: u32,
}

fn default_page() -> u32 { 1 }
fn default_per_page() -> u32 { 20 }

async fn list_users(
    State(state): State<AppState>,
    Query(params): Query<PaginationParams>,
) -> AppResult<Json<PaginatedResponse<UserResponse>>> {
    let per_page = params.per_page.clamp(1, 100); // at least 1, at most 100
    let offset = (params.page.saturating_sub(1)) * per_page;

    let (users, total) = state.user_service
        .list(offset, per_page)
        .await?;

    Ok(Json(PaginatedResponse {
        data: users.into_iter().map(Into::into).collect(),
        meta: PaginationMeta {
            page: params.page,
            per_page,
            total,
            total_pages: total.div_ceil(per_page as u64) as u32,
        },
    }))
}
```

**การแบ่งหน้าแบบอิง Cursor (Cursor-based pagination)** เหมาะสมกว่ามากสำหรับชุดข้อมูลขนาดใหญ่หรือข้อมูลที่มีการเปลี่ยนแปลงอยู่ตลอดเวลา โดยแทนที่จะใช้ offset ฝั่งไคลเอนต์จะส่ง cursor (โดยทั่วไปคือ ID หรือ timestamp ของข้อมูลตัวสุดท้ายที่เพิ่งได้รับ) แล้วเซิร์ฟเวอร์จะคืนข้อมูลหน้าถัดไปโดยเริ่มต่อจาก cursor นั้น วิธีนี้ช่วยขจัดปัญหา "record เลื่อนหรือกระโดดข้าม" ซึ่งมักเกิดกับ offset-based pagination เมื่อข้อมูลมีการเพิ่มหรือลบระหว่างการเปิดหน้า

หากคุณไม่อยากเขียนตรรกะ cursor ด้วยตัวเอง crate อย่าง `paginator-axum` มีระบบ cursor-based pagination สำเร็จรูปพร้อม metadata ฟิลด์ `next_cursor` และ `prev_cursor` มาให้ ซึ่งถือเป็นจุดเริ่มต้นที่ดีมาก

## การกรองและการเรียงลำดับ

สำหรับ endpoint แบบรายการที่ต้องรองรับการกรองข้อมูล เราสามารถรับค่าตัวกรองผ่าน query parameters ได้อย่างตรงไปตรงมา:


```rust
#[derive(Debug, Deserialize)]
pub struct UserListParams {
    #[serde(default = "default_page")]
    pub page: u32,
    #[serde(default = "default_per_page")]
    pub per_page: u32,
    pub role: Option<Role>,
    pub search: Option<String>,
    #[serde(default = "default_sort")]
    pub sort_by: String,
    #[serde(default = "default_sort_direction")]
    pub sort_direction: SortDirection,
}
```

ข้อควรระวัง: ควรจำกัดและเลือกฟิลด์ที่อนุญาตให้เรียงลำดับ (sort) อย่างรอบคอบ และตรวจสอบให้แน่ใจว่าคอลัมน์เหล่านั้นมีการทำ index ในฐานข้อมูลแล้ว เพราะการเปิดให้ผู้ใช้สั่ง sort ตามคอลัมน์ที่ไม่มี index คือสูตรสำเร็จของ slow query ที่จะสร้างปัญหาใหญ่ให้คุณบน production อย่างแน่นอน

## เอกสารประกอบ OpenAPI

เราทุกคนต่างเคยพบเจอปัญหาเอกสาร API ที่เขียนไว้อย่างถูกต้องสมบูรณ์แบบเมื่อหกเดือนก่อน แล้วค่อยๆ ล้าสมัยจนเชื่อถือไม่ได้อีกต่อไปนับจากนั้น สิ่งที่ผมพบว่าได้ผลดีกว่ามากคือการ generate เอกสารออกมาจากโค้ดโดยตรง ซึ่ง crate อย่าง `utoipa` ทำหน้าที่นี้ได้อย่างสมบูรณ์แบบ โดยจะสร้างสเปก OpenAPI จาก type ใน Rust และ annotation บน handler ของคุณโดยตรง และเนื่องจากเอกสารสร้างมาจากโค้ดจริง มันจึงไม่มีวันล้าสมัย

```rust
use utoipa::{OpenApi, ToSchema};

#[derive(Serialize, ToSchema)]
pub struct UserResponse {
    pub id: Uuid,
    pub name: String,
    pub email: String,
    pub created_at: DateTime<Utc>,
}

#[utoipa::path(
    post,
    path = "/api/v1/users",
    request_body = CreateUserDto,
    responses(
        (status = 201, description = "User created successfully", body = UserResponse),
        (status = 400, description = "Validation error", body = ErrorResponse),
        (status = 409, description = "User with this email already exists", body = ErrorResponse),
    ),
    tag = "users"
)]
async fn create_user(
    State(state): State<AppState>,
    ValidatedJson(payload): ValidatedJson<CreateUserDto>,
) -> AppResult<(StatusCode, Json<UserResponse>)> {
    // ...
}
```

สำหรับการเปิดให้บริการ Swagger UI ควบคู่ไปกับ API เราสามารถเชื่อมต่อระบบได้ดังนี้:

```rust
use utoipa::OpenApi;
use utoipa_swagger_ui::SwaggerUi;

#[derive(OpenApi)]
#[openapi(
    paths(create_user, get_user, list_users, update_user, delete_user),
    components(schemas(UserResponse, CreateUserDto, UpdateUserDto, ErrorResponse)),
    tags((name = "users", description = "User management endpoints"))
)]
struct ApiDoc;

let app = Router::new()
    .merge(api_routes())
    .merge(SwaggerUi::new("/swagger-ui").url("/api-docs/openapi.json", ApiDoc::openapi()))
    .with_state(state);
```

เพียงเท่านี้ นักพัฒนาคนอื่นก็สามารถเปิดดูเอกสาร API ของเราผ่าน `/swagger-ui` และทดลองยิง request จากเบราว์เซอร์ได้โดยตรง สเปกทั้งหมดถูกสร้างขึ้นตั้งแต่ตอนคอมไพล์จาก data type และ handler จริง จึงรับประกันได้ว่าจะตรงกับโค้ดที่รันอยู่ 100% เสมอ ซึ่งเป็นคุณสมบัติที่ยอดเยี่ยมมาก

## เอนด์พอยต์ health check

Production API ทุกตัวจำเป็นต้องมี health check endpoint เสมอ เพื่อให้ Load Balancer และ Container Orchestrator มีช่องทางตรวจสอบว่าเซอร์วิสของเรายังมีชีวิตอยู่และพร้อมรับ traffic หรือไม่ มาดูวิธีติดตั้งกัน:

```rust
/// Liveness probe: is the process running and able to handle requests?
async fn health_live() -> StatusCode {
    StatusCode::OK
}

/// Readiness probe: is the application ready to serve traffic?
/// Checks that all dependencies (database, cache, etc.) are reachable.
async fn health_ready(State(state): State<AppState>) -> StatusCode {
    match sqlx::query("SELECT 1").execute(&state.db).await {
        Ok(_) => StatusCode::OK,
        Err(_) => StatusCode::SERVICE_UNAVAILABLE,
    }
}
```

เราจะติดตั้ง endpoint เหล่านี้ไว้นอก route API ที่มี versioning เพื่อให้ URL คงที่เสมอแม้ API หลักจะมีการปรับเปลี่ยนเวอร์ชันก็ตาม:

```rust
let app = Router::new()
    .route("/health", get(health_live))
    .route("/health/ready", get(health_ready))
    .merge(api_routes())  // api_routes() already nests under /api/v1
    .with_state(state);
```

Liveness probe ควรทำงานได้อย่างรวดเร็วและไม่มีเงื่อนไขซับซ้อน เพราะหน้าที่ของมันมีเพียงแค่บอก orchestrator ว่า "ใช่ process ยังทำงานอยู่" ในขณะที่ Readiness probe จะทำหน้าที่ตรวจเช็กความพร้อมของ dependencies ต่างๆ (เช่น database, cache) เพื่อให้ orchestrator มั่นใจว่า instance นี้พร้อมที่จะรับ traffic ได้อย่างปลอดภัย การสับสนระหว่างสองตัวนี้เป็นข้อผิดพลาดที่พบได้บ่อยมาก และมักส่งผลให้ container ที่ทำงานปกติดีถูก restart โดยไม่จำเป็น เพียงเพราะ database เกิดความล่าช้าชั่วคราว

การออกแบบ API ด้วยแนวทางเหล่านี้จะทำให้เราได้รากฐานที่มั่นคง: URL ที่เป็นมาตรฐาน, รูปแบบ response ที่คาดเดาได้, ระบบ pagination ที่รองรับการขยายตัว, เอกสาร API ที่ตรงกับโค้ดจริงเสมอ และ health check ที่คอยรายงานสถานะให้อินฟราสตรักเจอร์ทราบอย่างแม่นยำ ลำดับถัดไป เราจะมาดูวิธีจัดการกับข้อผิดพลาดที่ย่อมต้องเกิดขึ้นอย่างแน่นอนเมื่อระบบเหล่านี้ถูกนำไปรันบน production
