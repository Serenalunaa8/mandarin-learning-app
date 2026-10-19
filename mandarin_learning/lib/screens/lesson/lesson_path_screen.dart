import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../models/vocabulary_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/vocabulary_provider.dart';
import '../../widgets/mascot_widget.dart';
import 'vocabulary_detail_screen.dart';

class LessonPathScreen extends StatelessWidget {
  const LessonPathScreen({super.key});

  static const List<Map<String, dynamic>> lessonTopics = [
    {
      'unit': 1,
      'title': 'Huruf Hanyu Pinyin',
      'icon': Icons.menu_book_rounded,
      'status': 'completed',
    },
    {
      'unit': 2,
      'title': 'Salam dan Perkenalan',
      'icon': Icons.chat_bubble_outline_rounded,
      'status': 'completed',
    },
    {
      'unit': 3,
      'title': 'Angka dalam Bahasa Mandarin',
      'icon': Icons.pin_outlined,
      'status': 'active',
      'progress': 0.60,
    },
    {
      'unit': 4,
      'title': 'Kata Kerja Dasar',
      'icon': Icons.lock_outline_rounded,
      'status': 'locked',
    },
    {
      'unit': 5,
      'title': 'Kata Sifat',
      'icon': Icons.lock_outline_rounded,
      'status': 'locked',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final vocab = context.watch<VocabularyProvider>();
    final currentLevel = vocab.selectedLevel;
    final units = vocab.currentLevelUnits;

    return Scaffold(
      backgroundColor: AppColors.mintBackground,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () {
            // Jika ada pop konteks
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            }
          },
        ),
        title: const Text('Jalur Pembelajaran'),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
              children: [
                const Text('💎', style: TextStyle(fontSize: 13)),
                const SizedBox(width: 4),
                Text(
                  '${auth.coins}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Banner Level 1 - Dasar Bahasa Mandarin
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFDCFCE7),
                    Color(0xFFBBF7D0),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Level $currentLevel',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF14532D),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Selector level HSK
                            PopupMenuButton<int>(
                              icon: const Icon(Icons.arrow_drop_down_circle_outlined, color: Color(0xFF15803D), size: 20),
                              onSelected: (lvl) => vocab.setLevel(lvl),
                              itemBuilder: (ctx) => List.generate(6, (i) {
                                final l = i + 1;
                                return PopupMenuItem(
                                  value: l,
                                  child: Text('Ganti ke HSK $l'),
                                );
                              }),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _getLevelSubtitle(currentLevel),
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF166534),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const MascotWidget(size: 70, pose: MascotPose.waving),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Lesson List Cards
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                itemCount: lessonTopics.length,
                itemBuilder: (context, index) {
                  final topic = lessonTopics[index];
                  final unitNum = topic['unit'] as int;
                  final title = topic['title'] as String;
                  final status = topic['status'] as String;
                  final double? progress = topic['progress'] as double?;

                  return _buildLessonCard(
                    context,
                    unitNum: unitNum,
                    title: title,
                    status: status,
                    progress: progress,
                    vocabItems: units[unitNum] ?? [],
                    onTap: () {
                      if (status == 'locked') {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Selesaikan pelajaran sebelumnya untuk membuka pelajaran ini.')),
                        );
                        return;
                      }

                      vocab.setUnit(unitNum);
                      final items = units[unitNum] ?? vocab.currentLevelVocabulary;
                      if (items.isNotEmpty) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => VocabularyDetailScreen(item: items.first),
                          ),
                        );
                      }
                    },
                  );
                },
              ),
            ),

            // Sticky Bottom Button "Lanjut ke Pelajaran 3"
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                    elevation: 0,
                  ),
                  onPressed: () {
                    vocab.setUnit(3);
                    final items = units[3] ?? vocab.currentLevelVocabulary;
                    if (items.isNotEmpty) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => VocabularyDetailScreen(item: items.first),
                        ),
                      );
                    }
                  },
                  child: const Text(
                    'Lanjut ke Pelajaran 3',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLessonCard(
    BuildContext context, {
    required int unitNum,
    required String title,
    required String status,
    double? progress,
    required List<VocabularyItem> vocabItems,
    required VoidCallback onTap,
  }) {
    final isLocked = status == 'locked';
    final isCompleted = status == 'completed';
    final isActive = status == 'active';

    Widget leadingIcon;
    if (isCompleted) {
      leadingIcon = Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0xFFDCFCE7),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(
          unitNum == 1 ? Icons.menu_book_rounded : Icons.chat_bubble_rounded,
          color: const Color(0xFF16A34A),
          size: 24,
        ),
      );
    } else if (isActive) {
      leadingIcon = Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0xFFDCFCE7),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Center(
          child: Text(
            '2 3',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF15803D)),
          ),
        ),
      );
    } else {
      leadingIcon = Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.lock_rounded, color: Color(0xFF94A3B8), size: 22),
      );
    }

    Widget trailing;
    if (isCompleted) {
      trailing = const Icon(Icons.chevron_right_rounded, color: AppColors.textLight);
    } else if (isActive) {
      trailing = Container(
        width: 34,
        height: 34,
        decoration: const BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 22),
      );
    } else {
      trailing = const Icon(Icons.chevron_right_rounded, color: Color(0xFFCBD5E1));
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
        border: Border.all(
          color: isActive ? const Color(0xFF86EFAC) : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              leadingIcon,
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pelajaran $unitNum',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isLocked ? const Color(0xFF94A3B8) : AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (isCompleted) ...[
                      Row(
                        children: const [
                          Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 14),
                          SizedBox(width: 4),
                          Text(
                            'Selesai',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF16A34A),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ] else if (isActive && progress != null) ...[
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 6,
                                backgroundColor: const Color(0xFFDCFCE7),
                                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${(progress * 100).toInt()}%',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryDark,
                            ),
                          ),
                        ],
                      ),
                    ] else if (isLocked) ...[
                      Row(
                        children: const [
                          Icon(Icons.lock_outline_rounded, color: Color(0xFF94A3B8), size: 14),
                          SizedBox(width: 4),
                          Text(
                            'Terkunci',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF94A3B8),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              trailing,
            ],
          ),
        ),
      ),
    );
  }

  String _getLevelSubtitle(int level) {
    switch (level) {
      case 1:
        return 'Dasar Bahasa Mandarin (150 Kata)';
      case 2:
        return 'Tingkat Percakapan Dasar (150 Kata)';
      case 3:
        return 'Tingkat Menengah Awal (300 Kata)';
      case 4:
        return 'Tingkat Menengah Lanjutan (600 Kata)';
      case 5:
        return 'Tingkat Mahir (1.300 Kata)';
      case 6:
        return 'Tingkat Fasih Profesional (2.500 Kata)';
      default:
        return 'Dasar Bahasa Mandarin';
    }
  }
}
