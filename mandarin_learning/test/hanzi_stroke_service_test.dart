import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mandarin_learning/services/hanzi_stroke_service.dart';

void main() {
  group('HanziStrokeData', () {
    test('parses ordered medians from stroke data', () {
      final data = HanziStrokeData.fromJson({
        'medians': [
          [
            [100, 100],
            [900, 900],
          ],
          [
            [900, 100],
            [100, 900],
          ],
        ],
      });

      expect(data.strokes, hasLength(2));
      expect(data.strokes.first.first.dx, 100);
      expect(data.strokes.last.last.dy, 900);
    });

    test('rejects missing or malformed medians', () {
      expect(
        () => HanziStrokeData.fromJson({'medians': []}),
        throwsFormatException,
      );
    });
  });

  test('compares written shapes and stroke order against real medians', () {
    const reference = HanziStrokeData([
      [Offset(0, 0), Offset(1024, 1024)],
      [Offset(1024, 0), Offset(0, 1024)],
    ]);
    final matchingWriting = compareHanziStrokes(
      drawnStrokes: const [
        [Offset(0, 0), Offset(100, 100)],
        [Offset(100, 0), Offset(0, 100)],
      ],
      reference: reference,
      canvasSize: const Size(100, 100),
    );
    final wrongStrokeOrder = compareHanziStrokes(
      drawnStrokes: const [
        [Offset(100, 0), Offset(0, 100)],
        [Offset(0, 0), Offset(100, 100)],
      ],
      reference: reference,
      canvasSize: const Size(100, 100),
    );

    expect(matchingWriting, 100);
    expect(wrongStrokeOrder, lessThan(matchingWriting));
  });
}
