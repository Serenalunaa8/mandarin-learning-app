import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'login_screen.dart';

/// Landing Page Onboarding Screen
/// Tampilan visual mengikuti referensi mockup:
/// - Bagian atas (~55%): Langit cerah, awan, bukit, maskot chibi di atas pedestal,
///   anak-anak mengintip dari semak, 6 lencana mengambang, dan tepi bukit
///   hijau tua bergelombang berlapis berbentuk segitiga terbalik.
/// - Bagian bawah: Kontainer hijau tua (#16300E) dengan tipografi, tombol CTA
///   "Start Learning", dan tautan navigasi ke "Log in".
class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _floatController;

  @override
  void initState() {
    super.initState();
    // Animasi mengambang halus untuk 6 lencana ikon
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _floatController.dispose();
    super.dispose();
  }

  void _onStartLearning(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
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
    final screenWidth = size.width;
    final screenHeight = size.height;

    // Proporsi tinggi area ilustrasi atas (~55% layar, termasuk tepi bergelombang)
    final topHeight = (screenHeight * 0.55).clamp(360.0, 520.0);

    // Tinggi area tepi bukit hijau tua bergelombang berlapis
    final scallopHeight = topHeight * 0.36;

    // Ukuran maskot (sekaligus dipakai untuk posisi tengah)
    final mascotWidth = (screenWidth * 0.41).clamp(140.0, 190.0);

    return Scaffold(
      backgroundColor: const Color(0xFF16300E), // Hijau tua solid sesuai mockup
      body: Stack(
        children: [
          // =========================================================
          // 1. ILUSTRASI ATAS (LANGIT, BUKIT, MASKOT, ANAK, IKON-IKON)
          // =========================================================
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: topHeight,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // 1A. Gradien Langit: biru muda -> hijau pucat
                Positioned.fill(
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: [0.0, 0.30, 0.65, 1.0],
                        colors: [
                          Color(0xFFA9DDF2), // Biru langit muda
                          Color(0xFFDDF0C4), // Transisi pucat
                          Color(0xFFD6EC9C), // Hijau kekuningan
                          Color(0xFFC4E38A), // Hijau muda bawah
                        ],
                      ),
                    ),
                  ),
                ),

                // 1B. Awan Kiri
                Positioned(
                  top: MediaQuery.of(context).padding.top + 10,
                  left: 0,
                  width: (screenWidth * 0.35).clamp(110.0, 160.0),
                  child: Image.asset(
                    'assets/image/landing_page/09_awan_kiri.png',
                    fit: BoxFit.contain,
                  ),
                ),

                // 1C. Awan Kanan
                Positioned(
                  top: MediaQuery.of(context).padding.top + 20,
                  right: 0,
                  width: (screenWidth * 0.25).clamp(80.0, 120.0),
                  child: Image.asset(
                    'assets/image/landing_page/10_awan_kanan.png',
                    fit: BoxFit.contain,
                  ),
                ),

                // 1D. Bukit Hijau (11_lahan_hijau.png)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Image.asset(
                    'assets/image/landing_page/11_lahan_hijau.png',
                    width: screenWidth,
                    fit: BoxFit.fitWidth,
                  ),
                ),

                // 1E. Maskot Chibi di atas Pedestal Emas (01_maskot.png)
                Positioned(
                  left: (screenWidth - mascotWidth) / 2,
                  bottom: topHeight * 0.25,
                  width: mascotWidth,
                  child: Image.asset(
                    'assets/image/landing_page/01_maskot.png',
                    fit: BoxFit.contain,
                  ),
                ),

                // 1F. Anak-anak Mengintip di Semak Kanan (08_anak_anak.png)
                Positioned(
                  right: -2,
                  bottom: topHeight * 0.16,
                  width: (screenWidth * 0.34).clamp(115.0, 165.0),
                  child: Image.asset(
                    'assets/image/landing_page/08_anak_anak.png',
                    fit: BoxFit.contain,
                  ),
                ),

                // 1G. 6 Lencana Ikon Mengambang + Bintang Berkilau (Sparkles)
                AnimatedBuilder(
                  animation: _floatController,
                  builder: (context, _) {
                    final floatVal = _floatController.value;
                    final dy1 = math.sin(floatVal * math.pi) * 5.0;
                    final dy2 = math.cos(floatVal * math.pi) * 4.5;
                    final dy3 = math.sin((floatVal + 0.5) * math.pi) * 4.0;
                    final badgeSize = (screenWidth * 0.125).clamp(42.0, 56.0);

                    // cx, cy = titik tengah lencana (proporsi lebar / tinggi area atas)
                    Widget badge(
                      String asset,
                      double cx,
                      double cy,
                      double dy,
                    ) {
                      return Positioned(
                        left: screenWidth * cx - badgeSize / 2,
                        top: topHeight * cy - badgeSize / 2 + dy,
                        width: badgeSize,
                        height: badgeSize,
                        child: Image.asset(asset, fit: BoxFit.contain),
                      );
                    }

                    Widget sparkle(double fx, double fy, double dy, double s) {
                      return Positioned(
                        left: screenWidth * fx,
                        top: topHeight * fy + dy,
                        child: _SparkleStar(size: s),
                      );
                    }

                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // Ikon 1: Jeruk Oranye (Kiri Atas)
                        badge(
                          'assets/image/landing_page/03_ikon_jeruk.png',
                          0.29,
                          0.39,
                          dy1,
                        ),

                        // Ikon 2: Panah Ungu Ganda (Kiri Tengah Luar)
                        badge(
                          'assets/image/landing_page/02_ikon_ungu_panah.png',
                          0.14,
                          0.48,
                          dy2,
                        ),

                        // Ikon 3: Bintang Pink (Kiri Bawah)
                        badge(
                          'assets/image/landing_page/05_ikon_pink_bintang.png',
                          0.29,
                          0.59,
                          dy3,
                        ),

                        // Ikon 4: Centang Kuning (Kanan Atas)
                        badge(
                          'assets/image/landing_page/04_ikon_kuning_centang.png',
                          0.755,
                          0.40,
                          dy2,
                        ),

                        // Ikon 5: Perisai Teal (Kanan Tengah Luar)
                        badge(
                          'assets/image/landing_page/06_ikon_teal_perisai_1.png',
                          0.86,
                          0.52,
                          dy1,
                        ),

                        // Ikon 6: Lonceng Biru (Kanan Bawah)
                        badge(
                          'assets/image/landing_page/07_ikon_teal_perisai_2.png',
                          0.72,
                          0.60,
                          dy3,
                        ),

                        // Sparkle Berkilau Kuning
                        sparkle(0.22, 0.42, dy3, 10),
                        sparkle(0.64, 0.37, dy1, 11),
                        sparkle(0.07, 0.56, dy2, 9),
                        sparkle(0.20, 0.66, dy1, 10),
                        sparkle(0.80, 0.66, dy2, 10),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),

          // =========================================================
          // 2. KARTU BAWAH (TEKS, CTA BUTTON, LOGIN LINK)
          // =========================================================
          Positioned(
            top: topHeight - 8,
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              color: const Color(0xFF16300E),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final compactLayout = constraints.maxHeight < 300;
                      return Column(
                        children: [
                          // Jarak aman agar teks berada rapi di bawah puncak lengkungan bukit
                          SizedBox(
                            height: compactLayout
                                ? 12
                                : (72 - 0.13 * scallopHeight + 14).clamp(
                                    56.0,
                                    74.0,
                                  ),
                          ),
                          if (compactLayout)
                            const SizedBox(height: 0)
                          else
                            const Spacer(flex: 1),

                          // Headline
                          Text(
                            'Learn Languages.\nLevel Up Your World.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: compactLayout ? 24 : 26,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              height: 1.25,
                              letterSpacing: -0.2,
                            ),
                          ),
                          SizedBox(height: compactLayout ? 6 : 10),

                          // Subtitle
                          const Text(
                            'Master new languages with fun lessons,\nreal conversations, and daily practice.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                              color: Color(0xFFB4C8AE),
                              height: 1.5,
                            ),
                          ),

                          if (compactLayout)
                            const SizedBox(height: 0)
                          else
                            const Spacer(flex: 2),

                          // CTA Button: "Start Learning" (efek 3D tepi bawah gelap)
                          Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(28),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0xFF2D8A1A),
                                  offset: Offset(0, 4),
                                  blurRadius: 0,
                                ),
                              ],
                            ),
                            child: SizedBox(
                              height: compactLayout ? 48 : 52,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF47B82A),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(28),
                                  ),
                                ),
                                onPressed: () => _onStartLearning(context),
                                child: const Text(
                                  'Start Learning',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: compactLayout ? 8 : 16),

                          // Footer Link: "Already have an account? Log in"
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                'Already have an account? ',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: Color(0xFF9DB596),
                                ),
                              ),
                              GestureDetector(
                                onTap: () => _onLogin(context),
                                child: const Text(
                                  'Log in',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF58D13A),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          // Ruang fleksibel bawah agar tombol dan teks login terangkat naik proporsional
                          if (compactLayout)
                            const SizedBox(height: 4)
                          else ...[
                            const Spacer(flex: 2),
                            const SizedBox(height: 12),
                          ],
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),

          // =========================================================
          // 3. TEPI BUKIT HIJAU TUA BERGELOMBANG BERLAPIS
          //    (segitiga terbalik, menimpa sambungan ilustrasi & kartu bawah)
          // =========================================================
          Positioned(
            top:
                topHeight -
                scallopHeight +
                72, // makin besar angka, makin turun
            left: 0,
            right: 0,
            height: scallopHeight,
            child: IgnorePointer(
              child: CustomPaint(painter: _ScallopedHillPainter()),
            ),
          ),
        ],
      ),
    );
  }
}

/// Empat lapis hijau tua bergelombang (scallop) membentuk segitiga terbalik:
/// tepi kiri-kanan tinggi, bagian tengah paling turun.
/// Lapis terakhir berwarna sama dengan kartu bawah agar menyatu.
class _ScallopedHillPainter extends CustomPainter {
  static const _colors = [
    Color(0xFF2F5E1E),
    Color(0xFF254D18),
    Color(0xFF1C3B12),
    Color(0xFF16300E),
  ];
  static const _bases = [0.02, 0.17, 0.32, 0.47]; // posisi y di tepi
  static const _bumps = [5, 4, 5, 4];
  static const _dip = 0.40; // seberapa dalam bagian tengah turun

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final steps = (w / 2).ceil();

    for (int i = 0; i < _colors.length; i++) {
      final path = Path();
      for (int s = 0; s <= steps; s++) {
        final x = w * s / steps;
        final t = x / w;

        // Bentuk segitiga terbalik: 0 di tepi, 1 di tengah
        final tri = 1 - (2 * t - 1).abs();

        final y =
            h * (_bases[i] + _dip * tri) -
            h * 0.05 * math.sin(_bumps[i] * math.pi * t).abs();

        if (s == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      path.lineTo(w, h);
      path.lineTo(0, h);
      path.close();

      canvas.drawPath(
        path,
        Paint()
          ..color = _colors[i]
          ..style = PaintingStyle.fill
          ..isAntiAlias = true,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Bintang berkilau 4 sudut dekoratif
class _SparkleStar extends StatelessWidget {
  final double size;

  const _SparkleStar({required this.size});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size(size, size), painter: _SparkleStarPainter());
  }
}

class _SparkleStarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFFF176).withValues(alpha: 0.95)
      ..style = PaintingStyle.fill;

    final cx = size.width / 2;
    final cy = size.height / 2;
    final rOut = size.width / 2;
    final rIn = rOut * 0.26;

    final path = Path();
    for (int i = 0; i < 8; i++) {
      final angle = (i * 45) * math.pi / 180 - math.pi / 2;
      final r = (i % 2 == 0) ? rOut : rIn;
      final x = cx + r * math.cos(angle);
      final y = cy + r * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
