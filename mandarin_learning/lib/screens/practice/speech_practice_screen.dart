import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../models/vocabulary_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/audio_service.dart';
import '../../services/tone_analysis_service.dart';
import '../../widgets/mascot_widget.dart';

class SpeechPracticeScreen extends StatefulWidget {
  final VocabularyItem item;

  const SpeechPracticeScreen({super.key, required this.item});

  @override
  State<SpeechPracticeScreen> createState() => _SpeechPracticeScreenState();
}

class _SpeechPracticeScreenState extends State<SpeechPracticeScreen> {
  bool _isRecording = false;
  bool _isAnalyzing = false;
  int _recordSeconds = 0;
  Timer? _timer;
  ToneContourResult? _result;
  bool _hasRewarded = false;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startRecording() {
    setState(() {
      _isRecording = true;
      _isAnalyzing = false;
      _recordSeconds = 0;
      _result = null;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        _recordSeconds++;
      });
      if (_recordSeconds >= 5) {
        _stopRecording();
      }
    });
  }

  void _stopRecording() async {
    _timer?.cancel();
    setState(() {
      _isRecording = false;
      _isAnalyzing = true;
    });

    // Simulasi analisis pemrosesan ASR dan Pitch F0
    await Future.delayed(const Duration(milliseconds: 900));

    if (!mounted) return;

    final result = ToneAnalysisService.instance.analyzePronunciation(
      pinyin: widget.item.pinyin,
      recordingDuration: Duration(seconds: _recordSeconds > 0 ? _recordSeconds : 1),
    );

    setState(() {
      _isAnalyzing = false;
      _result = result;
    });

    // Beri reward koin (FR-17: 5 koin untuk penyelesaian latihan pelafalan, 1 kali)
    if (!_hasRewarded && result.score > 0) {
      _hasRewarded = true;
      final auth = context.read<AuthProvider>();
      await auth.addCoins(
        5,
        'speech_practice',
        'Latihan pelafalan: ${widget.item.hanzi} (${widget.item.pinyin})',
        attemptId: 'speech_${widget.item.id}_${DateTime.now().millisecondsSinceEpoch}',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final tone = ToneAnalysisService.instance.detectToneFromPinyin(widget.item.pinyin);

    return Scaffold(
      backgroundColor: AppColors.mintBackground,
      appBar: AppBar(
        title: const Text('Latihan Pelafalan'),
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
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textDark),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Target Character Card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          widget.item.hanzi,
                          style: const TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(width: 16),
                        GestureDetector(
                          onTap: () => AudioService.instance.speak(widget.item.hanzi),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.volume_up_rounded, color: AppColors.primaryDark, size: 26),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.item.pinyin,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.item.artiIndonesia,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Panduan Pola Nada
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Row(
                  children: [
                    const Text('💡', style: TextStyle(fontSize: 20)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Target: ${_getToneTitle(tone)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Color(0xFF14532D),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _getToneRule(tone),
                            style: const TextStyle(fontSize: 12, color: Color(0xFF166534)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Hasil Analisis Kontur & Skor (FR-05)
              if (_isAnalyzing) ...[
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Column(
                    children: [
                      CircularProgressIndicator(color: AppColors.primary),
                      SizedBox(height: 16),
                      Text(
                        'Menganalisis frekuensi nada & ujaran...',
                        style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textDark),
                      ),
                    ],
                  ),
                ),
              ] else if (_result != null) ...[
                _buildAnalysisResultCard(_result!),
              ] else ...[
                // Ilustrasi Maskot Mendengarkan
                const Center(
                  child: MascotWidget(
                    size: 110,
                    pose: MascotPose.listening,
                    speechBubbleText: 'Dengarkan & Ucapkan!',
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Tombol Rekam Mikrofon (FR-04)
              Center(
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: _isAnalyzing
                          ? null
                          : _isRecording
                              ? _stopRecording
                              : _startRecording,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        width: _isRecording ? 90 : 80,
                        height: _isRecording ? 90 : 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isRecording ? AppColors.error : AppColors.primary,
                          boxShadow: [
                            BoxShadow(
                              color: (_isRecording ? AppColors.error : AppColors.primary).withValues(alpha: 0.35),
                              blurRadius: 16,
                              spreadRadius: _isRecording ? 4 : 1,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Icon(
                          _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                          color: Colors.white,
                          size: 38,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _isRecording
                          ? 'Merekam suara... ($_recordSeconds dtk) • Ketuk untuk selesai'
                          : 'Ketuk mikrofon untuk melafalkan',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _isRecording ? AppColors.error : AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Catatan Transparansi Kebutuhan PRD 7 & 13
              const Center(
                child: Text(
                  'Estimasi pembelajaran kontur nada, bukan sertifikasi ahli.',
                  style: TextStyle(fontSize: 11, color: AppColors.textLight),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnalysisResultCard(ToneContourResult res) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Evaluasi Kontur Nada',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark),
                  ),
                  Text(
                    res.toneName,
                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: res.score >= 80 ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '${res.score} / 100',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: res.score >= 80 ? const Color(0xFF15803D) : const Color(0xFFB45309),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Visualisasi Grafik Kontur Nada (Pitch Curve)
          Container(
            height: 120,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: CustomPaint(
              painter: _ToneContourGraphPainter(
                referenceCurve: res.referenceCurve,
                userCurve: res.userCurve,
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(width: 14, height: 3, color: const Color(0xFF0284C7)),
              const SizedBox(width: 6),
              const Text('Referensi Ideal', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
              const SizedBox(width: 18),
              Container(width: 14, height: 3, color: AppColors.primary),
              const SizedBox(width: 6),
              const Text('Suaramu', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
            ],
          ),
          const SizedBox(height: 14),

          // Saran / Feedback Text
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('📝', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    res.feedback,
                    style: const TextStyle(fontSize: 13, color: Color(0xFF14532D)),
                  ),
                ),
              ],
            ),
          ),
          if (_hasRewarded) ...[
            const SizedBox(height: 10),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('🎉 +5 Koin diperoleh dari latihan pelafalan!',
                    style: TextStyle(color: AppColors.primaryDark, fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _getToneTitle(MandarinTone tone) {
    switch (tone) {
      case MandarinTone.tone1:
        return 'Nada 1 (Datar Tinggi 5-5)';
      case MandarinTone.tone2:
        return 'Nada 2 (Naik 3-5)';
      case MandarinTone.tone3:
        return 'Nada 3 (Turun-Naik 2-1-4)';
      case MandarinTone.tone4:
        return 'Nada 4 (Turun Tajam 5-1)';
      case MandarinTone.neutral:
        return 'Nada Netral (Ringan 3)';
    }
  }

  String _getToneRule(MandarinTone tone) {
    switch (tone) {
      case MandarinTone.tone1:
        return 'Jaga nada suara tinggi dan stabil tanpa bergetar atau turun.';
      case MandarinTone.tone2:
        return 'Mulai dari sedang lalu naikkan intonasi ke atas dengan tegas.';
      case MandarinTone.tone3:
        return 'Turunkan nada ke rongga dada, lalu angkat suara ke atas di akhir.';
      case MandarinTone.tone4:
        return 'Hentakkan suara dari nada tinggi langsung meluncur turun ke rendah.';
      case MandarinTone.neutral:
        return 'Ucapkan singkat, rileks, dan ringan.';
    }
  }
}

class _ToneContourGraphPainter extends CustomPainter {
  final List<double> referenceCurve;
  final List<double> userCurve;

  _ToneContourGraphPainter({required this.referenceCurve, required this.userCurve});

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..strokeWidth = 1.0;

    // Gambar grid 5 baris nada (Chao scale 1 s.d. 5)
    for (int i = 1; i <= 5; i++) {
      final y = size.height - (i - 1) * (size.height / 4);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Reference curve (Biru)
    final refPaint = Paint()
      ..color = const Color(0xFF0284C7)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final refPath = Path();
    for (int i = 0; i < referenceCurve.length; i++) {
      final x = i * (size.width / (referenceCurve.length - 1));
      final val = referenceCurve[i]; // 1.0 - 5.0
      final y = size.height - ((val - 1.0) / 4.0) * size.height;
      if (i == 0) {
        refPath.moveTo(x, y);
      } else {
        refPath.lineTo(x, y);
      }
    }
    canvas.drawPath(refPath, refPaint);

    // User curve (Hijau cerah)
    final userPaint = Paint()
      ..color = const Color(0xFF22C55E)
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final userPath = Path();
    for (int i = 0; i < userCurve.length; i++) {
      final x = i * (size.width / (userCurve.length - 1));
      final val = userCurve[i];
      final y = size.height - ((val - 1.0) / 4.0) * size.height;
      if (i == 0) {
        userPath.moveTo(x, y);
      } else {
        userPath.lineTo(x, y);
      }
    }
    canvas.drawPath(userPath, userPaint);
  }

  @override
  bool shouldRepaint(covariant _ToneContourGraphPainter oldDelegate) => true;
}
