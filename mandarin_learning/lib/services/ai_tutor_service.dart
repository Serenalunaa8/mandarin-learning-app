import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

enum AiTutorMode {
  appApi(
    'app_api',
    'AI Tutor + Database',
    'Tutor Mandarin yang menjawab dengan bantuan materi kosakata Supabase.',
  ),
  gemini(
    'gemini',
    'Gemini Murni',
    'Gemini untuk pertanyaan umum, tanpa mengambil konteks dari database.',
  );

  const AiTutorMode(this.id, this.label, this.description);

  final String id;
  final String label;
  final String description;
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

    final safeHistory = history
        .where(
          (turn) =>
              (turn['role'] == 'user' || turn['role'] == 'model') &&
              (turn['text']?.trim().isNotEmpty ?? false),
        )
        .toList()
        .reversed
        .take(4)
        .toList()
        .reversed
        .map(
          (turn) => {
            'role': turn['role']!,
            'text': turn['text']!.trim().substring(
              0,
              turn['text']!.trim().length > 500
                  ? 500
                  : turn['text']!.trim().length,
            ),
          },
        )
        .toList();
    final body = <String, dynamic>{
      'mode': mode.id,
      'prompt': trimmedPrompt,
      'history': safeHistory,
    };

    try {
      final response = await SupabaseService.instance.client.functions
          .invoke('ai-tutor', body: body)
          .timeout(const Duration(seconds: 35));
      final data = response.data;
      if (data is Map) {
        final answer = data['answer'];
        if (answer is String && answer.trim().isNotEmpty) {
          return _cleanAnswer(answer);
        }
        final error = data['error'];
        if (error is String && error.isNotEmpty) {
          throw StateError(error);
        }
      }
      throw StateError('Layanan AI tidak mengembalikan jawaban.');
    } catch (error) {
      debugPrint('[AiTutorService] Request gagal (${mode.id}): $error');
      if (error is StateError) rethrow;
      if (error is FunctionException) {
        final details = error.details;
        if (details is Map && details['error'] is String) {
          throw StateError(details['error'] as String);
        }
        if (details is String && details.trim().isNotEmpty) {
          throw StateError(details);
        }
      }
      throw StateError(
        'AI belum bisa dihubungi. Periksa koneksi lalu coba lagi.',
      );
    }
  }

  String _cleanAnswer(String answer) {
    return answer
        .replaceAll(RegExp(r'\*\*(.*?)\*\*', dotAll: true), r'$1')
        .replaceAll(RegExp(r'(?<!\*)\*([^*\n]+)\*(?!\*)'), r'$1')
        .replaceAll('`', '')
        .replaceAll(RegExp(r'^\s{0,3}#{1,6}\s*', multiLine: true), '')
        .replaceAll(RegExp(r'^\s*[-+]\s+', multiLine: true), '• ')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }
}
