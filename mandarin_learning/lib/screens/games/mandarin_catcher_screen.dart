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

// FR-10: Mandarin Catcher
// Geser keranjang langsung dengan sentuhan/drag jari untuk menangkap kata Mandarin yang tepat!
// Fitur pendukung: accelerometer tilt opsional, 3 nyawa (hati), combo streak, animasi arcade.

class MandarinCatcherScreen extends StatefulWidget {
  const MandarinCatcherScreen({super.key});

  @override
  State<MandarinCatcherScreen> createState() => _MandarinCatcherScreenState();
}

class _MandarinCatcherScreenState extends State<MandarinCatcherScreen>
    with SingleTickerProviderStateMixin {
  static const double _catcherWidth = 116.0;
  static const double _catcherHeight = 72.0;
  static const double _objectWidth = 64.0;
  static const double _objectHeight = 84.0;
  static const int _gameDurationSecs = 30;
  static const double _fallSpeed = 2.8;

  // Game state
  double _catcherX = 140.0;
  List<_FallingObject> _fallingObjects = [];
  int _score = 0;
  int _combo = 0;
  int _maxCombo = 0;
  int _lives = 3;
  int _missedTargets = 0;
  bool _isPlaying = false;
  bool _gameOver = false;
  int _timeRemaining = _gameDurationSecs;
  bool _isLoading = true;
  bool _useSensorTilt = false;

  // Sensor
  bool _sensorAvailable = false;
  StreamSubscription<AccelerometerEvent>? _accelSub;
  double _accelX = 0;

  Timer? _gameTimer;
  Timer? _spawnTimer;
  late AnimationController _tickController;

  List<VocabularyItem> _allWords = [];
  VocabularyItem? _targetWord;
  final List<VocabularyItem> _caughtWords = [];
  final Random _rng = Random();

  double _screenWidth = 360.0;

  @override
  void initState() {
    super.initState();
    _tickController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 16),
    )..addListener(_tick);
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  @override
  void dispose() {
    _accelSub?.cancel();
    _gameTimer?.cancel();
    _spawnTimer?.cancel();
    _tickController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final vocab = context.read<VocabularyProvider>();
    _allWords = vocab.currentLevelVocabulary;

    if (_allWords.length < 3) {
      setState(() => _isLoading = false);
      return;
    }

    _pickNewTargetWord();
    _screenWidth = MediaQuery.of(context).size.width;
    _catcherX = (_screenWidth - _catcherWidth) / 2;

    // Cek sensor accelerometer
    try {
      _accelSub =
          accelerometerEventStream(
            samplingPeriod: const Duration(milliseconds: 50),
          ).listen(
            (event) {
              if (!mounted) return;
              _accelX = event.x;
            },
            onError: (_) {
              if (mounted) setState(() => _sensorAvailable = false);
            },
          );
      await Future.delayed(const Duration(milliseconds: 300));
      _sensorAvailable = true;
    } catch (_) {
      _sensorAvailable = false;
    }

    if (mounted) setState(() => _isLoading = false);
  }

  void _pickNewTargetWord() {
    if (_allWords.isEmpty) return;
    _targetWord = _allWords[_rng.nextInt(_allWords.length)];
  }

  void _startGame() {
    _pickNewTargetWord();
    setState(() {
      _score = 0;
      _combo = 0;
      _maxCombo = 0;
      _lives = 3;
      _missedTargets = 0;
      _caughtWords.clear();
      _timeRemaining = _gameDurationSecs;
      _fallingObjects = [];
      _isPlaying = true;
      _gameOver = false;
      _catcherX = (_screenWidth - _catcherWidth) / 2;
    });

    _tickController.repeat();

    // Spawn falling objects secara teratur
    _spawnTimer = Timer.periodic(const Duration(milliseconds: 900), (t) {
      if (!mounted || _gameOver) {
        t.cancel();
        return;
      }
      _spawnObject();
    });

    // Countdown timer
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
    if (!mounted || _gameOver || _targetWord == null) return;

    // 45% peluang target word, 55% distractor.
    final isTarget = _rng.nextDouble() < 0.45;
    final distractors = _allWords
        .where((word) => word.id != _targetWord!.id)
        .toList();
    final word = isTarget
        ? _targetWord!
        : distractors[_rng.nextInt(distractors.length)];

    final maxX = _screenWidth - _objectWidth - 20;
    final x = (20 + _rng.nextDouble() * max(0.0, maxX)).clamp(10.0, maxX);

    final obj = _FallingObject(
      id: DateTime.now().microsecondsSinceEpoch,
      x: x,
      y: -_objectHeight,
      word: word,
      isTarget: isTarget,
      colorIndex: _rng.nextInt(4),
    );

    setState(() => _fallingObjects.add(obj));
  }

  void _tick() {
    if (!mounted || !_isPlaying || _gameOver) return;

    // Gerak via sensor tilt jika diaktifkan
    if (_useSensorTilt && _sensorAvailable) {
      _catcherX -= _accelX * 0.7;
    }
    _catcherX = _catcherX.clamp(0.0, _screenWidth - _catcherWidth);

    final screenHeight = MediaQuery.of(context).size.height;
    final catcherY = screenHeight - 160.0;
    final catcherRect = Rect.fromLTWH(
      _catcherX,
      catcherY,
      _catcherWidth,
      _catcherHeight,
    );

    final toRemove = <_FallingObject>[];

    for (final obj in _fallingObjects) {
      obj.y += _fallSpeed;

      final objRect = Rect.fromLTWH(obj.x, obj.y, _objectWidth, _objectHeight);

      // Cek tabrakan objek dengan keranjang
      if (objRect.overlaps(catcherRect)) {
        toRemove.add(obj);

        if (obj.isTarget) {
          // ✅ Tertangkap target yang benar!
          _combo++;
          if (_combo > _maxCombo) _maxCombo = _combo;
          _score++;
          _caughtWords.add(obj.word);
          AudioService.instance.speak(obj.word.hanzi);
        } else {
          // ❌ Menangkap kata distractor! Kurangi nyawa
          _combo = 0;
          _lives--;
          if (_lives <= 0) {
            _endGame();
            return;
          }
        }
      } else if (obj.y > screenHeight - 140) {
        // Terlewat ke bawah layar
        toRemove.add(obj);
        if (obj.isTarget) {
          _missedTargets++;
          _combo = 0;
        }
      }
    }

    setState(() {
      _fallingObjects.removeWhere((o) => toRemove.contains(o));
    });
  }

  void _endGame() {
    _tickController.stop();
    _spawnTimer?.cancel();
    _gameTimer?.cancel();

    setState(() {
      _isPlaying = false;
      _gameOver = true;
    });

    _saveGameResult();
  }

  Future<void> _saveGameResult() async {
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    final vocab = context.read<VocabularyProvider>();
    final userId = auth.profile?.id ?? 'guest_local_user';

    final totalTargetItems = _caughtWords.length + _missedTargets;
    final accuracy = totalTargetItems > 0
        ? _caughtWords.length / totalTargetItems
        : 0.0;

    // PRD 6.1: reward 15, 10, atau 5 koin
    final coins = accuracy >= 0.75
        ? 15
        : accuracy >= 0.45
        ? 10
        : 5;
    final attemptId = 'catcher_${DateTime.now().millisecondsSinceEpoch}';

    await auth.addCoins(
      coins,
      'mandarin_catcher',
      'Mandarin Catcher: ${_caughtWords.length} kata tertangkap',
      attemptId: attemptId,
    );

    await vocab.recordQuizAttempt(
      QuizAttempt(
        id: attemptId,
        userId: userId,
        hskLevel: vocab.selectedLevel,
        quizType: 'mandarin_catcher',
        score: (accuracy * 100).round(),
        totalQuestions: max(1, totalTargetItems),
        correctAnswers: _caughtWords.length,
        coinsEarned: coins,
        createdAt: DateTime.now(),
      ),
    );
  }

  // Handle direct finger drag on the basket
  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (!_isPlaying || _gameOver) return;
    setState(() {
      _catcherX = (_catcherX + details.delta.dx).clamp(
        0.0,
        _screenWidth - _catcherWidth,
      );
    });
  }

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
              _buildCatcherMascot(width: 110, height: 126),
              const SizedBox(height: 16),
              const Text('Butuh minimal 3 kosakata untuk mulai bermain.'),
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

    if (_gameOver) return _buildGameOverScreen();
    if (!_isPlaying) return _buildWelcomeScreen();

    return _buildActivePlayScreen();
  }

  // 1. Welcome / Intro Screen
  Widget _buildWelcomeScreen() {
    return Scaffold(
      backgroundColor: AppColors.mintBackground,
      appBar: AppBar(
        title: const Text('Mandarin Catcher'),
        actions: [
          IconButton(
            tooltip: 'Panduan',
            icon: const Icon(Icons.help_outline_rounded),
            onPressed: () {},
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildCatcherMascot(width: 124, height: 142),
                const SizedBox(height: 16),
                const Text(
                  'Mandarin Catcher 🧺',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryDark,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Geser keranjang ke kiri dan kanan untuk menangkap kata Mandarin yang diminta!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textMuted,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),

                // Target preview card
                if (_targetWord != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFFBBF7D0),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        const Text(
                          '🎯 KOSAKATA TARGET KAMU',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                            color: Color(0xFFB45309),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _targetWord!.hanzi,
                              style: const TextStyle(
                                fontSize: 44,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryDark,
                              ),
                            ),
                            const SizedBox(width: 12),
                            IconButton(
                              onPressed: () => AudioService.instance.speak(
                                _targetWord!.hanzi,
                              ),
                              icon: const Icon(
                                Icons.volume_up_rounded,
                                color: AppColors.primaryGreen,
                                size: 28,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          _targetWord!.pinyin,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryGreen,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _targetWord!.artiIndonesia,
                          style: const TextStyle(
                            fontSize: 15,
                            color: AppColors.textDark,
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 20),

                // Control Mode Selector
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.touch_app_rounded,
                        color: AppColors.primaryGreen,
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Kontrol Sentuh & Geser (Rekomendasi)',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Geser jari di layar bawah untuk memindahkan keranjang',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_sensorAvailable)
                        Switch(
                          value: _useSensorTilt,
                          activeThumbColor: AppColors.primaryGreen,
                          onChanged: (val) =>
                              setState(() => _useSensorTilt = val),
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
                        borderRadius: BorderRadius.circular(18),
                      ),
                      elevation: 4,
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.play_arrow_rounded, size: 28),
                        SizedBox(width: 8),
                        Text(
                          'Mulai Menangkap!',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
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

  // 2. Active Game Screen
  Widget _buildActivePlayScreen() {
    return Scaffold(
      body: GestureDetector(
        onHorizontalDragUpdate: _onHorizontalDragUpdate,
        child: Stack(
          children: [
            const Positioned.fill(
              child: CustomPaint(painter: _CatcherGardenPainter()),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF4FFF5)
                              .withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.9),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF145C50)
                                  .withValues(alpha: 0.2),
                              blurRadius: 16,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: const Text(
                          'TANGKAP KATA YANG BENAR!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF174A3F),
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildGameBadge(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: List.generate(
                                3,
                                (i) => Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 1,
                                  ),
                                  child: Icon(
                                    Icons.favorite_rounded,
                                    size: 17,
                                    color: i < _lives
                                        ? const Color(0xFFEF5C62)
                                        : const Color(0xFFAA9B92),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          _buildGameBadge(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.timer_rounded,
                                  size: 16,
                                  color: Color(0xFF39776C),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '$_timeRemaining dtk',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: _timeRemaining <= 5
                                        ? const Color(0xFFCE3434)
                                        : const Color(0xFF24594F),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _buildGameBadge(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.star_rounded,
                                  size: 18,
                                  color: Color(0xFFF2A925),
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  '$_score',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF7B4A12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (_targetWord != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.92),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: const Color(0xFFB6E2D4),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF145C50)
                                    .withValues(alpha: 0.16),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.south_rounded,
                                color: Color(0xFF398C70),
                                size: 22,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'CARI: ${_targetWord!.artiIndonesia.toUpperCase()}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Color(0xFF377265),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    Text(
                                      '${_targetWord!.hanzi}  ·  ${_targetWord!.pinyin}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Color(0xFF193F38),
                                        fontSize: 17,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (_combo > 1)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFE6A8),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    'x$_combo 🔥',
                                    style: const TextStyle(
                                      color: Color(0xFF9C5B12),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            ..._fallingObjects.map(
              (obj) => Positioned(
                left: obj.x,
                top: obj.y,
                child: _buildFallingEgg(obj),
              ),
            ),
            Positioned(
              left: _catcherX,
              bottom: 88,
              child: _buildCatcherBasket(),
            ),
            Positioned(
              bottom: 18,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF164F49).withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.45),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.swipe_rounded, color: Colors.white, size: 17),
                      SizedBox(width: 7),
                      Text(
                        'Geser untuk menggerakkan keranjang',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCatcherMascot({required double width, required double height}) {
    final fullHeight = height / 0.74;
    return ClipRect(
      child: SizedBox(
        width: width,
        height: height,
        child: OverflowBox(
          alignment: Alignment.topCenter,
          minWidth: width,
          maxWidth: width,
          minHeight: fullHeight,
          maxHeight: fullHeight,
          child: Image.asset(
            'assets/image/landing_page/01_maskot.png',
            width: width,
            height: fullHeight,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }

  Widget _buildGameBadge({required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF174A3F).withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildFallingEgg(_FallingObject obj) {
    const eggColors = [
      (Color(0xFFFFF3D6), Color(0xFFE9C991), Color(0xFF684E35)),
      (Color(0xFFE0F1E6), Color(0xFFB8D3BD), Color(0xFF365C49)),
      (Color(0xFFE9E5F6), Color(0xFFC9C1E2), Color(0xFF554B70)),
      (Color(0xFFFFE5DC), Color(0xFFE9BBAE), Color(0xFF70483E)),
    ];
    final (light, dark, ink) = eggColors[obj.colorIndex];
    return SizedBox(
      width: _objectWidth,
      height: _objectHeight,
      child: Center(
        child: Container(
          width: 56,
          height: 74,
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.all(Radius.elliptical(30, 40)),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [light, dark],
            ),
            border: Border.all(
              color: const Color(0xFFFFFDF4).withValues(alpha: 0.85),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF194F45).withValues(alpha: 0.16),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  width: 6,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.46),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        obj.word.hanzi,
                        style: TextStyle(
                          color: ink,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          height: 1.1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        obj.word.pinyin,
                        style: TextStyle(
                          color: ink.withValues(alpha: 0.85),
                          fontSize: 8,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCatcherBasket() {
    return SizedBox(
      width: _catcherWidth,
      height: 164,
      child: Stack(
        alignment: Alignment.bottomCenter,
        clipBehavior: Clip.none,
        children: [
          Positioned(
            bottom: 26,
            child: _buildCatcherMascot(width: 126, height: 144),
          ),
          Positioned(
            bottom: 0,
            child: CustomPaint(
              size: Size(_catcherWidth, _catcherHeight),
              painter: _WovenBasketPainter(),
            ),
          ),
        ],
      ),
    );
  }

  // 3. Game Over Screen
  Widget _buildGameOverScreen() {
    final totalTargetItems = _caughtWords.length + _missedTargets;
    final accuracy = totalTargetItems > 0
        ? _caughtWords.length / totalTargetItems
        : 0.0;
    final coins = accuracy >= 0.75
        ? 15
        : accuracy >= 0.45
        ? 10
        : 5;
    final stars = accuracy >= 0.75
        ? 3
        : accuracy >= 0.45
        ? 2
        : 1;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/image/games/mandarin_catcher_night.png',
              fit: BoxFit.cover,
              alignment: Alignment.bottomCenter,
            ),
          ),
          Positioned.fill(child: ColoredBox(color: Color(0x33070E36))),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.91),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.9),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF07112B).withValues(alpha: 0.28),
                        blurRadius: 28,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildCatcherMascot(width: 124, height: 142),
                      const SizedBox(height: 16),
                      Text(
                        stars == 3
                            ? '🎉 Tangkapan Sempurna!'
                            : stars == 2
                            ? '👍 Bagus Sekali!'
                            : '💪 Latihan Lagi Yuk!',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryDark,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Stars rating
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          3,
                          (i) => Icon(
                            i < stars
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            color: const Color(0xFFF59E0B),
                            size: 38,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Stats Cards
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatTile(
                              '🎯 Skor',
                              '$_score',
                              AppColors.primaryDark,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildStatTile(
                              '✅ Tertangkap',
                              '${_caughtWords.length}',
                              AppColors.primaryGreen,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildStatTile(
                              '🔥 Max Combo',
                              'x$_maxCombo',
                              const Color(0xFFEA580C),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Reward Koin
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFF59E0B)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('🪙', style: TextStyle(fontSize: 22)),
                            const SizedBox(width: 8),
                            Text(
                              'Bonus Hadiah: +$coins Koin',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFB45309),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: const Text('Keluar'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _startGame,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryGreen,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
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
          ),
        ],
      ),
    );
  }

  Widget _buildStatTile(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
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
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
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
  final int colorIndex;

  _FallingObject({
    required this.id,
    required this.x,
    required this.y,
    required this.word,
    required this.isTarget,
    this.colorIndex = 0,
  });
}

class _CatcherGardenPainter extends CustomPainter {
  const _CatcherGardenPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;
    final rect = Offset.zero & size;

    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF65C9B3), Color(0xFF32AFA4), Color(0xFF168E8D)],
        ).createShader(rect),
    );

    final waterGlow = Paint()
      ..color = const Color(0xFFB9F4D8).withValues(alpha: 0.24)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 15; i++) {
      final x = width * (0.34 + (i * 0.137) % 0.62);
      final y = height * (0.12 + (i * 0.173) % 0.66);
      final waveWidth = 12.0 + (i % 4) * 7;
      canvas.drawLine(Offset(x, y), Offset(x + waveWidth, y - 3), waterGlow);
    }

    final bank = Path()
      ..moveTo(0, height * 0.43)
      ..quadraticBezierTo(
        width * 0.15,
        height * 0.36,
        width * 0.27,
        height * 0.47,
      )
      ..quadraticBezierTo(
        width * 0.4,
        height * 0.58,
        width * 0.59,
        height * 0.66,
      )
      ..quadraticBezierTo(width * 0.82, height * 0.76, width, height * 0.72)
      ..lineTo(width, height)
      ..lineTo(0, height)
      ..close();
    canvas.drawPath(
      bank,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFAAA184), Color(0xFF6D6652)],
        ).createShader(rect),
    );

    canvas.save();
    canvas.clipPath(bank);
    const stoneColors = [
      Color(0xFFD0C7AA),
      Color(0xFFBEB596),
      Color(0xFFAAA184),
      Color(0xFFD7CEB1),
    ];
    final stoneShade = Paint()..color = const Color(0xFF716A55);
    for (var row = 0; row < 9; row++) {
      final y = height * 0.4 + row * 55;
      final offset = row.isEven ? -24.0 : 18.0;
      for (var column = -1; column < 7; column++) {
        final x = offset + column * 78;
        final stonePaint = Paint()
          ..color = stoneColors[(row + column).abs() % 4];
        final stone = RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, 70, 48),
          const Radius.circular(8),
        );
        canvas.drawRRect(stone.shift(const Offset(1, 4)), stoneShade);
        canvas.drawRRect(stone, stonePaint);
        canvas.drawLine(
          Offset(x + 9, y + 9),
          Offset(x + 35, y + 9),
          Paint()
            ..color = Colors.white.withValues(alpha: 0.24)
            ..strokeWidth = 2.5,
        );
      }
    }
    canvas.restore();

    final shoreline = Path()
      ..moveTo(0, height * 0.43)
      ..quadraticBezierTo(
        width * 0.15,
        height * 0.36,
        width * 0.27,
        height * 0.47,
      )
      ..quadraticBezierTo(
        width * 0.4,
        height * 0.58,
        width * 0.59,
        height * 0.66,
      )
      ..quadraticBezierTo(width * 0.82, height * 0.76, width, height * 0.72);
    canvas.drawPath(
      shoreline,
      Paint()
        ..color = const Color(0xFFDFD4AA).withValues(alpha: 0.62)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );

    _drawLeaf(canvas, Offset(width * 0.02, height * 0.48), -0.75, 92);
    _drawLeaf(canvas, Offset(width * 0.08, height * 0.37), -0.15, 78);
    _drawLeaf(canvas, Offset(width * 0.15, height * 0.46), 0.55, 86);
    _drawLeaf(canvas, Offset(width * 0.01, height * 0.61), -1.1, 90);
    _drawLeaf(canvas, Offset(width * 0.24, height * 0.48), -0.2, 60);
    _drawLeaf(canvas, Offset(width * 0.34, height * 0.57), 0.4, 54);
    _drawFlower(canvas, Offset(width * 0.37, height * 0.34), 0.8);
    _drawFlower(canvas, Offset(width * 0.25, height * 0.52), 0.58);

    final sparklePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.74)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (final point in [
      Offset(width * 0.82, height * 0.39),
      Offset(width * 0.93, height * 0.57),
      Offset(width * 0.65, height * 0.31),
    ]) {
      canvas.drawLine(
        point.translate(-5, 0),
        point.translate(5, 0),
        sparklePaint,
      );
      canvas.drawLine(
        point.translate(0, -5),
        point.translate(0, 5),
        sparklePaint,
      );
    }
  }

  void _drawLeaf(Canvas canvas, Offset origin, double angle, double length) {
    canvas.save();
    canvas.translate(origin.dx, origin.dy);
    canvas.rotate(angle);
    final leaf = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(length * 0.34, -length * 0.36, length, -length * 0.2)
      ..quadraticBezierTo(length * 0.82, length * 0.2, 0, 0)
      ..close();
    canvas.drawPath(
      leaf,
      Paint()..color = const Color(0xFF287D50).withValues(alpha: 0.82),
    );
    canvas.drawLine(
      Offset.zero,
      Offset(length * 0.82, -length * 0.18),
      Paint()
        ..color = const Color(0xFF9BD58B).withValues(alpha: 0.7)
        ..strokeWidth = 1.5,
    );
    canvas.restore();
  }

  void _drawFlower(Canvas canvas, Offset center, double scale) {
    final stem = Paint()
      ..color = const Color(0xFF357A4F)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      center.translate(0, 6 * scale),
      center.translate(-8 * scale, 45 * scale),
      stem,
    );
    for (var i = 0; i < 5; i++) {
      final angle = i * pi * 2 / 5;
      canvas.drawOval(
        Rect.fromCenter(
          center: center.translate(
            cos(angle) * 9 * scale,
            sin(angle) * 9 * scale,
          ),
          width: 11 * scale,
          height: 17 * scale,
        ),
        Paint()..color = const Color(0xFF8A79D6),
      );
    }
    canvas.drawCircle(
      center,
      5 * scale,
      Paint()..color = const Color(0xFFF4D36B),
    );
  }

  @override
  bool shouldRepaint(covariant _CatcherGardenPainter oldDelegate) => false;
}

class _WovenBasketPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;
    final handle = Path()
      ..moveTo(width * 0.24, height * 0.49)
      ..cubicTo(
        width * 0.22,
        height * -0.08,
        width * 0.78,
        height * -0.08,
        width * 0.76,
        height * 0.49,
      );
    canvas.drawPath(
      handle,
      Paint()
        ..color = const Color(0xFF9A5928)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      handle,
      Paint()
        ..color = const Color(0xFFFFD38B)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );

    final basket = Path()
      ..moveTo(width * 0.04, height * 0.22)
      ..quadraticBezierTo(
        width * 0.5,
        height * 0.37,
        width * 0.96,
        height * 0.22,
      )
      ..lineTo(width * 0.84, height * 0.91)
      ..quadraticBezierTo(
        width * 0.5,
        height * 1.08,
        width * 0.16,
        height * 0.91,
      )
      ..close();
    canvas.drawPath(
      basket,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFE9B765), Color(0xFFB96F35)],
        ).createShader(Offset.zero & size),
    );

    canvas.save();
    canvas.clipPath(basket);
    for (var row = 0; row < 5; row++) {
      final y = height * (0.38 + row * 0.12);
      final curve = Path()
        ..moveTo(width * 0.1, y)
        ..quadraticBezierTo(width * 0.5, y + 8, width * 0.9, y);
      canvas.drawPath(
        curve,
        Paint()
          ..color = row.isEven
              ? const Color(0xFFFFD58D)
              : const Color(0xFF92542D)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5,
      );
    }
    for (var column = 0; column < 6; column++) {
      final x = width * (0.12 + column * 0.15);
      final weave = Path()
        ..moveTo(x, height * 0.28)
        ..quadraticBezierTo(x - 8, height * 0.58, x + 2, height * 0.94);
      canvas.drawPath(
        weave,
        Paint()
          ..color = column.isEven
              ? const Color(0xFFFFD58D)
              : const Color(0xFF9D5B30)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4,
      );
    }
    canvas.restore();
    canvas.drawPath(
      basket,
      Paint()
        ..color = const Color(0xFF89502D)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawOval(
      Rect.fromLTWH(0, height * 0.13, width, height * 0.28),
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFFFD78D), Color(0xFFB86B32)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawOval(
      Rect.fromLTWH(0, height * 0.13, width, height * 0.28),
      Paint()
        ..color = const Color(0xFF98552D)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(covariant _WovenBasketPainter oldDelegate) => false;
}
