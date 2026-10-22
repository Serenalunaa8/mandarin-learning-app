import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../core/constants/app_colors.dart';
import '../../models/vocabulary_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/audio_service.dart';
import '../../services/speech_evaluation_service.dart';
import '../../services/speech_recognition_settings_service.dart';
import '../../services/tone_analysis_service.dart';
import '../../widgets/mascot_widget.dart';

class SpeechPracticeScreen extends StatefulWidget {
  final VocabularyItem item;

  const SpeechPracticeScreen({super.key, required this.item});

  @override
  State<SpeechPracticeScreen> createState() => _SpeechPracticeScreenState();
}

class SpeechEvaluation {
  final String recognizedText;
  final double? recognitionConfidence;
  final int score;

  const SpeechEvaluation({
    required this.recognizedText,
    required this.recognitionConfidence,
    required this.score,
  });
}

class _SpeechPracticeScreenState extends State<SpeechPracticeScreen> {
  final SpeechToText _speech = SpeechToText();
  bool _isRecording = false;
  bool _isAnalyzing = false;
  int _recordSeconds = 0;
  Timer? _timer;
  SpeechEvaluation? _result;
  bool _hasRewarded = false;
  bool _isFinalizing = false;
  String _recognizedText = '';
  double? _recognitionConfidence;
  String? _recognitionError;
  bool _needsSpeechSetup = false;

  String _friendlySpeechError(String error) {
    final normalized = error.toLowerCase();
    if (normalized.contains('language') ||
        normalized.contains('locale') ||
        normalized.contains('bahasa')) {
      _needsSpeechSetup = true;
      return 'Layanan suara belum menyediakan bahasa Mandarin. Aktifkan atau unduh bahasa Mandarin pada layanan pengenalan suara perangkat.';
    }
    return error;
  }

  Future<void> _openSpeechSettings() async {
    final opened = await SpeechRecognitionSettingsService.openSettings();
    if (!mounted || opened) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Buka Pengaturan perangkat > Bahasa & masukan > Pengenalan suara. Pilih Google Speech Services dan unduh paket bahasa Mandarin.',
        ),
      ),
    );
  }

  Future<void> _playPronunciation() async {
    final played = await AudioService.instance.speak(widget.item.hanzi);
    if (!mounted || played) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Suara Mandarin belum tersedia. Periksa atau pasang suara Mandarin di pengaturan Text-to-speech perangkat.',
        ),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _speech.cancel();
    super.dispose();
  }

  double _soundLevel = 0.0;

  Future<void> _startRecording() async {
    setState(() {
      _isAnalyzing = true;
      _result = null;
      _recognitionError = null;
      _needsSpeechSetup = false;
      _recognizedText = '';
      _recognitionConfidence = null;
      _soundLevel = 0.0;
    });
    try {
      final available = await _speech.initialize(
        onError: (error) =>
            _finishRecognition(error: _friendlySpeechError(error.errorMsg)),
        onStatus: (status) {
          if (status == 'notListening' && _isRecording) {
            _finishRecognition();
          }
        },
      );
      if (!mounted) return;
      if (!available) {
        setState(() {
          _isAnalyzing = false;
          _needsSpeechSetup = true;
          _recognitionError = 'Pengenalan suara Mandarin tidak tersedia. Periksa izin mikrofon dan layanan suara perangkat.';
        });
        return;
      }

      final locales = await _speech.locales();
      final chineseLocales =
          locales
              .where(
                (locale) => locale.localeId
                    .toLowerCase()
                    .replaceAll('-', '_')
                    .startsWith('zh'),
              )
              .toList()
            ..sort((a, b) {
              int rank(String localeId) {
                final normalized = localeId.toLowerCase().replaceAll('-', '_');
                if (normalized == 'zh_cn' || normalized == 'cmn_cn') return 0;
                if (normalized.startsWith('zh_cn_') ||
                    normalized.startsWith('cmn_hans_cn')) {
                  return 1;
                }
                if (normalized.startsWith('zh_tw') ||
                    normalized.startsWith('zh_hk')) {
                  return 3;
                }
                return 2;
              }

              return rank(a.localeId).compareTo(rank(b.localeId));
            });
      final localeId = chineseLocales.isEmpty
          ? 'zh_CN'
          : chineseLocales.first.localeId;
      if (chineseLocales.isEmpty) _needsSpeechSetup = true;

      setState(() {
        _isRecording = true;
        _isAnalyzing = false;
        _recordSeconds = 0;
        _isFinalizing = false;
      });

      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) return;
        setState(() => _recordSeconds++);
      });
      await _speech.listen(
        onResult: (result) {
          _recognizedText = result.recognizedWords;
          _recognitionConfidence = result.hasConfidenceRating
              ? result.confidence
              : null;
          if (result.finalResult) _finishRecognition();
        },
        onSoundLevelChange: (level) {
          if (!mounted) return;
          setState(() => _soundLevel = level);
        },
        listenOptions: SpeechListenOptions(
          localeId: localeId,
          listenFor: const Duration(seconds: 8),
          pauseFor: const Duration(seconds: 2),
          partialResults: true,
          contextualPhrases: [widget.item.hanzi],
        ),
      );
    } catch (error) {
      debugPrint('[SpeechPractice] Recognition start failed: $error');
      if (!mounted) return;
      _timer?.cancel();
      setState(() {
        _isRecording = false;
        _isAnalyzing = false;
        _recognitionError = 'Pengenalan suara gagal dimulai. Periksa izin mikrofon dan layanan suara perangkat.';
      });
    }
  }

  Future<void> _stopRecording() async {
    try {
      if (_isRecording) await _speech.stop();
      await _finishRecognition();
    } catch (error) {
      debugPrint('[SpeechPractice] Recognition stop failed: $error');
      await _finishRecognition(
        error: 'Pengenalan suara gagal dihentikan. Coba mulai ulang latihan.',
      );
    }
  }

  Future<void> _finishRecognition({String? error}) async {
    if (_isFinalizing || (!_isRecording && !_isAnalyzing)) return;
    _isFinalizing = true;
    _timer?.cancel();
    if (mounted) {
      setState(() {
        _isRecording = false;
        _isAnalyzing = true;
        _soundLevel = 0.0;
      });
    }

    final similarity = error == null
        ? scoreMandarinTranscription(
            widget.item.hanzi,
            _recognizedText,
            targetPinyin: widget.item.pinyin,
          )
        : 0;
    final result = SpeechEvaluation(
      recognizedText: _recognizedText,
      recognitionConfidence: _recognitionConfidence,
      score: similarity,
    );
    if (!mounted) return;
    setState(() {
      _isAnalyzing = false;
      _result = error == null ? result : null;
      _recognitionError = error;
    });

    if (!_hasRewarded &&
        result.score >= 80 &&
        (result.recognitionConfidence == null ||
            result.recognitionConfidence! >= 0.7)) {
      _hasRewarded = true;
      final auth = context.read<AuthProvider>();
      await auth.addCoins(
        5,
        'speech_practice',
        'Latihan pelafalan: ${widget.item.hanzi} (${widget.item.pinyin})',
        attemptId:
            'speech_${widget.item.id}_${DateTime.now().millisecondsSinceEpoch}',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final tone = ToneAnalysisService.instance.detectToneFromPinyin(
      widget.item.pinyin,
    );

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
                        IconButton(
                          tooltip: 'Dengarkan pelafalan Mandarin',
                          onPressed: _playPronunciation,
                          icon: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.volume_up_rounded,
                              color: AppColors.primaryDark,
                              size: 26,
                            ),
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
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF166534),
                            ),
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
                        'Mengenali ucapan Mandarin...',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark,
                        ),
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
              if (_recognitionError != null) ...[
                const SizedBox(height: 12),
                Text(
                  _recognitionError!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.error, fontSize: 12),
                ),
                if (_needsSpeechSetup)
                  TextButton.icon(
                    onPressed: _openSpeechSettings,
                    icon: const Icon(Icons.settings_voice_rounded),
                    label: const Text('Atur bahasa Mandarin'),
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
                          color: _isRecording
                              ? AppColors.error
                              : AppColors.primary,
                          boxShadow: [
                            BoxShadow(
                              color:
                                  (_isRecording
                                          ? AppColors.error
                                          : AppColors.primary)
                                      .withValues(alpha: 0.35),
                              blurRadius: 16,
                              spreadRadius: _isRecording
                                  ? (4 + (_soundLevel * 1.5).clamp(0.0, 12.0))
                                  : 1,
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
                          ? 'Mendengarkan Mandarin... ($_recordSeconds dtk) • Ketuk untuk selesai'
                          : 'Ketuk mikrofon untuk melafalkan',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _isRecording
                            ? AppColors.error
                            : AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Catatan Transparansi Kebutuhan PRD 7 & 13
              const Center(
                child: Text(
                  'Penilaian mencocokkan transkripsi ASR, bukan mengukur nada atau kualitas aksen.',
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

  Widget _buildAnalysisResultCard(SpeechEvaluation res) {
    final confidence = res.recognitionConfidence;
    final advice = res.recognizedText.isEmpty
        ? 'Ucapan belum berhasil dikenali. Coba ucapkan lebih jelas di tempat yang lebih tenang.'
        : res.score == 100 && (confidence == null || confidence >= 0.8)
        ? 'Transkripsi cocok dengan target. Ini bukan penilaian ahli untuk nada atau aksen.'
        : res.score >= 70
        ? 'Sebagian ucapan cocok. Periksa karakter yang berbeda dan coba ulangi.'
        : 'Kurang tepat: hasil pengenalan belum cocok dengan target. Coba ucapkan kembali.';
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
          Text(
            'Kecocokan transkripsi: ${res.score}%',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Terdengar: ${res.recognizedText.isEmpty ? 'tidak terdeteksi' : res.recognizedText}',
            style: const TextStyle(fontSize: 18, color: AppColors.primaryDark),
          ),
          if (confidence != null) ...[
            const SizedBox(height: 4),
            Text(
              'Keyakinan pengenalan suara: ${(confidence * 100).round()}% (bukan skor pelafalan)',
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ],
          const SizedBox(height: 14),
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
                    advice,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF14532D),
                    ),
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
                Text(
                  '🎉 +5 Koin diperoleh dari latihan pelafalan!',
                  style: TextStyle(
                    color: AppColors.primaryDark,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
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
