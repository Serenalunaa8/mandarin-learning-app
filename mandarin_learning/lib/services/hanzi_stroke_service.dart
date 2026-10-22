import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class HanziStrokeData {
  final List<List<Offset>> strokes;

  const HanziStrokeData(this.strokes);

  factory HanziStrokeData.fromJson(Map<String, dynamic> json) {
    final medians = json['medians'];
    if (medians is! List || medians.isEmpty) {
      throw const FormatException('Data urutan stroke Hanzi kosong.');
    }
    final strokes = <List<Offset>>[];
    for (final median in medians) {
      if (median is! List || median.length < 2) {
        throw const FormatException('Data lintasan stroke Hanzi tidak valid.');
      }
      final points = <Offset>[];
      for (final point in median) {
        if (point is! List || point.length < 2 ||
            point[0] is! num || point[1] is! num) {
          throw const FormatException('Koordinat stroke Hanzi tidak valid.');
        }
        points.add(Offset(
          (point[0] as num).toDouble(),
          (point[1] as num).toDouble(),
        ));
      }
      strokes.add(points);
    }
    return HanziStrokeData(strokes);
  }
}

class HanziStrokeService {
  static final HanziStrokeService instance = HanziStrokeService._();
  HanziStrokeService._();

  final Map<String, HanziStrokeData> _cache = {};

  Future<HanziStrokeData> load(String character) async {
    final cached = _cache[character];
    if (cached != null) return cached;

    final response = await http
        .get(
          Uri.https(
            'cdn.jsdelivr.net',
            '/npm/hanzi-writer-data@2.0.1/$character.json',
          ),
        )
        .timeout(const Duration(seconds: 15));
    if (response.statusCode == 404) {
      throw StateError('Panduan stroke untuk $character tidak tersedia.');
    }
    if (response.statusCode != 200) {
      throw StateError(
        'Layanan panduan stroke merespons ${response.statusCode}.',
      );
    }
    final json = jsonDecode(response.body);
    if (json is! Map<String, dynamic>) {
      throw const FormatException('Data panduan stroke tidak valid.');
    }
    final data = HanziStrokeData.fromJson(json);
    _cache[character] = data;
    return data;
  }
}

int compareHanziStrokes({
  required List<List<Offset>> drawnStrokes,
  required HanziStrokeData reference,
  required Size canvasSize,
}) {
  if (drawnStrokes.isEmpty || canvasSize.isEmpty) return 0;

  final side = math.min(canvasSize.width, canvasSize.height);
  final left = (canvasSize.width - side) / 2;
  final top = (canvasSize.height - side) / 2;
  final normalizedDrawn = drawnStrokes.map((stroke) {
    return stroke.map((point) {
      return Offset(
        ((point.dx - left) / side * 1024).clamp(0, 1024).toDouble(),
        ((point.dy - top) / side * 1024).clamp(0, 1024).toDouble(),
      );
    }).toList();
  }).toList();

  final comparedCount = math.min(normalizedDrawn.length, reference.strokes.length);
  var totalError = 0.0;
  var sampleCount = 0;
  for (var index = 0; index < comparedCount; index++) {
    final expected = _resample(reference.strokes[index], 12);
    final actual = _resample(normalizedDrawn[index], 12);
    if (expected.isEmpty || actual.isEmpty) continue;
    for (var pointIndex = 0; pointIndex < expected.length; pointIndex++) {
      totalError += (expected[pointIndex] - actual[pointIndex]).distance / 1448;
      sampleCount++;
    }
  }

  if (sampleCount == 0) return 0;
  final shapeError = totalError / sampleCount;
  final missingStrokeRatio =
      (normalizedDrawn.length - reference.strokes.length).abs() /
      reference.strokes.length;
  final error = shapeError + missingStrokeRatio * 0.5;
  return ((1 - error / 0.22) * 100).round().clamp(0, 100);
}

List<Offset> _resample(List<Offset> points, int count) {
  if (points.length < 2) return points;
  final lengths = <double>[0];
  for (var index = 1; index < points.length; index++) {
    lengths.add(lengths.last + (points[index] - points[index - 1]).distance);
  }
  final totalLength = lengths.last;
  if (totalLength <= 0) return List.filled(count, points.first);

  final samples = <Offset>[];
  for (var sample = 0; sample < count; sample++) {
    final targetLength = totalLength * sample / (count - 1);
    var segment = 1;
    while (segment < lengths.length - 1 && lengths[segment] < targetLength) {
      segment++;
    }
    final segmentLength = lengths[segment] - lengths[segment - 1];
    final fraction = segmentLength == 0
        ? 0.0
        : (targetLength - lengths[segment - 1]) / segmentLength;
    samples.add(Offset.lerp(points[segment - 1], points[segment], fraction)!);
  }
  return samples;
}
