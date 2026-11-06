import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // إضافة إضافة Kotlin المفقودة
    id("org.jetbrains.kotlin.android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.fattball.syria"
    
    // ✅ تم التعديل: تثبيت إصدار SDK على 36 لحل مشكلة التوافق
    compileSdk = 36 
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.fattball.syria"
        minSdk = flutter.minSdkVersion
        
        // ✅ تم التعديل: تثبيت إصدار target SDK على 36
        targetSdk = 36 
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // 1. قراءة إعدادات التوقيع من ملف key.properties
    val keystoreProperties = Properties()
    val keystorePropertiesFile = rootProject.file("key.properties")
    if (keystorePropertiesFile.exists()) {
        keystoreProperties.load(FileInputStream(keystorePropertiesFile))
    }

    // 2. تعريف توقيع الـ Release
    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = keystoreProperties["storeFile"]?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }

    // 3. استخدام توقيع الـ Release بدلاً من الـ Debug
    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

kotlin {
    compilerOptions {
        // استخدام set() لتعيين القيمة بشكل صحيح في Kotlin DSL
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
    }
}

flutter {
    source = "../.."
}