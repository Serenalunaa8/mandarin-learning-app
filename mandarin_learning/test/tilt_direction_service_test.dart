import 'package:flutter_test/flutter_test.dart';
import 'package:mandarin_learning/services/tilt_direction_service.dart';

void main() {
  group('Pemetaan arah Tilt to Answer', () {
    test('Kemiringan kiri memilih kartu kiri', () {
      expect(optionForTiltX(4.0), 0);
    });

    test('Kemiringan kanan memilih kartu kanan', () {
      expect(optionForTiltX(-4.0), 1);
    });

    test('Posisi netral tidak memilih kartu', () {
      expect(optionForTiltX(0), isNull);
      expect(optionForTiltX(3.5), isNull);
      expect(optionForTiltX(-3.5), isNull);
    });
  });
}
