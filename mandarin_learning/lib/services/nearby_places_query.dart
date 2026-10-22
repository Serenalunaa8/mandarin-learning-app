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
  nwr(around:$radiusMeters,$latitude,$longitude)["amenity"~"^(restaurant|cafe|fast_food|food_court|ice_cream|bakery|bar|pub|canteen)\$"];
  nwr(around:$radiusMeters,$latitude,$longitude)["amenity"="bus_station"];
  nwr(around:$radiusMeters,$latitude,$longitude)["highway"="bus_stop"];
  nwr(around:$radiusMeters,$latitude,$longitude)["railway"~"^(station|halt|tram_stop|subway_entrance)\$"];
  nwr(around:$radiusMeters,$latitude,$longitude)["public_transport"~"^(platform|station|stop_position)\$"];
);
out center;
''';
}
