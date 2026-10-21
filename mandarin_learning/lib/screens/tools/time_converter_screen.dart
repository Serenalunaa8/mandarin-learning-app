import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../services/audio_service.dart';

// FR-13: Konversi Waktu (WIB, WITA, WIT, London dengan DST, CST / Beijing Time)
// PB-17: Mendukung komparasi 5 zona waktu & aturan British Summer Time (BST)

class TimeConverterScreen extends StatefulWidget {
  const TimeConverterScreen({super.key});

  @override
  State<TimeConverterScreen> createState() => _TimeConverterScreenState();
}

class _TimeConverterScreenState extends State<TimeConverterScreen> {
  late DateTime _currentTime;
  Timer? _timer;
  bool _isLiveTime = true;
  double _customHourOffset = 0; // offset in hours from current time if user slides

  @override
  void initState() {
    super.initState();
    _currentTime = DateTime.now().toUtc();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_isLiveTime && mounted) {
        setState(() {
          _currentTime = DateTime.now().toUtc();
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // Aturan London Daylight Saving Time (BST):
  // Dimulai Minggu terakhir Maret (01:00 UTC) s.d. Minggu terakhir Oktober (01:00 UTC)
  bool _isLondonDst(DateTime utcDate) {
    final year = utcDate.year;
    // Minggu terakhir Maret
    final lastSundayMarch = DateTime.utc(year, 3, 31);
    final marchDstStart = lastSundayMarch.subtract(Duration(days: lastSundayMarch.weekday % 7));

    // Minggu terakhir Oktober
    final lastSundayOct = DateTime.utc(year, 10, 31);
    final octDstEnd = lastSundayOct.subtract(Duration(days: lastSundayOct.weekday % 7));

    return utcDate.isAfter(marchDstStart) && utcDate.isBefore(octDstEnd);
  }

  DateTime _getTargetTime(int utcOffsetHours) {
    DateTime base = _currentTime;
    if (!_isLiveTime) {
      base = base.add(Duration(minutes: (_customHourOffset * 60).round()));
    }
    return base.add(Duration(hours: utcOffsetHours));
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  String _formatDate(DateTime dt) {
    const days = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
    return '${days[dt.weekday - 1]}, ${dt.day} ${months[dt.month - 1]}';
  }

  String _getMandarinPeriod(int hour) {
    if (hour >= 6 && hour < 12) return '早上 (Zǎoshang - Pagi)';
    if (hour >= 12 && hour < 14) return '中午 (Zhōngwǔ - Siang)';
    if (hour >= 14 && hour < 18) return '下午 (Xiàwǔ - Sore)';
    if (hour >= 18 && hour < 24) return '晚上 (Wǎnshang - Malam)';
    return '半夜 (Bànyè - Tengah Malam)';
  }

  @override
  Widget build(BuildContext context) {
    final nowUtc = _currentTime.add(Duration(minutes: (_customHourOffset * 60).round()));
    final isDst = _isLondonDst(nowUtc);
    final londonOffset = isDst ? 1 : 0;

    final wibTime = _getTargetTime(7);
    final witaTime = _getTargetTime(8);
    final witTime = _getTargetTime(9);
    final cstTime = _getTargetTime(8); // Beijing UTC+8
    final londonTime = _getTargetTime(londonOffset);

    return Scaffold(
      backgroundColor: AppColors.mintBackground,
      appBar: AppBar(
        title: const Text('Konversi Zona Waktu'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Beijing Time Spotlight (Primary Reference)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF14532D), Color(0xFF166534)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF14532D).withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Text('🇨🇳', style: TextStyle(fontSize: 22)),
                            SizedBox(width: 8),
                            Text(
                              'China Standard Time (CST)',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'UTC+8',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _formatTime(cstTime),
                      style: const TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_formatDate(cstTime)} • ${_getMandarinPeriod(cstTime.hour)}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFFBBF7D0),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Mode Realtime / Slider Simulasi
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _isLiveTime ? '⏱ Waktu Real-Time (Aktif)' : '🎚️ Simulasi Jam Khusus',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _isLiveTime = !_isLiveTime;
                              if (_isLiveTime) _customHourOffset = 0;
                            });
                          },
                          child: Text(_isLiveTime ? 'Ganti Manual' : 'Kembali Realtime'),
                        ),
                      ],
                    ),
                    if (!_isLiveTime) ...[
                      Slider(
                        value: _customHourOffset,
                        min: -12,
                        max: 12,
                        divisions: 24,
                        activeColor: AppColors.primaryGreen,
                        label: '${_customHourOffset >= 0 ? '+' : ''}${_customHourOffset.toInt()} Jam',
                        onChanged: (val) {
                          setState(() {
                            _customHourOffset = val;
                          });
                        },
                      ),
                      Text(
                        'Geser offset: ${_customHourOffset >= 0 ? '+' : ''}${_customHourOffset.toInt()} jam dari saat ini',
                        style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 4 Zona Lainnya
              const Text(
                'Perbandingan Zona Waktu Terkait',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 10),

              // 1. WIB
              _buildZoneCard(
                flag: '🇮🇩',
                title: 'WIB (Jakarta / Sumatra / Jawa)',
                utcLabel: 'UTC+7',
                diffFromCst: '-1 Jam dari Beijing',
                time: wibTime,
                color: const Color(0xFFEFF6FF),
              ),
              const SizedBox(height: 10),

              // 2. WITA
              _buildZoneCard(
                flag: '🇮🇩',
                title: 'WITA (Bali / Makassar)',
                utcLabel: 'UTC+8',
                diffFromCst: 'Sama persis dengan Beijing',
                time: witaTime,
                color: const Color(0xFFF0FDF4),
              ),
              const SizedBox(height: 10),

              // 3. WIT
              _buildZoneCard(
                flag: '🇮🇩',
                title: 'WIT (Maluku / Papua)',
                utcLabel: 'UTC+9',
                diffFromCst: '+1 Jam dari Beijing',
                time: witTime,
                color: const Color(0xFFFAF5FF),
              ),
              const SizedBox(height: 10),

              // 4. London
              _buildZoneCard(
                flag: '🇬🇧',
                title: 'London (Inggris)',
                utcLabel: isDst ? 'BST (UTC+1)' : 'GMT (UTC+0)',
                diffFromCst: isDst ? '-7 Jam dari Beijing (Summer Time)' : '-8 Jam dari Beijing (Winter)',
                time: londonTime,
                color: const Color(0xFFFFFBEB),
                badge: isDst ? 'Daylight Saving Aktif' : 'Standard Time',
              ),
              const SizedBox(height: 24),

              // Mandarin Time Terms
              const Text(
                'Kosakata Waktu Bahasa Mandarin',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 10),

              _buildVocabTile(hanzi: '现在几点？', pinyin: 'Xiànzài jǐ diǎn?', arti: 'Sekarang jam berapa?'),
              const SizedBox(height: 8),
              _buildVocabTile(hanzi: '时区', pinyin: 'Shíqū', arti: 'Zona waktu'),
              const SizedBox(height: 8),
              _buildVocabTile(hanzi: '北京时间', pinyin: 'Běijīng shíjiān', arti: 'Waktu Beijing (CST)'),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildZoneCard({
    required String flag,
    required String title,
    required String utcLabel,
    required String diffFromCst,
    required DateTime time,
    required Color color,
    String? badge,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(flag, style: const TextStyle(fontSize: 22)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    Text(
                      utcLabel,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _formatTime(time),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  diffFromCst,
                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
                if (badge != null) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      badge,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF92400E),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVocabTile({
    required String hanzi,
    required String pinyin,
    required String arti,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      hanzi,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      pinyin,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                  ],
                ),
                Text(arti, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.volume_up_rounded, color: AppColors.primaryDark),
            onPressed: () => AudioService.instance.speak(hanzi),
          ),
        ],
      ),
    );
  }
}
