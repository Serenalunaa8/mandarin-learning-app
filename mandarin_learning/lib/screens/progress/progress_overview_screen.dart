import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/vocabulary_provider.dart';
import '../practice/quiz_screen.dart';
import '../practice/dictionary_screen.dart';

class ProgressOverviewScreen extends StatelessWidget {
  const ProgressOverviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final vocab = context.watch<VocabularyProvider>();
    final learnedTotal = vocab.totalQuizMasteredVocabulary;
    final attempts = vocab.quizAttempts;
    final avgScore = vocab.averageQuizScore;

    return Scaffold(
      backgroundColor: AppColors.mintBackground,
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'Progres Belajar',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.forestGreen,
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16, top: 10, bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: AppColors.forestGreen.withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.monetization_on_rounded,
                  color: AppColors.coinGold,
                  size: 19,
                ),
                const SizedBox(width: 5),
                Text(
                  '${auth.coins}',
                  style: const TextStyle(
                    color: AppColors.forestGreen,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Ringkasan Utama Kosakata & Gamifikasi
              Container(
                width: double.infinity,
                height: 248,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  gradient: const LinearGradient(
                    colors: [Color(0xFFE5F8E9), Color(0xFFC8F0DC)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.forestGreen.withValues(alpha: 0.10),
                      blurRadius: 18,
                      offset: const Offset(0, 7),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  children: [
                    Positioned(
                      right: -10,
                      bottom: -14,
                      width: (MediaQuery.sizeOf(context).width - 40) * 0.42,
                      height: (MediaQuery.sizeOf(context).width - 40) * 0.42,
                      child: Image.asset(
                        'assets/image/beranda/maskot_02_baca_buku.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                    Positioned(
                      right: -16,
                      top: -14,
                      child: Icon(
                        Icons.cloud_rounded,
                        size: 100,
                        color: Colors.white.withValues(alpha: 0.42),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(22),
                      child: SizedBox(
                        width: (MediaQuery.sizeOf(context).width - 40) * 0.45,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Total Kosakata Dikuasai',
                              style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              '$learnedTotal / 5.000',
                              style: const TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primaryDark,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: (learnedTotal / 5000).clamp(0.0, 1.0),
                                minHeight: 9,
                                backgroundColor: Colors.white.withValues(
                                  alpha: 0.7,
                                ),
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  AppColors.primary,
                                ),
                              ),
                            ),
                            const Spacer(),
                            _buildStatCol(
                              '🔥 ${auth.streak}',
                              'Hari Streak',
                              alignment: CrossAxisAlignment.start,
                            ),
                            const SizedBox(height: 10),
                            _buildStatCol(
                              '🪙 ${auth.coins}',
                              'Koin',
                              alignment: CrossAxisAlignment.start,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              // 2. Performa & Riwayat Kuis Utama (PB-03 & PB-05 / FR-03 & FR-15)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Performa Kuis Utama',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(padding: EdgeInsets.zero),
                    icon: const Icon(
                      Icons.play_circle_outline_rounded,
                      size: 18,
                      color: AppColors.primaryDark,
                    ),
                    label: const Text(
                      'Mulai Kuis',
                      style: TextStyle(
                        color: AppColors.primaryDark,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const QuizScreen()),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Stat Kuis
              Row(
                children: [
                  Expanded(
                    child: _buildQuizStatBox(
                      title: 'Kuis Selesai',
                      value: '${vocab.totalQuizzesCompleted}',
                      icon: Icons.assignment_turned_in_rounded,
                      color: const Color(0xFFEFF6FF),
                      iconColor: const Color(0xFF2563EB),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildQuizStatBox(
                      title: 'Rata-rata Skor',
                      value: '${avgScore.round()}%',
                      icon: Icons.speed_rounded,
                      color: const Color(0xFFF0FDF4),
                      iconColor: const Color(0xFF16A34A),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildQuizStatBox(
                      title: 'Koleksi Kata',
                      value: '${vocab.favoriteVocabulary.length}',
                      icon: Icons.star_rounded,
                      color: const Color(0xFFFFFBEB),
                      iconColor: const Color(0xFFD97706),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const DictionaryScreen(
                              initialShowFavorites: true,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Riwayat Kuis Terbaru (Attempts List)
              if (attempts.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Riwayat Kuis Terakhir',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ...attempts.take(3).map((att) {
                        final isGreat = att.score >= 70;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    isGreat ? '🎯' : '📝',
                                    style: const TextStyle(fontSize: 18),
                                  ),
                                  const SizedBox(width: 10),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Kuis HSK ${att.hskLevel}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: AppColors.textDark,
                                        ),
                                      ),
                                      Text(
                                        '${att.correctAnswers}/${att.totalQuestions} Benar • +${att.coinsEarned} 🪙',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: isGreat
                                      ? const Color(0xFFDCFCE7)
                                      : const Color(0xFFFEF3C7),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${att.score}%',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: isGreat
                                        ? const Color(0xFF15803D)
                                        : const Color(0xFFB45309),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // 3. Kemajuan Per Level HSK (1 s.d. 6)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Kemajuan Per Level HSK',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  Text(
                    '6 Level',
                    style: TextStyle(
                      color: AppColors.primaryDark.withValues(alpha: 0.8),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...List.generate(6, (index) {
                final lvl = index + 1;
                final words = vocab.allVocabulary
                    .where((item) => item.hskLevel == lvl)
                    .toList();
                final totalWords = words.length;
                final learnedInLevel = words
                    .where((item) => vocab.learnedVocabIds.contains(item.id))
                    .length;
                final progress = totalWords == 0
                    ? 0.0
                    : (learnedInLevel / totalWords).clamp(0.0, 1.0);
                final levelColor = _levelColors[index];

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 13,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.forestGreen.withValues(alpha: 0.06),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: levelColor.withValues(alpha: 0.18),
                          border: Border.all(
                            color: levelColor.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            'HSK\n$lvl',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: levelColor,
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              height: 1.05,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'HSK Level $lvl',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: AppColors.textDark,
                                    ),
                                  ),
                                ),
                                Text(
                                  '$learnedInLevel / $totalWords (${(progress * 100).round()}%)',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primaryDark,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 9),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 8,
                                backgroundColor: const Color(0xFFEAF2FA),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  levelColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.textMuted,
                        size: 24,
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  static const _levelColors = [
    Color(0xFF16A66A),
    Color(0xFF2F80ED),
    Color(0xFF8955D8),
    Color(0xFFE94E65),
    Color(0xFFED8A35),
    Color(0xFF1E9C9A),
  ];

  Widget _buildStatCol(
    String title,
    String subtitle, {
    CrossAxisAlignment alignment = CrossAxisAlignment.center,
  }) {
    return Column(
      crossAxisAlignment: alignment,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
        ),
      ],
    );
  }

  Widget _buildQuizStatBox({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required Color iconColor,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 142),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: AppColors.forestGreen.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(height: 9),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
