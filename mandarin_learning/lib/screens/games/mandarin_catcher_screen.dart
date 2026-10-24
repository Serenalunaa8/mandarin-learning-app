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

/// FR-10: Mandarin Catcher Game
/// Catcher Mascot:
/// - Idle/normal: assets/image/games/Excited Green Frog Mascot.png
/// - Correct catch: assets/image/games/Blushing Green Sprout Mascot.png
/// - Wrong catch: assets/image/games/Crying Green Frog Chibi Mascot.png
/// Backgrounds: Multiple atmospheric game backgrounds from assets/image/games/
class MandarinCatcherScreen extends StatefulWidget {
  const MandarinCatcherScreen({super.key});

  @override
  State<MandarinCatcherScreen> createState() => _MandarinCatcherScreenState();
}

class _MandarinCatcherScreenState extends State<MandarinCatcherScreen>
    with SingleTickerProviderStateMixin {
  static const double _catcherWidth = 110.0;
  static const double _catcherHeight = 100.0;
  static const double _objectWidth = 68.0;
  static const double _objectHeight = 86.0;
  static const double _minimumEggGap = 88.0;
  static const int _maxFallingObjects = 2;
  static const int _gameDurationSecs = 30;
  static const int _wrongCatchLimit = 5;
  static const double _fallSpeed = 2.8;

  // Background choices from assets/image/games/
  static const List<Map<String, String>> _gameBackgrounds = [
    {
      'title': 'Langit Biru',
      'path': 'assets/image/games/background_2_langit_biru.png',
      'subtitle': 'Awan putih & langit cerah',
    },
    {
      'title': 'Padang Cerah',
      'path': 'assets/image/games/background_1_padang_cerah.png',
      'subtitle': 'Hamparan padang rumput',
    },
    {
      'title': 'Jalan Desa',
      'path': 'assets/image/games/background_3_jalan_desa.png',
      'subtitle': 'Jalan pedesaan asri',
    },
    {
      'title': 'Taman Bunga',
      'path': 'assets/image/games/background_4_taman_bunga.png',
      'subtitle': 'Taman bunga penuh warna',
    },
    {
      'title': 'Malam Danau',
      'path': 'assets/image/games/background_5_malam_dan_danau.png',
      'subtitle': 'Suasana malam tenang',
    },
  ];

  int _selectedBgIndex = 0;

  // Game state
  double _catcherX = 140.0;
  List<_FallingObject> _fallingObjects = [];
  int _score = 0;
  int _combo = 0;
  int _maxCombo = 0;
  int _wrongCaught = 0;
  int _missedTargets = 0;
  bool _isPlaying = false;
  bool _gameOver = false;
  int _timeRemaining = _gameDurationSecs;
  bool _isLoading = true;
  bool _useSensorTilt = false;

  // Mascot reaction state:
  // - true: dapat kata benar -> Blushing Green Sprout Mascot.png
  // - false: kata salah -> Crying Green Frog Chibi Mascot.png
  // - null: diam / normal -> Excited Green Frog Mascot.png
  bool? _catchReaction;
  String _reactionText = '';
  Timer? _reactionTimer;

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
    _reactionTimer?.cancel();
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
      _wrongCaught = 0;
      _missedTargets = 0;
      _caughtWords.clear();
      _timeRemaining = _gameDurationSecs;
      _fallingObjects = [];
      _isPlaying = true;
      _gameOver = false;
      _catcherX = (_screenWidth - _catcherWidth) / 2;
      _catchReaction = null;
      _reactionText = '';
    });

    _tickController.repeat();

    // Spawn falling objects secara teratur
    _spawnTimer = Timer.periodic(const Duration(milliseconds: 2400), (t) {
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
    if (distractors.isEmpty) return;

    final word = isTarget
        ? _targetWord!
        : distractors[_rng.nextInt(distractors.length)];

    if (_fallingObjects.length >= _maxFallingObjects) return;

    final maxX = max(10.0, _screenWidth - _objectWidth - 10);
    double? spacedX;
    for (var attempt = 0; attempt < 40; attempt++) {
      final candidate = 10 + _rng.nextDouble() * (maxX - 10);
      final isSeparated = _fallingObjects.every(
        (existing) =>
            (existing.x - candidate).abs() >=
            _objectWidth + _minimumEggGap,
      );
      if (isSeparated) {
        spacedX = candidate;
        break;
      }
    }
    if (spacedX == null) return;

    final obj = _FallingObject(
      id: DateTime.now().microsecondsSinceEpoch,
      x: spacedX,
      y: -_objectHeight,
      word: word,
      isTarget: isTarget,
      colorIndex: _rng.nextInt(4),
    );

    setState(() => _fallingObjects.add(obj));
  }

  void _triggerCatchReaction(bool isCorrect) {
    _reactionTimer?.cancel();
    setState(() {
      _catchReaction = isCorrect;
      _reactionText = isCorrect ? '+1 Benar! ✨' : 'Salah! 😭';
    });
    _reactionTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() {
          _catchReaction = null;
          _reactionText = '';
        });
      }
    });
  }

  void _tick() {
    if (!mounted || !_isPlaying || _gameOver) return;

    // Gerak via sensor tilt jika diaktifkan
    if (_useSensorTilt && _sensorAvailable) {
      _catcherX -= _accelX * 0.7;
    }
    _catcherX = _catcherX.clamp(0.0, _screenWidth - _catcherWidth);

    final screenHeight = MediaQuery.of(context).size.height;
    // Catcher is placed at bottom: 65, so top of catcher is screenHeight - 65 - _catcherHeight
    final catcherY = screenHeight - 65.0 - _catcherHeight;
    final catcherRect = Rect.fromLTWH(
      _catcherX + 8,
      catcherY + 12,
      _catcherWidth - 16,
      _catcherHeight - 20,
    );

    final toRemove = <_FallingObject>[];

    for (final obj in _fallingObjects) {
      obj.y += _fallSpeed;

      final objRect = Rect.fromLTWH(obj.x, obj.y, _objectWidth, _objectHeight);

      // Cek tabrakan objek dengan mulut katak
      if (objRect.overlaps(catcherRect)) {
        toRemove.add(obj);

        if (obj.isTarget) {
          // ✅ Tertangkap target yang benar!
          _combo++;
          if (_combo > _maxCombo) _maxCombo = _combo;
          _score++;
          _caughtWords.add(obj.word);
          _triggerCatchReaction(true);
          AudioService.instance.speak(obj.word.hanzi);
        } else {
          // ❌ Menangkap kata distractor! Kurangi nyawa
          _combo = 0;
          _wrongCaught++;
          _triggerCatchReaction(false);
          if (_wrongCaught >= _wrongCatchLimit) {
            _endGame();
            return;
          }
        }
      } else if (obj.y > screenHeight - 120) {
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
    if (_gameOver) return;
    _tickController.stop();
    _spawnTimer?.cancel();
    _gameTimer?.cancel();

    setState(() {
      _isPlaying = false;
      _gameOver = true;
    });

    _saveGameResult();
  }

  void _exitActiveGame() {
    _tickController.stop();
    _spawnTimer?.cancel();
    _gameTimer?.cancel();
    Navigator.of(context).maybePop();
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

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (!_isPlaying || _gameOver) return;
    setState(() {
      _catcherX = (_catcherX + details.delta.dx).clamp(
        0.0,
        _screenWidth - _catcherWidth,
      );
    });
  }

  void _cycleBackground() {
    setState(() {
      _selectedBgIndex = (_selectedBgIndex + 1) % _gameBackgrounds.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF0FDF4),
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primaryGreen),
        ),
      );
    }

    if (_allWords.length < 3) {
      return Scaffold(
        backgroundColor: const Color(0xFFF0FDF4),
        appBar: AppBar(title: const Text('Mandarin Catcher')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/image/games/Excited Green Frog Mascot.png',
                  width: 110,
                  height: 110,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Kosakata Belum Cukup',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Dibutuhkan minimal 3 kata pada level HSK saat ini untuk memainkan Mandarin Catcher.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_gameOver) {
      return _buildGameOverScreen();
    }

    if (_isPlaying) {
      return _buildActivePlayScreen();
    }

    return _buildWelcomeScreen();
  }

  // 1. Welcome / Intro Screen
  Widget _buildWelcomeScreen() {
    final currentBg = _gameBackgrounds[_selectedBgIndex];

    return Scaffold(
      body: Stack(
        children: [
          // Background Scenery
          Positioned.fill(
            child: Image.asset(
              currentBg['path']!,
              fit: BoxFit.cover,
            ),
          ),
          // Subtle soft white/transparent gradient overlay for readability
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.15),
                    Colors.white.withValues(alpha: 0.70),
                    Colors.white.withValues(alpha: 0.95),
                  ],
                  stops: const [0.0, 0.45, 0.85],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                // Top App Bar row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Material(
                        color: Colors.white.withValues(alpha: 0.9),
                        shape: const CircleBorder(),
                        elevation: 2,
                        child: IconButton(
                          tooltip: 'Kembali',
                          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1E293B)),
                          onPressed: () => Navigator.of(context).maybePop(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Mandarin Catcher',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      // Background switcher button
                      Material(
                        color: Colors.white.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(20),
                        elevation: 2,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: _cycleBackground,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.landscape_rounded, size: 18, color: Color(0xFF2563EB)),
                                const SizedBox(width: 6),
                                Text(
                                  currentBg['title']!,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1E293B),
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

                // Main content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    child: Column(
                      children: [
                        const SizedBox(height: 6),
                        // Mascot Hero Preview
                        Hero(
                          tag: 'catcher_mascot',
                          child: Image.asset(
                            'assets/image/games/Excited Green Frog Mascot.png',
                            width: 120,
                            height: 120,
                            fit: BoxFit.contain,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Ayo Tangkap Kata Mandarin! 🐸',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Bantu katak menangkap kata Mandarin yang cocok ke dalam mulutnya. Jangan sampai menangkap kata yang salah ya!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF475569),
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Target Preview Card
                        if (_targetWord != null)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.06),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF3C7),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text(
                                    '🎯 KOSAKATA TARGET KAMU',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.8,
                                      color: Color(0xFFB45309),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      _targetWord!.hanzi,
                                      style: const TextStyle(
                                        fontSize: 42,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      onPressed: () => AudioService.instance.speak(
                                        _targetWord!.hanzi,
                                      ),
                                      icon: const Icon(
                                        Icons.volume_up_rounded,
                                        color: Color(0xFF2563EB),
                                        size: 28,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  _targetWord!.pinyin,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF2563EB),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Artinya: ${_targetWord!.artiIndonesia}',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF334155),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        const SizedBox(height: 14),

                        // Background theme choices carousel
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Pilih Suasana Latar Belakang:',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 68,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: _gameBackgrounds.length,
                                separatorBuilder: (_, __) => const SizedBox(width: 8),
                                itemBuilder: (context, idx) {
                                  final bg = _gameBackgrounds[idx];
                                  final isSelected = idx == _selectedBgIndex;
                                  return InkWell(
                                    borderRadius: BorderRadius.circular(14),
                                    onTap: () => setState(() => _selectedBgIndex = idx),
                                    child: Container(
                                      width: 90,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: isSelected
                                              ? const Color(0xFF2563EB)
                                              : Colors.white,
                                          width: isSelected ? 2.5 : 1,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.1),
                                            blurRadius: 6,
                                            offset: const Offset(0, 3),
                                          ),
                                        ],
                                      ),
                                      clipBehavior: Clip.antiAlias,
                                      child: Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          Image.asset(
                                            bg['path']!,
                                            fit: BoxFit.cover,
                                          ),
                                          Container(
                                            color: isSelected
                                                ? const Color(0x332563EB)
                                                : Colors.black.withValues(alpha: 0.25),
                                          ),
                                          Center(
                                            child: Text(
                                              bg['title']!,
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 11,
                                                fontWeight: isSelected
                                                    ? FontWeight.w900
                                                    : FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 14),

                        // Sensor Tilt Toggle
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.touch_app_rounded,
                                color: Color(0xFF2563EB),
                                size: 22,
                              ),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Kontrol Sentuh & Geser',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                    Text(
                                      'Geser jari di layar bawah untuk menggerakkan katak',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (_sensorAvailable)
                                Switch(
                                  value: _useSensorTilt,
                                  activeColor: const Color(0xFF2563EB),
                                  onChanged: (val) =>
                                      setState(() => _useSensorTilt = val),
                                ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Play Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _startGame,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              elevation: 5,
                              shadowColor: const Color(0xFF10B981).withValues(alpha: 0.4),
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
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
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

  // 2. Active Game Screen
  Widget _buildActivePlayScreen() {
    final currentBg = _gameBackgrounds[_selectedBgIndex];
    final screenHeight = MediaQuery.of(context).size.height;
    final catcherY = screenHeight - 65.0 - _catcherHeight;

    // Anticipation logic: saat mau ambil kata (falling object mendekat di atas mulut katak)
    final isAnticipating = _fallingObjects.any((obj) {
      final inXRange = (obj.x + _objectWidth / 2 - (_catcherX + _catcherWidth / 2)).abs() < 60;
      final inYRange = obj.y >= catcherY - 110 && obj.y <= catcherY + 30;
      return inXRange && inYRange;
    });

    return Scaffold(
      body: GestureDetector(
        onHorizontalDragUpdate: _onHorizontalDragUpdate,
        child: Stack(
          children: [
            // Background Image from assets/image/games/
            Positioned.fill(
              child: Image.asset(
                currentBg['path']!,
                fit: BoxFit.cover,
              ),
            ),

            // Top HUD Overlay
            SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Top Row: Back Button, Title Bar, and Quick BG Switcher
                      Row(
                        children: [
                          Material(
                            color: Colors.white.withValues(alpha: 0.92),
                            shape: const CircleBorder(),
                            elevation: 3,
                            child: IconButton(
                              tooltip: 'Keluar',
                              onPressed: _exitActiveGame,
                              icon: const Icon(Icons.arrow_back_rounded),
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.92),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white,
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.12),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Text(
                                'TANGKAP KATA YANG BENAR!',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Material(
                            color: Colors.white.withValues(alpha: 0.92),
                            shape: const CircleBorder(),
                            elevation: 3,
                            child: IconButton(
                              tooltip: 'Ganti Suasana Latar',
                              onPressed: _cycleBackground,
                              icon: const Icon(Icons.palette_outlined),
                              color: const Color(0xFF2563EB),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Stats Row: Hearts (Lives), Timer, Score
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Hearts for remaining lives
                          _buildGameBadge(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: List.generate(_wrongCatchLimit, (index) {
                                final isAlive = index < (_wrongCatchLimit - _wrongCaught);
                                return Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 1.5),
                                  child: Icon(
                                    isAlive ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                    size: 18,
                                    color: isAlive ? const Color(0xFFEF4444) : const Color(0xFF94A3B8),
                                  ),
                                );
                              }),
                            ),
                          ),

                          // Time Remaining
                          _buildGameBadge(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.timer_rounded,
                                  size: 16,
                                  color: Color(0xFF2563EB),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '$_timeRemaining dtk',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 13,
                                    color: _timeRemaining <= 5
                                        ? const Color(0xFFDC2626)
                                        : const Color(0xFF1E293B),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Score Badge
                          _buildGameBadge(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.star_rounded,
                                  size: 19,
                                  color: Color(0xFFF59E0B),
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  '$_score',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 14,
                                    color: Color(0xFF92400E),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      // Target Word Banner
                      if (_targetWord != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.94),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: const Color(0xFF93C5FD),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.12),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.radar_rounded,
                                  color: Color(0xFF2563EB),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 10),
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
                                        color: Color(0xFF2563EB),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    Text(
                                      '${_targetWord!.hanzi}  ·  ${_targetWord!.pinyin}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Color(0xFF0F172A),
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                iconSize: 22,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                tooltip: 'Dengarkan',
                                icon: const Icon(
                                  Icons.volume_up_rounded,
                                  color: Color(0xFF2563EB),
                                ),
                                onPressed: () => AudioService.instance.speak(
                                  _targetWord!.hanzi,
                                ),
                              ),
                              if (_combo > 1) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF3C7),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: const Color(0xFFFBBF24),
                                    ),
                                  ),
                                  child: Text(
                                    'x$_combo 🔥',
                                    style: const TextStyle(
                                      color: Color(0xFFB45309),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            // Falling Word Bubbles
            ..._fallingObjects.map(
              (obj) => Positioned(
                left: obj.x,
                top: obj.y,
                child: _buildFallingEgg(obj),
              ),
            ),

            // Dynamic Mascot Catcher at Bottom
            Positioned(
              left: _catcherX,
              bottom: 65,
              child: _buildCatcherMascotWidget(isAnticipating: isAnticipating),
            ),

            // Bottom Guide Hint
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.35),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.swipe_rounded, color: Colors.white, size: 16),
                      SizedBox(width: 6),
                      Text(
                        'Geser katak ke kiri & kanan untuk menangkap kata',
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

  /// Catcher Mascot Widget
  /// - Menangkap kata yang benar: Blushing Green Sprout Mascot.png
  /// - Menangkap kata yang salah: Crying Green Frog Chibi Mascot.png
  /// - Saat diam / bermain: Excited Green Frog Mascot.png
  Widget _buildCatcherMascotWidget({bool isAnticipating = false}) {
    String assetPath;
    if (_catchReaction == true) {
      assetPath = 'assets/image/games/Blushing Green Sprout Mascot.png';
    } else if (_catchReaction == false) {
      assetPath = 'assets/image/games/Crying Green Frog Chibi Mascot.png';
    } else {
      assetPath = 'assets/image/games/Excited Green Frog Mascot.png';
    }

    final hasReaction = _catchReaction != null;

    return SizedBox(
      width: _catcherWidth,
      height: _catcherHeight + 24,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          // Floating eating pop text reaction (+1 Benar! / Salah!)
          if (_reactionText.isNotEmpty)
            Positioned(
              top: -8,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 150),
                opacity: hasReaction ? 1.0 : 0.0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _catchReaction == true
                        ? const Color(0xFF10B981)
                        : const Color(0xFFEF4444),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Text(
                    _reactionText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),

          // Frog Mascot
          AnimatedScale(
            duration: const Duration(milliseconds: 120),
            scale: hasReaction ? 1.10 : (isAnticipating ? 1.05 : 1.0),
            child: Image.asset(
              assetPath,
              width: _catcherWidth,
              height: _catcherHeight,
              fit: BoxFit.contain,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameBadge({required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildFallingEgg(_FallingObject obj) {
    // 4 Distinct palette styles for clear contrast
    const eggColors = [
      (Color(0xFFFFFBEB), Color(0xFFFDE68A), Color(0xFF78350F)), // Warm Amber
      (Color(0xFFEFF6FF), Color(0xFFBFDBFE), Color(0xFF1E3A8A)), // Sky Blue
      (Color(0xFFFDF4FF), Color(0xFFF5D0FE), Color(0xFF701A75)), // Soft Purple
      (Color(0xFFFFF1F2), Color(0xFFFECDD3), Color(0xFF881337)), // Coral Rose
    ];
    final (light, dark, ink) = eggColors[obj.colorIndex];

    return SizedBox(
      width: _objectWidth,
      height: _objectHeight,
      child: Center(
        child: Container(
          width: 60,
          height: 78,
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.all(Radius.elliptical(32, 42)),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [light, dark],
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.95),
              width: 2.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.16),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Gloss highlight
              Positioned(
                top: 10,
                left: 10,
                child: Container(
                  width: 8,
                  height: 14,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        obj.word.hanzi,
                        style: TextStyle(
                          color: ink,
                          fontSize: 23,
                          fontWeight: FontWeight.w900,
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
                          color: ink.withValues(alpha: 0.9),
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
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

  // 3. Game Over Screen
  Widget _buildGameOverScreen() {
    final currentBg = _gameBackgrounds[_selectedBgIndex];
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

    final isVictory = accuracy >= 0.5;

    return Scaffold(
      body: Stack(
        children: [
          // Background Scenery
          Positioned.fill(
            child: Image.asset(
              currentBg['path']!,
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.45),
            ),
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
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Mascot Result Expression
                      Image.asset(
                        isVictory
                            ? 'assets/image/games/Blushing Green Sprout Mascot.png'
                            : 'assets/image/games/Crying Green Frog Chibi Mascot.png',
                        width: 105,
                        height: 105,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        isVictory ? 'Luar Biasa! 🎉' : 'Permainan Selesai!',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isVictory
                            ? 'Kamu berhasil menangkap banyak kata target!'
                            : 'Jangan patah semangat, ayo coba lagi!',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Stars
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(3, (index) {
                          return Icon(
                            index < stars
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                            size: 42,
                            color: index < stars
                                ? const Color(0xFFF59E0B)
                                : const Color(0xFFCBD5E1),
                          );
                        }),
                      ),
                      const SizedBox(height: 16),

                      // Stats Grid
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatTile(
                              'Tertangkap',
                              '${_caughtWords.length}',
                              const Color(0xFF10B981),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildStatTile(
                              'Salah',
                              '$_wrongCaught/$_wrongCatchLimit',
                              const Color(0xFFEF4444),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildStatTile(
                              'Max Combo',
                              'x$_maxCombo',
                              const Color(0xFFF59E0B),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Coins Earned Pill
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFFFBBF24),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.monetization_on_rounded,
                              color: Color(0xFFD97706),
                              size: 22,
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

                      // Review caught words
                      if (_caughtWords.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Kata yang berhasil ditangkap:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF334155),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: _caughtWords.map((w) {
                            return Chip(
                              label: Text('${w.hanzi} (${w.pinyin})'),
                              labelStyle: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E293B),
                              ),
                              backgroundColor: const Color(0xFFF1F5F9),
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                            );
                          }).toList(),
                        ),
                      ],

                      const SizedBox(height: 20),

                      // Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.of(context).maybePop(),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF475569),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                side: const BorderSide(color: Color(0xFFCBD5E1)),
                              ),
                              child: const Text(
                                'Keluar',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _startGame,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF10B981),
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
            style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
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
