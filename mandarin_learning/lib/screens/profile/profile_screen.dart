import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/vocabulary_provider.dart';
import '../../widgets/avatar_picker_modal.dart';
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
    final fullName = user?.fullName ?? (auth.isGuest ? 'Tamu' : 'Pelajar Mandarin');
    final username = user?.username ?? (auth.isGuest ? 'tamu' : 'pelajar');
    final avatarUrl = (user?.avatarUrl != null && user!.avatarUrl.isNotEmpty)
        ? user.avatarUrl
        : 'assets/image/register/09_mascot_head.png';

    // Tier badge calculation
    String badgeEmoji = '🥈';
    String badgeTitle = 'Silver';
    if (auth.isGuest) {
      badgeEmoji = '👤';
      badgeTitle = 'Mode Tamu';
    } else {
      final xp = auth.totalXp;
      if (xp >= 500) {
        badgeEmoji = '🥇';
        badgeTitle = 'Gold';
      } else if (xp >= 150) {
        badgeEmoji = '🥈';
        badgeTitle = 'Silver';
      } else {
        badgeEmoji = '🥉';
        badgeTitle = 'Bronze';
      }
    }

    Widget buildAvatarImage() {
      if (avatarUrl.startsWith('http://') || avatarUrl.startsWith('https://')) {
        return Image.network(
          avatarUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Image.asset(
            'assets/image/register/09_mascot_head.png',
            fit: BoxFit.contain,
          ),
        );
      }
      return Image.asset(
        avatarUrl,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => Image.asset(
          'assets/image/register/09_mascot_head.png',
          fit: BoxFit.contain,
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF1F8F4),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Profil',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E3A24),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              ),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1E3A24).withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.settings_outlined,
                  color: Color(0xFF1E3A24),
                  size: 22,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Background Gradient
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFFE2F3F5),
                    Color(0xFFF3FBF5),
                    Color(0xFFEAF8EF),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),

          // Bottom Flower Bushes / Meadow (Mockup asset)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 110,
            child: IgnorePointer(
              child: Image.asset(
                'assets/image/beranda/semak_bunga_besar.png',
                fit: BoxFit.fill,
                errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
              ),
            ),
          ),

          // Scrollable Content
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Main Green Profile Card
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF1B4D2E),
                          Color(0xFF26663E),
                          Color(0xFF1E5631),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1E3A24).withValues(alpha: 0.18),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      children: [
                        // Decorative leaf overlays in background corners
                        Positioned(
                          right: -10,
                          top: -10,
                          width: 140,
                          height: 140,
                          child: Opacity(
                            opacity: 0.22,
                            child: Image.asset(
                              'assets/image/beranda/daun_lebat.png',
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                            ),
                          ),
                        ),
                        Positioned(
                          right: 15,
                          bottom: -20,
                          width: 110,
                          height: 110,
                          child: Opacity(
                            opacity: 0.25,
                            child: Image.asset(
                              'assets/image/beranda/daun_lebat.png',
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                            ),
                          ),
                        ),
                        Positioned(
                          left: -15,
                          bottom: -15,
                          width: 80,
                          height: 80,
                          child: Opacity(
                            opacity: 0.20,
                            child: Image.asset(
                              'assets/image/beranda/daun_tunas.png',
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                            ),
                          ),
                        ),

                        // Card Content
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
                          child: Row(
                            children: [
                              // Avatar with Glowing Rings & Edit Button
                              GestureDetector(
                                onTap: () => showAvatarPickerModal(context, auth),
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    // Outer Glowing Ring
                                    Container(
                                      width: 86,
                                      height: 86,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.white.withValues(alpha: 0.12),
                                        border: Border.all(
                                          color: Colors.white.withValues(alpha: 0.40),
                                          width: 2.5,
                                        ),
                                      ),
                                      padding: const EdgeInsets.all(5),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: const Color(0xFFDCFCE7),
                                          border: Border.all(
                                            color: Colors.white,
                                            width: 2.0,
                                          ),
                                        ),
                                        padding: const EdgeInsets.all(3),
                                        child: ClipOval(
                                          child: buildAvatarImage(),
                                        ),
                                      ),
                                    ),

                                    // Edit Pencil Button
                                    Positioned(
                                      bottom: 0,
                                      right: 0,
                                      child: Container(
                                        width: 26,
                                        height: 26,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: const Color(0xFF16A34A),
                                          border: Border.all(
                                            color: Colors.white,
                                            width: 2,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(alpha: 0.25),
                                              blurRadius: 4,
                                              offset: const Offset(0, 1),
                                            ),
                                          ],
                                        ),
                                        child: const Center(
                                          child: Icon(
                                            Icons.edit_rounded,
                                            size: 13,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 18),

                              // Name, Username & Tier Pill
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Full Name + Sprout Icon
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            fullName,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 22,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: -0.3,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Image.asset(
                                          'assets/image/beranda/daun_tunas.png',
                                          width: 20,
                                          height: 20,
                                          errorBuilder: (context, error, stackTrace) => const Text(
                                            '🌱',
                                            style: TextStyle(fontSize: 16),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),

                                    // Username
                                    Text(
                                      '@$username',
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.82),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 10),

                                    // Tier Badge Pill
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(20),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.08),
                                            blurRadius: 6,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(badgeEmoji, style: const TextStyle(fontSize: 13)),
                                          const SizedBox(width: 6),
                                          Text(
                                            badgeTitle,
                                            style: const TextStyle(
                                              color: Color(0xFF1E3A24),
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Guest Notice (if in guest mode)
                  if (auth.isGuest) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded, color: Color(0xFFB45309), size: 20),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Mode Tamu: Progres belajar & koin tidak disimpan.',
                              style: TextStyle(fontSize: 12, color: Color(0xFF78350F)),
                            ),
                          ),
                          const SizedBox(width: 6),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFD97706),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const RegisterScreen()),
                              );
                            },
                            child: const Text('Daftar', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // 3 Stat Cards Row: Streak, XP, Koin
                  Row(
                    children: [
                      // Streak
                      Expanded(
                        child: _buildProfileStatCard(
                          iconEmoji: '🔥',
                          iconBgColor: const Color(0xFFFEF3C7),
                          title: 'Streak',
                          value: '${auth.streak}',
                          unit: 'hari',
                        ),
                      ),
                      const SizedBox(width: 12),

                      // XP
                      Expanded(
                        child: _buildProfileStatCard(
                          iconEmoji: '💎',
                          iconBgColor: const Color(0xFFE0F2FE),
                          title: 'XP',
                          value: '${auth.isGuest ? auth.totalXp : (auth.totalXp > 0 ? auth.totalXp : 185)}',
                          unit: 'Total XP',
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Koin
                      Expanded(
                        child: _buildProfileStatCard(
                          iconEmoji: '🪙',
                          iconBgColor: const Color(0xFFFEF9C3),
                          title: 'Koin',
                          value: '${auth.isGuest ? auth.coins : (auth.coins > 0 ? auth.coins : 185)}',
                          unit: 'Tersedia',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Section Title: Menu Pembelajaran
                  Row(
                    children: [
                      Image.asset(
                        'assets/image/beranda/daun_tunas.png',
                        width: 22,
                        height: 22,
                        errorBuilder: (context, error, stackTrace) => const Text('🌱', style: TextStyle(fontSize: 18)),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Menu Pembelajaran',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E3A24),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Menu 1: Hasil & Progres Belajar
                  _buildMenuCard(
                    context,
                    title: 'Hasil & Progres Belajar',
                    iconAsset: 'assets/image/beranda/ikon_buku.png',
                    fallbackIcon: Icons.menu_book_rounded,
                    onTap: () => _showStudySummary(context, vocab, auth),
                  ),

                  // Menu 2: Kamus Lengkap HSK 1–6
                  _buildMenuCard(
                    context,
                    title: 'Kamus Lengkap HSK 1–6',
                    iconAsset: 'assets/image/beranda/ikon_terjemah.png',
                    fallbackIcon: Icons.import_contacts_rounded,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const DictionaryScreen()),
                      );
                    },
                  ),

                  // Menu 3: Beri Ulasan & Masukan
                  _buildMenuCard(
                    context,
                    title: 'Beri Ulasan & Masukan (Feedback)',
                    iconAsset: 'assets/image/beranda/ikon_surat.png',
                    fallbackIcon: Icons.rate_review_outlined,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const FeedbackScreen()),
                      );
                    },
                  ),

                  // Menu 4: Bantuan & FAQ
                  _buildMenuCard(
                    context,
                    title: 'Bantuan & FAQ',
                    fallbackIcon: Icons.help_outline_rounded,
                    onTap: () => _showFaqDialog(context),
                  ),

                  // Menu 5: Tentang Aplikasi
                  _buildMenuCard(
                    context,
                    title: 'Tentang Aplikasi',
                    fallbackIcon: Icons.info_outline_rounded,
                    onTap: () => _showAboutDialog(context),
                  ),

                  const SizedBox(height: 18),

                  // Logout Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: Color(0xFFFCA5A5), width: 1.2),
                        backgroundColor: Colors.white.withValues(alpha: 0.8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.logout_rounded, size: 20),
                      label: Text(
                        auth.isGuest ? 'Keluar dari Mode Tamu' : 'Keluar dari Akun (Logout)',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
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

                  // Ample padding for floating translucent bottom navbar
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileStatCard({
    required String iconEmoji,
    required Color iconBgColor,
    required String title,
    required String value,
    required String unit,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3A24).withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // Emoji with soft circular background
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: iconBgColor,
            ),
            child: Center(
              child: Text(
                iconEmoji,
                style: const TextStyle(fontSize: 22),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E3A24),
            ),
          ),
          const SizedBox(height: 1),
          Text(
            unit,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuCard(
    BuildContext context, {
    required String title,
    String? iconAsset,
    required IconData fallbackIcon,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3A24).withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // Rounded leading icon
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: iconAsset != null
                        ? Image.asset(
                            iconAsset,
                            width: 24,
                            height: 24,
                            errorBuilder: (context, error, stackTrace) => Icon(
                              fallbackIcon,
                              color: const Color(0xFF16A34A),
                              size: 22,
                            ),
                          )
                        : Icon(
                            fallbackIcon,
                            color: const Color(0xFF16A34A),
                            size: 22,
                          ),
                  ),
                ),
                const SizedBox(width: 14),

                // Title
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E3A24),
                    ),
                  ),
                ),

                // Trailing Chevron
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF94A3B8),
                  size: 24,
                ),
              ],
            ),
          ),
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
            const Text(
              'Hasil & Progres Belajar',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E3A24),
              ),
            ),
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
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/image/register/09_mascot_head.png',
              width: 60,
              height: 60,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const Icon(Icons.school, size: 40, color: Color(0xFF16A34A)),
            ),
            const SizedBox(height: 12),
            const Text(
              'Aplikasi Pembelajaran Mandarin untuk Pemula\nVersi 1.0 (HSK 1-6)',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
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
