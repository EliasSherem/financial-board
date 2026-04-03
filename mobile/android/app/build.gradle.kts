plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // Google Services plugin required for Firebase
    id("com.google.gms.google-services")
}

import java.util.Properties
import java.io.FileInputStream

// Load signing credentials from android/key.properties (do not commit real secrets)
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.example.mobile"
    compileSdk = flutter.compileSdkVersion
    // Highest installed NDK (some plugins require 27)
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        // Required by flutter_local_notifications and other libs using java.time, streams, etc.
        isCoreLibraryDesugaringEnabled = true
    }
    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: change to your final app id before publishing
        applicationId = "com.finsight.finsight"
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        // Bump versionCode for Play uploads (was flutter.versionCode)
        versionCode = 38
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            val store = keystoreProperties.getProperty("storeFile")
            if (!store.isNullOrEmpty()) storeFile = file(store)
            storePassword = keystoreProperties.getProperty("storePassword") ?: ""
            keyAlias = keystoreProperties.getProperty("keyAlias") ?: ""
            keyPassword = keystoreProperties.getProperty("keyPassword") ?: ""
        }
    }

    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("release")

            // Keep simple for first upload; enable later if needed
            isMinifyEnabled = false
            isShrinkResources = false
            // proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Core library desugaring for Java 8+ APIs on lower Android API levels
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
