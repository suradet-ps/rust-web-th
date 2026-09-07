# การตั้งค่า

ผมเคยเห็นบั๊กเรื่องการตั้งค่ามามากพอที่จะใช้ได้ทั้งชีวิต URL ฐานข้อมูลที่ทำงานบนแล็ปท็อปของคุณแต่ไม่ทำงานใน staging JWT secret ที่หลุดเข้าไปใน git commit ตัวแปรสภาพแวดล้อมที่หายไป แต่คุณเพิ่งรู้ตัวสิบนาทีหลังการดีพลอยต์เมื่อคำขอแรกพุ่งชนซอร์สโค้ดเส้นทางที่ต้องใช้มัน ทั้งหมดนี้หลีกเลี่ยงได้ และกลยุทธ์ที่เราจะใช้ตรงนี้ป้องกันทุกกรณีได้ทั้งหมด

แนวคิดตรงไปตรงมา: ดึงการตั้งค่าจากสภาพแวดล้อม ตรวจสอบความถูกต้องอย่างกระตือรือร้นตอนเริ่มระบบ และเก็บค่าที่อ่อนไหวให้ได้รับการปกป้องในหน่วยความจำ มาดูกันว่ามันทำงานอย่างไรในทางปฏิบัติ

## struct การตั้งค่าแบบกำหนดชนิดชัดเจน

เราเริ่มจาก struct ของ Rust ที่แทนการตั้งค่าทั้งหมดที่แอปพลิเคชันของเราต้องการ นี่เป็นหนึ่งในจุดที่ระบบชนิดข้อมูลของ Rust เข้ากันโดยธรรมชาติ: คุณได้รับการรับประกันตอนคอมไพล์ว่ามีฟิลด์ใดบ้างและชนิดข้อมูลของมันคืออะไร และคุณสามารถตรวจสอบความถูกต้องของค่าเมื่อสร้าง struct แทนการหวังว่ามันถูกต้องเมื่อบางสิ่งในที่สุดพยายามใช้มัน

```rust
use secrecy::{SecretString, ExposeSecret};
use serde::Deserialize;

#[derive(Debug, Clone, Deserialize)]
pub struct Config {
    #[serde(default = "default_port")]
    pub port: u16,

    #[serde(default = "default_environment")]
    pub environment: Environment,

    pub database_url: SecretString,

    pub jwt_secret: SecretString,

    #[serde(default = "default_log_level")]
    pub log_level: String,

    #[serde(default)]
    pub cors_origins: Vec<String>,
}

#[derive(Debug, Deserialize, Clone, PartialEq)]
#[serde(rename_all = "lowercase")]
pub enum Environment {
    Development,
    Staging,
    Production,
}

fn default_port() -> u16 { 3000 }
fn default_environment() -> Environment { Environment::Development }
fn default_log_level() -> String { "info".to_string() }
```

มีการตัดสินใจอย่างจงใจไม่กี่อย่างตรงนี้ที่คุ้มค่าจะเดินดู

สังเกตว่า `database_url` และ `jwt_secret` ใช้ `SecretString` จากครีต `secrecy` แทน `String` ธรรมดา สิ่งนี้ทำสองอย่างให้เรา: ค่าต่างๆ ถูกปกปิด (redact) โดยอัตโนมัติเมื่อคุณพิมพ์ struct ด้วย `Debug` (คุณจะเห็น `[REDACTED]` แทนความลับจริง) และหน่วยความจำถูกทำให้เป็นศูนย์เมื่อค่าถูก drop ผมเคยเห็นความลับใน production หลุดเข้าไปในไฟล์ล็อกบ่อยเกินกว่าที่อยากยอมรับ ดังนั้นการปกป้องแบบนี้มีประโยชน์มากจริงๆ

enum `Environment` เป็นชนิดข้อมูลที่แท้จริงแทนที่จะเป็นสตริง คุณสามารถ match กับมันแบบครบถ้วน (exhaustively) และคอมไพเลอร์จะบอกคุณถ้าคุณลืมจัดการกับวาเรียนต์หนึ่ง มันยังจับการพิมพ์ผิดอย่าง "prodduction" ตอน parse แทนที่จะปล่อยให้มันผ่านไปอย่างเงียบๆ

เราให้ค่าเริ่มต้นสำหรับฟิลด์ที่มีค่าเริ่มต้นที่สมเหตุสมผล ด้วยวิธีนั้นคุณสามารถเริ่มแอปพลิเคชันด้วยการตั้งค่าน้อยที่สุดระหว่างการพัฒนา ในขณะที่ยังต้องระบุค่าอย่างชัดเจนสำหรับสิ่งที่เช่นข้อมูลประจำตัวของฐานข้อมูล (credentials)

## การโหลดจากตัวแปรสภาพแวดล้อม

ครีต `config` ให้ระบบที่ยืดหยุ่นสำหรับโหลดการตั้งค่าจากหลายแหล่งและผสานมันเข้าด้วยกัน สำหรับแอปพลิเคชันส่วนใหญ่ การโหลดจากตัวแปรสภาพแวดล้อมก็เพียงพอแล้ว:

```rust
impl Config {
    pub fn from_env() -> anyhow::Result<Self> {
        // In development, load from a .env file if present.
        // The .ok() is intentional: in production there is no .env file,
        // and that is fine.
        dotenvy::dotenv().ok();

        let config = config::Config::builder()
            .add_source(
                config::Environment::default()
                    .separator("__")
            )
            .build()
            .context("failed to build configuration")?;

        let parsed: Config = config
            .try_deserialize()
            .context("failed to deserialize configuration")?;

        parsed.validate()?;

        Ok(parsed)
    }

    fn validate(&self) -> anyhow::Result<()> {
        if self.jwt_secret.expose_secret().len() < 48 {
            anyhow::bail!(
                "JWT_SECRET must be at least 48 characters for adequate security"
            );
        }
        Ok(())
    }
}
```

ตัวคั่น `__` หมายความว่าคุณสามารถตั้งค่าการตั้งค่าแบบซ้อนได้ด้วยสัญกรณ์ double-underscore ในตัวแปรสภาพแวดล้อม ดังนั้นถ้าคุณมีฟิลด์ `database.max_connections` แบบซ้อน คุณจะตั้งมันด้วย `DATABASE__MAX_CONNECTIONS`

เมธอด `validate` รันการตรวจสอบที่เราไม่สามารถแสดงผ่านชนิดข้อมูลเพียงอย่างเดียวได้ ตรงนี้มันทำให้แน่ใจว่า JWT secret ยาวพอที่จะต้านทานการโจมตีแบบ brute-force ถ้าการตรวจสอบล้มเหลว แอปพลิเคชันจะออกทันทีพร้อมข้อความข้อผิดพลาดที่ชัดเจน นั่นดีกว่าการเริ่มระบบได้อย่างราบรื่นแล้วก็พังเมื่อมีคนพยายามยืนยันตัวตนและโค้ดค้นพบว่ามันมี JWT secret ยาวสามตัวอักษร

## ไฟล์ .env สำหรับการพัฒนา

ระหว่างการพัฒนาในเครื่อง การเก็บการตั้งค่าในไฟล์ `.env` สะดวกดี เพราะคุณไม่ต้อง export ตัวแปรสภาพแวดล้อมด้วยมือทุกครั้งที่เริ่มแอปพลิเคชัน:

```
DATABASE_URL=postgres://localhost:5432/myapp_dev
JWT_SECRET=this-is-a-local-dev-secret-that-is-long-enough-for-validation
LOG_LEVEL=debug
ENVIRONMENT=development
```

ไฟล์นี้ต้องอยู่ใน `.gitignore` ของคุณ อย่า commit มันเข้าสู่ระบบควบคุมเวอร์ชัน แม้ว่ามันจะมีแค่ความลับสำหรับการพัฒนา จากประสบการณ์ของผม นิสัยการ commit ไฟล์ `.env` มักนำไปสู่การที่ใครสักคนดันความลับของ production ขึ้นไปโดยไม่ได้ตั้งใจในที่สุด ให้เตรียมไฟล์ `.env.example` ที่เอกสารว่าคาดหวังตัวแปรใดบ้าง:

```
# Copy this file to .env and fill in the values
DATABASE_URL=postgres://localhost:5432/myapp_dev
JWT_SECRET=<generate a random string of at least 48 characters>
LOG_LEVEL=info
ENVIRONMENT=development
```

## การใช้ความลับอย่างปลอดภัย

ครีต `secrecy` เล็ก แต่รับน้ำหนักได้เยอะ เมื่อคุณห่อค่าใน `SecretString` คุณจะได้รับการปกป้องสามอย่าง:

1. **การปกปิดใน Debug** โค้ดใดก็ตามที่พิมพ์ struct การตั้งค่า ไม่ว่าจะตั้งใจหรือโดยบังเอิญ จะเห็น `[REDACTED]` แทนความลับจริง เรื่องนี้สำคัญกว่าที่คุณคิด การบันทึกข้อมูลแบบมีโครงสร้างและการรายงานข้อผิดพลาดสามารถซีเรียลไลซ์ทั้งการตั้งค่าได้ง่ายๆ ถ้าคุณไม่ระวัง

2. **การทำให้หน่วยความจำเป็นศูนย์อย่างปลอดภัย** เมื่อ `SecretString` ถูก drop หน่วยความจำของมันจะถูกเขียนทับด้วยศูนย์ก่อนถูกจัดสรรคืน สิ่งนี้ทำให้ช่วงเวลาที่ความลับนอนอยู่ใน memory dump แคบลง

3. **การเปิดเผยอย่างจงใจ** เพื่อใช้ค่าความลับจริงๆ คุณต้องเรียก `.expose_secret()` ซึ่งคืนการอ้างอิงถึงสตริงด้านใน สิ่งนี้ทำให้การเข้าถึงความลับทุกครั้งชัดเจนและค้นหาได้ง่ายด้วย grep ระหว่างการรีวิวโค้ด

```rust
// When you need to use the secret, you explicitly expose it.
// Keep the exposed value's lifetime as short as possible.
let decoding_key = DecodingKey::from_secret(
    config.jwt_secret.expose_secret().as_bytes()
);
```

หลักสังเขป: เรียก `expose_secret()` ณ จุดที่ใช้งาน ไม่ใช่ก่อนหน้านั้น อย่าเก็บค่าที่ถูกเปิดเผยในตัวแปรที่ค้างอยู่นานเกินจำเป็น และอย่าล็อกมันเด็ดขาด

## การดีพลอยต์ใน production

ใน production การตั้งค่าของคุณควรมาจากระบบจัดการความลับของแพลตฟอร์มดีพลอยต์ ไม่ใช่จากไฟล์ ซึ่งอาจเป็น:

- ความลับของ Kubernetes ที่ mount เป็นตัวแปรสภาพแวดล้อม
- บล็อกสภาพแวดล้อมของ Docker ในไฟล์ compose หรือคอนฟิก orchestrator ของคุณ
- ตัวจัดการความลับของผู้ให้บริการคลาวด์ (AWS Secrets Manager, GCP Secret Manager, ฯลฯ)

สิ่งที่ดีเกี่ยวกับแนวทางของเราคือโค้ดแอปพลิเคชันไม่ต้องเปลี่ยนระหว่างสภาพแวดล้อม มันอ่านจากตัวแปรสภาพแวดล้อมเสมอ ข้อแตกต่างเพียงอย่างเดียวคือตัวแปรเหล่านั้นถูกตั้งอย่างไร: ไฟล์ `.env` ในการพัฒนา และความลับที่จัดการโดยแพลตฟอร์มใน production

## ล้มเหลวเร็ว (Fail fast)

ถ้ามีกฎหนึ่งข้อที่ผมจะตอกย้ำกับทุกทีม มันคือข้อนี้: ล้มเหลวทันทีและดังๆ ตอนเริ่มระบบถ้าการตั้งค่าที่จำเป็นหายไปหรือไม่ถูกต้อง การพังตอนเริ่มระบบพร้อมข้อความข้อผิดพลาดที่ชัดเจน ("JWT_SECRET environment variable is not set") ดีกว่าการพังสิบนาทีต่อมาเมื่อคำขอยืนยันตัวตนครั้งแรกเข้ามาและคุณค้นพบว่าไม่มี JWT secret

นี่คือเหตุผลที่ฟังก์ชัน `Config::from_env()` ของเราทำ deserialize และตรวจสอบความถูกต้องอย่างกระตือรือร้น เมื่อแอปพลิเคชันเริ่มรับคำขอ เรารู้แล้วว่าการตั้งค่าทั้งหมดมีอยู่ ถูกชนิดข้อมูล และผ่านการตรวจสอบ ไม่มีบั๊กการตั้งค่าที่แฝงอยู่รอทำให้คุณประหลาดใจตอนตีสองวันเสาร์ ด้วยรากฐานนั้นพร้อมแล้ว มาดูกันว่าเราจัดการข้อผิดพลาดข้ามส่วนที่เหลือของแอปพลิเคชันอย่างไร
