import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../home/main_navigation_screen.dart';
import 'register_screen.dart';

const Color _loginPageColor = Color(0xFF16300E);
const Color _loginTextColor = Colors.white;
const Color _loginFieldTextColor = Color(0xFF214735);
const Color _loginSupportingTextColor = Color(0xFFB9D6C0);
const Color _loginAccentColor = Color(0xFF22C55E);
const Color _loginIconColor = Color(0xFF15803D);
const Color _loginFieldBorderColor = Color(0xFFC7DCC8);

/// Halaman Masuk (Login Screen)
/// Tampilan seragam dengan Halaman Registrasi (Register Screen)
class LoginScreen extends StatefulWidget {
  final String? initialUsername;

  const LoginScreen({super.key, this.initialUsername});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  late final AnimationController _floatController;

  @override
  void initState() {
    super.initState();
    if (widget.initialUsername != null && widget.initialUsername!.isNotEmpty) {
      _usernameController.text = widget.initialUsername!;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted) {
        final auth = context.read<AuthProvider>();
        await auth.refreshBiometricStatus();
        if (_usernameController.text.isEmpty && auth.biometricLoginUsername != null) {
          _usernameController.text = auth.biometricLoginUsername!;
        }
      }
    });

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _floatController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submitLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    final success = await auth.login(
      _usernameController.text.trim(),
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
          content: Text(
            auth.errorMessage ?? 'Gagal masuk. Periksa username dan password.',
          ),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _handleBiometricLogin() async {
    final auth = context.read<AuthProvider>();

    if (!auth.isBiometricSupported) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Perangkat ini belum mendukung atau belum mengaktifkan biometrik di Pengaturan.',
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final success = await auth.loginWithBiometrics();

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Autentikasi biometrik berhasil! Selamat datang, ${auth.profile?.fullName ?? ""}',
          ),
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
          content: Text(
            auth.errorMessage ?? 'Autentikasi biometrik gagal atau dibatalkan.',
          ),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Widget _buildAdaptiveBiometricButton(AuthProvider auth) {
    final isFaceOnly = auth.hasFaceSensor && !auth.hasFingerprintSensor;
    final isFingerprintOnly = auth.hasFingerprintSensor && !auth.hasFaceSensor;

    final IconData biometricIcon;
    final String biometricLabel;

    if (!auth.isBiometricSupported) {
      biometricIcon = Icons.fingerprint_rounded;
      biometricLabel = 'Biometrik tidak tersedia di perangkat';
    } else if (isFaceOnly) {
      biometricIcon = Icons.face_retouching_natural_rounded;
      biometricLabel = auth.biometricLoginUsername != null
          ? 'Masuk dengan Wajah (@${auth.biometricLoginUsername})'
          : 'Masuk dengan Pengenalan Wajah';
    } else if (isFingerprintOnly) {
      biometricIcon = Icons.fingerprint_rounded;
      biometricLabel = auth.biometricLoginUsername != null
          ? 'Masuk dengan Sidik Jari (@${auth.biometricLoginUsername})'
          : 'Masuk dengan Sidik Jari';
    } else {
      biometricIcon = Icons.fingerprint_rounded;
      biometricLabel = auth.biometricLoginUsername != null
          ? 'Masuk dengan Biometrik (@${auth.biometricLoginUsername})'
          : 'Masuk dengan Biometrik';
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        height: 52,
        child: OutlinedButton(
          onPressed: auth.isLoading || !auth.isBiometricSupported
              ? null
              : _handleBiometricLogin,
          style: OutlinedButton.styleFrom(
            side: BorderSide(
              color: auth.biometricLoginUsername != null
                  ? _loginAccentColor
                  : _loginFieldBorderColor.withValues(alpha: 0.6),
              width: 1.4,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            backgroundColor: auth.biometricLoginUsername != null
                ? _loginAccentColor.withValues(alpha: 0.14)
                : Colors.white.withValues(alpha: 0.05),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(biometricIcon, size: 23, color: _loginAccentColor),
              const SizedBox(width: 9),
              Flexible(
                child: Text(
                  biometricLabel,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final size = MediaQuery.of(context).size;
    final screenWidth = size.width;
    final screenHeight = size.height;

    final illustrationHeight = (screenHeight * 0.34).clamp(230.0, 320.0);

    return Scaffold(
      backgroundColor: _loginPageColor,
      body: Stack(
        children: [
          // =========================================================
          // 1. KONTEN UTAMA SCROLLABLE
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

                      // Hamparan Bukit Hijau & Adegan Maskot
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
                          final dy1 = 6.0 * math.sin(fVal * math.pi * 2);
                          final dy2 = 5.0 * math.cos(fVal * math.pi * 2);

                          return Stack(
                            children: [
                              // Balon Pesan (Kiri Atas)
                              Positioned(
                                left: screenWidth * 0.16,
                                top: illustrationHeight * 0.14 + dy1,
                                width: (screenWidth * 0.14).clamp(42.0, 56.0),
                                child: Image.asset(
                                  'assets/image/register/10_icon_mail_bubble.png',
                                  fit: BoxFit.contain,
                                ),
                              ),

                              // Sparkle Kuning di Kiri
                              Positioned(
                                left: screenWidth * 0.12,
                                top: illustrationHeight * 0.32 + dy2,
                                width: 14,
                                height: 14,
                                child: Image.asset(
                                  'assets/image/register/06_sparkle_yellow_left_top.png',
                                  fit: BoxFit.contain,
                                ),
                              ),

                              // Koin Perisai Toska (Kiri Tengah)
                              Positioned(
                                left: screenWidth * 0.08,
                                top: illustrationHeight * 0.44 + dy1,
                                width: (screenWidth * 0.13).clamp(40.0, 52.0),
                                child: Image.asset(
                                  'assets/image/register/08_coin_shield_teal.png',
                                  fit: BoxFit.contain,
                                ),
                              ),

                              // Koin Panah Ungu (Kiri Bawah)
                              Positioned(
                                left: screenWidth * 0.22,
                                top: illustrationHeight * 0.50 + dy2,
                                width: (screenWidth * 0.15).clamp(44.0, 58.0),
                                child: Image.asset(
                                  'assets/image/register/11_coin_arrow_purple.png',
                                  fit: BoxFit.contain,
                                ),
                              ),

                              // Koin Centang Kuning (Kanan Atas)
                              Positioned(
                                right: screenWidth * 0.08,
                                top: illustrationHeight * 0.10 + dy2,
                                width: (screenWidth * 0.13).clamp(40.0, 52.0),
                                child: Image.asset(
                                  'assets/image/register/02_coin_check_yellow.png',
                                  fit: BoxFit.contain,
                                ),
                              ),

                              // Koin Jeruk (Kanan Tengah-Atas)
                              Positioned(
                                right: screenWidth * 0.22,
                                top: illustrationHeight * 0.18 + dy1,
                                width: (screenWidth * 0.14).clamp(42.0, 56.0),
                                child: Image.asset(
                                  'assets/image/register/03_coin_orange.png',
                                  fit: BoxFit.contain,
                                ),
                              ),

                              // Efek Burst Garis Kuning (Kanan)
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

                // 1B. Panel Gelombang Berwarna Hijau
                Transform.translate(
                  offset: const Offset(0, -24),
                  child: CustomPaint(
                    painter: _LoginPanelPainter(),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 66, 24, 24),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 4),

                            // Judul: "Welcome Back"
                            const Text(
                              'Welcome Back',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 25,
                                fontWeight: FontWeight.w800,
                                color: _loginTextColor,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 6),

                            // Subjudul
                            const Text(
                              'Masuk ke akunmu untuk melanjutkan belajar!',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w400,
                                color: _loginSupportingTextColor,
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Field: Username
                            _buildInputField(
                              controller: _usernameController,
                              hintText: 'Username',
                              prefixIcon: Icons.alternate_email_rounded,
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'Username wajib diisi';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),

                            // Field: Kata Sandi
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
                                  color: _loginAccentColor,
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
                                if (val.length < 6) {
                                  return 'Minimal 6 karakter';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 24),

                            // Tombol: "Masuk ->"
                            Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: SizedBox(
                                height: 52,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _loginAccentColor,
                                    foregroundColor: Colors.white,
                                    elevation: 2,
                                    shadowColor: _loginAccentColor.withValues(
                                      alpha: 0.22,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  onPressed: auth.isLoading
                                      ? null
                                      : _submitLogin,
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
                                              'Masuk',
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
                            const SizedBox(height: 16),

                            // Tombol: Biometrik Adaptif
                            _buildAdaptiveBiometricButton(auth),
                            const SizedBox(height: 12),

                            // Tautan: "Belum punya akun? Daftar Sekarang"
                            Wrap(
                              alignment: WrapAlignment.center,
                              children: [
                                const Text(
                                  'Belum punya akun? ',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: _loginSupportingTextColor,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const RegisterScreen(),
                                      ),
                                    );
                                  },
                                  child: const Text(
                                    'Daftar Sekarang',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: _loginAccentColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),
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
          // 2. TOMBOL KEMBALI DI POJOK KIRI ATAS
          // =========================================================
          if (Navigator.of(context).canPop())
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 16,
              child: Material(
                color: Colors.white.withValues(alpha: 0.86),
                shape: const CircleBorder(),
                child: IconButton(
                  onPressed: () => Navigator.maybePop(context),
                  tooltip: 'Kembali',
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                    color: _loginIconColor,
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
        color: _loginFieldTextColor,
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
        prefixIcon: Icon(prefixIcon, color: _loginIconColor, size: 21),
        suffixIcon: suffixIcon,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 15,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _loginFieldBorderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _loginAccentColor, width: 1.6),
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

class _LoginPanelPainter extends CustomPainter {
  static const _waveColors = [
    Color(0xFF2F5E1E),
    Color(0xFF254D18),
    Color(0xFF1C3B12),
    _loginPageColor,
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
