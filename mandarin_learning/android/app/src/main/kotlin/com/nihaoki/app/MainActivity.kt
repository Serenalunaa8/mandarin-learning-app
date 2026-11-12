package com.nihaoki.app

import android.content.Intent
import android.os.Build
import android.provider.Settings
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.nihaoki.app/biometric_settings",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "canAuthenticate" -> {
                    val bm = BiometricManager.from(this)
                    val authenticators = BiometricManager.Authenticators.BIOMETRIC_STRONG or
                            BiometricManager.Authenticators.BIOMETRIC_WEAK
                    result.success(bm.canAuthenticate(authenticators) == BiometricManager.BIOMETRIC_SUCCESS)
                }
                "hasFaceRecognition" -> {
                    val pm = packageManager
                    val hasFaceHardware = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                        pm.hasSystemFeature(android.content.pm.PackageManager.FEATURE_FACE) ||
                                pm.hasSystemFeature("android.hardware.biometrics.face") ||
                                pm.hasSystemFeature("com.samsung.android.bio.face") ||
                                pm.hasSystemFeature("oppo.hardware.biometrics.face") ||
                                pm.hasSystemFeature("org.lineageos.biometrics.face")
                    } else {
                        pm.hasSystemFeature("android.hardware.biometrics.face") ||
                                pm.hasSystemFeature("com.samsung.android.bio.face")
                    }

                    val bm = BiometricManager.from(this)
                    val weakCanAuth = bm.canAuthenticate(BiometricManager.Authenticators.BIOMETRIC_WEAK) == BiometricManager.BIOMETRIC_SUCCESS
                    val strongCanAuth = bm.canAuthenticate(BiometricManager.Authenticators.BIOMETRIC_STRONG) == BiometricManager.BIOMETRIC_SUCCESS

                    // Di Android, pengenalan wajah kamera 2D masuk kategori BIOMETRIC_WEAK (Class 2).
                    // Jika WEAK sukses atau perangkat punya fitur hardware face, deteksi aktif.
                    result.success(hasFaceHardware || (weakCanAuth && !strongCanAuth) || weakCanAuth)
                }
                "hasFingerprint" -> {
                    val pm = packageManager
                    val hasFingerHardware = pm.hasSystemFeature(android.content.pm.PackageManager.FEATURE_FINGERPRINT)
                    val bm = BiometricManager.from(this)
                    val strongCanAuth = bm.canAuthenticate(BiometricManager.Authenticators.BIOMETRIC_STRONG) == BiometricManager.BIOMETRIC_SUCCESS
                    result.success(hasFingerHardware || strongCanAuth)
                }
                "authenticate" -> authenticateBiometric(
                    call.argument<String>("reason") ?: "Verifikasi biometrik untuk masuk",
                    result,
                )
                "openEnrollment" -> {
                    val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                        Intent(Settings.ACTION_BIOMETRIC_ENROLL).apply {
                            putExtra(
                                Settings.EXTRA_BIOMETRIC_AUTHENTICATORS_ALLOWED,
                                BiometricManager.Authenticators.BIOMETRIC_STRONG or
                                        BiometricManager.Authenticators.BIOMETRIC_WEAK,
                            )
                        }
                    } else {
                        Intent(Settings.ACTION_SECURITY_SETTINGS)
                    }
                    try {
                        startActivity(intent)
                        result.success(true)
                    } catch (error: Exception) {
                        result.error("settings_unavailable", error.message, null)
                    }
                }
                "openSpeechSettings" -> {
                    val intent = Intent(Settings.ACTION_VOICE_INPUT_SETTINGS)
                    try {
                        startActivity(intent)
                        result.success(true)
                    } catch (error: Exception) {
                        result.error("speech_settings_unavailable", error.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun authenticateBiometric(
        reason: String,
        result: MethodChannel.Result,
    ) {
        runOnUiThread {
            try {
                val executor = ContextCompat.getMainExecutor(this)
                val promptInfo = BiometricPrompt.PromptInfo.Builder()
                    .setTitle("Masuk dengan Biometrik")
                    .setSubtitle(reason)
                    .setNegativeButtonText("Batal")
                    .setAllowedAuthenticators(
                        BiometricManager.Authenticators.BIOMETRIC_STRONG or
                                BiometricManager.Authenticators.BIOMETRIC_WEAK,
                    )
                    .build()

                var isCompleted = false
                val biometricPrompt = BiometricPrompt(
                    this,
                    executor,
                    object : BiometricPrompt.AuthenticationCallback() {
                        override fun onAuthenticationSucceeded(authResult: BiometricPrompt.AuthenticationResult) {
                            if (!isCompleted) {
                                isCompleted = true
                                result.success(true)
                            }
                        }

                        override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                            if (!isCompleted) {
                                isCompleted = true
                                result.success(false)
                            }
                        }

                        override fun onAuthenticationFailed() {
                            // Upaya gagal, sistem Android tetap menampilkan dialog untuk mencoba lagi
                        }
                    },
                )

                biometricPrompt.authenticate(promptInfo)
            } catch (error: Exception) {
                result.error("biometric_unavailable", error.message, null)
            }
        }
    }
}
