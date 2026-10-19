import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // Must run after the Android plugin: it reads google-services.json and
    // generates the resource the Firebase SDK (and Google Sign-In) reads.
    id("com.google.gms.google-services")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// A chave de release não mora no repo (é secret do CI). Este arquivo é
// gitignored; o job do APK o reconstrói antes de buildar. Sem ele o release
// não tem como assinar e falha de propósito — para não assinar com a chave
// de debug, que agora é pública no repo.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "br.com.appseries.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    defaultConfig {
        applicationId = "br.com.appseries.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // One debug key for the whole team, versioned on purpose: Google Sign-In only
    // accepts an app signed by a key whose SHA-1 is registered in Firebase, and
    // every machine generates its own ~/.android/debug.keystore. Without this file
    // each teammate would have to register their own SHA-1 (or face `ApiException: 10`).
    // Password and alias are the Android debug defaults, not a secret.
    signingConfigs {
        getByName("debug") {
            storeFile = file("debug.keystore")
            storePassword = "android"
            keyAlias = "androiddebugkey"
            keyPassword = "android"
        }
        create("release") {
            // Lê de key.properties. Sem o arquivo os campos ficam nulos e o
            // AGP recusa assinar o release ("Keystore file not set").
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = keystoreProperties["storeFile"]?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

kotlin {
    compilerOptions {
        // jvmTarget lives in the new compilerOptions DSL: with Kotlin 2.3 the old
        // `kotlinOptions { jvmTarget = "11" }` is a script compilation error.
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11)
    }
}

flutter {
    source = "../.."
}
