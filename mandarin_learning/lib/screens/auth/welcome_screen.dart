import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/chinese_scenery_background.dart';
import '../../widgets/mascot_widget.dart';
import '../home/main_navigation_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  
  bool _isLogin = true;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handleAuth() async {
    final auth = context.read<AuthProvider>();

    if (_isLogin) {
      if (_identifierController.text.trim().isEmpty || _passwordController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Silakan masukkan email/telepon dan kata sandi.'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      final success = await auth.login(
        _identifierController.text.trim(),
        _passwordController.text,
      );

      if (!mounted) return;

      if (success) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(auth.errorMessage ?? 'Gagal masuk. Periksa kredensial Anda.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } else {
      if (_nameController.text.trim().isEmpty ||
          _identifierController.text.trim().isEmpty ||
          _passwordController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Silakan lengkapi nama, email, dan kata sandi.'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      final success = await auth.register(
        _identifierController.text.trim(),
        _passwordController.text,
        _nameController.text.trim(),
      );

      if (!mounted) return;

      if (success) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(auth.errorMessage ?? 'Gagal mendaftar.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _handleGuestLogin() async {
    final auth = context.read<AuthProvider>();
    await auth.loginAsGuest();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      body: ChineseSceneryBackground(
        showPagoda: true,
        showLanterns: true,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  // Mascot Header Waving with Chinese Lanterns
                  const Center(
                    child: MascotWidget(
                      size: 150,
                      pose: MascotPose.waving,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Heading "Selamat Datang!"
                  Text(
                    _isLogin ? 'Selamat Datang!' : 'Buat Akun Baru',
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Ayo mulai perjalanan belajarmu\nbahasa Mandarin!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textMuted,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Registration Name field (only if registering)
                  if (!_isLogin) ...[
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          hintText: 'Nama Lengkap',
                          prefixIcon: Icon(Icons.badge_outlined, color: AppColors.textMuted),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // Email / Nomor Telepon
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _identifierController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        hintText: 'Email / Nomor Telepon',
                        prefixIcon: Icon(Icons.person_outline_rounded, color: AppColors.textMuted),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Kata Sandi
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        hintText: 'Kata Sandi',
                        prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.textMuted),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            color: AppColors.textMuted,
                          ),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                    ),
                  ),

                  // Lupa kata sandi?
                  if (_isLogin) ...[
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Fitur reset kata sandi dikirimkan ke email terdaftar.'),
                            ),
                          );
                        },
                        child: const Text(
                          'Lupa kata sandi?',
                          style: TextStyle(
                            color: AppColors.primaryDark,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 16),
                  ],

                  // Masuk Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: auth.isLoading ? null : _handleAuth,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(26),
                        ),
                      ),
                      child: auth.isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                            )
                          : Text(
                              _isLogin ? 'Masuk' : 'Daftar Sekarang',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Mode Tamu / Demo Cepat
                  TextButton.icon(
                    onPressed: _handleGuestLogin,
                    icon: const Icon(Icons.offline_bolt_rounded, size: 18, color: AppColors.primaryDark),
                    label: const Text(
                      'Coba Langsung Tanpa Akun (Mode Tamu)',
                      style: TextStyle(color: AppColors.primaryDark, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Divider "atau lanjut dengan"
                  Row(
                    children: [
                      const Expanded(child: Divider(color: Color(0xFFD1E7DD), thickness: 1)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Text(
                          'atau lanjut dengan',
                          style: TextStyle(fontSize: 12, color: AppColors.textMuted.withValues(alpha: 0.8)),
                        ),
                      ),
                      const Expanded(child: Divider(color: Color(0xFFD1E7DD), thickness: 1)),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Social Buttons (Google, Apple, Facebook)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildSocialButton(
                        onTap: _handleGuestLogin,
                        child: const Text('G', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Color(0xFFEA4335))),
                      ),
                      const SizedBox(width: 18),
                      _buildSocialButton(
                        onTap: _handleGuestLogin,
                        child: const Icon(Icons.apple, size: 26, color: Colors.black),
                      ),
                      const SizedBox(width: 18),
                      _buildSocialButton(
                        onTap: _handleGuestLogin,
                        child: const Text('f', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Color(0xFF1877F2))),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Belum punya akun? Daftar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _isLogin ? 'Belum punya akun? ' : 'Sudah punya akun? ',
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                      ),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _isLogin = !_isLogin;
                          });
                        },
                        child: Text(
                          _isLogin ? 'Daftar' : 'Masuk',
                          style: const TextStyle(
                            color: AppColors.primaryDark,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSocialButton({required Widget child, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(26),
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Center(child: child),
      ),
    );
  }
}
