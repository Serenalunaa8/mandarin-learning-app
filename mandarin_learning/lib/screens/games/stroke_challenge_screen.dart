import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../providers/vocabulary_provider.dart';
import '../../models/vocabulary_model.dart';
import '../../widgets/mascot_widget.dart';
import '../../services/hanzi_stroke_service.dart';

// FR-08: Hanzi Stroke Challenge with ordered stroke guidance and shape matching.

class StrokeChallengeScreen extends StatefulWidget {
  const StrokeChallengeScreen({super.key});

  @override
  State<StrokeChallengeScreen> createState() => _StrokeChallengeScreenState();
}

class _StrokeChallengeScreenState extends State<StrokeChallengeScreen> {
  List<VocabularyItem> _words = [];
  int _currentIndex = 0;
  final List<List<Offset>> _strokes = []; // each inner list = one stroke path
  List<Offset> _currentStroke = [];
  bool _isLoading = true;
  bool _isLoadingStrokeData = false;
  String? _strokeDataError;
  HanziStrokeData? _strokeData;
  int _characterIndex = 0;
  int _feedbackScore = 0;
  final GlobalKey _canvasKey = GlobalKey();
  bool _showFeedback = false;
  bool _feedbackPositive = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadWords());
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
      _strokeDataError = null;
      _strokeData = null;
    });
    try {
      final data = await HanziStrokeService.instance.load(character);
      if (!mounted || character != _currentCharacter) return;
      setState(() {
        _strokeData = data;
        _isLoadingStrokeData = false;
      });
    } catch (_) {
      if (!mounted || character != _currentCharacter) return;
      setState(() {
        _isLoadingStrokeData = false;
        _strokeDataError = 'Panduan stroke tidak dapat dimuat. Periksa internet lalu coba lagi.';
      });
    }
  }

  void _onPanStart(DragStartDetails d) {
    setState(() {
      _currentStroke = [d.localPosition];
    });
  }

  void _onPanUpdate(DragUpdateDetails d) {
    setState(() {
      _currentStroke.add(d.localPosition);
    });
  }

  void _onPanEnd(DragEndDetails d) {
    if (_currentStroke.length > 3) {
      setState(() {
        _strokes.add(List.from(_currentStroke));
        _currentStroke = [];
      });
    }
  }

  void _clearCanvas() {
    setState(() {
      _strokes.clear();
      _currentStroke = [];
      _showFeedback = false;
    });
  }

  void _checkWriting() {
    final canvasSize =
        (_canvasKey.currentContext?.findRenderObject() as RenderBox?)?.size;
    final strokeData = _strokeData;
    if (canvasSize == null || strokeData == null) return;
    final score = compareHanziStrokes(
      drawnStrokes: _strokes,
      reference: strokeData,
      canvasSize: canvasSize,
    );
    setState(() {
      _showFeedback = true;
      _feedbackScore = score;
      _feedbackPositive = score >= 75 && _strokes.length == _guideStrokeCount;
    });
  }

  void _nextWord() {
    final runeCount = _current?.hanzi.runes.length ?? 0;
    if (_characterIndex + 1 < runeCount) {
      setState(() {
        _characterIndex++;
        _strokes.clear();
        _currentStroke = [];
        _showFeedback = false;
      });
      _loadStrokeData();
      return;
    }
    setState(() {
      _currentIndex = (_currentIndex + 1) % _words.length;
      _characterIndex = 0;
      _strokes.clear();
      _currentStroke = [];
      _showFeedback = false;
    });
    _loadStrokeData();
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
      backgroundColor: AppColors.mintBackground,
      appBar: AppBar(
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        title: const Text('Hanzi Stroke Challenge'),
        actions: [
          TextButton.icon(
            onPressed: _nextWord,
            icon: const Icon(Icons.skip_next_rounded, color: Colors.white),
            label: const Text(
              'Lewati',
              style: TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              _buildWordInfo(word),
              const SizedBox(height: 20),
              _buildStrokeGuide(word),
              if (_strokeData != null) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _strokes.length < _guideStrokeCount
                        ? 'Langkah ${_strokes.length + 1} dari $_guideStrokeCount · Ikuti garis hijau'
                        : 'Semua langkah selesai · Periksa urutan dan bentuk tulisan',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              _buildCanvas(),
              const SizedBox(height: 16),
              _buildActionButtons(),
              if (_showFeedback) ...[
                const SizedBox(height: 16),
                _buildFeedback(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWordInfo(VocabularyItem word) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                _currentCharacter,
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryDark,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  word.pinyin,
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppColors.primaryGreen,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  word.artiIndonesia,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _strokeData == null
                        ? 'Memuat urutan stroke asli...'
                        : '$_guideStrokeCount stroke • karakter ${_characterIndex + 1}/${word.hanzi.runes.length}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFFB45309),
                      fontWeight: FontWeight.bold,
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

  Widget _buildStrokeGuide(VocabularyItem word) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '📖 Panduan Stroke',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 12),
          if (_isLoadingStrokeData)
            const Center(child: CircularProgressIndicator())
          else if (_strokeDataError != null)
            Row(
              children: [
                Expanded(
                  child: Text(
                    _strokeDataError!,
                    style: const TextStyle(fontSize: 12, color: Colors.red),
                  ),
                ),
                TextButton(
                  onPressed: _loadStrokeData,
                  child: const Text('Coba lagi'),
                ),
              ],
            )
          else if (_strokeData != null) ...[
            Wrap(
              spacing: 4,
              runSpacing: 8,
              children: List.generate(
                _guideStrokeCount,
                (index) => _StrokeGuideBox(
                  number: index + 1,
                  strokes: _strokeData!.strokes,
                  shownCount: index + 1,
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Setiap kotak menampilkan stroke sebenarnya sesuai urutan menulis.',
              style: TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCanvas() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '✏️ Kanvas Menulis',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 220,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 2),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Stack(
              children: [
                // Grid lines guide
                CustomPaint(painter: _GridPainter(), size: Size.infinite),
                // Show only completed strokes and the next stroke to prevent
                // tracing the whole character out of order.
                if (_strokeData != null)
                  CustomPaint(
                    painter: _ReferenceStrokePainter(
                      strokes: _strokeData!.strokes,
                      completedStrokeCount: _strokes.length,
                    ),
                    size: Size.infinite,
                  ),
                // Drawing canvas
                GestureDetector(
                  key: _canvasKey,
                  onPanStart: _onPanStart,
                  onPanUpdate: _onPanUpdate,
                  onPanEnd: _onPanEnd,
                  child: CustomPaint(
                    painter: _StrokePainter(
                      strokes: _strokes,
                      currentStroke: _currentStroke,
                    ),
                    size: Size.infinite,
                  ),
                ),
                // Stroke counter
                Positioned(
                  top: 8,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${_strokes.length} stroke',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _clearCanvas,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Hapus'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primaryDark,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            onPressed:
                _strokes.isNotEmpty &&
                    _strokeData != null &&
                    !_isLoadingStrokeData
                ? _checkWriting
                : null,
            icon: const Icon(Icons.check_circle_outline_rounded),
            label: const Text('Periksa Tulisan'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFeedback() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _feedbackPositive
            ? const Color(0xFFD1FAE5)
            : const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _feedbackPositive ? AppColors.primaryGreen : Colors.red,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          MascotWidget(
            pose: _feedbackPositive
                ? MascotPose.celebrating
                : MascotPose.studying,
            size: 56,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _feedbackPositive ? 'Cukup cocok' : 'Masih kurang tepat',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: _feedbackPositive
                        ? AppColors.primaryDark
                        : Colors.red[700],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Kecocokan bentuk: $_feedbackScore%. Urutan yang digambar: ${_strokes.length}/$_guideStrokeCount stroke. '
                  '${_feedbackPositive ? 'Bentuk dan urutan cukup sesuai.' : 'Periksa arah, bentuk, dan jumlah stroke lalu coba lagi.'}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _nextWord,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Karakter Berikutnya →'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Custom Painters ──────────────────────────────────────────

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFF1F5F9)
      ..strokeWidth = 1;

    // Vertical center line
    canvas.drawLine(
      Offset(size.width / 2, 0),
      Offset(size.width / 2, size.height),
      paint,
    );
    // Horizontal center line
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      paint,
    );

    // Diagonal guides (lighter)
    paint.color = const Color(0xFFF8FAFC);
    canvas.drawLine(Offset(0, 0), Offset(size.width, size.height), paint);
    canvas.drawLine(Offset(size.width, 0), Offset(0, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _StrokePainter extends CustomPainter {
  final List<List<Offset>> strokes;
  final List<Offset> currentStroke;

  const _StrokePainter({required this.strokes, required this.currentStroke});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1E3A5F)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    void drawPath(List<Offset> points) {
      if (points.length < 2) return;
      final path = Path()..moveTo(points[0].dx, points[0].dy);
      for (int i = 1; i < points.length; i++) {
        path.lineTo(points[i].dx, points[i].dy);
      }
      canvas.drawPath(path, paint);
    }

    for (final stroke in strokes) {
      drawPath(stroke);
    }
    drawPath(currentStroke);
  }

  @override
  bool shouldRepaint(covariant _StrokePainter old) =>
      old.strokes != strokes || old.currentStroke != currentStroke;
}

class _StrokeGuideBox extends StatelessWidget {
  final int number;
  final List<List<Offset>> strokes;
  final int shownCount;

  const _StrokeGuideBox({
    required this.number,
    required this.strokes,
    required this.shownCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primaryDark.withValues(alpha: 0.3)),
      ),
      child: CustomPaint(
        painter: _StrokeStepPainter(
          strokes: strokes,
          shownCount: shownCount,
          highlightedStroke: number - 1,
        ),
        child: Align(
          alignment: Alignment.topLeft,
          child: Text(
            '$number',
            style: const TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryGreen,
            ),
          ),
        ),
      ),
    );
  }
}

class _ReferenceStrokePainter extends CustomPainter {
  final List<List<Offset>> strokes;
  final int completedStrokeCount;

  const _ReferenceStrokePainter({
    required this.strokes,
    required this.completedStrokeCount,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final side = math.min(size.width, size.height);
    canvas.save();
    canvas.translate((size.width - side) / 2, (size.height - side) / 2);
    canvas.scale(side / 1024);
    final completedPaint = Paint()
      ..color = AppColors.primaryDark.withValues(alpha: 0.16)
      ..strokeWidth = 40
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final nextPaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.55)
      ..strokeWidth = 48
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final completed = completedStrokeCount.clamp(0, strokes.length);
    for (var index = 0; index < completed; index++) {
      _drawStroke(canvas, strokes[index], completedPaint);
    }
    if (completed < strokes.length) {
      _drawStroke(canvas, strokes[completed], nextPaint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ReferenceStrokePainter oldDelegate) =>
      !identical(oldDelegate.strokes, strokes) ||
      oldDelegate.completedStrokeCount != completedStrokeCount;
}

class _StrokeStepPainter extends CustomPainter {
  final List<List<Offset>> strokes;
  final int shownCount;
  final int highlightedStroke;

  const _StrokeStepPainter({
    required this.strokes,
    required this.shownCount,
    required this.highlightedStroke,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 1024, size.height / 1024);
    for (var index = 0; index < shownCount && index < strokes.length; index++) {
      final paint = Paint()
        ..color = index == highlightedStroke
            ? AppColors.primary
            : AppColors.primaryDark.withValues(alpha: 0.32)
        ..strokeWidth = 72
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      _drawStroke(canvas, strokes[index], paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _StrokeStepPainter oldDelegate) =>
      oldDelegate.shownCount != shownCount ||
      !identical(oldDelegate.strokes, strokes);
}

void _drawStroke(Canvas canvas, List<Offset> points, Paint paint) {
  if (points.isEmpty) return;
  final path = Path()..moveTo(points.first.dx, points.first.dy);
  for (var index = 1; index < points.length; index++) {
    path.lineTo(points[index].dx, points[index].dy);
  }
  canvas.drawPath(path, paint);
}
