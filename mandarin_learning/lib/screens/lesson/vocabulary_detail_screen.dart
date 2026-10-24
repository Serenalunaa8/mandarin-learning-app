import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../models/vocabulary_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/vocabulary_provider.dart';
import '../../services/audio_service.dart';
import '../../services/vocabulary_service.dart';
import '../practice/quiz_screen.dart';

class VocabularyDetailScreen extends StatefulWidget {
  final VocabularyItem item;
  final List<VocabularyItem>? vocabularyList;

  const VocabularyDetailScreen({
    super.key,
    required this.item,
    this.vocabularyList,
  });

  @override
  State<VocabularyDetailScreen> createState() => _VocabularyDetailScreenState();
}

class _VocabularyDetailScreenState extends State<VocabularyDetailScreen> {
  late int _currentIndex;
  late List<VocabularyItem> _wordList;
  late Future<List<ExampleSentence>> _examplesFuture;

  @override
  void initState() {
    super.initState();
    if (widget.vocabularyList != null && widget.vocabularyList!.isNotEmpty) {
      _wordList = widget.vocabularyList!;
    } else {
      final vocab = context.read<VocabularyProvider>();
      final unitItems =
          vocab.currentLevelUnits[vocab.selectedUnit] ??
          vocab.currentLevelVocabulary;
      _wordList = unitItems.isNotEmpty ? unitItems : [widget.item];
    }
    final foundIndex = _wordList.indexWhere((w) => w.id == widget.item.id);
    _currentIndex = foundIndex >= 0 ? foundIndex : 0;
    _examplesFuture = VocabularyService.instance.getExampleSentences(
      _wordList[_currentIndex],
    );
  }

  void _nextWord() {
    final vocab = context.read<VocabularyProvider>();
    final auth = context.read<AuthProvider>();

    // Tandai kata saat ini sudah dipelajari
    final currentWord = _wordList[_currentIndex];
    vocab.markAsLearned(
      vocabId: currentWord.id,
      userId: auth.profile?.id ?? 'guest_local_user',
      hskLevel: currentWord.hskLevel,
    );

    if (_currentIndex < _wordList.length - 1) {
      setState(() {
        _currentIndex++;
        _examplesFuture = VocabularyService.instance.getExampleSentences(
          _wordList[_currentIndex],
        );
      });
    } else {
      // Unit selesai! Lanjut ke Kuis Utama sesuai alur PRD 8.1
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('Unit Kosakata Selesai! 🎉'),
          content: const Text(
            'Hebat! Kamu telah menyelesaikan kosakata di unit ini. Lanjut uji kemampuanmu di Kuis Latihan?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Nanti Saja'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => QuizScreen(customItems: _wordList),
                  ),
                );
              },
              child: const Text('Mulai Kuis 🎯'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final currentItem = _wordList[_currentIndex];
    final displayTotal = _wordList.length;
    final displayIndex = _currentIndex + 1;
    final progress = displayIndex / displayTotal;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F8F4),
      body: Stack(
        children: [
          // Background Gradient
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFFF6FAF7),
                    Color(0xFFEDF7F1),
                    Color(0xFFE5F3EB),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),

          // Bottom Rolling Green Hills Scenery with Daisies
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.90,
                child: Image.asset(
                  'assets/image/landing_page/11_lahan_hijau.png',
                  height: 130,
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                  errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                ),
              ),
            ),
          ),

          // Main Screen Content
          SafeArea(
            child: Column(
              children: [
                // Top App Bar (Back button, Title, Diamond Badge)
                _buildTopBar(context, auth),

                // Top Progress Bar
                _buildProgressBar(progress, displayIndex, displayTotal),

                const SizedBox(height: 8),

                // Scrollable Cards Area
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Column(
                      children: [
                        // Card 1: Main Word Card with Hanzi, Audio, Meaning, and 3D Illustration
                        _buildMainWordCard(currentItem),

                        const SizedBox(height: 16),

                        // Card 2: Contoh Kalimat Card
                        _buildContohKalimatCard(currentItem),

                        // Bottom spacing for comfortable scroll above button
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),

                // Sticky Bottom "Lanjut" Button
                _buildBottomButton(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, AuthProvider auth) {
    final coinAmount = auth.coins > 0 ? auth.coins : 120;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Circular Back Button
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1E3A24).withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  Icons.arrow_back_rounded,
                  color: Color(0xFF1E3A24),
                  size: 22,
                ),
              ),
            ),
          ),

          // Screen Title
          const Text(
            'Kosakata',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E3A24),
              letterSpacing: -0.3,
            ),
          ),

          // Diamond / Coins Badge Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1E3A24).withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.diamond_rounded,
                  color: Color(0xFF38BDF8),
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  '$coinAmount',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E3A24),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(double progress, int displayIndex, int displayTotal) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Row(
        children: [
          // Rounded Linear Progress Bar
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: const Color(0xFFE2F0E7),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  Color(0xFF22C55E),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Counter Text
          Text(
            '$displayIndex/$displayTotal',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainWordCard(VocabularyItem currentItem) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3A24).withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left Column: Hanzi Box, Speaker, and Meaning
          Expanded(
            flex: 11,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Hanzi Box + Audio Speaker Button
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Mint Hanzi & Pinyin Box
                    Container(
                      width: 118,
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF8EF),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            currentItem.hanzi,
                            style: const TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF165B33),
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            currentItem.pinyin,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF16A34A),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Circular Speaker Button
                    GestureDetector(
                      onTap: () => AudioService.instance.speak(
                        currentItem.hanzi,
                      ),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: const BoxDecoration(
                          color: Color(0xFFDCFCE7),
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.volume_up_rounded,
                            color: Color(0xFF16A34A),
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Meaning / Indonesian Translation
                Text(
                  currentItem.artiIndonesia,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF64748B),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Right Column: Thematic 3D Illustration
          Expanded(
            flex: 9,
            child: _WordIllustrationWidget(item: currentItem),
          ),
        ],
      ),
    );
  }

  Widget _buildContohKalimatCard(VocabularyItem currentItem) {
    return FutureBuilder<List<ExampleSentence>>(
      future: _examplesFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Text(
              'Gagal memuat contoh kalimat: ${snapshot.error}',
              style: const TextStyle(color: Colors.red),
            ),
          );
        }

        if (!snapshot.hasData) {
          return Container(
            width: double.infinity,
            height: 140,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF16A34A)),
              ),
            ),
          );
        }

        final examples = snapshot.data!;
        if (examples.isEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1E3A24).withValues(alpha: 0.05),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row: Book Icon, Title, and Kalimat Count Pill
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.menu_book_rounded,
                        color: Color(0xFF16A34A),
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Contoh Kalimat',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E3A24),
                    ),
                  ),
                  const Spacer(),

                  // Pill: "X Kalimat"
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${examples.length} Kalimat',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF16A34A),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // List of Example Sentences
              ...examples.asMap().entries.map((entry) {
                final index = entry.key;
                final example = entry.value;

                return Container(
                  margin: EdgeInsets.only(
                    bottom: index < examples.length - 1 ? 12 : 0,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F8F5),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    children: [
                      // Cute Sprout and Daisy Decoration at Bottom-Left of First Sentence
                      if (index == 0)
                        Positioned(
                          left: -4,
                          bottom: -4,
                          child: IgnorePointer(
                            child: Opacity(
                              opacity: 0.85,
                              child: SizedBox(
                                width: 38,
                                height: 38,
                                child: Stack(
                                  children: [
                                    Image.asset(
                                      'assets/image/beranda/daun_tunas.png',
                                      width: 32,
                                      height: 32,
                                      fit: BoxFit.contain,
                                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                                    ),
                                    Positioned(
                                      right: 0,
                                      top: 4,
                                      child: Image.asset(
                                        'assets/image/beranda/bunga_putih.png',
                                        width: 18,
                                        height: 18,
                                        fit: BoxFit.contain,
                                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),

                      // Sentence Content Row
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Number Circle Badge
                            Container(
                              width: 26,
                              height: 26,
                              margin: const EdgeInsets.only(right: 12, top: 2),
                              decoration: const BoxDecoration(
                                color: Color(0xFFDCFCE7),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  '${index + 1}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF16A34A),
                                  ),
                                ),
                              ),
                            ),

                            // Hanzi, Pinyin, and Indonesian Translation
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    example.hanzi,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1E3A24),
                                      height: 1.25,
                                    ),
                                  ),
                                  if (example.pinyin != null &&
                                      example.pinyin!.isNotEmpty) ...[
                                    const SizedBox(height: 3),
                                    Text(
                                      example.pinyin!,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF16A34A),
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 4),
                                  Text(
                                    example.arti,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF64748B),
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(width: 8),

                            // Circular Speaker Button for Example Sentence
                            GestureDetector(
                              onTap: () => AudioService.instance.speak(
                                example.hanzi,
                              ),
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFDCFCE7),
                                  shape: BoxShape.circle,
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.volume_up_rounded,
                                    color: Color(0xFF16A34A),
                                    size: 19,
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
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBottomButton() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 16),
      color: Colors.transparent,
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF16A34A),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
            elevation: 0,
            shadowColor: const Color(0xFF16A34A).withValues(alpha: 0.35),
          ),
          onPressed: _nextWord,
          child: const Text(
            'Lanjut',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ),
    );
  }
}

/// Dynamic Thematic Illustration Widget matching the reference image
class _WordIllustrationWidget extends StatelessWidget {
  final VocabularyItem item;

  const _WordIllustrationWidget({required this.item});

  @override
  Widget build(BuildContext context) {
    final isLoveTheme = item.hanzi.contains('爱') ||
        item.hanzi.contains('喜') ||
        item.artiIndonesia.toLowerCase().contains('cinta') ||
        item.artiIndonesia.toLowerCase().contains('sayang');

    return SizedBox(
      height: 145,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // Soft blue cloud radial glow in background
          Positioned(
            top: 6,
            right: 0,
            left: 0,
            bottom: 6,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFE0F2FE).withValues(alpha: 0.90),
                    const Color(0xFFF0FDF4).withValues(alpha: 0.0),
                  ],
                  radius: 0.85,
                ),
              ),
            ),
          ),

          if (isLoveTheme) ...[
            // 3D Heart on Stacked Books Painter (Exact Match to Reference Mockup)
            Positioned.fill(
              child: CustomPaint(
                painter: _HeartBooksPainter(),
              ),
            ),

            // Green Leaf Tunas at the base
            Positioned(
              left: 4,
              bottom: 12,
              child: Image.asset(
                'assets/image/beranda/daun_tunas.png',
                width: 32,
                height: 32,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),

            // White Daisy at the base
            Positioned(
              left: 18,
              bottom: 8,
              child: Image.asset(
                'assets/image/beranda/bunga_putih.png',
                width: 22,
                height: 22,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ] else ...[
            // Stacked Books Base
            Positioned.fill(
              child: CustomPaint(
                painter: _BooksBasePainter(),
              ),
            ),

            // Mascot reading book sitting on top of books
            Positioned(
              top: 8,
              child: Image.asset(
                'assets/image/beranda/maskot_02_baca_buku.png',
                width: 90,
                height: 90,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Image.asset(
                  'assets/image/register/09_mascot_head.png',
                  width: 70,
                  height: 70,
                  fit: BoxFit.contain,
                ),
              ),
            ),

            // Sparkle rays around mascot
            Positioned(
              top: 8,
              right: 6,
              child: Image.asset(
                'assets/image/beranda/kilau_01.png',
                width: 18,
                height: 18,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),

            // Green Leaf at base
            Positioned(
              left: 6,
              bottom: 10,
              child: Image.asset(
                'assets/image/beranda/daun_tunas.png',
                width: 28,
                height: 28,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),

            // White Daisy at base
            Positioned(
              left: 20,
              bottom: 8,
              child: Image.asset(
                'assets/image/beranda/bunga_putih.png',
                width: 20,
                height: 20,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 3D Heart on Stacked Books with Yellow Burst Rays (Exact Mockup Representation)
class _HeartBooksPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 1. Yellow burst sparkle rays around the heart
    final sparkPaint = Paint()
      ..color = const Color(0xFFFBBF24)
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Top-left sparkle rays
    canvas.drawLine(
      Offset(w * 0.28, h * 0.22),
      Offset(w * 0.22, h * 0.20),
      sparkPaint,
    );
    canvas.drawLine(
      Offset(w * 0.24, h * 0.31),
      Offset(w * 0.18, h * 0.32),
      sparkPaint,
    );

    // Top-right sparkle rays
    canvas.drawLine(
      Offset(w * 0.72, h * 0.18),
      Offset(w * 0.77, h * 0.14),
      sparkPaint,
    );
    canvas.drawLine(
      Offset(w * 0.82, h * 0.25),
      Offset(w * 0.89, h * 0.23),
      sparkPaint,
    );
    canvas.drawLine(
      Offset(w * 0.80, h * 0.34),
      Offset(w * 0.87, h * 0.35),
      sparkPaint,
    );

    // 2. Bottom Book (Warm Orange / Yellow)
    canvas.save();
    canvas.translate(w * 0.52, h * 0.75);
    canvas.rotate(-0.04);
    final bottomBookRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: w * 0.64, height: h * 0.16),
      const Radius.circular(8),
    );
    canvas.drawRRect(
      bottomBookRect.shift(const Offset(0, 4)),
      Paint()..color = Colors.black.withValues(alpha: 0.08),
    );
    canvas.drawRRect(
      bottomBookRect,
      Paint()..color = const Color(0xFFF59E0B),
    );
    final pagesBottomRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(-w * 0.29, -h * 0.055, w * 0.59, h * 0.11),
      const Radius.circular(5),
    );
    canvas.drawRRect(
      pagesBottomRect,
      Paint()..color = const Color(0xFFFEF3C7),
    );
    canvas.restore();

    // 3. Top Book (Vibrant Sky Blue)
    canvas.save();
    canvas.translate(w * 0.50, h * 0.63);
    canvas.rotate(0.03);
    final topBookRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: w * 0.58, height: h * 0.15),
      const Radius.circular(8),
    );
    canvas.drawRRect(
      topBookRect.shift(const Offset(0, 3)),
      Paint()..color = Colors.black.withValues(alpha: 0.08),
    );
    canvas.drawRRect(
      topBookRect,
      Paint()..color = const Color(0xFF0284C7),
    );
    final pagesTopRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(-w * 0.26, -h * 0.05, w * 0.53, h * 0.10),
      const Radius.circular(5),
    );
    canvas.drawRRect(
      pagesTopRect,
      Paint()..color = const Color(0xFFF0F9FF),
    );
    canvas.restore();

    // 4. Glossy 3D Heart on top of the books
    canvas.save();
    canvas.translate(w * 0.50, h * 0.40);
    final heartPath = Path();
    final hw = w * 0.46;
    final hh = h * 0.38;
    heartPath.moveTo(0, hh * 0.35);
    // Left lobe
    heartPath.cubicTo(
      -hw * 0.55, -hh * 0.35,
      -hw * 0.55, hh * 0.55,
      0, hh * 0.95,
    );
    // Right lobe
    heartPath.cubicTo(
      hw * 0.55, hh * 0.55,
      hw * 0.55, -hh * 0.35,
      0, hh * 0.35,
    );

    // Heart soft drop shadow
    canvas.drawPath(
      heartPath.shift(const Offset(0, 4)),
      Paint()..color = Colors.black.withValues(alpha: 0.10),
    );

    // Heart rich 3D gradient
    final heartPaint = Paint()
      ..shader = const LinearGradient(
        colors: [
          Color(0xFFFB7185),
          Color(0xFFF43F5E),
          Color(0xFFE11D48),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(
        Rect.fromCenter(center: Offset.zero, width: hw, height: hh),
      );
    canvas.drawPath(heartPath, heartPaint);

    // Heart glossy highlight reflection on upper-left lobe
    canvas.save();
    canvas.rotate(-0.35);
    final highlightPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: 0.65),
          Colors.white.withValues(alpha: 0.0),
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(-hw * 0.20, -hh * 0.05),
          radius: hw * 0.25,
        ),
      );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(-hw * 0.20, -hh * 0.05),
        width: hw * 0.28,
        height: hh * 0.18,
      ),
      highlightPaint,
    );
    canvas.restore();

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Books Base Painter for other vocabulary items
class _BooksBasePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Bottom Book (Yellow/Orange)
    canvas.save();
    canvas.translate(w * 0.52, h * 0.82);
    canvas.rotate(-0.04);
    final bottomBookRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: w * 0.64, height: h * 0.16),
      const Radius.circular(8),
    );
    canvas.drawRRect(
      bottomBookRect.shift(const Offset(0, 4)),
      Paint()..color = Colors.black.withValues(alpha: 0.08),
    );
    canvas.drawRRect(
      bottomBookRect,
      Paint()..color = const Color(0xFFF59E0B),
    );
    final pagesBottomRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(-w * 0.29, -h * 0.055, w * 0.59, h * 0.11),
      const Radius.circular(5),
    );
    canvas.drawRRect(
      pagesBottomRect,
      Paint()..color = const Color(0xFFFEF3C7),
    );
    canvas.restore();

    // Top Book (Sky Blue)
    canvas.save();
    canvas.translate(w * 0.50, h * 0.70);
    canvas.rotate(0.03);
    final topBookRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: w * 0.58, height: h * 0.15),
      const Radius.circular(8),
    );
    canvas.drawRRect(
      topBookRect.shift(const Offset(0, 3)),
      Paint()..color = Colors.black.withValues(alpha: 0.08),
    );
    canvas.drawRRect(
      topBookRect,
      Paint()..color = const Color(0xFF0284C7),
    );
    final pagesTopRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(-w * 0.26, -h * 0.05, w * 0.53, h * 0.10),
      const Radius.circular(5),
    );
    canvas.drawRRect(
      pagesTopRect,
      Paint()..color = const Color(0xFFF0F9FF),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
