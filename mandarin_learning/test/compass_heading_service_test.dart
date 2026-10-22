import 'package:flutter_test/flutter_test.dart';
import 'package:mandarin_learning/services/compass_heading_service.dart';

void main() {
  group('calculateCompassHeading', () {
    const acceleration = [0.0, 0.0, 1.0];

    test('returns cardinal headings', () {
      expect(
        calculateCompassHeading(
          acceleration: acceleration,
          magneticField: [0, 1, 0],
        ),
        closeTo(0, 0.001),
      );
      expect(
        calculateCompassHeading(
          acceleration: acceleration,
          magneticField: [-1, 0, 0],
        ),
        closeTo(90, 0.001),
      );
      expect(
        calculateCompassHeading(
          acceleration: acceleration,
          magneticField: [0, -1, 0],
        ),
        closeTo(180, 0.001),
      );
      expect(
        calculateCompassHeading(
          acceleration: acceleration,
          magneticField: [1, 0, 0],
        ),
        closeTo(270, 0.001),
      );
    });

    test('returns null when sensor vectors cannot define a heading', () {
      expect(
        calculateCompassHeading(
          acceleration: [0, 0, 0],
          magneticField: [0, 1, 0],
        ),
        isNull,
      );
      expect(
        calculateCompassHeading(
          acceleration: acceleration,
          magneticField: [0, 0, 1],
        ),
        isNull,
      );
    });
  });

  group('smoothCompassHeading', () {
    test('smooths across north using the shortest angular direction', () {
      expect(smoothCompassHeading(359, 1), closeTo(359.32, 0.001));
      expect(smoothCompassHeading(1, 359), closeTo(0.68, 0.001));
    });

    test('normalizes the first heading into the compass range', () {
      expect(smoothCompassHeading(null, 361), closeTo(1, 0.001));
    });
  });
}
