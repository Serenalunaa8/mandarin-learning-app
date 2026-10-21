import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../home/main_navigation_screen.dart';
import 'login_screen.dart';
import 'register_screen.dart';

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  void _onStartLearning(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Mulai Petualangan Belajar 🐼',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Pilih cara masukmu untuk memulai materi HSK 1–6:',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
            const SizedBox(height: 20),

            // Opsi 1: Daftar Akun Baru (Disimpan ke Cloud)
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.person_add_alt_1_rounded, color: Colors.white),
                label: const Text(
                  'Daftar Akun Baru',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF22C55E),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                  elevation: 0,
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RegisterScreen()),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),

            // Opsi 2: Coba Mode Tamu (Tanpa Akun)
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.flash_on_rounded, color: Color(0xFF15803D)),
                label: const Text(
                  'Coba Cepat (Mode Tamu)',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF15803D),
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF86EFAC), width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                ),
                onPressed: () async {
                  Navigator.pop(ctx);
                  final auth = context.read<AuthProvider>();
                  await auth.loginAsGuest();
                  if (context.mounted) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onLogin(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final topHeight = size.height * 0.52;

    return Scaffold(
      backgroundColor: const Color(0xFF0C2B14), // Deep forest green
      body: Stack(
        children: [
          // Top Half: Sunny Grassland, Hills, Mascot, Pedestal & Floating Badges
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: topHeight + 50,
            child: CustomPaint(
              painter: _LandingSceneryPainter(),
              child: const SizedBox.expand(),
            ),
          ),

          // Bottom Half: Deep Forest Green Card Content
          Positioned(
            top: topHeight,
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              color: const Color(0xFF0C2B14),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    children: [
                      const Spacer(flex: 1),

                      // Headline: "Learn Languages. Level Up Your World."
                      const Text(
                        'Learn Languages.\nLevel Up Your World.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 27,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.22,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Subtitle: "Master new languages with fun lessons, real conversations, and daily practice."
                      const Text(
                        'Master new languages with fun lessons,\nreal conversations, and daily practice.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w400,
                          color: Color(0xFFA5C4AC),
                          height: 1.45,
                        ),
                      ),

                      const Spacer(flex: 2),

                      // CTA Button: "Start Learning"
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF22C55E), // Vibrant lime green
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shadowColor: const Color(0x6022C55E),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                          ),
                          onPressed: () => _onStartLearning(context),
                          child: const Text(
                            'Start Learning',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Footer: "Already have an account? Log in"
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Already have an account? ',
                            style: TextStyle(
                              fontSize: 13.5,
                              color: Color(0xFF8BAE93),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => _onLogin(context),
                            child: const Text(
                              'Log in',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF4ADE80), // Bright green
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),
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
}

/// CustomPainter yang menggambar pemandangan lengkap:
/// 1. Langit cerah kuning-kehijauan dengan awan halus.
/// 2. Perbukitan hijau bertingkat dengan pepohonan.
/// 3. Jalan setapak batu (stepping stones path).
/// 4. Podium/pedestal emas 3D.
/// 5. Maskot katak/panda hijau chibi yang menggemaskan dengan tunas di kepala & lidah melet.
/// 6. 6 Lencana gamifikasi melayang (Oranye, Ungu ⏩, Pink ⭐, Kuning Emas ✓, Toska 🛡️, Biru 🔔) + kilauan bintang.
/// 7. 4 Anak-anak ceria yang mengintip dari balik semak kanan.
/// 8. Transisi kurva kanopi bergelombang (scalloped green canopy) pemisah pemandangan dengan kartu bawah.
class _LandingSceneryPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 1. Sky Gradient
    final skyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFFEBF7E2),
          Color(0xFFE3F4D7),
          Color(0xFFD6F0C5),
          Color(0xFFC7EBB2),
        ],
        stops: [0.0, 0.35, 0.7, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, w, h * 0.7));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), skyPaint);

    // 2. Soft Fluffy Clouds in Sky
    final cloudPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.55)
      ..style = PaintingStyle.fill;

    _drawCloud(canvas, cloudPaint, w * 0.15, h * 0.12, 36);
    _drawCloud(canvas, cloudPaint, w * 0.82, h * 0.08, 42);
    _drawCloud(canvas, cloudPaint, w * 0.65, h * 0.18, 28);

    // 3. Distant Rolling Green Hills & Trees
    final hillBackPaint = Paint()
      ..color = const Color(0xFF9FD684)
      ..style = PaintingStyle.fill;
    final pathHill1 = Path()
      ..moveTo(0, h * 0.46)
      ..quadraticBezierTo(w * 0.25, h * 0.38, w * 0.55, h * 0.44)
      ..quadraticBezierTo(w * 0.8, h * 0.50, w, h * 0.42)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(pathHill1, hillBackPaint);

    // Background Tree Tufts
    final treePaint = Paint()
      ..color = const Color(0xFF7CBF5D)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(w * 0.08, h * 0.40), 22, treePaint);
    canvas.drawCircle(Offset(w * 0.18, h * 0.38), 28, treePaint);
    canvas.drawCircle(Offset(w * 0.88, h * 0.38), 26, treePaint);
    canvas.drawCircle(Offset(w * 0.96, h * 0.39), 20, treePaint);

    // Midground Hill
    final hillMidPaint = Paint()
      ..color = const Color(0xFF86CC67)
      ..style = PaintingStyle.fill;
    final pathHill2 = Path()
      ..moveTo(0, h * 0.52)
      ..quadraticBezierTo(w * 0.4, h * 0.44, w, h * 0.50)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(pathHill2, hillMidPaint);

    // 4. Stepping Stones Path leading to Pedestal
    final stonePaint = Paint()
      ..color = const Color(0xFFE8DEB5)
      ..style = PaintingStyle.fill;
    final stoneShadow = Paint()
      ..color = const Color(0xFFB5A97D).withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;

    final stones = [
      Offset(w * 0.32, h * 0.57),
      Offset(w * 0.38, h * 0.54),
      Offset(w * 0.44, h * 0.52),
      Offset(w * 0.50, h * 0.51),
      Offset(w * 0.56, h * 0.52),
      Offset(w * 0.62, h * 0.54),
    ];
    for (var s in stones) {
      canvas.drawOval(Rect.fromCenter(center: Offset(s.dx, s.dy + 2), width: 22, height: 12), stoneShadow);
      canvas.drawOval(Rect.fromCenter(center: s, width: 22, height: 11), stonePaint);
    }

    // 5. 3D Golden Pedestal / Podium
    final pedestalCenter = Offset(w * 0.5, h * 0.435);
    const pedWidth = 110.0;
    const pedHeight = 30.0;
    const pedDepth = 22.0;

    // Pedestal Front Cylinder 3D body
    final pedBodyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFFBBF24), Color(0xFFD97706)],
      ).createShader(Rect.fromLTWH(pedCenterX(w, pedWidth), pedestalCenter.dy, pedWidth, pedDepth));

    final pedBodyPath = Path()
      ..moveTo(pedCenterX(w, pedWidth), pedestalCenter.dy)
      ..lineTo(pedCenterX(w, pedWidth), pedestalCenter.dy + pedDepth)
      ..quadraticBezierTo(w * 0.5, pedestalCenter.dy + pedDepth + 14, pedCenterRight(w, pedWidth), pedestalCenter.dy + pedDepth)
      ..lineTo(pedCenterRight(w, pedWidth), pedestalCenter.dy)
      ..close();
    canvas.drawPath(pedBodyPath, pedBodyPaint);

    // Pedestal Top Ellipse
    final pedTopPaint = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0xFFFDE68A), Color(0xFFF59E0B)],
      ).createShader(Rect.fromCenter(center: pedestalCenter, width: pedWidth, height: pedHeight));
    canvas.drawOval(Rect.fromCenter(center: pedestalCenter, width: pedWidth, height: pedHeight), pedTopPaint);

    // 6. Cute Chibi Green Mascot standing on Pedestal
    _drawCuteMascot(canvas, Offset(w * 0.5, pedestalCenter.dy - 12));

    // 7. Floating 3D Gamified Badges
    // 1. Top-Left: Orange Citrus / Spoke
    _drawBadge(
      canvas: canvas,
      center: Offset(w * 0.29, h * 0.22),
      radius: 20,
      gradientColors: [const Color(0xFFFDBA74), const Color(0xFFEA580C)],
      icon: '🍊',
    );

    // 2. Far-Left: Purple ⏩
    _drawBadge(
      canvas: canvas,
      center: Offset(w * 0.14, h * 0.27),
      radius: 22,
      gradientColors: [const Color(0xFFC084FC), const Color(0xFF7E22CE)],
      icon: '⏩',
    );

    // 3. Bottom-Left: Hot Pink ⭐
    _drawBadge(
      canvas: canvas,
      center: Offset(w * 0.28, h * 0.33),
      radius: 19,
      gradientColors: [const Color(0xFFF472B6), const Color(0xFFDB2777)],
      icon: '⭐',
    );

    // 4. Top-Right: Golden Amber ✓
    _drawBadge(
      canvas: canvas,
      center: Offset(w * 0.74, h * 0.23),
      radius: 20,
      gradientColors: [const Color(0xFFFCD34D), const Color(0xFFD97706)],
      icon: '✓',
      isTextIcon: true,
    );

    // 5. Far-Right: Teal / Cyan Shield 🛡️
    _drawBadge(
      canvas: canvas,
      center: Offset(w * 0.86, h * 0.29),
      radius: 22,
      gradientColors: [const Color(0xFF2DD4BF), const Color(0xFF0F766E)],
      icon: '🛡️',
    );

    // 6. Middle-Right: Light Blue Bell 🔔
    _drawBadge(
      canvas: canvas,
      center: Offset(w * 0.72, h * 0.34),
      radius: 19,
      gradientColors: [const Color(0xFF60A5FA), const Color(0xFF2563EB)],
      icon: '🔔',
    );

    // Sparkles
    _drawSparkle(canvas, Offset(w * 0.23, h * 0.25), const Color(0xFFA855F7), 6);
    _drawSparkle(canvas, Offset(w * 0.76, h * 0.27), const Color(0xFFC084FC), 5);
    _drawSparkle(canvas, Offset(w * 0.36, h * 0.16), const Color(0xFFFBBF24), 5);

    // 8. Peeking Kids on Bottom-Right
    _drawPeekingKids(canvas, Offset(w * 0.80, h * 0.44));

    // 9. Multi-layered Scalloped Canopy Curves (Connecting into bottom dark forest green)
    final scallopPaintBack = Paint()
      ..color = const Color(0xFF1B4D25)
      ..style = PaintingStyle.fill;
    final scallopBack = Path()
      ..moveTo(0, h * 0.58)
      ..quadraticBezierTo(w * 0.12, h * 0.54, w * 0.25, h * 0.57)
      ..quadraticBezierTo(w * 0.38, h * 0.53, w * 0.50, h * 0.58)
      ..quadraticBezierTo(w * 0.65, h * 0.54, w * 0.78, h * 0.57)
      ..quadraticBezierTo(w * 0.90, h * 0.53, w, h * 0.58)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(scallopBack, scallopPaintBack);

    final scallopPaintFront = Paint()
      ..color = const Color(0xFF0C2B14)
      ..style = PaintingStyle.fill;
    final scallopFront = Path()
      ..moveTo(0, h * 0.62)
      ..quadraticBezierTo(w * 0.15, h * 0.57, w * 0.30, h * 0.62)
      ..quadraticBezierTo(w * 0.45, h * 0.56, w * 0.58, h * 0.61)
      ..quadraticBezierTo(w * 0.72, h * 0.56, w * 0.85, h * 0.60)
      ..quadraticBezierTo(w * 0.94, h * 0.57, w, h * 0.62)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(scallopFront, scallopPaintFront);
  }

  double pedCenterX(double w, double pw) => (w - pw) / 2;
  double pedCenterRight(double w, double pw) => (w + pw) / 2;

  void _drawCloud(Canvas canvas, Paint paint, double x, double y, double radius) {
    canvas.drawCircle(Offset(x, y), radius, paint);
    canvas.drawCircle(Offset(x + radius * 0.8, y + radius * 0.1), radius * 0.75, paint);
    canvas.drawCircle(Offset(x - radius * 0.7, y + radius * 0.15), radius * 0.65, paint);
  }

  void _drawCuteMascot(Canvas canvas, Offset bottomCenter) {
    final cx = bottomCenter.dx;
    final cy = bottomCenter.dy;

    // Body dimensions
    const headRadius = 40.0;
    final headCenter = Offset(cx, cy - 58);

    // Mascot Body (Chubby green)
    final bodyPaint = Paint()
      ..color = const Color(0xFF3CD052)
      ..style = PaintingStyle.fill;

    // Feet
    final footPaint = Paint()..color = const Color(0xFF28B73E);
    canvas.drawOval(Rect.fromCenter(center: Offset(cx - 18, cy - 2), width: 22, height: 14), footPaint);
    canvas.drawOval(Rect.fromCenter(center: Offset(cx + 18, cy - 2), width: 22, height: 14), footPaint);

    // Body torso
    canvas.drawOval(Rect.fromCenter(center: Offset(cx, cy - 22), width: 56, height: 44), bodyPaint);

    // Belly (White patch)
    final bellyPaint = Paint()..color = Colors.white;
    canvas.drawOval(Rect.fromCenter(center: Offset(cx, cy - 20), width: 34, height: 28), bellyPaint);

    // Arms
    canvas.drawOval(Rect.fromCenter(center: Offset(cx - 28, cy - 26), width: 14, height: 26), bodyPaint);
    canvas.drawOval(Rect.fromCenter(center: Offset(cx + 28, cy - 26), width: 14, height: 26), bodyPaint);

    // Green Ears on Hood
    final earPaint = Paint()..color = const Color(0xFF28B73E);
    canvas.drawCircle(Offset(cx - 30, headCenter.dy - 32), 12, earPaint);
    canvas.drawCircle(Offset(cx + 30, headCenter.dy - 32), 12, earPaint);

    // Head (Green Hoodie)
    canvas.drawCircle(headCenter, headRadius, bodyPaint);

    // Sprout on top
    final sproutPaint = Paint()
      ..color = const Color(0xFF1E822E)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(cx, headCenter.dy - headRadius), Offset(cx, headCenter.dy - headRadius - 10), sproutPaint);

    final leafPaint = Paint()..color = const Color(0xFF3CD052);
    canvas.drawOval(Rect.fromCenter(center: Offset(cx - 6, headCenter.dy - headRadius - 11), width: 12, height: 7), leafPaint);
    canvas.drawOval(Rect.fromCenter(center: Offset(cx + 6, headCenter.dy - headRadius - 11), width: 12, height: 7), leafPaint);

    // Cream Face inside Hood
    final facePaint = Paint()..color = const Color(0xFFFFF7ED);
    canvas.drawOval(Rect.fromCenter(center: Offset(headCenter.dx, headCenter.dy + 4), width: 62, height: 50), facePaint);

    // Rosy Pink Cheeks
    final cheekPaint = Paint()..color = const Color(0xFFFCA5A5);
    canvas.drawCircle(Offset(headCenter.dx - 22, headCenter.dy + 12), 7, cheekPaint);
    canvas.drawCircle(Offset(headCenter.dx + 22, headCenter.dy + 12), 7, cheekPaint);

    // Cute mischievous eyes
    final eyePaint = Paint()
      ..color = const Color(0xFF1F2937)
      ..style = PaintingStyle.fill;
    // Left eye (slanted mischievous)
    final eyeStroke = Paint()
      ..color = const Color(0xFF1F2937)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final leftEyebrow = Path()
      ..moveTo(headCenter.dx - 20, headCenter.dy - 3)
      ..lineTo(headCenter.dx - 8, headCenter.dy);
    canvas.drawPath(leftEyebrow, eyeStroke);
    canvas.drawCircle(Offset(headCenter.dx - 14, headCenter.dy + 4), 3.5, eyePaint);

    // Right eye
    final rightEyebrow = Path()
      ..moveTo(headCenter.dx + 8, headCenter.dy)
      ..lineTo(headCenter.dx + 20, headCenter.dy - 3);
    canvas.drawPath(rightEyebrow, eyeStroke);
    canvas.drawCircle(Offset(headCenter.dx + 14, headCenter.dy + 4), 3.5, eyePaint);

    // Little Tongue sticking out! 👅
    final tonguePaint = Paint()..color = const Color(0xFFF43F5E);
    final tonguePath = Path()
      ..moveTo(headCenter.dx - 5, headCenter.dy + 15)
      ..quadraticBezierTo(headCenter.dx, headCenter.dy + 24, headCenter.dx + 5, headCenter.dy + 15)
      ..close();
    canvas.drawPath(tonguePath, tonguePaint);
  }

  void _drawBadge({
    required Canvas canvas,
    required Offset center,
    required double radius,
    required List<Color> gradientColors,
    required String icon,
    bool isTextIcon = false,
  }) {
    // Drop shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.15)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(Offset(center.dx, center.dy + 4), radius, shadowPaint);

    // Outer Badge Circle
    final badgePaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.4),
        colors: gradientColors,
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, badgePaint);

    // Glossy Highlight on top edge
    final highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 2),
      math.pi * 1.1,
      math.pi * 0.8,
      false,
      highlightPaint,
    );

    // Icon in Badge
    final tp = TextPainter(
      text: TextSpan(
        text: icon,
        style: TextStyle(
          fontSize: isTextIcon ? radius * 1.1 : radius * 0.95,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy - tp.height / 2));
  }

  void _drawSparkle(Canvas canvas, Offset c, Color color, double radius) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(c.dx, c.dy - radius)
      ..quadraticBezierTo(c.dx, c.dy, c.dx + radius, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy + radius)
      ..quadraticBezierTo(c.dx, c.dy, c.dx - radius, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy - radius)
      ..close();
    canvas.drawPath(path, paint);
  }

  void _drawPeekingKids(Canvas canvas, Offset base) {
    // 4 cute kids heads peeking from behind the bushes
    final skinLight = Paint()..color = const Color(0xFFFDDEC2);
    final skinWarm = Paint()..color = const Color(0xFFE8B28B);
    final hairDark = Paint()..color = const Color(0xFF332014);
    final hairCurly = Paint()..color = const Color(0xFF1E140F);
    final glassesPaint = Paint()
      ..color = const Color(0xFF2563EB)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    // Kid 1: Blue Glasses Boy
    final k1 = Offset(base.dx - 32, base.dy);
    canvas.drawCircle(k1, 14, skinLight);
    canvas.drawArc(Rect.fromCircle(center: k1, radius: 15), math.pi, math.pi, true, hairDark);
    canvas.drawCircle(Offset(k1.dx - 5, k1.dy + 1), 4, glassesPaint);
    canvas.drawCircle(Offset(k1.dx + 5, k1.dy + 1), 4, glassesPaint);
    canvas.drawLine(Offset(k1.dx - 1, k1.dy + 1), Offset(k1.dx + 1, k1.dy + 1), glassesPaint);

    // Kid 2: Girl with Curly Hair in center
    final k2 = Offset(base.dx + 2, base.dy - 10);
    canvas.drawCircle(k2, 16, skinLight);
    canvas.drawCircle(Offset(k2.dx - 14, k2.dy - 4), 8, hairCurly);
    canvas.drawCircle(Offset(k2.dx + 14, k2.dy - 4), 8, hairCurly);
    canvas.drawArc(Rect.fromCircle(center: k2, radius: 17), math.pi, math.pi, true, hairCurly);

    // Kid 3: Warm tone smiling boy
    final k3 = Offset(base.dx + 10, base.dy + 6);
    canvas.drawCircle(k3, 14, skinWarm);
    canvas.drawArc(Rect.fromCircle(center: k3, radius: 14), math.pi, math.pi, true, hairDark);

    // Cute eyes & smiles for all peeking kids
    final eyeP = Paint()..color = const Color(0xFF1E1E1E);
    canvas.drawCircle(Offset(k2.dx - 5, k2.dy + 1), 2, eyeP);
    canvas.drawCircle(Offset(k2.dx + 5, k2.dy + 1), 2, eyeP);
    canvas.drawCircle(Offset(k3.dx - 4, k3.dy + 2), 2, eyeP);
    canvas.drawCircle(Offset(k3.dx + 4, k3.dy + 2), 2, eyeP);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
