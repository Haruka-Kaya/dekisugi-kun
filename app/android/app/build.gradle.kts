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
val keyPropertiesFile = providers.gradleProperty("dekisugiReleaseKeyProperties")
    .orNull
    ?.let { file(it) }
    ?: rootProject.file("key.properties")
val keyProperties = Properties().apply {
    if (keyPropertiesFile.isFile) {
        keyPropertiesFile.inputStream().use { load(it) }
    }
}
val requiredReleaseKeyProperties = listOf(
    "storeFile",
    "storePassword",
    "keyAlias",
    "keyPassword",
)
val missingReleaseKeyProperties = requiredReleaseKeyProperties.filter {
    keyProperties.getProperty(it).isNullOrBlank()
}
val releaseStoreFile = keyProperties.getProperty("storeFile")
    ?.takeIf { it.isNotBlank() }
    ?.let { file(it) }
val releaseSigningFailure = when {
    !keyPropertiesFile.isFile ->
        "Android release署名設定がありません。" +
            "android/key.propertiesを用意するか、" +
            "-PdekisugiReleaseKeyProperties=<path>を指定してください。"
    missingReleaseKeyProperties.isNotEmpty() ->
        "Android release署名設定が不足しています: " +
            missingReleaseKeyProperties.joinToString(", ")
    releaseStoreFile?.isFile != true ->
        "Android release署名鍵のstoreFileが存在しません。"
    else -> null
}
val hasReleaseSigning = releaseSigningFailure == null

android {
    namespace = "jp.dekisugi.dekisugi"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // flutter_local_notifications が要求する。
        // **無いと release ビルドだけが落ちる**（debug は通ってしまう）
        isCoreLibraryDesugaringEnabled = true
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
        if (hasReleaseSigning) {
            create("release") {
                storeFile = releaseStoreFile
                storePassword = keyProperties.getProperty("storePassword")
                keyAlias = keyProperties.getProperty("keyAlias")
                keyPassword = keyProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // releaseをdebug鍵へfallbackさせない。鍵が無いclean CIでは
            // debug APKだけを作り、release要求は下のtask graph guardで明示失敗する。
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                null
            }
        }
    }
}

// configuration自体はdebug CIでも通す一方、配布artifactを作るtaskだけは
// key.properties・全4項目・実在keystoreのどれかが欠ければ開始前に止める。
val appProjectPath = project.path
gradle.taskGraph.whenReady {
    val releaseArtifactRequested = allTasks.any { task ->
        task.project.path == appProjectPath &&
            (task.name == "assembleRelease" ||
                task.name == "bundleRelease" ||
                task.name.startsWith("packageRelease"))
    }
    if (releaseArtifactRequested && releaseSigningFailure != null) {
        throw GradleException(releaseSigningFailure)
    }
}

flutter {
    source = "../.."
}

dependencies {
    // 上の isCoreLibraryDesugaringEnabled とセット。
    // 片方だけだとビルドが通らない
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}
