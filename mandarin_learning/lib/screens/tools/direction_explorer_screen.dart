import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../../core/constants/app_colors.dart';
import '../../services/audio_service.dart';

// FR-11: Mandarin Direction Explorer (LBS + Kompas / Magnetometer)
// PB-15: Tempat sekitar, jarak, arah relatif, kompas, dan kosakata tanpa kuis

class PlaceItem {
  final String nameId;
  final String hanzi;
  final String pinyin;
  final String category;
  final String iconEmoji;
  final double latitude;
  final double longitude;

  PlaceItem({
    required this.nameId,
    required this.hanzi,
    required this.pinyin,
    required this.category,
    required this.iconEmoji,
    required this.latitude,
    required this.longitude,
  });
}

class DirectionExplorerScreen extends StatefulWidget {
  const DirectionExplorerScreen({super.key});

  @override
  State<DirectionExplorerScreen> createState() => _DirectionExplorerScreenState();
}

class _DirectionExplorerScreenState extends State<DirectionExplorerScreen> {
  Position? _currentPosition;
  bool _isLoadingLocation = true;
  bool _locationPermissionDenied = false;
  String? _locationErrorMessage;

  // Sensor Kompas (Magnetometer)
  StreamSubscription<MagnetometerEvent>? _magnetometerSub;
  double _headingDegrees = 0.0;
  bool _isCompassAvailable = true;

  // Kategori terpilih untuk filter tempat
  String _selectedCategory = 'Semua';

  // Daftar tempat acuan di sekitar pengguna (relatif terhadap koordinat pengguna atau titik default Jakarta)
  List<PlaceItem> _nearbyPlaces = [];

  @override
  void initState() {
    super.initState();
    _initLocationAndCompass();
  }

  @override
  void dispose() {
    _magnetometerSub?.cancel();
    super.dispose();
  }

  Future<void> _initLocationAndCompass() async {
    // 1. Inisialisasi Sensor Magnetometer untuk Kompas
    try {
      _magnetometerSub = magnetometerEventStream(
        samplingPeriod: const Duration(milliseconds: 100),
      ).listen(
        (event) {
          // Hitung heading dalam radian lalu ubah ke derajat (0 - 360)
          final heading = math.atan2(event.y, event.x) * (180 / math.pi);
          // Normalisasi ke 0 - 360 derajat
          double degrees = (heading + 360) % 360;
          if (mounted) {
            setState(() {
              _headingDegrees = degrees;
            });
          }
        },
        onError: (err) {
          if (mounted) {
            setState(() {
              _isCompassAvailable = false;
            });
          }
        },
      );
    } catch (e) {
      _isCompassAvailable = false;
    }

    // 2. Periksa Izin & Ambil Lokasi GPS (LBS)
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _locationPermissionDenied = true;
          _locationErrorMessage = 'Layanan GPS tidak aktif. Menggunakan mode fallback.';
          _isLoadingLocation = false;
          _generatePlacesAround(null);
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _locationPermissionDenied = true;
            _locationErrorMessage = 'Izin lokasi ditolak. Kosakata mata angin tetap dapat dipelajari.';
            _isLoadingLocation = false;
            _generatePlacesAround(null);
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _locationPermissionDenied = true;
          _locationErrorMessage = 'Izin lokasi ditolak permanen. Menggunakan mode fallback kosakata.';
          _isLoadingLocation = false;
          _generatePlacesAround(null);
        });
        return;
      }

      // Ambil posisi aktual
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 8),
        ),
      );

      if (mounted) {
        setState(() {
          _currentPosition = position;
          _isLoadingLocation = false;
          _locationPermissionDenied = false;
          _generatePlacesAround(position);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _locationPermissionDenied = true;
          _locationErrorMessage = 'Tidak dapat mendeteksi lokasi GPS ($e). Menampilkan tempat referensi.';
          _isLoadingLocation = false;
          _generatePlacesAround(null);
        });
      }
    }
  }

  void _generatePlacesAround(Position? userPos) {
    // Koordinat pusat (aktual atau default Monas/Jakarta jika GPS mati)
    final baseLat = userPos?.latitude ?? -6.175392;
    final baseLng = userPos?.longitude ?? 106.827153;

    // Menghasilkan tempat relevan dengan konteks kosakata Mandarin
    final places = [
      PlaceItem(
        nameId: 'Restoran Dimsum Panda',
        hanzi: '餐馆',
        pinyin: 'Cānguǎn',
        category: 'Makan',
        iconEmoji: '🥢',
        latitude: baseLat + 0.0035, // Utara
        longitude: baseLng + 0.0012,
      ),
      PlaceItem(
        nameId: 'Stasiun Kereta Cepat',
        hanzi: '车站',
        pinyin: 'Chēzhàn',
        category: 'Transportasi',
        iconEmoji: '🚄',
        latitude: baseLat + 0.0080, // Utara-Timur
        longitude: baseLng + 0.0065,
      ),
      PlaceItem(
        nameId: 'Hotel Grand Beijing',
        hanzi: '酒店',
        pinyin: 'Jiǔdiàn',
        category: 'Akomodasi',
        iconEmoji: '🏨',
        latitude: baseLat - 0.0042, // Selatan
        longitude: baseLng + 0.0031,
      ),
      PlaceItem(
        nameId: 'Bank of China',
        hanzi: '银行',
        pinyin: 'Yínháng',
        category: 'Keuangan',
        iconEmoji: '🏦',
        latitude: baseLat - 0.0020,
        longitude: baseLng - 0.0055, // Barat Daya
      ),
      PlaceItem(
        nameId: 'Rumah Sakit Persahabatan',
        hanzi: '医院',
        pinyin: 'Yīyuàn',
        category: 'Kesehatan',
        iconEmoji: '🏥',
        latitude: baseLat + 0.0015,
        longitude: baseLng - 0.0072, // Barat Laut
      ),
      PlaceItem(
        nameId: 'Taman Lotus Sejahtera',
        hanzi: '公园',
        pinyin: 'Gōngyuán',
        category: 'Rekreasi',
        iconEmoji: '🌳',
        latitude: baseLat - 0.0060, // Selatan-Barat
        longitude: baseLng - 0.0020,
      ),
      PlaceItem(
        nameId: 'Supermarket Segar Asia',
        hanzi: '超市',
        pinyin: 'Chāoshì',
        category: 'Belanja',
        iconEmoji: '🛒',
        latitude: baseLat + 0.0048,
        longitude: baseLng + 0.0040, // Timur Laut
      ),
    ];

    setState(() {
      _nearbyPlaces = places;
    });
  }

  // Hitung Jarak Haversine (Meter / Kilometer)
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const earthRadius = 6371000.0; // Meter
    final dLat = (lat2 - lat1) * (math.pi / 180);
    final dLon = (lon2 - lon1) * (math.pi / 180);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * (math.pi / 180)) *
            math.cos(lat2 * (math.pi / 180)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  // Hitung Arah Relatif (Bearing) & Petakan ke 8 Arah Mata Angin
  String _calculateBearing(double lat1, double lon1, double lat2, double lon2) {
    final phi1 = lat1 * (math.pi / 180);
    final phi2 = lat2 * (math.pi / 180);
    final deltaLambda = (lon2 - lon1) * (math.pi / 180);

    final y = math.sin(deltaLambda) * math.cos(phi2);
    final x = math.cos(phi1) * math.sin(phi2) -
        math.sin(phi1) * math.cos(phi2) * math.cos(deltaLambda);
    final theta = math.atan2(y, x);
    final degrees = (theta * (180 / math.pi) + 360) % 360;

    return _degreesToCardinal(degrees);
  }

  String _degreesToCardinal(double deg) {
    if (deg >= 337.5 || deg < 22.5) return '北 (Běi - Utara)';
    if (deg >= 22.5 && deg < 67.5) return '东北 (Dōngběi - Timur Laut)';
    if (deg >= 67.5 && deg < 112.5) return '东 (Dōng - Timur)';
    if (deg >= 112.5 && deg < 157.5) return '东南 (Dōngnán - Tenggara)';
    if (deg >= 157.5 && deg < 202.5) return '南 (Nán - Selatan)';
    if (deg >= 202.5 && deg < 247.5) return '西南 (Xīnán - Barat Daya)';
    if (deg >= 247.5 && deg < 292.5) return '西 (Xī - Barat)';
    return '西北 (Xīběi - Barat Laut)';
  }

  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.toStringAsFixed(0)} m';
    }
    return '${(meters / 1000).toStringAsFixed(2)} km';
  }

  @override
  Widget build(BuildContext context) {
    final userLat = _currentPosition?.latitude ?? -6.175392;
    final userLng = _currentPosition?.longitude ?? 106.827153;

    final categories = ['Semua', 'Makan', 'Transportasi', 'Akomodasi', 'Kesehatan', 'Belanja', 'Rekreasi'];

    final filteredPlaces = _selectedCategory == 'Semua'
        ? _nearbyPlaces
        : _nearbyPlaces.where((p) => p.category == _selectedCategory).toList();

    return Scaffold(
      backgroundColor: AppColors.mintBackground,
      appBar: AppBar(
        title: const Text('Mandarin Direction Explorer'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Compass & Heading Widget
              _buildCompassCard(),
              const SizedBox(height: 16),

              // GPS Banner / Fallback Notice
              if (_locationPermissionDenied) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.location_off_rounded, color: Color(0xFFB45309), size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _locationErrorMessage ?? 'GPS tidak aktif. Menampilkan referensi tempat sekitar.',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF92400E)),
                        ),
                      ),
                      TextButton(
                        onPressed: _initLocationAndCompass,
                        child: const Text('Coba Lagi', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // 8 Cardinal Directions Reference (Mata Angin)
              const Text(
                'Kosakata Arah Mata Angin (方向 - Fāngxiàng)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 10),

              _buildCardinalGrid(),
              const SizedBox(height: 20),

              // Category Filter Pills
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: categories.map((cat) {
                    final isSel = _selectedCategory == cat;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(cat),
                        selected: isSel,
                        selectedColor: AppColors.primary,
                        labelStyle: TextStyle(
                          color: isSel ? Colors.white : AppColors.textDark,
                          fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                          fontSize: 12,
                        ),
                        onSelected: (_) {
                          setState(() {
                            _selectedCategory = cat;
                          });
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),

              // Places Nearby List
              Text(
                'Tempat di Sekitar (${filteredPlaces.length})',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 10),

              if (_isLoadingLocation)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: CircularProgressIndicator(),
                  ),
                )
              else
                ...filteredPlaces.map((place) {
                  final dist = _calculateDistance(userLat, userLng, place.latitude, place.longitude);
                  final direction = _calculateBearing(userLat, userLng, place.latitude, place.longitude);

                  return _buildPlaceTile(place, dist, direction);
                }),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompassCard() {
    final cardinal = _degreesToCardinal(_headingDegrees);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Visual Dial Compass
          SizedBox(
            width: 110,
            height: 110,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Outer circle dial
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFE2E8F0), width: 3),
                    gradient: RadialGradient(
                      colors: [
                        Colors.white,
                        const Color(0xFFF1F5F9),
                      ],
                    ),
                  ),
                ),
                // Cardinal labels on dial
                const Positioned(top: 6, child: Text('北', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red))),
                const Positioned(bottom: 6, child: Text('南', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textMuted))),
                const Positioned(right: 6, child: Text('东', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textMuted))),
                const Positioned(left: 6, child: Text('西', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textMuted))),

                // Rotating Needle
                Transform.rotate(
                  angle: (_headingDegrees * (math.pi / 180)),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 4, height: 26, decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(2))),
                      Container(width: 4, height: 26, decoration: BoxDecoration(color: const Color(0xFF64748B), borderRadius: BorderRadius.circular(2))),
                    ],
                  ),
                ),
                // Center pin
                Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(color: Color(0xFF0F172A), shape: BoxShape.circle),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),

          // Heading details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('🧭', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 6),
                    Text(
                      _isCompassAvailable ? 'Kompas Aktif' : 'Simulasi Kompas',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _isCompassAvailable ? AppColors.primaryGreen : const Color(0xFFB45309),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${_headingDegrees.toStringAsFixed(0)}°',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                Text(
                  cardinal,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryDark,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Putar perangkat untuk melihat perubahan arah',
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardinalGrid() {
    final directions = [
      {'hanzi': '北', 'pinyin': 'Běi', 'arti': 'Utara'},
      {'hanzi': '南', 'pinyin': 'Nán', 'arti': 'Selatan'},
      {'hanzi': '东', 'pinyin': 'Dōng', 'arti': 'Timur'},
      {'hanzi': '西', 'pinyin': 'Xī', 'arti': 'Barat'},
      {'hanzi': '东北', 'pinyin': 'Dōngběi', 'arti': 'Timur Laut'},
      {'hanzi': '东南', 'pinyin': 'Dōngnán', 'arti': 'Tenggara'},
      {'hanzi': '西北', 'pinyin': 'Xīběi', 'arti': 'Barat Laut'},
      {'hanzi': '西南', 'pinyin': 'Xīnán', 'arti': 'Barat Daya'},
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 1.1,
        ),
        itemCount: directions.length,
        itemBuilder: (context, idx) {
          final item = directions[idx];
          return GestureDetector(
            onTap: () => AudioService.instance.speak(item['hanzi']!),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    item['hanzi']!,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                  ),
                  Text(
                    item['pinyin']!,
                    style: const TextStyle(fontSize: 11, color: AppColors.primaryGreen),
                  ),
                  Text(
                    item['arti']!,
                    style: const TextStyle(fontSize: 9, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPlaceTile(PlaceItem place, double distMeters, String direction) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
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
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(place.iconEmoji, style: const TextStyle(fontSize: 22)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      place.hanzi,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      place.pinyin,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _formatDistance(distMeters),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  place.nameId,
                  style: const TextStyle(fontSize: 13, color: AppColors.textDark, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.navigation_outlined, size: 12, color: AppColors.textMuted),
                    const SizedBox(width: 4),
                    Text(
                      'Arah: $direction',
                      style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.volume_up_rounded, color: AppColors.primaryDark, size: 20),
            onPressed: () => AudioService.instance.speak(place.hanzi),
          ),
        ],
      ),
    );
  }
}
