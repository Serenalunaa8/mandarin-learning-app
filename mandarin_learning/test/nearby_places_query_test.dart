import 'package:flutter_test/flutter_test.dart';
import 'package:mandarin_learning/services/nearby_places_query.dart';

void main() {
  group('Kueri tempat sekitar', () {
    test('Meminta tempat makan tanpa mensyaratkan nama OSM', () {
      final query = buildNearbyPlacesQuery(
        radiusMeters: 2000,
        latitude: -6.2,
        longitude: 106.8,
      );

      expect(query, contains('around:2000,-6.2,106.8'));
      expect(query, contains('["amenity"~"^(restaurant|cafe|fast_food'));
      expect(query, contains('ice_cream|bakery|bar|pub|canteen'));
      expect(
        query,
        contains(
          'nwr(around:2000,-6.2,106.8)["amenity"~"^(restaurant|cafe|fast_food',
        ),
      );
    });

    test('Meminta halte, stasiun, dan platform tanpa mensyaratkan nama', () {
      final query = buildNearbyPlacesQuery(
        radiusMeters: 2000,
        latitude: -6.2,
        longitude: 106.8,
      );

      expect(query, contains('["amenity"="bus_station"]'));
      expect(query, contains('["highway"="bus_stop"]'));
      expect(query, contains('station|halt|tram_stop|subway_entrance'));
      expect(query, contains('platform|station|stop_position'));
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
