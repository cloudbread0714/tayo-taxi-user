plugins {
    id("com.android.application")
    id("com.google.gms.google-services") // Firebase 연동
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin") // Flutter Gradle Plugin
}

dependencies {
    // Firebase BoM
    implementation(platform("com.google.firebase:firebase-bom:33.12.0"))

    // Firebase 제품
    implementation("com.google.firebase:firebase-analytics")

    // ✅ Google Maps & Places API 연동
    implementation("com.google.android.libraries.maps:maps:3.1.0-beta")
    implementation("com.google.android.libraries.places:places:3.3.0")
}

android {
    namespace = "com.example.app_tayo_taxi"

    // ✅ Android SDK 36으로 명시 설정
    compileSdk = 36
    ndkVersion = "27.0.12077973"

    // ✅ Java 11 호환성 설정
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.example.app_tayo_taxi"
        minSdk = 23
        targetSdk = 36 // ✅ 필수: flutter_naver_map 요구사항
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug") // 필요시 release용 서명 변경 가능
        }
    }
}

flutter {
    source = "../.."
}