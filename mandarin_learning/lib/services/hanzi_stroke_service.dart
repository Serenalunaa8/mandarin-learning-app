import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class HanziStrokeData {
  final List<List<Offset>> strokes;
  final List<Path> strokeOutlines;

  const HanziStrokeData(this.strokes, [this.strokeOutlines = const []]);

  factory HanziStrokeData.fromJson(
    Map<String, dynamic> json, {
    bool isFontCoordinates = false,
  }) {
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
        if (point is! List ||
            point.length < 2 ||
            point[0] is! num ||
            point[1] is! num) {
          throw const FormatException('Koordinat stroke Hanzi tidak valid.');
        }
        final rawX = (point[0] as num).toDouble();
        final rawY = (point[1] as num).toDouble();
        // Make Me a Hanzi outlines and medians share the same font coordinate
        // plane, whose top edge is y=900. Reflect around that same edge as the
        // SVG parser below so the active guide sits on its gray stroke.
        final screenY = isFontCoordinates ? (900.0 - rawY) : rawY;
        points.add(Offset(rawX, screenY));
      }
      strokes.add(points);
    }

    final strokeOutlines = <Path>[];
    final rawStrokes = json['strokes'];
    if (rawStrokes is List) {
      for (final s in rawStrokes) {
        if (s is String) {
          strokeOutlines.add(
            parseSingleSvgPath(s, isFontCoordinates: isFontCoordinates),
          );
        }
      }
    }

    return HanziStrokeData(strokes, strokeOutlines);
  }
}

/// Helper untuk mengurai SVG outline path resmi HanziWriter (M, L, Q, C, Z)
Path parseSingleSvgPath(String svg, {bool isFontCoordinates = true}) {
  final path = Path();
  final regExp = RegExp(r'[A-Za-z]|-?\d+(?:\.\d+)?');
  final matches = regExp.allMatches(svg);
  final tokens = matches.map((m) => m.group(0)!).toList();

  var i = 0;
  String currentCmd = '';
  while (i < tokens.length) {
    final t = tokens[i];
    if (RegExp(r'^[A-Za-z]$').hasMatch(t)) {
      currentCmd = t;
      i++;
    }

    if (currentCmd == 'M') {
      if (i + 1 < tokens.length) {
        final x = double.parse(tokens[i]);
        final rawY = double.parse(tokens[i + 1]);
        final y = isFontCoordinates ? (900.0 - rawY) : rawY;
        path.moveTo(x, y);
        i += 2;
        currentCmd = 'L';
      } else {
        break;
      }
    } else if (currentCmd == 'L') {
      if (i + 1 < tokens.length) {
        final x = double.parse(tokens[i]);
        final rawY = double.parse(tokens[i + 1]);
        final y = isFontCoordinates ? (900.0 - rawY) : rawY;
        path.lineTo(x, y);
        i += 2;
      } else {
        break;
      }
    } else if (currentCmd == 'Q') {
      if (i + 3 < tokens.length) {
        final x1 = double.parse(tokens[i]);
        final rawY1 = double.parse(tokens[i + 1]);
        final y1 = isFontCoordinates ? (900.0 - rawY1) : rawY1;
        final x = double.parse(tokens[i + 2]);
        final rawY = double.parse(tokens[i + 3]);
        final y = isFontCoordinates ? (900.0 - rawY) : rawY;
        path.quadraticBezierTo(x1, y1, x, y);
        i += 4;
      } else {
        break;
      }
    } else if (currentCmd == 'C') {
      if (i + 5 < tokens.length) {
        final x1 = double.parse(tokens[i]);
        final rawY1 = double.parse(tokens[i + 1]);
        final y1 = isFontCoordinates ? (900.0 - rawY1) : rawY1;
        final x2 = double.parse(tokens[i + 2]);
        final rawY2 = double.parse(tokens[i + 3]);
        final y2 = isFontCoordinates ? (900.0 - rawY2) : rawY2;
        final x = double.parse(tokens[i + 4]);
        final rawY = double.parse(tokens[i + 5]);
        final y = isFontCoordinates ? (900.0 - rawY) : rawY;
        path.cubicTo(x1, y1, x2, y2, x, y);
        i += 6;
      } else {
        break;
      }
    } else if (currentCmd == 'Z') {
      path.close();
      currentCmd = '';
    } else {
      i++;
    }
  }
  return path;
}

/// Informasi resmi tahapan penulisan goresan bahasa Mandarin (笔画 - Bǐhuà & 笔顺 - Bǐshùn)
class MandarinStrokeInfo {
  final String hanziName; // '撇', '捺', '横', '竖', '点', '提', '横折', '竖钩', dll
  final String pinyinName; // 'Piě', 'Nà', 'Héng', 'Shù', 'Diǎn', 'Tí', dll
  final String symbol; // '丿', '㇏', '一', '丨', '丶', '㇀', '𠃍', '亅'
  final String direction; // Deskripsi arah goresan
  final String description; // Penjelasan langkah penulisan
  final String rule; // Kaidah 笔顺 (e.g. 先撇后捺, 从上到下, 先横后竖)

  const MandarinStrokeInfo({
    required this.hanziName,
    required this.pinyinName,
    required this.symbol,
    required this.direction,
    required this.description,
    required this.rule,
  });

  String get displayName => '$pinyinName ($hanziName)';
}

/// Hasil evaluasi multi-tahap penulisan Hanzi
class HanziEvaluationResult {
  final int totalScore;
  final bool isCountValid;
  final int expectedStrokeCount;
  final int actualStrokeCount;
  final bool isOrderAndDirectionValid;
  final int directionScore;
  final int shapeScore;
  final bool isPassed;
  final String feedbackTitle;
  final String feedbackMessage;

  const HanziEvaluationResult({
    required this.totalScore,
    required this.isCountValid,
    required this.expectedStrokeCount,
    required this.actualStrokeCount,
    required this.isOrderAndDirectionValid,
    required this.directionScore,
    required this.shapeScore,
    required this.isPassed,
    required this.feedbackTitle,
    required this.feedbackMessage,
  });
}

class HanziStrokeService {
  static final HanziStrokeService instance = HanziStrokeService._();
  HanziStrokeService._();

  final Map<String, HanziStrokeData> _cache = {};

  // Offline fallback data untuk karakter umum bila jaringan lambat/offline
  static const Map<String, List<List<List<int>>>> _fallbackMedians = {
    '一': [
      [
        [150, 512],
        [874, 512],
      ],
    ],
    '二': [
      [
        [250, 360],
        [774, 360],
      ],
      [
        [150, 680],
        [874, 680],
      ],
    ],
    '三': [
      [
        [260, 280],
        [764, 280],
      ],
      [
        [320, 512],
        [704, 512],
      ],
      [
        [150, 750],
        [874, 750],
      ],
    ],
    '人': [
      [
        [512, 200],
        [200, 850],
      ],
      [
        [460, 480],
        [824, 850],
      ],
    ],
    '大': [
      [
        [150, 400],
        [874, 400],
      ],
      [
        [512, 180],
        [220, 860],
      ],
      [
        [460, 450],
        [804, 860],
      ],
    ],
    '十': [
      [
        [150, 512],
        [874, 512],
      ],
      [
        [512, 180],
        [512, 850],
      ],
    ],
    '爱': [
      [
        [627, 120],
        [338, 178],
      ],
      [
        [304, 231],
        [382, 310],
      ],
      [
        [456, 210],
        [512, 280],
      ],
      [
        [660, 164],
        [583, 298],
      ],
      [
        [211, 355],
        [168, 545],
      ],
      [
        [248, 419],
        [734, 449],
      ],
      [
        [283, 513],
        [674, 468],
      ],
      [
        [435, 394],
        [148, 854],
      ],
      [
        [410, 625],
        [265, 890],
      ],
      [
        [391, 672],
        [898, 894],
      ],
    ],
    '你': [
      [
        [317, 88],
        [68, 533],
      ],
      [
        [273, 342],
        [260, 859],
      ],
      [
        [556, 72],
        [406, 469],
      ],
      [
        [513, 368],
        [746, 440],
      ],
      [
        [586, 437],
        [490, 815],
      ],
      [
        [455, 584],
        [397, 749],
      ],
      [
        [742, 574],
        [878, 746],
      ],
    ],
    '好': [
      [
        [282, 112],
        [424, 767],
      ],
      [
        [390, 344],
        [137, 803],
      ],
      [
        [59, 443],
        [380, 399],
      ],
      [
        [493, 244],
        [663, 364],
      ],
      [
        [613, 370],
        [551, 815],
      ],
      [
        [449, 516],
        [960, 488],
      ],
    ],
  };

  Future<HanziStrokeData> load(String character) async {
    final cached = _cache[character];
    if (cached != null) return cached;

    // Coba ambil dari MakeMeAHanzi / hanzi-writer CDN
    try {
      final response = await http
          .get(
            Uri.https(
              'cdn.jsdelivr.net',
              '/npm/hanzi-writer-data@2.0.1/$character.json',
            ),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json is Map<String, dynamic>) {
          final data = HanziStrokeData.fromJson(json, isFontCoordinates: true);
          _cache[character] = data;
          return data;
        }
      }
    } catch (_) {
      // Abaikan error jaringan dan coba fallback
    }

    // Cek fallback data bawaan
    if (_fallbackMedians.containsKey(character)) {
      final rawMedians = _fallbackMedians[character]!;
      final strokes = rawMedians.map((stroke) {
        return stroke
            .map((pt) => Offset(pt[0].toDouble(), pt[1].toDouble()))
            .toList();
      }).toList();
      final data = HanziStrokeData(strokes);
      _cache[character] = data;
      return data;
    }

    throw StateError('Panduan stroke untuk $character tidak tersedia.');
  }

  /// Mengambil informasi resmi tahapan goresan Hanzi (Bihua & Bishun)
  MandarinStrokeInfo getMandarinStrokeInfo({
    required String character,
    required int strokeIndex,
    required List<Offset> points,
    int totalStrokes = 1,
  }) {
    if (_curatedStrokes.containsKey(character)) {
      final list = _curatedStrokes[character]!;
      if (strokeIndex >= 0 && strokeIndex < list.length) {
        return list[strokeIndex];
      }
    }
    return _classifyStrokeFromPoints(points, strokeIndex, totalStrokes);
  }

  static const Map<String, List<MandarinStrokeInfo>> _curatedStrokes = {
    '人': [
      MandarinStrokeInfo(
        hanziName: '撇',
        pinyinName: 'Pie',
        symbol: '丿',
        direction: 'Miring ke kiri bawah',
        description: 'Tarik goresan dari atas meluncur ke kiri bawah',
        rule: '先撇后捺 (Miring kiri dulu, baru miring kanan)',
      ),
      MandarinStrokeInfo(
        hanziName: '捺',
        pinyinName: 'Na',
        symbol: '㇏',
        direction: 'Miring ke kanan bawah',
        description:
            'Mulai dari goresan Pie, tarik melebar mantap ke kanan bawah',
        rule: '先撇后捺 (Miring kiri dulu, baru miring kanan)',
      ),
    ],
    '一': [
      MandarinStrokeInfo(
        hanziName: '横',
        pinyinName: 'Heng',
        symbol: '一',
        direction: 'Garis mendatar (kiri ke kanan)',
        description: 'Tarik mendatar lurus dari kiri ke kanan',
        rule: '从左到右 (Dari kiri ke kanan)',
      ),
    ],
    '二': [
      MandarinStrokeInfo(
        hanziName: '横',
        pinyinName: 'Heng',
        symbol: '一',
        direction: 'Mendatar atas (pendek)',
        description: 'Tarik garis mendatar pendek di bagian atas',
        rule: '从上到下 (Dari atas ke bawah)',
      ),
      MandarinStrokeInfo(
        hanziName: '横',
        pinyinName: 'Heng',
        symbol: '一',
        direction: 'Mendatar bawah (panjang)',
        description:
            'Tarik garis mendatar lebih panjang sebagai penopang dasar',
        rule: '从上到下 (Dari atas ke bawah)',
      ),
    ],
    '三': [
      MandarinStrokeInfo(
        hanziName: '横',
        pinyinName: 'Heng',
        symbol: '一',
        direction: 'Mendatar atas',
        description: 'Garis mendatar sedang di bagian atas',
        rule: '从上到下 (Dari atas ke bawah)',
      ),
      MandarinStrokeInfo(
        hanziName: '横',
        pinyinName: 'Heng',
        symbol: '一',
        direction: 'Mendatar tengah (pendek)',
        description: 'Garis mendatar paling pendek di posisi tengah',
        rule: '从上到下 (Dari atas ke bawah)',
      ),
      MandarinStrokeInfo(
        hanziName: '横',
        pinyinName: 'Heng',
        symbol: '一',
        direction: 'Mendatar bawah (panjang)',
        description: 'Garis mendatar panjang sebagai dasar karakter',
        rule: '从上到下 (Dari atas ke bawah)',
      ),
    ],
    '十': [
      MandarinStrokeInfo(
        hanziName: '横',
        pinyinName: 'Heng',
        symbol: '一',
        direction: 'Garis mendatar (kiri ke kanan)',
        description: 'Tarik garis mendatar dari kiri ke kanan',
        rule: '先横后竖 (Mendatar dulu, baru tegak lurus)',
      ),
      MandarinStrokeInfo(
        hanziName: '竖',
        pinyinName: 'Shu',
        symbol: '丨',
        direction: 'Garis tegak lurus (atas ke bawah)',
        description: 'Tarik tegak lurus dari atas menembus garis mendatar',
        rule: '先横后竖 (Mendatar dulu, baru tegak lurus)',
      ),
    ],
    '大': [
      MandarinStrokeInfo(
        hanziName: '横',
        pinyinName: 'Heng',
        symbol: '一',
        direction: 'Garis mendatar',
        description: 'Tarik garis mendatar di bagian atas',
        rule: '先横后撇 (Mendatar dulu, baru miring kiri)',
      ),
      MandarinStrokeInfo(
        hanziName: '撇',
        pinyinName: 'Pie',
        symbol: '丿',
        direction: 'Miring ke kiri bawah',
        description: 'Tarik dari atas tengah melengkung ke kiri bawah',
        rule: '先撇后捺 (Miring kiri dulu, baru miring kanan)',
      ),
      MandarinStrokeInfo(
        hanziName: '捺',
        pinyinName: 'Na',
        symbol: '㇏',
        direction: 'Miring ke kanan bawah',
        description: 'Tarik dari titik persimpangan miring ke kanan bawah',
        rule: '先撇后捺 (Miring kiri dulu, baru miring kanan)',
      ),
    ],
    '口': [
      MandarinStrokeInfo(
        hanziName: '竖',
        pinyinName: 'Shu',
        symbol: '丨',
        direction: 'Garis tegak kiri',
        description:
            'Tarik tegak lurus dari atas ke bawah di sisi kiri bingkai',
        rule: '先外后里再封口 (Luar, dalam, lalu tutup)',
      ),
      MandarinStrokeInfo(
        hanziName: '横折',
        pinyinName: 'Heng Zhe',
        symbol: '𠃍',
        direction: 'Mendatar lalu belok ke bawah',
        description: 'Tarik mendatar ke kanan lalu belok tegak ke bawah',
        rule: '先横后折 (Mendatar lalu belok bawah)',
      ),
      MandarinStrokeInfo(
        hanziName: '横',
        pinyinName: 'Heng',
        symbol: '一',
        direction: 'Garis penutup bawah',
        description: 'Tarik mendatar dari kiri ke kanan menutup bingkai',
        rule: '最后封口 (Tutup bagian bawah paling akhir)',
      ),
    ],
    '日': [
      MandarinStrokeInfo(
        hanziName: '竖',
        pinyinName: 'Shu',
        symbol: '丨',
        direction: 'Garis tegak kiri',
        description: 'Tegak lurus sisi kiri bingkai',
        rule: '先外后里再封口 (Luar, isi, lalu tutup)',
      ),
      MandarinStrokeInfo(
        hanziName: '横折',
        pinyinName: 'Heng Zhe',
        symbol: '𠃍',
        direction: 'Mendatar lalu belok ke bawah',
        description: 'Mendatar ke kanan lalu belok lurus ke bawah',
        rule: '先横后折 (Mendatar lalu belok)',
      ),
      MandarinStrokeInfo(
        hanziName: '横',
        pinyinName: 'Heng',
        symbol: '一',
        direction: 'Garis mendatar tengah',
        description: 'Isi garis mendatar di bagian dalam kotak',
        rule: '先里后封口 (Isi bagian dalam dulu)',
      ),
      MandarinStrokeInfo(
        hanziName: '横',
        pinyinName: 'Heng',
        symbol: '一',
        direction: 'Garis penutup bawah',
        description: 'Tutup kotak di sisi bawah dari kiri ke kanan',
        rule: '最后封口 (Tutup bagian bawah paling akhir)',
      ),
    ],
    '月': [
      MandarinStrokeInfo(
        hanziName: '撇',
        pinyinName: 'Pie',
        symbol: '丿',
        direction: 'Tegak miring ke kiri',
        description: 'Tarik tegak sedikit meluncur ke kiri bawah',
        rule: '从左到右 (Dari kiri ke kanan)',
      ),
      MandarinStrokeInfo(
        hanziName: '横折钩',
        pinyinName: 'Heng Zhe Gou',
        symbol: '𠃌',
        direction: 'Mendatar belok bawah berkait',
        description:
            'Mendatar ke kanan, belok ke bawah, lalu kaitkan ke kiri atas',
        rule: '横折钩 (Mendatar belok berkait)',
      ),
      MandarinStrokeInfo(
        hanziName: '横',
        pinyinName: 'Heng',
        symbol: '一',
        direction: 'Mendatar dalam atas',
        description: 'Garis mendatar pertama di bagian dalam',
        rule: '从上到下 (Dari atas ke bawah)',
      ),
      MandarinStrokeInfo(
        hanziName: '横',
        pinyinName: 'Heng',
        symbol: '一',
        direction: 'Mendatar dalam bawah',
        description: 'Garis mendatar kedua di bagian dalam',
        rule: '从上到下 (Dari atas ke bawah)',
      ),
    ],
    '你': [
      MandarinStrokeInfo(
        hanziName: '撇',
        pinyinName: 'Pie',
        symbol: '丿',
        direction: 'Miring ke kiri bawah',
        description: 'Radikal orang (亻): tarik miring ke kiri bawah',
        rule: '从左到右 (Kiri dulu baru kanan)',
      ),
      MandarinStrokeInfo(
        hanziName: '竖',
        pinyinName: 'Shu',
        symbol: '丨',
        direction: 'Garis tegak lurus',
        description: 'Radikal orang (亻): tarik tegak lurus ke bawah',
        rule: '先撇后竖 (Miring kiri dulu, baru tegak)',
      ),
      MandarinStrokeInfo(
        hanziName: '撇',
        pinyinName: 'Pie',
        symbol: '丿',
        direction: 'Miring pendek atas',
        description: 'Garis miring pendek di bagian kanan atas',
        rule: '从上到下 (Dari atas ke bawah)',
      ),
      MandarinStrokeInfo(
        hanziName: '横钩',
        pinyinName: 'Heng Gou',
        symbol: '乛',
        direction: 'Mendatar berkait',
        description: 'Tarik mendatar lalu kaitkan kecil ke bawah',
        rule: '先横后钩 (Mendatar lalu berkait)',
      ),
      MandarinStrokeInfo(
        hanziName: '竖钩',
        pinyinName: 'Shu Gou',
        symbol: '亅',
        direction: 'Tegak lurus berkait',
        description: 'Tarik tegak di tengah lalu kaitkan ke kiri atas',
        rule: '先中间后两边 (Tengah dulu baru kedua sisi)',
      ),
      MandarinStrokeInfo(
        hanziName: '撇',
        pinyinName: 'Pie',
        symbol: '丿',
        direction: 'Miring ke kiri',
        description: 'Garis miring penyeimbang di sisi kiri bawah',
        rule: '先左后右 (Sisi kiri dulu baru kanan)',
      ),
      MandarinStrokeInfo(
        hanziName: '点',
        pinyinName: 'Dian',
        symbol: '丶',
        direction: 'Titik di kanan',
        description: 'Titik penyeimbang akhir di sisi kanan',
        rule: '最后一点 (Titik penutup di akhir)',
      ),
    ],
    '好': [
      MandarinStrokeInfo(
        hanziName: '撇折',
        pinyinName: 'Pie Zhe',
        symbol: '𠃋',
        direction: 'Miring kiri belok kanan',
        description: 'Radikal perempuan (女): miring kiri lalu belok ke kanan',
        rule: '从左到右 (Kiri dulu baru kanan)',
      ),
      MandarinStrokeInfo(
        hanziName: '撇',
        pinyinName: 'Pie',
        symbol: '丿',
        direction: 'Miring menyilang',
        description: 'Tarik miring menyilang ke kiri bawah',
        rule: '从上到下 (Dari atas ke bawah)',
      ),
      MandarinStrokeInfo(
        hanziName: '提',
        pinyinName: 'Ti',
        symbol: '㇀',
        direction: 'Serong naik ke kanan',
        description: 'Tarik serong naik ke kanan atas menyelesaikan 女',
        rule: '从左下到右上 (Dari kiri bawah ke kanan atas)',
      ),
      MandarinStrokeInfo(
        hanziName: '横撇',
        pinyinName: 'Heng Pie',
        symbol: '㇇',
        direction: 'Mendatar miring kiri',
        description: 'Karakter anak (子): mendatar lalu miring ke kiri',
        rule: '从上到下 (Dari atas ke bawah)',
      ),
      MandarinStrokeInfo(
        hanziName: '竖弯钩',
        pinyinName: 'Shu Wan Gou',
        symbol: '乚',
        direction: 'Tegak lengkung berkait',
        description: 'Tarik tegak, melengkung ke kanan, lalu kaitkan ke atas',
        rule: '先竖后弯钩 (Tegak lalu lengkung berkait)',
      ),
      MandarinStrokeInfo(
        hanziName: '横',
        pinyinName: 'Heng',
        symbol: '一',
        direction: 'Garis mendatar penutup',
        description: 'Tarik mendatar memotong tengah 子',
        rule: '最后封横 (Garis mendatar penutup)',
      ),
    ],
    '我': [
      MandarinStrokeInfo(
        hanziName: '撇',
        pinyinName: 'Pie',
        symbol: '丿',
        direction: 'Miring pendek atas',
        description: 'Tarik miring pendek ke kiri di bagian atas',
        rule: '从上到下 (Dari atas ke bawah)',
      ),
      MandarinStrokeInfo(
        hanziName: '横',
        pinyinName: 'Heng',
        symbol: '一',
        direction: 'Garis mendatar',
        description: 'Tarik mendatar pendek di sebelah kiri',
        rule: '先横后竖 (Mendatar dulu baru tegak)',
      ),
      MandarinStrokeInfo(
        hanziName: '竖钩',
        pinyinName: 'Shu Gou',
        symbol: '亅',
        direction: 'Tegak lurus berkait',
        description: 'Tarik tegak lurus lalu kaitkan ke kiri atas',
        rule: '先竖后提 (Tegak dulu baru serong)',
      ),
      MandarinStrokeInfo(
        hanziName: '提',
        pinyinName: 'Ti',
        symbol: '㇀',
        direction: 'Serong naik ke kanan',
        description: 'Tarik serong menanjak dari kiri bawah ke kanan atas',
        rule: '从左下到右上 (Dari kiri bawah ke kanan atas)',
      ),
      MandarinStrokeInfo(
        hanziName: '斜钩',
        pinyinName: 'Xie Gou',
        symbol: '㇂',
        direction: 'Miring melengkung berkait',
        description:
            'Tarik garis melengkung panjang ke kanan bawah lalu kait ke atas',
        rule: '戈字偏旁 (Bagian radikal tombak)',
      ),
      MandarinStrokeInfo(
        hanziName: '撇',
        pinyinName: 'Pie',
        symbol: '丿',
        direction: 'Miring ke kiri',
        description: 'Garis miring pendek di bagian kanan',
        rule: '从上到下 (Dari atas ke bawah)',
      ),
      MandarinStrokeInfo(
        hanziName: '点',
        pinyinName: 'Dian',
        symbol: '丶',
        direction: 'Titik di kanan atas',
        description: 'Titik penyeimbang akhir di puncak kanan',
        rule: '最后一点 (Titik penutup di akhir)',
      ),
    ],
    '爱': [
      MandarinStrokeInfo(
        hanziName: '撇',
        pinyinName: 'Pie',
        symbol: '丿',
        direction: 'Miring pendek atas',
        description: 'Tarik miring ke kiri bawah di puncak karakter',
        rule: '从上到下 (Dari atas ke bawah)',
      ),
      MandarinStrokeInfo(
        hanziName: '点',
        pinyinName: 'Dian',
        symbol: '丶',
        direction: 'Titik kiri',
        description: 'Titik pertama di sebelah kiri',
        rule: '从左到右 (Dari kiri ke kanan)',
      ),
      MandarinStrokeInfo(
        hanziName: '点',
        pinyinName: 'Dian',
        symbol: '丶',
        direction: 'Titik tengah',
        description: 'Titik kedua di bagian tengah',
        rule: '从左到右 (Dari kiri ke kanan)',
      ),
      MandarinStrokeInfo(
        hanziName: '撇',
        pinyinName: 'Pie',
        symbol: '丿',
        direction: 'Miring ke kiri',
        description: 'Miring ketiga di sebelah kanan',
        rule: '从左到右 (Dari kiri ke kanan)',
      ),
      MandarinStrokeInfo(
        hanziName: '点',
        pinyinName: 'Dian',
        symbol: '丶',
        direction: 'Titik tudung',
        description: 'Titik kiri penopang tudung mahkota (冖)',
        rule: '从上到下 (Dari atas ke bawah)',
      ),
      MandarinStrokeInfo(
        hanziName: '横钩',
        pinyinName: 'Heng Gou',
        symbol: '乛',
        direction: 'Mendatar berkait',
        description: 'Tudung mahkota (冖): mendatar lalu kait ke bawah',
        rule: '先横后钩 (Mendatar lalu berkait)',
      ),
      MandarinStrokeInfo(
        hanziName: '横',
        pinyinName: 'Heng',
        symbol: '一',
        direction: 'Mendatar tengah',
        description: 'Garis mendatar pendek di bawah tudung',
        rule: '从上到下 (Dari atas ke bawah)',
      ),
      MandarinStrokeInfo(
        hanziName: '撇',
        pinyinName: 'Pie',
        symbol: '丿',
        direction: 'Miring ke kiri',
        description: 'Tarik miring melengkung ke kiri',
        rule: '先撇后横撇 (Miring kiri dulu)',
      ),
      MandarinStrokeInfo(
        hanziName: '横撇',
        pinyinName: 'Heng Pie',
        symbol: '㇇',
        direction: 'Mendatar miring kiri',
        description: 'Tarik mendatar lalu miring ke kiri (友 bagian atas)',
        rule: '横撇连笔 (Mendatar dan miring bersambung)',
      ),
      MandarinStrokeInfo(
        hanziName: '捺',
        pinyinName: 'Na',
        symbol: '㇏',
        direction: 'Miring ke kanan bawah',
        description: 'Tarik melebar kuat ke kanan bawah sebagai penopang dasar',
        rule: '先撇后捺 (Miring kiri dulu, baru miring kanan)',
      ),
    ],
  };

  MandarinStrokeInfo _classifyStrokeFromPoints(
    List<Offset> points,
    int strokeIndex,
    int totalStrokes,
  ) {
    if (points.length < 2) {
      return const MandarinStrokeInfo(
        hanziName: '点',
        pinyinName: 'Dian',
        symbol: '丶',
        direction: 'Titik (tekanan pendek)',
        description: 'Tekan kuas perlahan lalu angkat',
        rule: '基本笔画 (Goresan dasar)',
      );
    }

    final start = points.first;
    final end = points.last;
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final dist = (end - start).distance;

    var pathLen = 0.0;
    final turns = <int>[];
    for (var i = 0; i < points.length - 1; i++) {
      final seg = points[i + 1] - points[i];
      pathLen += seg.distance;
      if (i > 0) {
        final prev = points[i] - points[i - 1];
        final pLen = prev.distance;
        final cLen = seg.distance;
        if (pLen > 15 && cLen > 15) {
          final dot = (prev.dx * seg.dx + prev.dy * seg.dy) / (pLen * cLen);
          if (dot < 0.65) {
            turns.add(i);
          }
        }
      }
    }

    if (pathLen < 200 && dist < 200) {
      if (dy < -25 && dx > 25) {
        return const MandarinStrokeInfo(
          hanziName: '提',
          pinyinName: 'Ti',
          symbol: '㇀',
          direction: 'Serong naik ke kanan atas',
          description: 'Tarik serong naik dari kiri bawah ke kanan atas',
          rule: '从左下到右上 (Kiri bawah ke kanan atas)',
        );
      }
      return const MandarinStrokeInfo(
        hanziName: '点',
        pinyinName: 'Dian',
        symbol: '丶',
        direction: 'Titik (tekanan pendek)',
        description: 'Tekan kuas pendek dan mantap di posisi ini',
        rule: '从上到下 (Tekan dari atas)',
      );
    }

    final angle = math.atan2(dy, dx) * 180 / math.pi;

    if (turns.isNotEmpty) {
      final pMid = points[turns.first];
      final firstAngle =
          math.atan2(pMid.dy - start.dy, pMid.dx - start.dx) * 180 / math.pi;
      final lastSeg = points.last - points[points.length - 2];
      final hasHookUpLeft = (lastSeg.dy < -15 && lastSeg.dx < 20);
      final hasHookUpRight = (lastSeg.dy < -15 && lastSeg.dx > 15);

      if (firstAngle >= -35 && firstAngle <= 35) {
        if (hasHookUpLeft) {
          return const MandarinStrokeInfo(
            hanziName: '横折钩',
            pinyinName: 'Heng Zhe Gou',
            symbol: '𠃌',
            direction: 'Mendatar belok bawah berkait',
            description:
                'Mendatar ke kanan, belok ke bawah, lalu kaitkan ke kiri',
            rule: '先横后折 (Mendatar lalu belok kait)',
          );
        } else if (lastSeg.dx < -25 && lastSeg.dy > 10) {
          return const MandarinStrokeInfo(
            hanziName: '横撇',
            pinyinName: 'Heng Pie',
            symbol: '㇇',
            direction: 'Mendatar miring ke kiri',
            description:
                'Mendatar ke kanan lalu bersambung miring ke kiri bawah',
            rule: '先横后撇 (Mendatar lalu miring kiri)',
          );
        } else if (lastSeg.dx < -15 && lastSeg.dy.abs() < 50) {
          return const MandarinStrokeInfo(
            hanziName: '横钩',
            pinyinName: 'Heng Gou',
            symbol: '乛',
            direction: 'Mendatar dengan kaitan',
            description: 'Mendatar ke kanan lalu kaitkan kecil ke bawah',
            rule: '先横后钩 (Mendatar lalu kait)',
          );
        } else {
          return const MandarinStrokeInfo(
            hanziName: '横折',
            pinyinName: 'Heng Zhe',
            symbol: '𠃍',
            direction: 'Mendatar lalu belok ke bawah',
            description: 'Tarik mendatar ke kanan lalu belok tegak ke bawah',
            rule: '先横后折 (Mendatar lalu belok bawah)',
          );
        }
      }

      if (firstAngle >= 55 && firstAngle <= 125) {
        if (hasHookUpLeft || (lastSeg.dx < -20 && lastSeg.dy < 20)) {
          return const MandarinStrokeInfo(
            hanziName: '竖钩',
            pinyinName: 'Shu Gou',
            symbol: '亅',
            direction: 'Tegak dengan kaitan ke kiri',
            description: 'Tarik tegak lurus ke bawah lalu kaitkan ke kiri atas',
            rule: '先竖后钩 (Tegak lurus berkait)',
          );
        } else if (hasHookUpRight || (lastSeg.dx > 20 && lastSeg.dy < 25)) {
          return const MandarinStrokeInfo(
            hanziName: '竖弯钩',
            pinyinName: 'Shu Wan Gou',
            symbol: '乚',
            direction: 'Tegak melengkung berkait',
            description:
                'Tarik tegak, belok melengkung ke kanan, lalu kait ke atas',
            rule: '先竖后弯钩 (Tegak lengkung kait)',
          );
        } else if (lastSeg.dx > 25 && lastSeg.dy.abs() < 60) {
          return const MandarinStrokeInfo(
            hanziName: '竖折',
            pinyinName: 'Shu Zhe',
            symbol: '𠃊',
            direction: 'Tegak lalu belok ke kanan',
            description: 'Tarik tegak ke bawah lalu belok horizontal ke kanan',
            rule: '先竖后折 (Tegak lalu belok)',
          );
        }
      }

      if (firstAngle >= 115 && firstAngle <= 165) {
        if (lastSeg.dx > 25 && lastSeg.dy.abs() < 60) {
          return const MandarinStrokeInfo(
            hanziName: '撇折',
            pinyinName: 'Pie Zhe',
            symbol: '𠃋',
            direction: 'Miring kiri belok kanan',
            description: 'Miring ke kiri bawah lalu belok mendatar ke kanan',
            rule: '先撇后折 (Miring lalu belok kanan)',
          );
        } else if (lastSeg.dx > 15 && lastSeg.dy > 15) {
          return const MandarinStrokeInfo(
            hanziName: '撇点',
            pinyinName: 'Pie Dian',
            symbol: '𡿨',
            direction: 'Miring kiri lalu titik',
            description:
                'Miring ke kiri bawah lalu sambung titik ke kanan bawah',
            rule: '先撇后点 (Miring lalu titik)',
          );
        }
      }
    }

    if (angle >= -30 && angle <= 30) {
      return const MandarinStrokeInfo(
        hanziName: '横',
        pinyinName: 'Heng',
        symbol: '一',
        direction: 'Garis mendatar (kiri ke kanan)',
        description: 'Tarik lurus mendatar dari kiri ke kanan dengan stabil',
        rule: '从左到右 (Dari kiri ke kanan)',
      );
    }

    if (angle >= 65 && angle <= 115) {
      final lastSeg = points.last - points[points.length - 2];
      if (lastSeg.dx < -15 && lastSeg.dy < 15) {
        return const MandarinStrokeInfo(
          hanziName: '竖钩',
          pinyinName: 'Shu Gou',
          symbol: '亅',
          direction: 'Tegak lurus berkait ke kiri',
          description: 'Tarik tegak ke bawah lalu hentakkan kait ke kiri atas',
          rule: '先竖后钩 (Tegak lurus berkait)',
        );
      }
      return const MandarinStrokeInfo(
        hanziName: '竖',
        pinyinName: 'Shu',
        symbol: '丨',
        direction: 'Garis tegak lurus (atas ke bawah)',
        description: 'Tarik tegak lurus lurus dari atas ke bawah',
        rule: '从上到下 (Dari atas ke bawah)',
      );
    }

    if (angle > 115 && angle <= 165 || (dx < -25 && dy > 35)) {
      return const MandarinStrokeInfo(
        hanziName: '撇',
        pinyinName: 'Pie',
        symbol: '丿',
        direction: 'Garis miring ke kiri bawah',
        description: 'Tarik dari atas meluncur miring ke kiri bawah',
        rule: '从右上到左下 (Dari kanan atas ke kiri bawah)',
      );
    }

    if ((angle > 25 && angle < 65) || (dx > 35 && dy > 35)) {
      final lastSeg = points.last - points[points.length - 2];
      if (lastSeg.dy < -18 && lastSeg.dx < 20) {
        return const MandarinStrokeInfo(
          hanziName: '斜钩',
          pinyinName: 'Xie Gou',
          symbol: '㇂',
          direction: 'Miring melengkung berkait',
          description:
              'Tarik miring melengkung ke kanan bawah lalu kaitkan ke atas',
          rule: '先斜后钩 (Miring berkait)',
        );
      }
      return const MandarinStrokeInfo(
        hanziName: '捺',
        pinyinName: 'Na',
        symbol: '㇏',
        direction: 'Garis miring ke kanan bawah',
        description: 'Tarik dari kiri atas melebar mantap ke kanan bawah',
        rule: '先撇后捺 (Miring kiri dulu, baru miring kanan)',
      );
    }

    if (angle >= -70 && angle <= -15 && dx > 25) {
      return const MandarinStrokeInfo(
        hanziName: '提',
        pinyinName: 'Ti',
        symbol: '㇀',
        direction: 'Garis serong naik ke kanan atas',
        description: 'Tarik serong menanjak dari kiri bawah ke kanan atas',
        rule: '从左下到右上 (Dari kiri bawah ke kanan atas)',
      );
    }

    return const MandarinStrokeInfo(
      hanziName: '点',
      pinyinName: 'Dian',
      symbol: '丶',
      direction: 'Titik (tekanan pendek)',
      description: 'Tekan kuas pendek dan angkat di posisi ini',
      rule: '基本笔画 (Goresan titik)',
    );
  }
}

/// Evaluasi multi-tahap penulisan Hanzi dengan akurasi terjamin:
/// 1. Verifikasi Jumlah Stroke (Stroke Count Validation)
/// 2. Verifikasi Urutan & Arah Stroke (Stroke Order & Direction Matching)
/// 3. Verifikasi Geometri Bentuk (Resampled Point Deviation)
HanziEvaluationResult evaluateHanziWriting({
  required List<List<Offset>> drawnStrokes,
  required HanziStrokeData reference,
  required Size canvasSize,
}) {
  final expectedCount = reference.strokes.length;
  final actualCount = drawnStrokes.length;
  final isCountValid = actualCount > 0 && (actualCount - expectedCount).abs() <= 1;

  if (drawnStrokes.isEmpty || canvasSize.isEmpty) {
    return HanziEvaluationResult(
      totalScore: 0,
      isCountValid: false,
      expectedStrokeCount: expectedCount,
      actualStrokeCount: actualCount,
      isOrderAndDirectionValid: false,
      directionScore: 0,
      shapeScore: 0,
      isPassed: false,
      feedbackTitle: 'Belum Ada Coretan',
      feedbackMessage: 'Tuliskan karakter pada kanvas terlebih dahulu.',
    );
  }

  final side = math.min(canvasSize.width, canvasSize.height);
  final left = (canvasSize.width - side) / 2;
  final top = (canvasSize.height - side) / 2;

  // Normalize user strokes into the same 1024-unit canvas used by references.
  // Keep stroke boundaries: matching only the pooled silhouette can give a
  // high score to misplaced, repeated, or incorrectly ordered strokes.
  final normalizedDrawn = <List<Offset>>[];
  for (final stroke in drawnStrokes) {
    final normStroke = <Offset>[];
    for (final point in stroke) {
      final normP = Offset(
        ((point.dx - left) / side * 1024).clamp(0, 1024).toDouble(),
        ((point.dy - top) / side * 1024).clamp(0, 1024).toDouble(),
      );
      normStroke.add(normP);
    }
    if (normStroke.isNotEmpty) {
      normalizedDrawn.add(normStroke);
    }
  }

  // Compare each user stroke only with the reference stroke at the same index.
  // Do not move or resize the writing to fit: its actual placement matters.
  final comparedCount = math.min(
    normalizedDrawn.length,
    reference.strokes.length,
  );
  var totalDirSim = 0.0;
  var validDirCount = 0;
  var totalStrokeShapeScore = 0.0;
  for (var i = 0; i < comparedCount; i++) {
    final refStroke = reference.strokes[i];
    final userStroke = normalizedDrawn[i];
    if (refStroke.length < 2 || userStroke.length < 2) {
      validDirCount++;
      continue;
    }

    const sampleCount = 32;
    final refSamples = _resample(refStroke, sampleCount);
    final userSamples = _resample(userStroke, sampleCount);
    var distanceTotal = 0.0;
    var nearCount = 0;
    for (var sample = 0; sample < sampleCount; sample++) {
      final distance = (refSamples[sample] - userSamples[sample]).distance;
      distanceTotal += distance;
      if (distance <= 80) nearCount++;
    }
    final averageDistance = distanceTotal / sampleCount;
    final pathAccuracy = (1 - averageDistance / 220).clamp(0.0, 1.0);
    final pathCoverage = nearCount / sampleCount;
    totalStrokeShapeScore += (pathAccuracy * 0.7 + pathCoverage * 0.3) * 100;

    final rVec = refStroke.last - refStroke.first;
    final uVec = userStroke.last - userStroke.first;
    final rLen = rVec.distance;
    final uLen = uVec.distance;
    if (rLen > 10 && uLen > 10) {
      final dot = rVec.dx * uVec.dx + rVec.dy * uVec.dy;
      final cosT = dot / (rLen * uLen);
      totalDirSim += ((cosT + 1) / 2).clamp(0.0, 1.0);
      validDirCount++;
    }
  }
  final matchedShapeScore = comparedCount > 0
      ? totalStrokeShapeScore / comparedCount
      : 0.0;
  final countRatio = expectedCount > 0
      ? math.min(actualCount, expectedCount) / expectedCount
      : 0.0;
  final shapeScore = (matchedShapeScore * countRatio)
      .round()
      .clamp(0, 100)
      .toInt();
  final directionScore = validDirCount > 0
      ? ((totalDirSim / validDirCount) * 100).round()
      : 0;
  final isOrderAndDirectionValid = directionScore >= 60;

  // Wrong stroke count, order, or direction cannot pass on silhouette alone.
  final totalScore = isCountValid
      ? ((shapeScore * 0.7) + (directionScore * 0.3))
            .round()
            .clamp(0, 100)
            .toInt()
      : math.min(49, (shapeScore * 0.7).round()).toInt();
  final isPassed = isCountValid && shapeScore >= 58 && directionScore >= 50;

  String title;
  String message;

  if (isPassed && totalScore >= 78) {
    title = 'Bentuk Sangat Tepat! 很好';
    message = 'Bentuk tulisan Hanzi kamu sudah sangat rapi dan benar sesuai tulisan Hanzi di atas.';
  } else if (isPassed) {
    title = 'Tulisan Hanzi Sudah Benar! 加油';
    message = 'Tulisanmu sudah sesuai dengan karakter Hanzi di atas. Pertahankan dan latih keluwesannya!';
  } else if (!isCountValid) {
    title = 'Jumlah Goresan Belum Tepat';
    message =
        'Karakter ini membutuhkan $expectedCount goresan (kamu menulis $actualCount). Ikuti panduan goresan karakter di atas, lalu coba lagi.';
  } else if (!isOrderAndDirectionValid) {
    title = 'Arah atau Urutan Goresan Belum Tepat';
    message = 'Ikuti titik awal dan arah pada panduan, lalu tulis ulang karakter dari goresan pertama.';
  } else {
    title = 'Bentuk Belum Sesuai Hanzi di Atas';
    message = 'Tulisan kamu belum sesuai dengan karakter Hanzi yang ada di atas. Ikuti goresan karakter pada kanvas secara utuh.';
  }

  return HanziEvaluationResult(
    totalScore: totalScore,
    isCountValid: isCountValid,
    expectedStrokeCount: expectedCount,
    actualStrokeCount: actualCount,
    isOrderAndDirectionValid: isOrderAndDirectionValid,
    directionScore: directionScore,
    shapeScore: shapeScore,
    isPassed: isPassed,
    feedbackTitle: title,
    feedbackMessage: message,
  );
}

int compareHanziStrokes({
  required List<List<Offset>> drawnStrokes,
  required HanziStrokeData reference,
  required Size canvasSize,
}) {
  final result = evaluateHanziWriting(
    drawnStrokes: drawnStrokes,
    reference: reference,
    canvasSize: canvasSize,
  );
  return result.totalScore;
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
