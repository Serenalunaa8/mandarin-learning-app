package com.example.mandarin_learning

import android.content.Intent
import android.hardware.biometrics.BiometricPrompt
import android.os.Build
import android.os.CancellationSignal
import android.provider.Settings
import androidx.biometric.BiometricManager
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.example.mandarin_learning/biometric_settings",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "canAuthenticate" -> {
                    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) {
                        result.success(null)
                    } else {
                        result.success(
                            BiometricManager.from(this).canAuthenticate(
                                BiometricManager.Authenticators.BIOMETRIC_WEAK,
                            ) == BiometricManager.BIOMETRIC_SUCCESS,
                        )
                    }
                }
                "authenticate" -> authenticateBiometric(
                    call.argument<String>("reason") ?: "Verifikasi untuk masuk",
                    result,
                )
                "openEnrollment" -> {
                    val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                        Intent(Settings.ACTION_BIOMETRIC_ENROLL).apply {
                            putExtra(
                                Settings.EXTRA_BIOMETRIC_AUTHENTICATORS_ALLOWED,
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
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.P) {
            result.success(null)
            return
        }
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) {
            result.success(null)
            return
        }
        try {
            val builder = BiometricPrompt.Builder(this)
                .setTitle("Masuk dengan biometrik")
                .setSubtitle(reason)
                .setNegativeButton("Batal", mainExecutor) { _, _ ->
                    result.success(false)
                }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                builder.setAllowedAuthenticators(
                    BiometricManager.Authenticators.BIOMETRIC_WEAK,
                )
            } else {
                @Suppress("DEPRECATION")
                builder.setDeviceCredentialAllowed(false)
            }
            builder.build().authenticate(
                CancellationSignal(),
                mainExecutor,
                object : BiometricPrompt.AuthenticationCallback() {
                    override fun onAuthenticationSucceeded(
                        authenticationResult: BiometricPrompt.AuthenticationResult,
                    ) {
                        result.success(true)
                    }

                    override fun onAuthenticationError(
                        errorCode: Int,
                        errString: CharSequence,
                    ) {
                        result.success(false)
                    }
                },
            )
        } catch (error: Exception) {
            result.error("biometric_unavailable", error.message, null)
        }
    }
}
