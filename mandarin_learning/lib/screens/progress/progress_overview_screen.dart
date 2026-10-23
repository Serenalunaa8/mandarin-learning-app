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
    final learnedTotal = vocab.learnedVocabIds.length;
    final attempts = vocab.quizAttempts;
    final avgScore = vocab.averageQuizScore;

    return Scaffold(
      backgroundColor: AppColors.mintBackground,
      appBar: AppBar(title: const Text('Progres Belajar')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Ringkasan Utama Kosakata & Gamifikasi
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Colors.white,
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
                    const Text(
                      'Total Kosakata Dikuasai',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$learnedTotal / 5.000',
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    const SizedBox(height: 14),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: (learnedTotal / 5000).clamp(0.0, 1.0),
                        minHeight: 10,
                        backgroundColor: const Color(0xFFDCFCE7),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatCol('🔥 ${auth.streak}', 'Hari Streak'),
                        _buildStatCol('💎 ${auth.coins}', 'Permata/Koin'),
                        _buildStatCol(
                          '⭐ ${auth.isGuest ? auth.totalXp : (auth.totalXp > 0 ? auth.totalXp : 320)}',
                          'Poin XP',
                        ),
                      ],
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
                      value: '${vocab.favoriteVocabIds.length}',
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
              const Text(
                'Kemajuan Per Level HSK',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 12),
              ...List.generate(6, (index) {
                final lvl = index + 1;
                final progress = vocab.getLevelProgress(lvl);
                final totalWords = lvl == 1
                    ? 150
                    : (lvl == 2
                          ? 150
                          : (lvl == 3
                                ? 300
                                : (lvl == 4 ? 600 : (lvl == 5 ? 1300 : 2500))));
                final learnedInLevel = (progress * totalWords).round();

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'HSK Level $lvl',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: AppColors.textDark,
                            ),
                          ),
                          Text(
                            '$learnedInLevel / $totalWords kata (${(progress * 100).toInt()}%)',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryDark,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 8,
                          backgroundColor: const Color(0xFFF1F5F9),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            progress >= 1.0
                                ? const Color(0xFF16A34A)
                                : AppColors.primary,
                          ),
                        ),
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

  Widget _buildStatCol(String title, String subtitle) {
    return Column(
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
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            Text(
              title,
              style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
