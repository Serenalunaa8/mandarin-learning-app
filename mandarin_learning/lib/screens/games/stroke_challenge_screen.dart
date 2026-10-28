import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../models/vocabulary_model.dart';
import '../../providers/vocabulary_provider.dart';
import '../../services/audio_service.dart';
import '../../services/hanzi_stroke_service.dart';
import '../../widgets/mascot_widget.dart';

class HanziRuleInfo {
  final String ruleTitle;
  final String ruleDesc;

  const HanziRuleInfo({required this.ruleTitle, required this.ruleDesc});
}

class StrokeChallengeScreen extends StatefulWidget {
  const StrokeChallengeScreen({super.key});

  @override
  State<StrokeChallengeScreen> createState() => _StrokeChallengeScreenState();
}

class _DrawnStroke {
  final List<Offset> points;
  final Color color;
  final double width;

  const _DrawnStroke({
    required this.points,
    required this.color,
    required this.width,
  });
}

class _StrokeChallengeScreenState extends State<StrokeChallengeScreen>
    with SingleTickerProviderStateMixin {
  List<VocabularyItem> _words = [];
  int _currentIndex = 0;
  final List<_DrawnStroke> _drawnStrokes = [];
  List<Offset> _currentPoints = [];
  bool _isLoading = true;
  bool _isLoadingStrokeData = false;
  HanziStrokeData? _strokeData;
  int _characterIndex = 0;

  // Evaluasi bentuk
  HanziEvaluationResult? _evalResult;
  bool _showFeedback = false;

  // Super Chinese Animation Controller & State
  late AnimationController _animController;
  int _animStrokeIndex = 0;
  bool _isPlayingAnimation = true;
  double _animSpeed = 1.0;
  bool _isAnimationComplete = false;

  // Alat Pena
  Color _selectedColor = const Color(0xFF0F172A);
  int _activeTab = 0;
  double _strokeWidth = 7.0;
  bool _isEraser = false;

  // Pilihan warna pena kaligrafi yang selaras
  final List<Color> _colorPalette = const [
    Color(0xFF0F172A), // Hitam Tinta Kaligrafi
    Color(0xFF059669), // Hijau Zamrud
    Color(0xFFDC2626), // Merah Tiongkok
    Color(0xFFD97706), // Warm Amber
    Color(0xFF0284C7), // Azure Blue
  ];

  // Pagination langkah stroke
  int _activeStrokeStep = 0;
  bool _showActiveStepGuide = true;

  final GlobalKey _canvasKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );
    _animController.addListener(() {
      setState(() {});
    });
    _animController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _onStrokeAnimationCompleted();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadWords());
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _loadWords() {
    final vocab = context.read<VocabularyProvider>();
    final words = vocab.currentLevelVocabulary;
    setState(() {
      _words = words;
      _isLoading = false;
    });
    _loadStrokeData();
  }

  void _onStrokeAnimationCompleted() {
    final strokes = _strokeData?.strokes ?? [];
    if (strokes.isEmpty) return;

    if (_isPlayingAnimation) {
      if (_animStrokeIndex < strokes.length - 1) {
        setState(() {
          _animStrokeIndex++;
          _activeStrokeStep = _animStrokeIndex;
        });
        _animController.duration = Duration(
          milliseconds: (750 / _animSpeed).round(),
        );
        _animController.forward(from: 0.0);
      } else {
        setState(() {
          _isAnimationComplete = true;
          _isPlayingAnimation = false;
          _showActiveStepGuide = false;
        });
      }
    }
  }

  void _playAnimation() {
    final strokes = _strokeData?.strokes ?? [];
    if (strokes.isEmpty) return;
    setState(() {
      _isPlayingAnimation = true;
      _isAnimationComplete = false;
    });
    if (_animStrokeIndex >= strokes.length - 1 &&
        _animController.value >= 1.0) {
      setState(() {
        _animStrokeIndex = 0;
      });
    }
    _animController.duration = Duration(
      milliseconds: (750 / _animSpeed).round(),
    );
    _animController.forward(
      from: _animController.value >= 1.0 ? 0.0 : _animController.value,
    );
  }

  void _pauseAnimation() {
    setState(() {
      _isPlayingAnimation = false;
    });
    _animController.stop();
  }

  void _replayAnimation() {
    final strokes = _strokeData?.strokes ?? [];
    if (strokes.isEmpty) return;
    setState(() {
      _isPlayingAnimation = true;
      _isAnimationComplete = false;
      _animStrokeIndex = 0;
    });
    _animController.duration = Duration(
      milliseconds: (750 / _animSpeed).round(),
    );
    _animController.forward(from: 0.0);
  }

  void _nextStrokeStep() {
    final strokes = _strokeData?.strokes ?? [];
    if (strokes.isEmpty) return;
    setState(() {
      _isPlayingAnimation = false;
      _isAnimationComplete = false;
      _animStrokeIndex = (_animStrokeIndex + 1).clamp(0, strokes.length - 1);
      _activeStrokeStep = _animStrokeIndex;
    });
    _animController.duration = Duration(
      milliseconds: (750 / _animSpeed).round(),
    );
    _animController.forward(from: 0.0);
  }

  void _prevStrokeStep() {
    final strokes = _strokeData?.strokes ?? [];
    if (strokes.isEmpty) return;
    setState(() {
      _isPlayingAnimation = false;
      _isAnimationComplete = false;
      _animStrokeIndex = (_animStrokeIndex - 1).clamp(0, strokes.length - 1);
      _activeStrokeStep = _animStrokeIndex;
    });
    _animController.duration = Duration(
      milliseconds: (750 / _animSpeed).round(),
    );
    _animController.forward(from: 0.0);
  }

  void _selectStrokeStep(int index) {
    final strokes = _strokeData?.strokes ?? [];
    if (strokes.isEmpty || index >= strokes.length) return;
    setState(() {
      _isPlayingAnimation = false;
      _isAnimationComplete = false;
      _animStrokeIndex = index;
      _activeStrokeStep = index;
    });
    _animController.duration = Duration(
      milliseconds: (750 / _animSpeed).round(),
    );
    _animController.forward(from: 0.0);
  }

  void _toggleSpeed() {
    setState(() {
      if (_animSpeed == 1.0) {
        _animSpeed = 1.5;
      } else if (_animSpeed == 1.5) {
        _animSpeed = 0.75;
      } else {
        _animSpeed = 1.0;
      }
      _animController.duration = Duration(
        milliseconds: (750 / _animSpeed).round(),
      );
    });
  }

  VocabularyItem? get _current =>
      _words.isNotEmpty && _currentIndex < _words.length
      ? _words[_currentIndex]
      : null;

  String get _currentCharacter {
    final runes = (_current?.hanzi ?? '').runes.toList();
    if (runes.isEmpty) return '';
    return String.fromCharCode(
      runes[_characterIndex.clamp(0, runes.length - 1)],
    );
  }

  int get _guideStrokeCount => _strokeData?.strokes.length ?? 0;

  Future<void> _loadStrokeData() async {
    final character = _currentCharacter;
    if (character.isEmpty) return;
    setState(() {
      _isLoadingStrokeData = true;
      _strokeData = null;
      _evalResult = null;
      _showFeedback = false;
      _activeStrokeStep = 0;
      _animStrokeIndex = 0;
      _isAnimationComplete = false;
      _isPlayingAnimation = true;
    });
    _animController.stop();
    try {
      final data = await HanziStrokeService.instance.load(character);
      if (!mounted || character != _currentCharacter) return;
      setState(() {
        _strokeData = data;
        _isLoadingStrokeData = false;
        _animStrokeIndex = 0;
        _activeStrokeStep = 0;
        _isAnimationComplete = false;
        _isPlayingAnimation = true;
      });
      _animController.duration = Duration(
        milliseconds: (750 / _animSpeed).round(),
      );
      _animController.forward(from: 0.0);
    } catch (_) {
      if (!mounted || character != _currentCharacter) return;
      setState(() {
        _isLoadingStrokeData = false;
      });
    }
  }

  void _onPanStart(DragStartDetails d) {
    if (_isEraser) {
      _eraseAt(d.localPosition);
      return;
    }
    setState(() {
      _currentPoints = [d.localPosition];
    });
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (_isEraser) {
      _eraseAt(d.localPosition);
      return;
    }
    setState(() {
      _currentPoints.add(d.localPosition);
    });
  }

  void _onPanEnd(DragEndDetails d) {
    if (_isEraser) return;
    if (_currentPoints.length > 1) {
      setState(() {
        _drawnStrokes.add(
          _DrawnStroke(
            points: List.from(_currentPoints),
            color: _selectedColor,
            width: _strokeWidth,
          ),
        );
        _currentPoints = [];
      });
    }
  }

  void _eraseAt(Offset pos) {
    const eraseRadius = 25.0;
    setState(() {
      _drawnStrokes.removeWhere((stroke) {
        return stroke.points.any((p) => (p - pos).distance <= eraseRadius);
      });
    });
  }

  void _clearCanvas() {
    setState(() {
      _drawnStrokes.clear();
      _currentPoints = [];
      _showFeedback = false;
      _evalResult = null;
    });
  }

  void _checkWriting() {
    final canvasSize =
        (_canvasKey.currentContext?.findRenderObject() as RenderBox?)?.size;
    final strokeData = _strokeData;
    if (canvasSize == null || strokeData == null) return;

    final strokesPoints = _drawnStrokes.map((s) => s.points).toList();
    final result = evaluateHanziWriting(
      drawnStrokes: strokesPoints,
      reference: strokeData,
      canvasSize: canvasSize,
    );

    setState(() {
      _evalResult = result;
      _showFeedback = true;
    });

    _showResultDialog(result);
  }

  void _showResultDialog(HanziEvaluationResult res) {
    showDialog(
      context: context,
      builder: (ctx) {
        final isPassed = res.isPassed;
        final mascotAsset = isPassed
            ? 'assets/image/games/Blushing Green Sprout Mascot.png'
            : 'assets/image/games/Crying Green Frog Chibi Mascot.png';

        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                mascotAsset,
                width: 72,
                height: 72,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => MascotWidget(
                  pose: isPassed ? MascotPose.celebrating : MascotPose.studying,
                  size: 64,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                res.feedbackTitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isPassed
                      ? const Color(0xFFDCFCE7)
                      : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isPassed
                        ? const Color(0xFF86EFAC)
                        : const Color(0xFFFDE68A),
                  ),
                ),
                child: Text(
                  'Skor Ketepatan: ${res.totalScore}%',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: isPassed
                        ? const Color(0xFF15803D)
                        : const Color(0xFFB45309),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                res.feedbackMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12.5,
                  height: 1.4,
                  color: Color(0xFF475569),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _clearCanvas();
                      },
                      child: const Text(
                        'Coba Lagi',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ),
                  ),
                  if (isPassed) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF059669),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 2,
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _nextWord();
                        },
                        child: const Text(
                          'Lanjut →',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _nextWord() {
    final runeCount = _current?.hanzi.runes.length ?? 0;
    if (_characterIndex + 1 < runeCount) {
      setState(() {
        _characterIndex++;
        _drawnStrokes.clear();
        _currentPoints = [];
        _showFeedback = false;
        _evalResult = null;
        _activeStrokeStep = 0;
      });
      _loadStrokeData();
      return;
    }
    setState(() {
      _currentIndex = (_currentIndex + 1) % _words.length;
      _characterIndex = 0;
      _drawnStrokes.clear();
      _currentPoints = [];
      _showFeedback = false;
      _evalResult = null;
      _activeStrokeStep = 0;
    });
    _loadStrokeData();
  }

  HanziRuleInfo _getStrokeRule(
    int index,
    List<Offset> points,
    int totalStrokes,
  ) {
    if (points.isEmpty) {
      return const HanziRuleInfo(
        ruleTitle: 'Dari Atas ke Bawah',
        ruleDesc: 'Tulis bagian atas terlebih dahulu, kemudian bagian bawah',
      );
    }

    final char = _currentCharacter;

    if (char == '十') {
      if (index == 0) {
        return const HanziRuleInfo(
          ruleTitle: 'Horizontal Sebelum Vertikal',
          ruleDesc: 'Tulis garis mendatar (heng) lebih dulu sebelum garis tegak (shu)',
        );
      } else {
        return const HanziRuleInfo(
          ruleTitle: 'Goresan Vertikal Menembus',
          ruleDesc: 'Tulis garis tegak menembus garis mendatar',
        );
      }
    }

    if (char == '三' || char == '二' || char == '一') {
      return const HanziRuleInfo(
        ruleTitle: 'Dari Atas ke Bawah',
        ruleDesc: 'Tulis bagian atas terlebih dahulu, kemudian bagian bawah',
      );
    }

    if (char == '川') {
      return const HanziRuleInfo(
        ruleTitle: 'Dari Kiri ke Kanan',
        ruleDesc: 'Tulis bagian kiri terlebih dahulu, kemudian bagian kanan',
      );
    }

    if (char == '八' || char == '人') {
      if (index == 0) {
        return const HanziRuleInfo(
          ruleTitle: 'Dari Kiri ke Kanan',
          ruleDesc: 'Tulis garis miring kiri (pie) terlebih dahulu',
        );
      } else {
        return const HanziRuleInfo(
          ruleTitle: 'Goresan Kanan Berikutnya',
          ruleDesc: 'Tulis garis miring kanan (na) menyempurnakan karakter',
        );
      }
    }

    if (char == '小' || char == '水') {
      if (index == 0) {
        return const HanziRuleInfo(
          ruleTitle: 'Tengah Sebelum Samping',
          ruleDesc: 'Tulis bagian tengahnya dulu sebelum sisi kiri dan kanan',
        );
      } else {
        return const HanziRuleInfo(
          ruleTitle: 'Dari Kiri ke Kanan',
          ruleDesc: 'Tulis bagian kiri terlebih dahulu, kemudian bagian kanan',
        );
      }
    }

    if (char == '口' || char == '日' || char == '回' || char == '国') {
      if (index == 0) {
        return const HanziRuleInfo(
          ruleTitle: 'Luar Sebelum Dalam',
          ruleDesc:
              'Buat bingkai luar terlebih dahulu sebelum mengisi dalamnya',
        );
      } else if (index == totalStrokes - 1) {
        return const HanziRuleInfo(
          ruleTitle: 'Tutup Bagian Bawah di Akhir',
          ruleDesc: 'Tulis isi bagian dalam dulu, lalu tutup di bagian bawah',
        );
      } else {
        return const HanziRuleInfo(
          ruleTitle: 'Luar Sebelum Dalam',
          ruleDesc: 'Lengkapi bingkai luar lalu isi bagian dalam',
        );
      }
    }

    final start = points.first;
    final end = points.last;
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;

    if (index == totalStrokes - 1 &&
        (points.length < 3 || (end - start).distance < 240)) {
      return const HanziRuleInfo(
        ruleTitle: 'Titik Tambahan Terakhir',
        ruleDesc:
            'Goresan berupa titik kecil atau tambahan ditulis paling akhir',
      );
    }

    if (dx.abs() > dy.abs() * 2 && dy.abs() < 70) {
      if (index == 0) {
        return const HanziRuleInfo(
          ruleTitle: 'Horizontal Sebelum Vertikal',
          ruleDesc: 'Tulis garis mendatar (heng) lebih dulu sebelum garis tegak (shu)',
        );
      }
      return const HanziRuleInfo(
        ruleTitle: 'Dari Kiri ke Kanan',
        ruleDesc: 'Tarik garis mendatar dari kiri ke kanan dengan stabil',
      );
    }

    if (start.dy < 400 && index < 2) {
      return const HanziRuleInfo(
        ruleTitle: 'Dari Atas ke Bawah',
        ruleDesc: 'Tulis bagian atas terlebih dahulu, kemudian bagian bawah',
      );
    }

    if (start.dx < 420 && index <= totalStrokes ~/ 2) {
      return const HanziRuleInfo(
        ruleTitle: 'Dari Kiri ke Kanan',
        ruleDesc: 'Tulis bagian kiri terlebih dahulu, kemudian bagian kanan',
      );
    }

    if (index == totalStrokes - 1) {
      if (start.dy > 600) {
        return const HanziRuleInfo(
          ruleTitle: 'Tutup Bagian Bawah di Akhir',
          ruleDesc: 'Tulis isi bagian dalam dulu, lalu tutup bagian bawahnya di akhir',
        );
      }
      return const HanziRuleInfo(
        ruleTitle: 'Titik / Goresan Penutup',
        ruleDesc: 'Goresan penutup atau pelengkap ditulis paling akhir',
      );
    }

    if (index < totalStrokes ~/ 2) {
      return const HanziRuleInfo(
        ruleTitle: 'Dari Atas ke Bawah',
        ruleDesc: 'Tulis bagian atas terlebih dahulu, kemudian bagian bawah',
      );
    }

    return const HanziRuleInfo(
      ruleTitle: 'Dari Kiri ke Kanan',
      ruleDesc: 'Tulis bagian kiri terlebih dahulu, kemudian bagian kanan',
    );
  }

  MandarinStrokeInfo _getStrokeInfo(int index, List<Offset> points) {
    return HanziStrokeService.instance.getMandarinStrokeInfo(
      character: _currentCharacter,
      strokeIndex: index,
      points: points,
      totalStrokes: _guideStrokeCount,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_words.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Stroke Challenge')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const MascotWidget(pose: MascotPose.holdingSign, size: 100),
              const SizedBox(height: 16),
              const Text(
                'Belum ada kosakata untuk level ini.',
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

    final word = _current!;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          // Aksen halus awan di pojok kanan atas
          Positioned(
            top: -15,
            right: -25,
            child: Opacity(
              opacity: 0.16,
              child: Image.asset(
                'assets/image/beranda/awan_kecil.png',
                width: 140,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                _buildTopBar(word),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildWordCard(word),
                        const SizedBox(height: 14),

                        // Mode Switcher (Kanvas Menulis vs Animasi Urutan)
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final isWide = constraints.maxWidth >= 640;
                            if (isWide) {
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 5,
                                    child: _buildCanvasSection(),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    flex: 4,
                                    child: _buildAnimatedStrokeGuideSection(),
                                  ),
                                ],
                              );
                            }

                            // Mobile Layout: Segmented Tab
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildModeSwitcher(),
                                const SizedBox(height: 14),
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 250),
                                  child: _activeTab == 0
                                      ? _buildCanvasSection()
                                      : _buildAnimatedStrokeGuideSection(),
                                ),
                              ],
                            );
                          },
                        ),
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

  Widget _buildTopBar(VocabularyItem word) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.arrow_back_rounded,
                color: Color(0xFF334155),
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Image.asset(
            'assets/image/icon_beranda/stroke_challange.png',
            width: 32,
            height: 32,
            errorBuilder: (_, __, ___) => const Icon(
              Icons.draw_rounded,
              color: Color(0xFF059669),
              size: 28,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Stroke Challenge',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.3,
                  ),
                ),
                Text(
                  'Kata ${_currentIndex + 1} dari ${_words.length}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _nextWord,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFCBD5E1)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Lewati',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF475569),
                    ),
                  ),
                  SizedBox(width: 2),
                  Icon(
                    Icons.skip_next_rounded,
                    size: 16,
                    color: Color(0xFF475569),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWordCard(VocabularyItem word) {
    final vocab = context.watch<VocabularyProvider>();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Kotak Karakter Hanzi Aktif
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF0FDF4), Color(0xFFDCFCE7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: const Color(0xFF86EFAC),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _currentCharacter,
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF14532D),
                        height: 1.1,
                      ),
                    ),
                    Text(
                      word.pinyin,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF15803D),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),

              // Detail Kata
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  word.hanzi,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF0F172A),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () =>
                                    AudioService.instance.speak(word.hanzi),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFF1F5F9),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.volume_up_rounded,
                                    size: 18,
                                    color: Color(0xFF059669),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // HSK Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFBFDBFE)),
                          ),
                          child: Text(
                            'HSK ${vocab.selectedLevel}',
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1D4ED8),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      word.artiIndonesia,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF475569),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.gesture_rounded,
                                size: 13,
                                color: Color(0xFF059669),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$_guideStrokeCount Goresan Standar',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF334155),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Multi-character selector if word has 2+ characters
          _buildCharacterTabs(word),
        ],
      ),
    );
  }

  Widget _buildCharacterTabs(VocabularyItem word) {
    final runes = word.hanzi.runes.toList();
    if (runes.length <= 1) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: List.generate(runes.length, (idx) {
          final char = String.fromCharCode(runes[idx]);
          final isSelected = idx == _characterIndex;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                if (idx != _characterIndex) {
                  setState(() {
                    _characterIndex = idx;
                    _drawnStrokes.clear();
                    _currentPoints = [];
                    _showFeedback = false;
                    _evalResult = null;
                    _activeStrokeStep = 0;
                  });
                  _loadStrokeData();
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF059669)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF059669)
                        : const Color(0xFFE2E8F0),
                    width: isSelected ? 1.5 : 1.0,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      char,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: isSelected
                            ? Colors.white
                            : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '(${idx + 1}/${runes.length})',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: isSelected
                            ? const Color(0xFFD1FAE5)
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildModeSwitcher() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _activeTab = 0),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: _activeTab == 0 ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: _activeTab == 0
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.edit_rounded,
                      size: 16,
                      color: _activeTab == 0
                          ? const Color(0xFF059669)
                          : const Color(0xFF64748B),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Kanvas Menulis',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: _activeTab == 0
                            ? FontWeight.w900
                            : FontWeight.w600,
                        color: _activeTab == 0
                            ? const Color(0xFF0F172A)
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _activeTab = 1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: _activeTab == 1 ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: _activeTab == 1
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.play_circle_fill_rounded,
                      size: 16,
                      color: _activeTab == 1
                          ? const Color(0xFF0284C7)
                          : const Color(0xFF64748B),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Animasi Urutan (笔顺)',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: _activeTab == 1
                            ? FontWeight.w900
                            : FontWeight.w600,
                        color: _activeTab == 1
                            ? const Color(0xFF0F172A)
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCanvasSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Tulis Hanzi
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Color(0xFFDCFCE7),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.edit_rounded,
                      color: Color(0xFF15803D),
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Kanvas Menulis Hanzi',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        'Tulis goresan mengikuti pola karakter di kanvas',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (_strokeData != null && _strokeData!.strokes.isNotEmpty)
                GestureDetector(
                  onTap: () => setState(
                    () => _showActiveStepGuide = !_showActiveStepGuide,
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _showActiveStepGuide
                          ? const Color(0xFFF0FDF4)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _showActiveStepGuide
                            ? const Color(0xFF86EFAC)
                            : const Color(0xFFCBD5E1),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _showActiveStepGuide
                              ? Icons.visibility_rounded
                              : Icons.visibility_off_rounded,
                          size: 13,
                          color: _showActiveStepGuide
                              ? const Color(0xFF15803D)
                              : const Color(0xFF64748B),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _showActiveStepGuide
                              ? 'Panduan Nyala'
                              : 'Panduan Mati',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: _showActiveStepGuide
                                ? const Color(0xFF15803D)
                                : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Tianzige Canvas Box
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320, maxHeight: 320),
              child: AspectRatio(
                aspectRatio: 1.0,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAFAFA),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: const Color(0xFFCBD5E1),
                      width: 1.5,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(17),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Garis Tianzige (田字格)
                        CustomPaint(
                          painter: _TianzigeGridPainter(),
                          size: Size.infinite,
                        ),
                        // Karakter Asli Watermark
                        if (_strokeData != null)
                          CustomPaint(
                            painter: _AuthenticHanziWatermarkPainter(
                              strokeOutlines: _strokeData!.strokeOutlines,
                              fallbackStrokes: _strokeData!.strokes,
                              activeStrokeIndex: _showActiveStepGuide
                                  ? _activeStrokeStep
                                  : -1,
                            ),
                            size: Size.infinite,
                          ),
                        // Panduan Langkah Aktif (Bishun Guide Overlay)
                        if (_showActiveStepGuide &&
                            _strokeData != null &&
                            _activeStrokeStep >= 0 &&
                            _activeStrokeStep < _strokeData!.strokes.length)
                          CustomPaint(
                            painter: _ActiveStepGuidelinePainter(
                              stroke: _strokeData!.strokes[_activeStrokeStep],
                            ),
                            size: Size.infinite,
                          ),
                        // Lapisan Goresan Kuas Pengguna
                        GestureDetector(
                          key: _canvasKey,
                          onPanStart: _onPanStart,
                          onPanUpdate: _onPanUpdate,
                          onPanEnd: _onPanEnd,
                          child: CustomPaint(
                            painter: _CanvasBrushPainter(
                              drawnStrokes: _drawnStrokes,
                              currentPoints: _currentPoints,
                              currentColor: _selectedColor,
                              currentWidth: _strokeWidth,
                            ),
                            size: Size.infinite,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Alat Gambar Terpadu (Palette, Tool, Reset)
          _buildCompactToolsRow(),
          const SizedBox(height: 14),

          // Tombol Periksa Hanzi
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 2,
            ),
            onPressed: _drawnStrokes.isNotEmpty && !_isLoadingStrokeData
                ? _checkWriting
                : null,
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_rounded, size: 20),
                SizedBox(width: 8),
                Text(
                  'Periksa Ketepatan Hanzi  →',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),

          if (_showFeedback && _evalResult != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: _evalResult!.isPassed
                    ? const Color(0xFFDCFCE7)
                    : const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _evalResult!.isPassed
                      ? const Color(0xFF86EFAC)
                      : const Color(0xFFFDE68A),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _evalResult!.isPassed
                        ? Icons.check_circle_rounded
                        : Icons.info_outline_rounded,
                    color: _evalResult!.isPassed
                        ? const Color(0xFF16A34A)
                        : const Color(0xFFD97706),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${_evalResult!.feedbackTitle} (${_evalResult!.totalScore}%)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: _evalResult!.isPassed
                            ? const Color(0xFF14532D)
                            : const Color(0xFF92400E),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCompactToolsRow() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Pena Mode
              GestureDetector(
                onTap: () => setState(() => _isEraser = false),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: !_isEraser ? const Color(0xFF0F172A) : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.edit_rounded,
                        size: 14,
                        color: !_isEraser
                            ? Colors.white
                            : const Color(0xFF475569),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Pena',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: !_isEraser
                              ? Colors.white
                              : const Color(0xFF475569),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // Hapus Mode
              GestureDetector(
                onTap: () => setState(() => _isEraser = true),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: _isEraser ? const Color(0xFFDC2626) : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.auto_fix_high_rounded,
                        size: 14,
                        color: _isEraser
                            ? Colors.white
                            : const Color(0xFF475569),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Hapus',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: _isEraser
                              ? Colors.white
                              : const Color(0xFF475569),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              // Reset Button
              GestureDetector(
                onTap: _clearCanvas,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.refresh_rounded,
                        size: 14,
                        color: Color(0xFF64748B),
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Bersihkan',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Palette warna
              Row(
                children: _colorPalette.map((col) {
                  final isSel = _selectedColor == col && !_isEraser;
                  return GestureDetector(
                    onTap: () => setState(() {
                      _selectedColor = col;
                      _isEraser = false;
                    }),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: col,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSel ? const Color(0xFF38BDF8) : Colors.white,
                          width: isSel ? 2.5 : 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 3,
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),

              // Pilihan Ketebalan Kuas
              Row(
                children: [
                  _buildWidthChip('Tipis', 4.0),
                  const SizedBox(width: 4),
                  _buildWidthChip('Sedang', 7.0),
                  const SizedBox(width: 4),
                  _buildWidthChip('Tebal', 11.0),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWidthChip(String label, double width) {
    final isSelected = (_strokeWidth - width).abs() < 1.0;
    return GestureDetector(
      onTap: () => setState(() => _strokeWidth = width),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF0F172A)
                : const Color(0xFFCBD5E1),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedStrokeGuideSection() {
    final strokes = _strokeData?.strokes ?? [];
    if (strokes.isEmpty) {
      return _buildLoadingOrEmptyGuideCard();
    }

    final totalStrokes = strokes.length;
    final activeInfo = _animStrokeIndex < totalStrokes
        ? _getStrokeInfo(_animStrokeIndex, strokes[_animStrokeIndex])
        : null;
    final ruleInfo = _animStrokeIndex < totalStrokes
        ? _getStrokeRule(
            _animStrokeIndex,
            strokes[_animStrokeIndex],
            totalStrokes,
          )
        : null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Bar Animasi
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2FE),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.play_circle_fill_rounded,
                  color: Color(0xFF0284C7),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Urutan Goresan Resmi (笔顺)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      'Amati arah dan urutan penulisan yang baku',
                      style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              // Kecepatan putar
              GestureDetector(
                onTap: _toggleSpeed,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.speed_rounded,
                        size: 14,
                        color: Color(0xFF334155),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${_animSpeed}x',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF334155),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Display Tianzige Animasi
          Center(
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                color: const Color(0xFFFAFAFA),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(17),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Grid Tianzige
                    CustomPaint(
                      painter: _TianzigeGridPainter(),
                      size: Size.infinite,
                    ),
                    // Pelukis Animasi Goresan
                    CustomPaint(
                      painter: _SuperChineseStrokeAnimatorPainter(
                        allStrokes: strokes,
                        strokeOutlines: _strokeData?.strokeOutlines ?? [],
                        currentStrokeIndex: _animStrokeIndex,
                        strokeProgress: _animController.value,
                        isCompleted: _isAnimationComplete,
                      ),
                      size: Size.infinite,
                    ),
                    // Badge Indikator Goresan
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: _isAnimationComplete
                              ? const Color(0xFF059669)
                              : Colors.white.withValues(alpha: 0.94),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _isAnimationComplete
                                ? const Color(0xFF059669)
                                : const Color(0xFFCBD5E1),
                          ),
                        ),
                        child: Text(
                          _isAnimationComplete
                              ? 'Selesai ✓'
                              : 'Goresan ${_animStrokeIndex + 1} / $totalStrokes',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: _isAnimationComplete
                                ? Colors.white
                                : const Color(0xFF0F172A),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Interactive Step Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(totalStrokes, (idx) {
                final isCurrent =
                    idx == _animStrokeIndex && !_isAnimationComplete;
                final isDone = idx < _animStrokeIndex || _isAnimationComplete;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: GestureDetector(
                    onTap: () => _selectStrokeStep(idx),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: isCurrent
                            ? const Color(0xFF0284C7)
                            : isDone
                            ? const Color(0xFFDCFCE7)
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isCurrent
                              ? const Color(0xFF0284C7)
                              : isDone
                              ? const Color(0xFF86EFAC)
                              : const Color(0xFFCBD5E1),
                          width: isCurrent ? 1.5 : 1.0,
                        ),
                      ),
                      child: Text(
                        '${idx + 1}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isCurrent
                              ? FontWeight.w900
                              : FontWeight.w700,
                          color: isCurrent
                              ? Colors.white
                              : isDone
                              ? const Color(0xFF14532D)
                              : const Color(0xFF334155),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 12),

          // Kontrol Pemutar Animasi
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: _animStrokeIndex > 0 ? _prevStrokeStep : null,
                icon: const Icon(Icons.skip_previous_rounded),
                color: const Color(0xFF0284C7),
                disabledColor: const Color(0xFFCBD5E1),
                tooltip: 'Goresan Sebelumnya',
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  elevation: 2,
                ),
                onPressed: () {
                  if (_isAnimationComplete) {
                    _replayAnimation();
                  } else if (_isPlayingAnimation) {
                    _pauseAnimation();
                  } else {
                    _playAnimation();
                  }
                },
                icon: Icon(
                  _isAnimationComplete
                      ? Icons.replay_rounded
                      : _isPlayingAnimation
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  size: 20,
                ),
                label: Text(
                  _isAnimationComplete
                      ? 'Ulangi'
                      : _isPlayingAnimation
                      ? 'Jeda'
                      : 'Putar',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _animStrokeIndex < totalStrokes - 1
                    ? _nextStrokeStep
                    : null,
                icon: const Icon(Icons.skip_next_rounded),
                color: const Color(0xFF0284C7),
                disabledColor: const Color(0xFFCBD5E1),
                tooltip: 'Goresan Berikutnya',
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Detail Kartu Info Goresan Aktif
          if (activeInfo != null && ruleInfo != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F2FE),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFBAE6FD)),
                    ),
                    child: Center(
                      child: Text(
                        activeInfo.symbol.isNotEmpty ? activeInfo.symbol : '一',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0284C7),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              activeInfo.displayName,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE0E7FF),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                ruleInfo.ruleTitle,
                                style: const TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF3730A3),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          ruleInfo.ruleDesc,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),

          // Tombol aksi cepat ke kanvas
          ElevatedButton.icon(
            onPressed: () => setState(() => _activeTab = 0),
            icon: const Icon(Icons.edit_rounded, size: 18),
            label: const Text(
              'Praktikkan Menulis di Kanvas →',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingOrEmptyGuideCard() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: Color(0xFF059669),
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Memuat animasi urutan goresan...',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Custom Painters
// ─────────────────────────────────────────────────────────────

class _TianzigeGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final borderPaint = Paint()
      ..color = const Color(0xFFCBD5E1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final dashPaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Outer border
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), borderPaint);

    // Cross lines
    _drawDashedLine(
      canvas,
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      dashPaint,
    );
    _drawDashedLine(
      canvas,
      Offset(size.width / 2, 0),
      Offset(size.width / 2, size.height),
      dashPaint,
    );

    // Diagonal lines
    _drawDashedLine(
      canvas,
      Offset.zero,
      Offset(size.width, size.height),
      dashPaint,
    );
    _drawDashedLine(
      canvas,
      Offset(size.width, 0),
      Offset(0, size.height),
      dashPaint,
    );
  }

  void _drawDashedLine(Canvas canvas, Offset p1, Offset p2, Paint paint) {
    const dashWidth = 5.0;
    const dashSpace = 4.0;
    final totalDist = (p2 - p1).distance;
    final dx = (p2.dx - p1.dx) / totalDist;
    final dy = (p2.dy - p1.dy) / totalDist;

    var currentDist = 0.0;
    while (currentDist < totalDist) {
      final start = Offset(p1.dx + dx * currentDist, p1.dy + dy * currentDist);
      final nextDist = math.min(currentDist + dashWidth, totalDist);
      final end = Offset(p1.dx + dx * nextDist, p1.dy + dy * nextDist);
      canvas.drawLine(start, end, paint);
      currentDist += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CanvasBrushPainter extends CustomPainter {
  final List<_DrawnStroke> drawnStrokes;
  final List<Offset> currentPoints;
  final Color currentColor;
  final double currentWidth;

  const _CanvasBrushPainter({
    required this.drawnStrokes,
    required this.currentPoints,
    required this.currentColor,
    required this.currentWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in drawnStrokes) {
      final paint = Paint()
        ..color = s.color
        ..strokeWidth = s.width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      _drawSmoothPath(canvas, s.points, paint);
    }

    if (currentPoints.length > 1) {
      final curPaint = Paint()
        ..color = currentColor
        ..strokeWidth = currentWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      _drawSmoothPath(canvas, currentPoints, curPaint);
    }
  }

  void _drawSmoothPath(Canvas canvas, List<Offset> points, Paint paint) {
    if (points.isEmpty) return;
    if (points.length == 1) {
      canvas.drawCircle(points.first, paint.strokeWidth / 2, paint);
      return;
    }
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CanvasBrushPainter oldDelegate) => true;
}

class _AuthenticHanziWatermarkPainter extends CustomPainter {
  final List<Path> strokeOutlines;
  final List<List<Offset>> fallbackStrokes;
  final int activeStrokeIndex;

  const _AuthenticHanziWatermarkPainter({
    required this.strokeOutlines,
    required this.fallbackStrokes,
    required this.activeStrokeIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final scale = size.width / 1024.0;
    canvas.save();
    canvas.scale(scale, scale);

    if (strokeOutlines.isNotEmpty) {
      // 1. Gambar seluruh karakter dasar dengan bentuk outline kaligrafi autentik
      final basePaint = Paint()
        ..color = const Color(0xFF64748B).withValues(alpha: 0.22)
        ..style = PaintingStyle.fill;

      for (var i = 0; i < strokeOutlines.length; i++) {
        if (i != activeStrokeIndex) {
          canvas.drawPath(strokeOutlines[i], basePaint);
        }
      }

      // 2. Goresan aktif tahap ini diberi sorotan hijau lembut persis sesuai bentuk goresannya
      if (activeStrokeIndex >= 0 && activeStrokeIndex < strokeOutlines.length) {
        final activeFill = Paint()
          ..color = const Color(0xFF22C55E).withValues(alpha: 0.35)
          ..style = PaintingStyle.fill;
        canvas.drawPath(strokeOutlines[activeStrokeIndex], activeFill);

        final activeBorder = Paint()
          ..color = const Color(0xFF16A34A).withValues(alpha: 0.6)
          ..strokeWidth = 3.5
          ..style = PaintingStyle.stroke;
        canvas.drawPath(strokeOutlines[activeStrokeIndex], activeBorder);
      }
    } else if (fallbackStrokes.isNotEmpty) {
      final fallbackPaint = Paint()
        ..color = const Color(0xFF64748B).withValues(alpha: 0.25)
        ..strokeWidth = 60
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      for (var i = 0; i < fallbackStrokes.length; i++) {
        _drawSmoothPath(canvas, fallbackStrokes[i], fallbackPaint);
      }
    }

    canvas.restore();
  }

  void _drawSmoothPath(Canvas canvas, List<Offset> points, Paint paint) {
    if (points.isEmpty) return;
    if (points.length == 1) {
      canvas.drawCircle(points.first, paint.strokeWidth / 2, paint);
      return;
    }
    if (points.length == 2) {
      canvas.drawLine(points[0], points[1], paint);
      return;
    }
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final mid = Offset((p0.dx + p1.dx) / 2, (p0.dy + p1.dy) / 2);
      path.quadraticBezierTo(p0.dx, p0.dy, mid.dx, mid.dy);
    }
    path.lineTo(points.last.dx, points.last.dy);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _AuthenticHanziWatermarkPainter oldDelegate) =>
      oldDelegate.strokeOutlines != strokeOutlines ||
      oldDelegate.activeStrokeIndex != activeStrokeIndex ||
      oldDelegate.fallbackStrokes != fallbackStrokes;
}

class _SuperChineseStrokeAnimatorPainter extends CustomPainter {
  final List<List<Offset>> allStrokes;
  final List<Path> strokeOutlines;
  final int currentStrokeIndex;
  final double strokeProgress; // 0.0 to 1.0
  final bool isCompleted;

  const _SuperChineseStrokeAnimatorPainter({
    required this.allStrokes,
    required this.strokeOutlines,
    required this.currentStrokeIndex,
    required this.strokeProgress,
    required this.isCompleted,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (allStrokes.isEmpty || size.isEmpty) return;

    final scale = size.width / 1024;
    canvas.save();
    canvas.scale(scale, scale);

    final hasOutlines = strokeOutlines.length == allStrokes.length;

    // 1. Karakter telah selesai ditulis seutuhnya
    if (isCompleted) {
      if (hasOutlines) {
        final completePaint = Paint()
          ..color = const Color(0xFF1E293B)
          ..style = PaintingStyle.fill;
        for (final outline in strokeOutlines) {
          canvas.drawPath(outline, completePaint);
        }
      } else {
        final completePaint = Paint()
          ..color = const Color(0xFF1E293B)
          ..strokeWidth = 58
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..style = PaintingStyle.stroke;
        for (final s in allStrokes) {
          _drawSmoothPath(canvas, s, completePaint);
        }
      }
      canvas.restore();
      return;
    }

    // 2. Goresan masa depan (siluet abu-abu lembut)
    final futureStart = currentStrokeIndex + 1;
    if (hasOutlines) {
      final faintPaint = Paint()
        ..color = const Color(0xFFE2E8F0)
        ..style = PaintingStyle.fill;
      for (var i = futureStart; i < strokeOutlines.length; i++) {
        canvas.drawPath(strokeOutlines[i], faintPaint);
      }
    } else {
      final faintPaint = Paint()
        ..color = const Color(0xFFCBD5E1).withValues(alpha: 0.45)
        ..strokeWidth = 32
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      for (var i = futureStart; i < allStrokes.length; i++) {
        _drawSmoothPath(canvas, allStrokes[i], faintPaint);
      }
    }

    // 3. Goresan yang sudah selesai di tahap sebelumnya
    if (hasOutlines) {
      final prevPaint = Paint()
        ..color = const Color(0xFF1E293B)
        ..style = PaintingStyle.fill;
      for (var i = 0; i < currentStrokeIndex; i++) {
        canvas.drawPath(strokeOutlines[i], prevPaint);
      }
    } else {
      final prevPaint = Paint()
        ..color = const Color(0xFF1E293B)
        ..strokeWidth = 58
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      for (var i = 0; i < currentStrokeIndex; i++) {
        _drawSmoothPath(canvas, allStrokes[i], prevPaint);
      }
    }

    // 4. Goresan aktif yang sedang dianimasikan
    if (currentStrokeIndex >= 0 && currentStrokeIndex < allStrokes.length) {
      final points = allStrokes[currentStrokeIndex];
      if (points.isNotEmpty) {
        final progress = strokeProgress.clamp(0.0, 1.0);

        var totalLength = 0.0;
        for (var i = 0; i < points.length - 1; i++) {
          totalLength += (points[i + 1] - points[i]).distance;
        }

        final targetDist = totalLength * progress;
        var accDist = 0.0;
        final subPoints = <Offset>[points.first];
        var tip = points.first;

        for (var i = 0; i < points.length - 1; i++) {
          final segDist = (points[i + 1] - points[i]).distance;
          if (accDist + segDist < targetDist) {
            subPoints.add(points[i + 1]);
            accDist += segDist;
            tip = points[i + 1];
          } else {
            final remaining = targetDist - accDist;
            final ratio = segDist > 0.0001 ? (remaining / segDist) : 0.0;
            tip = Offset.lerp(points[i], points[i + 1], ratio)!;
            subPoints.add(tip);
            break;
          }
        }

        // Tampilkan goresan aktif
        if (hasOutlines) {
          final activeBgPaint = Paint()
            ..color = const Color(0xFFDCFCE7)
            ..style = PaintingStyle.fill;
          canvas.drawPath(strokeOutlines[currentStrokeIndex], activeBgPaint);

          canvas.save();
          canvas.clipPath(strokeOutlines[currentStrokeIndex]);
          final brushPaint = Paint()
            ..color = const Color(0xFF15803D)
            ..strokeWidth = 140
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..style = PaintingStyle.stroke;
          _drawSmoothPath(canvas, subPoints, brushPaint);
          canvas.restore();

          final borderPaint = Paint()
            ..color = const Color(0xFF16A34A).withValues(alpha: 0.45)
            ..strokeWidth = 2.5
            ..style = PaintingStyle.stroke;
          canvas.drawPath(strokeOutlines[currentStrokeIndex], borderPaint);
        } else {
          final activePaint = Paint()
            ..color = const Color(0xFF15803D)
            ..strokeWidth = 66
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..style = PaintingStyle.stroke;
          _drawSmoothPath(canvas, subPoints, activePaint);
        }

        // Marker Titik Awal Goresan
        final startPt = points.first;
        final redOriginPaint = Paint()
          ..color = const Color(0xFFDC2626)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(startPt, 22, redOriginPaint);
        final whiteOriginPaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill;
        canvas.drawCircle(startPt, 9, whiteOriginPaint);

        // Ujung stylus pena bergerak
        final tipPulsePaint = Paint()
          ..color = const Color(0xFFDC2626).withValues(alpha: 0.35)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(tip, 34, tipPulsePaint);

        final tipCorePaint = Paint()
          ..color = const Color(0xFFDC2626)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(tip, 18, tipCorePaint);

        final tipDotPaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill;
        canvas.drawCircle(tip, 8, tipDotPaint);
      }
    }

    canvas.restore();
  }

  void _drawSmoothPath(Canvas canvas, List<Offset> points, Paint paint) {
    if (points.isEmpty) return;
    if (points.length == 1) {
      canvas.drawCircle(points.first, paint.strokeWidth / 2, paint);
      return;
    }
    if (points.length == 2) {
      canvas.drawLine(points[0], points[1], paint);
      return;
    }
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final mid = Offset((p0.dx + p1.dx) / 2, (p0.dy + p1.dy) / 2);
      path.quadraticBezierTo(p0.dx, p0.dy, mid.dx, mid.dy);
    }
    path.lineTo(points.last.dx, points.last.dy);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(
    covariant _SuperChineseStrokeAnimatorPainter oldDelegate,
  ) => true;
}

/// Overlay panduan visual tahap penulisan pada kanvas Tianzige utama
class _ActiveStepGuidelinePainter extends CustomPainter {
  final List<Offset> stroke;

  const _ActiveStepGuidelinePainter({required this.stroke});

  @override
  void paint(Canvas canvas, Size size) {
    if (stroke.isEmpty || size.isEmpty) return;
    final scale = size.width / 1024;
    canvas.save();
    canvas.scale(scale, scale);

    final guidePaint = Paint()
      ..color = const Color(0xFF22C55E).withValues(alpha: 0.38)
      ..strokeWidth = 38
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
    for (var i = 1; i < stroke.length; i++) {
      path.lineTo(stroke[i].dx, stroke[i].dy);
    }
    canvas.drawPath(path, guidePaint);

    final startPt = stroke.first;
    final redPaint = Paint()
      ..color = const Color(0xFFEF4444).withValues(alpha: 0.85)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(startPt, 22, redPaint);

    final whitePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(startPt, 9, whitePaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ActiveStepGuidelinePainter oldDelegate) =>
      oldDelegate.stroke != stroke;
}
