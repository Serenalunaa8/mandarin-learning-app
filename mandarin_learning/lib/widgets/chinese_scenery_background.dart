import 'package:flutter/material.dart';

class ChineseSceneryBackground extends StatelessWidget {
  final Widget child;
  final bool showPagoda;
  final bool showLanterns;
  final double opacity;

  const ChineseSceneryBackground({
    super.key,
    required this.child,
    this.showPagoda = true,
    this.showLanterns = true,
    this.opacity = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Background gradient
        Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFEAF8EA), // Soft mint
                Color(0xFFDCF5DC),
                Color(0xFFF3FAF2),
                Color(0xFFFFFFFF),
              ],
              stops: [0.0, 0.35, 0.7, 1.0],
            ),
          ),
        ),
        // Scenery CustomPaint
        Positioned.fill(
          child: Opacity(
            opacity: opacity,
            child: CustomPaint(
              painter: _ChineseSceneryPainter(
                showPagoda: showPagoda,
                showLanterns: showLanterns,
              ),
            ),
          ),
        ),
        // Content
        child,
      ],
    );
  }
}

class _ChineseSceneryPainter extends CustomPainter {
  final bool showPagoda;
  final bool showLanterns;

  _ChineseSceneryPainter({required this.showPagoda, required this.showLanterns});

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Distant Misty Hills
    final hillPaint1 = Paint()
      ..color = const Color(0xFFC7EBC8).withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;

    final path1 = Path();
    path1.moveTo(0, size.height * 0.35);
    path1.quadraticBezierTo(size.width * 0.25, size.height * 0.30, size.width * 0.5, size.height * 0.34);
    path1.quadraticBezierTo(size.width * 0.75, size.height * 0.38, size.width, size.height * 0.32);
    path1.lineTo(size.width, size.height);
    path1.lineTo(0, size.height);
    path1.close();
    canvas.drawPath(path1, hillPaint1);

    // 2. Closer Green Hills
    final hillPaint2 = Paint()
      ..color = const Color(0xFFB5E3B7).withValues(alpha: 0.6)
      ..style = PaintingStyle.fill;

    final path2 = Path();
    path2.moveTo(0, size.height * 0.42);
    path2.quadraticBezierTo(size.width * 0.35, size.height * 0.48, size.width * 0.7, size.height * 0.40);
    path2.quadraticBezierTo(size.width * 0.88, size.height * 0.36, size.width, size.height * 0.44);
    path2.lineTo(size.width, size.height);
    path2.lineTo(0, size.height);
    path2.close();
    canvas.drawPath(path2, hillPaint2);

    // 3. Pagoda Pavilion on the left hill
    if (showPagoda) {
      final pagodaPaint = Paint()
        ..color = const Color(0xFF5A8E5C).withValues(alpha: 0.35)
        ..style = PaintingStyle.fill;

      final px = size.width * 0.08;
      final py = size.height * 0.34;

      // Tier 1 roof
      final roof1 = Path();
      roof1.moveTo(px - 14, py);
      roof1.quadraticBezierTo(px, py - 4, px + 14, py);
      roof1.lineTo(px + 10, py - 6);
      roof1.quadraticBezierTo(px, py - 8, px - 10, py - 6);
      roof1.close();
      canvas.drawPath(roof1, pagodaPaint);

      // Pillars 1
      canvas.drawRect(Rect.fromLTWH(px - 8, py, 3, 8), pagodaPaint);
      canvas.drawRect(Rect.fromLTWH(px + 5, py, 3, 8), pagodaPaint);

      // Tier 2 roof
      final roof2 = Path();
      roof2.moveTo(px - 18, py + 8);
      roof2.quadraticBezierTo(px, py + 4, px + 18, py + 8);
      roof2.lineTo(px + 12, py + 2);
      roof2.quadraticBezierTo(px, py, px - 12, py + 2);
      roof2.close();
      canvas.drawPath(roof2, pagodaPaint);

      // Base
      canvas.drawRect(Rect.fromLTWH(px - 10, py + 8, 20, 10), pagodaPaint);
    }

    // 4. Floating Chinese Lanterns
    if (showLanterns) {
      _drawLantern(canvas, size.width * 0.14, size.height * 0.16, 12, 16);
      _drawLantern(canvas, size.width * 0.82, size.height * 0.18, 14, 18);
      _drawLantern(canvas, size.width * 0.88, size.height * 0.28, 10, 13);
    }
  }

  void _drawLantern(Canvas canvas, double x, double y, double w, double h) {
    final lanternPaint = Paint()
      ..color = const Color(0xFFFF8A65).withValues(alpha: 0.65)
      ..style = PaintingStyle.fill;

    // Lantern body
    canvas.drawOval(
      Rect.fromCenter(center: Offset(x, y), width: w, height: h),
      lanternPaint,
    );

    // Caps
    final capPaint = Paint()
      ..color = const Color(0xFFD84315).withValues(alpha: 0.75)
      ..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTWH(x - w * 0.25, y - h * 0.5 - 2, w * 0.5, 2.5), capPaint);
    canvas.drawRect(Rect.fromLTWH(x - w * 0.25, y + h * 0.5 - 0.5, w * 0.5, 2.5), capPaint);

    // Tassel
    final tasselPaint = Paint()
      ..color = const Color(0xFFE65100).withValues(alpha: 0.7)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(x, y + h * 0.5 + 2), Offset(x, y + h * 0.5 + 7), tasselPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
