import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/vocabulary_provider.dart';
import '../auth/welcome_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final vocab = context.watch<VocabularyProvider>();
    final user = auth.profile;
    final fullName = user?.fullName ?? 'Pelajar Mandarin';
    final isGuest = auth.isGuest;

    return Scaffold(
      backgroundColor: AppColors.mintBackground,
      appBar: AppBar(
        title: const Text('Profil & Pengaturan'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            children: [
              // Kartu Profil
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primaryLight,
                        border: Border.all(color: AppColors.primary, width: 3),
                      ),
                      child: const Center(
                        child: Text('🐼', style: TextStyle(fontSize: 40)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      fullName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isGuest ? const Color(0xFFFEF3C7) : AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        isGuest ? 'Mode Tamu (Offline)' : 'Akun Terdaftar di Supabase',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isGuest ? const Color(0xFFB45309) : AppColors.primaryDark,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Grid Statistik Singkat
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildProfileStat('🔥', '${auth.streak}', 'Hari Streak'),
                        _buildProfileStat('🪙', '${auth.coins}', 'Saldo Koin'),
                        _buildProfileStat('⭐', '${auth.totalXp}', 'Total XP'),
                        _buildProfileStat('📚', 'HSK ${vocab.selectedLevel}', 'Tingkat'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Menu Opsi
              Container(
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.school_outlined, color: AppColors.primary),
                      title: const Text('Target Level HSK', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('Sedang fokus di HSK ${vocab.selectedLevel}'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () {
                        _showLevelPicker(context, vocab, auth);
                      },
                    ),
                    const Divider(height: 1, color: AppColors.divider),
                    ListTile(
                      leading: const Icon(Icons.notifications_outlined, color: AppColors.primary),
                      title: const Text('Pengingat Belajar', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: const Text('Setiap hari pukul 19:00 WIB'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                    ),
                    const Divider(height: 1, color: AppColors.divider),
                    ListTile(
                      leading: const Icon(Icons.feedback_outlined, color: AppColors.primary),
                      title: const Text('Kirim Umpan Balik', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: const Text('Beri masukan untuk pengembangan'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Tombol Keluar
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                  ),
                  onPressed: () async {
                    await auth.logout();
                    if (context.mounted) {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                        (route) => false,
                      );
                    }
                  },
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Keluar dari Akun', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileStat(String emoji, String val, String label) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 4),
        Text(val, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
      ],
    );
  }

  void _showLevelPicker(BuildContext context, VocabularyProvider vocab, AuthProvider auth) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Pilih Target Level HSK'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(6, (idx) {
              final lvl = idx + 1;
              return ListTile(
                title: Text('HSK Level $lvl'),
                selected: vocab.selectedLevel == lvl,
                trailing: vocab.selectedLevel == lvl
                    ? const Icon(Icons.check_circle_rounded, color: AppColors.primary)
                    : null,
                onTap: () {
                  vocab.setLevel(lvl);
                  auth.setHskLevel(lvl);
                  Navigator.pop(ctx);
                },
              );
            }),
          ),
        );
      },
    );
  }
}
