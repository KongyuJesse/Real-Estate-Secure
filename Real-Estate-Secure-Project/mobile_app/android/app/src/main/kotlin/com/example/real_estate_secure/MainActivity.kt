package com.example.real_estate_secure

import android.app.KeyguardManager
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.android.RenderMode
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val deepLinkMethodChannel = "real_estate_secure/deep_links"
    private val deepLinkEventChannel = "real_estate_secure/deep_links/events"
    private val securityMethodChannel = "real_estate_secure/security"
    private val runtimeConfigMethodChannel = "real_estate_secure/runtime_config"

    private var eventSink: EventChannel.EventSink? = null
    private var pendingLink: String? = null
    private var pendingBiometricResult: MethodChannel.Result? = null
    private var biometricPrompt: BiometricPrompt? = null

    override fun getRenderMode(): RenderMode = RenderMode.texture

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, deepLinkMethodChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getInitialLink" -> result.success(resolveDeepLink(intent))
                    else -> result.notImplemented()
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, deepLinkEventChannel)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    eventSink = events
                    pendingLink?.let(events::success)
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            })

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, securityMethodChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getBiometricStatus" -> result.success(resolveBiometricStatus())
                    "authenticateBiometric" -> authenticateBiometric(
                        reason = call.argument<String>("reason") ?: "Confirm your identity",
                        title = call.argument<String>("title") ?: "Real Estate Secure",
                        subtitle = call.argument<String>("subtitle")
                            ?: "Use your biometric or device lock to continue",
                        negativeButton = call.argument<String>("negativeButton") ?: "Cancel",
                        result = result,
                    )
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, runtimeConfigMethodChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getDefaultApiBaseUrl" -> result.success(resolveDefaultApiBaseUrl())
                    else -> result.notImplemented()
                }
            }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        emitDeepLink(intent)
    }

    override fun onDestroy() {
        biometricPrompt?.cancelAuthentication()
        pendingBiometricResult = null
        super.onDestroy()
    }

    private fun emitDeepLink(intent: Intent?) {
        val link = resolveDeepLink(intent) ?: return
        pendingLink = link
        eventSink?.success(link)
    }

    private fun resolveDeepLink(intent: Intent?): String? {
        if (intent?.action != Intent.ACTION_VIEW) {
            return null
        }
        val data = intent.dataString?.trim()
        return if (data.isNullOrEmpty()) null else data
    }

    private fun resolveDefaultApiBaseUrl(): String {
        return try {
            val applicationInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                packageManager.getApplicationInfo(
                    packageName,
                    PackageManager.ApplicationInfoFlags.of(PackageManager.GET_META_DATA.toLong()),
                )
            } else {
                @Suppress("DEPRECATION")
                packageManager.getApplicationInfo(packageName, PackageManager.GET_META_DATA)
            }
            val configuredUrl = applicationInfo.metaData
                ?.getString("com.realestatesecure.consumer.API_BASE_URL")
                ?.trim()
                .orEmpty()
            if (configuredUrl.isNotEmpty()) {
                configuredUrl
            } else if (isProbablyEmulator()) {
                "http://10.0.2.2:8080/v1"
            } else {
                "http://127.0.0.1:8080/v1"
            }
        } catch (_: Exception) {
            if (isProbablyEmulator()) {
                "http://10.0.2.2:8080/v1"
            } else {
                "http://127.0.0.1:8080/v1"
            }
        }
    }

    private fun isProbablyEmulator(): Boolean {
        return Build.FINGERPRINT.startsWith("generic") ||
            Build.FINGERPRINT.startsWith("unknown") ||
            Build.MODEL.contains("google_sdk") ||
            Build.MODEL.contains("Emulator") ||
            Build.MODEL.contains("Android SDK built for x86") ||
            Build.MANUFACTURER.contains("Genymotion") ||
            Build.BRAND.startsWith("generic") && Build.DEVICE.startsWith("generic") ||
            "google_sdk" == Build.PRODUCT
    }

    private fun resolveBiometricStatus(): Map<String, Any> {
        val biometricManager = BiometricManager.from(this)
        val keyguardManager = getSystemService(KeyguardManager::class.java)
        val hasFingerprintFeature = packageManager.hasSystemFeature(PackageManager.FEATURE_FINGERPRINT)
        val authenticators = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            BiometricManager.Authenticators.BIOMETRIC_STRONG or
                BiometricManager.Authenticators.DEVICE_CREDENTIAL
        } else {
            BiometricManager.Authenticators.BIOMETRIC_WEAK
        }

        val biometricStatus = biometricManager.canAuthenticate(authenticators)
        val hasDeviceCredential = keyguardManager?.isDeviceSecure == true
        val isBiometricReady = biometricStatus == BiometricManager.BIOMETRIC_SUCCESS
        val isAvailable = isBiometricReady || hasDeviceCredential

        val type = when {
            isBiometricReady && hasFingerprintFeature -> "fingerprint"
            isBiometricReady -> "biometric"
            hasDeviceCredential -> "device_credential"
            biometricStatus == BiometricManager.BIOMETRIC_ERROR_NONE_ENROLLED &&
                hasFingerprintFeature -> "fingerprint_unenrolled"
            biometricStatus == BiometricManager.BIOMETRIC_ERROR_NONE_ENROLLED -> "unenrolled"
            biometricStatus == BiometricManager.BIOMETRIC_ERROR_NO_HARDWARE -> "unsupported"
            biometricStatus == BiometricManager.BIOMETRIC_ERROR_HW_UNAVAILABLE -> "unavailable"
            else -> "unavailable"
        }

        return mapOf(
            "isAvailable" to isAvailable,
            "isEnrolled" to (isBiometricReady || hasDeviceCredential),
            "type" to type,
            "platform" to "android",
        )
    }

    private fun authenticateBiometric(
        reason: String,
        title: String,
        subtitle: String,
        negativeButton: String,
        result: MethodChannel.Result,
    ) {
        val status = resolveBiometricStatus()
        if (status["isAvailable"] != true) {
            result.success(false)
            return
        }

        if (pendingBiometricResult != null) {
            result.error(
                "biometric_in_progress",
                "Biometric authentication is already in progress.",
                null,
            )
            return
        }

        pendingBiometricResult = result

        val prompt = BiometricPrompt(
            this,
            ContextCompat.getMainExecutor(this),
            object : BiometricPrompt.AuthenticationCallback() {
                override fun onAuthenticationSucceeded(
                    result: BiometricPrompt.AuthenticationResult,
                ) {
                    finishBiometricAuthentication(true)
                }

                override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                    when (errorCode) {
                        BiometricPrompt.ERROR_NEGATIVE_BUTTON,
                        BiometricPrompt.ERROR_USER_CANCELED,
                        BiometricPrompt.ERROR_CANCELED -> {
                            finishBiometricAuthentication(false)
                        }
                        else -> {
                            finishBiometricAuthenticationWithError(
                                code = "biometric_error",
                                message = errString.toString(),
                            )
                        }
                    }
                }

                override fun onAuthenticationFailed() {
                    // Keep the system prompt open so the user can retry immediately.
                }
            },
        )
        biometricPrompt = prompt

        val promptInfoBuilder = BiometricPrompt.PromptInfo.Builder()
            .setTitle(title)
            .setSubtitle(subtitle)
            .setDescription(reason)
            .setConfirmationRequired(false)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            promptInfoBuilder.setAllowedAuthenticators(
                BiometricManager.Authenticators.BIOMETRIC_STRONG or
                    BiometricManager.Authenticators.DEVICE_CREDENTIAL,
            )
        } else {
            val keyguardManager = getSystemService(KeyguardManager::class.java)
            if (keyguardManager?.isDeviceSecure == true) {
                promptInfoBuilder.setDeviceCredentialAllowed(true)
            } else {
                promptInfoBuilder.setNegativeButtonText(negativeButton)
            }
        }

        prompt.authenticate(promptInfoBuilder.build())
    }

    private fun finishBiometricAuthentication(success: Boolean) {
        pendingBiometricResult?.success(success)
        pendingBiometricResult = null
        biometricPrompt = null
    }

    private fun finishBiometricAuthenticationWithError(code: String, message: String) {
        pendingBiometricResult?.error(code, message, null)
        pendingBiometricResult = null
        biometricPrompt = null
    }
}
