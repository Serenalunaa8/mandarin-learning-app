import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../home/main_navigation_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  final String? initialUsername;

  const LoginScreen({super.key, this.initialUsername});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    if (widget.initialUsername != null && widget.initialUsername!.isNotEmpty) {
      _usernameController.text = widget.initialUsername!;
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submitLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    final success = await auth.login(
      _usernameController.text,
      _passwordController.text,
    );

    if (!mounted) return;

    if (success) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
        (route) => false,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.errorMessage ?? 'Gagal masuk. Periksa username dan password.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _handleBiometricLogin() async {
    final auth = context.read<AuthProvider>();

    // Jika biometrik belum didaftarkan terlebih dahulu:
    if (!auth.isBiometricEnrolled) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.fingerprint_rounded, color: AppColors.primary, size: 28),
              SizedBox(width: 6),
              Icon(Icons.face_retouching_natural_rounded, color: AppColors.primary, size: 28),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Biometrik Belum Didaftarkan',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: const Text(
            'Anda belum mendaftarkan sidik jari atau pengenalan wajah untuk akun manapun di perangkat ini.\n\nSilakan masuk menggunakan nama pengguna dan kata sandi terlebih dahulu, lalu buka menu Pengaturan untuk mendaftarkan biometrik Anda.',
            style: TextStyle(fontSize: 13, height: 1.4),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Saya Mengerti'),
            ),
          ],
        ),
      );
      return;
    }

    final success = await auth.loginWithBiometrics();

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Autentikasi biometrik berhasil! Selamat datang, ${auth.profile?.fullName ?? ""}'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
        (route) => false,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.errorMessage ?? 'Biometrik gagal atau dibatalkan.'),
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
      appBar: AppBar(
        title: const Text('Masuk ke Akun'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 10),
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      color: AppColors.primaryLight,
                      shape: BoxShape.circle,
                    ),
                    child: const Text('🐼', style: TextStyle(fontSize: 48)),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Selamat Datang Kembali!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Masuk dengan username & password terenkripsi',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textMuted, fontSize: 14),
                ),
                const SizedBox(height: 16),

                // Info Keamanan & Database
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.security, color: AppColors.primary, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Terenkripsi SHA-256 • Tersimpan di Database Lokal & Online • Sesi Aktif',
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
                const SizedBox(height: 24),

                // Field Username
                const Text(
                  'Username',
                  style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _usernameController,
                  decoration: const InputDecoration(
                    hintText: 'Masukkan username Anda',
                    prefixIcon: Icon(Icons.person_outline, color: AppColors.primary),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Username wajib diisi';
                    return null;
                  },
                ),
                const SizedBox(height: 18),

                // Field Password
                const Text(
                  'Kata Sandi (Password)',
                  style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    hintText: '••••••••',
                    prefixIcon: const Icon(Icons.lock_outline, color: AppColors.primary),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        color: AppColors.textMuted,
                      ),
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.isEmpty) return 'Kata sandi wajib diisi';
                    if (val.length < 6) return 'Minimal 6 karakter';
                    return null;
                  },
                ),
                const SizedBox(height: 28),

                // Tombol Masuk
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: auth.isLoading ? null : _submitLogin,
                    child: auth.isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                          )
                        : const Text('Masuk ke Akun'),
                  ),
                ),
                const SizedBox(height: 14),

                // Tombol Login Biometrik (Sidik Jari & Pengenalan Wajah)
                SizedBox(
                  height: 52,
                  child: OutlinedButton(
                    onPressed: auth.isLoading || !auth.isBiometricSupported
                        ? null
                        : _handleBiometricLogin,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: auth.isBiometricEnrolled ? AppColors.primary : AppColors.border,
                        width: 1.5,
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      backgroundColor: auth.isBiometricEnrolled
                          ? AppColors.primaryLight.withValues(alpha: 0.3)
                          : Colors.white,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.fingerprint_rounded, size: 24, color: AppColors.primaryDark),
                        const SizedBox(width: 4),
                        const Icon(Icons.face_retouching_natural_rounded, size: 24, color: AppColors.primaryDark),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            !auth.isBiometricSupported
                                ? 'Biometrik tersedia di aplikasi Android/iOS'
                                : auth.isBiometricEnrolled
                                    ? 'Masuk sebagai @${auth.enrolledBiometricUsername}'
                                    : 'Masuk dengan Biometrik (Sidik Jari / Wajah)',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: AppColors.primaryDark,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Opsi Masuk Sebagai Tamu
                TextButton(
                  onPressed: auth.isLoading
                      ? null
                      : () async {
                          final nav = Navigator.of(context);
                          await auth.loginAsGuest();
                          if (mounted) {
                            nav.pushAndRemoveUntil(
                              MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
                              (route) => false,
                            );
                          }
                        },
                  child: const Text(
                    'Masuk sebagai Tamu (Mode Offline)',
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                ),
                const SizedBox(height: 16),

                // Belum punya akun?
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Belum punya akun? ', style: TextStyle(color: AppColors.textMuted)),
                    GestureDetector(
                      onTap: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => const RegisterScreen()),
                        );
                      },
                      child: const Text(
                        'Daftar Sekarang',
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
