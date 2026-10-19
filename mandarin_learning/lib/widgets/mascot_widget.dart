import 'dart:math' as math;
import 'package:flutter/material.dart';

enum MascotPose {
  waving,
  holdingSign,
  headOnly,
  studying,
  listening,
  celebrating,
}

class MascotWidget extends StatelessWidget {
  final double size;
  final MascotPose pose;
  final String? signText;
  final String? speechBubbleText;

  const MascotWidget({
    super.key,
    this.size = 120,
    this.pose = MascotPose.waving,
    this.signText,
    this.speechBubbleText,
  });

  @override
  Widget build(BuildContext context) {
    Widget mascot = CustomPaint(
      size: Size(size, size),
      painter: _MascotPainter(pose: pose, signText: signText),
    );

    if (speechBubbleText != null && speechBubbleText!.isNotEmpty) {
      return Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          mascot,
          Positioned(
            top: -16,
            right: -24,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
                border: Border.all(color: const Color(0xFF86EFAC), width: 1.5),
              ),
              child: Text(
                speechBubbleText!,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Color(0xFF14532D),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return mascot;
  }
}

class _MascotPainter extends CustomPainter {
  final MascotPose pose;
  final String? signText;

  _MascotPainter({required this.pose, this.signText});

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 120.0;
    canvas.save();
    canvas.scale(scale);

    const greenMain = Color(0xFF67B938);
    const greenDark = Color(0xFF4C9127);
    const greenLight = Color(0xFFA3DE72);
    const earInner = Color(0xFFD4F4B8);
    const faceWhite = Color(0xFFFFFFFF);
    const blushPink = Color(0xFFFF8FA3);
    const eyeBlack = Color(0xFF1E293B);

    final pMain = Paint()..color = greenMain..style = PaintingStyle.fill;
    final pDark = Paint()..color = greenDark..style = PaintingStyle.fill;
    final pLight = Paint()..color = greenLight..style = PaintingStyle.fill;
    final pEarInner = Paint()..color = earInner..style = PaintingStyle.fill;
    final pFace = Paint()..color = faceWhite..style = PaintingStyle.fill;
    final pBlush = Paint()..color = blushPink.withValues(alpha: 0.8)..style = PaintingStyle.fill;
    final pEye = Paint()..color = eyeBlack..style = PaintingStyle.fill;
    final pWhite = Paint()..color = Colors.white..style = PaintingStyle.fill;
    final pLine = Paint()
      ..color = greenDark
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    if (pose != MascotPose.headOnly) {
      // Body
      final bodyRect = RRect.fromRectAndRadius(
        const Rect.fromLTWH(36, 68, 48, 44),
        const Radius.circular(24),
      );
      canvas.drawRRect(bodyRect, pMain);

      // Belly patch
      final bellyRect = RRect.fromRectAndRadius(
        const Rect.fromLTWH(44, 76, 32, 30),
        const Radius.circular(16),
      );
      canvas.drawRRect(bellyRect, pEarInner);

      // Legs / Feet
      canvas.drawOval(const Rect.fromLTWH(34, 102, 22, 14), pDark);
      canvas.drawOval(const Rect.fromLTWH(64, 102, 22, 14), pDark);

      // Arms depending on pose
      if (pose == MascotPose.waving) {
        // Left arm down
        canvas.drawOval(const Rect.fromLTWH(26, 76, 16, 20), pMain);
        // Right arm waving up high!
        canvas.save();
        canvas.translate(92, 60);
        canvas.rotate(-math.pi / 4);
        canvas.drawOval(const Rect.fromLTWH(-8, -16, 18, 28), pMain);
        // Small paw tip
        canvas.drawCircle(const Offset(1, -16), 7, pLight);
        canvas.restore();
      } else if (pose == MascotPose.holdingSign) {
        // Both paws forward holding a sign
        // Draw sign behind paws
        final signRRect = RRect.fromRectAndRadius(
          const Rect.fromLTWH(28, 70, 64, 38),
          const Radius.circular(10),
        );
        final signPaint = Paint()..color = const Color(0xFFDCFCE7)..style = PaintingStyle.fill;
        final signBorder = Paint()
          ..color = const Color(0xFF22C55E)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;
        canvas.drawRRect(signRRect, signPaint);
        canvas.drawRRect(signRRect, signBorder);

        if (signText != null && signText!.isNotEmpty) {
          final tp = TextPainter(
            text: TextSpan(
              text: signText,
              style: TextStyle(
                color: const Color(0xFF14532D),
                fontSize: signText!.length > 2 ? 14 : 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            textDirection: TextDirection.ltr,
          );
          tp.layout();
          tp.paint(canvas, Offset(60 - tp.width / 2, 89 - tp.height / 2));
        }

        // Paws clamping the sign
        canvas.drawCircle(const Offset(28, 86), 8, pMain);
        canvas.drawCircle(const Offset(92, 86), 8, pMain);
      } else if (pose == MascotPose.celebrating) {
        // Both arms raised up high!
        canvas.drawOval(const Rect.fromLTWH(20, 52, 18, 26), pMain);
        canvas.drawOval(const Rect.fromLTWH(82, 52, 18, 26), pMain);
      } else {
        // Resting arms
        canvas.drawOval(const Rect.fromLTWH(26, 76, 16, 20), pMain);
        canvas.drawOval(const Rect.fromLTWH(78, 76, 16, 20), pMain);
      }
    }

    // Offset for head if headOnly
    final headCenter = pose == MascotPose.headOnly ? const Offset(60, 60) : const Offset(60, 48);

    // Ears
    // Left ear
    canvas.drawCircle(Offset(headCenter.dx - 30, headCenter.dy - 26), 16, pMain);
    canvas.drawCircle(Offset(headCenter.dx - 30, headCenter.dy - 26), 9, pEarInner);
    // Right ear
    canvas.drawCircle(Offset(headCenter.dx + 30, headCenter.dy - 26), 16, pMain);
    canvas.drawCircle(Offset(headCenter.dx + 30, headCenter.dy - 26), 9, pEarInner);

    // Head Base
    canvas.drawCircle(headCenter, 34, pMain);

    // Face White Patch
    final faceRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(headCenter.dx, headCenter.dy + 6), width: 52, height: 42),
      const Radius.circular(22),
    );
    canvas.drawRRect(faceRect, pFace);

    // Sprout on top of head! (Cute two little green leaves)
    final sproutPath = Path();
    sproutPath.moveTo(headCenter.dx, headCenter.dy - 34);
    sproutPath.quadraticBezierTo(headCenter.dx - 2, headCenter.dy - 44, headCenter.dx, headCenter.dy - 48);
    final pStem = Paint()
      ..color = const Color(0xFF22C55E)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(sproutPath, pStem);

    // Left leaf
    canvas.save();
    canvas.translate(headCenter.dx - 1, headCenter.dy - 48);
    canvas.rotate(-0.6);
    final leftLeaf = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(-8, -4, -10, 0)
      ..quadraticBezierTo(-8, 4, 0, 0);
    canvas.drawPath(leftLeaf, Paint()..color = const Color(0xFF4ADE80));
    canvas.restore();

    // Right leaf
    canvas.save();
    canvas.translate(headCenter.dx + 1, headCenter.dy - 48);
    canvas.rotate(0.6);
    final rightLeaf = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(8, -4, 10, 0)
      ..quadraticBezierTo(8, 4, 0, 0);
    canvas.drawPath(rightLeaf, Paint()..color = const Color(0xFF22C55E));
    canvas.restore();

    // Eyes
    // Left eye
    canvas.drawCircle(Offset(headCenter.dx - 13, headCenter.dy + 2), 5, pEye);
    canvas.drawCircle(Offset(headCenter.dx - 14.5, headCenter.dy), 1.8, pWhite);
    // Right eye
    canvas.drawCircle(Offset(headCenter.dx + 13, headCenter.dy + 2), 5, pEye);
    canvas.drawCircle(Offset(headCenter.dx + 11.5, headCenter.dy), 1.8, pWhite);

    // Blush Cheeks
    canvas.drawOval(
      Rect.fromCenter(center: Offset(headCenter.dx - 18, headCenter.dy + 12), width: 10, height: 6),
      pBlush,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(headCenter.dx + 18, headCenter.dy + 12), width: 10, height: 6),
      pBlush,
    );

    // Cute Nose & Snout
    canvas.drawCircle(Offset(headCenter.dx, headCenter.dy + 7), 3, Paint()..color = const Color(0xFF14532D));

    // Happy smiling mouth
    final mouthPath = Path();
    mouthPath.moveTo(headCenter.dx - 5, headCenter.dy + 13);
    mouthPath.quadraticBezierTo(headCenter.dx, headCenter.dy + 17, headCenter.dx + 5, headCenter.dy + 13);
    canvas.drawPath(mouthPath, pLine);

    // Headphones if listening
    if (pose == MascotPose.listening) {
      final hpBand = Path()
        ..moveTo(headCenter.dx - 32, headCenter.dy)
        ..quadraticBezierTo(headCenter.dx, headCenter.dy - 40, headCenter.dx + 32, headCenter.dy);
      canvas.drawPath(
        hpBand,
        Paint()
          ..color = const Color(0xFF0284C7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4,
      );
      // Ear cups
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(headCenter.dx - 32, headCenter.dy), width: 10, height: 18),
          const Radius.circular(5),
        ),
        Paint()..color = const Color(0xFF38BDF8),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(headCenter.dx + 32, headCenter.dy), width: 10, height: 18),
          const Radius.circular(5),
        ),
        Paint()..color = const Color(0xFF38BDF8),
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _MascotPainter oldDelegate) {
    return oldDelegate.pose != pose || oldDelegate.signText != signText;
  }
}
