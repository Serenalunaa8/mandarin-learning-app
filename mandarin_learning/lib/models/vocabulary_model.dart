class ExampleSentence {
  final String hanzi;
  final String? pinyin;
  final String arti;

  ExampleSentence({
    required this.hanzi,
    this.pinyin,
    required this.arti,
  });

  factory ExampleSentence.fromJson(Map<String, dynamic> json) {
    return ExampleSentence(
      hanzi: (json['hanzi'] ?? json['zh'] ?? '').toString(),
      pinyin: json['pinyin']?.toString(),
      arti: (json['arti'] ?? json['id'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'hanzi': hanzi,
    if (pinyin != null) 'pinyin': pinyin,
    'arti': arti,
  };
}

class VocabularyItem {
  final int id;
  final String hanzi;
  final String pinyin;
  final String artiIndonesia;
  final List<String> translations;
  final int hskLevel;
  final String? jenisKata;
  final List<ExampleSentence> contohKalimat;
  final String sumber;

  VocabularyItem({
    required this.id,
    required this.hanzi,
    required this.pinyin,
    required this.artiIndonesia,
    required this.translations,
    required this.hskLevel,
    this.jenisKata,
    required this.contohKalimat,
    required this.sumber,
  });

  factory VocabularyItem.fromJson(Map<String, dynamic> json) {
    var rawTranslations = json['translations'];
    List<String> transList = [];
    if (rawTranslations is List) {
      transList = rawTranslations.map((e) => e.toString()).toList();
    }

    var rawExamples = json['contoh_kalimat'] ?? json['examples'];
    List<ExampleSentence> examplesList = [];
    if (rawExamples is List) {
      for (var ex in rawExamples) {
        if (ex is Map<String, dynamic>) {
          examplesList.add(ExampleSentence.fromJson(ex));
        } else if (ex is Map) {
          examplesList.add(ExampleSentence.fromJson(Map<String, dynamic>.from(ex)));
        }
      }
    }

    return VocabularyItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      hanzi: (json['hanzi'] ?? '').toString(),
      pinyin: (json['pinyin'] ?? '').toString(),
      artiIndonesia: (json['arti_indonesia'] ?? json['arti'] ?? (transList.isNotEmpty ? transList.join('; ') : '')).toString(),
      translations: transList,
      hskLevel: (json['hsk_level'] as num?)?.toInt() ?? 1,
      jenisKata: json['jenis_kata']?.toString(),
      contohKalimat: examplesList,
      sumber: (json['sumber'] ?? 'HSK 2.0 Official Vocabulary').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'hanzi': hanzi,
    'pinyin': pinyin,
    'arti_indonesia': artiIndonesia,
    'translations': translations,
    'hsk_level': hskLevel,
    'jenis_kata': jenisKata,
    'contoh_kalimat': contohKalimat.map((e) => e.toJson()).toList(),
    'sumber': sumber,
  };

  VocabularyItem copyWith({
    int? id,
    String? hanzi,
    String? pinyin,
    String? artiIndonesia,
    List<String>? translations,
    int? hskLevel,
    String? jenisKata,
    List<ExampleSentence>? contohKalimat,
    String? sumber,
  }) {
    return VocabularyItem(
      id: id ?? this.id,
      hanzi: hanzi ?? this.hanzi,
      pinyin: pinyin ?? this.pinyin,
      artiIndonesia: artiIndonesia ?? this.artiIndonesia,
      translations: translations ?? this.translations,
      hskLevel: hskLevel ?? this.hskLevel,
      jenisKata: jenisKata ?? this.jenisKata,
      contohKalimat: contohKalimat ?? this.contohKalimat,
      sumber: sumber ?? this.sumber,
    );
  }
}
