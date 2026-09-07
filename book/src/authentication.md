# การยืนยันตัวตนและการอนุญาตสิทธิ์

เว็บแอปพลิเคชันเกือบทุกตัวจะต้องตอบคำถามพื้นฐาน 2 ข้อให้ได้เสมอ: "ใครเป็นคนส่ง request นี้มา?" และ "พวกเขามีสิทธิ์ทำสิ่งที่ร้องขอหรือไม่?" ข้อแรกคือการยืนยันตัวตน (Authentication) ส่วนข้อหลังคือการตรวจสอบสิทธิ์ (Authorization) และหากแอปพลิเคชันของคุณมีการจัดการข้อมูลผู้ใช้หรือมีส่วนที่ต้องควบคุมการเข้าถึง คุณย่อมจำเป็นต้องมีทั้งสองอย่างนี้อย่างแน่นอน

สิ่งที่ผมประทับใจเป็นพิเศษเกี่ยวกับ Axum ในเรื่องนี้คือระบบ extractor เพราะเราสามารถสร้าง custom extractor เพื่อตรวจเช็ก credentials และสิทธิ์ของผู้ใช้ได้โดยตรง ทำให้การเพิ่มระบบ auth เข้าไปใน handler ง่ายดายเพียงแค่ใส่ extractor ที่เหมาะสมลงไปในพารามิเตอร์ของฟังก์ชัน มาดูกันว่าแนวทางนี้ทำงานอย่างไร

## การเลือกกลยุทธ์การยืนยันตัวตน

แนวทางที่เหมาะสมจะขึ้นอยู่กับว่าไคลเอนต์ของคุณคือใครเป็นหลัก:

**แอปพลิเคชันบนเบราว์เซอร์แบบ First-party** ควรเลือกใช้ server-side sessions ร่วมกับ cookie โดยคุณควรเก็บ session ID ไว้ใน cookie ที่ตั้งค่า `HttpOnly`, `Secure`, `SameSite=Strict` ซึ่งหมายความว่าโค้ด JavaScript จะไม่สามารถเข้าถึง cookie นี้ได้ ช่วยลดความเสี่ยงจากการถูกขโมย cookie ผ่านการโจมตี XSS ได้อย่างมีนัยสำคัญ ทั้งนี้ผมต้องขอชี้แจงว่า `HttpOnly` ไม่ได้ป้องกันช่องโหว่ XSS โดยตรง เพราะ script ที่ถูกฝังเข้ามายังอาจแอบทำ action แทนผู้ใช้หรือขโมยข้อมูลอื่นบนหน้าเว็บได้ แต่มันช่วยตัดทางโจมตีที่พบบ่อยที่สุดอย่างการขโมย session token ออกไปโดยตรง ซึ่งนี่คือเหตุผลที่ทั้ง OWASP และ MDN ต่างแนะนำแนวทางนี้ ฝั่งเซิร์ฟเวอร์จะเก็บสถานะของ session (user ID, สิทธิ์การใช้งาน, วันหมดอายุ) ไว้ในฐานข้อมูลหรือ Redis เพื่อให้สามารถสั่งเพิกถอนสิทธิ์ (revoke) ได้ทันที โดย crate `tower-sessions` มี middleware สำหรับจัดการ session บน Axum และ `axum-login` จะช่วยวางเลเยอร์การระบุตัวตน ยืนยันตัวตน และตรวจสอบสิทธิ์ครอบทับอีกชั้น หากคุณเลือกใช้ session ร่วมกับ cookie คุณจำเป็นต้องมีมาตรการป้องกัน CSRF ตามที่อธิบายไว้ในบท [ความปลอดภัย](./security.md) ด้วยเสมอ

**API แบบ Service-to-service และการเชื่อมต่อกับ Third-party** เป็นจุดที่ stateless JWT โดดเด่นเป็นพิเศษ ไคลเอนต์จะแนบ token มาใน header `Authorization: Bearer` และเซิร์ฟเวอร์สามารถตรวจสอบความถูกต้องได้ทันทีโดยไม่ต้อง query ฐานข้อมูล วิธีนี้สะดวกอย่างยิ่งสำหรับ machine clients ที่ไม่มี browser cookies และยัง scale แนวนอนได้ง่ายเพราะไม่มี session state ฝั่งเซิร์ฟเวอร์ให้ต้องแชร์กัน ข้อแลกเปลี่ยนคือ JWT จะไม่สามารถยกเลิกก่อนเวลาหมดอายุได้ เว้นแต่คุณจะสร้าง infrastructure เพิ่มเติมเข้ามารองรับ (เช่น denylist หรือการใช้อายุ token สั้นๆ ควบคู่กับ refresh token)

**Public API สำหรับบุคคลภายนอก** มักเลือกใช้ OAuth2/OIDC โดยจะมี Identity Provider คอยออก token ให้ แล้ว API ของคุณทำหน้าที่ตรวจสอบความถูกต้อง crate อย่าง `jwt-authorizer` จะช่วยรองรับทั้ง OIDC discovery และการหมุนเวียนคีย์ (key rotation) แบบอัตโนมัติสำหรับกรณีการใช้งานลักษณะนี้

สำหรับเนื้อหาที่เหลือในบทนี้ เราจะเน้นไปที่แนวทาง JWT เนื่องจากเป็นแพตเทิร์นที่นิยมใช้กันมากที่สุดสำหรับ API service และยังแสดงให้เห็นถึงพลังของระบบ extractor ใน Axum ได้อย่างชัดเจน แต่หากคุณกำลังพัฒนาเว็บแอปพลิเคชันที่มีผู้ใช้เข้าใช้งานผ่านเบราว์เซอร์เป็นหลัก ผมแนะนำให้เริ่มต้นด้วย `tower-sessions` และ `axum-login` แทน

## การยืนยันตัวตนแบบ JWT ด้วย extractor ที่กำหนดเอง

JWT ตอบโจทย์ได้ดีมากกับการยืนยันตัวตนบน API แบบ stateless โดยมี flow การทำงานที่ตรงไปตรงมา: ไคลเอนต์ยืนยันตัวตน (โดยทั่วไปใช้อีเมลและรหัสผ่าน) แล้วรับ JWT กลับไป จากนั้นก็นำมาแนบใน header `Authorization` สำหรับทุกๆ request ถัดไป ฝั่งเซิร์ฟเวอร์จะตรวจสอบความถูกต้องของ token ในแต่ละ request ได้ทันทีโดยไม่ต้องเสียเวลาค้นหาข้อมูลใน database

หัวใจสำคัญที่ทำให้โครงสร้างนี้เป็นระเบียบเรียบร้อยใน Axum คือการสร้าง custom extractor ที่อิมพลีเมนต์ `FromRequestParts` เมื่อคุณใส่ extractor นี้ไว้ใน signature ของ handler ตัว Axum จะรันขั้นตอนตรวจสอบ token ให้อัตโนมัติก่อนที่ code logic ภายใน handler จะเริ่มทำงานด้วยซ้ำ มาดูกันว่าโค้ดจริงมีหน้าตาเป็นอย่างไร:


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

การนำไปใช้งานใน handler นั้นง่ายเพียงแค่เพิ่มพารามิเตอร์เข้าไปใน function signature:

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

หากไม่มี JWT แนบมา, token หมดอายุแล้ว, หรือไม่ถูกต้อง ตัว extractor ของเราจะคืน `AppError::Unauthorized` และโค้ดใน handler จะไม่ถูกรันเลยแม้แต่น้อย ไม่มีโค้ดตรวจเช็ก auth ปะปนอยู่ในตัว handler ซึ่งเป็นการแบ่งแยกหน้าที่ (separation of concerns) ที่ชัดเจนและสวยงามมาก

### การยืนยันตัวตนแบบไม่บังคับด้วย MaybeAuthUser

บาง endpoint อาจมีพฤติกรรมแตกต่างกันขึ้นอยู่กับว่าผู้เรียกเข้าสู่ระบบแล้วหรือยัง โดยไม่ได้บังคับว่าต้องล็อกอินเสมอไป เช่น endpoint ดึงฟีดข่าวที่แสดงผลเฉพาะบุคคลสำหรับผู้ใช้ที่เข้าสู่ระบบแล้ว แต่จะแสดงเนื้อหาทั่วไปสำหรับผู้เยี่ยมชมที่ไม่ระบุตัวตน

คุณอาจอยากใช้แค่ `Option<AuthUser>` ตรงจุดนี้ แต่การทำแบบนั้นจะทำให้เราสูญเสียความแตกต่างที่สำคัญมากไป เพราะค่า `None` อาจหมายถึง "ไม่ได้ส่ง Authorization header มาเลย" (เป็น anonymous user จริงๆ) หรืออาจหมายถึง "ส่ง Authorization header มา แต่ token นั้นผิดพลาดหรือใช้การไม่ได้" (ซึ่งควรได้ 401 ไม่ใช่การถอยกลับไปเป็นพฤติกรรมแบบ anonymous user ไปเงียบๆ) สถานการณ์สองแบบนี้แตกต่างกันอย่างสิ้นเชิง

การสร้าง custom extractor อย่าง `MaybeAuthUser` ช่วยให้เราแยกแยะสองกรณีนี้ออกจากกันได้อย่างชัดเจน:

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

ผมได้แพตเทิร์นนี้มาจาก reference implementation ใน [launchbadge/realworld-axum-sqlx](https://github.com/launchbadge/realworld-axum-sqlx) ซึ่งระบุไว้ชัดเจนว่าเป็นความตั้งใจในการออกแบบ แม้จะเป็นรายละเอียดเล็กๆ แต่ก็ช่วยป้องกันหมวดหมู่บั๊กด้าน auth ที่ตรวจจับได้ยาก นั่นคือกรณีที่ไคลเอนต์ส่ง token ผิดรูปเข้ามาแล้วระบบกลับทำงานแบบ anonymous user ไปเงียบๆ แทนที่จะแจ้ง error ออกมาให้ชัดเจน

## การออกโทเคน

ทีนี้มาดูอีกด้านหนึ่งกันบ้าง: โค้ดฝั่งสร้างและออก token ทำงานอย่างไรจริงๆ? endpoint ล็อกอินจะทำการตรวจสอบ credentials ของผู้ใช้ แล้วจึงออก JWT ให้ดังนี้:

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

มีข้อควรพิจารณาสำคัญสำหรับ production หลายข้อที่มักถูกมองข้ามได้ง่าย:

**อายุของโทเคน (Token lifetime)** ตัวอย่างข้างต้นใช้ access token ที่มีอายุเพียง 15 นาที การกำหนดอายุ token ให้สั้นจะช่วยจำกัดความเสียหายหาก token หลุดรอดไป สำหรับแอปพลิเคชันที่ต้องการให้ผู้ใช้ล็อกอินค้างไว้ได้นานขึ้น คุณควรมีกลไก refresh token แยกต่างหาก โดยเก็บ refresh token ไว้ใน HttpOnly cookie ที่ปลอดภัย และสามารถสั่ง revoke ฝั่งเซิร์ฟเวอร์ได้

**การตรึงอัลกอริทึม (Algorithm pinning)** ควรกำหนดอัลกอริทึมที่ยอมรับอย่างชัดเจนเสมอ (ในที่นี้คือ `Algorithm::HS256`) แทนที่จะเชื่อค่าใน header `alg` ที่ส่งมากับตัว token โดยตรง การยอมรับอัลกอริทึมตามที่ตัว token ระบุมาถือเป็นช่องทางการโจมตีที่เป็นที่รู้จักกันดี และผมเคยเห็นหลายทีมต้องเจ็บปวดกับเรื่องนี้เพราะคิดว่าตัวเองกำลังเขียนโค้ดให้ยืดหยุ่น

**ผู้ออกและผู้รับโทเคน (Issuer and Audience)** การระบุ claim `iss` และ `aud` พร้อมตรวจสอบค่าเหล่านี้ตอน decode จะช่วยป้องกันไม่ให้ token ที่สร้างขึ้นสำหรับ service หนึ่งถูกนำไปสวมรอยใช้กับอีก service หนึ่ง ซึ่งจุดนี้สำคัญมากเมื่อระบบของคุณมีหลาย service ที่ใช้ secret ร่วมกันหรือเชื่อมต่อกับ Identity Provider เดียวกัน

**Role claims กับการเพิกถอนสิทธิ์ (Revocation)** เรื่องนี้มักสร้างความประหลาดใจให้หลายคน: การฝัง role ไว้ใน JWT แปลว่าเมื่อมีการเปลี่ยนสิทธิ์ผู้ใช้ (เช่น ปลดสิทธิ์ admin หรือระงับบัญชี) การเปลี่ยนแปลงนั้นจะยังไม่มีผลจนกว่า token เดิมจะหมดอายุและมีการออก token ใหม่ หากระบบของคุณจำเป็นต้องตัดสิทธิ์ได้ทันที คุณจะต้องเลือกใช้อายุ token ที่สั้นมากๆ หรือตรวจสอบ token version เทียบกับฐานข้อมูล หรือสร้าง denylist ขึ้นมาช่วย

## การแฮชรหัสผ่าน

ทุกคนย่อมทราบดีอยู่แล้วว่าไม่ควรเก็บรหัสผ่านเป็น plain text แต่การเลือกอัลกอริทึมสำหรับ hash รหัสผ่านก็สำคัญไม่แพ้กัน สำหรับโปรเจกต์ใหม่ แนะนำให้เลือกใช้ Argon2 ซึ่งชนะการแข่งขัน Password Hashing Competition เมื่อปี 2015 และยังคงเป็นตัวเลือกที่ดีและปลอดภัยที่สุดในปัจจุบัน โปรดหลีกเลี่ยงการใช้ SHA-256, MD5 หรือแม้กระทั่ง bcrypt สำหรับโปรเจกต์ใหม่

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

ข้อสำคัญที่ต้องพึงระลึกไว้เสมอคือ: การแฮชรหัสผ่านนั้นถูกออกแบบมาให้ทำงานช้าโดยเจตนา เพื่อทำให้การโจมตีแบบ brute-force ทำได้ยากจนไม่คุ้มค่า แต่ในบริบทของ async programming การทำงานที่กิน CPU หนักและใช้เวลานานแบบนี้หมายความว่าคุณควรโยนงานไปรันบน blocking thread pool เพื่อไม่ให้ไปบล็อกการทำงานของ async runtime:

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

วิธีนี้ใช้งานได้ดี แต่หากคุณพบว่าตัวเองต้องเขียนโค้ดตรวจสอบ role ซ้ำๆ ในหลาย handler เราสามารถปรับปรุงให้ดีขึ้นได้ด้วยการสร้าง custom extractor ที่ฝังเงื่อนไข role เข้าไปในตัวเลย:

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

ยังมีอีกวิธีหนึ่งในการจัดการเรื่องนี้: แทนที่จะใส่ extractor ไว้ในแต่ละ handler คุณสามารถใช้ middleware ยืนยันตัวตนครอบ route ทั้งกลุ่มได้เลย วิธีนี้สะดวกมากเมื่อคุณมีกลุ่ม route ขนาดใหญ่ที่ต้องการ auth เหมือนกันทั้งหมด และไม่อยากเขียน `AuthUser` ซ้ำๆ ใน signature ของทุก handler

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

แล้วควรเลือกใช้แนวทางไหนดี? จากประสบการณ์ของผม extractor มีความยืดหยุ่นสูงกว่า เพราะแต่ละ handler สามารถเลือกใช้งานได้อย่างอิสระและเข้าถึงข้อมูล `AuthUser` ได้โดยตรง ส่วน middleware จะสะดวกกว่าเมื่อกลุ่มของ route ทั้งหมดมีเงื่อนไขการยืนยันตัวตนเหมือนกันทุกประการ นอกจากนี้คุณยังสามารถผสานทั้งสองวิธีเข้าด้วยกันได้ โดยใช้ middleware เป็นด่านแรกในการคัดกรอง และใช้ extractor สำหรับการตรวจสอบเงื่อนไขที่ละเอียดขึ้นภายใน handler แต่ละตัว

## เครตในระบบนิเวศ

ก่อนจะจบบทนี้ ควรทำความรู้จักเครื่องมือใน ecosystem เพิ่มเติมไว้ เพราะคุณไม่จำเป็นต้องเขียนโค้ดขึ้นมาเองทั้งหมด:

- **axum-login** ให้ระบบยืนยันตัวตนแบบ session พร้อมรองรับ backend storage หลากหลายรูปแบบ
- **axum-gate** รวมการตรวจสอบ JWT เข้ากับการตรวจสอบสิทธิ์ตามบทบาท (role-based authorization)
- **axum-session** จัดการ session ที่จัดเก็บไว้ในฐานข้อมูล
- **jwt-authorizer** รองรับการตรวจสอบ JWT พร้อมทั้ง OIDC discovery
- **axum-csrf-sync-pattern** อิมพลีเมนต์การป้องกัน CSRF สำหรับระบบยืนยันตัวตนแบบ session

สำหรับแอปพลิเคชันสไตล์ API ส่วนใหญ่ ผมคิดว่าแนวทาง custom extractor อย่าง `AuthUser` ที่เราสร้างขึ้นข้างต้นให้ความสมดุลที่ดีเยี่ยมระหว่างความเรียบง่ายและการควบคุม แต่เมื่อระบบต้องการฟีเจอร์ที่ซับซ้อนขึ้น เช่น session management, OAuth2 flows หรือการผสานเข้ากับ OIDC crate เหล่านี้จะช่วยประหยัดเวลาและลดภาระการพัฒนาไปได้มาก
