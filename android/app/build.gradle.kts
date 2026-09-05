plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.thingstoremember"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.thingstoremember"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        getByName("release") { signingConfig = signingConfigs.getByName("debug") }
    }

    packaging {
        jniLibs {
            // LiteRT-LM bundles the same LiteRT runtime used by the numeric
            // CompiledModel integration. Keep one shared runtime per ABI.
            pickFirsts += "lib/arm64-v8a/libLiteRt.so"
            pickFirsts += "lib/armeabi-v7a/libLiteRt.so"
            pickFirsts += "lib/x86/libLiteRt.so"
            pickFirsts += "lib/x86_64/libLiteRt.so"
            pickFirsts += "lib/arm64-v8a/libLiteRtClGlAccelerator.so"
            pickFirsts += "lib/x86_64/libLiteRtClGlAccelerator.so"
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
    }
}

flutter { source = "../.." }

dependencies {
    // LiteRT v2.2.0 Kotlin CompiledModel API. All inference has a CPU fallback.
    implementation("com.google.ai.edge.litert:litert:2.2.0")
    // LiteRT-LM 0.13.1 runs the local Qwen3 .litertlm artifact on Android.
    implementation("com.google.ai.edge.litertlm:litertlm-android:0.13.1")
}
