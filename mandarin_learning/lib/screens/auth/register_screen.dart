import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import 'login_screen.dart';

const Color _registerPageColor = Color(0xFF16300E);
const Color _registerTextColor = Colors.white;
const Color _registerFieldTextColor = Color(0xFF214735);
const Color _registerSupportingTextColor = Color(0xFFB9D6C0);
const Color _registerAccentColor = Color(0xFF22C55E);
const Color _registerIconColor = Color(0xFF15803D);
const Color _registerFieldBorderColor = Color(0xFFC7DCC8);

/// Halaman Pendaftaran (Register Screen)
/// Ilustrasi atas dipertahankan, dengan form bergelombang bernuansa hijau lembut.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  late final AnimationController _floatController;

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _floatController.dispose();
    _usernameController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submitRegister() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    final username = _usernameController.text.trim();
    final fullName = _nameController.text.trim();
    final email = _emailController.text.trim();

    final success = await auth.register(
      username: username,
      password: _passwordController.text,
      fullName: fullName,
      email: email,
    );

    if (!mounted) return;

    if (success) {
      await auth.refreshBiometricStatus();
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Pendaftaran berhasil! Akun tersimpan. Silakan masuk menggunakan nama pengguna dan kata sandi Anda.',
          ),
          backgroundColor: AppColors.success,
          duration: Duration(seconds: 3),
        ),
      );
      // Alur yang benar: Setelah daftar wajib masuk melalui Login, jangan langsung ke dashboard
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => LoginScreen(initialUsername: username),
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
    final size = MediaQuery.of(context).size;
    final screenWidth = size.width;
    final screenHeight = size.height;

    final illustrationHeight = (screenHeight * 0.34).clamp(230.0, 320.0);

    return Scaffold(
      backgroundColor: _registerPageColor,
      body: Stack(
        children: [
          // =========================================================
          // 1. KONTEN UTAMA SCROLLABLE (AGAR AMAN KETIKA KEYBOARD MUNCUL)
          // =========================================================
          SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: Column(
              children: [
                // 1A. Area Ilustrasi Atas
                SizedBox(
                  height: illustrationHeight,
                  width: screenWidth,
                  child: Stack(
                    clipBehavior: Clip.hardEdge,
                    children: [
                      // Latar Langit Biru Cerah ke Hijau Pucat
                      Positioned.fill(
                        child: Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Color(0xFFAEE2EE), // Biru langit cerah
                                Color(0xFFD3EFCF), // Transisi hijau pucat
                                Color(0xFFE5F5BA), // Hijau muda cerah
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Hamparan Bukit Hijau & Adegan Maskot (01_mascot_on_hill_scene.png)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Image.asset(
                          'assets/image/register/01_mascot_on_hill_scene.png',
                          height: illustrationHeight,
                          fit: BoxFit.contain,
                        ),
                      ),

                      // Elemen Mengambang dengan Animasi Floating
                      AnimatedBuilder(
                        animation: _floatController,
                        builder: (context, _) {
                          final fVal = _floatController.value;
                          final dy1 = math.sin(fVal * math.pi) * 4.0;
                          final dy2 = math.cos(fVal * math.pi) * 3.5;

                          return Stack(
                            children: [
                              // Balon Pesan Email Kuning (Kiri Atas)
                              Positioned(
                                left: screenWidth * 0.16,
                                top: illustrationHeight * 0.28 + dy1,
                                width: (screenWidth * 0.17).clamp(52.0, 68.0),
                                child: Image.asset(
                                  'assets/image/register/10_icon_mail_bubble.png',
                                  fit: BoxFit.contain,
                                ),
                              ),

                              // Sparkle Kuning di Kiri
                              Positioned(
                                left: screenWidth * 0.24,
                                top: illustrationHeight * 0.48 + dy2,
                                width: 18,
                                height: 18,
                                child: Image.asset(
                                  'assets/image/register/06_sparkle_yellow_left_top.png',
                                  fit: BoxFit.contain,
                                ),
                              ),

                              // Garis Pancaran Kuning (Burst Lines di atas balon pink)
                              Positioned(
                                right: screenWidth * 0.17,
                                top: illustrationHeight * 0.30 + dy2,
                                width: (screenWidth * 0.13).clamp(40.0, 52.0),
                                child: Image.asset(
                                  'assets/image/register/13_burst_lines_yellow.png',
                                  fit: BoxFit.contain,
                                ),
                              ),

                              // Balon Profil Pink (Kanan)
                              Positioned(
                                right: screenWidth * 0.17,
                                top: illustrationHeight * 0.38 + dy2,
                                width: (screenWidth * 0.16).clamp(50.0, 64.0),
                                child: Image.asset(
                                  'assets/image/register/12_coin_user_pink.png',
                                  fit: BoxFit.contain,
                                ),
                              ),

                              // Sparkle Kuning di Kanan
                              Positioned(
                                right: screenWidth * 0.26,
                                top: illustrationHeight * 0.40 + dy1,
                                width: 16,
                                height: 16,
                                child: Image.asset(
                                  'assets/image/register/05_sparkle_yellow_right.png',
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),

                Transform.translate(
                  offset: const Offset(0, -24),
                  child: CustomPaint(
                    painter: _RegisterPanelPainter(),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 66, 24, 12),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 4),

                            // Judul: "Create Your Account"
                            const Text(
                              'Create Your Account',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 25,
                                fontWeight: FontWeight.w800,
                                color: _registerTextColor,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 6),

                            // Subjudul
                            const Text(
                              'Join us and start learning new languages today!',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w400,
                                color: _registerSupportingTextColor,
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Username
                            _buildInputField(
                              controller: _usernameController,
                              hintText: 'Username',
                              prefixIcon: Icons.alternate_email_rounded,
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'Username wajib diisi';
                                }
                                if (val.trim().length < 3) {
                                  return 'Username minimal 3 karakter';
                                }
                                if (!RegExp(r'^[a-zA-Z0-9_]+$')
                                    .hasMatch(val.trim())) {
                                  return 'Username hanya boleh huruf, angka, dan underscore (_)';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),

                            // Nama Lengkap
                            _buildInputField(
                              controller: _nameController,
                              hintText: 'Nama Lengkap',
                              prefixIcon: Icons.person_rounded,
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'Nama wajib diisi';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),

                            // Email (Wajib)
                            _buildInputField(
                              controller: _emailController,
                              hintText: 'Email',
                              prefixIcon: Icons.email_rounded,
                              keyboardType: TextInputType.emailAddress,
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'Email wajib diisi';
                                }
                                final email = val.trim();
                                if (!email.contains('@') || !email.contains('.')) {
                                  return 'Format email tidak valid';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),

                            // Kata Sandi
                            _buildInputField(
                              controller: _passwordController,
                              hintText: 'Kata Sandi',
                              prefixIcon: Icons.lock_rounded,
                              obscureText: _obscurePassword,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  color: _registerAccentColor,
                                  size: 20,
                                ),
                                onPressed: () {
                                  setState(
                                    () => _obscurePassword = !_obscurePassword,
                                  );
                                },
                              ),
                              validator: (val) {
                                if (val == null || val.isEmpty) {
                                  return 'Kata sandi wajib diisi';
                                }
                                if (val.length < 6) return 'Minimal 6 karakter';
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),

                            // Konfirmasi Kata Sandi
                            _buildInputField(
                              controller: _confirmPasswordController,
                              hintText: 'Konfirmasi Kata Sandi',
                              prefixIcon: Icons.lock_reset_rounded,
                              obscureText: _obscureConfirm,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureConfirm
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  color: _registerAccentColor,
                                  size: 20,
                                ),
                                onPressed: () {
                                  setState(
                                    () => _obscureConfirm = !_obscureConfirm,
                                  );
                                },
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
                            const SizedBox(height: 24),

                            // Tombol: "Daftar ->"
                            Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: SizedBox(
                                height: 52,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _registerAccentColor,
                                    foregroundColor: Colors.white,
                                    elevation: 2,
                                    shadowColor: _registerAccentColor
                                        .withValues(alpha: 0.22),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  onPressed: auth.isLoading
                                      ? null
                                      : _submitRegister,
                                  child: auth.isLoading
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2.5,
                                          ),
                                        )
                                      : const Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              'Daftar',
                                              style: TextStyle(
                                                fontSize: 16.5,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 0.3,
                                              ),
                                            ),
                                            SizedBox(width: 10),
                                            Icon(
                                              Icons.arrow_forward_rounded,
                                              color: Colors.white,
                                              size: 21,
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),

                            // Tautan: "Sudah punya akun? Masuk"
                            Wrap(
                              alignment: WrapAlignment.center,
                              children: [
                                const Text(
                                  'Sudah punya akun? ',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: _registerSupportingTextColor,
                                  ),
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
                                    'Masuk',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: _registerAccentColor,
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
                ),
              ],
            ),
          ),

          // =========================================================
          // 3. TOMBOL KEMBALI DI POJOK KIRI ATAS
          // =========================================================
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            child: Material(
              color: Colors.white.withValues(alpha: 0.86),
              shape: const CircleBorder(),
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                tooltip: 'Kembali',
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  color: _registerIconColor,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hintText,
    required IconData prefixIcon,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      style: const TextStyle(
        color: _registerFieldTextColor,
        fontSize: 15,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(
          color: Color(0xFF819488),
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        filled: true,
        fillColor: Colors.white,
        prefixIcon: Icon(prefixIcon, color: _registerIconColor, size: 21),
        suffixIcon: suffixIcon,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 15,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _registerFieldBorderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _registerAccentColor, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFEF4444)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.6),
        ),
      ),
      validator: validator,
    );
  }
}

class _RegisterPanelPainter extends CustomPainter {
  static const _waveColors = [
    Color(0xFF2F5E1E),
    Color(0xFF254D18),
    Color(0xFF1C3B12),
    _registerPageColor,
  ];
  static const _waveBases = [0.02, 0.17, 0.32, 0.47];
  static const _waveBumps = [5, 4, 5, 4];

  @override
  void paint(Canvas canvas, Size size) {
    final waveHeight = 96.0;
    const waveLift = 32.0;
    final steps = (size.width / 2).ceil();

    for (var layer = 0; layer < _waveColors.length; layer++) {
      final path = Path();
      for (var step = 0; step <= steps; step++) {
        final x = size.width * step / steps;
        final t = x / size.width;
        final triangle = 1 - (2 * t - 1).abs();
        final y =
            waveHeight * (_waveBases[layer] + 0.40 * triangle) -
            waveHeight *
                0.05 *
                math.sin(_waveBumps[layer] * math.pi * t).abs() -
            waveLift;

        if (step == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      path
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();

      canvas.drawPath(
        path,
        Paint()
          ..color = _waveColors[layer]
          ..style = PaintingStyle.fill
          ..isAntiAlias = true,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
