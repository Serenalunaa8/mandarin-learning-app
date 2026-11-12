import 'package:flutter/foundation.dart';

import 'supabase_service.dart';

enum AiTutorMode {
  appApi(
    'app_api',
    'LingLing (玲玲)',
    'Tutor khusus Nihaoki untuk panduan aplikasi dan isi database pembelajaran.',
    'lingling-ai',
  ),
  gemini(
    'gemini',
    'Gemini',
    'Asisten umum untuk pertanyaan di luar aplikasi Nihaoki.',
    'gemini-ai',
  );

  const AiTutorMode(this.id, this.label, this.description, this.endpoint);

  final String id;
  final String label;
  final String description;
  final String endpoint;
}

class AiChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final String? audioText;
  final AiTutorMode? mode;
  final String? modelBadge;
  final String? databaseSummary;

  AiChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.audioText,
    this.mode,
    this.modelBadge,
    this.databaseSummary,
  });
}

class AiTutorService {
  static final AiTutorService instance = AiTutorService._internal();

  AiTutorService._internal();

  Future<String> askAiTutor(
    String prompt, {
    AiTutorMode mode = AiTutorMode.appApi,
    List<Map<String, String>> history = const [],
  }) async {
    final trimmedPrompt = prompt.trim();
    if (trimmedPrompt.isEmpty) {
      throw ArgumentError.value(
        prompt,
        'prompt',
        'Pertanyaan tidak boleh kosong.',
      );
    }

    if (trimmedPrompt.length > 4000) {
      throw ArgumentError.value(
        prompt,
        'prompt',
        'Pertanyaan maksimal 4.000 karakter.',
      );
    }

    final safeHistory = buildAiHistory(history);

    try {
      final response = await SupabaseService.instance.client.functions
          .invoke(
            mode.endpoint,
            body: {'prompt': trimmedPrompt, 'history': safeHistory},
          )
          .timeout(const Duration(seconds: 35));
      final data = response.data;
      if (data is Map) {
        final answer = data['answer'];
        if (answer is String && answer.trim().isNotEmpty) {
          return cleanAiAnswer(answer);
        }
        final error = data['error'];
        if (error is String && error.isNotEmpty) {
          throw StateError(error);
        }
      }
      throw StateError('Layanan AI tidak mengembalikan jawaban.');
    } catch (error) {
      debugPrint('[AiTutorService] Request backend gagal (${mode.id}): $error');
      if (error is StateError) rethrow;
      throw StateError(
        'AI belum bisa dihubungi. Periksa koneksi lalu coba lagi.',
      );
    }
  }
}

List<Map<String, String>> buildAiHistory(
  List<Map<String, String>> history,
) {
  final completeTurns = <List<Map<String, String>>>[];
  String? unansweredQuestion;

  for (final turn in history) {
    final role = turn['role'];
    final text = turn['text']?.trim();
    if (text == null || text.isEmpty) continue;

    if (role == 'user') {
      unansweredQuestion = text;
    } else if (role == 'model' && unansweredQuestion != null) {
      completeTurns.add([
        {'role': 'user', 'text': _limitHistoryText(unansweredQuestion)},
        {'role': 'model', 'text': _limitHistoryText(text)},
      ]);
      unansweredQuestion = null;
    }
  }

  return completeTurns
      .skip(completeTurns.length > 4 ? completeTurns.length - 4 : 0)
      .expand((turns) => turns)
      .toList();
}

String _limitHistoryText(String text) =>
    text.length > 500 ? text.substring(0, 500) : text;

String cleanAiAnswer(String answer) {
  var cleaned = answer;
  cleaned = cleaned.replaceAllMapped(
    RegExp(r'\$\$(.*?)\$\$', dotAll: true),
    (match) => match.group(1) ?? '',
  );
  cleaned = cleaned.replaceAllMapped(
    RegExp(r'(?<!\$)\$([^\n$]+?)\$(?!\$)'),
    (match) => match.group(1) ?? '',
  );
  cleaned = cleaned.replaceAllMapped(
    RegExp(r'\\\((.*?)\\\)|\\\[(.*?)\\\]', dotAll: true),
    (match) => match.group(1) ?? match.group(2) ?? '',
  );
  cleaned = cleaned.replaceAllMapped(
    RegExp(r'\*\*(.*?)\*\*', dotAll: true),
    (match) => match.group(1) ?? '',
  );
  cleaned = cleaned.replaceAllMapped(
    RegExp(r'__(.*?)__', dotAll: true),
    (match) => match.group(1) ?? '',
  );
  cleaned = cleaned.replaceAllMapped(
    RegExp(r'(?<![\*\s])\*([^\*\n]+)\*(?![\*\s])'),
    (match) => match.group(1) ?? '',
  );
  cleaned = cleaned.replaceAll(
    RegExp(r'^\s*[\*\-\+]\s+', multiLine: true),
    '• ',
  );
  cleaned = cleaned.replaceAll(
    RegExp(r'^\s{0,3}#{1,6}\s*', multiLine: true),
    '',
  );
  cleaned = cleaned.replaceAll('`', '');
  cleaned = cleaned.replaceAll(RegExp(r'\n{3,}'), '\n\n');
  return cleaned.trim();
}
