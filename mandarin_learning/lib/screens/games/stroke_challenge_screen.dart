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
  Color _selectedColor = const Color(0xFF15803D); // Hijau Tua default
  double _strokeWidth = 8.0;
  bool _isEraser = false;

  // Pilihan warna pena
  final List<Color> _colorPalette = const [
    Color(0xFF15803D), // Hijau Tua
    Color(0xFF1E293B), // Hitam / Slate
    Color(0xFFDC2626), // Merah
    Color(0xFFF59E0B), // Kuning / Amber
    Color(0xFF22C55E), // Hijau Muda
  ];

  // Pagination langkah stroke (kanan)
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
          _showActiveStepGuide =
              false; // Arahan penulisan pada kanvas hanya diputar sekali saja
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
    // Video pemutar di bawah dapat diputar ulang berkali-kali sesuai kebutuhan pengguna
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
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(
                res.isPassed
                    ? Icons.check_circle_rounded
                    : Icons.info_outline_rounded,
                color: res.isPassed ? AppColors.primaryGreen : Colors.orange,
                size: 28,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  res.feedbackTitle,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Skor Ketepatan Bentuk: ${res.totalScore}%',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryDark,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                res.feedbackMessage,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
          actions: [
            if (!res.isPassed)
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _clearCanvas();
                },
                child: const Text('Coba Lagi'),
              ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                if (res.isPassed) {
                  _nextWord();
                }
              },
              child: Text(res.isPassed ? 'Lanjut Kata Berikutnya →' : 'Tutup'),
            ),
          ],
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

  String _shortenStrokeRule(String rule) {
    if (rule.contains('Dari kiri ke kanan')) return 'Kiri ke kanan';
    if (rule.contains('Dari atas ke bawah')) return 'Atas ke bawah';
    if (rule.contains('Miring kiri dulu')) return 'Miring kiri lalu kanan';
    if (rule.contains('Dari luar ke dalam')) return 'Luar ke dalam';
    return rule;
  }

  String _shortenStrokeDescription(String description) {
    if (description.contains('Tarik')) {
      return description
          .replaceFirst(' dengan stabil', '')
          .replaceFirst(' sebagai penopang dasar', '');
    }
    if (description.contains('Tulis bagian')) {
      return description
          .replaceFirst('Tulis bagian ', 'Mulai ')
          .replaceFirst(' terlebih dahulu, kemudian ', ', lalu ');
    }
    return description;
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
      backgroundColor: const Color(0xFFF0FDF4),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTopBar(),
              const SizedBox(height: 10),
              _buildWordCard(word),
              const SizedBox(height: 14),
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 640;
                  if (isWide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 5, child: _buildCanvasSection()),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 4,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildAnimatedStrokeGuideSection(),
                              const SizedBox(height: 12),
                              _buildToolPaletteCard(),
                            ],
                          ),
                        ),
                      ],
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildCanvasSection(),
                      const SizedBox(height: 14),
                      _buildAnimatedStrokeGuideSection(),
                      const SizedBox(height: 14),
                      _buildToolPaletteCard(),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textDark),
          onPressed: () => Navigator.pop(context),
        ),
        const SizedBox(width: 4),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hanzi Stroke Challenge',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              Text(
                'Ikuti garis, lalu tulis perlahan.',
                style: TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
        Image.asset(
          'assets/image/beranda/maskot_02_baca_buku.png',
          width: 50,
          height: 50,
          fit: BoxFit.contain,
        ),
        const SizedBox(width: 8),
        InkWell(
          onTap: _nextWord,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.play_arrow_rounded,
                  size: 16,
                  color: AppColors.textDark,
                ),
                SizedBox(width: 2),
                Text(
                  'Lewati',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWordCard(VocabularyItem word) {
    final vocab = context.watch<VocabularyProvider>();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFDCFCE7)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          Row(
            children: [
              // Kotak Karakter Hanzi & Pinyin (Kiri)
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _currentCharacter,
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF14532D),
                        height: 1.1,
                      ),
                    ),
                    Text(
                      word.pinyin,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF15803D),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              // Detail Kata (Kanan)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          word.hanzi,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF14532D),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          word.pinyin,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF15803D),
                          ),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () => AudioService.instance.speak(word.hanzi),
                          child: const Icon(
                            Icons.volume_up_rounded,
                            size: 20,
                            color: Color(0xFF15803D),
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
                        color: AppColors.textDark,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.bar_chart_rounded,
                            size: 14,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$_guideStrokeCount stroke standar • Karakter ${_characterIndex + 1}/${word.hanzi.runes.length}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // HSK Badge di pojok kanan atas
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🎓', style: TextStyle(fontSize: 10)),
                  const SizedBox(width: 4),
                  Text(
                    'HSK ${vocab.selectedLevel}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1D4ED8),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCanvasSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Tulis Hanzi
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
                    'Tulis Hanzi',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  Text(
                    'Ikuti garis hijau di dalam kotak.',
                    style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Tianzige Canvas
          AspectRatio(
            aspectRatio: 1.0,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFFAFAFA),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Garis Tianzige (田字格)
                    CustomPaint(
                      painter: _TianzigeGridPainter(),
                      size: Size.infinite,
                    ),
                    // Karakter Mandarin Asli Autentik (Watermark Bentuk Hanzi Persis 100%)
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
          const SizedBox(height: 10),
          // Tombol Reset & Toggle Panduan di bawah kanvas
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                onPressed: _clearCanvas,
                icon: const Icon(
                  Icons.refresh_rounded,
                  size: 16,
                  color: AppColors.textDark,
                ),
                label: const Text(
                  'Reset',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textDark,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (_strokeData != null && _strokeData!.strokes.isNotEmpty)
                InkWell(
                  onTap: () => setState(
                    () => _showActiveStepGuide = !_showActiveStepGuide,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 4,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _showActiveStepGuide
                              ? Icons.visibility_rounded
                              : Icons.visibility_off_rounded,
                          size: 14,
                          color: _showActiveStepGuide
                              ? const Color(0xFF15803D)
                              : AppColors.textMuted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _showActiveStepGuide
                              ? 'Panduan Tahap ${_activeStrokeStep + 1}'
                              : 'Panduan Mati',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _showActiveStepGuide
                                ? const Color(0xFF15803D)
                                : AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          // Tombol Aksi Utama: Periksa Hanzi
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF15803D),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 2,
            ),
            onPressed: _drawnStrokes.isNotEmpty && !_isLoadingStrokeData
                ? _checkWriting
                : null,
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.edit_note_rounded, size: 20),
                SizedBox(width: 8),
                Text(
                  'Periksa Hanzi  →',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          if (_showFeedback && _evalResult != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _evalResult!.isPassed
                    ? const Color(0xFFDCFCE7)
                    : const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _evalResult!.isPassed
                      ? AppColors.primaryGreen
                      : Colors.orange,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _evalResult!.isPassed
                        ? Icons.check_circle_rounded
                        : Icons.info_outline_rounded,
                    color: _evalResult!.isPassed
                        ? AppColors.primaryGreen
                        : Colors.orange,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${_evalResult!.feedbackTitle} (${_evalResult!.totalScore}%)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
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
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFDCFCE7), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Bar Animasi Super Chinese
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.play_circle_fill_rounded,
                  color: Color(0xFF15803D),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Animasi Urutan Goresan (笔顺)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    Text(
                      'Amati, lalu ikuti di kanvas.',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              // Tombol Pengatur Kecepatan Putar
              InkWell(
                onTap: _toggleSpeed,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.speed_rounded,
                        size: 14,
                        color: AppColors.textDark,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'x',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Display Tianzige Animasi (Super Chinese Style Canvas)
          Center(
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                color: const Color(0xFFFAFAFA),
                borderRadius: BorderRadius.circular(16),
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
                borderRadius: BorderRadius.circular(15),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Grid Garis Tianzige (田字格)
                    CustomPaint(
                      painter: _TianzigeGridPainter(),
                      size: Size.infinite,
                    ),
                    // Pelukis Animasi Goresan Hidup
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
                    // Badge Indikator Status & Nomor Goresan
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
                              ? const Color(0xFF15803D)
                              : Colors.white.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _isAnimationComplete
                                ? const Color(0xFF15803D)
                                : const Color(0xFFCBD5E1),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 3,
                            ),
                          ],
                        ),
                        child: Text(
                          _isAnimationComplete ? 'Selesai ✓' : 'Goresan  / ',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: _isAnimationComplete
                                ? Colors.white
                                : AppColors.textDark,
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

          // Baris Navigasi Langkah Demi Langkah (Interactive Step Chips)
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
                            ? const Color(0xFF15803D)
                            : isDone
                            ? const Color(0xFFDCFCE7)
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isCurrent
                              ? const Color(0xFF15803D)
                              : isDone
                              ? const Color(0xFF86EFAC)
                              : const Color(0xFFCBD5E1),
                          width: isCurrent ? 1.5 : 1.0,
                        ),
                      ),
                      child: Text(
                        '',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isCurrent
                              ? FontWeight.bold
                              : FontWeight.w600,
                          color: isCurrent
                              ? Colors.white
                              : isDone
                              ? const Color(0xFF14532D)
                              : AppColors.textDark,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 12),

          // Kontrol Pemutar Animasi (Super Chinese Style: Prev, Play/Pause/Replay, Next)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: _animStrokeIndex > 0 ? _prevStrokeStep : null,
                icon: const Icon(Icons.skip_previous_rounded),
                color: const Color(0xFF15803D),
                disabledColor: const Color(0xFFCBD5E1),
                tooltip: 'Goresan Sebelumnya',
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF15803D),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  elevation: 1,
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
                color: const Color(0xFF15803D),
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
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFBBF7D0)),
                    ),
                    child: Center(
                      child: Text(
                        activeInfo.symbol.isNotEmpty ? activeInfo.symbol : '',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF15803D),
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
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textDark,
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
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF3730A3),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          ruleInfo.ruleDesc,
                          style: TextStyle(
                            fontSize: 10.5,
                            color: Colors.grey.shade700,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLoadingOrEmptyGuideCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFDCFCE7)),
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
                color: Color(0xFF15803D),
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Memuat animasi urutan goresan...',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolPaletteCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Alat Gambar',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: AppColors.textDark,
                ),
              ),
              InkWell(
                onTap: _clearCanvas,
                child: const Row(
                  children: [
                    Icon(
                      Icons.refresh_rounded,
                      size: 14,
                      color: AppColors.textMuted,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Reset',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Mode Pena vs Hapus
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _isEraser = false),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: !_isEraser
                          ? const Color(0xFF15803D)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.edit_rounded,
                          size: 15,
                          color: !_isEraser ? Colors.white : AppColors.textDark,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Pena',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: !_isEraser
                                ? Colors.white
                                : AppColors.textDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _isEraser = true),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: _isEraser
                          ? const Color(0xFFDC2626)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.auto_fix_high_rounded,
                          size: 15,
                          color: _isEraser ? Colors.white : AppColors.textDark,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Hapus',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _isEraser
                                ? Colors.white
                                : AppColors.textDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Ukuran Pena Slider
          const Text(
            'Ukuran Pena',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          Row(
            children: [
              const Text(
                '―',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: const Color(0xFF15803D),
                    inactiveTrackColor: const Color(0xFFDCFCE7),
                    thumbColor: const Color(0xFF15803D),
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 6,
                    ),
                  ),
                  child: Slider(
                    value: _strokeWidth,
                    min: 3.0,
                    max: 14.0,
                    onChanged: (v) => setState(() => _strokeWidth = v),
                  ),
                ),
              ),
              const Text(
                '+',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Warna Pena
          const Text(
            'Warna Pena',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: _colorPalette.map((col) {
              final isSel = _selectedColor == col && !_isEraser;
              return GestureDetector(
                onTap: () => setState(() {
                  _selectedColor = col;
                  _isEraser = false;
                }),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: col,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSel ? Colors.white : Colors.transparent,
                      width: 2.5,
                    ),
                    boxShadow: isSel
                        ? [
                            BoxShadow(
                              color: col.withValues(alpha: 0.4),
                              blurRadius: 6,
                              spreadRadius: 2,
                            ),
                          ]
                        : null,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          // Tips Card Kaidah Penulisan Hanzi
          Builder(
            builder: (context) {
              final strokes = _strokeData?.strokes ?? [];
              final activeInfo =
                  strokes.isNotEmpty &&
                      _activeStrokeStep >= 0 &&
                      _activeStrokeStep < strokes.length
                  ? _getStrokeInfo(
                      _activeStrokeStep,
                      strokes[_activeStrokeStep],
                    )
                  : null;
              final ruleTitle = activeInfo != null
                  ? 'Tahap ${_activeStrokeStep + 1}: ${_shortenStrokeRule(activeInfo.rule)}'
                  : 'Tips menulis';
              final ruleDesc = activeInfo != null
                  ? _shortenStrokeDescription(activeInfo.description)
                  : 'Ikuti garis hijau dan tulis perlahan.';
              return Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('💡', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ruleTitle,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF166534),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            ruleDesc,
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: Color(0xFF15803D),
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
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

    // 2. Goresan masa depan (siluet abu-abu lembut agar bentuk karakter Mandarin utuh tampak persis)
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

    // 3. Goresan yang sudah selesai di tahap sebelumnya (Tinta Pekat Solid #1E293B)
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
          // Placeholder bentuk dasar goresan aktif (hijau sangat muda)
          final activeBgPaint = Paint()
            ..color = const Color(0xFFDCFCE7)
            ..style = PaintingStyle.fill;
          canvas.drawPath(strokeOutlines[currentStrokeIndex], activeBgPaint);

          // Animasi kuas yang mengisi bentuk goresan asli persis
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

          // Garis tepi halus
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

        // Marker Titik Awal Goresan (Titik Merah Asal Penulisan)
        final startPt = points.first;
        final redOriginPaint = Paint()
          ..color = const Color(0xFFDC2626)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(startPt, 22, redOriginPaint);
        final whiteOriginPaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill;
        canvas.drawCircle(startPt, 9, whiteOriginPaint);

        // Ujung stylus pena bergerak (Pulsing Red Stylus Tip Cursor ala Super Chinese)
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
