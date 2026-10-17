plugins {
    id("com.android.application")
    id("kotlin-android")
    // Must run after the Android plugin: it reads google-services.json and
    // generates the resource the Firebase SDK (and Google Sign-In) reads.
    id("com.google.gms.google-services")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
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
    }

    buildTypes {
        release {
            // Debug key on purpose for now: keeps `flutter build apk --release`
            // working without shipping a real key. The release keystore comes
            // from a CI secret (see constitution.md).
            signingConfig = signingConfigs.getByName("debug")
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
