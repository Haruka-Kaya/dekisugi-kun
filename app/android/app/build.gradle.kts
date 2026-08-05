import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// 署名の設定は android/key.properties から読む。
// **このファイルも鍵本体も追跡しない**（どちらも .gitignore 済み）。
//
// 鍵を失うと、既存の利用者はもう更新を受け取れない。
// Play App Signing に登録していても、アップロード鍵を失えば
// 再登録の手続きが要る。**別媒体に退避すること。**
val keyProperties = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}
val hasReleaseKey = keyProperties.getProperty("storeFile") != null

android {
    namespace = "jp.dekisugi.dekisugi"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "jp.dekisugi.dekisugi"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKey) {
            create("release") {
                storeFile = file(keyProperties.getProperty("storeFile"))
                storePassword = keyProperties.getProperty("storePassword")
                keyAlias = keyProperties.getProperty("keyAlias")
                keyPassword = keyProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // 鍵が無い環境（CI・他人のクローン）では debug 署名のまま通す。
            // **配布前に必ず署名者を確かめること** —
            // CN=Android Debug のまま出すと Play に弾かれるか、
            // 弾かれなかった場合はもっと悪い（更新できない鍵で公開してしまう）。
            //   apksigner verify --print-certs <apk>
            signingConfig = if (hasReleaseKey) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}
