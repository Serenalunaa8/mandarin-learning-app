import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../core/constants/app_colors.dart';
import '../../providers/vocabulary_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/vocabulary_model.dart';
import '../../models/quiz_attempt_model.dart';
import '../../services/tilt_direction_service.dart';
import '../../widgets/mascot_widget.dart';

// FR-09: Tilt to Answer — gyroscope/accelerometer mengontrol pilihan jawaban
// Fallback: tap-based jika sensor tidak tersedia

class TiltToAnswerScreen extends StatefulWidget {
  const TiltToAnswerScreen({super.key});

  @override
  State<TiltToAnswerScreen> createState() => _TiltToAnswerScreenState();
}

class _TiltToAnswerScreenState extends State<TiltToAnswerScreen> {
  static const int _totalQuestions = 10;
  static const double _tiltThreshold = 3.5;
  static const double _tiltReleaseThreshold = 2.5;
  static const Duration _questionTimeout = Duration(seconds: 10);

  List<VocabularyItem> _pool = [];
  late _QuizQuestion _currentQuestion;
  int _questionIndex = 0;
  int _correct = 0;
  bool _answered = false;
  int? _selectedOptionIndex;
  bool _isLoading = true;
  bool _sensorAvailable = false;
  bool _gameOver = false;

  // Sensor
  StreamSubscription<AccelerometerEvent>? _accelSub;
  double _filteredTiltX = 0;
  int _highlightedOption = -1;
  bool _mustReturnToNeutral = false;
  Timer? _tiltAnswerTimer;
  Timer? _questionTimer;
  int _timerRemaining = 10;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  @override
  void dispose() {
    _accelSub?.cancel();
    _tiltAnswerTimer?.cancel();
    _questionTimer?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    final vocab = context.read<VocabularyProvider>();
    _pool = vocab.currentLevelVocabulary;

    if (_pool.length < 2) {
      setState(() => _isLoading = false);
      return;
    }

    // Try sensor
    try {
      _accelSub =
          accelerometerEventStream(
            samplingPeriod: const Duration(milliseconds: 100),
          ).listen(
            (event) {
              if (!mounted) return;
              final sensorJustBecameAvailable = !_sensorAvailable;
              _sensorAvailable = true;
              _filteredTiltX = _filteredTiltX * 0.78 + event.x * 0.22;
              if (_mustReturnToNeutral) {
                if (_filteredTiltX.abs() < _tiltReleaseThreshold) {
                  _mustReturnToNeutral = false;
                  _highlightedOption = -1;
                  setState(() {});
                }
                return;
              }
              final previous = _highlightedOption;
              _updateHighlight();
              if (sensorJustBecameAvailable || previous != _highlightedOption) {
                setState(() {});
              }
              if (previous != _highlightedOption) {
                _scheduleTiltAnswer();
              }
            },
            onError: (Object error) {
              debugPrint('[TiltToAnswer] Accelerometer error: $error');
              if (!mounted) return;
              setState(() => _sensorAvailable = false);
            },
          );
      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
    } catch (_) {
      _sensorAvailable = false;
    }

    _loadQuestion();
    _scheduleTiltAnswer();
    setState(() => _isLoading = false);
  }

  void _updateHighlight() {
    if (_answered) return;
    final option = optionForTiltX(_filteredTiltX, threshold: _tiltThreshold);
    if (option != null) {
      _highlightedOption = option;
    } else if (_filteredTiltX.abs() < _tiltReleaseThreshold) {
      _highlightedOption = -1;
    }
  }

  void _scheduleTiltAnswer() {
    _tiltAnswerTimer?.cancel();
    final option = _highlightedOption;
    if (!_sensorAvailable || _isLoading || option < 0 || _answered) return;
    _tiltAnswerTimer = Timer(const Duration(milliseconds: 350), () {
      if (!mounted || _answered || _highlightedOption != option) return;
      _onAnswer(option);
    });
  }

  void _loadQuestion() {
    if (_questionIndex >= _totalQuestions || _pool.length < 2) {
      _endGame();
      return;
    }

    final rng = Random();
    final shuffled = List<VocabularyItem>.from(_pool)..shuffle(rng);
    final correct = shuffled[0];
    final distractors = shuffled.skip(1).take(1).toList();

    final options = [correct, ...distractors]..shuffle(rng);
    final correctIndex = options.indexOf(correct);

    setState(() {
      _currentQuestion = _QuizQuestion(
        word: correct,
        options: options,
        correctIndex: correctIndex,
      );
      _answered = false;
      _selectedOptionIndex = null;
      _highlightedOption = -1;
      _timerRemaining = _questionTimeout.inSeconds;
    });

    _startTimer();
  }

  void _startTimer() {
    _questionTimer?.cancel();
    _tiltAnswerTimer?.cancel();
    _questionTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _timerRemaining--);
      if (_timerRemaining <= 0) {
        t.cancel();
        _onAnswer(-1); // time out = wrong
      }
    });
  }

  void _onAnswer(int optionIndex) {
    if (_answered) return;
    _questionTimer?.cancel();

    final isCorrect = optionIndex == _currentQuestion.correctIndex;
    _mustReturnToNeutral = _sensorAvailable && _highlightedOption >= 0;
    setState(() {
      _answered = true;
      _selectedOptionIndex = optionIndex;
      if (isCorrect) _correct++;
    });

    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      _questionIndex++;
      _loadQuestion();
    });
  }

  void _endGame() async {
    _questionTimer?.cancel();
    _accelSub?.cancel();

    setState(() => _gameOver = true);

    // Save attempt
    final auth = context.read<AuthProvider>();
    final vocab = context.read<VocabularyProvider>();
    final userId = auth.profile?.id ?? 'guest_local_user';
    final percentage = _correct / _totalQuestions;
    final coins = percentage >= 0.8
        ? 15
        : percentage >= 0.5
        ? 10
        : 5;
    final attemptId = 'tilt_${DateTime.now().millisecondsSinceEpoch}';

    await auth.addCoins(
      coins,
      'tilt_reward',
      'Hadiah Tilt to Answer ($_correct/$_totalQuestions benar)',
      attemptId: attemptId,
    );
    vocab.recordQuizAttempt(
      QuizAttempt(
        id: attemptId,
        userId: userId,
        hskLevel: vocab.selectedLevel,
        quizType: 'tilt_to_answer',
        score: (_correct / _totalQuestions * 100).round(),
        totalQuestions: _totalQuestions,
        correctAnswers: _correct,
        coinsEarned: coins,
        createdAt: DateTime.now(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_pool.length < 4) {
      return Scaffold(
        appBar: AppBar(title: const Text('Tilt to Answer')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const MascotWidget(pose: MascotPose.holdingSign, size: 100),
              const SizedBox(height: 16),
              const Text(
                'Butuh minimal 2 kosakata untuk bermain.',
                style: TextStyle(color: AppColors.textMuted),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Kembali'),
              ),
            ],
          ),
        ),
      );
    }

    if (_gameOver) return _buildGameOver();

    return Scaffold(
      backgroundColor: AppColors.mintBackground,
      appBar: AppBar(
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        title: const Text('Tilt to Answer'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '$_correct/$_questionIndex',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildProgressBar(),
            if (!_sensorAvailable) _buildSensorFallbackBanner(),
            Expanded(child: _buildQuestionArea()),
            _buildOptionsGrid(),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    final progress = _questionIndex / _totalQuestions;
    return Column(
      children: [
        LinearProgressIndicator(
          value: progress,
          backgroundColor: Colors.white,
          valueColor: const AlwaysStoppedAnimation<Color>(
            AppColors.primaryGreen,
          ),
          minHeight: 6,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Soal ${_questionIndex + 1} / $_totalQuestions',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _timerRemaining <= 2
                      ? Colors.red.withValues(alpha: 0.1)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '⏱ $_timerRemaining',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: _timerRemaining <= 2
                        ? Colors.red
                        : AppColors.primaryDark,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSensorFallbackBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, size: 16, color: Color(0xFFB45309)),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Sensor gyroscope tidak tersedia. Mode tap aktif.',
              style: TextStyle(fontSize: 11, color: Color(0xFFB45309)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionArea() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Pilih Hanzi yang artinya...',
            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
          const SizedBox(height: 12),
          Text(
            _currentQuestion.word.artiIndonesia,
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryDark,
            ),
            textAlign: TextAlign.center,
          ),
          if (_sensorAvailable) ...[
            const SizedBox(height: 12),
            const Text(
              'Miringkan ke kiri atau kanan dan tahan sebentar untuk memilih',
              style: TextStyle(fontSize: 11, color: AppColors.textMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOptionsGrid() {
    const labels = ['← Kiri', 'Kanan →'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: Row(
        children: [
          for (var i = 0; i < 2; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(child: _buildOptionTile(i, labels[i])),
          ],
        ],
      ),
    );
  }

  Widget _buildOptionTile(int i, String directionLabel) {
    final option = _currentQuestion.options[i];
    final isCorrect = i == _currentQuestion.correctIndex;
    final isSelected = _selectedOptionIndex == i;
    final isHighlighted = _highlightedOption == i && _sensorAvailable;

    Color bgColor = Colors.white;
    Color borderColor = const Color(0xFFE2E8F0);
    if (_answered) {
      if (isCorrect) {
        bgColor = const Color(0xFFD1FAE5);
        borderColor = AppColors.primaryGreen;
      } else if (isSelected) {
        bgColor = const Color(0xFFFEE2E2);
        borderColor = Colors.red;
      }
    } else if (isHighlighted) {
      bgColor = const Color(0xFFEFF6FF);
      borderColor = AppColors.primaryDark;
    }

    return GestureDetector(
      onTap: _answered ? null : () => _onAnswer(i),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_sensorAvailable)
              Text(
                directionLabel,
                style: const TextStyle(
                  fontSize: 9,
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            Text(
              option.hanzi,
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                color: _answered && isCorrect
                    ? AppColors.primaryGreen
                    : AppColors.textDark,
              ),
              textAlign: TextAlign.center,
            ),

            Text(
              option.pinyin,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _answered && isCorrect
                    ? AppColors.primaryGreen
                    : AppColors.textMuted,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameOver() {
    final percentage = _correct / _totalQuestions;
    final coins = percentage >= 0.8
        ? 15
        : percentage >= 0.5
        ? 10
        : 5;

    return Scaffold(
      backgroundColor: AppColors.mintBackground,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                MascotWidget(
                  pose: percentage >= 0.7
                      ? MascotPose.celebrating
                      : MascotPose.studying,
                  size: 120,
                ),
                const SizedBox(height: 24),
                Text(
                  percentage >= 0.8
                      ? '🎉 Luar Biasa!'
                      : percentage >= 0.5
                      ? '👍 Bagus!'
                      : '💪 Tetap Semangat!',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryDark,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$_correct dari $_totalQuestions jawaban benar',
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Koin Diperoleh',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '+$coins 🪙',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFB45309),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text('Selesai'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _questionIndex = 0;
                            _correct = 0;
                            _gameOver = false;
                          });
                          _init();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text('Main Lagi'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuizQuestion {
  final VocabularyItem word;
  final List<VocabularyItem> options;
  final int correctIndex;

  const _QuizQuestion({
    required this.word,
    required this.options,
    required this.correctIndex,
  });
}

