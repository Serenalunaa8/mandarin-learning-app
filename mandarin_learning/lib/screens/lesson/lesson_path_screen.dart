import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
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
                  colors: [Color(0xFFD8F4DF), Color(0xFFB8E8C5)],
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
                    left: -20,
                    right: -20,
                    bottom: -10,
                    top: 0,
                    child: Opacity(
                      opacity: 0.45,
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
    const nodePalettes = [
      [Color(0xFFB39DDB), Color(0xFF673AB7)],
      [Color(0xFFFFB74D), Color(0xFFEF6C00)],
      [Color(0xFFFFE082), Color(0xFFF9A825)],
      [Color(0xFF81D4FA), Color(0xFF0288D1)],
      [Color(0xFFF48FB1), Color(0xFFC2185B)],
      [Color(0xFF80CBC4), Color(0xFF00897B)],
    ];
    final nodeGradientColors = isLocked
        ? const [Color(0xFFDCE5E8), Color(0xFF9EAFB8)]
        : nodePalettes[(unitNum - 1) % nodePalettes.length];
    final nodeColor = isLocked
        ? const Color(0xFF8B9BA6)
        : nodeGradientColors.last;
    final nodeSize = isActive ? 88.0 : 78.0;
    final node = Container(
      width: nodeSize,
      height: nodeSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: nodeGradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white, width: 4),
        boxShadow: [
          BoxShadow(
            color: nodeColor.withValues(alpha: isLocked ? 0.12 : 0.3),
            blurRadius: 18,
            offset: const Offset(0, 6),
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
                strokeWidth: 3.5,
                backgroundColor: Colors.white.withValues(alpha: 0.55),
                valueColor: AlwaysStoppedAnimation<Color>(nodeColor),
              ),
            ),
          Icon(
            icon,
            color: isLocked ? const Color(0xFFF8FAFC) : Colors.white,
            size: isActive ? 36 : 31,
          ),
          if (isCompleted)
            Positioned(
              right: -2,
              bottom: -1,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  color: Color(0xFF238B72),
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

    final statusLabel = isCompleted
        ? const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF258B72),
                size: 14,
              ),
              SizedBox(width: 4),
              Text(
                'Selesai',
                style: TextStyle(
                  fontSize: 11,
                  color: Color(0xFF258B72),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          )
        : isActive && progress != null
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.auto_awesome_rounded,
                color: Color(0xFFD28A24),
                size: 14,
              ),
              const SizedBox(width: 4),
              Text(
                '${(progress * 100).toInt()}% selesai',
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF9B6B22),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          )
        : isLocked
        ? const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_rounded, color: Color(0xFF80919C), size: 13),
              SizedBox(width: 4),
              Text(
                'Terkunci',
                style: TextStyle(
                  fontSize: 11,
                  color: Color(0xFF80919C),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          )
        : null;

    final lessonLabelColor = isLocked
        ? const Color(0xFF70828E)
        : isActive
        ? const Color(0xFF9A681B)
        : const Color(0xFF287A68);
    final lessonLabelBackground = isLocked
        ? const Color(0xFFE8EEF0)
        : isActive
        ? const Color(0xFFFFEDC5)
        : const Color(0xFFDDF2EB);

    final lessonNode = SizedBox(
      width: 210,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(28),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: lessonLabelBackground,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    'Pelajaran $unitNum',
                    style: TextStyle(
                      fontSize: 11,
                      color: lessonLabelColor,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                node,
                const SizedBox(height: 9),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.2,
                    fontWeight: FontWeight.w800,
                    color: isLocked
                        ? const Color(0xFF80919C)
                        : const Color(0xFF263F47),
                  ),
                ),
                if (statusLabel != null) ...[
                  const SizedBox(height: 5),
                  statusLabel,
                ],
              ],
            ),
          ),
        ),
      ),
    );

    return SizedBox(
      height: 220,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _LessonTrailPainter(reverse: reverse)),
          ),
          Positioned.fill(
            child: Align(
              alignment: reverse ? Alignment.centerRight : Alignment.centerLeft,
              child: lessonNode,
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
    final nodeX = reverse ? size.width * 0.70 : size.width * 0.30;
    final otherX = reverse ? size.width * 0.30 : size.width * 0.70;
    final path = Path()
      ..moveTo(otherX, 0)
      ..cubicTo(otherX, 42, nodeX, 42, nodeX, size.height * 0.43)
      ..cubicTo(
        nodeX,
        size.height - 36,
        otherX,
        size.height - 35,
        otherX,
        size.height,
      );
    final outline = Paint()
      ..color = const Color(0xFFE5F0E8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.round;
    final trail = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFB6DFC2), Color(0xFF9ED9C7), Color(0xFFB8D7E4)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Offset.zero & size)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 11
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, outline);
    canvas.drawPath(path, trail);
  }

  @override
  bool shouldRepaint(covariant _LessonTrailPainter oldDelegate) =>
      oldDelegate.reverse != reverse;
}
