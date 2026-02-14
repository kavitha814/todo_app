plugins {
    id("com.android.application")
    id("kotlin-android")
    // Flutter Gradle Plugin (must be after Android & Kotlin)
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.company.todo"

    // 🔥 FIX FOR lStar ERROR
    compileSdk = 35
    ndkVersion = flutter.ndkVersion

    defaultConfig {
        applicationId = "com.company.todo"
        minSdk = flutter.minSdkVersion
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    buildTypes {
        getByName("release") {
            // Debug signing (NO passwords, NO keystore)
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")

    // Firebase BOM
    implementation(platform("com.google.firebase:firebase-bom:34.7.0"))

    // Firebase Analytics
    implementation("com.google.firebase:firebase-analytics")
}
