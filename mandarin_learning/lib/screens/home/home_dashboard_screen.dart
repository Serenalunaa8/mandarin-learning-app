import '../../widgets/avatar_image_helper.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/vocabulary_provider.dart';
import '../practice/speech_practice_screen.dart';
import '../practice/quiz_screen.dart';
import '../games/hanzi_matching_screen.dart';
import '../games/stroke_challenge_screen.dart';
import '../games/tilt_to_answer_screen.dart';
import '../games/mandarin_catcher_screen.dart';
import '../coins/coin_ledger_screen.dart';
import '../auth/register_screen.dart';
import '../lesson/lesson_path_screen.dart';
import '../tools/direction_explorer_screen.dart';
import '../tools/currency_converter_screen.dart';
import '../tools/time_converter_screen.dart';
import '../../widgets/daily_goal_modal.dart';

class HomeDashboardScreen extends StatefulWidget {
  final Function(int) onNavigateTab;

  const HomeDashboardScreen({super.key, required this.onNavigateTab});

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen> {
  Timer? _tickerTimer;

  @override
  void initState() {
    super.initState();
    _tickerTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tickerTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final vocab = context.watch<VocabularyProvider>();
    final user = auth.profile;
    final avatarUrl = (user?.avatarUrl != null && user!.avatarUrl.isNotEmpty)
        ? user.avatarUrl
        : 'assets/image/register/09_mascot_head.png';
    final fullName = user?.fullName ?? 'Aria';
    final firstName = auth.isGuest ? 'Tamu' : fullName.split(' ').first;
    final level = vocab.selectedLevel;
    final progress = vocab.getLevelProgress(level);
    final displayProgress = progress;
    final cardCategory = auth.isGuest
        ? 'Mulai Belajar'
        : 'Lanjutkan Pembelajaran';
    final cardSubtitle = auth.isGuest
        ? 'Pelajaran 1 · Mulai Belajar Mandarin'
        : 'Pelajaran 3 · Salam dan Perkenalan';
    final cardProgressValue = auth.isGuest
        ? 0.0
        : (displayProgress == 0 ? 0.6 : displayProgress);
    final cardProgressText = auth.isGuest
        ? '0%'
        : '${((displayProgress == 0 ? 0.6 : displayProgress) * 100).toInt()}%';
    final cardButtonText = auth.isGuest ? 'Mulai  →' : 'Lanjut  →';
    final targetMin = auth.dailyGoalMinutes;
    final activeSeconds = auth.activeStudySecondsToday;
    final learnedMin = auth.activeStudyMinutesToday;
    final dailyGoalRatio = auth.dailyGoalProgressRatio;
    final String dailyGoalProgressText = (learnedMin == 0 && activeSeconds > 0)
        ? '0 / $targetMin menit ($activeSeconds dtk)'
        : '$learnedMin / $targetMin menit';

    return Scaffold(
      backgroundColor: const Color(0xFFF1F8F4),
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFE2F3F5), Color(0xFFF3FBF5), Color(0xFFEAF8EF)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Bar: Mascot Avatar, Streak, Gems, Bell
                Row(
                  children: [
                    // Mascot Avatar Button (Sama dengan halaman Profil)
                    GestureDetector(
                      onTap: () => widget.onNavigateTab(4),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFDCFCE7),
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF1E3A24)
                                  .withValues(alpha: 0.08),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(2),
                        child: Center(
                          child: ClipOval(
                            child: buildUserAvatarWidget(
                              avatarUrl,
                              width: 38,
                              height: 38,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    // Streak Pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('🔥', style: TextStyle(fontSize: 14)),
                          const SizedBox(width: 4),
                          Text(
                            '${auth.streak}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Color(0xFF1E3A24),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Coin Pill (Ganti diamond jadi koin)
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CoinLedgerScreen(),
                        ),
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('🪙', style: TextStyle(fontSize: 13)),
                            const SizedBox(width: 4),
                            Text(
                              '${auth.isGuest ? auth.coins : (auth.coins > 0 ? auth.coins : 120)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Color(0xFF1E3A24),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Bell Pill
                    GestureDetector(
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Belum ada notifikasi baru.'),
                          ),
                        );
                      },
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.notifications_none_rounded,
                          size: 20,
                          color: Color(0xFF374151),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Guest Mode Banner jika sedang menggunakan mode tamu
                if (auth.isGuest) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.6),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.amber.withValues(alpha: 0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFDE68A),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.info_outline_rounded,
                            color: Color(0xFFB45309),
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Mode Tamu (Akses Terbatas)',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Color(0xFF92400E),
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Progres belajar & koin tidak disimpan.',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF78350F),
                                ),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          style: TextButton.styleFrom(
                            backgroundColor: const Color(0xFFD97706),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const RegisterScreen(),
                              ),
                            );
                          },
                          child: const Text(
                            'Daftar',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Greeting Header with Background Landscape & Mascot Peak
                SizedBox(
                  height: 120,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Background meadow hills
                      Positioned(
                        left: -20,
                        right: -20,
                        bottom: -10,
                        top: 0,
                        child: Opacity(
                          opacity: 0.45,
                          child: Image.asset(
                            'assets/image/beranda/bg_siang.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      // Greeting text (Note: 'Terus semangat, kamu pasti bisa!' has been removed per user instruction)
                      Positioned(
                        left: 0,
                        top: 24,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Halo, $firstName!',
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1E3A24),
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Mascot sitting on the hills holding a star with sparkles
                      Positioned(
                        right: 8,
                        bottom: 0,
                        child: Image.asset(
                          'assets/image/beranda/maskot_01_bintang.png',
                          height: 115,
                          fit: BoxFit.contain,
                        ),
                      ),
                      // Sparkle 1
                      Positioned(
                        right: 110,
                        top: 30,
                        child: Image.asset(
                          'assets/image/beranda/kilau_01.png',
                          width: 14,
                          fit: BoxFit.contain,
                        ),
                      ),
                      // Sparkle 2
                      Positioned(
                        right: 0,
                        top: 22,
                        child: Image.asset(
                          'assets/image/beranda/kilau_02.png',
                          width: 14,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // "Lanjutkan Pembelajaran" Card (Dark Forest Green Container)
                Container(
                  width: double.infinity,
                  height: 185,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF225534), Color(0xFF17472A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF17472A).withValues(alpha: 0.28),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Stack(
                      children: [
                        // Grassy hill background contour at bottom right
                        Positioned(
                          right: -25,
                          bottom: -30,
                          child: Container(
                            width: 190,
                            height: 120,
                            decoration: BoxDecoration(
                              color: const Color(0xFF133F23),
                              borderRadius: BorderRadius.circular(100),
                            ),
                          ),
                        ),
                        // Small white flowers along the mound
                        Positioned(
                          bottom: 10,
                          right: 125,
                          child: Image.asset(
                            'assets/image/beranda/bunga_putih_2.png',
                            width: 14,
                            fit: BoxFit.contain,
                          ),
                        ),
                        Positioned(
                          bottom: 8,
                          right: 32,
                          child: Image.asset(
                            'assets/image/beranda/bunga_putih_2.png',
                            width: 12,
                            fit: BoxFit.contain,
                          ),
                        ),

                        // Floating badges around mascot
                        // Top-left badge: yellow star coin
                        Positioned(
                          top: 26,
                          right: 110,
                          child: Image.asset(
                            'assets/image/beranda/koin.png',
                            width: 22,
                            height: 22,
                            fit: BoxFit.contain,
                          ),
                        ),
                        // Bottom-left badge: purple star badge
                        Positioned(
                          bottom: 48,
                          right: 120,
                          child: Image.asset(
                            'assets/image/beranda/ikon_bintang_ungu.png',
                            width: 22,
                            height: 22,
                            fit: BoxFit.contain,
                          ),
                        ),
                        // Top-right badge: pink user badge
                        Positioned(
                          top: 28,
                          right: 18,
                          child: Image.asset(
                            'assets/image/beranda/ikon_profil.png',
                            width: 22,
                            height: 22,
                            fit: BoxFit.contain,
                          ),
                        ),
                        // Bottom-right badge: cyan shield badge
                        Positioned(
                          bottom: 42,
                          right: 10,
                          child: Image.asset(
                            'assets/image/beranda/ikon_perisai.png',
                            width: 22,
                            height: 22,
                            fit: BoxFit.contain,
                          ),
                        ),

                        // Mascot sitting with star on the mound
                        Positioned(
                          right: 28,
                          bottom: 8,
                          child: Image.asset(
                            'assets/image/beranda/maskot_01_bintang.png',
                            height: 105,
                            fit: BoxFit.contain,
                          ),
                        ),

                        // Left content: Lesson Info, Progress, and Lanjut Button
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 16,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    cardCategory,
                                    style: const TextStyle(
                                      color: Color(0xFFB8E6C4),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  const Text(
                                    'Percakapan Sehari-hari',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    cardSubtitle,
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.85,
                                      ),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    width: 165,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                          child: LinearProgressIndicator(
                                            value: cardProgressValue,
                                            minHeight: 7,
                                            backgroundColor: const Color(
                                              0xFF133F23,
                                            ),
                                            valueColor:
                                                const AlwaysStoppedAnimation<
                                                  Color
                                                >(Color(0xFF52E686)),
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          cardProgressText,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFDCFCE7),
                                      foregroundColor: const Color(0xFF1E5631),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 20,
                                        vertical: 8,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      elevation: 0,
                                      minimumSize: Size.zero,
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const LessonPathScreen(),
                                        ),
                                      );
                                    },
                                    child: Text(
                                      cardButtonText,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: Color(0xFF1E3A24),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // "Tujuan Hari Ini" Card
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
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
                  child: Row(
                    children: [
                      Image.asset(
                        'assets/image/beranda/ikon_kalender.png',
                        width: 44,
                        height: 44,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Tujuan Hari Ini',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1E3A24),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () =>
                                      showDailyGoalBottomSheet(context, auth),
                                  child: const Text(
                                    'Edit',
                                    style: TextStyle(
                                      color: Color(0xFF16A34A),
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Belajar selama $targetMin menit',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Color(0xFF1F2937),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              dailyGoalProgressText,
                              style: const TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: dailyGoalRatio,
                                backgroundColor: const Color(0xFFE2E8F0),
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  Color(0xFF16A34A),
                                ),
                                minHeight: 6,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // "Latihan Cepat" Section Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Latihan Cepat',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E3A24),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => widget.onNavigateTab(2), // Tab Praktik
                      child: const Row(
                        children: [
                          Text(
                            'AI Tutor',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF225232),
                            ),
                          ),
                          SizedBox(width: 2),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 18,
                            color: Color(0xFF225232),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                GridView.count(
                  crossAxisCount: 4,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 2,
                  mainAxisSpacing: 4,
                  childAspectRatio: 0.95,
                  children: [
                    _buildQuickActionItem(
                      imageAsset:
                          'assets/image/icon_beranda/kuis_artipinyin.png',
                      color: const Color(0xFFE76F51),
                      title: 'Kuis Arti & Pinyin',
                      onTap: () => _openQuickFeature(
                        context,
                        isGuest: auth.isGuest,
                        builder: (_) => const QuizScreen(),
                      ),
                    ),
                    _buildQuickActionItem(
                      imageAsset: 'assets/image/icon_beranda/pelafalan.png',
                      color: const Color(0xFF398A9A),
                      title: 'Pelafalan & Nada',
                      onTap: () {
                        final words = vocab.currentLevelVocabulary;
                        final targetWord = words.isNotEmpty
                            ? words.first
                            : null;
                        if (targetWord == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Kosakata latihan belum tersedia.'),
                            ),
                          );
                          return;
                        }
                        _openQuickFeature(
                          context,
                          isGuest: auth.isGuest,
                          builder: (_) =>
                              SpeechPracticeScreen(item: targetWord),
                        );
                      },
                    ),
                    _buildQuickActionItem(
                      imageAsset:
                          'assets/image/icon_beranda/hanzi_matching.png',
                      color: const Color(0xFF5184B8),
                      title: 'Hanzi Matching',
                      onTap: () => _openQuickFeature(
                        context,
                        isGuest: auth.isGuest,
                        builder: (_) => const HanziMatchingScreen(),
                      ),
                    ),
                    _buildQuickActionItem(
                      imageAsset:
                          'assets/image/icon_beranda/stroke_challange.png',
                      color: const Color(0xFF6D9B53),
                      title: 'Stroke Challenge',
                      onTap: () => _openQuickFeature(
                        context,
                        isGuest: auth.isGuest,
                        builder: (_) => const StrokeChallengeScreen(),
                      ),
                    ),
                    _buildQuickActionItem(
                      imageAsset:
                          'assets/image/icon_beranda/tilt_to_answer.png',
                      color: const Color(0xFF8B6B9E),
                      title: 'Tilt to Answer',
                      onTap: () => _openQuickFeature(
                        context,
                        isGuest: auth.isGuest,
                        builder: (_) => const TiltToAnswerScreen(),
                      ),
                    ),
                    _buildQuickActionItem(
                      imageAsset:
                          'assets/image/icon_beranda/mandarin_catcher.png',
                      color: const Color(0xFFE89B45),
                      title: 'Mandarin Catcher',
                      onTap: () => _openQuickFeature(
                        context,
                        isGuest: auth.isGuest,
                        builder: (_) => const MandarinCatcherScreen(),
                      ),
                    ),
                    _buildQuickActionItem(
                      imageAsset: 'assets/image/beranda/koin.png',
                      color: const Color(0xFFD3A32F),
                      title: 'Saldo & Riwayat',
                      onTap: () => _openQuickFeature(
                        context,
                        isGuest: auth.isGuest,
                        builder: (_) => const CoinLedgerScreen(),
                      ),
                    ),
                    _buildQuickActionItem(
                      imageAsset:
                          'assets/image/icon_beranda/direction_explorer.png',
                      color: const Color(0xFF398A9A),
                      title: 'Direction Explorer',
                      onTap: () => _openQuickFeature(
                        context,
                        isGuest: auth.isGuest,
                        builder: (_) => const DirectionExplorerScreen(),
                      ),
                    ),
                    _buildQuickActionItem(
                      imageAsset:
                          'assets/image/icon_beranda/konversi_mata_uang.png',
                      color: const Color(0xFF6D9B53),
                      title: 'Konversi Mata Uang',
                      onTap: () => _openQuickFeature(
                        context,
                        isGuest: auth.isGuest,
                        builder: (_) => const CurrencyConverterScreen(),
                      ),
                    ),
                    _buildQuickActionItem(
                      imageAsset: 'assets/image/icon_beranda/zona_waktu.png',
                      color: const Color(0xFF5184B8),
                      title: 'Zona Waktu Dunia',
                      onTap: () => _openQuickFeature(
                        context,
                        isGuest: auth.isGuest,
                        builder: (_) => const TimeConverterScreen(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 90),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openQuickFeature(
    BuildContext context, {
    required bool isGuest,
    required WidgetBuilder builder,
  }) {
    if (isGuest) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Fitur ini hanya tersedia untuk akun terdaftar. Silakan daftar untuk mengakses.',
          ),
          action: SnackBarAction(
            label: 'Daftar',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RegisterScreen()),
              );
            },
          ),
        ),
      );
      return;
    }

    Navigator.push(context, MaterialPageRoute(builder: builder));
  }

  Widget _buildQuickActionItem({
    required String imageAsset,
    required Color color,
    required String title,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Image.asset(imageAsset, fit: BoxFit.contain),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E3A24),
            ),
          ),
        ],
      ),
    );
  }
}
