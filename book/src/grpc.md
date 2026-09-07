# gRPC ด้วย Tonic

ถ้าคุณกำลังสร้างเซอร์วิส Axum ตามแพตเทิร์นในบทก่อนๆ ณ จุดใดจุดหนึ่งคุณจะเจอคำถามที่คุ้นเคย นั่นคือเราจะคุยกับเซอร์วิสภายในตัวอื่นๆ อย่างไร? API แบบ HTTP/JSON นั้นยอดเยี่ยมสำหรับไคลเอนต์บนเบราว์เซอร์และผู้บริโภคจากบุคคลที่สาม แต่สำหรับการสื่อสารระหว่างเซอร์วิสกับเซอร์วิส คุณมักต้องการบางอย่างที่มีการรับประกันสกีมาที่แข็งแกร่งกว่า มีการสตรีมในตัว และมีการสร้างโค้ดอัตโนมัติ นั่นคือที่มาของ gRPC Tonic คือเฟรมเวิร์ก gRPC ที่เป็นตัวเลือกหลักในนิเวศ Rust และเนื่องจากมันสร้างบน Tokio เช่นเดียวกับ Axum ทั้งสองจึงทำงานร่วมกันได้อย่างลงตัว

ในบทนี้ เราจะเดินผ่านการเพิ่มพื้นผิว gRPC ให้กับเซอร์วิส Rust ที่มีอยู่ของเรา รันมันควบคู่ไปกับเซิร์ฟเวอร์ HTTP Axum ของเรา และนำหลักการทางสถาปัตยกรรมแบบเดียวกับที่เราใช้มาตลอด (แฮนด์เลอร์บาง, การแยกโดเมน, การจัดการข้อผิดพลาดแบบรวมศูนย์) ไปใช้กับฝั่ง gRPC

## เมื่อไหร่ควรใช้ gRPC

gRPC เหมาะสมอย่างเป็นธรรมชาติเมื่อผู้บริโภคของคุณคือเซอร์วิสอื่นที่คุณควบคุมได้ ทั้งสองฝ่ายได้ประโยชน์จากสกีมาร่วมที่กำหนดในไฟล์ `.proto` ฟอร์แมต wire ของ protobuf กระชับกว่า JSON และคุณได้ความปลอดภัยด้านชนิดข้อมูลข้ามขอบเขตภาษาแบบฟรีๆ RPC แบบสตรีม (server-streaming, client-streaming, แบบสองทิศทาง) เป็นแนวคิดระดับเฟิร์สคลาส ไม่ใช่สิ่งที่คุณต้องต่อเติมภายหลัง

จุดที่ gRPC เหมาะน้อยกว่าคือไคลเอนต์บนเบราว์เซอร์ (แม้ gRPC-Web จะช่วยถมช่องว่างนั้น), API สาธารณะที่ความสามารถในการทดสอบด้วย curl มีความสำคัญ, หรือเซอร์วิส CRUD ธรรมดาๆ ที่กลไกของ protobuf เพิ่มค่าใช้จ่ายมากกว่าคุณค่าที่ได้รับ

จากประสบการณ์ของผม ระบบ production ส่วนใหญ่ลงเอยด้วยการใช้ทั้งสองอย่าง: gRPC สำหรับการสื่อสารภายในระหว่างเซอร์วิส และ HTTP/JSON สำหรับ API ที่เปิดสู่สาธารณะ นั่นคือสถานการณ์ที่เราจะจัดการในบทนี้พอดี

## การจัดระเบียบไฟล์ Proto

นิยามของ Protocol buffer อยู่ในไฟล์ `.proto` โดยปกติจะอยู่ในไดเรกทอรี `proto/` ที่รากของโปรเจกต์หรือเวิร์กสเปซของคุณ:

```
my-service/
├── proto/
│   └── myservice/
│       └── v1/
│           ├── users.proto
│           └── health.proto
├── build.rs
├── Cargo.toml
└── src/
    └── ...
```

คุณอาจสงสัยว่าทำไมเราถึงกำหนดเวอร์ชันให้แพ็กเกจ proto (เช่น `myservice.v1`) ตั้งแต่เริ่ม อันที่จริงมันสำคัญที่นี่ยิ่งกว่าใน REST เพราะสกีมา proto ถูกคอมไพล์เป็นโค้ดฝั่งไคลเอนต์ เมื่อผู้บริโภคพึ่งพาไทป์ที่ถูกสร้างขึ้นเหล่านั้นแล้ว การเปลี่ยนสกีมาคือการเปลี่ยนแปลงที่ทำลาย (breaking change) สำหรับทุกคนเลย การกำหนดเวอร์ชันตั้งแต่เริ่มช่วยให้คุณรอดพ้นจากไมเกรชันที่เจ็บปวดในภายหลัง

ไฟล์ proto ทั่วไปหน้าตาแบบนี้:

```protobuf
syntax = "proto3";

package myservice.v1;

service UserService {
    rpc GetUser (GetUserRequest) returns (GetUserResponse);
    rpc CreateUser (CreateUserRequest) returns (CreateUserResponse);
    rpc ListUsers (ListUsersRequest) returns (stream UserResponse);
}

message GetUserRequest {
    string id = 1;
}

message GetUserResponse {
    string id = 1;
    string name = 2;
    string email = 3;
}

// ... other messages
```

## การสร้างโค้ดตอนบิลด์

Tonic ใช้สคริปต์บิลด์เพื่อคอมไพล์ไฟล์ `.proto` เป็นโค้ด Rust ในตอนบิลด์ มาลองเพิ่มดีเพนเดนซีลงใน `Cargo.toml` ของเรากัน:

```toml
[dependencies]
tonic = "0.14"
tonic-prost = "0.14"
prost = "0.14"

[build-dependencies]
tonic-prost-build = "0.14"
```

สิ่งหนึ่งที่อาจทำให้คุณสะดุด: ตั้งแต่ tonic 0.14 เป็นต้นไป การสร้างโค้ด protobuf ใช้ `tonic-prost-build` ไม่ใช่ `tonic-build` ตรงๆ ครีต `tonic-build` ยังคงมีอยู่จริงในฐานะโครงสร้างพื้นฐานของ codegen แต่ว่าตัวที่คุณต้องพึ่งพาจริงๆ สำหรับการคอมไพล์ protobuf คือ `tonic-prost-build` คุณจะต้องมี `tonic-prost` เป็นดีเพนเดนซีรันไทม์ควบคู่กับ `tonic` เองด้วย

ตอนนี้มาสร้าง `build.rs` ของเรากัน:

```rust
fn main() -> Result<(), Box<dyn std::error::Error>> {
    tonic_prost_build::configure()
        .build_server(true)
        .build_client(true)
        .compile_protos(
            &["proto/myservice/v1/users.proto"],
            &["proto/"],
        )?;
    Ok(())
}
```

โค้ดที่ถูกสร้างจะไปอยู่ในไดเรกทอรี `target/` ของคุณ และคุณดึงมันเข้ามาด้วย `tonic::include_proto!("myservice.v1")` ถ้าคุณต้องการให้ไทป์ที่ถูกสร้างทำงานร่วมกับไทป์โดเมนของคุณได้อย่างลงตัว คุณสามารถตั้งค่า `tonic_build` ให้เพิ่ม derive แบบกำหนดเอง (เช่น `Eq`, `Hash`, หรือ `serde::Serialize`) ได้

## การนำเซอร์วิส gRPC ไปใช้

โค้ดที่ถูกสร้างให้เทรตแก่คุณสำหรับการนำไปใช้กับเซอร์วิสของคุณ แต่ละเมธอด RPC กลายเป็นเมธอดของเทรตที่รับ `Request<T>` และคืนค่า `Result<Response<U>, Status>` ถ้าคุณเคยเขียนแฮนด์เลอร์ Axum มาก่อน สิ่งนี้จะรู้สึกคุ้นเคยมาก

```rust
use tonic::{Request, Response, Status};

// Include the generated code.
pub mod pb {
    tonic::include_proto!("myservice.v1");
}

use pb::user_service_server::{UserService, UserServiceServer};

pub struct MyUserService {
    // Same domain services and repositories you use in Axum handlers.
    inner: domain::services::UserService<PostgresUserRepo>,
}

impl UserService for MyUserService {
    async fn get_user(
        &self,
        request: Request<pb::GetUserRequest>,
    ) -> Result<Response<pb::GetUserResponse>, Status> {
        let req = request.into_inner();
        let id = Uuid::parse_str(&req.id)
            .map_err(|_| Status::invalid_argument("invalid user ID"))?;

        let user = self.inner
            .get_by_id(&UserId::from_uuid(id))
            .await
            .map_err(|e| {
                tracing::error!(error = ?e, "failed to fetch user");
                Status::internal("internal error")
            })?
            .ok_or_else(|| Status::not_found("user not found"))?;

        Ok(Response::new(pb::GetUserResponse {
            id: user.id().as_uuid().to_string(),
            name: user.name().as_str().to_string(),
            email: user.email().as_str().to_string(),
        }))
    }

    // ... other methods
}
```

สังเกตว่าสิ่งนี้เป็นไปตามแพตเทิร์นเดียวกับแฮนด์เลอร์ Axum ของเราทุกประการ: ดึงอินพุตออกมา เรียกเซอร์วิสโดเมน แล้วแปลงผลลัพธ์ให้เป็นฟอร์แมตการส่งผ่าน ความแตกต่างมีเล็กน้อย ข้อผิดพลาดถูกแปลงเป็นรหัส `tonic::Status` แทนที่จะเป็นรหัสสถานะ HTTP และไทป์คำขอ/การตอบกลับมาจาก protobuf แทนที่จะเป็นการดีซีเรียลไลซ์ JSON แต่รูปทรงของโค้ดเหมือนกัน ซึ่งนั่นคือประเด็นทั้งหมดของสถาปัตยกรรมแบบเลเยอร์ของเรา

## การจัดการข้อผิดพลาดใน gRPC

`tonic::Status` คือสิ่งที่เทียบเท่ากับรหัสสถานะ HTTP ในโลก gRPC แต่ยังพกข้อความข้อผิดพลาดไปด้วย รหัสมาตรฐานประกอบด้วย `NotFound`, `InvalidArgument`, `PermissionDenied`, `Internal`, `Unavailable`, และอื่นๆ ที่แปลงไปมาระหว่างความหมาย HTTP ได้ค่อนข้างตรงๆ

ถ้าคุณมี enum `AppError` อยู่แล้วสำหรับแฮนด์เลอร์ Axum ของคุณ (ตามที่อธิบายไว้ในบท [การจัดการข้อผิดพลาด](./error-handling.md)) คุณสามารถเขียนการแปลงจาก `AppError` เป็น `Status` และใช้ประโยชน์จากงานทั้งหมดนั้นซ้ำได้:

```rust
impl From<AppError> for Status {
    fn from(err: AppError) -> Self {
        match err {
            AppError::NotFound => Status::not_found("resource not found"),
            AppError::Validation(msg) => Status::invalid_argument(msg),
            AppError::Unauthorized => Status::unauthenticated("authentication required"),
            AppError::Forbidden => Status::permission_denied("insufficient permissions"),
            AppError::Conflict(msg) => Status::already_exists(msg),
            AppError::Internal(e) => {
                tracing::error!(error = ?e, "internal error in gRPC handler");
                Status::internal("internal error")
            }
            _ => Status::internal("internal error"),
        }
    }
}
```

เมื่อมีสิ่งนี้แล้ว แฮนด์เลอร์ gRPC ของคุณก็สามารถใช้แพตเทิร์นการส่งต่อด้วย `?` แบบเดียวกับแฮนด์เลอร์ Axum ของคุณได้ ข้อผิดพลาดจากโดเมนจะถูกแปลงเป็นรหัสสถานะ gRPC ที่ถูกต้องโดยอัตโนมัติ และคุณไม่ต้องเขียนตรรกะการแปลงซ้ำไปทั่ว

## การรัน gRPC ควบคู่กับ Axum

มีสองวิธีที่พบได้ทั่วไปสำหรับการรันทั้ง HTTP และ gRPC ในโพรเซสเดียวกัน มาดูกันทีละแบบ

**พอร์ตแยกกัน** เป็นตัวเลือกที่ง่ายกว่า และเป็นสิ่งที่ผมแนะนำให้เริ่มต้นด้วย เซิร์ฟเวอร์ Axum ของเรา bind กับพอร์ต 3000 เซิร์ฟเวอร์ Tonic ของเรา bind กับพอร์ต 50051 แต่ละตัวรันใน `tokio::spawn` ของตัวเอง และใช้ `AppState`, พูลฐานข้อมูล, และเซอร์วิสโดเมนร่วมกัน

```rust
// Spawn the HTTP server.
let http_handle = tokio::spawn(async move {
    let listener = TcpListener::bind("0.0.0.0:3000").await.unwrap();
    axum::serve(listener, http_router)
        .with_graceful_shutdown(http_token.cancelled_owned())
        .await
        .unwrap();
});

// Spawn the gRPC server.
let grpc_handle = tokio::spawn(async move {
    tonic::transport::Server::builder()
        .add_service(UserServiceServer::new(grpc_user_service))
        .serve_with_shutdown(
            "0.0.0.0:50051".parse().unwrap(),
            grpc_token.cancelled_owned(),
        )
        .await
        .unwrap();
});
```

**พอร์ตเดียวกันพร้อมการตรวจจับโปรโตคอล** ซับซ้อนกว่าแต่ลดพื้นผิวการปฏิบัติงานของคุณ `Server` ของ Tonic สามารถประกอบเข้ากับเราเตอร์ Axum ได้ เพื่อให้คำขอ gRPC แบบ HTTP/2 และคำขอ REST แบบ HTTP/1.1 ถูกจัดการโดย listener ตัวเดียวกัน อย่างไรก็ตามสิ่งนี้ต้องใช้การตั้งค่าที่ระมัดระวัง และจากประสบการณ์ของผม มันมักจะคุ้มค่าเฉพาะเมื่อคุณมีเหตุผลหนักแน่นที่จะเลี่ยงการใช้หลายพอร์ต เช่น นโยบายเครือข่ายที่เข้มงวด

สำหรับแอปพลิเคชันส่วนใหญ่ ให้ใช้พอร์ตแยกกัน มันง่ายกว่า เฝ้าติดตามแยกกันได้ง่ายกว่า และคุณจะไม่เจอเคสขอบของโปรโตคอลดีเทกชัน

## มิดเดิลแวร์และอินเทอร์เซปเตอร์

Tonic รองรับอินเทอร์เซปเตอร์ ซึ่งเทียบเท่ากับมิดเดิลแวร์ในโลก gRPC คุณสามารถเพิ่มการยืนยันตัวตน การบันทึกข้อมูล และความกังวลข้ามฝั่ง (cross-cutting concerns) อื่นๆ ได้เหมือนกับที่คุณทำใน Axum:

```rust
use tonic::service::interceptor;

fn auth_interceptor(req: Request<()>) -> Result<Request<()>, Status> {
    let token = req.metadata()
        .get("authorization")
        .and_then(|v| v.to_str().ok())
        .and_then(|v| v.strip_prefix("Bearer "))
        .ok_or_else(|| Status::unauthenticated("missing token"))?;

    // Validate token...

    Ok(req)
}

// Apply the interceptor to a service.
let user_service = UserServiceServer::with_interceptor(
    MyUserService::new(state),
    auth_interceptor,
);
```

สำหรับมิดเดิลแวร์ที่ซับซ้อนกว่า (tracing, เมตริก, การหมดเวลา) Tonic ผสานกับเลเยอร์ของ Tower เช่นเดียวกับ Axum คุณสามารถใช้ `TraceLayer`, `TimeoutLayer`, และมิดเดิลแวร์ Tower อื่นๆ แบบเดียวกันกับเซิร์ฟเวอร์ gRPC ของคุณได้ ซึ่งหมายความว่าทักษะที่คุณสั่งสมมาจากบทก่อนๆ นำมาปรับใช้ได้โดยตรง

## gRPC reflection

การเพิ่ม server reflection ทำให้ไคลเอนต์อย่าง `grpcurl` และ `grpc-ui` ค้นพบ API ของเซอร์วิสของคุณได้โดยไม่ต้องมีไฟล์ proto อยู่บนเครื่อง มองมันเป็นสิ่งที่เทียบเท่ากับ Swagger UI ในโลก gRPC มันมีประโยชน์อย่างเหลือเชื่อในช่วงพัฒนา ดังนั้นผมแนะนำให้ตั้งค่ามันตั้งแต่เนิ่นๆ

```rust
use tonic_reflection::server::Builder;

let reflection_service = Builder::configure()
    .register_encoded_file_descriptor_set(pb::FILE_DESCRIPTOR_SET)
    .build_v1()?;

tonic::transport::Server::builder()
    .add_service(reflection_service)
    .add_service(UserServiceServer::new(user_service))
    .serve(addr)
    .await?;
```

เพื่อสร้างชุดไฟล์ descriptor ให้เพิ่มสิ่งนี้ลงใน `build.rs` ของคุณ:

```rust
tonic_prost_build::configure()
    .file_descriptor_set_path(
        std::path::PathBuf::from(std::env::var("OUT_DIR").unwrap())
            .join("myservice_descriptor.bin")
    )
    .compile_protos(&["proto/myservice/v1/users.proto"], &["proto/"])?;
```

## การทดสอบเซอร์วิส gRPC

คุณสามารถทดสอบเซอร์วิส gRPC ได้ด้วยการรันเซิร์ฟเวอร์จริงในเทสต์แล้วเชื่อมต่อกับมันด้วยไคลเอนต์ที่ถูกสร้าง:

```rust
#[tokio::test]
async fn test_get_user() {
    let addr = start_test_grpc_server().await;
    let mut client = UserServiceClient::connect(
        format!("http://{}", addr)
    ).await.unwrap();

    let response = client
        .get_user(pb::GetUserRequest {
            id: "some-uuid".to_string(),
        })
        .await
        .unwrap();

    assert_eq!(response.into_inner().name, "Alice");
}
```

ถ้าค่าใช้จ่ายด้านเครือข่ายรบกวนคุณสำหรับการทดสอบหน่วยที่ต้องเร็ว คุณยังใช้ `tonic::transport::Channel` กับ transport ภายในโพรเซสได้ มันคล้ายกับแพตเทิร์นการทดสอบ `oneshot` ของ Axum และมันทำให้เทสต์ของคุณเร็วโดยไม่เสียความครอบคลุม
