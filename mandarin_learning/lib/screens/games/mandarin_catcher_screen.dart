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
import '../../widgets/mascot_widget.dart';

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
  static const double _catcherWidth = 84.0;
  static const double _catcherHeight = 44.0;
  static const double _objectSize = 58.0;
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
      _accelSub = accelerometerEventStream(
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

    // 45% peluang target word, 55% distractor
    final isTarget = _rng.nextDouble() < 0.45;
    final word = isTarget ? _targetWord! : _allWords[_rng.nextInt(_allWords.length)];

    final maxX = _screenWidth - _objectSize - 20;
    final x = (20 + _rng.nextDouble() * max(0.0, maxX)).clamp(10.0, maxX);

    final obj = _FallingObject(
      id: DateTime.now().microsecondsSinceEpoch,
      x: x,
      y: -_objectSize,
      word: word,
      isTarget: isTarget && word.id == _targetWord!.id,
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
    final catcherY = screenHeight - 210.0;
    final catcherRect = Rect.fromLTWH(
      _catcherX,
      catcherY,
      _catcherWidth,
      _catcherHeight,
    );

    final toRemove = <_FallingObject>[];

    for (final obj in _fallingObjects) {
      obj.y += _fallSpeed;

      final objRect = Rect.fromLTWH(obj.x, obj.y, _objectSize, _objectSize);

      // Cek tabrakan objek dengan keranjang
      if (objRect.overlaps(catcherRect)) {
        toRemove.add(obj);

        if (obj.isTarget) {
          // ✅ Tertangkap target yang benar!
          _combo++;
          if (_combo > _maxCombo) _maxCombo = _combo;
          final bonusPoints = 10 + (_combo > 1 ? (_combo * 2) : 0);
          _score += bonusPoints;
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
    final accuracy = totalTargetItems > 0 ? _caughtWords.length / totalTargetItems : 0.0;

    // PRD 6.1: reward 15, 10, atau 5 koin
    final coins = accuracy >= 0.75 ? 15 : accuracy >= 0.45 ? 10 : 5;
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
        score: (_score / 2).round().clamp(0, 100),
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
      _catcherX = (_catcherX + details.delta.dx).clamp(0.0, _screenWidth - _catcherWidth);
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
              const MascotWidget(pose: MascotPose.holdingSign, size: 100),
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
                const MascotWidget(pose: MascotPose.celebrating, size: 110),
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
                  style: TextStyle(fontSize: 13, color: AppColors.textMuted, height: 1.4),
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
                      border: Border.all(color: const Color(0xFFBBF7D0), width: 1.5),
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
                              onPressed: () => AudioService.instance.speak(_targetWord!.hanzi),
                              icon: const Icon(Icons.volume_up_rounded, color: AppColors.primaryGreen, size: 28),
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
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.touch_app_rounded, color: AppColors.primaryGreen),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Kontrol Sentuh & Geser (Rekomendasi)',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Geser jari di layar bawah untuk memindahkan keranjang',
                              style: TextStyle(fontSize: 10, color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                      if (_sensorAvailable)
                        Switch(
                          value: _useSensorTilt,
                          activeThumbColor: AppColors.primaryGreen,
                          onChanged: (val) => setState(() => _useSensorTilt = val),
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
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
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
        // User can drag anywhere on screen horizontally to position the basket!
        onHorizontalDragUpdate: _onHorizontalDragUpdate,
        child: Stack(
          children: [
            // Sky gradient background
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF0F2027),
                    Color(0xFF203A43),
                    Color(0xFF2C5364),
                  ],
                ),
              ),
            ),

            // Subtle Bamboo silhouettes at sides
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 20,
              child: Container(
                color: Colors.green.withValues(alpha: 0.05),
              ),
            ),

            // Top HUD
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Nyawa / Lives
                        Row(
                          children: List.generate(
                            3,
                            (i) => Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: Text(
                                i < _lives ? '❤️' : '🖤',
                                style: const TextStyle(fontSize: 18),
                              ),
                            ),
                          ),
                        ),
                        // Timer
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.timer_outlined, color: Colors.white70, size: 16),
                              const SizedBox(width: 4),
                              Text(
                                '$_timeRemaining dtk',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _timeRemaining <= 5 ? Colors.redAccent : Colors.white,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Score
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD97706).withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFF59E0B)),
                          ),
                          child: Text(
                            '🌟 $_score',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFFCD34D),
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Target Banner
                    if (_targetWord != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              '🎯 Tangkap: ',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Color(0xFFB45309),
                              ),
                            ),
                            Text(
                              _targetWord!.hanzi,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryDark,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '(${_targetWord!.artiIndonesia})',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textMuted,
                              ),
                            ),
                            if (_combo > 1) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEF4444),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Combo x$_combo! 🔥',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Falling Objects (Lampion / Emas dengan Hanzi)
            ..._fallingObjects.map(
              (obj) => Positioned(
                left: obj.x,
                top: obj.y,
                child: _buildFallingLantern(obj),
              ),
            ),

            // Woven Basket Catcher
            Positioned(
              left: _catcherX,
              bottom: 160,
              child: _buildCatcherBasket(),
            ),

            // Drag Helper Hint bar at bottom
            Positioned(
              bottom: 24,
              left: 24,
              right: 24,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.swipe_rounded, color: Colors.white70, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Geser jari di layar ke kiri / kanan untuk gerakkan keranjang',
                        style: TextStyle(fontSize: 11, color: Colors.white70),
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

  Widget _buildFallingLantern(_FallingObject obj) {
    return Container(
      width: _objectSize,
      height: _objectSize,
      decoration: BoxDecoration(
        color: obj.isTarget ? const Color(0xFFFFFBEB) : Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: obj.isTarget ? const Color(0xFFF59E0B) : const Color(0xFFCBD5E1),
          width: obj.isTarget ? 2.5 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: obj.isTarget
                ? const Color(0xFFF59E0B).withValues(alpha: 0.5)
                : Colors.black.withValues(alpha: 0.15),
            blurRadius: obj.isTarget ? 12 : 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              obj.word.hanzi,
              style: TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.bold,
                color: obj.isTarget ? const Color(0xFFB45309) : AppColors.primaryDark,
              ),
            ),
            Text(
              obj.word.pinyin,
              style: TextStyle(
                fontSize: 9,
                color: obj.isTarget ? const Color(0xFFD97706) : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCatcherBasket() {
    return Container(
      width: _catcherWidth,
      height: _catcherHeight,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF10B981), Color(0xFF047857)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(20),
          top: Radius.circular(8),
        ),
        border: Border.all(color: const Color(0xFF6EE7B7), width: 2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withValues(alpha: 0.45),
            blurRadius: 16,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: const Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('🧺', style: TextStyle(fontSize: 22)),
            SizedBox(width: 4),
            Text('🐼', style: TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }

  // 3. Game Over Screen
  Widget _buildGameOverScreen() {
    final totalTargetItems = _caughtWords.length + _missedTargets;
    final accuracy = totalTargetItems > 0 ? _caughtWords.length / totalTargetItems : 0.0;
    final coins = accuracy >= 0.75 ? 15 : accuracy >= 0.45 ? 10 : 5;
    final stars = accuracy >= 0.75 ? 3 : accuracy >= 0.45 ? 2 : 1;

    return Scaffold(
      backgroundColor: AppColors.mintBackground,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                MascotWidget(
                  pose: stars >= 2 ? MascotPose.celebrating : MascotPose.studying,
                  size: 110,
                ),
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
                      i < stars ? Icons.star_rounded : Icons.star_outline_rounded,
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
                      child: _buildStatTile('🎯 Skor', '$_score', AppColors.primaryDark),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildStatTile('✅ Tertangkap', '${_caughtWords.length}', AppColors.primaryGreen),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildStatTile('🔥 Max Combo', 'x$_maxCombo', const Color(0xFFEA580C)),
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
                          padding: const EdgeInsets.symmetric(vertical: 14),
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
                          padding: const EdgeInsets.symmetric(vertical: 14),
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
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
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

  _FallingObject({
    required this.id,
    required this.x,
    required this.y,
    required this.word,
    required this.isTarget,
  });
}
