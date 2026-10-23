String buildNearbyPlacesQuery({
  required int radiusMeters,
  required double latitude,
  required double longitude,
}) {
  if (radiusMeters <= 0 ||
      !latitude.isFinite ||
      !longitude.isFinite ||
      latitude < -90 ||
      latitude > 90 ||
      longitude < -180 ||
      longitude > 180) {
    throw ArgumentError('Koordinat atau radius pencarian tempat tidak valid.');
  }

  return '''
[out:json][timeout:20];
(
  nwr(around:$radiusMeters,$latitude,$longitude)["name"]["amenity"];
  nwr(around:$radiusMeters,$latitude,$longitude)["name"]["shop"];
  nwr(around:$radiusMeters,$latitude,$longitude)["name"]["tourism"];
  nwr(around:$radiusMeters,$latitude,$longitude)["name"]["leisure"];
  nwr(around:$radiusMeters,$latitude,$longitude)["name"]["public_transport"];
  nwr(around:$radiusMeters,$latitude,$longitude)["name"]["office"];
);
out center;
''';
}
