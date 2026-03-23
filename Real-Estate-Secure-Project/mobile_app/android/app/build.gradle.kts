import java.io.File
import java.util.Properties

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    // The Flutter Gradle Plugin must be applied after the Android Gradle plugin.
    id("dev.flutter.flutter-gradle-plugin")
}

fun loadMobileEnv(file: File): Map<String, String> {
    if (!file.exists()) {
        return emptyMap()
    }

    return buildMap {
        file.forEachLine { rawLine ->
            val line = rawLine.trim()
            if (line.isEmpty() || line.startsWith("#")) {
                return@forEachLine
            }
            val separator = line.indexOf('=')
            if (separator <= 0) {
                return@forEachLine
            }
            val key = line.substring(0, separator).trim()
            if (key.isEmpty()) {
                return@forEachLine
            }
            val value = line.substring(separator + 1).trim().removeSurrounding("\"")
            put(key, value)
        }
    }
}

fun normalizeConsumerApiBaseUrl(raw: String?): String {
    val value = raw?.trim()?.trimEnd('/') ?: ""
    if (value.isEmpty()) {
        return ""
    }
    return if (value.endsWith("/v1")) value else "$value/v1"
}

fun resolveAndroidSdkDir(androidRootDir: File): String? {
    val localPropertiesFile = File(androidRootDir, "local.properties")
    if (localPropertiesFile.exists()) {
        val properties = Properties()
        localPropertiesFile.inputStream().use(properties::load)
        properties.getProperty("sdk.dir")
            ?.trim()
            ?.takeIf { it.isNotEmpty() }
            ?.let { return it }
    }

    return sequenceOf(
        System.getenv("ANDROID_SDK_ROOT"),
        System.getenv("ANDROID_HOME"),
    )
        .mapNotNull { it?.trim() }
        .firstOrNull { it.isNotEmpty() }
}

fun resolveAdbExecutable(androidRootDir: File): File? {
    val sdkDir = resolveAndroidSdkDir(androidRootDir) ?: return null
    val executableName = if (System.getProperty("os.name").startsWith("Windows")) {
        "adb.exe"
    } else {
        "adb"
    }
    val adbFile = File(File(sdkDir, "platform-tools"), executableName)
    return adbFile.takeIf(File::exists)
}

val mobileRootDir = rootProject.projectDir.parentFile
val mobileEnv = loadMobileEnv(File(mobileRootDir, ".env"))
val googleMapsApiKey = providers.gradleProperty("GOOGLE_MAPS_API_KEY").orNull
    ?: System.getenv("GOOGLE_MAPS_API_KEY")
    ?: mobileEnv["GOOGLE_MAPS_API_KEY"]
    ?: ""
val admobAndroidAppId = providers.gradleProperty("ADMOB_ANDROID_APP_ID").orNull
    ?: System.getenv("ADMOB_ANDROID_APP_ID")
    ?: mobileEnv["ADMOB_ANDROID_APP_ID"]
    ?: "ca-app-pub-3940256099942544~3347511713"
val explicitConsumerApiBaseUrl = normalizeConsumerApiBaseUrl(
    providers.gradleProperty("RES_API_BASE_URL").orNull
        ?: System.getenv("RES_API_BASE_URL")
        ?: mobileEnv["RES_API_BASE_URL"],
)
val consumerApiBaseUrl = explicitConsumerApiBaseUrl
val adbExecutable = resolveAdbExecutable(rootProject.projectDir)

android {
    namespace = "com.example.real_estate_secure"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.real_estate_secure"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = maxOf(flutter.minSdkVersion, 24)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["googleMapsApiKey"] = googleMapsApiKey
        manifestPlaceholders["admobAndroidAppId"] = admobAndroidAppId
        manifestPlaceholders["consumerApiBaseUrl"] = consumerApiBaseUrl
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    implementation("androidx.biometric:biometric:1.2.0-alpha05")
}

flutter {
    source = "../.."
}

val ensureDebugAdbReverse by tasks.registering {
    group = "development"
    description = "Ensures the debug backend is reachable from a USB-connected Android device."

    doLast {
        val adb = adbExecutable
        if (adb == null) {
            println("Skipping adb reverse: adb executable was not found.")
            return@doLast
        }

        val serial = System.getenv("ANDROID_SERIAL")?.trim().orEmpty()
        val command = mutableListOf(adb.absolutePath)
        if (serial.isNotEmpty()) {
            command += listOf("-s", serial)
        }
        command += listOf("reverse", "tcp:8080", "tcp:8080")

        exec {
            commandLine(command)
            isIgnoreExitValue = true
        }
    }
}

tasks.matching { it.name == "preDebugBuild" }.configureEach {
    dependsOn(ensureDebugAdbReverse)
}
