# gRPC ด้วย Tonic

หากคุณกำลังสร้างเซอร์วิส Axum ตามแบบแผนในบทก่อนๆ มาเรื่อยๆ เมื่อถึงจุดหนึ่งคุณจะต้องพบกับคำถามที่คุ้นเคย: เราจะสื่อสารกับเซอร์วิสภายในตัวอื่นๆ อย่างไร? การสร้าง API แบบ HTTP/JSON นั้นยอดเยี่ยมมากสำหรับไคลเอนต์บนเว็บเบราว์เซอร์และผู้ใช้งานภายนอก แต่สำหรับการสื่อสารกันเองระหว่างเซอร์วิสภายใน (service-to-service communication) คุณมักจะต้องการอะไรบางอย่างที่มีการรับประกันโครงสร้างข้อมูล (schema guarantees) ที่รัดกุมกว่า, มีระบบสตรีมมิงในตัว, และสร้างโค้ดให้โดยอัตโนมัติ นั่นคือจุดที่ gRPC เข้ามาตอบโจทย์ ซึ่ง Tonic คือเฟรมเวิร์ก gRPC ที่เป็นตัวเลือกอันดับหนึ่งในระบบนิเวศของ Rust และเนื่องจากมันถูกพัฒนาขึ้นบน Tokio เช่นเดียวกับ Axum ทั้งสองตัวจึงทำงานประสานกันได้อย่างลงตัวไร้รอยต่อ

ในบทนี้ เราจะมาดูขั้นตอนการเพิ่มช่องทาง gRPC ให้กับเซอร์วิส Rust ที่มีอยู่เดิม รันมันควบคู่ไปกับเซิร์ฟเวอร์ HTTP Axum และนำหลักการทางสถาปัตยกรรมชุดเดิมที่เราใช้มาตลอด (แฮนด์เลอร์ขนาดเล็กเบาบาง, การแยกเลเยอร์โดเมนอย่างชัดเจน, การจัดการข้อผิดพลาดแบบรวมศูนย์) มาประยุกต์ใช้กับฝั่ง gRPC อย่างเป็นระบบ

## เมื่อไหร่ควรใช้ gRPC

gRPC ตอบโจทย์ได้อย่างเป็นธรรมชาติเมื่อผู้เรียกใช้งาน (consumer) คือเซอร์วิสตัวอื่นๆ ภายใต้การควบคุมของคุณเอง ทั้งสองฝั่งจะได้รับประโยชน์จากสกีมาส่วนกลางที่กำหนดไว้ในไฟล์ `.proto`, รูปแบบ wire format ของ Protocol Buffers (protobuf) นั้นกะทัดรัดและประหยัดแบนด์วิธกว่า JSON มาก, และคุณยังได้ความปลอดภัยเรื่องชนิดข้อมูล (type safety) ข้ามภาษาไปใช้งานได้ฟรีๆ อีกด้วย ยิ่งไปกว่านั้น RPC แบบสตรีม (ไม่ว่าจะเป็น server-streaming, client-streaming, หรือแบบสองทิศทาง bidirectional) ยังถือเป็นแนวคิดระดับ first-class ที่รองรับมาตั้งแต่ต้น ไม่ใช่สิ่งที่ต้องมาดัดแปลงเสริมแต่งในภายหลัง

ทว่าจุดที่ gRPC อาจไม่ค่อยเหมาะนัก ได้แก่ ไคลเอนต์ที่รันบนเว็บบราวเซอร์โดยตรง (แม้จะมี gRPC-Web เข้ามาช่วยปิดช่องว่างนี้ก็ตาม), พับลิก API ที่จำเป็นต้องเปิดให้ทดสอบยิงได้ง่ายๆ ด้วยคำสั่ง `curl`, หรือเซอร์วิสประเภท CRUD พื้นฐานทั่วไปที่ขั้นตอนและกลไกของ protobuf อาจกลายเป็นภาระมากกว่าความคุ้มค่า

จากประสบการณ์จริง ระบบในระดับ production ส่วนใหญ่มักจบลงด้วยการใช้งานร่วมกันทั้งสองรูปแบบ: ใช้ gRPC สำหรับการสื่อสารกันเองระหว่างเซอร์วิสภายใน และเปิด API แบบ HTTP/JSON สำหรับฝั่งภายนอกหรือผู้ใช้ทั่วไป ซึ่งนี่ก็คือสถานการณ์จริงที่เราจะมาจัดการกันในบทนี้นั่นเอง

## การจัดระเบียบไฟล์ Proto

นิยามของ Protocol buffer จะถูกเขียนไว้ในไฟล์ `.proto` ซึ่งโดยทั่วไปมักจัดวางไว้ในไดเรกทอรี `proto/` ณ ระดับรากของโปรเจกต์หรือเวิร์กสเปซของคุณ:

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

คุณอาจสงสัยว่าทำไมเราจึงควรกำหนดเวอร์ชันให้กับแพ็กเกจ proto (เช่น `myservice.v1`) ตั้งแต่แรกเริ่ม อันที่จริงแล้ว เรื่องนี้มีความสำคัญยิ่งกว่าการทำ REST เสียอีก เพราะสกีมา proto จะถูกนำไปคอมไพล์เป็นโค้ดในฝั่งของไคลเอนต์ เมื่อผู้บริโภคนำไทป์ที่เจนออกมาเหล่านั้นไปใช้งานแล้ว การแก้ไขสกีมาอาจกลายเป็นการเปลี่ยนแปลงที่กระทบโค้ดเดิมอย่างรุนแรง (breaking change) สำหรับทุกคนได้ทันที การวางโครงสร้างระบุเวอร์ชันไว้ตั้งแต่ต้นจึงช่วยปกป้องคุณจากการต้องมาทำไมเกรชันที่ยุ่งยากซับซ้อนในภายหลัง

ตัวอย่างไฟล์ proto ทั่วไปจะมีโครงสร้างดังนี้:

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

Tonic จะอาศัยสคริปต์การบิลด์ (`build.rs`) เพื่อคอมไพล์ไฟล์ `.proto` ออกมาเป็นโค้ด Rust ในระหว่างกระบวนการบิลด์โปรเจกต์ เรามาลองเพิ่มดีเพนเดนซีที่จำเป็นลงใน `Cargo.toml` กันก่อน:

```toml
[dependencies]
tonic = "0.14"
tonic-prost = "0.14"
prost = "0.14"

[build-dependencies]
tonic-prost-build = "0.14"
```

จุดหนึ่งที่อาจทำให้คุณสับสนได้คือ: ตั้งแต่เวอร์ชัน Tonic 0.14 เป็นต้นมา การสร้างโค้ดจาก protobuf จะเปลี่ยนมาใช้ `tonic-prost-build` แทนการใช้ `tonic-build` โดยตรง แม้ crate `tonic-build` จะยังคงมีอยู่เพื่อทำหน้าที่เป็นโครงสร้างพื้นฐานสำหรับ codegen แต่ตัวที่คุณจำเป็นต้องเรียกใช้สำหรับการคอมไพล์ protobuf จริงๆ คือ `tonic-prost-build` และคุณยังจำเป็นต้องใส่ `tonic-prost` เป็นดีเพนเดนซีสำหรับตอนรันไทม์ควบคู่ไปกับ `tonic` อีกด้วย

คราวนี้ มาเขียนสคริปต์ใน `build.rs` กัน:

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

โค้ดที่ถูกสร้างขึ้นจะถูกจัดเก็บไว้ในไดเรกทอรี `target/` ของคุณ และคุณสามารถนำโค้ดดังกล่าวเข้ามาใช้งานในโปรเจกต์ได้ด้วยมาโคร `tonic::include_proto!("myservice.v1")` นอกจากนี้ หากคุณต้องการให้ไทป์ที่ถูกเจนขึ้นมาสามารถผสานการทำงานกับไทป์ในโดเมนได้อย่างราบรื่น คุณยังสามารถตั้งค่าคอนฟิกให้เพิ่ม derive แบบกำหนดเอง (เช่น `Eq`, `Hash`, หรือ `serde::Serialize`) เข้าไปได้อีกด้วย

## การนำเซอร์วิส gRPC ไปใช้

โค้ดที่ถูกเจนขึ้นมาจะเตรียมเทรต (trait) สำหรับนำไปอิมพลีเมนต์เป็นเซอร์วิสของคุณ โดยแต่ละเมธอดของ RPC จะกลายสภาพเป็นเมธอดบนเทรตที่รับค่า `Request<T>` และส่งคืนผลลัพธ์กลับมาเป็น `Result<Response<U>, Status>` ซึ่งหากคุณเคยเขียนแฮนด์เลอร์ใน Axum มาก่อน โครงสร้างนี้จะให้ความรู้สึกที่คุ้นเคยเป็นอย่างยิ่ง

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

สังเกตได้ว่ารูปแบบนี้ถอดแบบมาจากแพตเทิร์นเดียวกับแฮนด์เลอร์ของ Axum แบบเป๊ะๆ: ดึงข้อมูลอินพุตออกมา, เรียกใช้เซอร์วิสของโดเมน, แล้วแปลงผลลัพธ์ให้อยู่ในฟอร์แมตสำหรับส่งผ่านเครือข่าย ความแตกต่างมีเพียงเล็กน้อยเท่านั้น คือข้อผิดพลาดจะถูกแปลงไปเป็นรหัสสถานะ `tonic::Status` แทนที่จะเป็น HTTP status code และไทป์ของคำขอ/การตอบกลับจะมาจาก protobuf แทนการทำ JSON deserialization แต่รูปทรง (shape) ของโครงสร้างโค้ดยังคงเหมือนเดิมทุกประการ ซึ่งนี่คือหัวใจและเป้าหมายทั้งหมดของการออกแบบสถาปัตยกรรมแบบแบ่งเลเยอร์ของเรา

## การจัดการข้อผิดพลาดใน gRPC

`tonic::Status` คือสิ่งที่เทียบเท่ากับรหัสสถานะ HTTP ในโลกของ gRPC แต่จะพ่วงข้อความแจ้งข้อผิดพลาดแนบติดไปด้วย รหัสมาตรฐานจะประกอบไปด้วย `NotFound`, `InvalidArgument`, `PermissionDenied`, `Internal`, `Unavailable` และอื่นๆ ซึ่งสามารถจับคู่ความหมายเข้ากับรหัส HTTP ได้อย่างตรงไปตรงมา

หากคุณมี enum `AppError` สำหรับแฮนด์เลอร์ Axum อยู่แล้ว (ตามที่อธิบายไว้ในบท [การจัดการข้อผิดพลาด](./error-handling.md)) คุณสามารถเขียนตัวแปลงชนิดข้อมูลจาก `AppError` ไปเป็น `Status` เพื่อนำสิ่งที่มีอยู่แล้วกลับมาใช้ซ้ำได้อย่างคุ้มค่า:

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

เมื่อมีตัวแปลงนี้แล้ว แฮนด์เลอร์ gRPC ของคุณก็สามารถใช้โอเปอเรเตอร์ `?` ในการส่งต่อข้อผิดพลาดได้แบบเดียวกับแฮนด์เลอร์ของ Axum ข้อผิดพลาดจากฝั่งโดเมนจะถูกแปลงเป็นรหัสสถานะ gRPC ที่ถูกต้องโดยอัตโนมัติ ทำให้คุณไม่ต้องมาคอยเขียนตรรกะการแปลง error ซ้ำๆ กระจายอยู่ทั่วทั้งโปรเจกต์

## การรัน gRPC ควบคู่กับ Axum

โดยทั่วไปมีสองแนวทางหลักในการรันทั้ง HTTP และ gRPC ร่วมกันภายในโพรเซสเดียวกัน เรามาดูข้อดีข้อเสียของแต่ละแบบกัน:

**แยกคนละพอร์ต (Separate ports)** เป็นตัวเลือกที่เรียบง่ายกว่า และเป็นแนวทางที่ผมแนะนำให้เริ่มต้นใช้งาน โดยให้เซิร์ฟเวอร์ Axum ของเรา bind เข้ากับพอร์ต 3000 และเซิร์ฟเวอร์ Tonic bind เข้ากับพอร์ต 50051 ทั้งสองตัวจะรันแยกกันใน `tokio::spawn` ของตนเอง พร้อมทั้งแชร์ `AppState`, พูลฐานข้อมูล, และเซอร์วิสโดเมนร่วมกันอย่างเป็นอิสระ

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

**ใช้พอร์ตเดียวกันพร้อมการตรวจจับโปรโตคอล (Same port with protocol detection)** วิธีนี้จะมีความซับซ้อนมากกว่า แต่ช่วยลดภาระด้านการจัดการพอร์ตลงได้ โดย `Server` ของ Tonic สามารถประกอบเข้ากับเราเตอร์ของ Axum เพื่อให้คำขอ gRPC ที่วิ่งผ่าน HTTP/2 และคำขอ REST ที่วิ่งผ่าน HTTP/1.1 ได้รับการจัดการผ่าน listener บนพอร์ตเดียวกัน อย่างไรก็ตาม วิธีนี้ต้องอาศัยการตั้งค่าที่รัดกุมรอบคอบ และจากประสบการณ์ตรง มันมักจะคุ้มค่าเฉพาะเมื่อคุณมีเหตุผลจำเป็นจริงๆ เช่น ต้องปฏิบัติตามนโยบายด้านเน็ตเวิร์กที่เข้มงวด

สำหรับแอปพลิเคชันส่วนใหญ่ การเลือกใช้พอร์ตแยกกันถือเป็นทางเลือกที่ดีกว่ามาก เพราะเรียบง่ายกว่า, แยกมอนิเตอร์และตรวจสอบได้สะดวกกว่า, และไม่เสี่ยงที่จะเจอกับปัญหา edge case ในขั้นตอนการตรวจจับโปรโตคอล

## มิดเดิลแวร์และอินเทอร์เซปเตอร์

Tonic รองรับอินเทอร์เซปเตอร์ (interceptor) ซึ่งทำหน้าที่เทียบเท่ากับมิดเดิลแวร์ในโลกของ gRPC โดยคุณสามารถแทรกระบบยืนยันตัวตน, การบันทึกล็อก, และการจัดการเรื่องส่วนกลางอื่นๆ (cross-cutting concerns) ได้เช่นเดียวกับที่ทำใน Axum:

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

สำหรับมิดเดิลแวร์ที่มีความซับซ้อนมากขึ้น (เช่น tracing, metrics, timeout) Tonic สามารถต่อเข้ากับเลเยอร์ของ Tower ได้เช่นเดียวกับ Axum คุณจึงสามารถนำ `TraceLayer`, `TimeoutLayer`, และมิดเดิลแวร์ตัวอื่นๆ ของ Tower มาใช้งานร่วมกับเซิร์ฟเวอร์ gRPC ของคุณได้ทันที ทำให้องค์ความรู้และทักษะที่คุณได้ฝึกฝนมาจากบทก่อนๆ สามารถนำมาต่อยอดใช้งานได้โดยตรง

## gRPC reflection

การเปิดใช้งาน server reflection จะช่วยให้เครื่องมือฝั่งไคลเอนต์ เช่น `grpcurl` และ `grpc-ui` สามารถตรวจสอบและค้นพบ API ของเซอร์วิสคุณได้โดยอัตโนมัติโดยไม่จำเป็นต้องมีไฟล์ `.proto` อยู่ในเครื่องปลายทาง ให้มองว่ามันคือสิ่งที่เทียบเท่ากับ Swagger UI ในโลกของ gRPC ฟีเจอร์นี้มีประโยชน์อย่างมหาศาลในระหว่างขั้นตอนการพัฒนา ดังนั้นผมจึงแนะนำให้ตั้งค่าเปิดใช้งานไว้ตั้งแต่เนิ่นๆ

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

สำหรับการสร้างชุดไฟล์ descriptor ให้เพิ่มคำสั่งต่อไปนี้ลงในไฟล์ `build.rs` ของคุณ:

```rust
tonic_prost_build::configure()
    .file_descriptor_set_path(
        std::path::PathBuf::from(std::env::var("OUT_DIR").unwrap())
            .join("myservice_descriptor.bin")
    )
    .compile_protos(&["proto/myservice/v1/users.proto"], &["proto/"])?;
```

## การทดสอบเซอร์วิส gRPC

คุณสามารถทดสอบเซอร์วิส gRPC ได้อย่างสมจริง โดยการเปิดเซิร์ฟเวอร์ขึ้นมาจริงๆ ภายในเทสต์ แล้วเชื่อมต่อเข้าไปด้วยไคลเอนต์ที่ถูกเจนขึ้นมา:

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

หากคุณกังวลเรื่อง overhead ของการเชื่อมต่อเครือข่ายสำหรับการทำยูนิตเทสต์ที่ต้องการความรวดเร็วสูง คุณยังสามารถเลือกใช้ `tonic::transport::Channel` ร่วมกับ in-process transport ได้อีกด้วย ซึ่งมีแนวคิดคล้ายคลึงกับแพตเทิร์นการทดสอบแบบ `oneshot` ของ Axum ช่วยให้เทสต์ของคุณทำงานได้อย่างรวดเร็วเป็นพิเศษโดยไม่สูญเสียความครอบคลุมในการทดสอบเลย
