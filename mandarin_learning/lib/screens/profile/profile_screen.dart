import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/vocabulary_provider.dart';
import '../../widgets/mascot_widget.dart';
import '../auth/landing_screen.dart';
import '../auth/register_screen.dart';
import '../practice/dictionary_screen.dart';
import '../tools/feedback_screen.dart';
import '../settings/settings_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final vocab = context.watch<VocabularyProvider>();
    final user = auth.profile;
    final fullName = user?.fullName ?? 'Pelajar Mandarin';
    final username = user?.username ?? '';

    return Scaffold(
      backgroundColor: AppColors.mintBackground,
      appBar: AppBar(
        title: const Text('Profil'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: AppColors.textDark),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Bottom Pagoda & Garden Landscape decoration
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 120,
            child: Opacity(
              opacity: 0.6,
              child: CustomPaint(
                painter: _BottomPagodaPainter(),
              ),
            ),
          ),

          // Main Scroll Content
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Column(
                children: [
                  // Avatar & Name Header
                  Center(
                    child: Column(
                      children: [
                        Container(
                          width: 86,
                          height: 86,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFFDCFCE7),
                            border: Border.all(color: AppColors.primary, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: MascotWidget(size: 78, pose: MascotPose.headOnly),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          fullName,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                        ),
                        if (username.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            '@$username',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryDark,
                            ),
                          ),
                        ],
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                          decoration: BoxDecoration(
                            color: auth.isGuest ? const Color(0xFFFEF3C7) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: auth.isGuest ? const Color(0xFFF59E0B).withValues(alpha: 0.5) : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(auth.isGuest ? '👤' : '🥈', style: const TextStyle(fontSize: 14)),
                              const SizedBox(width: 6),
                              Text(
                                auth.isGuest ? 'Mode Tamu' : 'Silver',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: auth.isGuest ? const Color(0xFF92400E) : const Color(0xFF475569),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (auth.isGuest) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.6)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline_rounded, color: Color(0xFFB45309), size: 20),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text(
                                    'Akses terbatas: progres & koin tidak disimpan.',
                                    style: TextStyle(fontSize: 11, color: Color(0xFF78350F)),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFD97706),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    elevation: 0,
                                  ),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => const RegisterScreen()),
                                    );
                                  },
                                  child: const Text('Daftar', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 3 Stat Cards in a row (Streak, XP, Peringkat)
                  Row(
                    children: [
                      Expanded(
                        child: _buildProfileStatCard(
                          icon: '🔥',
                          title: 'Streak',
                          value: '${auth.streak}',
                          unit: 'hari',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildProfileStatCard(
                          icon: '💎',
                          title: 'XP',
                          value: '${auth.isGuest ? auth.totalXp : (auth.totalXp > 0 ? auth.totalXp : 320)}',
                          unit: 'Total XP',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildProfileStatCard(
                          icon: '🪙',
                          title: 'Koin',
                          value: '${auth.coins}',
                          unit: 'Tersedia',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Section Title
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Menu Pembelajaran',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Menu Items
                  _buildMenuItem(
                    context,
                    icon: Icons.auto_stories_rounded,
                    title: 'Hasil & Progres Belajar',
                    onTap: () {
                      _showStudySummary(context, vocab, auth);
                    },
                  ),

                  _buildMenuItem(
                    context,
                    icon: Icons.menu_book_rounded,
                    title: 'Kamus Lengkap HSK 1–6',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const DictionaryScreen()),
                      );
                    },
                  ),

                  _buildMenuItem(
                    context,
                    icon: Icons.rate_review_outlined,
                    title: 'Beri Ulasan & Masukan (Feedback)',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const FeedbackScreen()),
                      );
                    },
                  ),

                  _buildMenuItem(
                    context,
                    icon: Icons.help_outline_rounded,
                    title: 'Bantuan & FAQ',
                    onTap: () {
                      _showFaqDialog(context);
                    },
                  ),

                  _buildMenuItem(
                    context,
                    icon: Icons.info_outline_rounded,
                    title: 'Tentang Aplikasi',
                    onTap: () {
                      _showAboutDialog(context);
                    },
                  ),

                  const SizedBox(height: 20),

                  // Tombol Logout
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: Color(0xFFFCA5A5)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      ),
                      icon: const Icon(Icons.logout_rounded, size: 20),
                      label: Text(auth.isGuest ? 'Keluar dari Mode Tamu' : 'Keluar dari Akun (Logout)', style: const TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () async {
                        await auth.logout();
                        if (context.mounted) {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(builder: (_) => const LandingScreen()),
                            (route) => false,
                          );
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileStatCard({
    required String icon,
    required String title,
    required String value,
    required String unit,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(icon, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 6),
          Text(
            title,
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          Text(
            unit,
            style: const TextStyle(fontSize: 10, color: AppColors.textLight),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
          leading: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primaryDark, size: 22),
          ),
          title: Text(
            title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textDark),
          ),
          trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textLight),
          onTap: onTap,
        ),
      ),
    );
  }

  void _showStudySummary(BuildContext context, VocabularyProvider vocab, AuthProvider auth) {
    final progress = vocab.getLevelProgress(vocab.selectedLevel);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Hasil & Progres Belajar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.school, color: AppColors.primary),
              title: Text('Tingkat Aktif: HSK ${vocab.selectedLevel}'),
              subtitle: Text('${(progress * 100).toInt()}% dari materi level telah dipelajari'),
            ),
            ListTile(
              leading: const Icon(Icons.stars_rounded, color: AppColors.coinGold),
              title: Text('Saldo Koin: ${auth.coins} 🪙'),
              subtitle: const Text('Koin dapat digunakan untuk petunjuk kuis & mini game'),
            ),
          ],
        ),
      ),
    );
  }

  void _showFaqDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Bantuan & FAQ'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Bagaimana cara belajar pelafalan?', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('Gunakan menu Latihan Pelafalan di tab Latihan. Rekam suaramu dengan mikrofon dan sistem akan mengevaluasi kontur nada Mandarin Anda.\n'),
              Text('Untuk apa koin digunakan?', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('Koin dapat digunakan untuk membuka bantuan petunjuk di Kuis Tebak Arti (20 koin) dan mini-game Hanzi.\n'),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Mengerti')),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Tentang Aplikasi'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MascotWidget(size: 60, pose: MascotPose.headOnly),
            SizedBox(height: 12),
            Text(
              'Aplikasi Pembelajaran Mandarin untuk Pemula\nVersi 1.0 (HSK 1-6)',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Dilengkapi Autentikasi Enkripsi SHA-256, Sesi Login, Biometrik Sidik Jari, Penyimpanan Database Lokal SQLite & Online Supabase.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tutup')),
        ],
      ),
    );
  }
}

class _BottomPagodaPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFC7EBC8).withValues(alpha: 0.6)
      ..style = PaintingStyle.fill;

    // Rolling hill
    final path = Path();
    path.moveTo(0, size.height * 0.6);
    path.quadraticBezierTo(size.width * 0.4, size.height * 0.3, size.width, size.height * 0.7);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    canvas.drawPath(path, paint);

    // Pagoda silhouette on right
    final px = size.width * 0.85;
    final py = size.height * 0.35;
    final pagodaPaint = Paint()
      ..color = const Color(0xFF5A8E5C).withValues(alpha: 0.4)
      ..style = PaintingStyle.fill;

    // Roof 1
    final r1 = Path()
      ..moveTo(px - 14, py)
      ..quadraticBezierTo(px, py - 4, px + 14, py)
      ..lineTo(px + 8, py - 6)
      ..quadraticBezierTo(px, py - 7, px - 8, py - 6)
      ..close();
    canvas.drawPath(r1, pagodaPaint);

    // Roof 2
    final r2 = Path()
      ..moveTo(px - 18, py + 8)
      ..quadraticBezierTo(px, py + 4, px + 18, py + 8)
      ..lineTo(px + 12, py + 2)
      ..quadraticBezierTo(px, py + 1, px - 12, py + 2)
      ..close();
    canvas.drawPath(r2, pagodaPaint);

    canvas.drawRect(Rect.fromLTWH(px - 10, py + 8, 20, 16), pagodaPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
