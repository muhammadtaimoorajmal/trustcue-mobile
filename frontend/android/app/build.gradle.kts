import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "io.github.muhammadtaimoorajmal.trustcue"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "30.0.16138531"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "io.github.muhammadtaimoorajmal.trustcue"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties.getProperty("keyAlias") ?: ""
                keyPassword = keystoreProperties.getProperty("keyPassword") ?: ""
                val storeFilePath = keystoreProperties.getProperty("storeFile") ?: ""
                val rootStoreFile = rootProject.file(storeFilePath)
                val appStoreFile = file(storeFilePath)
                storeFile = if (rootStoreFile.exists()) {
                    rootStoreFile.absoluteFile
                } else if (appStoreFile.exists()) {
                    appStoreFile.absoluteFile
                } else {
                    rootStoreFile.absoluteFile
                }
                storePassword = keystoreProperties.getProperty("storePassword") ?: ""
            }
        }
    }

    buildTypes {
        release {
            if (keystorePropertiesFile.exists()) {
                signingConfig = signingConfigs.getByName("release")
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

gradle.taskGraph.whenReady {
    val isReleaseBuild = allTasks.any { task ->
        val name = task.name.lowercase()
        (name.contains("release") && !name.contains("test"))
    }
    if (isReleaseBuild && !keystorePropertiesFile.exists()) {
        throw GradleException(
            "Release signing configuration is missing. " +
            "Please create android/key.properties with storeFile, storePassword, keyAlias, and keyPassword to build release artifacts."
        )
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
