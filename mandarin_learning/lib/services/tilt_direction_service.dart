int? optionForTiltX(double accelerationX, {double threshold = 3.5}) {
  if (accelerationX > threshold) return 0;
  if (accelerationX < -threshold) return 1;
  return null;
}
