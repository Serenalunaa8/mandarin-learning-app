import 'dart:math' as math;

/// Calculates a tilt-compensated compass heading in degrees (0°–360°).
double? calculateCompassHeading({
  required List<double> acceleration,
  required List<double> magneticField,
}) {
  if (acceleration.length != 3 || magneticField.length != 3) return null;

  final gravity = _normalize(acceleration);
  final magnetic = _normalize(magneticField);
  if (gravity == null || magnetic == null) return null;

  final east = _normalize(_cross(magnetic, gravity));
  if (east == null) return null;
  final north = _normalize(_cross(gravity, east));
  if (north == null) return null;

  final heading = math.atan2(east[1], north[1]) * (180 / math.pi);
  return (heading + 360) % 360;
}

double smoothCompassHeading(
  double? previous,
  double current, {
  double smoothing = 0.16,
}) {
  final normalizedCurrent = (current % 360 + 360) % 360;
  if (previous == null) return normalizedCurrent;
  final normalizedPrevious = (previous % 360 + 360) % 360;
  final delta = ((normalizedCurrent - normalizedPrevious + 540) % 360) - 180;
  return (normalizedPrevious + delta * smoothing + 360) % 360;
}

double compassHeadingDifference(double a, double b) {
  return (((a - b + 540) % 360) - 180).abs();
}

List<double>? _normalize(List<double> vector) {
  final magnitude = math.sqrt(
    vector.fold<double>(0, (sum, value) => sum + value * value),
  );
  if (magnitude < 1e-6) return null;
  return vector.map((value) => value / magnitude).toList();
}

List<double> _cross(List<double> a, List<double> b) => [
  a[1] * b[2] - a[2] * b[1],
  a[2] * b[0] - a[0] * b[2],
  a[0] * b[1] - a[1] * b[0],
];
