plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

import java.util.Properties
import java.io.FileInputStream
import org.gradle.api.GradleException

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

val hasKeystore = keystoreProperties.isNotEmpty() &&
    keystoreProperties.getProperty("storeFile") != null

android {
    namespace = "app.nookph"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    signingConfigs {
        if (hasKeystore) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = file(keystoreProperties.getProperty("storeFile")!!)
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    defaultConfig {
        applicationId = "app.nookph"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            if (hasKeystore) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
}

// Only fail when a release build is actually requested. This runs after the
// task graph is computed, so debug builds (assembleDebug / flutter run) are
// unaffected even when key.properties is absent.
if (!hasKeystore) {
    gradle.taskGraph.whenReady {
        val buildingRelease = allTasks.any { task ->
            task.name.contains("Release") &&
                (task.name.startsWith("assemble") ||
                    task.name.startsWith("bundle") ||
                    task.name.startsWith("package"))
        }
        if (buildingRelease) {
            throw GradleException(
                "Release build requested but android/key.properties is missing or invalid. " +
                    "Create it (see README) or build a debug variant."
            )
        }
    }
}

flutter {
    source = "../.."
}