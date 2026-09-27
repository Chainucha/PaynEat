import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Upload key สำหรับ release ที่ขึ้น Google Play (ticket 29a, docs/store/README.md) — ไม่อยู่ใน repo เด็ดขาด
// CI ส่งมาทาง environment จาก GitHub Secrets ส่วนเครื่องนักพัฒนาใช้ android/key.properties (อยู่ใน .gitignore)
// ถ้าไม่มีทั้งสองทาง release ยังลงนามด้วย debug key ให้ `flutter run --release` ใช้ได้ — แต่เมื่อ
// PAYNEAT_REQUIRE_UPLOAD_KEY=true (job ที่ build ขึ้น store) จะหยุด build แทน ไม่มีทางได้ไฟล์ debug ขึ้น store
val keyProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}
fun uploadKey(env: String, property: String): String? =
    System.getenv(env)?.takeIf { it.isNotBlank() } ?: keyProperties.getProperty(property)

val uploadStoreFile = uploadKey("PAYNEAT_UPLOAD_STORE_FILE", "storeFile")
val uploadStorePassword = uploadKey("PAYNEAT_UPLOAD_STORE_PASSWORD", "storePassword")
val uploadKeyAlias = uploadKey("PAYNEAT_UPLOAD_KEY_ALIAS", "keyAlias")
val uploadKeyPassword = uploadKey("PAYNEAT_UPLOAD_KEY_PASSWORD", "keyPassword")
val hasUploadKey = listOf(uploadStoreFile, uploadStorePassword, uploadKeyAlias, uploadKeyPassword)
    .all { !it.isNullOrBlank() }
if (!hasUploadKey && System.getenv("PAYNEAT_REQUIRE_UPLOAD_KEY") == "true") {
    throw GradleException(
        "PAYNEAT_REQUIRE_UPLOAD_KEY=true แต่ไม่มี upload key ครบ (PAYNEAT_UPLOAD_STORE_FILE, " +
            "PAYNEAT_UPLOAD_STORE_PASSWORD, PAYNEAT_UPLOAD_KEY_ALIAS, PAYNEAT_UPLOAD_KEY_PASSWORD) " +
            "— ดู docs/store/README.md",
    )
}

android {
    namespace = "com.payneat.payneat_pos"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // ห้ามเปลี่ยนหลังอัปโหลดขึ้น Google Play ครั้งแรก: Play ผูกแอปกับ applicationId ตลอดไป
        // (docs/store/README.md, DECISIONS #75, #78) — namespace ด้านบนเป็นแค่ package ของโค้ด Kotlin ไม่ต้องตรงกัน
        applicationId = "suruch.boss.payneat"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasUploadKey) {
            create("upload") {
                storeFile = file(uploadStoreFile!!)
                storePassword = uploadStorePassword
                keyAlias = uploadKeyAlias
                keyPassword = uploadKeyPassword
            }
        }
    }

    buildTypes {
        release {
            // Play App Signing: ไฟล์ .aab ลงนามด้วย upload key แล้ว Google ลงนามใหม่ด้วย app signing key
            // ที่ Google เก็บเอง — ถ้า upload key หาย ขอเปลี่ยนได้โดยไม่เสียแอป
            signingConfig =
                if (hasUploadKey) signingConfigs.getByName("upload") else signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
