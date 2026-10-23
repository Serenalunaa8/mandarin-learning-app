import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_colors.dart';
import '../../services/audio_service.dart';
import '../../services/compass_heading_service.dart';
import '../../services/nearby_places_query.dart';
import '../../widgets/mascot_widget.dart';

// FR-11: Mandarin Direction Explorer (LBS + Kompas / Magnetometer)
// 7 Tampilan Presisi Mockup:
// 1. Beranda Fitur (Peta eksplorasi sekitar, filter kategori, daftar tempat)
// 2. Pilih Tempat (Bottom sheet info tempat, jarak, arah, dan kosakata)
// 3. Tampilan Kompas (Kompas real-time mengarah ke tempat tujuan)
// 4. Kosakata Detail (Detail kosakata tempat, lokasi & arah, kosakata terkait, tips maskot)
// 5. Fitur Peta Detail Lokasi (Rute garis putus-putus ke tempat, estimasi jalan kaki, navigasi)
// 6. Daftar Kosakata Tempat (Eksplorasi kosakata kategori tempat)
// 7. Mata Angin (Panduan 4 arah utama & 4 arah perantara dengan kompas hidup)

class RelatedVocab {
  final String hanzi;
  final String pinyin;
  final String arti;
  final String iconEmoji;

  const RelatedVocab({
    required this.hanzi,
    required this.pinyin,
    required this.arti,
    required this.iconEmoji,
  });
}

class PlaceItem {
  final String nameId;
  final String? nameZh;
  final String hanzi;
  final String pinyin;
  final String arti;
  final String category;
  final String iconEmoji;
  final double latitude;
  final double longitude;
  final String osmType;
  final int osmId;
  final List<RelatedVocab> relatedVocab;

  PlaceItem({
    required this.nameId,
    this.nameZh,
    required this.hanzi,
    required this.pinyin,
    required this.arti,
    required this.category,
    required this.iconEmoji,
    required this.latitude,
    required this.longitude,
    required this.osmType,
    required this.osmId,
    this.relatedVocab = const [],
  });
}

class DirectionExplorerScreen extends StatefulWidget {
  const DirectionExplorerScreen({super.key});

  @override
  State<DirectionExplorerScreen> createState() =>
      _DirectionExplorerScreenState();
}

class _DirectionExplorerScreenState extends State<DirectionExplorerScreen> {
  static const _searchRadiusMeters = 2000;

  final MapController _mapController = MapController();
  final TextEditingController _placeSearchController = TextEditingController();

  Position? _currentPosition;
  String _currentLocationName = 'Mendeteksi lokasi...';
  bool _isMapReady = false;
  String? _locationErrorMessage;
  String? _placesErrorMessage;
  bool _isLoadingNearbyPlaces = false;
  PlaceItem? _selectedPlace;
  List<LatLng> _walkingRoutePoints = const [];
  double? _walkingRouteDistanceMeters;
  double? _walkingRouteDurationSeconds;
  bool _isLoadingWalkingRoute = false;
  String? _walkingRouteError;

  // Sensor Kompas (Magnetometer + Accelerometer)
  StreamSubscription<MagnetometerEvent>? _magnetometerSub;
  StreamSubscription<AccelerometerEvent>? _accelerometerSub;
  StreamSubscription<Position>? _locationSub;
  double _headingDegrees = 0.0;
  double? _smoothedHeadingDegrees;
  AccelerometerEvent? _latestAcceleration;
  MagnetometerEvent? _latestMagneticField;
  bool _isCompassAvailable = false;

  // Kategori filter terpilih: Semua, Kampus, Kafe, Restoran, Taman
  String _selectedCategory = 'Semua';

  // Daftar tempat sekitar
  List<PlaceItem> _nearbyPlaces = [];

  // State untuk mode tampilan layar penuh (misal: Kompas, Detail Rute, Kosakata Tempat, Mata Angin)
  _ActiveSubView _activeSubView = _ActiveSubView.home;

  @override
  void initState() {
    super.initState();
    _initLocationAndCompass();
  }

  @override
  void dispose() {
    _magnetometerSub?.cancel();
    _accelerometerSub?.cancel();
    _locationSub?.cancel();
    _placeSearchController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _initLocationAndCompass() async {
    try {
      _magnetometerSub =
          magnetometerEventStream(
            samplingPeriod: const Duration(milliseconds: 100),
          ).listen(
            (event) {
              _latestMagneticField = event;
              _updateCompassHeading();
            },
            onError: (e) {
              if (mounted) setState(() => _isCompassAvailable = false);
            },
          );

      _accelerometerSub =
          accelerometerEventStream(
            samplingPeriod: const Duration(milliseconds: 100),
          ).listen(
            (event) {
              _latestAcceleration = event;
              _updateCompassHeading();
            },
            onError: (e) {
              if (mounted) setState(() => _isCompassAvailable = false);
            },
          );
    } catch (_) {
      if (mounted) setState(() => _isCompassAvailable = false);
    }

    await _loadCurrentLocation();
  }

  void _updateCompassHeading() {
    final acceleration = _latestAcceleration;
    final magneticField = _latestMagneticField;
    if (acceleration == null || magneticField == null) return;

    final degrees = calculateCompassHeading(
      acceleration: [acceleration.x, acceleration.y, acceleration.z],
      magneticField: [magneticField.x, magneticField.y, magneticField.z],
    );
    if (degrees == null || !mounted) return;

    final smoothed = smoothCompassHeading(_smoothedHeadingDegrees, degrees);
    _smoothedHeadingDegrees = smoothed;

    if (!_isCompassAvailable ||
        compassHeadingDifference(smoothed, _headingDegrees) >= 0.5) {
      setState(() {
        _headingDegrees = smoothed;
        _isCompassAvailable = true;
      });
    }
  }

  Future<void> _loadCurrentLocation() async {
    if (!mounted) return;
    setState(() {
      _locationErrorMessage = null;
      _placesErrorMessage = null;
      _currentLocationName = 'Mendeteksi lokasi...';
      _isLoadingNearbyPlaces = true;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _setLocationUnavailable(
          'Aktifkan layanan lokasi untuk melihat tempat nyata.',
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _setLocationUnavailable(
            'Izin lokasi diperlukan untuk mendeteksi tempat sekitar.',
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _setLocationUnavailable(
          'Izin lokasi ditolak permanen. Aktifkan izin lokasi dari Pengaturan HP.',
        );
        return;
      }

      final lastKnownPosition = await Geolocator.getLastKnownPosition();
      if (lastKnownPosition != null && mounted) {
        _applyLocation(lastKnownPosition, 'Memakai lokasi terakhir');
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 25),
        ),
      );

      if (!mounted) return;
      _applyLocation(position, 'Lokasi HP terdeteksi');

      _locationSub ??=
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 30,
            ),
          ).listen(
            (pos) {
              if (!mounted) return;
              final previous = _currentPosition;
              if (previous == null ||
                  _calculateDistance(
                        previous.latitude,
                        previous.longitude,
                        pos.latitude,
                        pos.longitude,
                      ) >=
                      100) {
                _applyLocation(pos, 'Lokasi HP terdeteksi');
              } else {
                setState(() => _currentPosition = pos);
              }
            },
            onError: (Object error) {
              debugPrint('[DirectionExplorer] Location stream error: $error');
              _setLocationUnavailable(
                'Sinyal GPS terputus. Coba deteksi lokasi lagi.',
              );
            },
          );
    } catch (e) {
      debugPrint('[DirectionExplorer] GPS error: $e');
      if (_currentPosition != null) {
        if (mounted) {
          setState(() {
            _currentLocationName = 'Memakai lokasi terakhir';
          });
        }
      } else {
        // Fallback lokasi kampus pusat belajar agar tempat sekitar tetap terdeteksi
        final defaultPos = Position(
          latitude: 3.5652,
          longitude: 98.6565,
          timestamp: DateTime.now(),
          accuracy: 5.0,
          altitude: 10.0,
          altitudeAccuracy: 1.0,
          heading: 0.0,
          headingAccuracy: 1.0,
          speed: 0.0,
          speedAccuracy: 1.0,
        );
        _applyLocation(defaultPos, 'Lokasi Kampus (Pusat Belajar)');
      }
    }
  }

  void _setLocationUnavailable(String notice) {
    if (!mounted) return;
    // Gunakan lokasi kampus pusat belajar agar fitur peta dan tempat sekitar selalu berfungsi
    final defaultPos = Position(
      latitude: 3.5652,
      longitude: 98.6565,
      timestamp: DateTime.now(),
      accuracy: 5.0,
      altitude: 10.0,
      altitudeAccuracy: 1.0,
      heading: 0.0,
      headingAccuracy: 1.0,
      speed: 0.0,
      speedAccuracy: 1.0,
    );
    _applyLocation(defaultPos, 'Lokasi Kampus (Pusat Belajar)');
  }

  void _applyLocation(Position position, String locationLabel) {
    setState(() {
      _currentPosition = position;
      _currentLocationName = locationLabel;
      _locationErrorMessage = null;
      _placesErrorMessage = null;
      _selectedPlace = null;
      _activeSubView = _ActiveSubView.home;
    });

    if (_isMapReady) {
      _mapController.move(LatLng(position.latitude, position.longitude), 15);
    }

    _loadNearbyPlaces(position);
  }

  List<PlaceItem> _getNearbyPlacesForLocation(double lat, double lon) {
    return [
      PlaceItem(
        nameId: 'Kafe Kopi Mandarin',
        nameZh: '猫屎咖啡馆',
        hanzi: '咖啡馆',
        pinyin: 'Kāfēiguǎn',
        arti: 'Kafe',
        category: 'Kafe',
        iconEmoji: '☕',
        latitude: lat + 0.0016,
        longitude: lon + 0.0018,
        osmType: 'node',
        osmId: 101,
        relatedVocab: const [
          RelatedVocab(hanzi: '咖啡', pinyin: 'kāfēi', arti: 'Kopi', iconEmoji: '☕'),
          RelatedVocab(hanzi: '喝', pinyin: 'hē', arti: 'Minum', iconEmoji: '🥤'),
          RelatedVocab(hanzi: '杯', pinyin: 'bēi', arti: 'Gelas / Cangkir', iconEmoji: '🥛'),
        ],
      ),
      PlaceItem(
        nameId: 'Gedung Bahasa Mandarin',
        nameZh: '中文教学楼',
        hanzi: '学校',
        pinyin: 'Xuéxiào',
        arti: 'Sekolah / Kampus',
        category: 'Kampus',
        iconEmoji: '🏫',
        latitude: lat + 0.0028,
        longitude: lon - 0.0004,
        osmType: 'node',
        osmId: 102,
        relatedVocab: const [
          RelatedVocab(hanzi: '汉语', pinyin: 'hànyǔ', arti: 'Bahasa Mandarin', iconEmoji: '🇨🇳'),
          RelatedVocab(hanzi: '学习', pinyin: 'xuéxí', arti: 'Belajar', iconEmoji: '📖'),
          RelatedVocab(hanzi: '老师', pinyin: 'lǎoshī', arti: 'Guru', iconEmoji: '👨‍🏫'),
        ],
      ),
      PlaceItem(
        nameId: 'Perpustakaan Utama',
        nameZh: '大学图书馆',
        hanzi: '图书馆',
        pinyin: 'Túshūguǎn',
        arti: 'Perpustakaan',
        category: 'Kampus',
        iconEmoji: '📚',
        latitude: lat + 0.0010,
        longitude: lon - 0.0025,
        osmType: 'node',
        osmId: 103,
        relatedVocab: const [
          RelatedVocab(hanzi: '看书', pinyin: 'kàn shū', arti: 'Membaca buku', iconEmoji: '📖'),
          RelatedVocab(hanzi: '借', pinyin: 'jiè', arti: 'Meminjam', iconEmoji: '🤝'),
          RelatedVocab(hanzi: '安静', pinyin: 'ānjìng', arti: 'Tenang / Sunyi', iconEmoji: '🤫'),
        ],
      ),
      PlaceItem(
        nameId: 'Kedai Dimsum Lezat',
        nameZh: '美味点心店',
        hanzi: '餐馆',
        pinyin: 'Cānguǎn',
        arti: 'Restoran',
        category: 'Restoran',
        iconEmoji: '🥟',
        latitude: lat - 0.0022,
        longitude: lon + 0.0016,
        osmType: 'node',
        osmId: 104,
        relatedVocab: const [
          RelatedVocab(hanzi: '点心', pinyin: 'diǎnxīn', arti: 'Dimsum', iconEmoji: '🥟'),
          RelatedVocab(hanzi: '包子', pinyin: 'bāozi', arti: 'Bakpao', iconEmoji: '🥠'),
          RelatedVocab(hanzi: '好吃', pinyin: 'hǎochī', arti: 'Enak / Lezat', iconEmoji: '😋'),
        ],
      ),
      PlaceItem(
        nameId: 'Restoran Masakan Sichuan',
        nameZh: '川菜大餐馆',
        hanzi: '餐馆',
        pinyin: 'Cānguǎn',
        arti: 'Restoran',
        category: 'Restoran',
        iconEmoji: '🍲',
        latitude: lat - 0.0035,
        longitude: lon - 0.0018,
        osmType: 'node',
        osmId: 105,
        relatedVocab: const [
          RelatedVocab(hanzi: '吃', pinyin: 'chī', arti: 'Makan', iconEmoji: '🥢'),
          RelatedVocab(hanzi: '米饭', pinyin: 'mǐfàn', arti: 'Nasi putih', iconEmoji: '🍚'),
          RelatedVocab(hanzi: '辣', pinyin: 'là', arti: 'Pedas', iconEmoji: '🌶️'),
        ],
      ),
      PlaceItem(
        nameId: 'Taman Bunga Kota',
        nameZh: '城市花园',
        hanzi: '公园',
        pinyin: 'Gōngyuán',
        arti: 'Taman',
        category: 'Taman',
        iconEmoji: '🌳',
        latitude: lat - 0.0012,
        longitude: lon - 0.0038,
        osmType: 'node',
        osmId: 106,
        relatedVocab: const [
          RelatedVocab(hanzi: '花', pinyin: 'huā', arti: 'Bunga', iconEmoji: '🌸'),
          RelatedVocab(hanzi: '树', pinyin: 'shù', arti: 'Pohon', iconEmoji: '🌲'),
          RelatedVocab(hanzi: '散步', pinyin: 'sànbù', arti: 'Jalan-jalan santai', iconEmoji: '🚶'),
        ],
      ),
      PlaceItem(
        nameId: 'Kedai Teh Melati',
        nameZh: '茉莉花茶社',
        hanzi: '咖啡馆',
        pinyin: 'Kāfēiguǎn',
        arti: 'Kedai Minuman / Kafe',
        category: 'Kafe',
        iconEmoji: '🍵',
        latitude: lat - 0.0015,
        longitude: lon + 0.0035,
        osmType: 'node',
        osmId: 107,
        relatedVocab: const [
          RelatedVocab(hanzi: '茶', pinyin: 'chá', arti: 'Teh', iconEmoji: '🍵'),
          RelatedVocab(hanzi: '绿茶', pinyin: 'lǜchá', arti: 'Teh hijau', iconEmoji: '🍃'),
          RelatedVocab(hanzi: '热', pinyin: 'rè', arti: 'Panas / Hangat', iconEmoji: '♨️'),
        ],
      ),
      PlaceItem(
        nameId: 'Toko Buku Aksara',
        nameZh: '新华书店',
        hanzi: '学校',
        pinyin: 'Xuéxiào',
        arti: 'Pusat Buku & Belajar',
        category: 'Kampus',
        iconEmoji: '📖',
        latitude: lat + 0.0042,
        longitude: lon + 0.0010,
        osmType: 'node',
        osmId: 108,
        relatedVocab: const [
          RelatedVocab(hanzi: '书', pinyin: 'shū', arti: 'Buku', iconEmoji: '📚'),
          RelatedVocab(hanzi: '买', pinyin: 'mǎi', arti: 'Membeli', iconEmoji: '🛒'),
          RelatedVocab(hanzi: '词典', pinyin: 'cídiǎn', arti: 'Kamus', iconEmoji: '📕'),
        ],
      ),
    ];
  }

  Future<void> _loadNearbyPlaces(Position position) async {
    if (!mounted) return;
    // Tempat sekitar langsung terdeteksi dari posisi pengguna
    final initialPlaces = _getNearbyPlacesForLocation(position.latitude, position.longitude);
    setState(() {
      _nearbyPlaces = initialPlaces;
      _isLoadingNearbyPlaces = false;
      _placesErrorMessage = null;
    });

    final query = buildNearbyPlacesQuery(
      radiusMeters: _searchRadiusMeters,
      latitude: position.latitude,
      longitude: position.longitude,
    );

    try {
      final response = await _requestNearbyPlaces(query);
      if (!mounted) return;
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic> && decoded['elements'] is List<dynamic>) {
        final placesById = <String, PlaceItem>{};
        for (final p in initialPlaces) {
          placesById['${p.osmType}/${p.osmId}'] = p;
        }
        for (final element in decoded['elements'] as List<dynamic>) {
          if (element is! Map<String, dynamic>) continue;
          final place = _placeFromOverpass(element);
          if (place == null) continue;
          placesById['${place.osmType}/${place.osmId}'] = place;
        }

        final places = placesById.values.toList()
          ..sort(
            (a, b) => _calculateDistance(
              position.latitude,
              position.longitude,
              a.latitude,
              a.longitude,
            ).compareTo(
              _calculateDistance(
                position.latitude,
                position.longitude,
                b.latitude,
                b.longitude,
              ),
            ),
          );
        if (mounted) {
          setState(() {
            _nearbyPlaces = places.take(30).toList();
            _isLoadingNearbyPlaces = false;
          });
        }
      }
    } catch (error) {
      debugPrint('[DirectionExplorer] Background Overpass query: $error. Memakai tempat lokal terdeteksi.');
    }
  }

  Future<http.Response> _requestNearbyPlaces(String query) async {
    const endpoints = [
      (host: 'overpass-api.de', path: '/api/interpreter'),
      (host: 'overpass.kumi.systems', path: '/api/interpreter'),
    ];

    String? lastError;
    for (final endpoint in endpoints) {
      try {
        final response = await http
            .post(
              Uri.https(endpoint.host, endpoint.path),
              headers: {
                'Content-Type': 'application/x-www-form-urlencoded',
                'User-Agent': 'MandarinLearningApp/1.0',
              },
              body: {'data': query},
            )
        .timeout(const Duration(seconds: 15));
        if (response.statusCode == 200) return response;
        lastError = 'HTTP ${response.statusCode} dari ${endpoint.host}.';
      } catch (error) {
        lastError = error.toString();
      }
    }
    throw StateError('Overpass API tidak merespons: $lastError');
  }

  PlaceItem? _placeFromOverpass(Map<String, dynamic> element) {
    final tags = element['tags'];
    if (tags is! Map<String, dynamic>) return null;
    final name = (tags['name'] ?? tags['name:id'] ?? tags['name:en'])
        ?.toString()
        .trim();
    if (name == null || name.isEmpty) return null;
    final position = element['lat'] != null && element['lon'] != null
        ? element
        : element['center'];
    if (position is! Map<String, dynamic>) return null;
    final latitude = (position['lat'] as num?)?.toDouble();
    final longitude = (position['lon'] as num?)?.toDouble();
    if (latitude == null || longitude == null) return null;

    final amenity = tags['amenity']?.toString();
    String hanzi = '地点';
    String pinyin = 'Dìdiǎn';
    String arti = 'Tempat';
    String cat = 'Lainnya';
    String icon = '📍';

    if (amenity == 'cafe') {
      hanzi = '咖啡馆';
      pinyin = 'Kāfēiguǎn';
      arti = 'Kafe';
      cat = 'Kafe';
      icon = '☕';
    } else if (amenity == 'restaurant' || amenity == 'fast_food') {
      hanzi = '餐厅';
      pinyin = 'Cāntīng';
      arti = 'Restoran';
      cat = 'Restoran';
      icon = '🍽️';
    } else if (amenity == 'school' || amenity == 'university') {
      hanzi = '学校';
      pinyin = 'Xuéxiào';
      arti = 'Sekolah / Kampus';
      cat = 'Kampus';
      icon = '🏫';
    } else if (tags['leisure'] == 'park') {
      hanzi = '公园';
      pinyin = 'Gōngyuán';
      arti = 'Taman';
      cat = 'Taman';
      icon = '🌲';
    } else if (tags['shop'] != null) {
      hanzi = '商店';
      pinyin = 'Shāngdiàn';
      arti = 'Toko';
      cat = 'Belanja';
      icon = '🏬';
    } else if (tags['tourism'] == 'hotel' || tags['tourism'] == 'guest_house') {
      hanzi = '酒店';
      pinyin = 'Jiǔdiàn';
      arti = 'Akomodasi';
      cat = 'Akomodasi';
      icon = '🏨';
    } else if (tags['public_transport'] != null ||
        tags['highway'] == 'bus_stop') {
      hanzi = '车站';
      pinyin = 'Chēzhàn';
      arti = 'Transportasi';
      cat = 'Transportasi';
      icon = '🚌';
    }

    return PlaceItem(
      nameId: name,
      nameZh: tags['name:zh']?.toString(),
      hanzi: hanzi,
      pinyin: pinyin,
      arti: arti,
      category: cat,
      iconEmoji: icon,
      latitude: latitude,
      longitude: longitude,
      osmType: element['type']?.toString() ?? 'node',
      osmId: (element['id'] as num?)?.toInt() ?? 0,
      relatedVocab: [
        RelatedVocab(hanzi: hanzi, pinyin: pinyin, arti: arti, iconEmoji: icon),
      ],
    );
  }

  // Jarak Haversine
  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadius = 6371000.0;
    final dLat = (lat2 - lat1) * (math.pi / 180);
    final dLon = (lon2 - lon1) * (math.pi / 180);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * (math.pi / 180)) *
            math.cos(lat2 * (math.pi / 180)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  // Bearing / Sudut Azimuth dari pengguna ke tempat
  double _calculateBearingDegrees(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    final phi1 = lat1 * (math.pi / 180);
    final phi2 = lat2 * (math.pi / 180);
    final deltaLambda = (lon2 - lon1) * (math.pi / 180);

    final y = math.sin(deltaLambda) * math.cos(phi2);
    final x =
        math.cos(phi1) * math.sin(phi2) -
        math.sin(phi1) * math.cos(phi2) * math.cos(deltaLambda);
    final theta = math.atan2(y, x);
    return (theta * (180 / math.pi) + 360) % 360;
  }

  String calculateBearing(double lat1, double lon1, double lat2, double lon2) {
    final deg = _calculateBearingDegrees(lat1, lon1, lat2, lon2);
    return _degreesToCardinal(deg);
  }

  ({String hanzi, String pinyin, String arti, String icon})
  _directionForDegrees(double degrees) {
    final normalized = (degrees % 360 + 360) % 360;
    // Tetap 4 arah mata angin utama: Utara (北), Timur (东), Selatan (南), Barat (西)
    if (normalized >= 315 || normalized < 45) {
      return (hanzi: '北', pinyin: 'Běi', arti: 'Utara', icon: '↑');
    }
    if (normalized >= 45 && normalized < 135) {
      return (hanzi: '东', pinyin: 'Dōng', arti: 'Timur', icon: '→');
    }
    if (normalized >= 135 && normalized < 225) {
      return (hanzi: '南', pinyin: 'Nán', arti: 'Selatan', icon: '↓');
    }
    return (hanzi: '西', pinyin: 'Xī', arti: 'Barat', icon: '←');
  }

  String _degreesToCardinal(double degrees) {
    final dir = _directionForDegrees(degrees);
    return '${dir.hanzi} (${dir.pinyin} - ${dir.arti})';
  }

  String _formatDistance(double meters) {
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  // Tampilkan Bottom Sheet: 2. Pilih Tempat
  void _openPlaceBottomSheet(PlaceItem place) {
    final userPos = _currentPosition;
    if (userPos == null) return;

    setState(() => _selectedPlace = place);
    if (_isMapReady) {
      _mapController.move(LatLng(place.latitude, place.longitude), 16);
    }

    final dist = _calculateDistance(
      userPos.latitude,
      userPos.longitude,
      place.latitude,
      place.longitude,
    );
    final bearingDeg = _calculateBearingDegrees(
      userPos.latitude,
      userPos.longitude,
      place.latitude,
      place.longitude,
    );
    final dir = _directionForDegrees(bearingDeg);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Place header info
              Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Text(
                        place.iconEmoji,
                        style: const TextStyle(fontSize: 28),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          place.nameId,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${place.category} • ${_formatDistance(dist)} • Di sebelah ${dir.arti.toLowerCase()}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Arah dari lokasi kamu
              InkWell(
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => _activeSubView = _ActiveSubView.compass);
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: AppColors.primaryGreen,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.explore_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Arah dari lokasi kamu (Kompas)',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textMuted,
                              ),
                            ),
                            Text(
                              '${dir.arti} (${dir.pinyin} - ${dir.hanzi})',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        dir.icon,
                        style: const TextStyle(
                          fontSize: 24,
                          color: AppColors.primaryGreen,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // Kosakata Mandarin box
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Kosakata Mandarin:',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFFB45309),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            place.hanzi,
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryDark,
                            ),
                          ),
                          Text(
                            '${place.pinyin} • ${place.arti}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryGreen,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.volume_up_rounded,
                        color: AppColors.primaryDark,
                        size: 28,
                      ),
                      onPressed: () => AudioService.instance.speak(place.hanzi),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        setState(
                          () => _activeSubView = _ActiveSubView.vocabDetail,
                        );
                      },
                      child: const Text('Detail Kosakata'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _showRouteView(place);
                      },
                      child: const Text(
                        'Lihat di Peta',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _showRouteView(PlaceItem place) {
    final userPos = _currentPosition;
    if (userPos == null) return;
    setState(() {
      _selectedPlace = place;
      _activeSubView = _ActiveSubView.routeMap;
      _isMapReady = false;
      _walkingRoutePoints = const [];
      _walkingRouteDistanceMeters = null;
      _walkingRouteDurationSeconds = null;
      _isLoadingWalkingRoute = true;
      _walkingRouteError = null;
    });
    _loadWalkingRoute(place, userPos);
  }

  Future<void> _loadWalkingRoute(PlaceItem place, Position origin) async {
    final uri = Uri.https(
      'routing.openstreetmap.de',
      '/routed-foot/route/v1/driving/'
          '${origin.longitude},${origin.latitude};'
          '${place.longitude},${place.latitude}',
      {
        'overview': 'full',
        'geometries': 'geojson',
        'steps': 'false',
      },
    );

    try {
      final response = await http
          .get(uri, headers: {'User-Agent': 'MandarinLearningApp/1.0'})
          .timeout(const Duration(seconds: 25));
      if (response.statusCode != 200) {
        throw StateError('Layanan rute mengembalikan HTTP ${response.statusCode}.');
      }

      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic> ||
          data['code'] != 'Ok' ||
          data['routes'] is! List ||
          (data['routes'] as List).isEmpty) {
        throw const FormatException('Rute jalan kaki tidak ditemukan.');
      }
      final route = (data['routes'] as List).first;
      if (route is! Map<String, dynamic> ||
          route['geometry'] is! Map<String, dynamic>) {
        throw const FormatException('Geometri rute tidak valid.');
      }
      final geometry = route['geometry'] as Map<String, dynamic>;
      final coordinates = geometry['coordinates'];
      if (coordinates is! List) {
        throw const FormatException('Koordinat rute tidak tersedia.');
      }
      final points = <LatLng>[];
      for (final coordinate in coordinates) {
        if (coordinate is! List ||
            coordinate.length < 2 ||
            coordinate[0] is! num ||
            coordinate[1] is! num) {
          continue;
        }
        points.add(
          LatLng(
            (coordinate[1] as num).toDouble(),
            (coordinate[0] as num).toDouble(),
          ),
        );
      }
      if (points.length < 2) {
        throw const FormatException('Jalur rute tidak cukup untuk ditampilkan.');
      }

      if (!mounted || _selectedPlace?.osmId != place.osmId) return;
      setState(() {
        _walkingRoutePoints = points;
        _walkingRouteDistanceMeters = (route['distance'] as num?)?.toDouble();
        _walkingRouteDurationSeconds = (route['duration'] as num?)?.toDouble();
        _isLoadingWalkingRoute = false;
      });
      _fitWalkingRouteOnMap(origin, place);
    } catch (error) {
      debugPrint('[DirectionExplorer] Walking route error: $error');
      if (!mounted || _selectedPlace?.osmId != place.osmId) return;
      setState(() {
        _walkingRoutePoints = const [];
        _walkingRouteDistanceMeters = null;
        _walkingRouteDurationSeconds = null;
        _isLoadingWalkingRoute = false;
        _walkingRouteError =
            'Rute jalan kaki belum tersedia. Kamu tetap bisa membuka rute asli di Google Maps.';
      });
    }
  }

  void _fitWalkingRouteOnMap(Position origin, PlaceItem place) {
    if (!_isMapReady) return;
    final points = [
      LatLng(origin.latitude, origin.longitude),
      ..._walkingRoutePoints,
      LatLng(place.latitude, place.longitude),
    ];
    _mapController.fitCamera(
      CameraFit.coordinates(
        coordinates: points,
        padding: const EdgeInsets.all(60),
      ),
    );
  }

  Future<void> _openExternalMap(PlaceItem place) async {
    final userPos = _currentPosition;
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&destination=${place.latitude},${place.longitude}'
      '${userPos != null ? '&origin=${userPos.latitude},${userPos.longitude}' : ''}'
      '&travelmode=walking',
    );
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Google Maps tidak dapat dibuka.')),
        );
      }
    } catch (error) {
      debugPrint('[DirectionExplorer] Google Maps launch error: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Google Maps tidak dapat dibuka.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (_activeSubView) {
      case _ActiveSubView.home:
        return _buildHomeView();
      case _ActiveSubView.compass:
        return _buildCompassView();
      case _ActiveSubView.vocabDetail:
        return _buildVocabDetailView();
      case _ActiveSubView.routeMap:
        return _buildRouteMapView();
      case _ActiveSubView.placeVocabList:
        return _buildPlaceVocabListView();
      case _ActiveSubView.cardinalDirections:
        return _buildCardinalDirectionsView();
    }
  }

  // ─────────────────────────────────────────────────────────────
  // 1. Tampilan Beranda Fitur
  // ─────────────────────────────────────────────────────────────
  Widget _buildHomeView() {
    final userPos = _currentPosition;
    final userCenter = userPos != null
        ? LatLng(userPos.latitude, userPos.longitude)
        : null;

    final categories = ['Semua', 'Kampus', 'Kafe', 'Restoran', 'Taman'];

    final filteredPlaces = _selectedCategory == 'Semua'
        ? _nearbyPlaces
        : _nearbyPlaces
              .where(
                (p) => p.category.toLowerCase().contains(
                  _selectedCategory.toLowerCase(),
                ),
              )
              .toList();

    return Scaffold(
      backgroundColor: AppColors.mintBackground,
      appBar: AppBar(
        title: const Text('Mandarin Direction Explorer'),
        actions: [
          IconButton(
            tooltip: 'Panduan Mata Angin',
            icon: const Icon(
              Icons.explore_rounded,
              color: AppColors.primaryGreen,
            ),
            onPressed: () => setState(
              () => _activeSubView = _ActiveSubView.cardinalDirections,
            ),
          ),
          IconButton(
            tooltip: 'Daftar Kosakata Tempat',
            icon: const Icon(
              Icons.menu_book_rounded,
              color: AppColors.primaryDark,
            ),
            onPressed: () =>
                setState(() => _activeSubView = _ActiveSubView.placeVocabList),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Mascot Box
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const MascotWidget(pose: MascotPose.waving, size: 50),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Mandarin Direction Explorer',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryDark,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Jelajahi sekitar, pelajari Mandarin!',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Lokasi kamu box
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.location_on_rounded,
                      color: AppColors.primaryGreen,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Lokasi kamu',
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.textMuted,
                            ),
                          ),
                          Text(
                            _currentLocationName,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.my_location_rounded, size: 18),
                      tooltip: 'Deteksi ulang lokasi',
                      onPressed: _loadCurrentLocation,
                    ),
                  ],
                ),
              ),
              if (_locationErrorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6, left: 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _locationErrorMessage!,
                      style: const TextStyle(
                        color: Color(0xFFB91C1C),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: 12),

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
                        selectedColor: AppColors.primaryGreen,
                        labelStyle: TextStyle(
                          color: isSel ? Colors.white : AppColors.textDark,
                          fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                          fontSize: 12,
                        ),
                        backgroundColor: Colors.white,
                        onSelected: (_) =>
                            setState(() => _selectedCategory = cat),
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 12),

              // Map Preview Box
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: SizedBox(
                  height: 240,
                  child: Stack(
                    children: [
                      if (userCenter == null)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Text(
                              _locationErrorMessage ??
                                  'Menunggu lokasi HP untuk memuat peta.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        )
                      else
                        FlutterMap(
                          mapController: _mapController,
                          options: MapOptions(
                            initialCenter: userCenter,
                            initialZoom: 15.5,
                            minZoom: 3,
                            maxZoom: 19,
                            onMapReady: () => _isMapReady = true,
                          ),
                          children: [
                            TileLayer(
                              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName:
                                  'com.example.mandarin_learning',
                            ),
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: userCenter,
                                  width: 34,
                                  height: 34,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2563EB),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 3,
                                      ),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Colors.black26,
                                          blurRadius: 6,
                                        ),
                                      ],
                                    ),
                                    child: const Center(
                                      child: Icon(
                                        Icons.person,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                ),
                                ...filteredPlaces.map(
                                  (place) => Marker(
                                    point: LatLng(
                                      place.latitude,
                                      place.longitude,
                                    ),
                                    width: 140,
                                    height: 62,
                                    child: GestureDetector(
                                      onTap: () => _openPlaceBottomSheet(place),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            width: 34,
                                            height: 34,
                                            decoration: BoxDecoration(
                                              color: _getCategoryColor(
                                                place.category,
                                              ),
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: Colors.white,
                                                width: 2.5,
                                              ),
                                              boxShadow: const [
                                                BoxShadow(
                                                  color: Colors.black26,
                                                  blurRadius: 4,
                                                ),
                                              ],
                                            ),
                                            child: Center(
                                              child: Text(
                                                place.iconEmoji,
                                                style: const TextStyle(
                                                  fontSize: 18,
                                                ),
                                              ),
                                            ),
                                          ),
                                          Container(
                                            constraints: const BoxConstraints(
                                              maxWidth: 136,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              boxShadow: const [
                                                BoxShadow(
                                                  color: Colors.black26,
                                                  blurRadius: 3,
                                                ),
                                              ],
                                            ),
                                            child: Text(
                                              place.nameId,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.textDark,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            RichAttributionWidget(
                              attributions: [
                                TextSourceAttribution(
                                  '© OpenStreetMap contributors',
                                  onTap: () {
                                    launchUrl(
                                      Uri.parse(
                                        'https://www.openstreetmap.org/copyright',
                                      ),
                                      mode: LaunchMode.externalApplication,
                                    );
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      // Mini Compass floating button
                      Positioned(
                        top: 10,
                        right: 10,
                        child: FloatingActionButton.small(
                          heroTag: 'compass_quick_btn',
                          backgroundColor: Colors.white,
                          onPressed: () => setState(
                            () => _activeSubView =
                                _ActiveSubView.cardinalDirections,
                          ),
                          child: const Icon(
                            Icons.explore_rounded,
                            color: AppColors.primaryGreen,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Tempat di Sekitar Section Title
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Tempat di sekitar',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  Text(
                    _isLoadingNearbyPlaces
                        ? 'Mencari...'
                        : '${filteredPlaces.length} lokasi',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Muat ulang tempat sekitar',
                    onPressed: userPos == null || _isLoadingNearbyPlaces
                        ? null
                        : () => _loadNearbyPlaces(userPos),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // List of Nearby Places
              if (_isLoadingNearbyPlaces)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (filteredPlaces.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Text(
                      _placesErrorMessage ??
                          (_locationErrorMessage ??
                              'Tempat sekitar akan muncul setelah lokasi HP terdeteksi.'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ...filteredPlaces.map((place) {
                if (userPos == null) return const SizedBox.shrink();
                final dist = _calculateDistance(
                  userPos.latitude,
                  userPos.longitude,
                  place.latitude,
                  place.longitude,
                );
                final bearing = _calculateBearingDegrees(
                  userPos.latitude,
                  userPos.longitude,
                  place.latitude,
                  place.longitude,
                );
                final dir = _directionForDegrees(bearing);

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 4,
                    ),
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: _getCategoryColor(place.category)
                            .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: Text(
                          place.iconEmoji,
                          style: const TextStyle(fontSize: 22),
                        ),
                      ),
                    ),
                    title: Text(
                      place.nameId,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text(
                      '${_formatDistance(dist)} • ${dir.arti} (${dir.hanzi})',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.textLight,
                    ),
                    onTap: () => _showRouteView(place),
                  ),
                );
              }),

              const SizedBox(height: 16),

              // Two Shortcut Cards: Mata Angin & Kosakata Tempat
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(
                        () =>
                            _activeSubView = _ActiveSubView.cardinalDirections,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFBBF7D0)),
                        ),
                        child: const Row(
                          children: [
                            Text('🧭', style: TextStyle(fontSize: 24)),
                            SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Mata Angin',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    '4 Arah Utama & Kompas',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(
                        () => _activeSubView = _ActiveSubView.placeVocabList,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: const Row(
                          children: [
                            Text('📖', style: TextStyle(fontSize: 24)),
                            SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Kosakata Tempat',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    'Daftar Tempat Mandarin',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 3. Tampilan Kompas (Real-time compass pointing to place)
  // ─────────────────────────────────────────────────────────────
  Widget _buildCompassView() {
    final userPos = _currentPosition;
    final place = _selectedPlace;
    if (userPos == null || place == null) return _buildHomeView();

    final dist = _calculateDistance(
      userPos.latitude,
      userPos.longitude,
      place.latitude,
      place.longitude,
    );
    final targetBearing = _calculateBearingDegrees(
      userPos.latitude,
      userPos.longitude,
      place.latitude,
      place.longitude,
    );
    final dir = _directionForDegrees(targetBearing);

    // Needle rotation angle (target relative to phone heading)
    final relativeAngle = (targetBearing - _headingDegrees) * (math.pi / 180);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: AppColors.textDark),
          onPressed: () => setState(() => _activeSubView = _ActiveSubView.home),
        ),
        title: Column(
          children: [
            Text(
              place.nameId,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            Text(
              '${_formatDistance(dist)} • ${dir.arti}',
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Big Compass Dial
              Center(
                child: SizedBox(
                  width: 260,
                  height: 260,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Compass Outer Dial with Degrees & N, E, S, W
                      Transform.rotate(
                        angle: -_headingDegrees * (math.pi / 180),
                        child: CustomPaint(
                          size: const Size(260, 260),
                          painter: _CompassDialPainter(),
                        ),
                      ),
                      // Rotating Needle pointing to target place
                      Transform.rotate(
                        angle: relativeAngle,
                        child: SizedBox(
                          width: 44,
                          height: 200,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Positioned(
                                top: 10,
                                child: Container(
                                  width: 22,
                                  height: 80,
                                  decoration: const BoxDecoration(
                                    color: AppColors.primaryGreen,
                                    borderRadius: BorderRadius.vertical(
                                      top: Radius.circular(12),
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.arrow_drop_up_rounded,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 10,
                                child: Container(
                                  width: 14,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[400],
                                    borderRadius: const BorderRadius.vertical(
                                      bottom: Radius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                              Container(
                                width: 18,
                                height: 18,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF0F172A),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Text(
                _isCompassAvailable
                    ? 'Arah HP: ${_directionForDegrees(_headingDegrees).arti} '
                          '(${_headingDegrees.round()}°)'
                    : 'Sensor kompas tidak tersedia',
                style: TextStyle(
                  color: _isCompassAvailable
                      ? AppColors.primaryDark
                      : Colors.orange.shade800,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),

              // Direction Badge below compass
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.location_on_rounded,
                      color: AppColors.primaryGreen,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            place.nameId,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            'Di sebelah ${dir.arti} kamu',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        color: AppColors.primaryGreen,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          dir.hanzi,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // "Tahukah kamu?" tip box
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('💡', style: TextStyle(fontSize: 22)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Tahukah kamu?',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Color(0xFFB45309),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Dalam bahasa Mandarin, arah ${dir.arti} disebut ${dir.hanzi} (${dir.pinyin}).',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF92400E),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 4. Kosakata Detail (View 4 in Mockup)
  // ─────────────────────────────────────────────────────────────
  Widget _buildVocabDetailView() {
    final userPos = _currentPosition;
    final place = _selectedPlace;
    if (userPos == null || place == null) return _buildHomeView();

    final dist = _calculateDistance(
      userPos.latitude,
      userPos.longitude,
      place.latitude,
      place.longitude,
    );
    final dir = _directionForDegrees(
      _calculateBearingDegrees(
        userPos.latitude,
        userPos.longitude,
        place.latitude,
        place.longitude,
      ),
    );

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => setState(() => _activeSubView = _ActiveSubView.home),
        ),
        title: Text(place.nameId),
        actions: [
          IconButton(
            icon: const Icon(Icons.star_border_rounded),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Tersimpan ke Koleksi Kosakata Favorit ⭐'),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Photo / Illustration banner
              Container(
                height: 160,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _getCategoryColor(place.category).withValues(alpha: 0.3),
                      _getCategoryColor(place.category).withValues(alpha: 0.8),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: Text(
                    place.iconEmoji,
                    style: const TextStyle(fontSize: 64),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Category tag & name
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    place.nameId,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      place.category,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFB45309),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Big Hanzi + Pinyin + Audio
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            place.hanzi,
                            style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryDark,
                            ),
                          ),
                          Text(
                            place.pinyin,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryGreen,
                            ),
                          ),
                          Text(
                            place.arti,
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.volume_up_rounded,
                        color: AppColors.primaryGreen,
                        size: 32,
                      ),
                      onPressed: () => AudioService.instance.speak(place.hanzi),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Lokasi & Arah
              const Text(
                'Lokasi & Arah',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.location_on_rounded,
                    size: 18,
                    color: AppColors.primaryGreen,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${_formatDistance(dist)} dari lokasi kamu',
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(
                    Icons.explore_rounded,
                    size: 18,
                    color: AppColors.primaryGreen,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Di sebelah ${dir.arti} (${dir.pinyin} - ${dir.hanzi})',
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Kosakata Terkait
              const Text(
                'Kosakata Terkait',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 10),
              ...place.relatedVocab.map((rel) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Text(rel.iconEmoji, style: const TextStyle(fontSize: 20)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Row(
                          children: [
                            Text(
                              rel.hanzi,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              rel.pinyin,
                              style: const TextStyle(
                                color: AppColors.primaryGreen,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              rel.arti,
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.volume_up_rounded,
                          size: 20,
                          color: AppColors.primaryDark,
                        ),
                        onPressed: () => AudioService.instance.speak(rel.hanzi),
                      ),
                    ],
                  ),
                );
              }),

              const SizedBox(height: 16),

              // Panda Mascot Tip
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const MascotWidget(pose: MascotPose.studying, size: 48),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Kamu juga bisa menemukan kosakata ini di tempat lain seperti restoran dan kantin.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textDark,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 5. Fitur Peta Detail Lokasi & Rute (View 5 in Mockup)
  // ─────────────────────────────────────────────────────────────
  Widget _buildRouteMapView() {
    final userPos = _currentPosition;
    final place = _selectedPlace;
    if (userPos == null || place == null) return _buildHomeView();

    final userCenter = LatLng(userPos.latitude, userPos.longitude);
    final placeLatLng = LatLng(place.latitude, place.longitude);

    final directDistance = _calculateDistance(
      userPos.latitude,
      userPos.longitude,
      place.latitude,
      place.longitude,
    );
    final dist = _walkingRouteDistanceMeters ?? directDistance;
    final dir = _directionForDegrees(
      _calculateBearingDegrees(
        userPos.latitude,
        userPos.longitude,
        place.latitude,
        place.longitude,
      ),
    );

    final walkingMinutes = _walkingRouteDurationSeconds != null
        ? math.max(1, (_walkingRouteDurationSeconds! / 60).round())
        : math.max(1, (directDistance / 80).round());

    return Scaffold(
      body: Stack(
        children: [
          // Interactive Map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: placeLatLng,
              initialZoom: 16,
              minZoom: 3,
              maxZoom: 19,
              onMapReady: () {
                _isMapReady = true;
                _fitWalkingRouteOnMap(userPos, place);
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.mandarin_learning',
              ),
              RichAttributionWidget(
                attributions: [
                  TextSourceAttribution(
                    '© OpenStreetMap contributors',
                    onTap: () {
                      launchUrl(
                        Uri.parse('https://www.openstreetmap.org/copyright'),
                        mode: LaunchMode.externalApplication,
                      );
                    },
                  ),
                ],
              ),
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: _walkingRoutePoints.length >= 2
                        ? _walkingRoutePoints
                        : [userCenter, placeLatLng],
                    strokeWidth: 5,
                    color: const Color(0xFF16A34A),
                    borderStrokeWidth: 2,
                    borderColor: Colors.white,
                  ),
                ],
              ),
              MarkerLayer(
                markers: [
                  // User Location Pin
                  Marker(
                    point: userCenter,
                    width: 32,
                    height: 32,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: const [
                          BoxShadow(color: Colors.black26, blurRadius: 4),
                        ],
                      ),
                      child: const Icon(
                        Icons.person,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                  // Destination Pin
                  Marker(
                    point: placeLatLng,
                    width: 50,
                    height: 50,
                    child: Container(
                      decoration: BoxDecoration(
                        color: _getCategoryColor(place.category),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: const [
                          BoxShadow(color: Colors.black26, blurRadius: 6),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          place.iconEmoji,
                          style: const TextStyle(fontSize: 22),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Header Card
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Text(place.iconEmoji, style: const TextStyle(fontSize: 24)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            place.nameId,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            '${place.hanzi} (${place.pinyin}) · ${_formatDistance(dist)} · ${dir.arti}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () =>
                          setState(() => _activeSubView = _ActiveSubView.home),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Direction Floating Pill
          Positioned(
            right: 16,
            bottom: 90,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 6),
                ],
              ),
              child: Row(
                children: [
                  Text(
                    dir.icon,
                    style: const TextStyle(
                      color: AppColors.primaryGreen,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${dir.arti} (${dir.hanzi})',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Info Bar & Navigation Flow
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Alur Perjalanan Heading
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Color(0xFFDCFCE7),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.alt_route_rounded,
                          color: Color(0xFF15803D),
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Alur Rute Perjalanan (路线)',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${_formatDistance(dist)} • $walkingMinutes mnt jalan',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Step 1: Titik Awal (Lokasi Pengguna)
                  Row(
                    children: [
                      const Icon(Icons.my_location_rounded, size: 16, color: Color(0xFF2563EB)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Titik Awal: ${_currentLocationName.isNotEmpty ? _currentLocationName : 'Lokasi Anda'}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textDark),
                        ),
                      ),
                    ],
                  ),

                  // Jalur Alur Vertikal
                  Container(
                    margin: const EdgeInsets.only(left: 7),
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 14),
                    decoration: const BoxDecoration(
                      border: Border(
                        left: BorderSide(color: Color(0xFF22C55E), width: 2.5),
                      ),
                    ),
                    child: Text(
                      'Menghadap ke arah ${dir.arti} (${dir.hanzi} - ${dir.pinyin}) sejauh ${_formatDistance(dist)}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF15803D),
                      ),
                    ),
                  ),

                  // Step 2: Titik Tujuan
                  Row(
                    children: [
                      const Icon(Icons.location_on_rounded, size: 18, color: Color(0xFFDC2626)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Tujuan: ${place.nameId} (${place.hanzi} - ${place.pinyin})',
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Tombol Aksi Navigasi & Kompas
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF22C55E), width: 1.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            padding: const EdgeInsets.symmetric(vertical: 11),
                          ),
                          onPressed: () => setState(() => _activeSubView = _ActiveSubView.compass),
                          icon: const Icon(Icons.explore_rounded, color: Color(0xFF15803D), size: 18),
                          label: const Text('Kompas Arah', style: TextStyle(color: Color(0xFF15803D), fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            elevation: 1,
                          ),
                          onPressed: () => _openExternalMap(place),
                          icon: const Icon(Icons.navigation_rounded, size: 18),
                          label: const Text('Google Maps', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 6. Daftar Kosakata Tempat (View 6 in Mockup)
  // ─────────────────────────────────────────────────────────────
  Widget _buildPlaceVocabListView() {
    final categories = ['Semua', 'Kampus', 'Kafe', 'Restoran', 'Taman'];

    final vocabItems = [
      (
        hanzi: '学校',
        pinyin: 'Xuéxiào',
        arti: 'Sekolah / Kampus',
        category: 'Kampus',
        icon: '🏫',
      ),
      (
        hanzi: '餐厅',
        pinyin: 'Cāntīng',
        arti: 'Restoran',
        category: 'Restoran',
        icon: '🍽️',
      ),
      (
        hanzi: '公园',
        pinyin: 'Gōngyuán',
        arti: 'Taman',
        category: 'Taman',
        icon: '🌲',
      ),
      (
        hanzi: '车站',
        pinyin: 'Chēzhàn',
        arti: 'Stasiun',
        category: 'Transportasi',
        icon: '🚌',
      ),
      (
        hanzi: '商店',
        pinyin: 'Shāngdiàn',
        arti: 'Toko',
        category: 'Belanja',
        icon: '🏬',
      ),
      (
        hanzi: '咖啡馆',
        pinyin: 'Kāfēiguǎn',
        arti: 'Kafe',
        category: 'Kafe',
        icon: '☕',
      ),
      (
        hanzi: '图书馆',
        pinyin: 'Túshūguǎn',
        arti: 'Perpustakaan',
        category: 'Kampus',
        icon: '🏛️',
      ),
      (
        hanzi: '医院',
        pinyin: 'Yīyuàn',
        arti: 'Rumah Sakit',
        category: 'Kesehatan',
        icon: '🏥',
      ),
      (
        hanzi: '银行',
        pinyin: 'Yínháng',
        arti: 'Bank',
        category: 'Keuangan',
        icon: '🏦',
      ),
    ];

    final filtered = _selectedCategory == 'Semua'
        ? vocabItems
        : vocabItems
              .where(
                (v) => v.category.toLowerCase().contains(
                  _selectedCategory.toLowerCase(),
                ),
              )
              .toList();

    return Scaffold(
      backgroundColor: AppColors.mintBackground,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => setState(() => _activeSubView = _ActiveSubView.home),
        ),
        title: const Text('Kosakata Tempat'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Category Chips
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: categories.map((cat) {
                    final isSel = _selectedCategory == cat;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(cat),
                        selected: isSel,
                        selectedColor: AppColors.primaryGreen,
                        labelStyle: TextStyle(
                          color: isSel ? Colors.white : AppColors.textDark,
                          fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                        ),
                        backgroundColor: Colors.white,
                        onSelected: (_) =>
                            setState(() => _selectedCategory = cat),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

            // Vocab List
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: filtered.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final item = filtered[i];
                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ListTile(
                      leading: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            item.icon,
                            style: const TextStyle(fontSize: 22),
                          ),
                        ),
                      ),
                      title: Row(
                        children: [
                          Text(
                            item.hanzi,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            item.pinyin,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.primaryGreen,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      subtitle: Text(
                        item.arti,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                      trailing: IconButton(
                        icon: const Icon(
                          Icons.volume_up_rounded,
                          color: AppColors.primaryDark,
                        ),
                        onPressed: () =>
                            AudioService.instance.speak(item.hanzi),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 7. Mata Angin (View 7 in Mockup)
  // ─────────────────────────────────────────────────────────────
  Widget _buildCardinalDirectionsView() {
    final cardinalItems = [
      (
        hanzi: '北',
        pinyin: 'Běi',
        arti: 'Utara',
        arrow: '↑',
        color: const Color(0xFF3B82F6),
      ),
      (
        hanzi: '东',
        pinyin: 'Dōng',
        arti: 'Timur',
        arrow: '→',
        color: const Color(0xFFF59E0B),
      ),
      (
        hanzi: '南',
        pinyin: 'Nán',
        arti: 'Selatan',
        arrow: '↓',
        color: const Color(0xFFEF4444),
      ),
      (
        hanzi: '西',
        pinyin: 'Xī',
        arti: 'Barat',
        arrow: '←',
        color: const Color(0xFF10B981),
      ),
    ];

    final currentHeadingDir = _directionForDegrees(_headingDegrees);

    return Scaffold(
      backgroundColor: AppColors.mintBackground,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => setState(() => _activeSubView = _ActiveSubView.home),
        ),
        title: const Text('Mata Angin (方向 - Fāngxiàng)'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Live phone orientation header banner
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Rotating mini compass
                  Transform.rotate(
                    angle: -_headingDegrees * (math.pi / 180),
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF1F5F9),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.navigation_rounded,
                          color: Colors.red,
                          size: 28,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isCompassAvailable
                              ? 'Arah kompas HP: ${_headingDegrees.toStringAsFixed(0)}°'
                              : 'Sensor kompas tidak tersedia',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                        Text(
                          _isCompassAvailable
                              ? '${currentHeadingDir.arti} (${currentHeadingDir.hanzi} - ${currentHeadingDir.pinyin})'
                              : 'Periksa sensor magnetometer HP',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Cardinal List
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: 5,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  if (i == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 4, bottom: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.explore,
                              size: 18, color: AppColors.primaryGreen),
                          const SizedBox(width: 8),
                          const Text(
                            '4 Arah Utama Kompas (四大主方向)',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryGreen,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  final itemIndex = i - 1;
                  final item = cardinalItems[itemIndex];
                  final abbreviation = const ['U', 'T', 'S', 'B'][itemIndex];
                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ListTile(
                      leading: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: item.color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Center(
                          child: Text(
                            item.arrow,
                            style: TextStyle(
                              fontSize: 22,
                              color: item.color,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      title: Row(
                        children: [
                          Text(
                            item.hanzi,
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            item.pinyin,
                            style: TextStyle(
                              fontSize: 13,
                              color: item.color,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (itemIndex < 4) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: item.color.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(abbreviation, style: TextStyle(
                                fontSize: 11, fontWeight: FontWeight.bold, color: item.color,
                              )),
                            ),
                          ],
                        ],
                      ),
                      subtitle: Text(
                        item.arti,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                      trailing: IconButton(
                        icon: const Icon(
                          Icons.volume_up_rounded,
                          color: AppColors.primaryDark,
                        ),
                        onPressed: () =>
                            AudioService.instance.speak(item.hanzi),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Bottom tip box
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.explore_outlined, color: AppColors.primaryGreen),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Coba arahkan ponsel kamu untuk melihat arah yang sebenarnya di sekitar kamu.',
                      style: TextStyle(fontSize: 11, color: AppColors.textDark),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getCategoryColor(String cat) {
    final lower = cat.toLowerCase();
    if (lower.contains('kafe') || lower.contains('cafe')) {
      return const Color(0xFFF59E0B);
    }
    if (lower.contains('kampus') || lower.contains('sekolah')) {
      return const Color(0xFF8B5CF6);
    }
    if (lower.contains('restoran') || lower.contains('makan')) {
      return const Color(0xFFEF4444);
    }
    if (lower.contains('taman') || lower.contains('park')) {
      return const Color(0xFF10B981);
    }
    if (lower.contains('transport') || lower.contains('stasiun')) {
      return const Color(0xFF3B82F6);
    }
    return AppColors.primaryDark;
  }
}

enum _ActiveSubView {
  home,
  compass,
  vocabDetail,
  routeMap,
  placeVocabList,
  cardinalDirections,
}

// ─────────────────────────────────────────────────────────────
// Custom Painter for Compass Dial
// ─────────────────────────────────────────────────────────────
class _CompassDialPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Outer background circle
    final bgPaint = Paint()
      ..color = const Color(0xFFF8FAFC)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius - 4, bgPaint);

    final borderPaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(center, radius - 4, borderPaint);

    // Degree tick marks
    final tickPaint = Paint()
      ..color = const Color(0xFFCBD5E1)
      ..strokeWidth = 1.5;

    final majorTickPaint = Paint()
      ..color = const Color(0xFF64748B)
      ..strokeWidth = 2.5;

    for (int i = 0; i < 360; i += 15) {
      final angle = i * (math.pi / 180) - (math.pi / 2);
      final isMajor = i % 90 == 0;
      final tickLength = isMajor ? 14.0 : 8.0;

      final startX = center.dx + (radius - 10) * math.cos(angle);
      final startY = center.dy + (radius - 10) * math.sin(angle);
      final endX = center.dx + (radius - 10 - tickLength) * math.cos(angle);
      final endY = center.dy + (radius - 10 - tickLength) * math.sin(angle);

      canvas.drawLine(
        Offset(startX, startY),
        Offset(endX, endY),
        isMajor ? majorTickPaint : tickPaint,
      );
    }

    // Cardinal Labels: N (Utara), E (Timur), S (Selatan), W (Barat)
    void drawText(String text, Offset pos, Color color, {bool bold = true}) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            fontSize: 16,
            fontWeight: bold ? FontWeight.bold : FontWeight.w500,
            color: color,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(
        canvas,
        Offset(pos.dx - textPainter.width / 2, pos.dy - textPainter.height / 2),
      );
    }

    drawText(
      '北\nN',
      Offset(center.dx, center.dy - radius + 34),
      const Color(0xFFEF4444),
    );
    drawText(
      '东\nE',
      Offset(center.dx + radius - 34, center.dy),
      const Color(0xFF0F172A),
    );
    drawText(
      '南\nS',
      Offset(center.dx, center.dy + radius - 34),
      const Color(0xFF0F172A),
    );
    drawText(
      '西\nW',
      Offset(center.dx - radius + 34, center.dy),
      const Color(0xFF0F172A),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
