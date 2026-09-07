# การยืนยันตัวตนและการอนุญาตสิทธิ์

เว็บแอปพลิเคชันทุกตัวสุดท้ายต้องตอบคำถามสองข้อ: "ใครกำลังส่งคำขอนี้?" และ "พวกเขาได้รับอนุญาตให้ทำสิ่งที่ขอหรือไม่?" ข้อแรกคือการยืนยันตัวตน ข้อสองคือการอนุญาตสิทธิ์ ถ้าแอปของคุณจัดการข้อมูลผู้ใช้หรือเปิดเผยอะไรที่ละเอียดอ่อน คุณจะต้องมีทั้งสองอย่าง

สิ่งที่ผมชอบมากเกี่ยวกับ Axum ตรงนี้คือระบบตัวแยกข้อมูล เราสร้างตัวแยกข้อมูลที่กำหนดเองเพื่อตรวจสอบข้อมูลประจำตัวและเช็กสิทธิ์ได้ แล้วการเพิ่ม auth ให้แฮนด์เลอร์ก็แค่ใส่ตัวแยกข้อมูลที่ถูกต้องลงในลิสต์อาร์กิวเมนต์ มาดูกันว่ามันทำงานอย่างไร

## การเลือกกลยุทธ์การยืนยันตัวตน

แนวทางที่ถูกต้องขึ้นอยู่กับว่าไคลเอนต์ของคุณคือใคร

**แอปพลิเคชันเบราว์เซอร์แบบเฟิร์สต์ปาร์ตี้** ควรใช้เซสชันฝั่งเซิร์ฟเวอร์กับคุกกี้ คุณเก็บไอดีเซสชันในคุกกี้ `HttpOnly`, `Secure`, `SameSite=Strict` ซึ่งหมายความว่าจาวาสคริปต์เข้าถึงไม่ได้ สิ่งนี้ลดความเสี่ยงของการขโมยคุกกี้ผ่าน XSS ลงอย่างมีนัยสำคัญ ผมควรชี้แจงว่า `HttpOnly` ไม่ได้ป้องกัน XSS เอง และสคริปต์ที่ถูกแทรกยังสามารถกระทำการแทนผู้ใช้หรือขโมยข้อมูลอื่นในหน้าได้ แต่มันป้องกันเวกเตอร์การโจมตีที่พบบ่อยที่สุด นั่นคือการขโมยโทเคนเซสชันโดยตรง ซึ่งเป็นเหตุผลที่ OWASP และ MDN ต่างแนะนำ เซิร์ฟเวอร์เก็บสถานะเซสชัน (ไอดีผู้ใช้ สิทธิ์ วันหมดอายุ) ในฐานข้อมูลหรือ Redis เพื่อให้เพิกถอนเซสชันได้ทันที ครีต `tower-sessions` ให้มิดเดิลแวร์เซสชันสำหรับ Axum และ `axum-login` วางเลเยอร์การระบุตัวตน การยืนยันตัวตน และการอนุญาตสิทธิ์ซ้อนอยู่ข้างบน ถ้าคุณเลือกเซสชันแบบคุกกี้ คุณจะต้องมีการป้องกัน CSRF ตามที่อธิบายไว้ในบท [ความปลอดภัย](./security.md)

**API แบบเซอร์วิสต่อเซอร์วิสและการผสานกับบุคคลที่สาม** คือจุดที่ JWT แบบไม่เก็บสถานะ (stateless) เปล่งประกาย ไคลเอนต์ใส่โทเคนในส่วนหัว `Authorization: Bearer` และเซิร์ฟเวอร์ตรวจสอบมันโดยไม่ต้องแตะฐานข้อมูล นี่ง่ายกว่าสำหรับไคลเอนต์เครื่องจักรที่ไม่มีคุกกี้ในเบราว์เซอร์ และมันสเกลในแนวนอนได้เพราะไม่มีสถานะเซสชันฝั่งเซิร์ฟเวอร์ให้แชร์ ข้อแลกเปลี่ยนคือ JWT ไม่สามารถเพิกถอนก่อนหมดอายุได้หากไม่มีอินฟราสตรักเจอร์เพิ่มเติม (ลิสต์ปฏิเสธ หรือไลฟ์ไทม์สั้นกับรีเฟรชโทเคน)

**API สาธารณะที่มีผู้บริโภคภายนอก** มักใช้ OAuth2/OIDC โดยผู้ให้บริการระบุตัวตน (identity provider) เป็นผู้ออกโทเคน และ API ของคุณตรวจสอบมัน ครีต `jwt-authorizer` รองรับ OIDC discovery และการหมุนคีย์อัตโนมัติสำหรับกรณีการใช้งานนี้

สำหรับบทที่เหลือ เราจะโฟกัสที่แนวทาง JWT มันเป็นแพตเทิร์นที่พบบ่อยที่สุดสำหรับเซอร์วิสแบบ API และมันโชว์แพตเทิร์นตัวแยกข้อมูลของ Axum ได้สวย ถ้าคุณกำลังสร้างแอปพลิเคชันที่ผู้ใช้ใช้งานผ่านเบราว์เซอร์ ให้เริ่มด้วย `tower-sessions` และ `axum-login` แทน

## การยืนยันตัวตนแบบ JWT ด้วย extractor ที่กำหนดเอง

JWT ทำงานได้ดีกับการยืนยันตัวตน API แบบไม่เก็บสถานะ โฟลว์ตรงไปตรงมา: ไคลเอนต์ยืนยันตัวตน (โดยทั่วไปด้วยอีเมลและรหัสผ่าน) ได้ JWT กลับมา แล้วก็ใส่ไว้ในส่วนหัว `Authorization` ในทุกคำขอถัดไป เซิร์ฟเวอร์ตรวจสอบโทเคนทุกครั้งโดยไม่ต้องค้นอะไรในฐานข้อมูล

กุญแจสำคัญที่ทำให้สิ่งนี้ทำงานได้อย่างสะอาดใน Axum คือการสร้างตัวแยกข้อมูลที่กำหนดเองซึ่งอิมพลีเมนต์ `FromRequestParts` เมื่อคุณใส่ตัวแยกข้อมูลนี้ในลายเซ็นของแฮนด์เลอร์ Axum จะรันตรรกะการตรวจสอบให้อัตโนมัติก่อนที่บอดี้ของแฮนด์เลอร์จะได้ประมวลผล มาดูกันว่าหน้าตาเป็นอย่างไร

```rust
use axum::{
    extract::FromRequestParts,
    http::request::Parts,
};
use axum_extra::{
    headers::{Authorization, authorization::Bearer},
    TypedHeader,
};
use jsonwebtoken::{decode, Algorithm, DecodingKey, Validation};

/// Represents an authenticated user. Including this in a handler's
/// signature automatically requires and validates a JWT.
#[derive(Debug, Clone)]
pub struct AuthUser {
    pub user_id: Uuid,
    pub email: String,
    pub role: Role,
}

#[derive(Debug, Clone, Deserialize, Serialize)]
pub struct Claims {
    pub sub: Uuid,       // subject (user ID)
    pub email: String,
    pub role: Role,
    pub iss: String,     // issuer
    pub aud: String,     // audience
    pub exp: usize,      // expiration time
    pub iat: usize,      // issued at
}

impl<S> FromRequestParts<S> for AuthUser
where
    AppState: FromRef<S>,
    S: Send + Sync,
{
    type Rejection = AppError;

    async fn from_request_parts(
        parts: &mut Parts,
        state: &S,
    ) -> Result<Self, Self::Rejection> {
        let app_state = AppState::from_ref(state);

        // Extract the Authorization: Bearer <token> header
        let TypedHeader(Authorization(bearer)) = parts
            .extract::<TypedHeader<Authorization<Bearer>>>()
            .await
            .map_err(|_| AppError::Unauthorized)?;

        // Decode and validate the JWT with explicit validation rules.
        // Validation::default() uses HS256 and checks exp, but you should
        // be explicit about what you accept in production.
        let mut validation = Validation::new(Algorithm::HS256);
        validation.set_issuer(&["myapp"]);
        validation.set_audience(&["myapp-api"]);
        validation.leeway = 30; // 30 seconds of clock skew tolerance

        let token_data = decode::<Claims>(
            bearer.token(),
            &DecodingKey::from_secret(
                app_state.config.jwt_secret.expose_secret().as_bytes()
            ),
            &validation,
        )
        .map_err(|_| AppError::Unauthorized)?;

        Ok(AuthUser {
            user_id: token_data.claims.sub,
            email: token_data.claims.email,
            role: token_data.claims.role,
        })
    }
}
```

การใช้งานในแฮนด์เลอร์ง่ายแค่เพิ่มพารามิเตอร์ลงในลายเซ็นฟังก์ชัน:

```rust
async fn get_my_profile(
    user: AuthUser,
    State(state): State<AppState>,
) -> AppResult<Json<ProfileResponse>> {
    let profile = state.user_service
        .get_by_id(UserId::from_uuid(user.user_id))
        .await?
        .ok_or(AppError::NotFound)?;

    Ok(Json(profile.into()))
}
```

ถ้า JWT หายไป หมดอายุ หรือไม่ถูกต้อง ตัวแยกข้อมูลของเราคืน `AppError::Unauthorized` และบอดี้ของแฮนด์เลอร์ไม่ถูกรันเลย ไม่มีโค้ดเช็ก auth แบบชัดเจนในตัวแฮนด์เลอร์ ซึ่งเป็นรูปแบบการแยกหน้าที่ผมอยากเห็นเป๊ะๆ

### การยืนยันตัวตนแบบไม่บังคับด้วย MaybeAuthUser

บางเอนด์พอยต์มีพฤติกรรมต่างกันขึ้นอยู่กับว่าผู้เรียกเข้าสู่ระบบหรือยัง โดยไม่จำเป็นต้องบังคับให้ยืนยันตัวตนจริงๆ นึกถึงเอนด์พอยต์ฟีดที่แสดงผลเฉพาะบุคคลสำหรับผู้ใช้ที่เข้าสู่ระบบแล้ว และผลลัพธ์ทั่วไปสำหรับผู้เยี่ยมชมที่ไม่ระบุตัวตน

คุณอาจอยากใช้แค่ `Option<AuthUser>` ตรงนี้ แต่นั่นทำให้ความแตกต่างสำคัญหายไป `None` อาจหมายถึง "ไม่มีการส่งส่วนหัว Authorization" (ผู้ใช้ไม่ระบุตัวตน) หรือ "มีการส่งส่วนหัว Authorization แต่โทเคนไม่มีความหมาย" (ซึ่งควรเป็น 401 ไม่ใช่การถอยไปเป็นพฤติกรรมผู้ไม่ระบุตัวตนเงียบๆ) สองสถานการณ์นี้ต่างกันมาก

extractor เฉพาะ `MaybeAuthUser` ช่วยให้เราแยกสองกรณีนี้ได้:

```rust
pub struct MaybeAuthUser(pub Option<AuthUser>);

impl<S> FromRequestParts<S> for MaybeAuthUser
where
    AppState: FromRef<S>,
    S: Send + Sync,
{
    type Rejection = AppError;

    async fn from_request_parts(
        parts: &mut Parts,
        state: &S,
    ) -> Result<Self, Self::Rejection> {
        // If there is no Authorization header at all, that is fine.
        let Some(auth_header) = parts.headers.get(header::AUTHORIZATION) else {
            return Ok(Self(None));
        };

        // But if a header IS present, it must be valid.
        // An invalid token is an error, not anonymous access.
        let token = auth_header
            .to_str()
            .ok()
            .and_then(|v| v.strip_prefix("Bearer "))
            .ok_or(AppError::Unauthorized)?;

        let app_state = AppState::from_ref(state);
        let mut validation = Validation::new(Algorithm::HS256);
        validation.set_issuer(&["myapp"]);
        validation.set_audience(&["myapp-api"]);

        let token_data = decode::<Claims>(
            token,
            &DecodingKey::from_secret(
                app_state.config.jwt_secret.expose_secret().as_bytes()
            ),
            &validation,
        )
        .map_err(|_| AppError::Unauthorized)?;

        Ok(Self(Some(AuthUser {
            user_id: token_data.claims.sub,
            email: token_data.claims.email,
            role: token_data.claims.role,
        })))
    }
}
```

ผมเก็บแพตเทิร์นนี้มาจากรีพรีเซนเทชันอ้างอิง [launchbadge/realworld-axum-sqlx](https://github.com/launchbadge/realworld-axum-sqlx) ซึ่งบันทึกไว้ว่าเป็นการตัดสินใจออกแบบโดยเจตนา มันเป็นรายละเอียดเล็กๆ แต่ป้องกันบั๊ก auth ที่ละเอียดอ่อนทั้งหมวด ที่ไคลเอนต์ส่งโทเคนผิดรูปแล้วได้พฤติกรรมผู้ไม่ระบุตัวตนเงียบๆ แทนที่จะเป็นข้อผิดพลาดที่ชัดเจน

## การออกโทเคน

ทีนี้มาดูอีกด้านของเหรียญ: เราสร้างโทเคนเหล่านี้ได้อย่างไรจริงๆ เอนด์พอยต์ login ตรวจสอบข้อมูลประจำตัวแล้วออก JWT:

```rust
use jsonwebtoken::{encode, EncodingKey, Header};

async fn login(
    State(state): State<AppState>,
    Json(credentials): Json<LoginDto>,
) -> AppResult<Json<TokenResponse>> {
    let user = state.user_service
        .authenticate(&credentials.email, &credentials.password)
        .await?
        .ok_or(AppError::Unauthorized)?;

    let now = chrono::Utc::now();
    let claims = Claims {
        sub: *user.id().as_uuid(),
        email: user.email().as_str().to_string(),
        role: user.role().clone(),
        iss: "myapp".to_string(),
        aud: "myapp-api".to_string(),
        iat: now.timestamp() as usize,
        // Short-lived access tokens limit damage if compromised.
        // For longer sessions, implement a refresh token mechanism.
        exp: (now + chrono::TimeDelta::try_minutes(15).expect("valid duration"))
            .timestamp() as usize,
    };

    let token = encode(
        &Header::default(),
        &claims,
        &EncodingKey::from_secret(
            state.config.jwt_secret.expose_secret().as_bytes()
        ),
    )
    .map_err(|e| AppError::Internal(e.into()))?;

    Ok(Json(TokenResponse { token }))
}
```

มีข้อควรพิจารณาเรื่อง production อยู่หลายข้อที่มองข้ามได้ง่าย

**อายุของโทเคน (token lifetime)** ตัวอย่างของเราใช้อักเสสโทเคนอายุ 15 นาที อายุสั้นจำกัดกรอบเวลาที่เสี่ยงถ้าโทเคนถูกขโมย สำหรับแอปพลิเคชันที่ผู้ใช้ต้องมีเซสชันยาวขึ้น คุณจะต้องมีโฟลว์รีเฟรชโทเคนแยกต่างหาก โดยรีเฟรชโทเคนอยู่ในคุกกี้ HttpOnly ที่ปลอดภัยและเพิกถอนได้ฝั่งเซิร์ฟเวอร์

**การยึดอัลกอริทึม (algorithm pinning)** ระบุอัลกอริทึมที่คาดหวังอย่างชัดเจนเสมอ (ตรงนี้คือ `Algorithm::HS256`) แทนที่จะเชื่อส่วนหัว `alg` ในตัวโทเคน การยอมรับอัลกอริทึมที่โทเคนประกาศตัวเองเป็นเวกเตอร์การโจมตีที่รู้จักกันดี และผมเคยเห็นมันกัดทีมที่คิดว่าตัวเองกำลังยืดหยุ่น

**ผู้ออกโทเคนและกลุ่มผู้รับ (issuer and audience)** การตั้งเคลม `iss` และ `aud` พร้อมตรวจสอบมันตอนดีโค้ด ป้องกันไม่ให้โทเคนที่ออกสำหรับเซอร์วิสหนึ่งถูกยอมรับโดยอีกเซอร์วิสหนึ่ง สิ่งนี้สำคัญทันทีที่คุณมีเซอร์วิสมากกว่าหนึ่งตัวที่แชร์ความลับเดียวกันหรือใช้ identity provider เดียวกัน

**เคลมบทบาทกับการเพิกถอน (role claims and revocation)** นี่คือสิ่งที่ทำให้คนเซอร์ไพรส์: การฝังบทบาทลงใน JWT หมายความว่าการเปลี่ยนสิทธิ์ (เพิกถอนสิทธิ์แอดมิน ปิดบัญชี) จะไม่ส่งผลจนกว่าโทเคนจะหมดอายุและออกใหม่ ถ้าการเพิกถอนทันทีสำคัญต่อแอปพลิเคชันของคุณ คุณจะต้องใช้ไลฟ์ไทม์ของโทเคนที่สั้นมาก การเช็กเวอร์ชันโทเคนกับฐานข้อมูล หรือลิสต์ปฏิเสธ

## การแฮชรหัสผ่าน

คุณรู้อยู่แล้วว่าอย่าเก็บรหัสผ่านเป็นข้อความธรรมดา แต่การเลือกอัลกอริทึมแฮชก็สำคัญเช่นกัน สำหรับโปรเจกต์ใหม่ ใช้ Argon2 มันชนะการแข่งขัน Password Hashing Competition ในปี 2015 และมันยังเป็นตัวเลือกที่ดีที่สุดที่เรามี อย่าใช้ SHA-256, MD5 หรือแม้แต่ bcrypt สำหรับโค้ดใหม่

```rust
use argon2::{
    Argon2,
    PasswordHash,
    PasswordHasher,
    PasswordVerifier,
    password_hash::SaltString,
};
use argon2::password_hash::rand_core::OsRng;

pub fn hash_password(password: &str) -> anyhow::Result<String> {
    let salt = SaltString::generate(&mut OsRng);
    // Use Argon2id, which is the variant recommended by OWASP.
    // The default() configuration uses Argon2id with reasonable parameters,
    // but for production you should tune memory cost and iterations based
    // on your hardware and OWASP's current minimum recommendations.
    let hasher = Argon2::default(); // Argon2id with default params
    let hash = hasher
        .hash_password(password.as_bytes(), &salt)
        .map_err(|e| anyhow::anyhow!("failed to hash password: {}", e))?
        .to_string();
    Ok(hash)
}

pub fn verify_password(password: &str, hash: &str) -> anyhow::Result<bool> {
    let parsed_hash = PasswordHash::new(hash)
        .map_err(|e| anyhow::anyhow!("failed to parse password hash: {}", e))?;
    Ok(Argon2::default()
        .verify_password(password.as_bytes(), &parsed_hash)
        .is_ok())
}
```

เรื่องหนึ่งที่ต้องจำไว้: การแฮชรหัสผ่านช้าอย่างตั้งใจ นั่นคือประเด็นทั้งหมด คือการทำให้การโจมตีแบบ brute-force ไม่สามารถทำได้จริง แต่ในบริบท async นี่หมายความว่าคุณควรรันมันบนเธรดที่บล็อก เพื่อไม่ให้ผูกมัดรันไทม์แอซิงก์ไว้:

```rust
let hash = tokio::task::spawn_blocking(move || hash_password(&password))
    .await
    .context("password hashing task failed")??;
```

## การอนุญาตสิทธิ์ตามบทบาท

เมื่อเราทำให้การยืนยันตัวตนทำงานได้แล้ว การอนุญาตสิทธิ์คือขั้นถัดไปตามธรรมชาติ วิธีที่ง่ายที่สุดคือการเช็กบทบาทของผู้ใช้ในแฮนด์เลอร์:

```rust
async fn admin_only_endpoint(
    user: AuthUser,
    State(state): State<AppState>,
) -> AppResult<Json<AdminData>> {
    if user.role != Role::Admin {
        return Err(AppError::Forbidden);
    }
    // ... admin logic
}
```

แบบนั้นใช้ได้ แต่ถ้าคุณพบว่าตัวเองเขียนการเช็กบทบาทซ้ำๆ ในหลายแฮนด์เลอร์ เราทำได้ดีกว่านี้ มาสร้างตัวแยกข้อมูลที่ฝังข้อกำหนดบทบาทเข้าไปเลย:

```rust
pub struct RequireAdmin(pub AuthUser);

impl<S> FromRequestParts<S> for RequireAdmin
where
    AppState: FromRef<S>,
    S: Send + Sync,
{
    type Rejection = AppError;

    async fn from_request_parts(
        parts: &mut Parts,
        state: &S,
    ) -> Result<Self, Self::Rejection> {
        let user = AuthUser::from_request_parts(parts, state).await?;

        if user.role != Role::Admin {
            return Err(AppError::Forbidden);
        }

        Ok(Self(user))
    }
}

// Usage: just include it in the handler signature
async fn admin_endpoint(RequireAdmin(user): RequireAdmin) -> AppResult<Json<AdminData>> {
    // If we get here, the user is authenticated AND has the admin role
    // ...
}
```

## การยืนยันตัวตนผ่านมิดเดิลแวร์

ยังมีอีกวิธีในการจัดการเรื่องนี้: แทนที่จะวางตัวแยกข้อมูลบนแฮนด์เลอร์แต่ละตัว คุณใช้การยืนยันตัวตนเป็นมิดเดิลแวร์กับกลุ่มเส้นทางทั้งกลุ่ม นี่สะดวกเมื่อคุณมีเส้นทางเป็นบล็อกที่ต้องยืนยันตัวตนทั้งหมด และไม่อยากเขียน `AuthUser` ซ้ำในลายเซ็นของทุกแฮนด์เลอร์

```rust
let public_routes = Router::new()
    .route("/health", get(health_check))
    .route("/api/v1/auth/login", post(login))
    .route("/api/v1/auth/register", post(register));

let protected_routes = Router::new()
    .nest("/api/v1/users", user_routes())
    .nest("/api/v1/posts", post_routes())
    .route_layer(middleware::from_fn_with_state(
        state.clone(),
        auth_middleware,
    ));

let app = Router::new()
    .merge(public_routes)
    .merge(protected_routes)
    .with_state(state);
```

แล้วควรเลือกวิธีไหน? จากประสบการณ์ของผม ตัวแยกข้อมูลยืดหยุ่นกว่าเพราะแฮนด์เลอร์แต่ละตัวเลือกเข้า/ออกได้ และแฮนด์เลอร์เข้าถึงค่า `AuthUser` ได้โดยตรง มิดเดิลแวร์สะดวกกว่าเมื่อเส้นทางทั้งกลุ่มมีข้อกำหนดการยืนยันตัวตนเดียวกัน คุณยังรวมทั้งสองเข้าด้วยกันได้ โดยใช้มิดเดิลแวร์เป็นพื้นฐานและใช้ตัวแยกข้อมูลสำหรับการเช็กที่ละเอียดขึ้นภายในกลุ่มนั้น

## ครีตในระบบนิเวศ

ก่อนจะปิดท้าย คุ้มที่จะรู้ว่าระบบนิเวศมีอะไรให้บ้าง คุณไม่ต้องเขียนเองทุกอย่าง:

- **axum-login** ให้การยืนยันตัวตนแบบเซสชันพร้อมแบ็กเอนด์ที่เสียบสลับได้
- **axum-gate** รวมการตรวจสอบ JWT เข้ากับการอนุญาตสิทธิ์ตามบทบาท
- **axum-session** จัดการเซสชันที่เก็บในฐานข้อมูล
- **jwt-authorizer** ให้การตรวจสอบ JWT พร้อมรองรับ OIDC discovery
- **axum-csrf-sync-pattern** อิมพลีเมนต์การป้องกัน CSRF สำหรับการยืนยันตัวตนแบบเซสชัน

สำหรับแอปพลิเคชันสไตล์ API ส่วนใหญ่ ผมคิดว่าแนวทางตัวแยกข้อมูล `AuthUser` ที่เราสร้างข้างบนให้สมดุลที่เหมาะสมระหว่างความเรียบง่ายและการควบคุม แต่เมื่อคุณต้องการฟีเจอร์ซับซ้อนอย่างการจัดการเซสชัน โฟลว์ OAuth2 หรือการผสาน OIDC ครีตพวกนี้ช่วยประหยัดงานได้มาก
