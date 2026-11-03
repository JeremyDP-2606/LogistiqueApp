import java.util.Properties
import java.io.FileInputStream

// Load local.properties
val localProperties = Properties().apply {
    val localFile = rootProject.file("local.properties")
    if (localFile.exists()) {
        FileInputStream(localFile).use { load(it) }
    }
}

// Load key.properties
val keyProperties = Properties().apply {
    val keyFile = rootProject.file("key.properties")
    if (keyFile.exists()) {
        FileInputStream(keyFile).use { load(it) }
    }
}

val flutterRoot: String = localProperties["flutter.sdk"] as? String
    ?: throw GradleException("Flutter SDK not found. Define location with flutter.sdk in the local.properties file.")

val flutterVersionCode: Int = (localProperties["flutter.versionCode"] as? String)?.toIntOrNull() ?: 1
val flutterVersionName: String = localProperties["flutter.versionName"] as? String ?: "1.0"

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "fr.app.wabap"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    sourceSets["main"].java.srcDirs("src/main/kotlin")

    signingConfigs {
        create("release") {
            if (keyProperties.containsKey("storeFile")) {
                storeFile = file(keyProperties["storeFile"]!!)
                storePassword = keyProperties["storePassword"] as String
                keyAlias = keyProperties["keyAlias"] as String
                keyPassword = keyProperties["keyPassword"] as String
            }
        }
    }

    defaultConfig {
        applicationId = "fr.app.wabap"
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutterVersionCode
        versionName = flutterVersionName
        // Clé Google Maps : MAPS_API_KEY dans android/local.properties (non versionné) ou variable d'environnement
        manifestPlaceholders["MAPS_API_KEY"] =
            (localProperties["MAPS_API_KEY"] as? String) ?: System.getenv("MAPS_API_KEY") ?: ""
    }

    buildTypes {
        getByName("release") {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            signingConfig = if (keyProperties.containsKey("storeFile")) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
        getByName("debug") {
            isDebuggable = true
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}
