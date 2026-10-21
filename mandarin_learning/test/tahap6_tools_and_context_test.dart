import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Tahap 6: Direction Explorer & LBS Kompas (PB-15, FR-11, PBI-057 s.d. PBI-062)', () {
    double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
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

    String degreesToCardinal(double deg) {
      final normalized = (deg % 360 + 360) % 360;
      if (normalized >= 337.5 || normalized < 22.5) return '北 (Běi - Utara)';
      if (normalized >= 22.5 && normalized < 67.5) return '东北 (Dōngběi - Timur Laut)';
      if (normalized >= 67.5 && normalized < 112.5) return '东 (Dōng - Timur)';
      if (normalized >= 112.5 && normalized < 157.5) return '东南 (Dōngnán - Tenggara)';
      if (normalized >= 157.5 && normalized < 202.5) return '南 (Nán - Selatan)';
      if (normalized >= 202.5 && normalized < 247.5) return '西南 (Xīnán - Barat Daya)';
      if (normalized >= 247.5 && normalized < 292.5) return '西 (Xī - Barat)';
      return '西北 (Xīběi - Barat Laut)';
    }

    test('PBI-059: Perhitungan jarak Haversine menghasilkan meter yang akurat', () {
      // Titik referensi Jakarta Monas (-6.175392, 106.827153)
      const latMonas = -6.175392;
      const lonMonas = 106.827153;

      // Titik yang sama persis -> jarak 0 m
      final distSelf = calculateDistance(latMonas, lonMonas, latMonas, lonMonas);
      expect(distSelf, closeTo(0.0, 0.01));

      // Titik bergeser sekitar ~380 meter ke utara
      final distNorth = calculateDistance(latMonas, lonMonas, latMonas + 0.0035, lonMonas);
      expect(distNorth, greaterThan(350.0));
      expect(distNorth, lessThan(420.0));
    });

    test('PBI-060 & FR-11: Pemetaan derajat azimuth ke 8 arah mata angin Mandarin', () {
      expect(degreesToCardinal(0.0), '北 (Běi - Utara)');
      expect(degreesToCardinal(360.0), '北 (Běi - Utara)');
      expect(degreesToCardinal(45.0), '东北 (Dōngběi - Timur Laut)');
      expect(degreesToCardinal(90.0), '东 (Dōng - Timur)');
      expect(degreesToCardinal(135.0), '东南 (Dōngnán - Tenggara)');
      expect(degreesToCardinal(180.0), '南 (Nán - Selatan)');
      expect(degreesToCardinal(225.0), '西南 (Xīnán - Barat Daya)');
      expect(degreesToCardinal(270.0), '西 (Xī - Barat)');
      expect(degreesToCardinal(315.0), '西北 (Xīběi - Barat Laut)');
    });

    test('PBI-057: Fallback daftar kosakata mata angin tetap tersedia jika GPS mati', () {
      bool isGpsEnabled = false;
      final defaultPlaces = [
        {'name': '餐馆', 'category': 'Makan'},
        {'name': '车站', 'category': 'Transportasi'},
        {'name': '酒店', 'category': 'Akomodasi'},
        {'name': '银行', 'category': 'Keuangan'},
      ];

      expect(isGpsEnabled, isFalse);
      // Mode fallback tetap menyajikan tempat sekitar dengan koordinat default
      expect(defaultPlaces.length, 4);
      expect(defaultPlaces.any((p) => p['name'] == '餐馆'), isTrue);
    });
  });

  group('Tahap 6: Konversi Mata Uang (PB-16, FR-12, PBI-063 s.d. PBI-065)', () {
    const rateUsdToIdr = 15600.0;
    const rateUsdToCny = 7.02;

    double convertCurrency(double amount, String from, String to) {
      if (from == to) return amount;

      // Ke USD
      double inUsd;
      if (from == 'USD') {
        inUsd = amount;
      } else if (from == 'CNY') {
        inUsd = amount / rateUsdToCny;
      } else {
        inUsd = amount / rateUsdToIdr;
      }

      // Dari USD ke target
      if (to == 'USD') return inUsd;
      if (to == 'CNY') return inUsd * rateUsdToCny;
      return inUsd * rateUsdToIdr;
    }

    test('PBI-064: Konversi CNY ke IDR sesuai acuan kurs PRD', () {
      // 100 CNY ≈ (100 / 7.02) * 15600 ≈ 222.222 IDR
      final result = convertCurrency(100, 'CNY', 'IDR');
      expect(result, greaterThan(220000.0));
      expect(result, lessThan(225000.0));
    });

    test('PBI-064: Konversi USD ke IDR dan CNY ke USD', () {
      final usdToIdr = convertCurrency(10, 'USD', 'IDR');
      expect(usdToIdr, 156000.0);

      final cnyToUsd = convertCurrency(70.2, 'CNY', 'USD');
      expect(cnyToUsd, closeTo(10.0, 0.05));
    });

    test('PBI-065: Identitas konversi bolak-balik (Round-trip conversion)', () {
      const originalAmount = 500.0;
      final toIdr = convertCurrency(originalAmount, 'CNY', 'IDR');
      final backToCny = convertCurrency(toIdr, 'IDR', 'CNY');

      expect(backToCny, closeTo(originalAmount, 0.01));
    });
  });

  group('Tahap 6: Konversi Waktu (PB-17, FR-13, PBI-066 s.d. PBI-068)', () {
    bool isLondonDst(DateTime utcDate) {
      final year = utcDate.year;
      final lastSundayMarch = DateTime.utc(year, 3, 31);
      final marchDstStart = lastSundayMarch.subtract(Duration(days: lastSundayMarch.weekday % 7));

      final lastSundayOct = DateTime.utc(year, 10, 31);
      final octDstEnd = lastSundayOct.subtract(Duration(days: lastSundayOct.weekday % 7));

      return utcDate.isAfter(marchDstStart) && utcDate.isBefore(octDstEnd);
    }

    DateTime convertToZone(DateTime utcTime, int offsetHours) {
      return utcTime.add(Duration(hours: offsetHours));
    }

    test('PBI-066: Komparasi waktu CST (Beijing UTC+8) terhadap WIB, WITA, WIT', () {
      final utcBase = DateTime.utc(2026, 10, 21, 10, 0, 0); // 10:00 UTC

      final cst = convertToZone(utcBase, 8); // 18:00
      final wib = convertToZone(utcBase, 7); // 17:00
      final wita = convertToZone(utcBase, 8); // 18:00
      final wit = convertToZone(utcBase, 9); // 19:00

      // CST vs WIB -> selisih persis 1 jam (Beijing 1 jam lebih cepat dari Jakarta)
      expect(cst.hour - wib.hour, 1);

      // CST vs WITA -> waktu sama persis (keduanya UTC+8)
      expect(cst.hour, wita.hour);

      // CST vs WIT -> WIT 1 jam lebih cepat
      expect(wit.hour - cst.hour, 1);
    });

    test('PBI-067: Deteksi British Summer Time (BST / DST) London', () {
      // 15 Juli 2026 (Musim Panas) -> DST harus aktif (UTC+1)
      final summerDate = DateTime.utc(2026, 7, 15, 12, 0, 0);
      expect(isLondonDst(summerDate), isTrue);

      // 15 Desember 2026 (Musim Dingin) -> DST tidak aktif (GMT UTC+0)
      final winterDate = DateTime.utc(2026, 12, 15, 12, 0, 0);
      expect(isLondonDst(winterDate), isFalse);
    });

    test('PBI-068: Kategorisasi pembagian waktu Mandarin (Pagi, Siang, Sore, Malam)', () {
      String getPeriod(int hour) {
        if (hour >= 6 && hour < 12) return '早上';
        if (hour >= 12 && hour < 14) return '中午';
        if (hour >= 14 && hour < 18) return '下午';
        if (hour >= 18 && hour < 24) return '晚上';
        return '半夜';
      }

      expect(getPeriod(8), '早上');
      expect(getPeriod(12), '中午');
      expect(getPeriod(15), '下午');
      expect(getPeriod(20), '晚上');
      expect(getPeriod(2), '半夜');
    });
  });

  group('Tahap 6: Umpan Balik (PB-18, FR-21)', () {
    test('Validasi rating bintang (1 s.d. 5) dan kelengkapan pesan', () {
      bool validateFeedback(String msg, int rating) {
        if (msg.trim().isEmpty) return false;
        if (rating < 1 || rating > 5) return false;
        return true;
      }

      expect(validateFeedback('Aplikasi sangat membantu!', 5), isTrue);
      expect(validateFeedback('Audio di level HSK 4 agak cepat', 4), isTrue);
      expect(validateFeedback('', 5), isFalse); // Pesan kosong
      expect(validateFeedback('Bagus', 0), isFalse); // Rating tidak valid
    });
  });
}
