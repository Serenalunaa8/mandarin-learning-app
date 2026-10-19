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
import '../../widgets/mascot_widget.dart';

// FR-10: Mandarin Catcher — accelerometer menggerakkan catcher
// Tangkap kosakata target, hindari distractor
// Fallback: tombol kiri/kanan jika sensor tidak tersedia

class MandarinCatcherScreen extends StatefulWidget {
  const MandarinCatcherScreen({super.key});

  @override
  State<MandarinCatcherScreen> createState() => _MandarinCatcherScreenState();
}

class _MandarinCatcherScreenState extends State<MandarinCatcherScreen>
    with SingleTickerProviderStateMixin {
  static const double _catcherWidth = 80;
  static const double _catcherHeight = 40;
  static const double _objectSize = 54;
  static const int _gameDurationSecs = 30;
  static const double _fallSpeed = 2.5; // px per frame
  static const double _sensitivity = 18.0;

  // Game state
  double _catcherX = 0;
  List<_FallingObject> _fallingObjects = [];
  int _score = 0;
  int _missed = 0;
  bool _isPlaying = false;
  bool _gameOver = false;
  int _timeRemaining = _gameDurationSecs;
  bool _isLoading = true;

  // Sensor
  bool _sensorAvailable = false;
  StreamSubscription<AccelerometerEvent>? _accelSub;
  double _accelX = 0;

  // Manual control
  Timer? _leftTimer;
  Timer? _rightTimer;

  Timer? _gameTimer;
  Timer? _tickTimer;
  late AnimationController _tickController;

  List<VocabularyItem> _targetWords = [];
  List<VocabularyItem> _allWords = [];
  VocabularyItem? _targetWord;
  final Random _rng = Random();

  double _screenWidth = 360;

  @override
  void initState() {
    super.initState();
    _tickController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 16), // ~60fps
    )..addListener(_tick);
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  @override
  void dispose() {
    _accelSub?.cancel();
    _gameTimer?.cancel();
    _tickTimer?.cancel();
    _leftTimer?.cancel();
    _rightTimer?.cancel();
    _tickController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final vocab = context.read<VocabularyProvider>();
    _allWords = vocab.currentLevelVocabulary;
    _targetWords = _allWords.take(20).toList();

    if (_allWords.length < 3) {
      setState(() => _isLoading = false);
      return;
    }

    // Pick a target word for this session
    _targetWord = _targetWords[_rng.nextInt(_targetWords.length)];
    _screenWidth = MediaQuery.of(context).size.width;
    _catcherX = _screenWidth / 2 - _catcherWidth / 2;

    // Try sensor
    try {
      _accelSub =
          accelerometerEventStream(
            samplingPeriod: const Duration(milliseconds: 50),
          ).listen((event) {
            if (!mounted) return;
            _accelX = event.x;
          }, onError: (_) => _sensorAvailable = false);
      await Future.delayed(const Duration(milliseconds: 400));
      _sensorAvailable = true;
    } catch (_) {
      _sensorAvailable = false;
    }

    setState(() => _isLoading = false);
  }

  void _startGame() {
    setState(() {
      _score = 0;
      _missed = 0;
      _timeRemaining = _gameDurationSecs;
      _fallingObjects = [];
      _isPlaying = true;
      _gameOver = false;
      _catcherX = _screenWidth / 2 - _catcherWidth / 2;
    });

    _tickController.repeat();

    // Spawn objects
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted || _gameOver) {
        t.cancel();
        return;
      }
      _spawnObject();
    });

    // Countdown
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _timeRemaining--);
      if (_timeRemaining <= 0) {
        t.cancel();
        _endGame();
      }
    });
  }

  void _spawnObject() {
    if (!mounted || _gameOver) return;
    final isTarget = _rng.nextDouble() < 0.45; // 45% chance target
    final word = isTarget
        ? _targetWord!
        : _allWords[_rng.nextInt(_allWords.length)];

    final obj = _FallingObject(
      id: DateTime.now().microsecondsSinceEpoch,
      x: _rng.nextDouble() * (_screenWidth - _objectSize),
      y: -_objectSize,
      word: word,
      isTarget: isTarget && word.id == _targetWord!.id,
    );

    setState(() => _fallingObjects.add(obj));
  }

  void _tick() {
    if (!mounted || !_isPlaying || _gameOver) return;

    // Move catcher via sensor
    if (_sensorAvailable) {
      _catcherX -= _accelX * (_sensitivity / 60);
    }
    _catcherX = _catcherX.clamp(0, _screenWidth - _catcherWidth);

    final catcherRect = Rect.fromLTWH(
      _catcherX,
      MediaQuery.of(context).size.height - 180,
      _catcherWidth,
      _catcherHeight,
    );

    final toRemove = <_FallingObject>[];
    for (final obj in _fallingObjects) {
      obj.y += _fallSpeed;

      final objRect = Rect.fromLTWH(obj.x, obj.y, _objectSize, _objectSize);

      if (objRect.overlaps(catcherRect)) {
        toRemove.add(obj);
        if (obj.isTarget) {
          _score++;
        } else {
          _missed++;
        }
      } else if (obj.y > MediaQuery.of(context).size.height - 100) {
        toRemove.add(obj);
        if (obj.isTarget) _missed++;
      }
    }

    setState(() {
      _fallingObjects.removeWhere((o) => toRemove.contains(o));
    });
  }

  void _endGame() {
    _tickController.stop();
    _tickTimer?.cancel();
    _gameTimer?.cancel();
    _accelSub?.cancel();

    setState(() {
      _isPlaying = false;
      _gameOver = true;
    });

    _saveResult();
  }

  Future<void> _saveResult() async {
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    final vocab = context.read<VocabularyProvider>();
    final userId = auth.profile?.id ?? 'guest_local_user';
    final total = _score + _missed;
    final percentage = total > 0 ? _score / total : 0.0;
    final coins = percentage >= 0.7
        ? 15
        : percentage >= 0.4
        ? 10
        : 5;
    final attemptId = 'catcher_${DateTime.now().millisecondsSinceEpoch}';

    await auth.addCoins(
      coins,
      'catcher_reward',
      'Hadiah Mandarin Catcher ($_score kosakata tertangkap)',
      attemptId: attemptId,
    );
    await vocab.recordQuizAttempt(
      QuizAttempt(
        id: attemptId,
        userId: userId,
        hskLevel: vocab.selectedLevel,
        quizType: 'mandarin_catcher',
        score: (_score * 10).clamp(0, 100),
        totalQuestions: total,
        correctAnswers: _score,
        coinsEarned: coins,
        createdAt: DateTime.now(),
      ),
    );
  }

  // Manual buttons
  void _holdLeft() {
    _leftTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (!mounted) return;
      setState(() {
        _catcherX = (_catcherX - 8).clamp(0, _screenWidth - _catcherWidth);
      });
    });
  }

  void _holdRight() {
    _rightTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (!mounted) return;
      setState(() {
        _catcherX = (_catcherX + 8).clamp(0, _screenWidth - _catcherWidth);
      });
    });
  }

  void _stopLeft() => _leftTimer?.cancel();
  void _stopRight() => _rightTimer?.cancel();

  @override
  Widget build(BuildContext context) {
    _screenWidth = MediaQuery.of(context).size.width;

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_allWords.length < 3) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mandarin Catcher')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const MascotWidget(pose: MascotPose.holdingSign, size: 100),
              const SizedBox(height: 16),
              const Text('Butuh minimal 3 kosakata untuk bermain.'),
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
    if (!_isPlaying) return _buildStartScreen();

    return _buildGameScreen();
  }

  Widget _buildStartScreen() {
    return Scaffold(
      backgroundColor: AppColors.mintBackground,
      appBar: AppBar(
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        title: const Text('Mandarin Catcher'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const MascotWidget(pose: MascotPose.waving, size: 120),
              const SizedBox(height: 24),
              const Text(
                'Tangkap Kosakata!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryDark,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Cara Bermain:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_targetWord != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Tangkap: ',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFB45309),
                              ),
                            ),
                            Text(
                              '${_targetWord!.hanzi} (${_targetWord!.artiIndonesia})',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryDark,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 8),
                    Text(
                      _sensorAvailable
                          ? '📱 Miringkan perangkat untuk gerakkan keranjang'
                          : '👆 Gunakan tombol ← → untuk gerakkan keranjang',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '⏱ 30 detik, hindari kata-kata lain!',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _startGame,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Mulai Bermain!',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGameScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFF1A3A5C),
      body: Stack(
        children: [
          // Sky background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF1A3A5C), Color(0xFF2D5A8E)],
              ),
            ),
          ),

          // HUD
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildHudChip('🎯 $_score', Colors.green),
                  _buildHudChip(
                    '⏱ $_timeRemaining',
                    _timeRemaining <= 10 ? Colors.red : Colors.white54,
                  ),
                  _buildHudChip('❌ $_missed', Colors.red),
                ],
              ),
            ),
          ),

          // Target word reminder
          if (_targetWord != null)
            Positioned(
              top: 60,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7).withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Tangkap: ${_targetWord!.hanzi}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFB45309),
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),

          // Falling objects
          ..._fallingObjects.map(
            (obj) => Positioned(
              left: obj.x,
              top: obj.y,
              child: _buildFallingWord(obj),
            ),
          ),

          // Catcher
          Positioned(left: _catcherX, bottom: 120, child: _buildCatcher()),

          // Manual controls if no sensor
          if (!_sensorAvailable)
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTapDown: (_) => _holdLeft(),
                    onTapUp: (_) => _stopLeft(),
                    onTapCancel: _stopLeft,
                    child: Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                  const SizedBox(width: 40),
                  GestureDetector(
                    onTapDown: (_) => _holdRight(),
                    onTapUp: (_) => _stopRight(),
                    onTapCancel: _stopRight,
                    child: Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: Colors.white,
                        size: 28,
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

  Widget _buildHudChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: color,
          fontSize: 15,
        ),
      ),
    );
  }

  Widget _buildFallingWord(_FallingObject obj) {
    return Container(
      width: _objectSize,
      height: _objectSize,
      decoration: BoxDecoration(
        color: obj.isTarget
            ? const Color(0xFFFEF3C7)
            : Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: obj.isTarget
              ? const Color(0xFFF59E0B)
              : Colors.white.withValues(alpha: 0.3),
          width: obj.isTarget ? 2 : 1,
        ),
      ),
      child: Center(
        child: Text(
          obj.word.hanzi,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: obj.isTarget
                ? const Color(0xFFB45309)
                : Colors.white.withValues(alpha: 0.8),
          ),
        ),
      ),
    );
  }

  Widget _buildCatcher() {
    return Container(
      width: _catcherWidth,
      height: _catcherHeight,
      decoration: BoxDecoration(
        color: AppColors.primaryGreen,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryGreen.withValues(alpha: 0.4),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
      child: const Center(child: Text('🧺', style: TextStyle(fontSize: 20))),
    );
  }

  Widget _buildGameOver() {
    final total = _score + _missed;
    final percentage = total > 0 ? _score / total : 0.0;
    final coins = percentage >= 0.7
        ? 15
        : percentage >= 0.4
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
                  pose: percentage >= 0.5
                      ? MascotPose.celebrating
                      : MascotPose.studying,
                  size: 120,
                ),
                const SizedBox(height: 24),
                Text(
                  percentage >= 0.7
                      ? '🎉 Tangkap Master!'
                      : percentage >= 0.4
                      ? '👍 Lumayan!'
                      : '💪 Terus Berlatih!',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryDark,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildStatCard('✅', '$_score', 'Ditangkap'),
                    const SizedBox(width: 12),
                    _buildStatCard('❌', '$_missed', 'Terlewat'),
                    const SizedBox(width: 12),
                    _buildStatCard('🪙', '+$coins', 'Koin'),
                  ],
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
                            _gameOver = false;
                            _isPlaying = false;
                            _targetWord =
                                _targetWords[_rng.nextInt(_targetWords.length)];
                          });
                          _startGame();
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

  Widget _buildStatCard(String emoji, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: AppColors.primaryDark,
            ),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _FallingObject {
  final int id;
  final double x;
  double y;
  final VocabularyItem word;
  final bool isTarget;

  _FallingObject({
    required this.id,
    required this.x,
    required this.y,
    required this.word,
    required this.isTarget,
  });
}
