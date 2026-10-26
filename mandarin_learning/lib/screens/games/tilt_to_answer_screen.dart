import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../core/constants/app_colors.dart';
import '../../models/quiz_attempt_model.dart';
import '../../models/vocabulary_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/vocabulary_provider.dart';
import '../../services/audio_service.dart';
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

    // Cek sensor accelerometer
    try {
      _accelSub = accelerometerEventStream(
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
        _onAnswer(-1); // time out = salah
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

    // Lafalkan karakter Mandarin yang benar
    AudioService.instance.speak(_currentQuestion.word.hanzi);

    Future.delayed(const Duration(milliseconds: 1250), () {
      if (!mounted) return;
      _questionIndex++;
      _loadQuestion();
    });
  }

  void _endGame() async {
    _questionTimer?.cancel();
    _accelSub?.cancel();

    setState(() => _gameOver = true);

    // Simpan hasil
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
      return const Scaffold(
        backgroundColor: Color(0xFFF0FDF4),
        body: Center(child: CircularProgressIndicator(color: AppColors.primaryGreen)),
      );
    }
    if (_pool.length < 2) {
      return Scaffold(
        backgroundColor: const Color(0xFFF0FDF4),
        body: SafeArea(child: _buildEmptyState()),
      );
    }

    if (_gameOver) return _buildGameOver();

    return Scaffold(
      backgroundColor: const Color(0xFFF0FDF4),
      body: Stack(
        children: [
          // Latar Belakang Alam Lembut & Awan dari assets
          Positioned.fill(
            child: Opacity(
              opacity: 0.16,
              child: Image.asset(
                'assets/image/games/background_1_padang_cerah.png',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ),
          Positioned(
            top: -15,
            right: -25,
            child: Opacity(
              opacity: 0.4,
              child: Image.asset(
                'assets/image/beranda/awan_kecil.png',
                width: 150,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ),
          Positioned(
            top: 100,
            left: -35,
            child: Opacity(
              opacity: 0.28,
              child: Image.asset(
                'assets/image/beranda/awan_besar.png',
                width: 170,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ),

          // Konten Utama
          SafeArea(
            child: Column(
              children: [
                _buildAppBar(),
                _buildProgressBar(),
                const SizedBox(height: 4),
                _buildTiltLevelIndicator(),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildQuestionArea(),
                          const SizedBox(height: 14),
                          _buildOptionsGrid(),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      child: Row(
        children: [
          // Tombol Kembali
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.arrow_back_rounded,
                color: Color(0xFF334155),
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Judul dengan Ikon Tilt to Answer
          Expanded(
            child: Row(
              children: [
                Image.asset(
                  'assets/image/icon_beranda/tilt_to_answer.png',
                  width: 32,
                  height: 32,
                  errorBuilder: (_, __, ___) => const Text('📱', style: TextStyle(fontSize: 22)),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Tilt to Answer',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),

          // Skor Saat Ini
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF16A34A)),
                const SizedBox(width: 5),
                Text(
                  '$_correct / $_totalQuestions',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    final progress = (_questionIndex + 1) / _totalQuestions;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Soal ${_questionIndex + 1} dari $_totalQuestions',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF334155),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: _timerRemaining <= 3
                        ? const Color(0xFFFEE2E2)
                        : const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _timerRemaining <= 3
                          ? const Color(0xFFEF4444)
                          : const Color(0xFFBFDBFE),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.timer_rounded,
                        size: 13,
                        color: _timerRemaining <= 3
                            ? const Color(0xFFDC2626)
                            : const Color(0xFF2563EB),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$_timerRemaining dtk',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                          color: _timerRemaining <= 3
                              ? const Color(0xFFDC2626)
                              : const Color(0xFF2563EB),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                backgroundColor: const Color(0xFFF1F5F9),
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF0284C7)),
                minHeight: 7,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Indikator visual sensor kemiringan (Gyroscope Horizon Bubble Level)
  Widget _buildTiltLevelIndicator() {
    if (!_sensorAvailable) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF3C7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFDE68A)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.touch_app_rounded, size: 16, color: Color(0xFFB45309)),
            SizedBox(width: 8),
            Text(
              'Mode Sentuh Aktif — Ketuk salah satu kartu jawaban',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                color: Color(0xFFB45309),
              ),
            ),
          ],
        ),
      );
    }

    // Normalisasi tilt: -1.0 (kanan) sampai +1.0 (kiri)
    final normalizedTilt = (_filteredTiltX / 7.0).clamp(-1.0, 1.0);
    final isLeftActive = _highlightedOption == 0;
    final isRightActive = _highlightedOption == 1;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.arrow_back_rounded,
                    size: 15,
                    color: isLeftActive ? const Color(0xFF0284C7) : const Color(0xFF94A3B8),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Miring Kiri',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isLeftActive ? FontWeight.w900 : FontWeight.w600,
                      color: isLeftActive ? const Color(0xFF0284C7) : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              Text(
                isLeftActive
                    ? '← Memilih Kiri!'
                    : (isRightActive ? 'Memilih Kanan! →' : 'Miringkan HP untuk memilih'),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isLeftActive
                      ? const Color(0xFF0284C7)
                      : (isRightActive ? const Color(0xFFD97706) : const Color(0xFF94A3B8)),
                ),
              ),
              Row(
                children: [
                  Text(
                    'Miring Kanan',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isRightActive ? FontWeight.w900 : FontWeight.w600,
                      color: isRightActive ? const Color(0xFFD97706) : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 15,
                    color: isRightActive ? const Color(0xFFD97706) : const Color(0xFF94A3B8),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Track Level Indikator
          Container(
            height: 10,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final trackWidth = constraints.maxWidth;
                final bubbleX = (trackWidth / 2) - 11 - (normalizedTilt * (trackWidth / 2 - 14));
                final bubbleClamped = bubbleX.clamp(0.0, trackWidth - 22);

                return Stack(
                  children: [
                    Center(
                      child: Container(
                        width: 4,
                        height: 6,
                        decoration: BoxDecoration(
                          color: const Color(0xFFCBD5E1),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Positioned(
                      left: bubbleClamped,
                      top: 1,
                      child: Container(
                        width: 22,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isLeftActive
                              ? const Color(0xFF0284C7)
                              : (isRightActive
                                  ? const Color(0xFFD97706)
                                  : const Color(0xFF64748B)),
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: [
                            BoxShadow(
                              color: (isLeftActive
                                      ? const Color(0xFF0284C7)
                                      : (isRightActive
                                          ? const Color(0xFFD97706)
                                          : Colors.black))
                                  .withValues(alpha: 0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionArea() {
    String mascotAsset = 'assets/image/games/Excited Green Frog Mascot.png';
    if (_answered) {
      final isCorrect = _selectedOptionIndex == _currentQuestion.correctIndex;
      mascotAsset = isCorrect
          ? 'assets/image/games/Blushing Green Sprout Mascot.png'
          : 'assets/image/games/Crying Green Frog Chibi Mascot.png';
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Maskot Interaktif lebih kompak di sebelah kiri
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Image.asset(
              mascotAsset,
              key: ValueKey<String>(mascotAsset),
              width: 50,
              height: 50,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const MascotWidget(
                pose: MascotPose.studying,
                size: 44,
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Teks Arti Bahasa Indonesia
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDE9FE),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '🎯 ARTI BAHASA INDONESIA',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                      color: Color(0xFF6D28D9),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _currentQuestion.word.artiIndonesia,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                      height: 1.15,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionsGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        // Padding horizontal 14 di kiri dan kanan
        final usableWidth = totalWidth - 28;
        final cardWidth = (usableWidth - 12) / 2;
        // Rasio proporsional kokoh (tinggi ~1.22x lebar), tidak kurus/ramping
        final cardHeight = (cardWidth * 1.22).clamp(195.0, 240.0);

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: SizedBox(
            height: cardHeight,
            child: Row(
              children: [
                Expanded(child: _buildOptionTile(0)),
                const SizedBox(width: 12),
                Expanded(child: _buildOptionTile(1)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOptionTile(int i) {
    final option = _currentQuestion.options[i];
    final isCorrect = i == _currentQuestion.correctIndex;
    final isSelected = _selectedOptionIndex == i;
    final isHighlighted = _highlightedOption == i && _sensorAvailable;
    final isLeft = i == 0;

    // Palet Warna Selaras Dual-Tone (Kiri: Biru Langit Azure vs Kanan: Warm Amber Honey)
    Color bgColor;
    Color borderColor;
    Color shadowColor;
    Color textColor;
    Color subTextColor;
    Color badgeBg;
    Color badgeText;
    double borderWidth = 2.0;
    double bevelOffset = 4.0;

    if (_answered) {
      if (isCorrect) {
        bgColor = const Color(0xFFDCFCE7); // Hijau Mint Sukses
        borderColor = const Color(0xFF16A34A);
        shadowColor = const Color(0xFF16A34A).withValues(alpha: 0.25);
        textColor = const Color(0xFF15803D);
        subTextColor = const Color(0xFF16A34A);
        badgeBg = const Color(0xFFBBF7D0);
        badgeText = const Color(0xFF166534);
        bevelOffset = 2.0;
      } else if (isSelected) {
        bgColor = const Color(0xFFFEF2F2); // Rose Red Salah
        borderColor = const Color(0xFFEF4444);
        shadowColor = const Color(0xFFEF4444).withValues(alpha: 0.25);
        textColor = const Color(0xFFB91C1C);
        subTextColor = const Color(0xFFEF4444);
        badgeBg = const Color(0xFFFEE2E2);
        badgeText = const Color(0xFFDC2626);
        bevelOffset = 2.0;
      } else {
        bgColor = Colors.white.withValues(alpha: 0.6);
        borderColor = const Color(0xFFE2E8F0);
        shadowColor = Colors.transparent;
        textColor = const Color(0xFF94A3B8);
        subTextColor = const Color(0xFFCBD5E1);
        badgeBg = const Color(0xFFF1F5F9);
        badgeText = const Color(0xFF94A3B8);
      }
    } else if (isHighlighted) {
      // Glow aktif saat HP dimiringkan ke kartu ini
      if (isLeft) {
        bgColor = const Color(0xFFE0F2FE);
        borderColor = const Color(0xFF0284C7);
        shadowColor = const Color(0xFF0284C7).withValues(alpha: 0.3);
        textColor = const Color(0xFF075985);
        subTextColor = const Color(0xFF0284C7);
        badgeBg = const Color(0xFFBAE6FD);
        badgeText = const Color(0xFF0369A1);
      } else {
        bgColor = const Color(0xFFFEF3C7);
        borderColor = const Color(0xFFD97706);
        shadowColor = const Color(0xFFD97706).withValues(alpha: 0.3);
        textColor = const Color(0xFF78350F);
        subTextColor = const Color(0xFFB45309);
        badgeBg = const Color(0xFFFDE68A);
        badgeText = const Color(0xFF92400E);
      }
      borderWidth = 2.8;
      bevelOffset = 2.0;
    } else {
      // Status Normal (Dual-tone)
      if (isLeft) {
        bgColor = const Color(0xFFF0F9FF); // Soft Azure
        borderColor = const Color(0xFFBAE6FD);
        shadowColor = const Color(0xFF7DD3FC);
        textColor = const Color(0xFF0C4A6E);
        subTextColor = const Color(0xFF0284C7);
        badgeBg = const Color(0xFFE0F2FE);
        badgeText = const Color(0xFF0284C7);
      } else {
        bgColor = const Color(0xFFFFFDF5); // Soft Honey Amber
        borderColor = const Color(0xFFFDE68A);
        shadowColor = const Color(0xFFFCD34D);
        textColor = const Color(0xFF78350F);
        subTextColor = const Color(0xFFB45309);
        badgeBg = const Color(0xFFFEF3C7);
        badgeText = const Color(0xFFD97706);
      }
    }

    return GestureDetector(
      onTap: _answered ? null : () => _onAnswer(i),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: borderColor, width: borderWidth),
          boxShadow: [
            BoxShadow(
              color: shadowColor,
              offset: Offset(0, bevelOffset),
              blurRadius: isHighlighted ? 10 : 0,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Status Benar / Salah saat dijawab
            if (_answered && (isCorrect || isSelected)) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  isCorrect ? '✓ BENAR' : '✕ SALAH',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: badgeText,
                  ),
                ),
              ),
              const SizedBox(height: 6),
            ],

            // Karakter Hanzi (Ukuran besar & proporsional)
            Expanded(
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    option.hanzi,
                    style: TextStyle(
                      fontSize: 50,
                      fontWeight: FontWeight.w900,
                      color: textColor,
                      height: 1.1,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),

            // Pinyin (Proporsional lebih besar dan jelas)
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                option.pinyin,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: subTextColor,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameOver() {
    final percentage = _correct / _totalQuestions;
    final int coins;
    final int stars;

    if (percentage >= 0.8) {
      stars = 3;
      coins = 15;
    } else if (percentage >= 0.5) {
      stars = 2;
      coins = 10;
    } else {
      stars = 1;
      coins = 5;
    }

    final isVictory = percentage >= 0.5;

    return Scaffold(
      backgroundColor: const Color(0xFFF0FDF4),
      body: Stack(
        children: [
          // Background Scenery dari assets
          Positioned.fill(
            child: Opacity(
              opacity: 0.18,
              child: Image.asset(
                'assets/image/games/background_1_padang_cerah.png',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ),
          Positioned.fill(
            child: Container(color: Colors.black.withValues(alpha: 0.45)),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: const Color(0xFF86EFAC), width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Maskot Perayaan dengan Sparkles
                      Stack(
                        alignment: Alignment.center,
                        clipBehavior: Clip.none,
                        children: [
                          Positioned(
                            top: -12,
                            right: -16,
                            child: Image.asset(
                              'assets/image/beranda/kilau_01.png',
                              width: 38,
                              height: 38,
                              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                            ),
                          ),
                          Positioned(
                            bottom: -8,
                            left: -14,
                            child: Image.asset(
                              'assets/image/beranda/kilau_02.png',
                              width: 32,
                              height: 32,
                              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                            ),
                          ),
                          Container(
                            width: 95,
                            height: 95,
                            decoration: const BoxDecoration(
                              color: Color(0xFFECFDF5),
                              shape: BoxShape.circle,
                            ),
                            padding: const EdgeInsets.all(10),
                            child: Image.asset(
                              isVictory
                                  ? 'assets/image/games/Blushing Green Sprout Mascot.png'
                                  : 'assets/image/games/Crying Green Frog Chibi Mascot.png',
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => MascotWidget(
                                pose: isVictory
                                    ? MascotPose.celebrating
                                    : MascotPose.studying,
                                size: 75,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      Text(
                        isVictory ? 'Luar Biasa! 🎉' : 'Permainan Selesai!',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF065F46),
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        isVictory
                            ? 'Kamu berhasil menjawab dengan tepat!'
                            : 'Jangan patah semangat, ayo coba lagi!',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Bintang
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(3, (index) {
                          return Icon(
                            index < stars
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                            size: 40,
                            color: index < stars
                                ? const Color(0xFFF59E0B)
                                : const Color(0xFFCBD5E1),
                          );
                        }),
                      ),
                      const SizedBox(height: 16),

                      // Statistik Hasil
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatTile(
                              'Benar',
                              '$_correct/$_totalQuestions',
                              const Color(0xFF10B981),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildStatTile(
                              'Akurasi',
                              '${(percentage * 100).round()}%',
                              const Color(0xFF0284C7),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Koin Diperoleh dengan Aset Koin
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFEF3C7), Color(0xFFFDE68A)],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFF59E0B)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.asset(
                              'assets/image/beranda/koin.png',
                              width: 22,
                              height: 22,
                              errorBuilder: (_, __, ___) =>
                                  const Text('🪙', style: TextStyle(fontSize: 18)),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '+$coins Koin Didapatkan!',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF92400E),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Tombol Aksi
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                side: const BorderSide(color: Color(0xFFCBD5E1)),
                              ),
                              child: const Text(
                                'Selesai',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF475569),
                                ),
                              ),
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
                                backgroundColor: const Color(0xFF059669),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 3,
                              ),
                              child: const Text(
                                'Main Lagi',
                                style: TextStyle(fontWeight: FontWeight.w900),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatTile(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/image/games/Crying Green Frog Chibi Mascot.png',
              width: 100,
              height: 100,
              errorBuilder: (_, __, ___) => const MascotWidget(
                pose: MascotPose.holdingSign,
                size: 90,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Butuh minimal 2 kosakata untuk bermain.',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Kembali'),
            ),
          ],
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
