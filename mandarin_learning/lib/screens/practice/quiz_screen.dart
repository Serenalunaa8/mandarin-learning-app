import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../models/vocabulary_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/vocabulary_provider.dart';
import '../../services/audio_service.dart';
import '../../widgets/mascot_widget.dart';
import 'speech_practice_screen.dart';

class QuizQuestion {
  final VocabularyItem targetItem;
  final List<String> options;
  final int correctIndex;

  QuizQuestion({
    required this.targetItem,
    required this.options,
    required this.correctIndex,
  });
}

class QuizScreen extends StatefulWidget {
  final List<VocabularyItem>? customItems;
  final String title;

  const QuizScreen({
    super.key,
    this.customItems,
    this.title = 'Latihan',
  });

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  List<QuizQuestion> _questions = [];
  int _currentIndex = 0;
  int? _selectedOptionIndex;
  bool _isAnswerChecked = false;
  int _correctCount = 0;
  bool _quizCompleted = false;
  bool _hintUsed = false;
  String? _hintText;

  @override
  void initState() {
    super.initState();
    _generateQuizQuestions();
  }

  void _generateQuizQuestions() {
    final vocab = context.read<VocabularyProvider>();
    List<VocabularyItem> pool = widget.customItems ?? vocab.currentLevelVocabulary;

    if (pool.length < 4) {
      pool = vocab.currentLevelVocabulary;
    }
    if (pool.isEmpty) return;

    final rand = math.Random();
    final shuffledPool = List<VocabularyItem>.from(pool)..shuffle(rand);
    final count = math.min(10, shuffledPool.length);

    List<QuizQuestion> list = [];

    for (int i = 0; i < count; i++) {
      final target = shuffledPool[i];

      // Ambil 3 pilihan pengecoh dari kata lain
      final distractors = pool.where((item) => item.id != target.id).toList()..shuffle(rand);
      final wrongChoices = distractors.take(3).map((e) => e.artiIndonesia).toList();

      while (wrongChoices.length < 3) {
        wrongChoices.add('Pilihan ${wrongChoices.length + 1}');
      }

      final options = [target.artiIndonesia, ...wrongChoices]..shuffle(rand);
      final correctIdx = options.indexOf(target.artiIndonesia);

      list.add(QuizQuestion(
        targetItem: target,
        options: options,
        correctIndex: correctIdx,
      ));
    }

    setState(() {
      _questions = list;
      _currentIndex = 0;
      _selectedOptionIndex = null;
      _isAnswerChecked = false;
      _correctCount = 0;
      _quizCompleted = false;
      _hintUsed = false;
      _hintText = null;
    });
  }

  void _selectOption(int index) {
    if (_isAnswerChecked) return;
    setState(() {
      _selectedOptionIndex = index;
    });
  }

  void _handleNextOrCheck() async {
    if (_selectedOptionIndex == null) return;

    final currentQ = _questions[_currentIndex];

    if (!_isAnswerChecked) {
      // Periksa jawaban
      final isCorrect = _selectedOptionIndex == currentQ.correctIndex;
      if (isCorrect) {
        _correctCount++;
      }
      setState(() {
        _isAnswerChecked = true;
      });
    } else {
      // Lanjut ke soal berikutnya atau selesai
      if (_currentIndex < _questions.length - 1) {
        setState(() {
          _currentIndex++;
          _selectedOptionIndex = null;
          _isAnswerChecked = false;
          _hintUsed = false;
          _hintText = null;
        });
      } else {
        _finishQuiz();
      }
    }
  }

  void _finishQuiz() async {
    setState(() {
      _quizCompleted = true;
    });

    final total = _questions.isEmpty ? 1 : _questions.length;
    final score = ((_correctCount / total) * 100).round();

    // Aturan Reward PRD 6.1 (FR-17)
    int rewardCoins = 0;
    if (score >= 90) {
      rewardCoins = 15;
    } else if (score >= 70) {
      rewardCoins = 10;
    } else if (score >= 50) {
      rewardCoins = 5;
    }

    if (rewardCoins > 0) {
      final auth = context.read<AuthProvider>();
      await auth.addCoins(
        rewardCoins,
        'quiz_reward',
        'Skor kuis utama: $score% ($rewardCoins koin)',
        attemptId: 'quiz_${DateTime.now().millisecondsSinceEpoch}',
      );
    }
  }

  // Bantuan Kuis (FR-19: 20 Koin)
  void _useHint() async {
    final auth = context.read<AuthProvider>();
    if (auth.coins < 20) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Koin tidak cukup (butuh 20 koin). Teruslah berlatih!'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Gunakan Bantuan Kuis?'),
        content: const Text(
          'Tukarkan 20 koin untuk mendapatkan petunjuk makna konteks kata ini tanpa membuka jawaban langsung.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Gunakan (20 🪙)'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await auth.deductCoins(
        20,
        'quiz_hint',
        'Bantuan kuis kosakata: ${_questions[_currentIndex].targetItem.hanzi}',
      );
      if (success && mounted) {
        final target = _questions[_currentIndex].targetItem;
        String hint = 'Petunjuk: Kata ini berkaitan dengan "${target.jenisKata ?? 'kategori umum'}".';
        if (target.contohKalimat.isNotEmpty) {
          hint += '\nContoh penggunaan: "${target.contohKalimat.first.arti}"';
        }
        setState(() {
          _hintUsed = true;
          _hintText = hint;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    if (_quizCompleted) {
      return _buildCompletionScreen();
    }

    final currentQ = _questions[_currentIndex];
    final progress = (_currentIndex + 1) / _questions.length;

    return Scaffold(
      backgroundColor: AppColors.mintBackground,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(widget.title),
        actions: [
          // Tombol Bantuan Kuis (20 Koin)
          IconButton(
            icon: const Icon(Icons.lightbulb_outline_rounded, color: AppColors.coinGold),
            tooltip: 'Petunjuk Bantuan (20 Koin)',
            onPressed: _hintUsed ? null : _useHint,
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: AppColors.textDark),
            onPressed: () {},
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Header Progress Bar & Counter (3/10)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Soal ${_currentIndex + 1} dari ${_questions.length}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textMuted),
                      ),
                      Text(
                        '${_currentIndex + 1}/${_questions.length}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: const Color(0xFFDCFCE7),
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Question prompt
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Pilih arti yang benar dari kata berikut!',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Target Word Box (Display Hanzi & Pinyin)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Center(
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          currentQ.targetItem.hanzi,
                          style: const TextStyle(
                            fontSize: 42,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: () => AudioService.instance.speak(currentQ.targetItem.hanzi),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.volume_up_rounded, color: AppColors.primaryDark, size: 22),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      currentQ.targetItem.pinyin,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Hint Text if used
            if (_hintText != null) ...[
              const SizedBox(height: 10),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Row(
                  children: [
                    const Text('💡', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _hintText!,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF92400E), fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Options list
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: currentQ.options.length,
                itemBuilder: (context, index) {
                  final optionText = currentQ.options[index];
                  final isSelected = _selectedOptionIndex == index;
                  final isCorrectOption = index == currentQ.correctIndex;

                  Color borderColor = const Color(0xFFE2E8F0);
                  Color bgColor = Colors.white;
                  Widget iconTrailing = Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
                    ),
                  );

                  if (isSelected && !_isAnswerChecked) {
                    borderColor = AppColors.primary;
                    bgColor = const Color(0xFFF0FDF4);
                    iconTrailing = Container(
                      width: 22,
                      height: 22,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check, size: 16, color: Colors.white),
                    );
                  } else if (_isAnswerChecked) {
                    if (isCorrectOption) {
                      borderColor = AppColors.success;
                      bgColor = const Color(0xFFDCFCE7);
                      iconTrailing = const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 24);
                    } else if (isSelected && !isCorrectOption) {
                      borderColor = AppColors.error;
                      bgColor = const Color(0xFFFEE2E2);
                      iconTrailing = const Icon(Icons.cancel_rounded, color: AppColors.error, size: 24);
                    }
                  }

                  return GestureDetector(
                    onTap: () => _selectOption(index),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: borderColor, width: isSelected ? 1.8 : 1.2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              optionText,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                color: AppColors.textDark,
                              ),
                            ),
                          ),
                          iconTrailing,
                        ],
                      ),
                    ),
                  );
                },
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
                    backgroundColor: _selectedOptionIndex == null
                        ? const Color(0xFFCBD5E1)
                        : AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                    elevation: 0,
                  ),
                  onPressed: _selectedOptionIndex == null ? null : _handleNextOrCheck,
                  child: Text(
                    _isAnswerChecked
                        ? (_currentIndex < _questions.length - 1 ? 'Lanjut' : 'Lihat Hasil')
                        : 'Periksa',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletionScreen() {
    final total = _questions.isEmpty ? 1 : _questions.length;
    final score = ((_correctCount / total) * 100).round();

    int rewardCoins = 0;
    if (score >= 90) {
      rewardCoins = 15;
    } else if (score >= 70) {
      rewardCoins = 10;
    } else if (score >= 50) {
      rewardCoins = 5;
    }

    return Scaffold(
      backgroundColor: AppColors.mintBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              // Celebrating Mascot
              const MascotWidget(
                size: 150,
                pose: MascotPose.celebrating,
                speechBubbleText: '太棒了! (Hebat!)',
              ),
              const SizedBox(height: 24),

              Text(
                score >= 70 ? 'Luar Biasa!' : 'Terus Semangat!',
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.textDark),
              ),
              const SizedBox(height: 8),
              Text(
                'Kamu menjawab $_correctCount dari $total soal dengan benar.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: AppColors.textMuted),
              ),
              const SizedBox(height: 24),

              // Score Card
              Container(
                padding: const EdgeInsets.all(20),
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
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        const Text('Skor Akhir', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                        const SizedBox(height: 4),
                        Text('$score%', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primaryDark)),
                      ],
                    ),
                    Container(height: 40, width: 1, color: const Color(0xFFE2E8F0)),
                    Column(
                      children: [
                        const Text('Reward Koin', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                        const SizedBox(height: 4),
                        Text('+$rewardCoins 🪙', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.coinGold)),
                      ],
                    ),
                  ],
                ),
              ),
              const Spacer(),

              // Core Learning Loop: Lanjut ke Latihan Pelafalan (PRD 8.1 Alur Utama Pembelajaran)
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.mic_rounded, color: Colors.white),
                  label: const Text('Lanjut ke Latihan Pelafalan', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                  ),
                  onPressed: () {
                    final target = _questions.first.targetItem;
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SpeechPracticeScreen(item: target),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),

              // Tombol Kembali ke Menu
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Kembali ke Menu Belajar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
