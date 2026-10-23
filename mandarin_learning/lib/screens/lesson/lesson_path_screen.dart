import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../models/vocabulary_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/vocabulary_provider.dart';
import 'vocabulary_detail_screen.dart';
import '../auth/register_screen.dart';

class LessonPathScreen extends StatelessWidget {
  const LessonPathScreen({super.key});

  static const List<Map<String, dynamic>> lessonTopics = [
    {
      'unit': 1,
      'title': 'Huruf Hanyu Pinyin',
      'icon': Icons.menu_book_rounded,
      'status': 'completed',
    },
    {
      'unit': 2,
      'title': 'Salam dan Perkenalan',
      'icon': Icons.chat_bubble_outline_rounded,
      'status': 'completed',
    },
    {
      'unit': 3,
      'title': 'Angka dalam Bahasa Mandarin',
      'icon': Icons.pin_outlined,
      'status': 'active',
      'progress': 0.60,
    },
    {
      'unit': 4,
      'title': 'Kata Kerja Dasar',
      'icon': Icons.lock_outline_rounded,
      'status': 'locked',
    },
    {
      'unit': 5,
      'title': 'Kata Sifat',
      'icon': Icons.lock_outline_rounded,
      'status': 'locked',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final vocab = context.watch<VocabularyProvider>();
    final currentLevel = vocab.selectedLevel;
    final units = vocab.currentLevelUnits;

    // Guest mode: show full locked state
    if (auth.isGuest) {
      return Scaffold(
        backgroundColor: const Color(0xFFF1FAF3),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: () {
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              }
            },
          ),
          title: const Text('Jalur Pembelajaran'),
        ),
        body: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: Image.asset(
                  'assets/image/beranda/bg_siang.png',
                  fit: BoxFit.cover,
                ),
              ),
              const Positioned.fill(
                child: ColoredBox(color: Color(0xD9F4FBF4)),
              ),
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(28, 26, 28, 28),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.94),
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(color: const Color(0xFFD7F2DF)),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF276B43).withValues(alpha: 0.1),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          'assets/image/beranda/maskot_02_baca_buku.png',
                          height: 156,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE3F7E9),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'MODE TAMU',
                            style: TextStyle(
                              color: Color(0xFF25804A),
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Kursus Terkunci',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF173E2B),
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Kursus hanya tersedia untuk akun terdaftar. Daftar sekarang dan mulai perjalanan belajar Mandarin-mu!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF718278),
                            height: 1.55,
                          ),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF37A85B),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(28),
                              ),
                              elevation: 0,
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const RegisterScreen(),
                                ),
                              );
                            },
                            child: const Text(
                              'Daftar Sekarang',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
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

    return Scaffold(
      backgroundColor: const Color(0xFFF1FAF3),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF1FAF3),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () {
            // Jika ada pop konteks
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            }
          },
        ),
        title: const Text('Jalur Pembelajaran'),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                const Text('💎', style: TextStyle(fontSize: 13)),
                const SizedBox(width: 4),
                Text(
                  '${auth.coins}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              height: 156,
              margin: const EdgeInsets.fromLTRB(18, 4, 18, 12),
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFDDF8E6), Color(0xFFC4F0D1)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF27824B).withValues(alpha: 0.1),
                    blurRadius: 16,
                    offset: const Offset(0, 7),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: 0,
                    bottom: 0,
                    width: 230,
                    height: 95,
                    child: Opacity(
                      opacity: 0.34,
                      child: Image.asset(
                        'assets/image/beranda/bg_siang.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  Positioned(
                    right: 4,
                    bottom: -10,
                    child: Image.asset(
                      'assets/image/beranda/maskot_02_baca_buku.png',
                      width: 148,
                      height: 136,
                      fit: BoxFit.contain,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 17, 130, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        PopupMenuButton<int>(
                          padding: EdgeInsets.zero,
                          offset: const Offset(0, 40),
                          onSelected: (lvl) => vocab.setLevel(lvl),
                          itemBuilder: (ctx) => List.generate(6, (i) {
                            final l = i + 1;
                            return PopupMenuItem(
                              value: l,
                              child: Text('Ganti ke HSK $l'),
                            );
                          }),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 13,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFAEEBC0),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Level $currentLevel',
                                  style: const TextStyle(
                                    color: Color(0xFF17623A),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: Color(0xFF17623A),
                                  size: 18,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _getLevelSubtitle(currentLevel),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF14532D),
                            fontSize: 17,
                            height: 1.2,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Lesson List Cards
            Expanded(
              child: Stack(
                children: [
                  Positioned(
                    right: 0,
                    top: 28,
                    child: Opacity(
                      opacity: 0.28,
                      child: Image.asset(
                        'assets/image/beranda/awan_kecil.png',
                        width: 86,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    bottom: 12,
                    child: Opacity(
                      opacity: 0.75,
                      child: Image.asset(
                        'assets/image/beranda/semak_bunga_besar.png',
                        width: 90,
                      ),
                    ),
                  ),
                  ListView.builder(
                    padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
                    itemCount: lessonTopics.length,
                    itemBuilder: (context, index) {
                      final topic = lessonTopics[index];
                      final unitNum = topic['unit'] as int;
                      final title = topic['title'] as String;
                      final status = topic['status'] as String;
                      final double? progress = topic['progress'] as double?;

                      return _buildLessonCard(
                        context,
                        unitNum: unitNum,
                        title: title,
                        status: status,
                        progress: progress,
                        vocabItems: units[unitNum] ?? [],
                        reverse: index.isOdd,
                        onTap: () {
                          if (status == 'locked') {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Selesaikan pelajaran sebelumnya untuk membuka pelajaran ini.',
                                ),
                              ),
                            );
                            return;
                          }

                          vocab.setUnit(unitNum);
                          final items =
                              units[unitNum] ?? vocab.currentLevelVocabulary;
                          if (items.isNotEmpty) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    VocabularyDetailScreen(item: items.first),
                              ),
                            );
                          }
                        },
                      );
                    },
                  ),
                ],
              ),
            ),

            // Sticky Bottom Button "Lanjut ke Pelajaran 3"
            Container(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.94),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(26),
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF285C3B).withValues(alpha: 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF38A85D),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () {
                    vocab.setUnit(3);
                    final items = units[3] ?? vocab.currentLevelVocabulary;
                    if (items.isNotEmpty) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              VocabularyDetailScreen(item: items.first),
                        ),
                      );
                    }
                  },
                  child: const Text(
                    'Lanjut ke Pelajaran 3',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLessonCard(
    BuildContext context, {
    required int unitNum,
    required String title,
    required String status,
    double? progress,
    required List<VocabularyItem> vocabItems,
    required bool reverse,
    required VoidCallback onTap,
  }) {
    final isLocked = status == 'locked';
    final isCompleted = status == 'completed';
    final isActive = status == 'active';

    final icon = isLocked
        ? Icons.lock_rounded
        : unitNum == 1
        ? Icons.menu_book_rounded
        : unitNum == 2
        ? Icons.chat_bubble_rounded
        : Icons.pin_rounded;
    final nodeColor = isLocked
        ? const Color(0xFFB6C1CA)
        : const Color(0xFF37A853);
    final nodeSize = isActive ? 82.0 : 74.0;
    final leadingIcon = Container(
      width: nodeSize,
      height: nodeSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: isLocked
              ? const [Color(0xFFF8FAFC), Color(0xFFDCE4EA)]
              : const [Color(0xFF91E878), Color(0xFF35B553)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white, width: 5),
        boxShadow: [
          BoxShadow(
            color: nodeColor.withValues(alpha: isLocked ? 0.12 : 0.24),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (isActive)
            SizedBox(
              width: nodeSize,
              height: nodeSize,
              child: CircularProgressIndicator(
                value: progress ?? 0,
                strokeWidth: 3,
                backgroundColor: Colors.white.withValues(alpha: 0.45),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  Color(0xFF249F4B),
                ),
              ),
            ),
          Icon(
            icon,
            color: isLocked ? const Color(0xFF94A3B8) : Colors.white,
            size: isActive ? 34 : 30,
          ),
          if (isCompleted)
            Positioned(
              right: -2,
              bottom: -1,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  color: Color(0xFF38A85D),
                  shape: BoxShape.circle,
                  border: Border.fromBorderSide(
                    BorderSide(color: Colors.white, width: 2),
                  ),
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 15,
                ),
              ),
            ),
          if (isLocked)
            Positioned(
              right: -1,
              bottom: -1,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Color(0xFF8293A1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_rounded,
                  color: Colors.white,
                  size: 12,
                ),
              ),
            ),
        ],
      ),
    );

    Widget trailing;
    if (isCompleted) {
      trailing = const Icon(
        Icons.check_circle_rounded,
        color: Color(0xFF38A85D),
        size: 22,
      );
    } else if (isActive) {
      trailing = Container(
        width: 30,
        height: 30,
        decoration: const BoxDecoration(
          color: Color(0xFF38A85D),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.play_arrow_rounded,
          color: Colors.white,
          size: 20,
        ),
      );
    } else {
      trailing = const Icon(
        Icons.lock_outline_rounded,
        color: Color(0xFFB2BDC8),
        size: 20,
      );
    }

    final card = Container(
      constraints: const BoxConstraints(minHeight: 112),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: isActive ? const Color(0xFF9CE4A8) : Colors.white,
          width: isActive ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF306B46).withValues(alpha: 0.08),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(26),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isLocked
                            ? const Color(0xFFF0F3F6)
                            : const Color(0xFFE1F7E8),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        'Pelajaran $unitNum',
                        style: TextStyle(
                          fontSize: 10,
                          color: isLocked
                              ? const Color(0xFF8C9AA6)
                              : const Color(0xFF27834A),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.2,
                        fontWeight: FontWeight.w800,
                        color: isLocked
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF243849),
                      ),
                    ),
                    const SizedBox(height: 7),
                    if (isCompleted)
                      const Row(
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            color: Color(0xFF38A85D),
                            size: 15,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Selesai',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF38A85D),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      )
                    else if (isActive && progress != null)
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 7,
                                backgroundColor: const Color(0xFFE5ECE8),
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  Color(0xFF39AE5B),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 7),
                          Text(
                            '${(progress * 100).toInt()}%',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF527267),
                            ),
                          ),
                        ],
                      )
                    else if (isLocked)
                      const Row(
                        children: [
                          Icon(
                            Icons.lock_rounded,
                            color: Color(0xFF9AA8B4),
                            size: 14,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Terkunci',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF94A3B8),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              trailing,
            ],
          ),
        ),
      ),
    );

    return SizedBox(
      height: 142,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _LessonTrailPainter(reverse: reverse)),
          ),
          Center(
            child: Row(
              children: [
                if (!reverse) ...[leadingIcon, const SizedBox(width: 10)],
                Expanded(child: card),
                if (reverse) ...[const SizedBox(width: 10), leadingIcon],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getLevelSubtitle(int level) {
    switch (level) {
      case 1:
        return 'Dasar Bahasa Mandarin (150 Kata)';
      case 2:
        return 'Tingkat Percakapan Dasar (150 Kata)';
      case 3:
        return 'Tingkat Menengah Awal (300 Kata)';
      case 4:
        return 'Tingkat Menengah Lanjutan (600 Kata)';
      case 5:
        return 'Tingkat Mahir (1.300 Kata)';
      case 6:
        return 'Tingkat Fasih Profesional (2.500 Kata)';
      default:
        return 'Dasar Bahasa Mandarin';
    }
  }
}

class _LessonTrailPainter extends CustomPainter {
  final bool reverse;

  const _LessonTrailPainter({required this.reverse});

  @override
  void paint(Canvas canvas, Size size) {
    final nodeX = reverse ? size.width - 41 : 41.0;
    final otherX = reverse ? 41.0 : size.width - 41;
    final path = Path()
      ..moveTo(otherX, 0)
      ..cubicTo(otherX, 35, nodeX, 36, nodeX, size.height / 2)
      ..cubicTo(
        nodeX,
        size.height - 36,
        otherX,
        size.height - 35,
        otherX,
        size.height,
      );
    final outline = Paint()
      ..color = const Color(0xFFD9F5E2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 22
      ..strokeCap = StrokeCap.round;
    final trail = Paint()
      ..color = const Color(0xFFB7EBC7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, outline);
    canvas.drawPath(path, trail);
  }

  @override
  bool shouldRepaint(covariant _LessonTrailPainter oldDelegate) =>
      oldDelegate.reverse != reverse;
}
