# การดีพลอยต์ (Deployment)

เมื่อเราพัฒนาเว็บเซอร์วิสเสร็จแล้ว ทดสอบจนผ่านฉลุย และมันรันได้อย่างราบรื่นบนเครื่องแล็ปท็อปของเรา แล้วขั้นตอนต่อไปคืออะไร? การนำระบบขึ้นสู่ production มีหัวใจสำคัญหลายประการที่เราต้องทำให้ถูกต้อง: ตั้งแต่การสร้างคอนเทนเนอร์อิมเมจขนาดเล็กกะทัดรัด, การปิดระบบอย่างนุ่มนวล (Graceful Shutdown) เพื่อไม่ให้คำขอที่กำลังประมวลผลอยู่หลุดหาย ไปจนถึงการจัดเตรียม health check endpoint ให้ออร์เคสเตรเตอร์คอยตรวจสอบสถานะของแอปพลิเคชันได้อย่างแม่นยำ มาดูรายละเอียดในแต่ละเรื่องกันครับ

## Docker และบิลด์แบบหลายสเตจ

หากคุณคอมไพล์โค้ด Rust ด้วย target มาตรฐานของ GNU Linux (`x86_64-unknown-linux-gnu`) ไบนารีที่ได้จะถูกลิงก์แบบไดนามิกกับ glibc โดยไม่มี runtime dependency อื่นใดเพิ่มเติม หรือคุณอาจเลือกคอมไพล์ด้วย target อย่าง musl (`x86_64-unknown-linux-musl`) เพื่อให้ได้ไบนารีที่เป็น static ล้วน 100% เลยก็ได้ ไม่ว่าจะเลือกทางไหน คอนเทนเนอร์บน production ของเราก็ไม่จำเป็นต้องมี Rust toolchain, ซอร์สโค้ด หรือ build dependency ใดๆ หลงเหลืออยู่อีกเลยนอกจาก C library มาตรฐาน ซึ่งนับเป็นข่าวดีอย่างยิ่ง เพราะหมายความว่าเราสามารถใช้เทคนิค Docker multi-stage build ได้อย่างเต็มประสิทธิภาพ: นั่นคือคอมไพล์ซอร์สโค้ดในสเตจแรก จากนั้นคัดลอกเฉพาะตัวไบนารีที่ได้ไปยัง runtime image ขนาดจิ๋วในสเตจถัดไป

```dockerfile
# Build stage
FROM rust:1-slim AS builder

WORKDIR /app

# Cache dependencies by copying just the manifest files first.
# For more robust dependency caching, consider the cargo-chef crate,
# which is purpose-built for this problem in Docker builds.
COPY Cargo.toml Cargo.lock ./
RUN mkdir src && echo "fn main() {}" > src/main.rs
RUN cargo build --release && rm -rf src

# Now copy the actual source and rebuild (only changed files recompile)
COPY . .
RUN touch src/main.rs && cargo build --release

# Runtime stage
FROM debian:bookworm-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Run as a non-root user
RUN useradd --create-home appuser
USER appuser

COPY --from=builder /app/target/release/my-app /usr/local/bin/my-app

EXPOSE 3000

CMD ["my-app"]
```

เทคนิคการแคช dependency ใน build stage เป็นเรื่องที่คุ้มค่าแก่การทำความเข้าใจอย่างยิ่ง เราเริ่มต้นด้วยการคัดลอกเพียงแค่ `Cargo.toml` และ `Cargo.lock` เข้ามาก่อน แล้วสั่งรันบิลด์เพื่อสร้าง dummy project ซึ่งจะช่วยให้ Docker สามารถแคช dependency ทั้งหมดที่คอมไพล์เสร็จแล้วเก็บไว้เป็นเลเยอร์ได้ และเมื่อใดก็ตามที่เราแก้ไขโค้ดของแอปพลิเคชันโดยที่ไม่ได้แตะต้อง dependency (ซึ่งมักเป็นกรณีส่วนใหญ่ในการทำงานประจำวัน) Docker จะนำเลเยอร์แคชเดิมมาใช้ซ้ำทันที และคอมไพล์เฉพาะโค้ดส่วนของเราที่เปลี่ยนแปลงเท่านั้น หากปราศจากเทคนิคนี้ คุณจะต้องนั่งรอคอมไพล์ dependency ทั้งหมดใหม่ทุกครั้งที่บิลด์ และด้วยระยะเวลาการคอมไพล์ของ Rust ในปัจจุบัน มันจะกลายเป็นความทรมานอย่างรวดเร็ว

คุณอาจสงสัยว่าเหตุใดเราจึงต้องติดตั้ง `ca-certificates` ใน runtime image คำตอบคือแอปพลิเคชันของเรามักจะต้องยิง outbound HTTPS request ออกไปภายนอก (เช่น เรียกใช้ external API, payment gateway หรือบริการอื่นๆ) จึงจำเป็นต้องมีชุด CA certificate bundle ไว้ตรวจสอบความถูกต้องของการเชื่อมต่อ TLS หากละเลยขั้นตอนนี้ คุณจะพบกับข้อผิดพลาดเกี่ยวกับ TLS อันลึกลับตอนรันไทม์ ซึ่งคงไม่ใช่เรื่องสนุกแน่ๆ หากต้องมานั่งดีบักบน production

หากคุณต้องการลดขนาดอิมเมจให้เล็กลงไปอีกขั้น คุณสามารถเลือกคอมไพล์ด้วย `x86_64-unknown-linux-musl` เพื่อผลิตไบนารีแบบ statically linked ล้วนๆ แล้วใช้ `FROM scratch` เป็น runtime base image ซึ่งจะช่วยบีบขนาดอิมเมจลงมาเหลือต่ำกว่า 20 MB ได้อย่างน่าประทับใจ ทว่าข้อแลกเปลี่ยนคือคุณจะไม่มีทั้ง shell หรือเครื่องมือช่วยดีบักใดๆ หลงเหลืออยู่ในคอนเทนเนอร์เลย ซึ่งอาจทำให้การสืบหาสาเหตุของปัญหายากขึ้นอย่างมากเมื่อเกิดเหตุฉุกเฉินตอนตีสอง จากประสบการณ์ของผม อิมเมจแบบ Debian slim ถือเป็นจุดสมดุลที่ดีที่สุดสำหรับทีมส่วนใหญ่

## การปิดระบบอย่างนุ่มนวล

เมื่อ container orchestrator เช่น Kubernetes, ECS หรือ Docker Swarm ตัดสินใจจะหยุดการทำงานของแอปพลิเคชัน มันจะส่งสัญญาณ SIGTERM เข้ามาก่อน พร้อมทั้งให้ช่วงเวลาผ่อนผัน (grace period ซึ่งโดยทั่วไปคือ 30 วินาที) เพื่อเปิดโอกาสให้โปรเซสเคลียร์งานที่คั่งค้างอยู่ให้เสร็จสิ้นก่อนที่จะส่งสัญญาณเด็ดขาดอย่าง SIGKILL ตามมา หากแอปพลิเคชันของเราไม่ได้ดักจับและจัดการสัญญาณ SIGTERM สิ่งเลวร้ายย่อมเกิดขึ้น: คำขอที่กำลังประมวลผลค้างอยู่จะถูกตัดทิ้งทันที, database transaction จะตกค้างอยู่ในสถานะไม่ชัดเจน และฝั่งไคลเอนต์จะเจอกับ connection reset ซึ่งไม่มีใครอยากให้เกิดเหตุการณ์เช่นนั้นอย่างแน่นอน

ข่าวดีคือ Axum มีกลไกในตัวที่เตรียมไว้สำหรับการทำ graceful shutdown ไว้อย่างยอดเยี่ยม:

```rust
use tokio::signal;

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    // ... setup code ...

    let listener = tokio::net::TcpListener::bind("0.0.0.0:3000").await?;
    tracing::info!("listening on {}", listener.local_addr()?);

    axum::serve(listener, app)
        .with_graceful_shutdown(shutdown_signal())
        .await?;

    tracing::info!("server shut down cleanly");
    Ok(())
}

async fn shutdown_signal() {
    let ctrl_c = async {
        signal::ctrl_c()
            .await
            .expect("failed to install Ctrl+C handler");
    };

    #[cfg(unix)]
    let terminate = async {
        signal::unix::signal(signal::unix::SignalKind::terminate())
            .expect("failed to install SIGTERM handler")
            .recv()
            .await;
    };

    #[cfg(not(unix))]
    let terminate = std::future::pending::<()>();

    tokio::select! {
        _ = ctrl_c => {},
        _ = terminate => {},
    }

    tracing::info!("shutdown signal received, draining connections");
}
```

เมื่อได้รับสัญญาณแจ้งเตือนการปิดระบบ Axum จะหยุดรับการเชื่อมต่อใหม่ทันที แต่จะยังคงเดินหน้าประมวลผลคำขอที่ค้างอยู่ระหว่างดำเนินการ (in-flight requests) ต่อไปจนเสร็จสิ้น และเมื่อคำขอที่ค้างอยู่ทั้งหมดถูกประมวลผลจนหมด (หรือเมื่อหมดระยะเวลาผ่อนผัน) เซิร์ฟเวอร์ก็จะปิดตัวลงอย่างหมดจดและปลอดภัย

เรื่องนี้มีความสำคัญอย่างยิ่งต่อการทำงานกับฐานข้อมูล เพราะหากคำขอกำลังทำงานอยู่กึ่งกลาง transaction ในจังหวะที่สัญญาณ SIGKILL ฟาดลงมา แม้ฐานข้อมูลจะสั่ง rollback transaction นั้นในท้ายที่สุดหลังจาก connection timeout แต่ไคลเอนต์จะเห็นเป็น error ทันที ในทางกลับกัน ด้วยการทำ graceful shutdown ตัว transaction จะสามารถทำงานต่อจนเสร็จสมบูรณ์ตามปกติ และส่ง response ที่ถูกต้องกลับไปยังไคลเอนต์ได้ นี่คือหนึ่งในรายละเอียดที่หลายคนอาจมองข้าม แต่มันสร้างความแตกต่างอย่างมหาศาลในการทำงานจริงบน production

## การตรวจสุขภาพ

Health check endpoint ทำหน้าที่สื่อสารกับ container orchestrator หรือ load balancer เพื่อรายงานว่าแอปพลิเคชันยังมีชีวิตอยู่และพร้อมที่จะให้บริการ traffic หรือไม่ โดยทั่วไป orchestrator ส่วนใหญ่จะแบ่งประเภทของการตรวจสอบสุขภาพออกเป็น 2 ชนิดหลักๆ ซึ่งคุ้มค่าอย่างยิ่งที่จะทำความเข้าใจความแตกต่างของทั้งสองตัว เพราะหากตั้งค่าสับสน อาจนำไปสู่พฤติกรรมประหลาดที่ชวนปวดหัวได้

**Liveness Probe** ตอบคำถามที่ว่า: "โปรเซสยังมีชีวิตอยู่และไม่ได้เกิดอาการค้าง (hang) ใช่หรือไม่?" หาก liveness probe ล้มเหลว ตัว orchestrator จะสั่งรีสตาร์ตคอนเทนเนอร์ใหม่ทันที การตรวจสอบนี้จึงควรเน้นความเรียบง่ายและรวดเร็วเป็นหลัก และนี่คือข้อควรระวังสำคัญที่สุด: อย่าตรวจสอบ dependency ภายนอกใน liveness probe เป็นอันขาด หากฐานข้อมูลเกิดขัดข้องชั่วคราว คุณคงไม่ต้องการให้ orchestrator ไล่ฆ่าแล้วรีสตาร์ตเว็บแอปพลิเคชันวนไปเรื่อยๆ เพราะการทำเช่นนั้นจะยิ่งเป็นการกระหน่ำโหลดซ้ำเติมฐานข้อมูลที่กำลังวิกฤตอยู่ให้ย่ำแย่ลงไปอีก

```rust
async fn health_live() -> StatusCode {
    StatusCode::OK
}
```

**Readiness Probe** ตอบคำถามที่ต่างออกไป: "อินสแตนซ์นี้พร้อมที่จะรับ traffic หรือยัง?" หาก readiness probe ล้มเหลว orchestrator จะเพียงแค่หยุดการส่ง traffic มายังอินสแตนซ์ตัวนี้ชั่วคราวโดยไม่สั่งรีสตาร์ตคอนเทนเนอร์ จุดนี้เองคือตำแหน่งที่เราควรตรวจสอบว่า connection ไปยังฐานข้อมูลยังปกติดีหรือไม่, cache ที่จำเป็นสามารถเข้าถึงได้หรือยัง และแอปพลิเคชันทำขั้นตอน initialization ตอนสตาร์ตอัปเสร็จสิ้นเรียบร้อยแล้วหรือไม่

```rust
async fn health_ready(State(state): State<AppState>) -> StatusCode {
    let db_ok = sqlx::query("SELECT 1")
        .execute(&state.db)
        .await
        .is_ok();

    if db_ok {
        StatusCode::OK
    } else {
        StatusCode::SERVICE_UNAVAILABLE
    }
}
```

เราจะเมานต์ (mount) endpoint เหล่านี้ไว้ภายนอกเส้นทาง API ที่มีเวอร์ชัน:

```rust
let app = Router::new()
    .route("/health", get(health_live))
    .route("/health/ready", get(health_ready))
    .nest("/api/v1", api_routes())
    .with_state(state);
```

สำหรับการ deploy บน Kubernetes คุณสามารถกำหนดค่า probe ภายใน pod spec ได้ดังนี้:

```yaml
livenessProbe:
  httpGet:
    path: /health
    port: 3000
  initialDelaySeconds: 5
  periodSeconds: 10

readinessProbe:
  httpGet:
    path: /health/ready
    port: 3000
  initialDelaySeconds: 5
  periodSeconds: 10
```

## การตั้งค่าจากสภาพแวดล้อม

ตามที่เราได้อธิบายไว้ในบท [การตั้งค่า](./configuration.md) แอปพลิเคชันของเราควรอ่าน configuration ทั้งหมดจาก environment variable ซึ่งหมายความว่าเราสามารถนำ Docker image ตัวเดียวกันนี้ไป deploy ใช้งานได้ทั้งบน development, staging และ production โดยสิ่งเดียวที่เปลี่ยนแปลงไปในแต่ละสภาพแวดล้อมมีเพียงแค่ค่าของ environment variable ที่ระบบ deployment platform ป้อนเข้ามาให้เท่านั้น

อย่าเผลอฝัง (hardcode/bake) ค่าคอนฟิกเฉพาะของสภาพแวดล้อมลงใน Docker image เป็นอันขาด ผมเห็นหลายทีมทำเช่นนี้และลงท้ายด้วยปัญหาเสมอ ตัวอิมเมจควรเป็นอาร์ติแฟกต์ที่ไม่เปลี่ยนแปลง (Immutable Artifact) ที่คุณทำการบิลด์เพียงครั้งเดียวแล้วสามารถนำไป deploy ได้ทุกที่ เมื่อคุณเลื่อนระดับ (promote) อิมเมจที่ผ่านการทดสอบอย่างสมบูรณ์จาก staging ขึ้นสู่ production คุณย่อมต้องการความมั่นใจเต็มร้อยว่าไบนารีที่กำลังรันอยู่นั้นเป็นตัวเดียวกันทุกประการ

## การรันไมเกรชัน

Database migration ควรถูกสั่งรันเป็นส่วนหนึ่งของกระบวนการเริ่มต้นแอปพลิเคชัน (Startup) ก่อนที่เซิร์ฟเวอร์จะเปิดรับ traffic แรก ซึ่งเราสามารถจัดการเรื่องนี้ได้อย่างสะดวกด้วยมาโคร `sqlx::migrate!` ตามที่ได้อธิบายไว้ในบท [เลเยอร์ฐานข้อมูล](./database.md)

หากอยู่ในสภาพแวดล้อมของ Kubernetes คุณอาจเลือกสั่งรัน migration ในรูปแบบของ Init Container หรือ Pre-deployment Job แยกต่างหากก็ได้เช่นกัน แนวทางนั้นจะมีความชัดเจนตรงไปตรงมาและช่วยแยกความล้มเหลวจากการทำ migration ออกจากความล้มเหลวในการสตาร์ตของตัวแอปพลิเคชันได้อย่างเด็ดขาด ทว่าสำหรับแอปพลิเคชันส่วนใหญ่ ประสบการณ์ของผมพบว่าการรัน migration ในจังหวะ startup โดยตรงนั้นเรียบง่ายกว่าและทำงานได้ดีอย่างยิ่ง โดยเฉพาะเมื่อทำงานควบคู่กับ readiness probe ซึ่งจะคอยการันตีว่าแอปพลิเคชันจะไม่เปิดรับ traffic ใดๆ จนกว่ากระบวนการ migration จะเสร็จสมบูรณ์และฐานข้อมูลพร้อมใช้งาน นับเป็นตาข่ายนิรภัยที่อุ่นใจได้อย่างแท้จริง

## แล้ว Shuttle ล่ะ?

[Shuttle](https://www.shuttle.dev/) คือแพลตฟอร์มการ deploy ที่พัฒนาขึ้นเพื่อระบบนิเวศของ Rust โดยเฉพาะ โดยช่วยดูแลเรื่องการจัดเตรียมโครงสร้างพื้นฐาน (Infrastructure Provisioning), การตั้งค่าฐานข้อมูล และการ deploy ให้โดยอัตโนมัติด้วยการตั้งค่าเพียงเล็กน้อย หากคุณไม่จำเป็นต้องลงไปควบคุมรายละเอียดในระดับโครงสร้างพื้นฐานด้วยตนเอง Shuttle จะช่วยปลดเปลื้องภาระงานด้าน operation ออกไปจากบ่าของคุณได้อย่างมหาศาล

อย่างไรก็ดี ผมเชื่อมั่นว่าการทำความเข้าใจวิธีการ deploy ด้วย Docker และ Kubernetes ย่อมมีคุณค่าอย่างยิ่ง ไม่ว่าสุดท้ายแล้วคุณจะเลือกใช้แพลตฟอร์มใดก็ตาม เพราะแนวคิดพื้นฐานที่เราได้กล่าวถึงในบทนี้ (ทั้งการทำ graceful shutdown, health check, การคอนฟิกผ่าน environment variable และการสร้าง immutable image) ล้วนเป็นหลักการสากลที่นำไปปรับใช้ได้ทุกหนแห่ง แม้ว่าคุณจะใช้งาน Shuttle หรือแพลตฟอร์มสำเร็จรูปอื่นๆ การเข้าใจสิ่งที่เกิดขึ้นภายใต้กระโปรงรถ (Under the Hood) ย่อมช่วยให้คุณสืบหาและแก้ปัญหาได้อย่างแม่นยำเมื่อเกิดเหตุไม่คาดฝันขึ้น
