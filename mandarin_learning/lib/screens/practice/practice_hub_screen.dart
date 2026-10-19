import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class PracticeHubScreen extends StatelessWidget {
  const PracticeHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.mintBackground,
      appBar: AppBar(
        title: const Text('Latihan & Permainan'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          children: [
            const Text(
              'Aktivitas Belajar Mandiri',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 12),
            _buildFeatureCard(
              context,
              title: 'Kamus Mandarin–Indonesia',
              desc: 'Cari 5.000 kata berdasarkan Hanzi, Pinyin, atau Arti',
              emoji: '📖',
              color: const Color(0xFFEFF6FF),
              tag: 'Kamus',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Modul Kamus akan aktif di Tahap 4')),
                );
              },
            ),
            const SizedBox(height: 12),
            _buildFeatureCard(
              context,
              title: 'Kuis Tebak Arti & Pinyin',
              desc: 'Uji pemahaman kosakata dengan kuis interaktif',
              emoji: '🎯',
              color: const Color(0xFFFDF2F8),
              tag: 'Kuis Utama',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Modul Kuis akan aktif di Tahap 4')),
                );
              },
            ),
            const SizedBox(height: 12),
            _buildFeatureCard(
              context,
              title: 'Latihan Pelafalan & Nada',
              desc: 'Rekam suaramu dan dapatkan umpan balik kontur nada',
              emoji: '🎙️',
              color: const Color(0xFFF0FDF4),
              tag: 'Suara & Nada',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Modul Pelafalan akan aktif di Tahap 5')),
                );
              },
            ),
            const SizedBox(height: 12),
            _buildFeatureCard(
              context,
              title: 'AI Tutor Mandarin',
              desc: 'Tanya penjelasan tata bahasa dan contoh kalimat kapan saja',
              emoji: '🤖',
              color: const Color(0xFFF5F3FF),
              tag: 'AI LLM',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Modul AI Tutor akan aktif di Tahap 5')),
                );
              },
            ),
            const SizedBox(height: 20),
            const Text(
              'Mini-Game & Sensor Interaktif',
              style: TextStyle(
                fontSize: 18,
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
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Modul Hanzi Matching akan aktif di Tahap 6')),
                );
              },
            ),
            const SizedBox(height: 12),
            _buildFeatureCard(
              context,
              title: 'Hanzi Stroke Challenge',
              desc: 'Latihan menulis karakter Hanzi mengikuti garis panduan',
              emoji: '✍️',
              color: const Color(0xFFF0FDF4),
              tag: 'Tulisan',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Modul Stroke Challenge akan aktif di Tahap 6')),
                );
              },
            ),
            const SizedBox(height: 12),
            _buildFeatureCard(
              context,
              title: 'Tilt to Answer',
              desc: 'Jawab kuis dengan memiringkan perangkatmu (Gyroscope)',
              emoji: '📱',
              color: const Color(0xFFF8FAFC),
              tag: 'Sensor Kemiringan',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Modul Tilt to Answer akan aktif di Tahap 6')),
                );
              },
            ),
            const SizedBox(height: 12),
            _buildFeatureCard(
              context,
              title: 'Mandarin Catcher',
              desc: 'Gerakkan keranjang untuk menangkap kosakata target (Accelerometer)',
              emoji: '🧺',
              color: const Color(0xFFFFF7ED),
              tag: 'Accelerometer',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Modul Mandarin Catcher akan aktif di Tahap 6')),
                );
              },
            ),
            const SizedBox(height: 20),
            const Text(
              'Fitur Kontekstual & Utilitas',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 12),
            _buildFeatureCard(
              context,
              title: 'Mandarin Direction Explorer',
              desc: 'Peta LBS sekitar, kompas arah relatif, dan kosakata tempat/arah',
              emoji: '🧭',
              color: const Color(0xFFECFDF5),
              tag: 'LBS & Kompas',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Modul Direction Explorer akan aktif di Tahap 7')),
                );
              },
            ),
            const SizedBox(height: 12),
            _buildFeatureCard(
              context,
              title: 'Konverter Mata Uang & Waktu',
              desc: 'Konversi IDR/CNY/USD serta WIB/WITA/WIT/London/CST',
              emoji: '💱',
              color: const Color(0xFFF1F5F9),
              tag: 'Konversi',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Modul Konverter akan aktif di Tahap 7')),
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
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Text(emoji, style: const TextStyle(fontSize: 26)),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    desc,
                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                tag,
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
