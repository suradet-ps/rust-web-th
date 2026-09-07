# การออกแบบ API

ถ้าคุณเคยผสานเข้ากับ API ที่ทุกเอนด์พอยต์คืนข้อมูลในรูปทรงที่ต่างกันเล็กน้อย คุณจะรู้ว่ามันน่าหงุดหงิดแค่ไหน คุณใช้เวลาอ่านเอกสาร (หรือเดา) มากกว่าสร้างของจริงเสียอีก ผมอยากให้เราไม่ทำแบบนั้นกับใคร รวมถึงตัวเราในอนาคต ในบทนี้เราจะเดินดูข้อตกลงของ REST แพตเทิร์นการตอบกลับ กลยุทธ์การแบ่งหน้า และแนวทางเอกสารประกอบ ที่จะทำให้ API Axum ของเราคาดเดาได้และน่าใช้

## ข้อตกลงของ REST

REST ไม่ใช่สเปกทางการที่มีกฎเคร่งครัด มันเป็นชุดข้อตกลงที่ผู้บริโภค API ส่วนใหญ่คาดหวังมากกว่า มาดูข้อที่สำคัญที่สุดกัน

**ใช้คำนามพหูพจน์สำหรับทรัพยากร** `/api/v1/users` ไม่ใช่ `/api/v1/user` ชื่อทรัพยากรแทนคอลเลกชัน และไอเทมแต่ละตัวภายในคอลเลกชันนั้นเข้าถึงด้วยไอดีของมัน

**ใช้เมธอด HTTP เพื่อแสดงการดำเนินการ** `GET` ดึงข้อมูล `POST` สร้างทรัพยากรใหม่ `PUT` แทนที่ทรัพยากรทั้งหมด `PATCH` อัปเดตบางส่วน และ `DELETE` ลบทรัพยากร นี่อาจดูเหมือนชัดเจนในตัวเอง แต่ผมเห็น API มากมายที่ใช้ `POST` กับทุกอย่าง

**ใช้รหัสสถานะที่เหมาะสม** พูดตรงๆ นี่คือหนึ่งในสิ่งที่ให้ประโยชน์สูงสุดต่อการใช้งาน API เมื่อไคลเอนต์สร้างทรัพยากร คืน `201 Created` ไม่ใช่ `200 OK` เมื่อการลบสำเร็จ คืน `204 No Content` เมื่อไคลเอนต์ส่งอินพุตที่ไม่ถูกต้อง คืน `400 Bad Request` พร้อมรายละเอียดว่าผิดอะไร เมื่อทรัพยากรที่ขอไม่มีอยู่ คืน `404 Not Found`

นี่คือรหัสสถานะที่คุณจะหยิบใช้บ่อยที่สุด:

| รหัส | ความหมาย | เมื่อใดควรใช้ |
|------|---------|------------|
| 200 | OK | การอ่านหรืออัปเดตที่สำเร็จ |
| 201 | Created | ทรัพยากรใหม่ถูกสร้างขึ้น |
| 204 | No Content | การดำเนินการสำเร็จโดยไม่มีบอดี้ในการตอบกลับ (การลบ) |
| 400 | Bad Request | อินพุตไม่ถูกต้องหรือการตรวจสอบความถูกต้องล้มเหลว |
| 401 | Unauthorized | การยืนยันตัวตนขาดหายหรือไม่ถูกต้อง |
| 403 | Forbidden | ยืนยันตัวตนแล้วแต่ไม่ได้รับอนุญาต |
| 404 | Not Found | ทรัพยากรไม่มีอยู่ |
| 409 | Conflict | ละเมิดกฎทางธุรกิจ (อีเมลซ้ำ ฯลฯ) |
| 422 | Unprocessable Entity | คำขอไม่ถูกต้องในเชิงความหมาย |
| 500 | Internal Server Error | เซิร์ฟเวอร์ล้มเหลวโดยไม่คาดคิด |

## การกำหนดเวอร์ชัน API

ถ้าคุณกำลังสร้าง API สาธารณะหรือเซอร์วิสแพลตฟอร์ม ให้กำหนดเวอร์ชันตั้งแต่เริ่ม การเพิ่มเวอร์ชันทีหลังหมายถึงการเปลี่ยนแปลงที่พังความเข้ากันได้เดิมหรือวิธีแก้ที่งุ่มง่าม ในขณะที่ต้นทุนของการประทับ `/v1` บนเส้นทางของคุณตั้งแต่วันแรกแทบไม่มีเลย

สำหรับเซอร์วิสภายในที่ออกรุ่นพร้อมกันกับผู้บริโภค การกำหนดเวอร์ชันด้วยพาธสำคัญน้อยกว่า จากประสบการณ์ของผม วิวัฒนาการสกีมาอย่างมีวินัย (การเปลี่ยนแปลงแบบเพิ่มเติม ช่วงเวลาเลิกใช้งาน การทดสอบคอนแทรกต์) มักสำคัญกว่าคำนำหน้าเวอร์ชัน อย่ากำหนดเวอร์ชันเพียงเพราะคู่มือบอกให้ทำ จงกำหนดเวอร์ชันเพราะผู้บริโภคของคุณต้องการหลักประกันความเสถียรที่คุณไม่สามารถให้ได้ผ่านการประสานงานเพียงอย่างเดียว

แนวทางที่ง่ายที่สุดและใช้แพร่หลายที่สุดคือการกำหนดเวอร์ชันแบบอิงพาธ:

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

เมื่อคุณต้องการ v2 ของเอนด์พอยต์เฉพาะในที่สุด คุณก็เพิ่มมันคู่กับ v1 ได้เลยโดยไม่รบกวนผู้บริโภคเดิม:

```rust
fn api_routes() -> Router<AppState> {
    Router::new()
        .nest("/api/v1", v1_routes())
        .nest("/api/v2", v2_routes())
}
```

เรื่องหนึ่งที่ควรจำไว้: พยายามให้อิมพลีเมนเทชันแฮนด์เลอร์ของคุณถอดคัปปลิ้งจากคำนำหน้าเวอร์ชัน เพื่อที่เส้นทาง v1 และ v2 จะได้แชร์ตรรกะเซอร์วิสเดียวกันเบื้องหลังได้ ในส่วนที่พฤติกรรมไม่ได้เปลี่ยน

## รูปทรงการตอบกลับที่สม่ำเสมอ

คุณอาจสงสัยว่าทำไมเราต้องวุ่นวายห่อทุกการตอบกลับด้วยชนิดข้อมูลมาตรฐาน เหตุผลง่ายๆ: เมื่อทุกเอนด์พอยต์คืนข้อมูลในโครงสร้างที่คาดเดาได้ ไคลเอนต์สามารถเขียนตรรกะการแยกวิเคราะห์แบบทั่วไปได้ แทนที่จะจัดการพิเศษเป็นรายเอนด์พอยต์ มาลองนิยามชนิดข้อมูลห่อหุ้ม (wrapper type) สองสามตัวกัน

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

สำหรับการตอบกลับข้อผิดพลาด เราจะใช้รูปแบบที่อธิบายไว้ในบท [การจัดการข้อผิดพลาด](./error-handling.md) เพื่อที่ไคลเอนต์จะเช็กฟิลด์ `error` เพื่อตัดสินว่าคำขอสำเร็จได้เสมอ

## การแบ่งหน้า

เอนด์พอยต์ใดก็ตามที่คืนลิสต์ทรัพยากร ควรสนับสนุนการแบ่งหน้า ถ้าไม่มี คุณก็ห่างจากการหมดเวลา ข้อผิดพลาดหน่วยความจำเต็ม และผู้บริโภคที่ไม่พอใจ แค่ชุดข้อมูลใหญ่ชุดเดียว เชื่อผมเถอะ การเพิ่มการแบ่งหน้าตอนนี้ง่ายกว่าการต่อเติมทีหลัง เมื่อตาราง users ของคุณโตไปถึงหลายแสนแถว

**การแบ่งหน้าแบบอิงออฟเซ็ต (offset-based)** เป็นวิธีที่ง่ายที่สุด และทำงานได้ดีเมื่อชุดข้อมูลไม่มหาศาล และไม่มีเรกคอร์ดถูกเพิ่มหรือลบบ่อยระหว่างการแบ่งหน้า:

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

**การแบ่งหน้าแบบอิงเคอร์เซอร์ (cursor-based)** ดีกว่าสำหรับชุดข้อมูลขนาดใหญ่หรือที่เปลี่ยนแปลงบ่อย แทนที่จะใช้ออฟเซ็ต ไคลเอนต์ส่งเคอร์เซอร์ (โดยทั่วไปคือไอดีหรือเวลาสแตมป์ของไอเทมสุดท้ายที่ได้รับ) และเซิร์ฟเวอร์คืนหน้าถัดไปโดยเริ่มหลังเคอร์เซอร์นั้น วิธีนี้เลี่ยงปัญหาการ "ข้ามแถว" ซึ่งการแบ่งหน้าแบบอิงออฟเซ็ตอาจพลาดหรือซ้ำเรกคอร์ดเมื่อข้อมูลเปลี่ยนไประหว่างหน้า

ถ้าไม่อยากเขียนตรรกะเคอร์เซอร์เอง ครีต `paginator-axum` ให้การแบ่งหน้าแบบอิงเคอร์เซอร์พร้อมเมทาดาทาที่มีฟิลด์ `next_cursor` และ `prev_cursor` มันเป็นจุดเริ่มต้นที่แข็งแรง

## การกรองและการเรียงลำดับ

สำหรับเอนด์พอยต์ลิสต์ที่ต้องกรอง เรารับพารามิเตอร์ตัวกรองเป็นสตริงควิวรี ตรงไปตรงมา:

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

สิ่งที่ต้องระวัง: เลือกให้ดีว่าอนุญาตให้เรียงลำดับด้วยฟิลด์ใดบ้าง และมั่นใจว่าฟิลด์เหล่านั้นมีอินเด็กซ์ในฐานข้อมูล การปล่อยให้ผู้ใช้เรียงลำดับด้วยคอลัมน์ที่ไม่มีอินเด็กซ์เป็นสูตรของควิวรีช้าที่จะกัดคุณใน production

## เอกสารประกอบ OpenAPI

เราทุกคนเคยเจอเอกสาร API ที่แม่นยำตอนมีคนเขียนเมื่อหกเดือนก่อน แล้วค่อยๆ ล้าสมัยไปเรื่อยๆ ตั้งแต่นั้น สิ่งที่ผมพบว่าได้ผลดีกว่ามากคือการสร้างเอกสารจากโค้ดโดยตรง ครีต `utoipa` ทำแบบนี้เป๊ะ: สร้างสเปก OpenAPI จากชนิดข้อมูล Rust และแอนโนเทชันบนแฮนด์เลอร์ของคุณ เพราะเอกสารมาจากโค้ดจริง พวกมันจึงไม่มีทางเก่า

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

เพื่อเสิร์ฟ Swagger UI คู่กับ API ของเรา เราต่อสายมันแบบนี้:

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

ตอนนี้นักพัฒนาสามารถเปิดดูเอกสาร API ของเราได้ที่ `/swagger-ui` และลองส่งคำขอจากเบราว์เซอร์ได้โดยตรง สเปกถูกสร้างขึ้นตอนคอมไพล์จากชนิดข้อมูลและแฮนด์เลอร์จริง ดังนั้นมันจึงไม่มีทางหลุดออกจากอิมพลีเมนเทชันได้จริงๆ เป็นคุณสมบัติที่ดีที่มีติดตัว

## เอนด์พอยต์ health check

API production ทุกตัวต้องมีเอนด์พอยต์ health check ลองบาลานเซอร์และตัวจัดระเบียบคอนเทนเนอร์ของคุณต้องมีทางรู้ว่าเซอร์วิสของคุณยังมีชีวิตอยู่และพร้อมรับทราฟฟิกหรือไม่ มาดูวิธีตั้งค่ากัน

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

เราเมานต์เอนด์พอยต์เหล่านี้ไว้นอกเส้นทาง API ที่กำหนดเวอร์ชัน เพื่อให้มันคงที่แม้ API จะวิวัฒนาการไป:

```rust
let app = Router::new()
    .route("/health", get(health_live))
    .route("/health/ready", get(health_ready))
    .merge(api_routes())  // api_routes() already nests under /api/v1
    .with_state(state);
```

liveness probe ควรเร็วและไม่มีเงื่อนไข ทุกอย่างที่มันบอกตัวจัดระเบียบคือ "ใช่ กระบวนการยังมีชีวิตอยู่" ส่วน readiness probe คือตัวที่เช็กว่าดีเพนเดนซีของเรา (ฐานข้อมูล แคช อะไรก็ตาม) สบายดีหรือไม่ เพื่อให้ตัวจัดระเบียบรู้ว่าปลอดภัยที่จะส่งทราฟฟิกมาที่อินสแตนซ์นี้ การสับสนสองตัวนี้เป็นความผิดพลาดที่พบบ่อย และมันทำให้ตัวจัดระเบียบของคุณรีสตาร์ตคอนเทนเนอร์ที่แข็งแรงดี เพียงเพราะฐานข้อมูลสะดุดไปชั่วครู่

เมื่อออกแบบ API ด้วยวิธีนี้ เรามีรากฐานที่แข็งแรง: URL ที่สม่ำเสมอ รูปทรงการตอบกลับที่คาดเดาได้ การแบ่งหน้าที่ไม่พังเมื่อสเกล เอกสารที่แม่นยำอยู่เสมอ และ health check ที่คอยรายงานสถานะให้อินฟราสตรักเจอร์ของเรารู้ ต่อไป มาดูวิธีจัดการข้อผิดพลาดที่ต้องเกิดขึ้นแน่ๆ เมื่อทุกอย่างนี้รันอยู่ใน production
