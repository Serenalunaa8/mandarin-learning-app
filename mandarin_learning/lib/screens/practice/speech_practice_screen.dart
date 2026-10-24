import 'dart:async';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../core/constants/app_colors.dart';
import '../../models/vocabulary_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/audio_service.dart';
import '../../services/speech_evaluation_service.dart';
import '../../services/speech_recognition_settings_service.dart';
import '../../services/tone_analysis_service.dart';
import '../../widgets/mascot_widget.dart';
import '../../widgets/in_app_notification.dart';

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
  final AudioRecorder _audioRecorder = AudioRecorder();

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
  bool _hasVoiceActivity = false;
  StreamSubscription<Amplitude>? _amplitudeSub;

  @override
  void initState() {
    super.initState();
    _preInitSpeech();
  }

  Future<void> _preInitSpeech() async {
    try {
      // 1. Minta runtime permission mikrofon via permission_handler & AudioRecorder
      await Permission.microphone.request();
      await _audioRecorder.hasPermission();

      // 2. Inisialisasi engine SpeechToText
      await _speech.initialize(
        onError: (error) {
          debugPrint('[SpeechPractice] preInit onError: ${error.errorMsg}');
        },
        onStatus: (status) {
          debugPrint('[SpeechPractice] preInit onStatus: $status');
        },
      );
    } catch (e) {
      debugPrint('[SpeechPractice] preInit exception: $e');
    }
  }

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
    _amplitudeSub?.cancel();
    _audioRecorder.dispose();
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
      _hasVoiceActivity = false;
    });

    try {
      // 1. Pastikan izin mikrofon telah diberikan
      final micPermission = await Permission.microphone.request();
      if (micPermission.isPermanentlyDenied) {
        setState(() {
          _isAnalyzing = false;
          _recognitionError = 'Izin mikrofon ditolak permanen. Silakan aktifkan di Pengaturan aplikasi.';
        });
        return;
      }
      if (!micPermission.isGranted) {
        final hasMicPermission = await _audioRecorder.hasPermission();
        if (!hasMicPermission) {
          setState(() {
            _isAnalyzing = false;
            _recognitionError = 'Izin mikrofon diperlukan untuk merekam pelafalan Anda.';
          });
          return;
        }
      }

      bool available = _speech.isAvailable;
      if (!available) {
        available = await _speech.initialize(
          onError: (error) {
            debugPrint('[SpeechPractice] onError: ${error.errorMsg}');
            final msg = error.errorMsg.toLowerCase();
            if (msg.contains('no_match') || msg.contains('7')) {
              // Suara terdengar tetapi tidak ada kata yang cocok dengan target (pengucapan salah / tidak cocok)
              _finishRecognition();
            } else if (msg.contains('timeout') || msg.contains('6')) {
              // Hening / tidak ada suara yang ditangkap
              _hasVoiceActivity = false;
              _finishRecognition();
            } else {
              _finishRecognition(error: _friendlySpeechError(error.errorMsg));
            }
          },
          onStatus: (status) {
            debugPrint('[SpeechPractice] onStatus: $status');
            if (status == 'notListening' && _isRecording) {
              Future.delayed(const Duration(milliseconds: 700), () {
                if (mounted && _isRecording) {
                  _finishRecognition();
                }
              });
            }
          },
        );
      }

      final locales = await _speech.locales();
      String? localeId;
      final chineseLocales = locales.where((locale) {
        final id = locale.localeId.toLowerCase().replaceAll('-', '_');
        return id.startsWith('zh') || id.startsWith('cmn');
      }).toList();

      if (chineseLocales.isNotEmpty) {
        chineseLocales.sort((a, b) {
          int rank(String id) {
            final n = id.toLowerCase().replaceAll('-', '_');
            if (n == 'zh_cn' || n == 'cmn_cn') return 0;
            if (n.startsWith('zh_cn') || n.startsWith('cmn_hans')) return 1;
            return 2;
          }
          return rank(a.localeId).compareTo(rank(b.localeId));
        });
        localeId = chineseLocales.first.localeId;
      } else {
        localeId = null;
      }

      setState(() {
        _isRecording = true;
        _isAnalyzing = false;
        _recordSeconds = 0;
        _isFinalizing = false;
      });

      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) return;
        setState(() => _recordSeconds++);
      });

      await _speech.listen(
        onResult: (result) {
          if (!mounted) return;
          setState(() {
            _recognizedText = result.recognizedWords;
            _recognitionConfidence = result.hasConfidenceRating
                ? result.confidence
                : null;
            if (_recognizedText.trim().isNotEmpty) {
              _hasVoiceActivity = true;
            }
          });
          if (result.finalResult && _recognizedText.trim().isNotEmpty) {
            _finishRecognition();
          }
        },
        onSoundLevelChange: (level) {
          if (!mounted) return;
          setState(() {
            _soundLevel = level;
            // RMS dB level dari Android RecognitionListener berkisar antara -2.0 s.d 10.0+
            if (level > 0.1) {
              _hasVoiceActivity = true;
            }
          });
        },
        listenOptions: SpeechListenOptions(
          localeId: localeId,
          listenFor: const Duration(seconds: 10),
          pauseFor: const Duration(milliseconds: 1800),
          partialResults: true,
          cancelOnError: false,
          listenMode: ListenMode.confirmation,
        ),
      );
    } catch (error) {
      debugPrint('[SpeechPractice] Recognition start failed: $error');
      if (!mounted) return;
      _timer?.cancel();
      setState(() {
        _isRecording = false;
        _isAnalyzing = false;
        _recognitionError = 'Pengenalan suara gagal dimulai. Pastikan izin mikrofon telah diberikan.';
      });
    }
  }

  Future<void> _stopRecording() async {
    try {
      if (_isRecording) {
        await _speech.stop();
        await Future.delayed(const Duration(milliseconds: 350));
      }
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
    _amplitudeSub?.cancel();

    if (mounted) {
      setState(() {
        _isRecording = false;
        _isAnalyzing = true;
        _soundLevel = 0.0;
      });
    }

    final rawText = (_recognizedText.trim().isNotEmpty
        ? _recognizedText
        : _speech.lastRecognizedWords).trim();

    int calculatedScore = 0;
    String finalText = rawText;
    String? finalError = error;

    if (rawText.isNotEmpty) {
      // 1. Teks ucapan nyata berhasil dikenali oleh mikrofon ASR
      calculatedScore = scoreMandarinTranscription(
        widget.item.hanzi,
        rawText,
        targetPinyin: widget.item.pinyin,
        confidence: _recognitionConfidence,
      );
      finalText = rawText;
      finalError = null;
    } else if (_hasVoiceActivity && _recordSeconds >= 1) {
      // 2. Suara nyata pengguna terdeteksi mikrofon, tetapi pengucapan tidak cocok dengan target
      // (error_no_match atau pelafalan keliru). Seperti Duolingo, ini divalidasi sebagai Kurang Tepat (skor rendah), BUKAN 96%!
      calculatedScore = 25;
      finalText = 'Pelafalan tidak cocok / kurang jelas';
      finalError = null;
    } else {
      // 3. Hening total / mikrofon belum menangkap suara pengguna
      calculatedScore = 0;
      finalText = '';
    }

    final result = SpeechEvaluation(
      recognizedText: finalText,
      recognitionConfidence: _recognitionConfidence,
      score: calculatedScore,
    );

    if (!mounted) return;
    setState(() {
      _isAnalyzing = false;
      _result = result;
      _recognitionError = finalError;
    });

    if (!_hasRewarded && result.score >= 80) {
      _hasRewarded = true;
      final auth = context.read<AuthProvider>();
      await auth.addCoins(
        5,
        'speech_practice',
        'Latihan pelafalan: ${widget.item.hanzi} (${widget.item.pinyin})',
        attemptId:
            'speech_${widget.item.id}_${DateTime.now().millisecondsSinceEpoch}',
      );
      if (mounted) {
        InAppNotification.showReward(
          context,
          title: '🎉 Pelafalan Tepat! (${result.score}%)',
          message:
              'Hebat! Pelafalan "${widget.item.hanzi}" berhasil divalidasi • +5 Koin!',
          score: result.score,
          coins: 5,
        );
      }
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

              // Hasil Analisis Validasi & Skor
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
                        'Memvalidasi pelafalan Mandarin...',
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
                        width: _isRecording ? 92 : 82,
                        height: _isRecording ? 92 : 82,
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
                              blurRadius: 18,
                              spreadRadius: _isRecording
                                  ? (4 + (_soundLevel * 1.5).clamp(0.0, 14.0))
                                  : 2,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Icon(
                          _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _isRecording
                          ? (_recognizedText.isNotEmpty
                              ? '🎙️ Terdengar: "$_recognizedText" • Ketuk untuk selesai'
                              : (_hasVoiceActivity
                                  ? '🎙️ Suara terdeteksi... ($_recordSeconds dtk) • Ucapkan kata'
                                  : 'Mendengarkan... Silakan ucapkan ($_recordSeconds dtk)'))
                          : 'Ketuk mikrofon untuk melafalkan',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _isRecording
                            ? (_hasVoiceActivity ? const Color(0xFF15803D) : AppColors.error)
                            : AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Catatan Transparansi
              const Center(
                child: Text(
                  'Penilaian memvalidasi kecocokan pelafalan lisan terhadap target Mandarin.',
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

  void _showManualPronunciationDialog() {
    final controller = TextEditingController(text: widget.item.pinyin);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tes Evaluasi Pelafalan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Masukkan kata Pinyin atau Hanzi yang kamu lafalkan untuk diuji:',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: 'Contoh: ni hao',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              final typed = controller.text.trim();
              if (typed.isNotEmpty) {
                final score = scoreMandarinTranscription(
                  widget.item.hanzi,
                  typed,
                  targetPinyin: widget.item.pinyin,
                  confidence: 1.0,
                );
                setState(() {
                  _result = SpeechEvaluation(
                    recognizedText: typed,
                    recognitionConfidence: 1.0,
                    score: score,
                  );
                });
              }
            },
            child: const Text('Evaluasi'),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisResultCard(SpeechEvaluation res) {
    final bool isEmpty = res.score == 0 && res.recognizedText.trim().isEmpty;
    final bool isCorrect = !isEmpty && res.score >= 80;
    final bool isPartial = !isEmpty && !isCorrect && res.score >= 50;

    final Color scoreColor = isEmpty
        ? AppColors.textMuted
        : isCorrect
            ? const Color(0xFF15803D)
            : isPartial
                ? const Color(0xFFB45309)
                : AppColors.error;
    final Color scoreBg = isEmpty
        ? const Color(0xFFF1F5F9)
        : isCorrect
            ? const Color(0xFFF0FDF4)
            : isPartial
                ? const Color(0xFFFFFBEB)
                : const Color(0xFFFEF2F2);
    final String statusIcon = isEmpty
        ? '🔇'
        : isCorrect
            ? '✅'
            : isPartial
                ? '⚠️'
                : '❌';
    final String statusLabel = isEmpty
        ? 'Suara Belum Terdeteksi'
        : isCorrect
            ? 'Pelafalan Benar'
            : isPartial
                ? 'Hampir Tepat'
                : 'Pelafalan Kurang Tepat';

    return Container(
      padding: const EdgeInsets.all(22),
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
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Badge status validasi
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            decoration: BoxDecoration(
              color: scoreBg,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: scoreColor.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(statusIcon, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Text(
                  statusLabel,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: scoreColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Skor lingkaran besar (langsung persentase cth: 90%)
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 100,
                height: 100,
                child: CircularProgressIndicator(
                  value: res.score / 100,
                  strokeWidth: 9,
                  backgroundColor: scoreBg,
                  color: scoreColor,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${res.score}%',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                      color: scoreColor,
                    ),
                  ),
                  Text(
                    'Tingkat Validasi',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: scoreColor.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),

          if (isEmpty) ...[
            const Text(
              'Mikrofon belum menangkap suara.\nSilakan dekatkan suara ke mikrofon lalu ucapkan kata Mandarin dengan jelas.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _showManualPronunciationDialog,
              icon: const Icon(Icons.keyboard_alt_outlined, size: 16),
              label: const Text(
                'Uji Input Pelafalan Alternatif',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ] else ...[
            // Kotak Transparansi Suara Nyata (seperti Duolingo)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Target Kata:', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                      Text(
                        '${widget.item.hanzi} (${widget.item.pinyin})',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textDark),
                      ),
                    ],
                  ),
                  const Divider(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Terdengar oleh Aplikasi:', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                      Flexible(
                        child: Text(
                          res.recognizedText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isCorrect
                                ? const Color(0xFF15803D)
                                : (isPartial ? const Color(0xFFB45309) : AppColors.error),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: scoreBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: scoreColor.withValues(alpha: 0.2)),
              ),
              child: Text(
                isCorrect
                    ? 'Luar biasa! Pelafalan kamu sudah sesuai (${res.score}%).'
                    : isPartial
                        ? 'Hampir tepat (${res.score}%). Perhatikan kembali intonasi dan pengucapan kata.'
                        : 'Pelafalan belum sesuai (${res.score}%). Kata yang terdeteksi berbeda dengan target. Dengarkan audio contoh lalu coba lagi.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: scoreColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],

          if (_hasRewarded) ...[
            const SizedBox(height: 12),
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