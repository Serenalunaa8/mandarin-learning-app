import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../services/biometric_service.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _enableFingerprint = false;
  bool _enableFace = false;
  bool? _pendingFingerprintEnrollment;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AuthProvider>().refreshBiometricStatus();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final pendingFingerprint = _pendingFingerprintEnrollment;
    if (pendingFingerprint == null) return;
    _pendingFingerprintEnrollment = null;
    context.read<AuthProvider>().refreshBiometricStatus().then((_) {
      if (!mounted) return;
      final auth = context.read<AuthProvider>();
      final available = pendingFingerprint
          ? auth.hasFingerprintSensor
          : auth.hasFaceSensor;
      if (available) {
        setState(() {
          if (pendingFingerprint) {
            _enableFingerprint = true;
          } else {
            _enableFace = true;
          }
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Biometrik belum terdaftar. Selesaikan pendaftarannya di Pengaturan perangkat.',
            ),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _usernameController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _enableDeviceBiometric({
    required bool fingerprint,
    required bool enabled,
  }) async {
    if (!enabled) {
      setState(() {
        if (fingerprint) {
          _enableFingerprint = false;
        } else {
          _enableFace = false;
        }
      });
      return;
    }

    final auth = context.read<AuthProvider>();
    final available = fingerprint
        ? auth.hasFingerprintSensor
        : auth.hasFaceSensor;
    if (available) {
      setState(() {
        if (fingerprint) {
          _enableFingerprint = true;
        } else {
          _enableFace = true;
        }
      });
      return;
    }

    _pendingFingerprintEnrollment = fingerprint;
    final opened = await BiometricService.instance.openEnrollmentSettings();
    if (!mounted) return;
    if (!opened) {
      _pendingFingerprintEnrollment = null;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Buka Pengaturan perangkat > Keamanan & privasi untuk mendaftarkan sidik jari atau wajah.',
          ),
        ),
      );
    }
  }

  Future<void> _submitRegister() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    final success = await auth.register(
      username: _usernameController.text,
      password: _passwordController.text,
      fullName: _nameController.text,
      email: _emailController.text,
      enableFingerprint: _enableFingerprint,
      enableFace: _enableFace,
    );

    if (!mounted) return;

    if (success) {
      final registeredUsername = _usernameController.text.trim();
      final biometricRegistered =
          auth.isBiometricEnrolled &&
          auth.enrolledBiometricUsername == registeredUsername.toLowerCase();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            biometricRegistered
                ? 'Akun tersimpan dan login biometrik berhasil diaktifkan di perangkat ini. Silakan masuk.'
                : _enableFingerprint || _enableFace
                ? 'Akun tersimpan, tetapi biometrik belum aktif. Anda dapat mendaftarkannya setelah masuk melalui Pengaturan.'
                : 'Pendaftaran berhasil! Akun tersimpan. Silakan masuk menggunakan username dan kata sandi Anda.',
          ),
          backgroundColor:
              biometricRegistered || (!_enableFingerprint && !_enableFace)
              ? AppColors.success
              : AppColors.error,
          duration: const Duration(seconds: 4),
        ),
      );
      // Alur yang benar: Setelah daftar wajib masuk melalui Login, jangan langsung ke dashboard
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => LoginScreen(initialUsername: registeredUsername),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            auth.errorMessage ?? 'Gagal mendaftar. Silakan coba lagi.',
          ),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: AppColors.mintBackground,
      appBar: AppBar(title: const Text('Buat Akun Baru')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Mulai Belajar Mandarin!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Buat akun tersinkronisasi database lokal & online',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textMuted, fontSize: 14),
                ),
                const SizedBox(height: 16),

                // Info Keamanan
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.lock_clock_outlined,
                        color: AppColors.primary,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Password otomatis dienkripsi dengan SHA-256 (Tanpa Firebase).',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Username
                const Text(
                  'Username',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _usernameController,
                  decoration: const InputDecoration(
                    hintText: 'contoh: lucy_mandarin',
                    prefixIcon: Icon(
                      Icons.alternate_email,
                      color: AppColors.primary,
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Username wajib diisi';
                    }
                    if (val.trim().length < 3) {
                      return 'Username minimal 3 karakter';
                    }
                    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(val.trim())) {
                      return 'Username hanya boleh huruf, angka, dan underscore (_)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Nama Lengkap
                const Text(
                  'Nama Lengkap',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    hintText: 'Nama lengkap Anda',
                    prefixIcon: Icon(
                      Icons.person_outline,
                      color: AppColors.primary,
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Nama wajib diisi';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Email
                const Text(
                  'Email (Opsional)',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    hintText: 'nama@email.com',
                    prefixIcon: Icon(
                      Icons.email_outlined,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Password
                const Text(
                  'Kata Sandi (Password)',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    hintText: '••••••••',
                    prefixIcon: const Icon(
                      Icons.lock_outline,
                      color: AppColors.primary,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: AppColors.textMuted,
                      ),
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.isEmpty) {
                      return 'Kata sandi wajib diisi';
                    }
                    if (val.length < 6) return 'Minimal 6 karakter';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Konfirmasi Password
                const Text(
                  'Konfirmasi Kata Sandi',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirm,
                  decoration: InputDecoration(
                    hintText: '••••••••',
                    prefixIcon: const Icon(
                      Icons.lock_reset,
                      color: AppColors.primary,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirm
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: AppColors.textMuted,
                      ),
                      onPressed: () {
                        setState(() => _obscureConfirm = !_obscureConfirm);
                      },
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.isEmpty) {
                      return 'Konfirmasi kata sandi wajib diisi';
                    }
                    if (val != _passwordController.text) {
                      return 'Konfirmasi kata sandi tidak cocok';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 18),

                // Pilih sensor biometrik secara terpisah; autentikasi dikelola OS.
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        secondary: const Icon(
                          Icons.fingerprint_rounded,
                          color: AppColors.primary,
                        ),
                        title: const Text(
                          'Sidik Jari',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        subtitle: Text(
                          auth.hasFingerprintSensor
                              ? 'Aktifkan login menggunakan sidik jari'
                              : auth.isBiometricSupported
                              ? 'Sidik jari belum terdaftar di perangkat'
                              : 'Tersedia di aplikasi Android/iOS',
                          style: const TextStyle(fontSize: 11),
                        ),
                        value: auth.hasFingerprintSensor && _enableFingerprint,
                        onChanged: (value) => _enableDeviceBiometric(
                          fingerprint: true,
                          enabled: value,
                        ),
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        secondary: const Icon(
                          Icons.face_retouching_natural_rounded,
                          color: AppColors.primary,
                        ),
                        title: const Text(
                          'Pengenalan Wajah',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        subtitle: Text(
                          auth.hasFaceSensor
                              ? 'Aktifkan login menggunakan wajah'
                              : auth.isBiometricSupported
                              ? 'Pengenalan wajah belum terdaftar di perangkat'
                              : 'Tersedia di aplikasi Android/iOS',
                          style: const TextStyle(fontSize: 11),
                        ),
                        value: auth.hasFaceSensor && _enableFace,
                        onChanged: (value) => _enableDeviceBiometric(
                          fingerprint: false,
                          enabled: value,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Biometrik dikelola perangkat dan tidak disimpan ke database aplikasi.',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Tombol Daftar
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: auth.isLoading ? null : _submitRegister,
                    child: auth.isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Text('Daftar Akun Baru'),
                  ),
                ),
                const SizedBox(height: 20),

                // Sudah punya akun?
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Sudah punya akun? ',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const LoginScreen(),
                          ),
                        );
                      },
                      child: const Text(
                        'Masuk di Sini',
                        style: TextStyle(
                          color: AppColors.primaryDark,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
