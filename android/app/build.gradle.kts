import java.util.Properties
import java.util.Base64
import java.net.URI

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val signingProperties = Properties()
val signingFile = rootProject.file("key.properties")
if (signingFile.exists()) signingFile.inputStream().use { signingProperties.load(it) }
gradle.taskGraph.whenReady {
    if (allTasks.any { it.name.contains("release", ignoreCase = true) }) {
        if (listOf("storeFile", "storePassword", "keyAlias", "keyPassword").any { signingProperties.getProperty(it).isNullOrBlank() }) {
            throw GradleException("Release signing requires android/key.properties; debug signing is never used for release.")
        }
        val defines = (project.findProperty("dart-defines") as? String).orEmpty().split(",")
            .filter { it.isNotBlank() }.map { String(Base64.getDecoder().decode(it)) }
        val api = defines.firstOrNull { it.startsWith("API_BASE_URL=") }?.substringAfter("=")
        val uri = api?.let { URI(it) }
        if (uri == null || uri.scheme != "https" || uri.host.isNullOrBlank() || uri.userInfo != null) {
            throw GradleException("Release requires --dart-define=API_BASE_URL=https://your-production-host")
        }
    }
}

android {
    namespace = "com.monetizer.app"
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
        applicationId = "com.monetizer.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (signingFile.exists()) {
                storeFile = rootProject.file(signingProperties.getProperty("storeFile"))
                storePassword = signingProperties.getProperty("storePassword")
                keyAlias = signingProperties.getProperty("keyAlias")
                keyPassword = signingProperties.getProperty("keyPassword")
            }
        }
    }
    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
    source = "../.."
}
