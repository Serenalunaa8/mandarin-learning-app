import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/vocabulary_provider.dart';
import 'dictionary_screen.dart';
import 'quiz_screen.dart';
import 'speech_practice_screen.dart';
import 'ai_tutor_screen.dart';

class PracticeHubScreen extends StatelessWidget {
  const PracticeHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vocab = context.watch<VocabularyProvider>();
    final words = vocab.currentLevelVocabulary;

    return Scaffold(
      backgroundColor: AppColors.mintBackground,
      appBar: AppBar(
        title: const Text('Latihan & Fitur Belajar'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          children: [
            const Text(
              'Aktivitas Belajar Mandiri (Tahap 4)',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 12),

            // 1. Kamus Mandarin
            _buildFeatureCard(
              context,
              title: 'Kamus Mandarin–Indonesia',
              desc: 'Cari 5.000 kata HSK 1–6 berdasarkan Hanzi, Pinyin, atau Arti',
              emoji: '📖',
              color: const Color(0xFFEFF6FF),
              tag: 'Kamus HSK',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DictionaryScreen()),
                );
              },
            ),
            const SizedBox(height: 12),

            // 2. Kuis Utama Tebak Arti & Pinyin (FR-03)
            _buildFeatureCard(
              context,
              title: 'Kuis Tebak Arti & Pinyin',
              desc: 'Uji pemahaman kosakata dengan kuis pilihan ganda dan raih reward koin',
              emoji: '🎯',
              color: const Color(0xFFFDF2F8),
              tag: 'Kuis Utama',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const QuizScreen()),
                );
              },
            ),
            const SizedBox(height: 12),

            // 3. Latihan Pelafalan & Analisis Nada (FR-04 & FR-05)
            _buildFeatureCard(
              context,
              title: 'Latihan Pelafalan & Kontur Nada',
              desc: 'Rekam suaramu dengan mikrofon dan dapatkan evaluasi grafik nada skala Chao',
              emoji: '🎙️',
              color: const Color(0xFFF0FDF4),
              tag: 'Suara & Nada',
              onTap: () {
                final target = words.isNotEmpty ? words.first : null;
                if (target != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => SpeechPracticeScreen(item: target)),
                  );
                }
              },
            ),
            const SizedBox(height: 12),

            // 4. AI Tutor Mandarin (FR-14)
            _buildFeatureCard(
              context,
              title: 'AI Tutor Mandarin (Xiao Xiong)',
              desc: 'Tanyakan tata bahasa, contoh percakapan, dan tips pelafalan kapan saja',
              emoji: '🤖',
              color: const Color(0xFFF5F3FF),
              tag: 'AI Tutor',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AiTutorScreen()),
                );
              },
            ),

            const SizedBox(height: 24),
            const Text(
              'Mini-Game & Sensor Interaktif (Tahap 5)',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 12),

            _buildFeatureCard(
              context,
              title: 'Hanzi Matching',
              desc: 'Cocokkan Hanzi dengan artinya, dapatkan bonus 25 koin tiap 5 streak!',
              emoji: '🧩',
              color: const Color(0xFFFFFBEB),
              tag: 'Streak Koin',
              isComingSoon: true,
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Hanzi Matching dijadwalkan pada Sprint 5 / Tahap 5')),
                );
              },
            ),
            const SizedBox(height: 12),

            _buildFeatureCard(
              context,
              title: 'Hanzi Stroke Challenge',
              desc: 'Latihan menulis Hanzi mengikuti urutan goresan stroke dengan kanvas layar',
              emoji: '✍️',
              color: const Color(0xFFEFF6FF),
              tag: 'Stroke Goresan',
              isComingSoon: true,
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Stroke Challenge dijadwalkan pada Sprint 5 / Tahap 5')),
                );
              },
            ),
            const SizedBox(height: 12),

            _buildFeatureCard(
              context,
              title: 'Tilt to Answer',
              desc: 'Jawab kuis dengan memiringkan perangkat memanfaatkan sensor gyroscope',
              emoji: '📱',
              color: const Color(0xFFF0FDF4),
              tag: 'Sensor Gerak',
              isComingSoon: true,
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Tilt to Answer dijadwalkan pada Sprint 5')),
                );
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureCard(
    BuildContext context, {
    required String title,
    required String desc,
    required String emoji,
    required Color color,
    required String tag,
    required VoidCallback onTap,
    bool isComingSoon = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text(emoji, style: const TextStyle(fontSize: 24)),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            tag,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryDark,
                            ),
                          ),
                          if (isComingSoon)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                'Tahap 5',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFB45309),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        desc,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.chevron_right_rounded, color: AppColors.textLight),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
