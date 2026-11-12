import 'package:flutter_test/flutter_test.dart';
import 'package:nihaoki/services/nearby_places_query.dart';

void main() {
  group('Kueri tempat sekitar', () {
    test(
      'Hanya meminta tempat bernama agar hasil bisa ditampilkan langsung',
      () {
        final query = buildNearbyPlacesQuery(
          radiusMeters: 2000,
          latitude: -6.2,
          longitude: 106.8,
        );

        expect(query, contains('around:2000,-6.2,106.8'));
        expect(query, contains('["name"]["amenity"]'));
        expect(query, contains('["name"]["shop"]'));
        expect(query, contains('["name"]["tourism"]'));
        expect(query, contains('"highway"="bus_stop"'));
      },
    );

    test('Meminta transportasi umum bernama', () {
      final query = buildNearbyPlacesQuery(
        radiusMeters: 2000,
        latitude: -6.2,
        longitude: 106.8,
      );

      expect(query, contains('["name"]["public_transport"]'));
      expect(query, contains('["name"]["railway"~"station|halt|tram_stop"]'));
      expect(query, contains('["name"]["highway"="bus_stop"]'));
    });

    test('Tidak membatasi jumlah data tempat hasil pencarian', () {
      final query = buildNearbyPlacesQuery(
        radiusMeters: 2000,
        latitude: -6.2,
        longitude: 106.8,
      );

      expect(query, contains('out center;'));
      expect(query, isNot(contains('out center 80')));
    });

    test('Menolak koordinat dan radius tidak valid', () {
      expect(
        () =>
            buildNearbyPlacesQuery(radiusMeters: 0, latitude: 0, longitude: 0),
        throwsArgumentError,
      );
      expect(
        () => buildNearbyPlacesQuery(
          radiusMeters: 1000,
          latitude: 91,
          longitude: 0,
        ),
        throwsArgumentError,
      );
    });
  });
}
