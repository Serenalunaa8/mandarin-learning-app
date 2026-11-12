import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/vocabulary_provider.dart';
import '../auth/register_screen.dart';
import '../coins/coin_ledger_screen.dart';
import '../games/hanzi_matching_screen.dart';
import '../games/mandarin_catcher_screen.dart';
import '../games/stroke_challenge_screen.dart';
import '../games/tilt_to_answer_screen.dart';
import 'dictionary_screen.dart';
import 'quiz_screen.dart';
import 'speech_practice_screen.dart';
import 'ai_tutor_screen.dart';
import '../tools/direction_explorer_screen.dart';
import '../tools/currency_converter_screen.dart';
import '../tools/time_converter_screen.dart';
import '../tools/feedback_screen.dart';

class PracticeHubScreen extends StatelessWidget {
  const PracticeHubScreen({super.key});

  void _showGuestLockedSnackbar(BuildContext context) {
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
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final vocab = context.watch<VocabularyProvider>();
    final words = vocab.currentLevelVocabulary;
    final isGuest = auth.isGuest;

    return Scaffold(
      backgroundColor: AppColors.mintBackground,
      appBar: AppBar(title: const Text('Latihan & Fitur Belajar')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          children: [
            // Guest mode info banner
            if (isGuest) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFED7AA)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      color: Color(0xFFEA580C),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Mode Tamu: Hanya Kamus Mandarin yang tersedia',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF9A3412),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
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
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFEA580C),
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const Text(
              'Aktivitas Belajar Mandiri (Tahap 4)',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 12),

            // 1. Kamus Mandarin — always accessible
            _buildFeatureCard(
              context,
              title: 'Kamus Mandarin–Indonesia',
              desc: 'Cari 5.000 kata HSK 1–6 berdasarkan Hanzi, Pinyin, atau Arti',
              emoji: '📖',
              color: const Color(0xFFEFF6FF),
              tag: 'Kamus HSK',
              locked: false,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DictionaryScreen()),
                );
              },
            ),
            const SizedBox(height: 12),

            // 2. Kuis Utama
            _buildFeatureCard(
              context,
              title: 'Kuis Tebak Arti & Pinyin',
              desc: 'Uji pemahaman kosakata dengan kuis pilihan ganda dan raih reward koin',
              emoji: '🎯',
              color: const Color(0xFFFDF2F8),
              tag: 'Kuis Utama',
              locked: isGuest,
              onTap: () {
                if (isGuest) {
                  _showGuestLockedSnackbar(context);
                  return;
                }
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const QuizScreen()),
                );
              },
            ),
            const SizedBox(height: 12),

            // 3. Latihan Pelafalan
            _buildFeatureCard(
              context,
              title: 'Latihan Pelafalan & Kontur Nada',
              desc: 'Rekam suaramu dengan mikrofon dan dapatkan evaluasi grafik nada skala Chao',
              emoji: '🎙️',
              color: const Color(0xFFF0FDF4),
              tag: 'Suara & Nada',
              locked: isGuest,
              onTap: () {
                if (isGuest) {
                  _showGuestLockedSnackbar(context);
                  return;
                }
                final target = words.isNotEmpty ? words.first : null;
                if (target != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SpeechPracticeScreen(item: target),
                    ),
                  );
                }
              },
            ),
            const SizedBox(height: 12),

            // 4. AI Tutor
            _buildFeatureCard(
              context,
              title: 'AI Tutor Mandarin (LingLing 玲玲)',
              desc: 'Tanyakan tata bahasa, contoh percakapan, dan tips pelafalan kapan saja',
              emoji: '🤖',
              color: const Color(0xFFF5F3FF),
              tag: 'AI Tutor',
              locked: isGuest,
              onTap: () {
                if (isGuest) {
                  _showGuestLockedSnackbar(context);
                  return;
                }
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
              locked: isGuest,
              onTap: () {
                if (isGuest) {
                  _showGuestLockedSnackbar(context);
                  return;
                }
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const HanziMatchingScreen(),
                  ),
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
              locked: isGuest,
              onTap: () {
                if (isGuest) {
                  _showGuestLockedSnackbar(context);
                  return;
                }
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const StrokeChallengeScreen(),
                  ),
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
              locked: isGuest,
              onTap: () {
                if (isGuest) {
                  _showGuestLockedSnackbar(context);
                  return;
                }
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TiltToAnswerScreen()),
                );
              },
            ),
            const SizedBox(height: 12),

            _buildFeatureCard(
              context,
              title: 'Mandarin Catcher',
              desc: 'Tangkap kosakata target dengan menggerakkan perangkat atau tombol kontrol',
              emoji: '🧺',
              color: const Color(0xFFECFDF5),
              tag: 'Sensor Gerak',
              locked: isGuest,
              onTap: () {
                if (isGuest) {
                  _showGuestLockedSnackbar(context);
                  return;
                }
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const MandarinCatcherScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),

            _buildFeatureCard(
              context,
              title: 'Saldo & Riwayat Koin',
              desc:
                  'Lihat saldo, reward, dan koin yang digunakan untuk bantuan',
              emoji: '🪙',
              color: const Color(0xFFFFF7ED),
              tag: 'Reward Koin',
              locked: isGuest,
              onTap: () {
                if (isGuest) {
                  _showGuestLockedSnackbar(context);
                  return;
                }
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CoinLedgerScreen()),
                );
              },
            ),
            const SizedBox(height: 24),

            const Text(
              'Fitur Kontekstual & Alat Bantu (Tahap 6)',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 12),

            // 1. Direction Explorer
            _buildFeatureCard(
              context,
              title: 'Mandarin Direction Explorer',
              desc: 'Peta GPS real-time, pencarian tempat pintar, in-map kompas mata angin & kalkulator konversi harga 3 mata uang',
              emoji: '🧭',
              color: const Color(0xFFF0FDF4),
              tag: 'LBS, Search & Kurs',
              locked: isGuest,
              onTap: () {
                if (isGuest) {
                  _showGuestLockedSnackbar(context);
                  return;
                }
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const DirectionExplorerScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),

            // 2. Konversi Mata Uang
            _buildFeatureCard(
              context,
              title: 'China Trip Budget Planner (旅行预算)',
              desc: 'Rencanakan anggaran ke Tiongkok dalam Rupiah, konversi Yuan (CNY) & alokasi 4 kebutuhan',
              emoji: '🇨🇳',
              color: const Color(0xFFFFFBEB),
              tag: 'Budget & Kurs',
              locked: isGuest,
              onTap: () {
                if (isGuest) {
                  _showGuestLockedSnackbar(context);
                  return;
                }
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CurrencyConverterScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),

            // 3. Konversi Waktu
            _buildFeatureCard(
              context,
              title: 'Konversi Zona Waktu Dunia',
              desc: 'Komparasi jam Beijing (CST), WIB, WITA, WIT, dan London dengan Daylight Saving',
              emoji: '⏰',
              color: const Color(0xFFEFF6FF),
              tag: 'Zona Waktu',
              locked: isGuest,
              onTap: () {
                if (isGuest) {
                  _showGuestLockedSnackbar(context);
                  return;
                }
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const TimeConverterScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),

            // 4. Umpan Balik
            _buildFeatureCard(
              context,
              title: 'Umpan Balik & Saran',
              desc: 'Kirim kritik, saran materi, dan penilaian aplikasi langsung ke pengembang',
              emoji: '💌',
              color: const Color(0xFFFAF5FF),
              tag: 'Feedback',
              locked: isGuest,
              onTap: () {
                if (isGuest) {
                  _showGuestLockedSnackbar(context);
                  return;
                }
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const FeedbackScreen()),
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
    bool locked = false,
    bool isComingSoon = false,
  }) {
    return Opacity(
      opacity: locked ? 0.55 : 1.0,
      child: Container(
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
                      color: locked ? const Color(0xFFF1F5F9) : color,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: locked
                          ? const Icon(
                              Icons.lock_rounded,
                              color: Color(0xFF94A3B8),
                              size: 24,
                            )
                          : Text(emoji, style: const TextStyle(fontSize: 24)),
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
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: locked
                                    ? const Color(0xFF94A3B8)
                                    : AppColors.primaryDark,
                              ),
                            ),
                            if (isComingSoon)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
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
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: locked
                                ? const Color(0xFF94A3B8)
                                : AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          locked
                              ? 'Fitur ini hanya tersedia untuk akun terdaftar.'
                              : desc,
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
                  Icon(
                    locked
                        ? Icons.lock_outline_rounded
                        : Icons.chevron_right_rounded,
                    color: AppColors.textLight,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
