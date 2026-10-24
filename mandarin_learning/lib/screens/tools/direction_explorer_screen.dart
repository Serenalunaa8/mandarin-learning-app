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
// import '../../services/nearby_places_query.dart';

// FR-11 & FR-12: Direction Explorer dengan GPS Real Device, In-Map Compass,
// Pencarian Tempat Pintar, dan Konversi 3 Mata Uang (CNY, IDR, USD) Kontekstual

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
  final String? description;
  final List<RelatedVocab> relatedVocab;
  final double minPriceCny;
  final double maxPriceCny;

  const PlaceItem({
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
    this.description,
    this.relatedVocab = const [],
    this.minPriceCny = 20.0,
    this.maxPriceCny = 80.0,
  });
}

class DirectionExplorerScreen extends StatefulWidget {
  const DirectionExplorerScreen({super.key});

  @override
  State<DirectionExplorerScreen> createState() => _DirectionExplorerScreenState();
}

class _DirectionExplorerScreenState extends State<DirectionExplorerScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();

  // State GPS & Lokasi
  Position? _currentPosition;
  String _currentLocationName = 'Mendeteksi koordinat GPS...';
  bool _isLocationServiceDisabled = false;
  bool _isLocationPermissionDenied = false;
  String? _locationErrorMessage;
  bool _isLoadingNearbyPlaces = false;
  String? _placesErrorMessage;

  // Sensor Kompas (Magnetometer + Accelerometer)
  StreamSubscription<MagnetometerEvent>? _magnetometerSub;
  StreamSubscription<AccelerometerEvent>? _accelerometerSub;
  StreamSubscription<Position>? _locationSub;
  double _headingDegrees = 0.0;
  double? _smoothedHeadingDegrees;
  AccelerometerEvent? _latestAcceleration;
  MagnetometerEvent? _latestMagneticField;
  bool _isCompassAvailable = false;

  // Kategori filter terpilih
  String _selectedCategory = 'Semua';

  // Daftar tempat sekitar & hasil pencarian
  List<PlaceItem> _nearbyPlaces = [];
  List<PlaceItem> _searchResults = [];
  bool _isSearching = false;

  // Tempat terpilih untuk navigasi rute
  PlaceItem? _selectedPlace;
  List<LatLng> _walkingRoutePoints = [];
  double? _walkingRouteDistanceMeters;
  double? _walkingRouteDurationSeconds;

  bool _isMapReady = false;
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
    _searchController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _initLocationAndCompass() async {
    try {
      _magnetometerSub = magnetometerEventStream(
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

      _accelerometerSub = accelerometerEventStream(
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
      _currentLocationName = 'Mendeteksi koordinat GPS...';
      _isLoadingNearbyPlaces = true;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          setState(() {
            _isLocationServiceDisabled = true;
            _locationErrorMessage = 'GPS HP belum aktif. Silakan aktifkan layanan lokasi.';
            _currentLocationName = 'GPS Tidak Aktif';
            _isLoadingNearbyPlaces = false;
          });
        }
        return;
      } else {
        if (mounted) setState(() => _isLocationServiceDisabled = false);
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            setState(() {
              _isLocationPermissionDenied = true;
              _locationErrorMessage = 'Izin lokasi belum diberikan.';
              _currentLocationName = 'Izin Lokasi Diperlukan';
              _isLoadingNearbyPlaces = false;
            });
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _isLocationPermissionDenied = true;
            _locationErrorMessage = 'Izin lokasi ditolak permanen. Buka Pengaturan HP untuk mengizinkan.';
            _currentLocationName = 'Izin Lokasi Ditolak';
            _isLoadingNearbyPlaces = false;
          });
        }
        return;
      }

      // 1. Ambil posisi terakhir yang tersimpan di HP agar langsung tampil seketika
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null && mounted) {
        _applyLocation(lastKnown, 'Lokasi Terkini HP');
      }

      // 2. Pasang pendengar stream lokasi agar peta langsung menerima koordinat riil seketika
      _locationSub ??= Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).listen(
        (pos) {
          if (!mounted) return;
          final previous = _currentPosition;
          if (previous == null ||
              _calculateDistance(previous.latitude, previous.longitude, pos.latitude, pos.longitude) >= 15) {
            _applyLocation(pos, 'Lokasi Real-Time');
          } else {
            setState(() => _currentPosition = pos);
          }
        },
        onError: (err) {
          debugPrint('[DirectionExplorer] Location stream error: $err');
        },
      );

      // 3. Ambil posisi GPS real-time akurasi tinggi dengan fallback cepat
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 5),
          ),
        );
      } catch (_) {
        try {
          position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.medium,
              timeLimit: Duration(seconds: 4),
            ),
          );
        } catch (_) {}
      }

      if (position != null && mounted) {
        _applyLocation(position, 'Lokasi GPS Akurat');
      } else if (lastKnown == null && mounted && _currentPosition == null) {
        setState(() {
          _locationErrorMessage = 'Menunggu sinyal GPS perangkat... Pastikan GPS HP aktif.';
          _isLoadingNearbyPlaces = false;
        });
      }
    } catch (e) {
      debugPrint('[DirectionExplorer] GPS error: $e');
    }
  }

  void _applyLocation(Position position, String label) {
    if (!mounted) return;
    setState(() {
      _currentPosition = position;
      _currentLocationName =
          '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)} ($label)';
      _locationErrorMessage = null;
      _isLocationServiceDisabled = false;
      _isLocationPermissionDenied = false;
    });

    if (_isMapReady) {
      _mapController.move(
        LatLng(position.latitude, position.longitude),
        15.5,
      );
    }
    _loadNearbyPlaces(position);
  }

  // Menghasilkan tempat awal kontekstual di sekitar koordinat nyata pengguna
  List<PlaceItem> _generateNearbyContextualPlaces(double lat, double lon) {
    return [
      PlaceItem(
        nameId: 'Kedai Kopi & Teh Nusantara',
        nameZh: '休闲咖啡馆',
        hanzi: '咖啡馆',
        pinyin: 'Kāfēiguǎn',
        arti: 'Kafe Kopi & Teh',
        category: 'Kafe',
        iconEmoji: '☕',
        latitude: lat + 0.0016,
        longitude: lon + 0.0014,
        osmType: 'node',
        osmId: 101,
        minPriceCny: 15.0,
        maxPriceCny: 45.0,
        description: 'Kedai kopi dan teh santai terdekat dengan aneka kopi artisan, teh melati, dan camilan.',
        relatedVocab: const [
          RelatedVocab(hanzi: '咖啡', pinyin: 'kāfēi', arti: 'Kopi', iconEmoji: '☕'),
          RelatedVocab(hanzi: '茶', pinyin: 'chá', arti: 'Teh', iconEmoji: '🍵'),
          RelatedVocab(hanzi: '点心', pinyin: 'diǎnxīn', arti: 'Camilan', iconEmoji: '🥐'),
        ],
      ),
      PlaceItem(
        nameId: 'Butik Busana & Toko Baju Tren',
        nameZh: '时尚服装精品店',
        hanzi: '服装店',
        pinyin: 'Fúzhuāngdiàn',
        arti: 'Toko Busana / Butik',
        category: 'Toko Baju',
        iconEmoji: '👗',
        latitude: lat + 0.0022,
        longitude: lon - 0.0018,
        osmType: 'node',
        osmId: 102,
        minPriceCny: 80.0,
        maxPriceCny: 350.0,
        description: 'Butik pakaian menyediakan kemeja kasual, dress gaun, celana, dan jaket tren terkini.',
        relatedVocab: const [
          RelatedVocab(hanzi: '衣服', pinyin: 'yīfu', arti: 'Pakaian / Baju', iconEmoji: '👕'),
          RelatedVocab(hanzi: '衬衫', pinyin: 'chènshān', arti: 'Kemeja', iconEmoji: '👔'),
          RelatedVocab(hanzi: '裙子', pinyin: 'qúnzi', arti: 'Rok / Gaun', iconEmoji: '👗'),
        ],
      ),
      PlaceItem(
        nameId: 'Hotel Wisatawan Nyaman',
        nameZh: '舒适快捷酒店',
        hanzi: '酒店',
        pinyin: 'Jiǔdiàn',
        arti: 'Hotel / Akomodasi',
        category: 'Hotel',
        iconEmoji: '🏨',
        latitude: lat - 0.0020,
        longitude: lon + 0.0025,
        osmType: 'node',
        osmId: 103,
        minPriceCny: 200.0,
        maxPriceCny: 650.0,
        description: 'Hotel penginapan bersih dengan fasilitas lengkap, sarapan, dan kamar ber-AC.',
        relatedVocab: const [
          RelatedVocab(hanzi: '酒店', pinyin: 'jiǔdiàn', arti: 'Hotel', iconEmoji: '🏨'),
          RelatedVocab(hanzi: '房间', pinyin: 'fángjiān', arti: 'Kamar', iconEmoji: '🛏️'),
          RelatedVocab(hanzi: '预订', pinyin: 'yùdìng', arti: 'Pesan / Booking', iconEmoji: '📅'),
        ],
      ),
      PlaceItem(
        nameId: 'Restoran Masakan Khas & Kuliner Lezat',
        nameZh: '特色风味餐厅',
        hanzi: '餐厅',
        pinyin: 'Cāntīng',
        arti: 'Restoran Kuliner',
        category: 'Restoran',
        iconEmoji: '🍽️',
        latitude: lat - 0.0018,
        longitude: lon - 0.0022,
        osmType: 'node',
        osmId: 104,
        minPriceCny: 30.0,
        maxPriceCny: 120.0,
        description: 'Restoran masakan hangat dengan aneka hidangan khas gurih, daging, ayam, dan kuah spesial.',
        relatedVocab: const [
          RelatedVocab(hanzi: '面条', pinyin: 'miàntiáo', arti: 'Mie', iconEmoji: '🍜'),
          RelatedVocab(hanzi: '牛肉', pinyin: 'niúròu', arti: 'Daging sapi', iconEmoji: '🥩'),
          RelatedVocab(hanzi: '好吃', pinyin: 'hǎochī', arti: 'Enak / Lezat', iconEmoji: '😋'),
        ],
      ),
      PlaceItem(
        nameId: 'Halte & Stasiun Transportasi',
        nameZh: '城市公共交通车站',
        hanzi: '车站',
        pinyin: 'Chēzhàn',
        arti: 'Stasiun / Halte Transportasi',
        category: 'Transportasi',
        iconEmoji: '🚆',
        latitude: lat + 0.0019,
        longitude: lon - 0.0015,
        osmType: 'node',
        osmId: 106,
        description: 'Titik transportasi publik lokal (halte bus / stasiun kereta) untuk mobilitas harian.',
        relatedVocab: const [
          RelatedVocab(hanzi: '车站', pinyin: 'chēzhàn', arti: 'Stasiun / Halte', iconEmoji: '🚆'),
          RelatedVocab(hanzi: '公交车', pinyin: 'gōngjiāochē', arti: 'Bus umum', iconEmoji: '🚌'),
          RelatedVocab(hanzi: '地铁', pinyin: 'dìtiě', arti: 'Kereta bawah tanah (Metro)', iconEmoji: '🚇'),
          RelatedVocab(hanzi: '买票', pinyin: 'mǎi piào', arti: 'Beli tiket', iconEmoji: '🎟️'),
        ],
      ),
      PlaceItem(
        nameId: 'Taman Terbuka Rekreasi Asri',
        nameZh: '城市绿色公园',
        hanzi: '公园',
        pinyin: 'Gōngyuán',
        arti: 'Taman Terbuka Hijau',
        category: 'Taman',
        iconEmoji: '🌳',
        latitude: lat + 0.0030,
        longitude: lon + 0.0032,
        osmType: 'node',
        osmId: 105,
        minPriceCny: 10.0,
        maxPriceCny: 50.0,
        description: 'Taman kota asri untuk jalan santai pagi, menghirup udara segar, dan olahraga ringan.',
        relatedVocab: const [
          RelatedVocab(hanzi: '公园', pinyin: 'gōngyuán', arti: 'Taman kota', iconEmoji: '🌳'),
          RelatedVocab(hanzi: '散步', pinyin: 'sànbù', arti: 'Jalan santai', iconEmoji: '🚶'),
          RelatedVocab(hanzi: '树木', pinyin: 'shùmù', arti: 'Pepohonan', iconEmoji: '🌲'),
        ],
      ),
    ];
  }

  Future<void> _loadNearbyPlaces(Position position) async {
    if (!mounted) return;

    setState(() {
      _isLoadingNearbyPlaces = true;
      _placesErrorMessage = null;
    });

    final realPlaces = <PlaceItem>[];

    // 1. Ambil tempat-tempat nyata terdekat via Nominatim bounding box di sekitar GPS perangkat
    try {
      final minLon = position.longitude - 0.055;
      final maxLat = position.latitude + 0.055;
      final maxLon = position.longitude + 0.055;
      final minLat = position.latitude - 0.055;

      final categoriesToFetch = [
        ('stasiun halte bus', 'Transportasi', '车站', 'Chēzhàn', '🚆', 5.0, 25.0),
        ('cafe', 'Kafe', '咖啡馆', 'Kāfēiguǎn', '☕', 15.0, 45.0),
        ('restaurant', 'Restoran', '餐厅', 'Cāntīng', '🍽️', 30.0, 120.0),
        ('hotel', 'Hotel', '酒店', 'Jiǔdiàn', '🏨', 200.0, 650.0),
        ('clothes', 'Toko Baju', '服装店', 'Fúzhuāngdiàn', '👗', 80.0, 350.0),
      ];

      for (final cat in categoriesToFetch) {
        final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
          'format': 'json',
          'q': cat.$1,
          'viewbox': '$minLon,$maxLat,$maxLon,$minLat',
          'bounded': '1',
          'limit': '5',
          'addressdetails': '1',
        });
        final res = await http.get(uri, headers: {
          'User-Agent': 'MandarinLearningApp/1.0',
          'Accept-Language': 'id,en',
        }).timeout(const Duration(seconds: 4));

        if (res.statusCode == 200) {
          final decoded = jsonDecode(res.body);
          if (decoded is List) {
            for (final item in decoded) {
              if (item is! Map<String, dynamic>) continue;
              final name = item['display_name']?.toString().split(',')[0].trim() ?? '';
              final lat = double.tryParse(item['lat']?.toString() ?? '');
              final lon = double.tryParse(item['lon']?.toString() ?? '');
              if (name.isEmpty || lat == null || lon == null) continue;

              if (!realPlaces.any((p) => p.nameId.toLowerCase() == name.toLowerCase())) {
                realPlaces.add(
                  PlaceItem(
                    nameId: name,
                    hanzi: cat.$3,
                    pinyin: cat.$4,
                    arti: cat.$2,
                    category: cat.$2,
                    iconEmoji: cat.$5,
                    latitude: lat,
                    longitude: lon,
                    osmType: 'node',
                    osmId: DateTime.now().millisecondsSinceEpoch + realPlaces.length,
                    minPriceCny: cat.$6,
                    maxPriceCny: cat.$7,
                    relatedVocab: [
                      RelatedVocab(hanzi: cat.$3, pinyin: cat.$4, arti: cat.$2, iconEmoji: cat.$5),
                    ],
                  ),
                );
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[DirectionExplorer] Error loading Nominatim nearby: $e');
    }

    if (realPlaces.isNotEmpty) {
      realPlaces.sort((a, b) => _calculateDistance(position.latitude, position.longitude, a.latitude, a.longitude)
          .compareTo(_calculateDistance(position.latitude, position.longitude, b.latitude, b.longitude)));
    }

    if (mounted) {
      setState(() {
        _nearbyPlaces = realPlaces.isNotEmpty ? realPlaces : _generateNearbyContextualPlaces(position.latitude, position.longitude);
        _isLoadingNearbyPlaces = false;
      });
    }
  }



  // Pencarian Cerdas Tempat Sekitar & Rekomendasi
  Future<void> _performSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    final userPos = _currentPosition;
    setState(() => _isSearching = true);

    final results = <PlaceItem>[];
    final lowerQ = trimmed.toLowerCase();

    // 1. Cocokkan dari data tempat sekitar yang sudah dimuat
    for (final p in _nearbyPlaces) {
      if (p.nameId.toLowerCase().contains(lowerQ) ||
          p.category.toLowerCase().contains(lowerQ) ||
          p.hanzi.contains(trimmed) ||
          p.pinyin.toLowerCase().contains(lowerQ)) {
        if (!results.any((r) => r.nameId.toLowerCase() == p.nameId.toLowerCase())) {
          results.add(p);
        }
      }
    }

    // 2. Query Nominatim OpenStreetMap (Universal Search seperti Google Maps)
    if (userPos != null) {
      try {
        // Tentukan kata kunci pencarian Nominatim (mendukung transportasi & bebas)
        String nominatimQ = trimmed;
        if (lowerQ.contains('transport') || lowerQ.contains('transportasi')) {
          nominatimQ = 'stasiun halte terminal';
        }

        // Cari pertama kali dalam radius pengguna
        final uriBounded = Uri.https('nominatim.openstreetmap.org', '/search', {
          'format': 'json',
          'q': nominatimQ,
          'viewbox': '${userPos.longitude - 0.15},${userPos.latitude + 0.15},${userPos.longitude + 0.15},${userPos.latitude - 0.15}',
          'bounded': '1',
          'limit': '15',
          'addressdetails': '1',
        });

        var res = await http.get(uriBounded, headers: {
          'User-Agent': 'MandarinLearningApp/1.0',
          'Accept-Language': 'id,en',
        }).timeout(const Duration(seconds: 5));

        var decoded = res.statusCode == 200 ? jsonDecode(res.body) : null;

        // Fallback jika pencarian lokal kosong: cari lebih luas tanpa bounded
        if (decoded == null || (decoded is List && decoded.isEmpty)) {
          final uriUnbounded = Uri.https('nominatim.openstreetmap.org', '/search', {
            'format': 'json',
            'q': nominatimQ,
            'limit': '10',
            'addressdetails': '1',
          });
          res = await http.get(uriUnbounded, headers: {
            'User-Agent': 'MandarinLearningApp/1.0',
            'Accept-Language': 'id,en',
          }).timeout(const Duration(seconds: 5));
          if (res.statusCode == 200) {
            decoded = jsonDecode(res.body);
          }
        }

        if (decoded is List) {
          for (final item in decoded) {
            if (item is! Map<String, dynamic>) continue;
            final name = item['display_name']?.toString().split(',')[0].trim() ?? trimmed;
            final lat = double.tryParse(item['lat']?.toString() ?? '');
            final lon = double.tryParse(item['lon']?.toString() ?? '');
            if (lat == null || lon == null || name.isEmpty) continue;

            final type = item['type']?.toString().toLowerCase() ?? '';
            final cls = item['class']?.toString().toLowerCase() ?? '';
            final itemLower = name.toLowerCase();

            // Klasifikasi kategori & kosakata Mandarin secara universal
            String cat = 'Tempat Umum';
            String icon = '📍';
            String hanzi = '地点';
            String pinyin = 'Dìdiǎn';
            String arti = 'Tempat Umum';

            if (lowerQ.contains('transport') ||
                itemLower.contains('stasiun') ||
                itemLower.contains('halte') ||
                itemLower.contains('terminal') ||
                itemLower.contains('bandara') ||
                cls.contains('railway') ||
                cls.contains('highway') ||
                type.contains('station') ||
                type.contains('bus_stop')) {
              cat = 'Transportasi';
              icon = '🚆';
              hanzi = '车站';
              pinyin = 'Chēzhàn';
              arti = 'Stasiun / Transportasi';
            } else if (lowerQ.contains('cafe') || lowerQ.contains('kafe') || lowerQ.contains('kopi') || type.contains('cafe')) {
              cat = 'Kafe'; icon = '☕'; hanzi = '咖啡馆'; pinyin = 'Kāfēiguǎn'; arti = 'Kafe';
            } else if (lowerQ.contains('hotel') || lowerQ.contains('penginapan') || cls.contains('tourism')) {
              cat = 'Hotel'; icon = '🏨'; hanzi = '酒店'; pinyin = 'Jiǔdiàn'; arti = 'Hotel';
            } else if (lowerQ.contains('baju') || lowerQ.contains('fashion') || lowerQ.contains('clothing') || cls.contains('shop')) {
              cat = 'Toko Baju'; icon = '👗'; hanzi = '服装店'; pinyin = 'Fúzhuāngdiàn'; arti = 'Toko Baju';
            } else if (lowerQ.contains('resto') || lowerQ.contains('makan') || type.contains('restaurant')) {
              cat = 'Restoran'; icon = '🍽️'; hanzi = '餐厅'; pinyin = 'Cāntīng'; arti = 'Restoran';
            } else if (lowerQ.contains('taman') || type.contains('park')) {
              cat = 'Taman'; icon = '🌲'; hanzi = '公园'; pinyin = 'Gōngyuán'; arti = 'Taman';
            } else if (itemLower.contains('masjid') || itemLower.contains('gereja') || cls.contains('amenity') && type.contains('place_of_worship')) {
              cat = 'Tempat Ibadah'; icon = '🕌'; hanzi = '宗教场所'; pinyin = 'Zōngjiào chǎngsuǒ'; arti = 'Tempat Ibadah';
            } else if (itemLower.contains('sekolah') || itemLower.contains('universitas') || itemLower.contains('kampus')) {
              cat = 'Pendidikan'; icon = '🏫'; hanzi = '学校'; pinyin = 'Xuéxiào'; arti = 'Sekolah / Kampus';
            } else if (itemLower.contains('rumah sakit') || itemLower.contains('apotek') || itemLower.contains('klinik')) {
              cat = 'Kesehatan'; icon = '🏥'; hanzi = '医院'; pinyin = 'Yīyuàn'; arti = 'Rumah Sakit';
            }

            final newItem = PlaceItem(
              nameId: name,
              hanzi: hanzi,
              pinyin: pinyin,
              arti: arti,
              category: cat,
              iconEmoji: icon,
              latitude: lat,
              longitude: lon,
              osmType: 'node',
              osmId: DateTime.now().millisecondsSinceEpoch + results.length,
              relatedVocab: [
                RelatedVocab(hanzi: hanzi, pinyin: pinyin, arti: arti, iconEmoji: icon),
              ],
            );

            if (!results.any((r) => r.nameId.toLowerCase() == name.toLowerCase())) {
              results.add(newItem);
            }
          }
        }
      } catch (e) {
        debugPrint('[DirectionExplorer] Universal search error: $e');
      }
    }

    // Jika pencarian transportasi masih kosong, tambahkan rekomendasi kontekstual cerdas
    if (results.isEmpty && userPos != null) {
      if (lowerQ.contains('transport') || lowerQ.contains('stasiun') || lowerQ.contains('halte')) {
        results.addAll([
          PlaceItem(
            nameId: 'Stasiun Kereta & Transportasi Publik',
            nameZh: '城市公共交通总站',
            hanzi: '车站',
            pinyin: 'Chēzhàn',
            arti: 'Stasiun / Halte Transportasi',
            category: 'Transportasi',
            iconEmoji: '🚆',
            latitude: userPos.latitude + 0.0019,
            longitude: userPos.longitude - 0.0015,
            osmType: 'node',
            osmId: 310,
            description: 'Titik transportasi umum terdekat untuk bus kota dan kereta api.',
            relatedVocab: const [
              RelatedVocab(hanzi: '车站', pinyin: 'chēzhàn', arti: 'Stasiun / Halte', iconEmoji: '🚆'),
              RelatedVocab(hanzi: '公交车', pinyin: 'gōngjiāochē', arti: 'Bus kota', iconEmoji: '🚌'),
              RelatedVocab(hanzi: '地铁', pinyin: 'dìtiě', arti: 'Subway / Metro', iconEmoji: '🚇'),
            ],
          ),
          PlaceItem(
            nameId: 'Halte Transit Bus Kota',
            nameZh: '公交巴士中转站',
            hanzi: '公交车站',
            pinyin: 'Gōngjiāochē zhàn',
            arti: 'Halte Transit Bus',
            category: 'Transportasi',
            iconEmoji: '🚌',
            latitude: userPos.latitude - 0.0014,
            longitude: userPos.longitude + 0.0018,
            osmType: 'node',
            osmId: 311,
            description: 'Halte bus terdekat dengan rute transit antarmoda.',
            relatedVocab: const [
              RelatedVocab(hanzi: '买票', pinyin: 'mǎi piào', arti: 'Beli tiket', iconEmoji: '🎟️'),
              RelatedVocab(hanzi: '到站', pinyin: 'dàozhàn', arti: 'Tiba di stasiun', iconEmoji: '📍'),
            ],
          ),
        ]);
      }
    }

    if (userPos != null) {
      results.sort(
        (a, b) => _calculateDistance(userPos.latitude, userPos.longitude, a.latitude, a.longitude).compareTo(
          _calculateDistance(userPos.latitude, userPos.longitude, b.latitude, b.longitude),
        ),
      );
    }

    if (mounted) {
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    }
  }

  // Jarak Haversine
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const earthRadius = 6371000.0;
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

  double _calculateBearingDegrees(double lat1, double lon1, double lat2, double lon2) {
    final dLon = (lon2 - lon1) * (math.pi / 180);
    final y = math.sin(dLon) * math.cos(lat2 * (math.pi / 180));
    final x = math.cos(lat1 * (math.pi / 180)) * math.sin(lat2 * (math.pi / 180)) -
        math.sin(lat1 * (math.pi / 180)) * math.cos(lat2 * (math.pi / 180)) * math.cos(dLon);
    final radians = math.atan2(y, x);
    final deg = radians * (180 / math.pi);
    return (deg % 360 + 360) % 360;
  }

  ({String hanzi, String pinyin, String arti, String icon, String arrow}) _directionForDegrees(double degrees) {
    final normalized = (degrees % 360 + 360) % 360;
    if (normalized >= 337.5 || normalized < 22.5) {
      return (hanzi: '北', pinyin: 'Běi', arti: 'Utara', icon: '↑', arrow: '↑');
    }
    if (normalized >= 22.5 && normalized < 67.5) {
      return (hanzi: '东北', pinyin: 'Dōngběi', arti: 'Timur Laut', icon: '↗', arrow: '↗');
    }
    if (normalized >= 67.5 && normalized < 112.5) {
      return (hanzi: '东', pinyin: 'Dōng', arti: 'Timur', icon: '→', arrow: '→');
    }
    if (normalized >= 112.5 && normalized < 157.5) {
      return (hanzi: '东南', pinyin: 'Dōngnán', arti: 'Tenggara', icon: '↘', arrow: '↘');
    }
    if (normalized >= 157.5 && normalized < 202.5) {
      return (hanzi: '南', pinyin: 'Nán', arti: 'Selatan', icon: '↓', arrow: '↓');
    }
    if (normalized >= 202.5 && normalized < 247.5) {
      return (hanzi: '西南', pinyin: 'Xīnán', arti: 'Barat Daya', icon: '↙', arrow: '↙');
    }
    if (normalized >= 247.5 && normalized < 292.5) {
      return (hanzi: '西', pinyin: 'Xī', arti: 'Barat', icon: '←', arrow: '←');
    }
    return (hanzi: '西北', pinyin: 'Xīběi', arti: 'Barat Laut', icon: '↖', arrow: '↖');
  }

  String _formatDistance(double meters) {
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  // Tampilkan Rute ke Tempat Terpilih
  void _showRouteView(PlaceItem destination) {
    final userPos = _currentPosition;
    if (userPos == null) return;

    setState(() {
      _selectedPlace = destination;
      _activeSubView = _ActiveSubView.routeMap;
      _walkingRoutePoints = [];
      _walkingRouteDistanceMeters = null;
      _walkingRouteDurationSeconds = null;
    });

    final origin = LatLng(userPos.latitude, userPos.longitude);
    final dest = LatLng(destination.latitude, destination.longitude);

    if (_isMapReady) {
      _fitWalkingRoutePoints(origin, dest);
    }

    _loadWalkingRouteCoordinates(origin.latitude, origin.longitude, dest.latitude, dest.longitude, destination);
  }

  Future<void> _loadWalkingRouteCoordinates(
    double startLat,
    double startLon,
    double destLat,
    double destLon,
    PlaceItem destination,
  ) async {
    final url = Uri.parse(
      'https://router.project-osrm.org/route/v1/foot/$startLon,$startLat;$destLon,$destLat?overview=full&geometries=geojson',
    );

    try {
      final response = await http.get(
        url,
        headers: {'User-Agent': 'MandarinLearningApp/1.0'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['routes'] != null && (data['routes'] as List).isNotEmpty) {
          final route = data['routes'][0];
          final geometry = route['geometry'];
          final coordinates = geometry['coordinates'] as List;

          final points = coordinates.map((coord) {
            return LatLng((coord[1] as num).toDouble(), (coord[0] as num).toDouble());
          }).toList();

          if (mounted && _selectedPlace == destination) {
            setState(() {
              _walkingRoutePoints = points;
              _walkingRouteDistanceMeters = (route['distance'] as num).toDouble();
              _walkingRouteDurationSeconds = (route['duration'] as num).toDouble();
            });
            _fitWalkingRoutePoints(LatLng(startLat, startLon), LatLng(destLat, destLon));
            return;
          }
        }
      }
    } catch (_) {}

    if (mounted && _selectedPlace == destination) {
      setState(() {
        _walkingRoutePoints = [LatLng(startLat, startLon), LatLng(destLat, destLon)];
      });
    }
  }

  void _fitWalkingRoutePoints(LatLng origin, LatLng destination) {
    final minLat = math.min(origin.latitude, destination.latitude);
    final maxLat = math.max(origin.latitude, destination.latitude);
    final minLon = math.min(origin.longitude, destination.longitude);
    final maxLon = math.max(origin.longitude, destination.longitude);

    final center = LatLng((minLat + maxLat) / 2, (minLon + maxLon) / 2);
    final dist = _calculateDistance(origin.latitude, origin.longitude, destination.latitude, destination.longitude);

    double zoom = 15.5;
    if (dist > 5000) {
      zoom = 12.0;
    } else if (dist > 2500) {
      zoom = 13.5;
    } else if (dist > 1000) {
      zoom = 14.5;
    } else {
      zoom = 16.0;
    }

    _mapController.move(center, zoom);
  }

  // Buka Google Maps Aplikasi Native di HP
  Future<void> _openExternalMap(PlaceItem place) async {
    final googleNavUri = Uri.parse(
      'google.navigation:q=${place.latitude},${place.longitude}&mode=w',
    );
    final geoUri = Uri.parse(
      'geo:${place.latitude},${place.longitude}?q=${place.latitude},${place.longitude}(${Uri.encodeComponent(place.nameId)})',
    );
    final webUri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${place.latitude},${place.longitude}&travelmode=walking',
    );

    try {
      if (await canLaunchUrl(googleNavUri)) {
        await launchUrl(googleNavUri, mode: LaunchMode.externalNonBrowserApplication);
        return;
      }
    } catch (_) {}

    try {
      if (await canLaunchUrl(geoUri)) {
        await launchUrl(geoUri, mode: LaunchMode.externalNonBrowserApplication);
        return;
      }
    } catch (_) {}

    try {
      await launchUrl(geoUri, mode: LaunchMode.externalNonBrowserApplication);
      return;
    } catch (_) {}

    try {
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('[DirectionExplorer] Error launching Google Maps: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────
  // MODAL DETAIL TEMPAT & KONVERSI 3 MATA UANG KONTEKSTUAL
  // ─────────────────────────────────────────────────────────────
  void _openPlaceBottomSheet(PlaceItem place) {
    final userPos = _currentPosition;
    final dist = userPos != null
        ? _calculateDistance(userPos.latitude, userPos.longitude, place.latitude, place.longitude)
        : 0.0;
    final bearing = userPos != null
        ? _calculateBearingDegrees(userPos.latitude, userPos.longitude, place.latitude, place.longitude)
        : 0.0;
    final dir = _directionForDegrees(bearing);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _PlaceDetailModal(
          place: place,
          distanceMeters: dist,
          direction: dir,
          onShowRoute: () {
            Navigator.pop(ctx);
            _showRouteView(place);
          },
          onOpenGoogleMaps: () {
            Navigator.pop(ctx);
            _openExternalMap(place);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    switch (_activeSubView) {
      case _ActiveSubView.home:
        return _buildHomeView();
      case _ActiveSubView.routeMap:
        return _buildRouteMapView();
      case _ActiveSubView.placeVocabList:
        return _buildPlaceVocabListView();
      case _ActiveSubView.cardinalDirections:
        return _buildCardinalDirectionsView();
    }
  }

  // ─────────────────────────────────────────────────────────────
  // 1. TAMPILAN BERANDA (PETA REAL GPS, SEARCH & IN-MAP COMPASS)
  // ─────────────────────────────────────────────────────────────
  Widget _buildHomeView() {
    final userPos = _currentPosition;
    final userCenter = userPos != null ? LatLng(userPos.latitude, userPos.longitude) : null;

    final categories = ['Semua', 'Transportasi', 'Kafe', 'Restoran', 'Hotel', 'Toko Baju', 'Taman'];

    final activePlaces = _searchResults.isNotEmpty
        ? _searchResults
        : (_selectedCategory == 'Semua'
            ? _nearbyPlaces
            : _nearbyPlaces.where((p) => p.category.toLowerCase().contains(_selectedCategory.toLowerCase())).toList());

    return Scaffold(
      backgroundColor: AppColors.mintBackground,
      appBar: AppBar(
        title: const Text('Mandarin Direction Explorer'),
        actions: [
          IconButton(
            tooltip: 'Panduan 8 Mata Angin',
            icon: const Icon(Icons.explore_rounded, color: AppColors.primaryGreen),
            onPressed: () => setState(() => _activeSubView = _ActiveSubView.cardinalDirections),
          ),
          IconButton(
            tooltip: 'Kamus Kosakata Tempat',
            icon: const Icon(Icons.menu_book_rounded, color: AppColors.primaryDark),
            onPressed: () => setState(() => _activeSubView = _ActiveSubView.placeVocabList),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search Bar Pintar Tempat & Rekomendasi
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  onSubmitted: _performSearch,
                  decoration: InputDecoration(
                    hintText: 'Cari tempat (cth: cafe, hotel, baju, resto)...',
                    hintStyle: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                    prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primaryGreen),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 20),
                            onPressed: () {
                              _searchController.clear();
                              _performSearch('');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ),

              // Status GPS Warning Banner (jika GPS mati atau izin belum diberikan)
              if (_isLocationServiceDisabled)
                Container(
                  margin: const EdgeInsets.only(top: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.location_off_rounded, color: Color(0xFFDC2626), size: 22),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Layanan GPS belum aktif di HP Anda.',
                          style: TextStyle(fontSize: 12, color: Color(0xFF991B1B), fontWeight: FontWeight.bold),
                        ),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFDC2626),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () async {
                          await Geolocator.openLocationSettings();
                        },
                        child: const Text('Aktifkan GPS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),

              if (_isLocationPermissionDenied)
                Container(
                  margin: const EdgeInsets.only(top: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.security_rounded, color: Color(0xFFD97706), size: 22),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Izin lokasi diperlukan untuk deteksi GPS nyata.',
                          style: TextStyle(fontSize: 12, color: Color(0xFF92400E), fontWeight: FontWeight.bold),
                        ),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD97706),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () async {
                          await Geolocator.openAppSettings();
                        },
                        child: const Text('Buka Izin', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 10),

              // Status Bar Lokasi Nyata Pengguna
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.my_location_rounded, color: Color(0xFF2563EB), size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Titik Koordinat GPS Perangkat Nyata:',
                            style: TextStyle(fontSize: 10, color: AppColors.textMuted),
                          ),
                          Text(
                            _currentLocationName,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textDark),
                          ),
                          if (_locationErrorMessage != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                _locationErrorMessage!,
                                style: const TextStyle(fontSize: 10, color: Color(0xFFDC2626)),
                              ),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, size: 20),
                      tooltip: 'Deteksi ulang posisi GPS',
                      onPressed: _loadCurrentLocation,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // Filter Kategori Chips
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
                        onSelected: (_) {
                          setState(() {
                            _selectedCategory = cat;
                            _searchController.clear();
                            _searchResults = [];
                          });
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 12),

              // WIDGET PETA INTERAKTIF DENGAN IN-MAP COMPASS HUD
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: SizedBox(
                  height: 270,
                  child: Stack(
                    children: [
                      FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: userCenter ?? const LatLng(-6.2088, 106.8456),
                          initialZoom: userCenter != null ? 15.5 : 12.0,
                          minZoom: 3,
                          maxZoom: 19,
                          onMapReady: () {
                            _isMapReady = true;
                            final current = _currentPosition;
                            if (current != null) {
                              _mapController.move(LatLng(current.latitude, current.longitude), 15.5);
                            }
                          },
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.example.mandarin_learning',
                          ),
                          MarkerLayer(
                            markers: [
                              if (userCenter != null)
                                Marker(
                                  point: userCenter,
                                  width: 36,
                                  height: 36,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2563EB),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 3),
                                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
                                    ),
                                    child: const Center(
                                      child: Icon(Icons.person, color: Colors.white, size: 18),
                                    ),
                                  ),
                                ),
                              ...activePlaces.map(
                                (place) => Marker(
                                  point: LatLng(place.latitude, place.longitude),
                                  width: 140,
                                  height: 60,
                                  child: GestureDetector(
                                    onTap: () => _openPlaceBottomSheet(place),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 32,
                                          height: 32,
                                          decoration: BoxDecoration(
                                            color: _getCategoryColor(place.category),
                                            shape: BoxShape.circle,
                                            border: Border.all(color: Colors.white, width: 2),
                                            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                                          ),
                                          child: Center(
                                            child: Text(place.iconEmoji, style: const TextStyle(fontSize: 16)),
                                          ),
                                        ),
                                        Container(
                                          constraints: const BoxConstraints(maxWidth: 136),
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(6),
                                            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 3)],
                                          ),
                                          child: Text(
                                            place.nameId,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textDark),
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
                                '© OpenStreetMap',
                                onTap: () {},
                              ),
                            ],
                          ),
                        ],
                      ),

                      // Indikator Loading GPS Riil Perangkat
                      if (userCenter == null)
                        Positioned.fill(
                          child: Container(
                            color: Colors.black.withValues(alpha: 0.3),
                            child: const Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircularProgressIndicator(color: Colors.white),
                                  SizedBox(height: 10),
                                  Text(
                                    'Mendeteksi koordinat GPS riil HP Anda...',
                                    style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                      // IN-MAP COMPASS HUD: KOMPAS MATA ANGIN LANGSUNG DI DALAM PETA!
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Transform.rotate(
                                angle: -_headingDegrees * (math.pi / 180),
                                child: Container(
                                  width: 30,
                                  height: 30,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Color(0xFFF1F5F9),
                                  ),
                                  child: const Center(
                                    child: Icon(Icons.navigation_rounded, color: Color(0xFFEF4444), size: 18),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${_headingDegrees.toStringAsFixed(0)}° ${_directionForDegrees(_headingDegrees).hanzi}',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textDark),
                                  ),
                                  Text(
                                    _directionForDegrees(_headingDegrees).arti,
                                    style: const TextStyle(fontSize: 9.5, color: AppColors.textMuted),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Tombol Re-Center Lokasi Nyata HP (Pojok Kanan Bawah Peta)
                      Positioned(
                        bottom: 10,
                        right: 10,
                        child: FloatingActionButton.small(
                          heroTag: 'recenter_map_btn',
                          backgroundColor: Colors.white,
                          onPressed: () {
                            if (userCenter != null && _isMapReady) {
                              _mapController.move(userCenter, 16.0);
                            } else {
                              _loadCurrentLocation();
                            }
                          },
                          child: const Icon(Icons.my_location_rounded, color: Color(0xFF2563EB), size: 20),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // Judul Daftar Tempat
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _searchResults.isNotEmpty ? 'Hasil Pencarian Tempat' : 'Tempat Nyata Sekitar Koordinat Anda',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textDark),
                  ),
                  Text(
                    _isSearching ? 'Mencari...' : '${activePlaces.length} lokasi',
                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // List Rekomendasi Tempat Sekitar
              if (_isSearching || _isLoadingNearbyPlaces)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (activePlaces.isEmpty)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text(
                      _placesErrorMessage ??
                          (_searchResults.isNotEmpty
                              ? 'Tidak menemukan tempat dengan kata kunci "${_searchController.text}". Coba kata kunci lain.'
                              : 'Sedang mendeteksi tempat sekitar titik koordinat Anda...'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
                  ),
                ),

              ...activePlaces.map((place) {
                final dist = userPos != null
                    ? _calculateDistance(userPos.latitude, userPos.longitude, place.latitude, place.longitude)
                    : 0.0;
                final bearing = userPos != null
                    ? _calculateBearingDegrees(userPos.latitude, userPos.longitude, place.latitude, place.longitude)
                    : 0.0;
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
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: _getCategoryColor(place.category).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: Text(place.iconEmoji, style: const TextStyle(fontSize: 22)),
                      ),
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            place.nameId,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _getCategoryColor(place.category).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            place.category,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: _getCategoryColor(place.category),
                            ),
                          ),
                        ),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_formatDistance(dist)} • Arah ${dir.arti} (${dir.hanzi}) ${dir.icon} • ${place.hanzi} (${place.pinyin})',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textLight),
                    onTap: () => _openPlaceBottomSheet(place),
                  ),
                );
              }),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 2. TAMPILAN PETA RUTE DENGAN IN-MAP LIVE COMPASS HUD TERINTEGRASI
  // ─────────────────────────────────────────────────────────────
  Widget _buildRouteMapView() {
    final userPos = _currentPosition;
    final place = _selectedPlace;
    if (userPos == null || place == null) return _buildHomeView();

    final userCenter = LatLng(userPos.latitude, userPos.longitude);
    final placeLatLng = LatLng(place.latitude, place.longitude);

    final directDistance = _calculateDistance(userPos.latitude, userPos.longitude, place.latitude, place.longitude);
    final dist = _walkingRouteDistanceMeters ?? directDistance;
    final bearing = _calculateBearingDegrees(userPos.latitude, userPos.longitude, place.latitude, place.longitude);
    final dir = _directionForDegrees(bearing);

    final walkingMinutes = _walkingRouteDurationSeconds != null
        ? math.max(1, (_walkingRouteDurationSeconds! / 60).round())
        : math.max(1, (directDistance / 80).round());
    final drivingMinutes = math.max(1, (directDistance / 400).round());

    // Relative target needle angle for compass
    final targetRelativeAngle = (bearing - _headingDegrees) * (math.pi / 180);

    return Scaffold(
      body: Stack(
        children: [
          // Peta Rute
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: placeLatLng,
              initialZoom: 15.5,
              minZoom: 3,
              maxZoom: 19,
              onMapReady: () {
                _isMapReady = true;
                _fitWalkingRoutePoints(userCenter, placeLatLng);
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.mandarin_learning',
              ),
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: _walkingRoutePoints.length >= 2 ? _walkingRoutePoints : [userCenter, placeLatLng],
                    strokeWidth: 5,
                    color: const Color(0xFF16A34A),
                    borderStrokeWidth: 2,
                    borderColor: Colors.white,
                  ),
                ],
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: userCenter,
                    width: 36,
                    height: 36,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                      ),
                      child: const Center(
                        child: Icon(Icons.person, color: Colors.white, size: 18),
                      ),
                    ),
                  ),
                  Marker(
                    point: placeLatLng,
                    width: 50,
                    height: 50,
                    child: Container(
                      decoration: BoxDecoration(
                        color: _getCategoryColor(place.category),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
                      ),
                      child: Center(
                        child: Text(place.iconEmoji, style: const TextStyle(fontSize: 22)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Header Card Rute
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10),
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
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                          ),
                          Text(
                            '${place.hanzi} (${place.pinyin}) · ${_formatDistance(dist)}',
                            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => setState(() => _activeSubView = _ActiveSubView.home),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // IN-MAP COMPASS HUD: KOMPAS DI DALAM PETA YANG MEMANDU LANGSUNG KE TUJUAN!
          Positioned(
            top: 80,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      // Dial jarum utara HP (berputar dengan orientasi HP)
                      Transform.rotate(
                        angle: -_headingDegrees * (math.pi / 180),
                        child: Container(
                          width: 46,
                          height: 46,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFFF1F5F9),
                          ),
                          child: const Center(
                            child: Icon(Icons.navigation_rounded, color: Color(0xFFEF4444), size: 26),
                          ),
                        ),
                      ),
                      // Panah penunjuk arah tujuan relatif terhadap hadapan pengguna
                      Transform.rotate(
                        angle: targetRelativeAngle,
                        child: const Icon(Icons.arrow_upward_rounded, color: Color(0xFF16A34A), size: 24),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${dir.hanzi} (${dir.pinyin})',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                  ),
                  Text(
                    'Arah ${dir.arti}',
                    style: const TextStyle(fontSize: 9.5, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Bar Rute & Navigasi
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
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Color(0xFFDCFCE7),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.alt_route_rounded, color: Color(0xFF15803D), size: 18),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Alur Rute Perjalanan (路线)',
                        style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: AppColors.textDark),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${_formatDistance(dist)} • $walkingMinutes mnt',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textDark),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Step 1: Titik Awal
                  Row(
                    children: [
                      const Icon(Icons.my_location_rounded, size: 16, color: Color(0xFF2563EB)),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Titik Awal: Lokasi GPS Anda Saat Ini',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textDark),
                        ),
                      ),
                    ],
                  ),

                  // Jalur Tengah
                  Container(
                    margin: const EdgeInsets.only(left: 7),
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 14),
                    decoration: const BoxDecoration(
                      border: Border(left: BorderSide(color: Color(0xFF22C55E), width: 2.5)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Menghadap ke arah ${dir.arti} (${dir.hanzi} - ${dir.pinyin}) ${dir.arrow} sejauh ${_formatDistance(dist)}',
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF15803D)),
                        ),
                        Text(
                          'Estimasi: ~$walkingMinutes mnt jalan kaki / ~$drivingMinutes mnt berkendara',
                          style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),

                  // Step 2: Titik Tujuan
                  Row(
                    children: [
                      const Icon(Icons.location_on_rounded, size: 18, color: Color(0xFFDC2626)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Tujuan: ${place.nameId} (${place.hanzi})',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Tombol Aksi
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF22C55E), width: 1.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            padding: const EdgeInsets.symmetric(vertical: 11),
                          ),
                          onPressed: () => _openPlaceBottomSheet(place),
                          icon: const Icon(Icons.currency_exchange_rounded, color: Color(0xFF15803D), size: 18),
                          label: const Text('Konversi Harga', style: TextStyle(color: Color(0xFF15803D), fontSize: 12, fontWeight: FontWeight.bold)),
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
  // 3. DAFTAR KOSAKATA TEMPAT
  // ─────────────────────────────────────────────────────────────
  Widget _buildPlaceVocabListView() {
    final vocabItems = [
      (hanzi: '咖啡馆', pinyin: 'Kāfēiguǎn', arti: 'Kafe / Kedai Kopi', category: 'Kafe', icon: '☕'),
      (hanzi: '酒店', pinyin: 'Jiǔdiàn', arti: 'Hotel / Penginapan', category: 'Hotel', icon: '🏨'),
      (hanzi: '服装店', pinyin: 'Fúzhuāngdiàn', arti: 'Toko Baju / Butik', category: 'Toko Baju', icon: '👗'),
      (hanzi: '餐厅', pinyin: 'Cāntīng', arti: 'Restoran / Rumah Makan', category: 'Restoran', icon: '🍽️'),
      (hanzi: '公园', pinyin: 'Gōngyuán', arti: 'Taman Kota', category: 'Taman', icon: '🌲'),
      (hanzi: '商店', pinyin: 'Shāngdiàn', arti: 'Toko / Minimarket', category: 'Belanja', icon: '🏬'),
      (hanzi: '学校', pinyin: 'Xuéxiào', arti: 'Sekolah / Kampus', category: 'Edukasi', icon: '🏫'),
      (hanzi: '车站', pinyin: 'Chēzhàn', arti: 'Stasiun / Terminal', category: 'Transportasi', icon: '🚌'),
    ];

    return Scaffold(
      backgroundColor: AppColors.mintBackground,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => setState(() => _activeSubView = _ActiveSubView.home),
        ),
        title: const Text('Kamus Kosakata Tempat (地点)'),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: vocabItems.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          final item = vocabItems[i];
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: ListTile(
              leading: Text(item.icon, style: const TextStyle(fontSize: 26)),
              title: Row(
                children: [
                  Text(item.hanzi, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  Text(item.pinyin, style: const TextStyle(fontSize: 13, color: AppColors.primaryGreen, fontWeight: FontWeight.w600)),
                ],
              ),
              subtitle: Text(item.arti, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
              trailing: IconButton(
                icon: const Icon(Icons.volume_up_rounded, color: AppColors.primaryDark),
                onPressed: () => AudioService.instance.speak(item.hanzi),
              ),
            ),
          );
        },
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 4. PANDUAN 8 ARAH MATA ANGIN MANDARIN
  // ─────────────────────────────────────────────────────────────
  Widget _buildCardinalDirectionsView() {
    final cardinalItems = [
      (hanzi: '北', pinyin: 'Běi', arti: 'Utara', arrow: '↑', abbreviation: 'U / N', degrees: '0° / 360°', color: const Color(0xFFEF4444)),
      (hanzi: '东北', pinyin: 'Dōngběi', arti: 'Timur Laut', arrow: '↗', abbreviation: 'TL / NE', degrees: '45°', color: const Color(0xFF0284C7)),
      (hanzi: '东', pinyin: 'Dōng', arti: 'Timur', arrow: '→', abbreviation: 'T / E', degrees: '90°', color: const Color(0xFFF59E0B)),
      (hanzi: '东南', pinyin: 'Dōngnán', arti: 'Tenggara', arrow: '↘', abbreviation: 'TG / SE', degrees: '135°', color: const Color(0xFFEA580C)),
      (hanzi: '南', pinyin: 'Nán', arti: 'Selatan', arrow: '↓', abbreviation: 'S / S', degrees: '180°', color: const Color(0xFFDC2626)),
      (hanzi: '西南', pinyin: 'Xīnán', arti: 'Barat Daya', arrow: '↙', abbreviation: 'BD / SW', degrees: '225°', color: const Color(0xFF7C3AED)),
      (hanzi: '西', pinyin: 'Xī', arti: 'Barat', arrow: '←', abbreviation: 'B / W', degrees: '270°', color: const Color(0xFF10B981)),
      (hanzi: '西北', pinyin: 'Xīběi', arti: 'Barat Laut', arrow: '↖', abbreviation: 'BL / NW', degrees: '315°', color: const Color(0xFF0D9488)),
    ];

    final currentHeadingDir = _directionForDegrees(_headingDegrees);

    return Scaffold(
      backgroundColor: AppColors.mintBackground,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => setState(() => _activeSubView = _ActiveSubView.home),
        ),
        title: const Text('8 Mata Angin (方向 - Fāngxiàng)'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Banner Orientasi HP Real
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
              ),
              child: Row(
                children: [
                  Transform.rotate(
                    angle: -_headingDegrees * (math.pi / 180),
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFF1F5F9)),
                      child: const Center(
                        child: Icon(Icons.navigation_rounded, color: Color(0xFFEF4444), size: 30),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isCompassAvailable ? 'Arah sensor HP: ${_headingDegrees.toStringAsFixed(0)}°' : 'Sensor kompas tidak aktif',
                          style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                        ),
                        Text(
                          '${currentHeadingDir.arti} (${currentHeadingDir.hanzi} - ${currentHeadingDir.pinyin})',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: cardinalItems.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final item = cardinalItems[i];
                  final isCurrentActive = currentHeadingDir.hanzi == item.hanzi;

                  return Container(
                    decoration: BoxDecoration(
                      color: isCurrentActive ? const Color(0xFFF0FDF4) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isCurrentActive ? const Color(0xFF22C55E) : Colors.transparent, width: 2),
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
                          child: Text(item.arrow, style: TextStyle(fontSize: 22, color: item.color, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      title: Row(
                        children: [
                          Text(item.hanzi, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 8),
                          Text(item.pinyin, style: TextStyle(fontSize: 13, color: item.color, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 8),
                          Text(item.abbreviation, style: TextStyle(fontSize: 11, color: item.color, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      subtitle: Text('${item.arti} • Sudut: ${item.degrees}', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                      trailing: IconButton(
                        icon: const Icon(Icons.volume_up_rounded, color: AppColors.primaryDark),
                        onPressed: () => AudioService.instance.speak(item.hanzi),
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

  Color _getCategoryColor(String cat) {
    final lower = cat.toLowerCase();
    if (lower.contains('baju') || lower.contains('pakaian') || lower.contains('fashion')) {
      return const Color(0xFF7C3AED); // Ungu Toko Baju
    }
    if (lower.contains('hotel') || lower.contains('penginapan')) {
      return const Color(0xFF0284C7); // Biru Langit Hotel
    }
    if (lower.contains('kafe') || lower.contains('cafe')) {
      return const Color(0xFF854D0E); // Coklat Kopi Kafe
    }
    if (lower.contains('restoran') || lower.contains('makan')) {
      return const Color(0xFFEA580C); // Oranye Kuliner
    }
    if (lower.contains('taman') || lower.contains('park')) {
      return const Color(0xFF16A34A); // Hijau Taman
    }
    return const Color(0xFF4F46E5);
  }
}

enum _ActiveSubView {
  home,
  routeMap,
  placeVocabList,
  cardinalDirections,
}

// ─────────────────────────────────────────────────────────────
// WIDGET MODAL DETAIL TEMPAT DENGAN KONVERSI 3 MATA UANG
// ─────────────────────────────────────────────────────────────
class _PlaceDetailModal extends StatelessWidget {
  final PlaceItem place;
  final double distanceMeters;
  final ({String hanzi, String pinyin, String arti, String icon, String arrow}) direction;
  final VoidCallback onShowRoute;
  final VoidCallback onOpenGoogleMaps;

  const _PlaceDetailModal({
    required this.place,
    required this.distanceMeters,
    required this.direction,
    required this.onShowRoute,
    required this.onOpenGoogleMaps,
  });

  @override
  Widget build(BuildContext context) {
    List<(String zh, String py, String id)> phrases = [];
    final catLower = place.category.toLowerCase();
    final nameLower = place.nameId.toLowerCase();

    if (catLower.contains('transport') || nameLower.contains('stasiun') || nameLower.contains('halte') || nameLower.contains('terminal')) {
      phrases = [
        ('请问地铁站在哪里？', 'Qǐngwèn dìtiě zhàn zài nǎlǐ?', 'Permisi, di mana stasiun subway?'),
        ('买一张去北京的火车票', 'Mǎi yī zhāng qù Běijīng de huǒchē piào', 'Beli satu tiket kereta ke Beijing'),
        ('下一班车什么时候到？', 'Xià yī bān chē shénme shíhou dào?', 'Kapan bus berikutnya tiba?'),
      ];
    } else if (catLower.contains('baju') || nameLower.contains('baju') || nameLower.contains('fashion')) {
      phrases = [
        ('这件衣服很好看', 'Zhè jiàn yīfu hěn hǎokàn', 'Baju ini sangat bagus'),
        ('可以试穿一下吗？', 'Kěyǐ shìchuān yīxià ma?', 'Boleh saya coba pakai?'),
        ('有大一点的尺码吗？', 'Yǒu dà yīdiǎn de chǐmǎ ma?', 'Ada ukuran yang lebih besar?'),
      ];
    } else if (catLower.contains('hotel') || nameLower.contains('hotel') || nameLower.contains('penginapan')) {
      phrases = [
        ('我要办理入住', 'Wǒ yào bànlǐ rùzhù', 'Saya ingin proses check-in'),
        ('包含早餐吗？', 'Bāohán zǎocān ma?', 'Apakah termasuk sarapan?'),
        ('可以退房吗？', 'Kěyǐ tuìfáng ma?', 'Bisa proses check-out?'),
      ];
    } else if (catLower.contains('kafe') || catLower.contains('resto') || nameLower.contains('kopi') || nameLower.contains('makan')) {
      phrases = [
        ('服务员，买单！', 'Fúwùyuán, mǎidān!', 'Pelayan, bayar tagihannya!'),
        ('有什么推荐的菜吗？', 'Yǒu shénme tuījiàn de cài ma?', 'Ada menu makanan yang direkomendasikan?'),
        ('我要打包', 'Wǒ yào dǎbāo', 'Saya mau bungkus bawa pulang'),
      ];
    } else {
      phrases = [
        ('请问怎么去这里？', 'Qǐngwèn zěnme qù zhèlǐ?', 'Permisi, bagaimana rute ke tempat ini?'),
        ('到了吗？', 'Dàole ma?', 'Apakah sudah sampai?'),
        ('我想去这里', 'Wǒ xiǎng qù zhèlǐ', 'Saya ingin pergi ke lokasi ini'),
      ];
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
              ),
            ),

            // Header Tempat
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(child: Text(place.iconEmoji, style: const TextStyle(fontSize: 28))),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        place.nameId,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textDark),
                      ),
                      Text(
                        '${place.category} • ${place.hanzi} (${place.pinyin})',
                        style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted),
                      ),
                      Text(
                        '${distanceMeters < 1000 ? "${distanceMeters.round()} m" : "${(distanceMeters / 1000).toStringAsFixed(1)} km"} dari Anda • Arah ${direction.arti} (${direction.hanzi}) ${direction.icon}',
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF15803D)),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // KARTU LOKASI & ARAH MATA ANGIN REALTIME
            Container(
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
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Text(direction.icon, style: const TextStyle(fontSize: 20)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Arah Menuju Lokasi: ${direction.arti} (${direction.hanzi})',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF166534),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Jarak lurus: ${distanceMeters < 1000 ? "${distanceMeters.round()} meter" : "${(distanceMeters / 1000).toStringAsFixed(2)} km"} • Koordinat: ${place.latitude.toStringAsFixed(4)}, ${place.longitude.toStringAsFixed(4)}',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF15803D)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // KOSAKATA MANDARIN TEMPAT INI
            if (place.relatedVocab.isNotEmpty) ...[
              const Text(
                'Kosakata Mandarin Terkait:',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textDark),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: place.relatedVocab.map((v) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(v.iconEmoji, style: const TextStyle(fontSize: 15)),
                        const SizedBox(width: 6),
                        Text('${v.hanzi} (${v.pinyin}) - ${v.arti}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primaryDark)),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.volume_up_rounded, size: 16, color: AppColors.primaryGreen),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => AudioService.instance.speak(v.hanzi),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
            ],

            // FRASA PERCAKAPAN MANDARIN
            const Text(
              'Frasa Percakapan Mandarin yang Berguna:',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textDark),
            ),
            const SizedBox(height: 8),
            ...phrases.map((phrase) {
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(phrase.$1, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primaryDark)),
                          Text('${phrase.$2} • ${phrase.$3}', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.volume_up_rounded, size: 18, color: AppColors.primaryGreen),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => AudioService.instance.speak(phrase.$1),
                    ),
                  ],
                ),
              );
            }),

            const SizedBox(height: 18),

            // TOMBOL AKSI NAVIGASI
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    onPressed: onShowRoute,
                    icon: const Icon(Icons.map_rounded),
                    label: const Text('Lihat Jalur di Peta', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    onPressed: onOpenGoogleMaps,
                    icon: const Icon(Icons.navigation_rounded),
                    label: const Text('Google Maps HP', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
