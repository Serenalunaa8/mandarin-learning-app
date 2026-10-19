import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../providers/vocabulary_provider.dart';
import '../../models/vocabulary_model.dart';
import '../../widgets/mascot_widget.dart';

// FR-08: Hanzi Stroke Challenge — tampilkan panduan urutan stroke + kanvas menulis
// Validasi terbatas (free-draw canvas), feedback sederhana "Bagus!" / "Coba Lagi"

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
  bool _showFeedback = false;
  bool _feedbackPositive = false;

  // Stroke guide data (simplified: stroke count per common character)
  static const Map<String, int> _strokeCounts = {
    '我': 7,
    '你': 7,
    '他': 5,
    '们': 5,
    '是': 9,
    '的': 8,
    '了': 2,
    '在': 6,
    '有': 6,
    '大': 3,
    '小': 3,
    '中': 4,
    '人': 2,
    '日': 4,
    '月': 4,
    '水': 4,
    '火': 4,
    '木': 4,
    '金': 8,
    '土': 3,
  };

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
  }

  VocabularyItem? get _current =>
      _words.isNotEmpty && _currentIndex < _words.length
      ? _words[_currentIndex]
      : null;

  int get _guideStrokeCount {
    final hanzi = _current?.hanzi ?? '';
    return _strokeCounts[hanzi] ?? hanzi.length + 2;
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
    // Validasi terbatas: minimal stroke count ~ expected
    final expected = _guideStrokeCount;
    final written = _strokes.length;
    final positive = written >= (expected - 2) && written <= (expected + 3);
    setState(() {
      _showFeedback = true;
      _feedbackPositive = positive;
    });
  }

  void _nextWord() {
    setState(() {
      _currentIndex = (_currentIndex + 1) % _words.length;
      _strokes.clear();
      _currentStroke = [];
      _showFeedback = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
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
                word.hanzi,
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
                    'Perkiraan $_guideStrokeCount stroke',
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(
              _guideStrokeCount.clamp(1, 8),
              (i) => _StrokeGuideBox(
                number: i + 1,
                hanzi: word.hanzi,
                progress: (i + 1) / _guideStrokeCount,
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tulis karakter ini mengikuti urutan stroke di atas.',
            style: TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
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
                // Ghost hanzi guide
                Center(
                  child: Text(
                    _current?.hanzi ?? '',
                    style: TextStyle(
                      fontSize: 120,
                      color: Colors.grey.withValues(alpha: 0.08),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                // Drawing canvas
                GestureDetector(
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
            onPressed: _strokes.isNotEmpty ? _checkWriting : null,
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
                  _feedbackPositive ? '🎉 Bagus Sekali!' : '💪 Coba Lagi!',
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
                  _feedbackPositive
                      ? 'Jumlah stroke sudah sesuai. Lanjut ke karakter berikutnya!'
                      : 'Perkiraan $_guideStrokeCount stroke, kamu menulis ${_strokes.length} stroke. Coba lagi!',
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

// ── Stroke Guide Box ─────────────────────────────────────────

class _StrokeGuideBox extends StatelessWidget {
  final int number;
  final String hanzi;
  final double progress;

  const _StrokeGuideBox({
    required this.number,
    required this.hanzi,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primaryDark.withValues(alpha: 0.3)),
      ),
      child: Stack(
        children: [
          Center(
            child: ClipRect(
              child: Align(
                alignment: Alignment.centerLeft,
                widthFactor: progress,
                child: Text(
                  hanzi,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryDark.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 2,
            child: Text(
              '$number',
              style: const TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryGreen,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
