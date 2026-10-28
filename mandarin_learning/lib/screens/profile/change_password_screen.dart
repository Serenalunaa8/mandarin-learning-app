import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../auth/register_screen.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  String? _inlineError;

  // Warna tema non-hijau yang selaras dengan aksen gamifikasi Nihaoki (Sunset Orange & Coin Gold)
  static const Color _themePrimary = Color(
    0xFFF97316,
  ); // AppColors.streakOrange
  static const Color _themeDark = Color(0xFFEA580C);
  static const Color _themeAmber = Color(0xFFF59E0B); // AppColors.coinGold
  static const Color _themeSoftBg = Color(0xFFFFF7ED); // Cream Apricot
  static const Color _themeBorder = Color(0xFFFED7AA); // Border hangat
  static const Color _pageBg = Color(0xFFFDFBF7); // Latar porcelain lembut

  @override
  void initState() {
    super.initState();
    _currentPasswordController.addListener(() => setState(() {}));
    _newPasswordController.addListener(() => setState(() {}));
    _confirmPasswordController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  bool get _hasMinLength => _newPasswordController.text.trim().length >= 6;
  bool get _isDifferentFromOld =>
      _newPasswordController.text.isNotEmpty &&
      _newPasswordController.text != _currentPasswordController.text;
  bool get _isMatching =>
      _confirmPasswordController.text.isNotEmpty &&
      _confirmPasswordController.text == _newPasswordController.text;

  Future<void> _handleSubmit() async {
    setState(() => _inlineError = null);

    if (!_formKey.currentState!.validate()) return;

    final currentPass = _currentPasswordController.text;
    final newPass = _newPasswordController.text.trim();
    final confirmPass = _confirmPasswordController.text.trim();

    if (newPass != confirmPass) {
      setState(() => _inlineError = 'Konfirmasi kata sandi tidak cocok.');
      return;
    }

    if (currentPass == newPass) {
      setState(
        () => _inlineError =
            'Kata sandi baru tidak boleh sama dengan kata sandi saat ini.',
      );
      return;
    }

    setState(() => _isLoading = true);

    final auth = context.read<AuthProvider>();
    final success = await auth.changePassword(
      currentPassword: currentPass,
      newPassword: newPass,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      _showSuccessDialog();
    } else {
      setState(() {
        _inlineError =
            auth.errorMessage ??
            'Gagal memperbarui kata sandi. Silakan periksa kembali.';
      });
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: _themeSoftBg,
                shape: BoxShape.circle,
                border: Border.all(color: _themeBorder, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: _themePrimary.withValues(alpha: 0.16),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: Image.asset(
                  'assets/image/beranda/ikon_centang.png',
                  width: 44,
                  height: 44,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.check_circle_rounded,
                    color: _themePrimary,
                    size: 42,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Kata Sandi Berhasil Diubah!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: AppColors.textDark,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Akunmu kini terlindungi dengan kata sandi baru. Data tersimpan aman di SQLite lokal dan Supabase.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                color: AppColors.textMuted,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _themePrimary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context);
                },
                child: const Text(
                  'Selesai & Kembali',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: _pageBg,
      body: Stack(
        children: [
          // 1. Panorama Lembah Sunset Tiongkok (Aksen Hangat Jingga & Emas Sesuai Tema Nihaoki)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 175,
            child: Opacity(
              opacity: 0.22,
              child: Image.asset(
                'assets/image/background/03_sunset_valley.png',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const SizedBox.shrink(),
              ),
            ),
          ),

          // 2. Lapisan gradasi halus di atas banner
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 175,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    _pageBg.withValues(alpha: 0.40),
                    _pageBg.withValues(alpha: 0.85),
                    _pageBg,
                  ],
                ),
              ),
            ),
          ),

          // 3. Ornamen Awan Tradisional khas Nihaoki di pojok kanan atas
          Positioned(
            top: 26,
            right: -15,
            child: Opacity(
              opacity: 0.38,
              child: Image.asset(
                'assets/image/beranda/awan_kecil.png',
                width: 76,
                errorBuilder: (context, error, stackTrace) =>
                    const SizedBox.shrink(),
              ),
            ),
          ),

          // 4. Ornamen Kilau Emas
          Positioned(
            top: 64,
            left: 22,
            child: Opacity(
              opacity: 0.40,
              child: Image.asset(
                'assets/image/beranda/kilau_01.png',
                width: 20,
                errorBuilder: (context, error, stackTrace) =>
                    const SizedBox.shrink(),
              ),
            ),
          ),

          // 5. Konten Utama
          SafeArea(
            child: Column(
              children: [
                _buildAppBar(context),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    child: auth.isGuest
                        ? _buildGuestNotice(context)
                        : _buildFormContent(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        border: const Border(bottom: BorderSide(color: Color(0xFFF1E9E0))),
      ),
      child: Row(
        children: [
          // Tombol Kembali
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: AppColors.textDark,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Info Halaman
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ubah Kata Sandi',
                  style: TextStyle(
                    fontSize: 17.5,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textDark,
                    letterSpacing: -0.3,
                  ),
                ),
                Text(
                  'Keamanan Akun • Enkripsi SHA-256',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _themeDark,
                  ),
                ),
              ],
            ),
          ),

          // Badge Perisai Keamanan
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _themeSoftBg,
              shape: BoxShape.circle,
              border: Border.all(color: _themeBorder, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: _themePrimary.withValues(alpha: 0.12),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Image.asset(
                'assets/image/beranda/ikon_perisai.png',
                width: 24,
                height: 24,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.shield_rounded,
                  size: 22,
                  color: _themePrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuestNotice(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _themeBorder),
        boxShadow: [
          BoxShadow(
            color: _themePrimary.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Image.asset(
            'assets/image/beranda/maskot_02_baca_buku.png',
            width: 90,
            height: 90,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) =>
                const Text('🐼', style: TextStyle(fontSize: 54)),
          ),
          const SizedBox(height: 16),
          const Text(
            'Akun Dalam Mode Tamu',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Akun tamu tidak menggunakan kata sandi. Daftarkan akun baru agar progres belajar, koin 🪙, dan streak 🔥 tersimpan aman di database permanen.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textMuted,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _themePrimary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: const Icon(Icons.person_add_rounded, size: 20),
              label: const Text(
                'Daftar Akun Baru Sekarang',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
              ),
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const RegisterScreen()),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormContent() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Kartu Panduan Keamanan dari Maskot LingLing
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFFBEB), _themeSoftBg],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: _themeBorder),
              boxShadow: [
                BoxShadow(
                  color: _themePrimary.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Maskot LingLing memegang kaca pembesar
                SizedBox(
                  width: 58,
                  height: 58,
                  child: Image.asset(
                    'assets/image/beranda/maskot_04_lup.png',
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) =>
                        const Text('🐼', style: TextStyle(fontSize: 38)),
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Tips Keamanan Akun',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w900,
                              color: _themeDark,
                            ),
                          ),
                          SizedBox(width: 4),
                          Text('🛡️', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Pastikan kata sandi baru mudah diingat namun sulit ditebak orang lain untuk melindungi koin & streak belajarmu.',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textMuted,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Pesan Error Inline
          if (_inlineError != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: AppColors.error,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _inlineError!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFFB91C1C),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // 2. Kartu Utama Form Input
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Input 1: Kata Sandi Saat Ini
                _buildFieldLabel(
                  'Kata Sandi Saat Ini',
                  Icons.lock_clock_outlined,
                ),
                _buildPasswordField(
                  controller: _currentPasswordController,
                  hintText: 'Ketik kata sandi akunmu saat ini',
                  obscureText: _obscureCurrent,
                  onToggleObscure: () =>
                      setState(() => _obscureCurrent = !_obscureCurrent),
                  validator: (val) {
                    if (val == null || val.isEmpty) {
                      return 'Kata sandi saat ini wajib diisi';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 18),

                // Input 2: Kata Sandi Baru
                _buildFieldLabel('Kata Sandi Baru', Icons.lock_outline_rounded),
                _buildPasswordField(
                  controller: _newPasswordController,
                  hintText: 'Minimal 6 karakter kombinasi',
                  obscureText: _obscureNew,
                  onToggleObscure: () =>
                      setState(() => _obscureNew = !_obscureNew),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Kata sandi baru wajib diisi';
                    }
                    if (val.trim().length < 6) {
                      return 'Kata sandi baru minimal 6 karakter';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 18),

                // Input 3: Konfirmasi Kata Sandi Baru
                _buildFieldLabel(
                  'Konfirmasi Kata Sandi Baru',
                  Icons.lock_reset_rounded,
                ),
                _buildPasswordField(
                  controller: _confirmPasswordController,
                  hintText: 'Ulangi kata sandi baru secara sama',
                  obscureText: _obscureConfirm,
                  onToggleObscure: () =>
                      setState(() => _obscureConfirm = !_obscureConfirm),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Konfirmasi kata sandi wajib diisi';
                    }
                    if (val.trim() != _newPasswordController.text.trim()) {
                      return 'Konfirmasi kata sandi tidak cocok';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 3. Checklist Ketentuan Interaktif (Bergaya Quest Gamifikasi Nihaoki)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 6,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.checklist_rounded, size: 18, color: _themeAmber),
                    SizedBox(width: 6),
                    Text(
                      'Ketentuan Kata Sandi',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildRequirementItem('Minimal 6 karakter', _hasMinLength),
                const SizedBox(height: 8),
                _buildRequirementItem(
                  'Berbeda dari kata sandi saat ini',
                  _isDifferentFromOld,
                ),
                const SizedBox(height: 8),
                _buildRequirementItem(
                  'Konfirmasi kata sandi cocok',
                  _isMatching,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 4. Tombol Aksi Utama (Gradient Sunset Orange & Amber)
          SizedBox(
            width: double.infinity,
            height: 52,
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_themePrimary, _themeDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(26),
                boxShadow: [
                  BoxShadow(
                    color: _themePrimary.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26),
                  ),
                ),
                onPressed: _isLoading ? null : _handleSubmit,
                child: _isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.lock_reset_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Simpan Kata Sandi Baru',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildFieldLabel(String text, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          Icon(icon, size: 16, color: _themeDark),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF334155),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String hintText,
    required bool obscureText,
    required VoidCallback onToggleObscure,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      validator: validator,
      style: const TextStyle(
        fontSize: 14,
        color: AppColors.textDark,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(
          fontSize: 13,
          color: AppColors.textLight,
          fontWeight: FontWeight.normal,
        ),
        filled: true,
        fillColor: const Color(0xFFFFFDFB),
        suffixIcon: IconButton(
          icon: Icon(
            obscureText
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            size: 20,
            color: const Color(0xFF94A3B8),
          ),
          onPressed: onToggleObscure,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 13,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _themePrimary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.error),
        ),
      ),
    );
  }

  Widget _buildRequirementItem(String label, bool isSatisfied) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: isSatisfied ? _themeSoftBg : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSatisfied ? _themeBorder : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: isSatisfied ? _themePrimary : const Color(0xFFCBD5E1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(
                isSatisfied ? Icons.check_rounded : Icons.circle,
                size: isSatisfied ? 13 : 6,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSatisfied ? FontWeight.w700 : FontWeight.w500,
                color: isSatisfied ? AppColors.textDark : AppColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
