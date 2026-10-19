import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../models/vocabulary_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/vocabulary_provider.dart';
import '../../services/audio_service.dart';
import '../../widgets/mascot_widget.dart';
import '../practice/quiz_screen.dart';

class VocabularyDetailScreen extends StatefulWidget {
  final VocabularyItem item;

  const VocabularyDetailScreen({super.key, required this.item});

  @override
  State<VocabularyDetailScreen> createState() => _VocabularyDetailScreenState();
}

class _VocabularyDetailScreenState extends State<VocabularyDetailScreen> {
  late int _currentIndex;
  late List<VocabularyItem> _wordList;

  @override
  void initState() {
    super.initState();
    final vocab = context.read<VocabularyProvider>();
    final unitItems = vocab.currentLevelUnits[vocab.selectedUnit] ?? vocab.currentLevelVocabulary;
    _wordList = unitItems.isNotEmpty ? unitItems : [widget.item];
    final foundIndex = _wordList.indexWhere((w) => w.id == widget.item.id);
    _currentIndex = foundIndex >= 0 ? foundIndex : 0;
  }

  void _nextWord() {
    final vocab = context.read<VocabularyProvider>();
    final auth = context.read<AuthProvider>();

    // Tandai kata saat ini sudah dipelajari
    final currentWord = _wordList[_currentIndex];
    vocab.markAsLearned(
      vocabId: currentWord.id,
      userId: auth.profile?.id ?? 'guest_local_user',
    );

    if (_currentIndex < _wordList.length - 1) {
      setState(() {
        _currentIndex++;
      });
    } else {
      // Unit selesai! Lanjut ke Kuis Utama sesuai alur PRD 8.1
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Unit Kosakata Selesai! 🎉'),
          content: const Text('Hebat! Kamu telah menyelesaikan kosakata di unit ini. Lanjut uji kemampuanmu di Kuis Latihan?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Nanti Saja'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => QuizScreen(customItems: _wordList),
                  ),
                );
              },
              child: const Text('Mulai Kuis 🎯'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentItem = _wordList[_currentIndex];
    final displayTotal = _wordList.length > 10 ? 10 : _wordList.length;
    final displayIndex = (_currentIndex % 10) + 1;
    final progress = displayIndex / displayTotal;

    final hasExample = currentItem.contohKalimat.isNotEmpty;
    final exampleHanzi = hasExample ? currentItem.contohKalimat.first.hanzi : '${currentItem.hanzi}！';
    final exampleArti = hasExample ? currentItem.contohKalimat.first.arti : currentItem.artiIndonesia;

    return Scaffold(
      backgroundColor: AppColors.mintBackground,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Kosakata'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 18),
            child: Center(
              child: Text(
                '$displayIndex/$displayTotal',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top Green Progress Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
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
            const SizedBox(height: 14),

            // Content scroll area
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    // Big Character Card with Mascot holding Hanzi sign
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Hanzi & Speaker
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                currentItem.hanzi,
                                style: const TextStyle(
                                  fontSize: 64,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textDark,
                                ),
                              ),
                              const SizedBox(width: 14),
                              GestureDetector(
                                onTap: () => AudioService.instance.speak(currentItem.hanzi),
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryLight,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.volume_up_rounded, color: AppColors.primaryDark, size: 24),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          // Pinyin
                          Text(
                            currentItem.pinyin,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryDark,
                            ),
                          ),
                          const SizedBox(height: 4),
                          // Meaning
                          Text(
                            currentItem.artiIndonesia,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 16,
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Garden landscape with mascot holding sign
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFFE8F5E9),
                                  Color(0xFFC8E6C9),
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Center(
                              child: MascotWidget(
                                size: 110,
                                pose: MascotPose.holdingSign,
                                signText: currentItem.hanzi,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // "Contoh Kalimat" Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
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
                            'Contoh Kalimat',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textMuted,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      exampleHanzi,
                                      style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textDark,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      currentItem.pinyin,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: AppColors.primaryDark,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      exampleArti,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              GestureDetector(
                                onTap: () => AudioService.instance.speak(exampleHanzi),
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryLight,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.volume_up_rounded, color: AppColors.primaryDark, size: 22),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),

            // Sticky Bottom Button "Lanjut"
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
                  onPressed: _nextWord,
                  child: const Text(
                    'Lanjut',
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
}
