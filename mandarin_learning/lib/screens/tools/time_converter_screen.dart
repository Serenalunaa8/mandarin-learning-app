import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

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
  double _customHourOffset =
      0; // offset in hours from current time if user slides
  String _sourceZoneId = 'WIB';
  String _targetZoneId = 'China';

  List<_TimeZoneOption> get _zones => [
    _TimeZoneOption(
      id: 'WIB',
      name: 'WIB · Jakarta',
      subname: 'Jawa, Sumatra, Kalbar',
      flag: '🇮🇩',
      accentColor: const Color(0xFF0284C7),
      offsetAt: (_) => 7,
    ),
    _TimeZoneOption(
      id: 'WITA',
      name: 'WITA · Bali',
      subname: 'Bali, Sulawesi, NTT, NTB',
      flag: '🇮🇩',
      accentColor: const Color(0xFF0D9488),
      offsetAt: (_) => 8,
    ),
    _TimeZoneOption(
      id: 'WIT',
      name: 'WIT · Papua',
      subname: 'Maluku & Papua',
      flag: '🇮🇩',
      accentColor: const Color(0xFF7C3AED),
      offsetAt: (_) => 9,
    ),
    _TimeZoneOption(
      id: 'China',
      name: 'CST · Beijing',
      subname: 'Seluruh Wilayah Tiongkok',
      flag: '🇨🇳',
      accentColor: const Color(0xFFDC2626),
      offsetAt: (_) => 8,
    ),
    _TimeZoneOption(
      id: 'London',
      name: 'London · Inggris',
      subname: 'Britania Raya (UK)',
      flag: '🇬🇧',
      accentColor: const Color(0xFFD97706),
      offsetAt: (utc) => _isLondonDst(utc) ? 1 : 0,
    ),
  ];

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
    final marchSunday = DateTime.utc(year, 3, 31);
    final octoberSunday = DateTime.utc(year, 10, 31);
    final bstStarts = DateTime.utc(year, 3, 31 - (marchSunday.weekday % 7), 1);
    final bstEnds = DateTime.utc(year, 10, 31 - (octoberSunday.weekday % 7), 1);
    return !utcDate.isBefore(bstStarts) && utcDate.isBefore(bstEnds);
  }

  _TimeZoneOption _zone(String id) =>
      _zones.firstWhere((zone) => zone.id == id, orElse: () => _zones.first);

  DateTime _timeInZone(DateTime utc, _TimeZoneOption zone) =>
      utc.add(Duration(hours: zone.offsetAt(utc)));

  String _utcLabel(DateTime utc, _TimeZoneOption zone) {
    final offset = zone.offsetAt(utc);
    final sign = offset >= 0 ? '+' : '-';
    return 'UTC$sign${offset.abs().toString().padLeft(2, '0')}:00';
  }

  void _swapZones() {
    setState(() {
      final previousSource = _sourceZoneId;
      _sourceZoneId = _targetZoneId;
      _targetZoneId = previousSource;
    });
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
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    return '${days[dt.weekday - 1]}, ${dt.day} ${months[dt.month - 1]}';
  }

  String _getMandarinPeriod(int hour) {
    if (hour >= 6 && hour < 12) return '早上 (Zǎoshang · Pagi)';
    if (hour >= 12 && hour < 14) return '中午 (Zhōngwǔ · Siang)';
    if (hour >= 14 && hour < 18) return '下午 (Xiàwǔ · Sore)';
    if (hour >= 18 && hour < 24) return '晚上 (Wǎnshang · Malam)';
    return '半夜 (Bànyè · Tengah Malam)';
  }

  String _getTimeDiffText(
    _TimeZoneOption source,
    _TimeZoneOption target,
    DateTime utc,
  ) {
    final srcOffset = source.offsetAt(utc);
    final tgtOffset = target.offsetAt(utc);
    final diff = tgtOffset - srcOffset;

    if (diff == 0) return 'Waktu sama persis';
    if (diff > 0) return '$diff jam lebih cepat';
    return '${diff.abs()} jam lebih lambat';
  }

  @override
  Widget build(BuildContext context) {
    final nowUtc = _currentTime.add(
      Duration(minutes: (_customHourOffset * 60).round()),
    );
    final conversionUtc = nowUtc;
    final sourceZone = _zone(_sourceZoneId);
    final targetZone = _zone(_targetZoneId);
    final sourceTime = _timeInZone(conversionUtc, sourceZone);
    final convertedTime = _timeInZone(conversionUtc, targetZone);
    final isDst = _isLondonDst(nowUtc);
    final londonOffset = isDst ? 1 : 0;

    final cstTime = _getTargetTime(8); // Beijing UTC+8
    final wibTime = _getTargetTime(7);
    final witaTime = _getTargetTime(8);
    final witTime = _getTargetTime(9);
    final londonTime = _getTargetTime(londonOffset);

    return Scaffold(
      backgroundColor: AppColors.mintBackground,
      appBar: AppBar(title: const Text('Konversi Zona Waktu')),
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
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
                      _formatDate(cstTime),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getMandarinPeriod(cstTime.hour),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Mode Realtime / Slider Simulasi
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
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
                          _isLiveTime
                              ? '⏱ Waktu Real-Time (Aktif)'
                              : '🎚️ Simulasi Jam Khusus',
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
                          child: Text(
                            _isLiveTime ? 'Ganti Manual' : 'Kembali Realtime',
                          ),
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
                        label:
                            '${_customHourOffset >= 0 ? '+' : ''}${_customHourOffset.toInt()} Jam',
                        onChanged: (val) {
                          setState(() {
                            _customHourOffset = val;
                          });
                        },
                      ),
                      Text(
                        'Geser offset: ${_customHourOffset >= 0 ? '+' : ''}${_customHourOffset.toInt()} jam dari saat ini',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Pemilih asal dan tujuan membuat konversi bisa dibalik dan
              // mendukung seluruh zona yang ditampilkan di halaman ini.
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Konversi waktu antarnegara',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildZoneSelector(
                            label: 'Dari',
                            value: _sourceZoneId,
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _sourceZoneId = value);
                              }
                            },
                          ),
                        ),
                        IconButton(
                          tooltip: 'Tukar zona waktu',
                          onPressed: _swapZones,
                          icon: const Icon(Icons.swap_horiz_rounded),
                          color: AppColors.primaryGreen,
                        ),
                        Expanded(
                          child: _buildZoneSelector(
                            label: 'Ke',
                            value: _targetZoneId,
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _targetZoneId = value);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${sourceZone.name}  ${_utcLabel(conversionUtc, sourceZone)}',
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            '${_formatTime(sourceTime)}  ·  ${_formatDate(sourceTime)}',
                            style: const TextStyle(
                              color: AppColors.textDark,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Icon(
                              Icons.arrow_downward_rounded,
                              color: AppColors.primaryGreen,
                            ),
                          ),
                          Text(
                            '${targetZone.name}  ${_utcLabel(conversionUtc, targetZone)}',
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            '${_formatTime(convertedTime)}  ·  ${_formatDate(convertedTime)}',
                            style: const TextStyle(
                              color: AppColors.primaryGreen,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _getTimeDiffText(
                              sourceZone,
                              targetZone,
                              conversionUtc,
                            ),
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
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
                name: 'WIB · Jakarta',
                subname: 'Jawa, Sumatra, Kalbar',
                utcLabel: 'UTC+7',
                diffFromCst: '-1 Jam dari Beijing',
                time: wibTime,
                accentColor: const Color(0xFF0284C7),
              ),
              const SizedBox(height: 10),

              // 2. WITA
              _buildZoneCard(
                flag: '🇮🇩',
                name: 'WITA · Bali',
                subname: 'Bali, Sulawesi, NTT, NTB',
                utcLabel: 'UTC+8',
                diffFromCst: 'Sama persis dengan Beijing',
                time: witaTime,
                accentColor: const Color(0xFF0D9488),
              ),
              const SizedBox(height: 10),

              // 3. WIT
              _buildZoneCard(
                flag: '🇮🇩',
                name: 'WIT · Papua',
                subname: 'Maluku & Papua',
                utcLabel: 'UTC+9',
                diffFromCst: '+1 Jam dari Beijing',
                time: witTime,
                accentColor: const Color(0xFF7C3AED),
              ),
              const SizedBox(height: 10),

              // 4. London
              _buildZoneCard(
                flag: '🇬🇧',
                name: 'London · Inggris',
                subname: 'Britania Raya (UK)',
                utcLabel: isDst ? 'BST (UTC+1)' : 'GMT (UTC+0)',
                diffFromCst: isDst
                    ? '-7 Jam dari Beijing (Summer Time)'
                    : '-8 Jam dari Beijing (Winter)',
                time: londonTime,
                accentColor: const Color(0xFFD97706),
                badge: isDst ? 'Daylight Saving Aktif' : 'Standard Time',
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildZoneSelector({
    required String label,
    required String value,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF64748B),
            ),
          ),
          DropdownButton<String>(
            value: value,
            isExpanded: true,
            isDense: true,
            underline: const SizedBox.shrink(),
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
            ),
            items: _zones
                .map(
                  (zone) => DropdownMenuItem<String>(
                    value: zone.id,
                    child: Text(
                      '${zone.flag} ${zone.id}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildZoneCard({
    required String flag,
    required String name,
    required String subname,
    required String utcLabel,
    required String diffFromCst,
    required DateTime time,
    required Color accentColor,
    String? badge,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(flag, style: const TextStyle(fontSize: 20)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      name,
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
                const SizedBox(height: 3),
                Text(
                  subname,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textMuted,
                  ),
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
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
                if (badge != null) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
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
}

class _TimeZoneOption {
  final String id;
  final String name;
  final String subname;
  final String flag;
  final Color accentColor;
  final int Function(DateTime utc) offsetAt;

  const _TimeZoneOption({
    required this.id,
    required this.name,
    required this.subname,
    required this.flag,
    required this.accentColor,
    required this.offsetAt,
  });
}
