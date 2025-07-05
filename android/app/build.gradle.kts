// android/app/build.gradle.kts

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // START: FlutterFire Configuration - Correct way to apply for Kotlin DSL
    id("com.google.gms.google-services") // This should be here for .kts files
    // END: FlutterFire Configuration
}

android {
    namespace = "com.example.screen_time_app" // Ensure this matches your Firebase project's package name
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
        applicationId = "com.example.screen_time_app" // Ensure this matches your Firebase project's package name
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Add Firebase dependencies here if they are not already in your project-level build.gradle
    // For example:
    implementation(platform("com.google.firebase:firebase-bom:32.7.0")) // Use the latest BOM version
    implementation("com.google.firebase:firebase-auth-ktx")
    implementation("com.google.firebase:firebase-firestore-ktx")
    // ... other dependencies
}

// IMPORTANT: The 'apply plugin' line is removed from here for .kts files.
// The plugin is applied correctly within the 'plugins { ... }' block above.
