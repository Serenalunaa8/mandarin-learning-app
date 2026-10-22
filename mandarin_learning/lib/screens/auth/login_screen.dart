import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../services/biometric_service.dart';
import '../home/main_navigation_screen.dart';
import 'register_screen.dart';

// =============================================================
// ASET (folder assets/image/regist)
// Sesuaikan nama file dengan yang ada di folder kamu.
// =============================================================
const String _kHeaderAsset = 'assets/image/regist/header.png'; // langit + pohon + bukit + maskot
const String _kBushLeftAsset = 'assets/image/regist/semak_kiri.png'; // semak kiri bawah (opsional)
const String _kBushRightAsset = 'assets/image/regist/semak_kanan.png'; // semak kanan bawah (opsional)

// Warna tema gelap sesuai mockup
const Color _kDarkBg = Color(0xFF16300E);
const Color _kFieldFill = Color(0xFF234523);
const Color _kFieldBorder = Color(0xFF2F6B2F);
const Color _kHint = Color(0xFF8FB48F);
const Color _kIcon = Color(0xFF86D67F);
const Color _kSubtitle = Color(0xFF9CCB8F);
const Color _kLink = Color(0xFF4ADE80);

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AuthProvider>().refreshBiometricStatus();
    });
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

    if (!auth.isBiometricSupported) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Perangkat ini belum mendukung atau belum mengaktifkan biometrik.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Jika biometrik belum dihubungkan ke akun manapun di perangkat:
    if (!auth.isBiometricEnrolled) {
      final isFaceOnly = auth.hasFaceSensor && !auth.hasFingerprintSensor;
      final biometricName = isFaceOnly
          ? 'pengenalan wajah'
          : (auth.hasFingerprintSensor && !auth.hasFaceSensor
              ? 'sidik jari'
              : 'biometrik');
      final biometricIcon = isFaceOnly
          ? Icons.face_retouching_natural_rounded
          : Icons.fingerprint_rounded;

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: _kDarkBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: _kFieldBorder, width: 1.5),
          ),
          title: Row(
            children: [
              Icon(biometricIcon, color: _kIcon, size: 28),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Biometrik Belum Terhubung',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            'Untuk menggunakan login dengan $biometricName, silakan masuk atau daftar menggunakan nama pengguna dan kata sandi sekali.\n\nPastikan juga $biometricName sudah didaftarkan pada Pengaturan perangkat HP Anda.',
            style: const TextStyle(fontSize: 13, height: 1.4, color: _kSubtitle),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                BiometricService.instance.openEnrollmentSettings();
              },
              child: const Text(
                'Pengaturan HP',
                style: TextStyle(color: _kLink),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _kIcon,
                foregroundColor: _kDarkBg,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'Saya Mengerti',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
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

  // ---------------------------------------------------------------
  // Helper tampilan
  // ---------------------------------------------------------------

  InputDecoration _fieldDecoration({
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    OutlineInputBorder border(Color c, [double w = 1.5]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide(color: c, width: w),
        );

    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: _kHint, fontSize: 15),
      filled: true,
      fillColor: _kFieldFill,
      prefixIcon: Icon(icon, color: _kIcon, size: 26),
      suffixIcon: suffix,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      border: border(_kFieldBorder),
      enabledBorder: border(_kFieldBorder),
      focusedBorder: border(_kIcon, 2),
      errorBorder: border(const Color(0xFFFF8A80)),
      focusedErrorBorder: border(const Color(0xFFFF8A80), 2),
      errorStyle: const TextStyle(color: Color(0xFFFFB4AB), fontSize: 12),
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.white,
          fontSize: 14,
        ),
      ),
    );
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
      biometricLabel = auth.isBiometricEnrolled
          ? 'Masuk dengan Wajah (@${auth.enrolledBiometricUsername})'
          : 'Masuk dengan Pengenalan Wajah';
    } else if (isFingerprintOnly) {
      biometricIcon = Icons.fingerprint_rounded;
      biometricLabel = auth.isBiometricEnrolled
          ? 'Masuk dengan Sidik Jari (@${auth.enrolledBiometricUsername})'
          : 'Masuk dengan Sidik Jari';
    } else {
      biometricIcon = Icons.fingerprint_rounded;
      biometricLabel = auth.isBiometricEnrolled
          ? 'Masuk dengan Biometrik (@${auth.enrolledBiometricUsername})'
          : 'Masuk dengan Biometrik';
    }

    return SizedBox(
      height: 52,
      child: OutlinedButton(
        onPressed: auth.isLoading || !auth.isBiometricSupported
            ? null
            : _handleBiometricLogin,
        style: OutlinedButton.styleFrom(
          side: BorderSide(
            color: auth.isBiometricEnrolled ? _kIcon : _kFieldBorder,
            width: 1.5,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          backgroundColor: auth.isBiometricEnrolled
              ? _kFieldFill
              : _kFieldFill.withValues(alpha: 0.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(biometricIcon, size: 24, color: _kIcon),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                biometricLabel,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Colors.white,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bushDecoration(String asset, {required bool left}) {
    return Positioned(
      bottom: 0,
      left: left ? 0 : null,
      right: left ? null : 0,
      width: 110,
      child: IgnorePointer(
        child: Image.asset(
          asset,
          fit: BoxFit.contain,
          alignment: left ? Alignment.bottomLeft : Alignment.bottomRight,
          errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final size = MediaQuery.of(context).size;
    final topPadding = MediaQuery.of(context).padding.top;

    final headerHeight = (size.height * 0.36).clamp(250.0, 340.0);
    const overlap = 30.0; // seberapa jauh panel gelap naik menimpa ilustrasi
    final panelTop = headerHeight - overlap;

    return Scaffold(
      backgroundColor: _kDarkBg,
      body: SingleChildScrollView(
        child: Stack(
          children: [
            // =====================================================
            // 1. ILUSTRASI ATAS
            // =====================================================
            SizedBox(
              width: double.infinity,
              height: headerHeight,
              child: Image.asset(
                _kHeaderAsset,
                fit: BoxFit.cover,
                alignment: Alignment.bottomCenter,
                errorBuilder: (context, error, stackTrace) => Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFFA9DDF2), Color(0xFFC4E38A)],
                    ),
                  ),
                ),
              ),
            ),

            // =====================================================
            // 2. PANEL GELAP BERTEPI GELOMBANG
            // =====================================================
            Padding(
              padding: EdgeInsets.only(top: panelTop),
              child: ClipPath(
                clipper: _WaveTopClipper(),
                child: Container(
                  width: double.infinity,
                  constraints: BoxConstraints(minHeight: size.height - panelTop),
                  color: _kDarkBg,
                  child: Stack(
                    children: [
                      // Semak dekoratif kiri & kanan bawah
                      _bushDecoration(_kBushLeftAsset, left: true),
                      _bushDecoration(_kBushRightAsset, left: false),

                      SafeArea(
                        top: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(28, 50, 28, 24),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Text(
                                  'Selamat Datang Kembali!',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Masuk dengan username & password terenkripsi',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: _kSubtitle,
                                    fontSize: 14,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // Info Keamanan & Database
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: _kFieldFill.withValues(alpha: 0.7),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: _kFieldBorder.withValues(alpha: 0.8)),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.security, color: _kIcon, size: 22),
                                      SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          'Terenkripsi SHA-256 • Tersimpan di Database Lokal & Online • Sesi Aktif',
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            color: _kHint,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 24),

                                // Field Username
                                _label('Username'),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _usernameController,
                                  style: const TextStyle(color: Colors.white, fontSize: 15),
                                  cursorColor: _kIcon,
                                  decoration: _fieldDecoration(
                                    hint: 'Masukkan username Anda',
                                    icon: Icons.person_rounded,
                                  ),
                                  validator: (val) {
                                    if (val == null || val.trim().isEmpty) return 'Username wajib diisi';
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 18),

                                // Field Password
                                _label('Kata Sandi (Password)'),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _passwordController,
                                  obscureText: _obscurePassword,
                                  style: const TextStyle(color: Colors.white, fontSize: 15),
                                  cursorColor: _kIcon,
                                  decoration: _fieldDecoration(
                                    hint: '••••••••',
                                    icon: Icons.lock_rounded,
                                    suffix: IconButton(
                                      icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                        color: _kIcon,
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

                                // Tombol Masuk (efek 3D tepi bawah gelap)
                                Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(30),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color(0xFF2D8A1A),
                                        offset: Offset(0, 4),
                                        blurRadius: 0,
                                      ),
                                    ],
                                  ),
                                  child: SizedBox(
                                    height: 54,
                                    child: ElevatedButton(
                                      onPressed: auth.isLoading ? null : _submitLogin,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF47B82A),
                                        disabledBackgroundColor: const Color(0xFF47B82A).withValues(alpha: 0.6),
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        shadowColor: Colors.transparent,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(30),
                                        ),
                                      ),
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
                                              children: [
                                                SizedBox(width: 24),
                                                Expanded(
                                                  child: Text(
                                                    'Masuk ke Akun',
                                                    textAlign: TextAlign.center,
                                                    style: TextStyle(
                                                      fontSize: 17,
                                                      fontWeight: FontWeight.bold,
                                                      letterSpacing: 0.2,
                                                    ),
                                                  ),
                                                ),
                                                Icon(Icons.arrow_forward_rounded, size: 24),
                                              ],
                                            ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 18),

                                // Tombol Login Biometrik Adaptif Sesuai Sensor Perangkat
                                _buildAdaptiveBiometricButton(auth),
                                const SizedBox(height: 10),

                                // Opsi Masuk Sebagai Tamu
                                TextButton(
                                  onPressed: auth.isLoading
                                      ? null
                                      : () async {
                                          final nav = Navigator.of(context);
                                          await auth.loginAsGuest();
                                          if (mounted) {
                                            nav.pushAndRemoveUntil(
                                              MaterialPageRoute(
                                                  builder: (_) => const MainNavigationScreen()),
                                              (route) => false,
                                            );
                                          }
                                        },
                                  child: const Text(
                                    'Masuk sebagai Tamu (Mode Offline)',
                                    style: TextStyle(color: _kHint),
                                  ),
                                ),
                                const SizedBox(height: 10),

                                // Belum punya akun?
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text(
                                      'Belum punya akun? ',
                                      style: TextStyle(color: _kHint, fontSize: 14),
                                    ),
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
                                          color: _kLink,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 24),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // =====================================================
            // 3. TOMBOL KEMBALI (menggantikan AppBar)
            // =====================================================
            if (Navigator.of(context).canPop())
              Positioned(
                top: topPadding + 8,
                left: 12,
                child: Material(
                  color: Colors.white.withValues(alpha: 0.75),
                  shape: const CircleBorder(),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, color: _kDarkBg),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Tepi atas bergelombang halus untuk panel gelap (mengikuti mockup).
class _WaveTopClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final w = size.width;
    const top = 0.0;
    const amp = 22.0;

    final path = Path()..moveTo(0, top + amp);
    path.cubicTo(
      w * 0.18, top + amp * 1.7,
      w * 0.32, top - 2,
      w * 0.52, top + amp * 0.55,
    );
    path.cubicTo(
      w * 0.72, top + amp * 1.25,
      w * 0.86, top + amp * 0.2,
      w, top + amp * 0.85,
    );
    path.lineTo(w, size.height);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}