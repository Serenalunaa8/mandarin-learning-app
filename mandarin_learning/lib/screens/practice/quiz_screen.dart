import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../models/vocabulary_model.dart';
import '../../models/quiz_attempt_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/vocabulary_provider.dart';
import '../../services/audio_service.dart';
import '../../widgets/in_app_notification.dart';
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

  const QuizScreen({super.key, this.customItems, this.title = 'Latihan'});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  List<QuizQuestion> _questions = [];
  int _currentIndex = 0;
  int? _selectedOptionIndex;
  bool _isAnswerChecked = false;
  int _correctCount = 0;
  final Set<int> _correctVocabIds = {};
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
    List<VocabularyItem> pool =
        widget.customItems ?? vocab.currentLevelVocabulary;

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
      final distractors = pool.where((item) => item.id != target.id).toList()
        ..shuffle(rand);
      final wrongChoices = distractors
          .take(3)
          .map((e) => e.artiIndonesia)
          .toList();

      while (wrongChoices.length < 3) {
        wrongChoices.add('Pilihan ${wrongChoices.length + 1}');
      }

      final options = [target.artiIndonesia, ...wrongChoices]..shuffle(rand);
      final correctIdx = options.indexOf(target.artiIndonesia);

      list.add(
        QuizQuestion(
          targetItem: target,
          options: options,
          correctIndex: correctIdx,
        ),
      );
    }

    setState(() {
      _questions = list;
      _currentIndex = 0;
      _selectedOptionIndex = null;
      _isAnswerChecked = false;
      _correctCount = 0;
      _correctVocabIds.clear();
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
        _correctVocabIds.add(currentQ.targetItem.id);
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

    final attemptId = 'quiz_${DateTime.now().millisecondsSinceEpoch}';
    final auth = context.read<AuthProvider>();
    final vocab = context.read<VocabularyProvider>();

    if (rewardCoins > 0) {
      await auth.addCoins(
        rewardCoins,
        'quiz_reward',
        'Skor kuis utama: $score% ($rewardCoins koin)',
        attemptId: attemptId,
      );
    }

    // Rekam attempt kuis untuk pemantauan progres (PB-05 & FR-15)
    await vocab.recordQuizAttempt(
      QuizAttempt(
        id: attemptId,
        userId: auth.profile?.id ?? 'guest_local_user',
        hskLevel: vocab.selectedLevel,
        quizType: 'tebak_arti_pinyin',
        score: score,
        totalQuestions: total,
        correctAnswers: _correctCount,
        coinsEarned: rewardCoins,
        createdAt: DateTime.now(),
      ),
      correctVocabIds: _correctVocabIds,
    );

    // Tampilkan notifikasi reward di dalam aplikasi (In-App Notification)
    if (mounted) {
      await InAppNotification.showReward(
        context,
        title: score >= 70
            ? '🎉 Kuis Selesai! Skor: $score/100'
            : '📚 Kuis Selesai! Skor: $score/100',
        message: rewardCoins > 0
            ? 'Hebat! Kamu berhasil menyelesaikan kuis dan memperoleh +$rewardCoins Koin!'
            : 'Terus semangat! Tingkatkan skor untuk memperoleh koin reward.',
        score: score,
        coins: rewardCoins,
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
        String hint =
            'Petunjuk: Kata ini berkaitan dengan "${target.jenisKata ?? 'kategori umum'}".';
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
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    if (_quizCompleted) {
      return _buildCompletionScreen();
    }

    final currentQ = _questions[_currentIndex];
    final progress = (_currentIndex + 1) / _questions.length;

    return Scaffold(
      backgroundColor: const Color(0xFFEAF7F2),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leadingWidth: 72,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16, top: 6, bottom: 6),
          child: _roundHeaderButton(
            icon: Icons.arrow_back_rounded,
            onPressed: () => Navigator.pop(context),
          ),
        ),
        title: Text(
          widget.title,
          style: const TextStyle(
            color: Color(0xFF124B36),
            fontSize: 23,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8, top: 6, bottom: 6),
            child: _roundHeaderButton(
              icon: Icons.lightbulb_outline_rounded,
              iconColor: AppColors.primaryDark,
              onPressed: _hintUsed ? null : _useHint,
              tooltip: 'Petunjuk bantuan (20 koin)',
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16, top: 6, bottom: 6),
            child: Container(
              height: 46,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF164B38).withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/image/beranda/koin.png',
                    width: 21,
                    height: 21,
                    errorBuilder: (_, _, _) => const Icon(
                      Icons.monetization_on_rounded,
                      size: 20,
                      color: AppColors.coinGold,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${context.watch<AuthProvider>().coins}',
                    style: const TextStyle(
                      color: Color(0xFF124B36),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFE8F7F2), Color(0xFFF5FBF7), Color(0xFFEAF7F2)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              // Header Progress Bar & Counter (3/10)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Soal ${_currentIndex + 1} dari ${_questions.length}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryDark,
                          ),
                        ),
                        Text(
                          '${_currentIndex + 1}/${_questions.length}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF124B36),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: progress),
                        duration: const Duration(milliseconds: 350),
                        builder: (context, value, _) => LinearProgressIndicator(
                          value: value,
                          minHeight: 9,
                          backgroundColor: const Color(0xFFD3EEE2),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFF1B9B4B),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Question prompt
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Image.asset(
                      'assets/image/beranda/maskot_04_lup.png',
                      width: 64,
                      height: 64,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.lightbulb_rounded,
                        color: AppColors.primary,
                        size: 48,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Pilih arti yang benar dari kata berikut!',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF124B36),
                          height: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Target Word Box (Display Hanzi & Pinyin)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                height: 210,
                decoration: BoxDecoration(
                  color: const Color(0xFF145D3B),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF145D3B).withValues(alpha: 0.2),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Image.asset(
                        'assets/image/beranda/bg_sungai.png',
                        fit: BoxFit.cover,
                        color: const Color(0xFF0C4C31).withValues(alpha: 0.74),
                        colorBlendMode: BlendMode.multiply,
                      ),
                    ),
                    Positioned(
                      left: -12,
                      top: -16,
                      child: Icon(
                        Icons.cloud_rounded,
                        size: 78,
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    Positioned(
                      right: -12,
                      bottom: -8,
                      width: (MediaQuery.sizeOf(context).width * 0.44).clamp(
                        130.0,
                        176.0,
                      ),
                      height: (MediaQuery.sizeOf(context).width * 0.44).clamp(
                        130.0,
                        176.0,
                      ),
                      child: Image.asset(
                        'assets/image/beranda/maskot_03_semangat.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                    Positioned(
                      left: 24,
                      top: 20,
                      bottom: 20,
                      right: (MediaQuery.sizeOf(context).width * 0.38).clamp(
                        112.0,
                        148.0,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    currentQ.targetItem.hanzi,
                                    maxLines: 1,
                                    style: const TextStyle(
                                      fontSize: 48,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Material(
                                color: const Color(0xFF2FAE60),
                                shape: const CircleBorder(),
                                child: InkWell(
                                  customBorder: const CircleBorder(),
                                  onTap: () => AudioService.instance.speak(
                                    currentQ.targetItem.hanzi,
                                  ),
                                  child: const Padding(
                                    padding: EdgeInsets.all(11),
                                    child: Icon(
                                      Icons.volume_up_rounded,
                                      color: Colors.white,
                                      size: 22,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            currentQ.targetItem.pinyin,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFD8F3DF),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'HSK ${currentQ.targetItem.hskLevel}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.72),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      right: 24,
                      top: 26,
                      child: Image.asset(
                        'assets/image/beranda/kilau_01.png',
                        width: 22,
                        height: 22,
                      ),
                    ),
                  ],
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
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF92400E),
                            fontWeight: FontWeight.w500,
                          ),
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

                    Color borderColor = const Color(0xFFCDEBE0);
                    Color bgColor = Colors.white;
                    Widget iconTrailing = Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFCBD5E1),
                          width: 1.5,
                        ),
                      ),
                    );

                    if (isSelected && !_isAnswerChecked) {
                      borderColor = const Color(0xFF24A45A);
                      bgColor = const Color(0xFFF0FDF4);
                      iconTrailing = Container(
                        width: 22,
                        height: 22,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check,
                          size: 16,
                          color: Colors.white,
                        ),
                      );
                    } else if (_isAnswerChecked) {
                      if (isCorrectOption) {
                        borderColor = AppColors.success;
                        bgColor = const Color(0xFFDCFCE7);
                        iconTrailing = const Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.success,
                          size: 24,
                        );
                      } else if (isSelected && !isCorrectOption) {
                        borderColor = AppColors.error;
                        bgColor = const Color(0xFFFEE2E2);
                        iconTrailing = const Icon(
                          Icons.cancel_rounded,
                          color: AppColors.error,
                          size: 24,
                        );
                      }
                    }

                    return GestureDetector(
                      onTap: () => _selectOption(index),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        constraints: const BoxConstraints(minHeight: 76),
                        decoration: BoxDecoration(
                          color: bgColor,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: borderColor,
                            width: isSelected ? 1.7 : 1.1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF164B38)
                                  .withValues(alpha: 0.045),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: Row(
                            children: [
                              Container(
                                width: 46,
                                height: 46,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFE5F5E9),
                                  shape: BoxShape.circle,
                                ),
                                padding: const EdgeInsets.all(12),
                                child: Image.asset(
                                  'assets/image/beranda/daun_tunas.png',
                                  fit: BoxFit.contain,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  optionText,
                                  style: TextStyle(
                                    fontSize: 15,
                                    height: 1.2,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.w600,
                                    color: AppColors.textDark,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              iconTrailing,
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Sticky Bottom Button "Lanjut"
              Container(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 18),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF7F2).withValues(alpha: 0.94),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF164B38).withValues(alpha: 0.06),
                      blurRadius: 14,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _selectedOptionIndex == null
                          ? const Color(0xFF9CB9AA)
                          : const Color(0xFF198B4A),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(32),
                        side: const BorderSide(color: Colors.white, width: 2),
                      ),
                      elevation: 4,
                      shadowColor: const Color(0xFF198B4A)
                          .withValues(alpha: 0.3),
                    ),
                    onPressed: _selectedOptionIndex == null
                        ? null
                        : _handleNextOrCheck,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _isAnswerChecked
                              ? (_currentIndex < _questions.length - 1
                                    ? 'Lanjut'
                                    : 'Lihat Hasil')
                              : 'Periksa',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Icon(Icons.arrow_forward_rounded, size: 26),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
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
      backgroundColor: const Color(0xFFEAF7F2),
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFE8F7F2), Color(0xFFF5FBF7), Color(0xFFEAF7F2)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    _roundHeaderButton(
                      icon: Icons.arrow_back_rounded,
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Expanded(
                      child: Text(
                        'Hasil Latihan',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF124B36),
                          fontWeight: FontWeight.w800,
                          fontSize: 21,
                        ),
                      ),
                    ),
                    const SizedBox(width: 46),
                  ],
                ),
                const Spacer(),
                Container(
                  width: 184,
                  height: 184,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Color(0xFFC9F2D5), Color(0xFFE8F8EC)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  padding: const EdgeInsets.all(14),
                  child: Image.asset(
                    'assets/image/beranda/maskot_03_semangat.png',
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  score >= 70 ? 'Luar Biasa!' : 'Terus Semangat!',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF124B36),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Kamu menjawab $_correctCount dari $total soal dengan benar.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 20,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF164B38).withValues(alpha: 0.07),
                        blurRadius: 16,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _completionMetric(
                        icon: Icons.check_circle_rounded,
                        label: 'Skor Akhir',
                        value: '$score%',
                        color: AppColors.primary,
                      ),
                      Container(
                        height: 52,
                        width: 1,
                        color: const Color(0xFFE6EFEA),
                      ),
                      _completionMetric(
                        icon: Icons.monetization_on_rounded,
                        label: 'Reward Koin',
                        value: '+$rewardCoins',
                        color: AppColors.coinGold,
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  height: 58,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.mic_rounded, color: Colors.white),
                    label: const Text(
                      'Lanjut ke Latihan Pelafalan',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF198B4A),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                        side: const BorderSide(color: Colors.white, width: 2),
                      ),
                      elevation: 4,
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
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryDark,
                      side: const BorderSide(color: Color(0xFFB8DFCB)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Kembali ke Menu Belajar',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _roundHeaderButton({
    required IconData icon,
    required VoidCallback? onPressed,
    Color iconColor = const Color(0xFF124B36),
    String? tooltip,
  }) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF164B38).withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, color: iconColor, size: 24),
      ),
    );
  }

  Widget _completionMetric({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 25),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }
}
