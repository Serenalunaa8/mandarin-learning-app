import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../models/vocabulary_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/vocabulary_provider.dart';
import '../../services/audio_service.dart';
import '../../services/vocabulary_service.dart';
import '../../widgets/mascot_widget.dart';
import '../practice/quiz_screen.dart';

class VocabularyDetailScreen extends StatefulWidget {
  final VocabularyItem item;
  final List<VocabularyItem>? vocabularyList;

  const VocabularyDetailScreen({
    super.key,
    required this.item,
    this.vocabularyList,
  });

  @override
  State<VocabularyDetailScreen> createState() => _VocabularyDetailScreenState();
}

class _VocabularyDetailScreenState extends State<VocabularyDetailScreen> {
  late int _currentIndex;
  late List<VocabularyItem> _wordList;
  late Future<List<ExampleSentence>> _examplesFuture;

  @override
  void initState() {
    super.initState();
    if (widget.vocabularyList != null && widget.vocabularyList!.isNotEmpty) {
      _wordList = widget.vocabularyList!;
    } else {
      final vocab = context.read<VocabularyProvider>();
      final unitItems =
          vocab.currentLevelUnits[vocab.selectedUnit] ??
          vocab.currentLevelVocabulary;
      _wordList = unitItems.isNotEmpty ? unitItems : [widget.item];
    }
    final foundIndex = _wordList.indexWhere((w) => w.id == widget.item.id);
    _currentIndex = foundIndex >= 0 ? foundIndex : 0;
    _examplesFuture = VocabularyService.instance.getExampleSentences(
      _wordList[_currentIndex],
    );
  }

  void _nextWord() {
    final vocab = context.read<VocabularyProvider>();
    final auth = context.read<AuthProvider>();

    // Tandai kata saat ini sudah dipelajari
    final currentWord = _wordList[_currentIndex];
    vocab.markAsLearned(
      vocabId: currentWord.id,
      userId: auth.profile?.id ?? 'guest_local_user',
      hskLevel: currentWord.hskLevel,
    );

    if (_currentIndex < _wordList.length - 1) {
      setState(() {
        _currentIndex++;
        _examplesFuture = VocabularyService.instance.getExampleSentences(
          _wordList[_currentIndex],
        );
      });
    } else {
      // Unit selesai! Lanjut ke Kuis Utama sesuai alur PRD 8.1
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('Unit Kosakata Selesai! 🎉'),
          content: const Text(
            'Hebat! Kamu telah menyelesaikan kosakata di unit ini. Lanjut uji kemampuanmu di Kuis Latihan?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Nanti Saja'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
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
    final displayTotal = _wordList.length;
    final displayIndex = _currentIndex + 1;
    final progress = displayIndex / displayTotal;

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
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppColors.primary,
                  ),
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
                                onTap: () => AudioService.instance.speak(
                                  currentItem.hanzi,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryLight,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.volume_up_rounded,
                                    color: AppColors.primaryDark,
                                    size: 24,
                                  ),
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
                                colors: [Color(0xFFE8F5E9), Color(0xFFC8E6C9)],
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
                    FutureBuilder<List<ExampleSentence>>(
                      future: _examplesFuture,
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Text(
                            'Contoh penggunaan gagal dimuat: ${snapshot.error}',
                            style: const TextStyle(color: Colors.red),
                          );
                        }
                        if (!snapshot.hasData) {
                          return const SizedBox(
                            height: 120,
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        final examples = snapshot.data!;
                        if (examples.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        return Container(
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
                              Row(
                                children: [
                                  const Icon(
                                    Icons.menu_book_rounded,
                                    size: 18,
                                    color: AppColors.primary,
                                  ),
                                  const SizedBox(width: 6),
                                  const Text(
                                    'Contoh Kalimat',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1E3A24),
                                    ),
                                  ),
                                  const Spacer(),
                                  if (examples.length > 1)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFDCFCE7),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        '${examples.length} Kalimat',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF16A34A),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              ...examples.asMap().entries.map((entry) {
                                final index = entry.key;
                                final example = entry.value;
                                return Container(
                                  margin: EdgeInsets.only(bottom: index < examples.length - 1 ? 12 : 0),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 22,
                                        height: 22,
                                        margin: const EdgeInsets.only(right: 10, top: 2),
                                        decoration: const BoxDecoration(
                                          color: Color(0xFFDCFCE7),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Center(
                                          child: Text(
                                            '${index + 1}',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF16A34A),
                                            ),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              example.hanzi,
                                              style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF0F172A),
                                              ),
                                            ),
                                            if (example.pinyin != null && example.pinyin!.isNotEmpty) ...[
                                              const SizedBox(height: 2),
                                              Text(
                                                example.pinyin!,
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                  color: Color(0xFF16A34A),
                                                ),
                                              ),
                                            ],
                                            const SizedBox(height: 4),
                                            Text(
                                              example.arti,
                                              style: const TextStyle(
                                                fontSize: 13,
                                                color: Color(0xFF475569),
                                                height: 1.3,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      GestureDetector(
                                        onTap: () => AudioService.instance.speak(
                                          example.hanzi,
                                        ),
                                        child: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: AppColors.primaryLight,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.volume_up_rounded,
                                            color: AppColors.primaryDark,
                                            size: 20,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ),
                        );
                      },
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
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
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
