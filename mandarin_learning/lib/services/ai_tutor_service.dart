import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'supabase_service.dart';

enum AiProvider {
  gemini('gemini', 'Google Gemini', 'gemini-2.5-flash'),
  anthropic('anthropic', 'Anthropic Claude', 'claude-haiku-5-5'),
  openAi('openai', 'OpenAI GPT', 'gpt-6-luna'),
  groq('groq', 'Groq Llama', 'llama-3.3-70b-versatile');

  const AiProvider(this.id, this.label, this.model);

  final String id;
  final String label;
  final String model;
}

class AiChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final String? audioText; // Jika ada kalimat mandarin yang bisa dibaca oleh TTS

  AiChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.audioText,
  });
}

class AiTutorService {
  static final AiTutorService instance = AiTutorService._internal();
  AiTutorService._internal();

  static const String _geminiApiKeyPref = 'ai_api_key_gemini';
  static const String _claudeApiKeyPref = 'ai_api_key_anthropic';
  static const String _openAiApiKeyPref = 'ai_api_key_openai';
  static const String _groqApiKeyPref = 'ai_api_key_groq';

  // System instruction untuk AI Tutor
  static const String _systemPrompt = '''
Kamu adalah Xiao Xiong (小熊), AI Tutor bahasa Mandarin yang ramah, interaktif, dan mendidik khusus untuk penutur bahasa Indonesia (pemula hingga menengah HSK 1-6).
Aturan jawaban:
1. Selalu berikan penjelasan dalam Bahasa Indonesia yang jelas, hangat, dan mudah dipahami.
2. Setiap kali menyebutkan kosakata atau kalimat Mandarin, selalu sertakan: Hanzi (karakter), Pinyin (dengan tanda nada yang benar), dan Arti dalam Bahasa Indonesia.
   Contoh format: 咖啡馆 (kāfēiguǎn) = kafe.
3. Berikan contoh kalimat praktis yang relevan dengan kehidupan sehari-hari jika menjelaskan tata bahasa.
4. Gunakan gaya bahasa tutor yang menyemangati, sertakan emoji yang sesuai.
''';

  /// Mendapatkan daftar provider yang didukung.
  /// Semua provider (Gemini, Claude, OpenAI, Groq) selalu tersedia untuk dipilih.
  Future<List<AiProvider>> getAvailableProviders() async {
    return AiProvider.values;
  }

  /// Simpan API key kustom ke SharedPreferences
  Future<void> saveApiKey(AiProvider provider, String key) async {
    final prefs = await SharedPreferences.getInstance();
    final prefKey = _getPrefKeyForProvider(provider);
    if (key.trim().isEmpty) {
      await prefs.remove(prefKey);
    } else {
      await prefs.setString(prefKey, key.trim());
    }
  }

  /// Ambil API key yang tersimpan untuk provider
  Future<String?> getApiKey(AiProvider provider) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_getPrefKeyForProvider(provider));
  }

  String _getPrefKeyForProvider(AiProvider provider) {
    switch (provider) {
      case AiProvider.gemini:
        return _geminiApiKeyPref;
      case AiProvider.anthropic:
        return _claudeApiKeyPref;
      case AiProvider.openAi:
        return _openAiApiKeyPref;
      case AiProvider.groq:
        return _groqApiKeyPref;
    }
  }

  /// Tanya AI Tutor dengan urutan prioritas:
  /// 1. Direct API call jika user telah mengatur API key
  /// 2. Supabase Edge Function jika tersedia
  /// 3. Offline intelligent Mandarin Tutor knowledge base jika koneksi gagal
  Future<String> askAiTutor(
    String prompt, {
    required AiProvider provider,
  }) async {
    final trimmedPrompt = prompt.trim();
    if (trimmedPrompt.isEmpty) return 'Silakan masukkan pertanyaanmu tentang bahasa Mandarin.';

    final customKey = await getApiKey(provider);

    // 1. Coba Direct API jika ada key
    if (customKey != null && customKey.isNotEmpty) {
      try {
        return await _callDirectApi(provider, customKey, trimmedPrompt);
      } catch (e) {
        debugPrint('[AiTutorService] Direct API call gagal ($provider): $e');
        // fallback ke edge function atau offline knowledge base
      }
    }

    // 2. Coba Supabase Edge Function
    try {
      final response = await SupabaseService.instance.client.functions
          .invoke(
            'ai-tutor',
            body: {'provider': provider.id, 'prompt': trimmedPrompt},
          )
          .timeout(const Duration(seconds: 15));
      final data = response.data;
      if (data is Map<String, dynamic>) {
        final answer = data['answer']?.toString().trim();
        if (answer != null && answer.isNotEmpty) return answer;
      }
    } catch (edgeError) {
      debugPrint('[AiTutorService] Supabase Edge Function tidak tersedia: $edgeError');
    }

    // 3. Fallback cerdas: Offline Mandarin Tutor Knowledge Base
    return _getSmartOfflineResponse(trimmedPrompt);
  }

  /// Panggilan langsung ke REST API provider resmi
  Future<String> _callDirectApi(
    AiProvider provider,
    String apiKey,
    String prompt,
  ) async {
    switch (provider) {
      case AiProvider.gemini:
        return _callGeminiApi(apiKey, prompt);
      case AiProvider.anthropic:
        return _callClaudeApi(apiKey, prompt);
      case AiProvider.openAi:
        return _callOpenAiApi(apiKey, prompt);
      case AiProvider.groq:
        return _callGroqApi(apiKey, prompt);
    }
  }

  /// Google Gemini API (v1beta generateContent)
  Future<String> _callGeminiApi(String apiKey, String prompt) async {
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$apiKey',
    );

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': '$_systemPrompt\n\nPertanyaan pengguna: $prompt'}
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.7,
          'maxOutputTokens': 1024,
        }
      }),
    ).timeout(const Duration(seconds: 25));

    if (response.statusCode != 200) {
      final err = jsonDecode(response.body);
      final msg = err['error']?['message'] ?? 'Error ${response.statusCode}';
      throw Exception('Gemini API Error: $msg');
    }

    final data = jsonDecode(response.body);
    final candidates = data['candidates'] as List?;
    if (candidates != null && candidates.isNotEmpty) {
      final parts = candidates.first['content']?['parts'] as List?;
      if (parts != null && parts.isNotEmpty) {
        return parts.first['text'].toString().trim();
      }
    }
    throw Exception('Gemini tidak mengembalikan teks jawaban.');
  }

  /// Anthropic Claude API (v1/messages)
  Future<String> _callClaudeApi(String apiKey, String prompt) async {
    final url = Uri.parse('https://api.anthropic.com/v1/messages');

    final response = await http.post(
      url,
      headers: {
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
        'content-type': 'application/json',
      },
      body: jsonEncode({
        'model': 'claude-3-5-haiku-20241022',
        'max_tokens': 1024,
        'system': _systemPrompt,
        'messages': [
          {'role': 'user', 'content': prompt}
        ],
      }),
    ).timeout(const Duration(seconds: 25));

    if (response.statusCode != 200) {
      final err = jsonDecode(response.body);
      final msg = err['error']?['message'] ?? 'Error ${response.statusCode}';
      throw Exception('Claude API Error: $msg');
    }

    final data = jsonDecode(response.body);
    final content = data['content'] as List?;
    if (content != null && content.isNotEmpty) {
      return content.first['text'].toString().trim();
    }
    throw Exception('Claude tidak mengembalikan teks jawaban.');
  }

  /// OpenAI API (v1/chat/completions)
  Future<String> _callOpenAiApi(String apiKey, String prompt) async {
    final url = Uri.parse('https://api.openai.com/v1/chat/completions');

    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': 'gpt-4o-mini',
        'messages': [
          {'role': 'system', 'content': _systemPrompt},
          {'role': 'user', 'content': prompt}
        ],
        'temperature': 0.7,
      }),
    ).timeout(const Duration(seconds: 25));

    if (response.statusCode != 200) {
      final err = jsonDecode(response.body);
      final msg = err['error']?['message'] ?? 'Error ${response.statusCode}';
      throw Exception('OpenAI API Error: $msg');
    }

    final data = jsonDecode(response.body);
    final choices = data['choices'] as List?;
    if (choices != null && choices.isNotEmpty) {
      return choices.first['message']['content'].toString().trim();
    }
    throw Exception('OpenAI tidak mengembalikan teks jawaban.');
  }

  /// Groq API (v1/chat/completions)
  Future<String> _callGroqApi(String apiKey, String prompt) async {
    final url = Uri.parse('https://api.groq.com/openai/v1/chat/completions');

    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': 'llama-3.3-70b-versatile',
        'messages': [
          {'role': 'system', 'content': _systemPrompt},
          {'role': 'user', 'content': prompt}
        ],
        'temperature': 0.7,
      }),
    ).timeout(const Duration(seconds: 25));

    if (response.statusCode != 200) {
      final err = jsonDecode(response.body);
      final msg = err['error']?['message'] ?? 'Error ${response.statusCode}';
      throw Exception('Groq API Error: $msg');
    }

    final data = jsonDecode(response.body);
    final choices = data['choices'] as List?;
    if (choices != null && choices.isNotEmpty) {
      return choices.first['message']['content'].toString().trim();
    }
    throw Exception('Groq tidak mengembalikan teks jawaban.');
  }

  /// Offline smart Mandarin tutor knowledge base
  String _getSmartOfflineResponse(String prompt) {
    final lower = prompt.toLowerCase();

    if (lower.contains('de') || lower.contains('的') || lower.contains('得') || lower.contains('地')) {
      return '''
Halo! Ini perbedaan 3 macam "de" dalam bahasa Mandarin yang sangat penting:

1. **的 (de)** - Kepemilikan & Modifikasi Kata Benda:
   • Menghubungkan kata sifat atau pemilik dengan kata benda.
   • Rumus: Pemilik/Sifat + 的 + Kata Benda
   • Contoh: 我的书 (wǒ de shū) = Buku saya.
   • Contoh: 漂亮的衣服 (piàoliang de yīfu) = Pakaian yang cantik.

2. **得 (de)** - Derajat atau Hasil Tindakan:
   • Dipakai setelah kata kerja untuk menilai seberapa baik tindakan dilakukan.
   • Rumus: Kata Kerja + 得 + Penilaian/Derajat
   • Contoh: 他跑得很快 (tā pǎo de hěn kuài) = Dia berlari dengan sangat cepat.
   • Contoh: 你中文说得很好 (nǐ zhōngwén shuō de hěn hǎo) = Bahasa Mandarinmu sangat lancar.

3. **地 (de)** - Keterangan Cara (Adverbia):
   • Dipakai sebelum kata kerja untuk menjelaskan cara melakukan sesuatu.
   • Rumus: Kata Sifat + 地 + Kata Kerja
   • Contoh: 他慢慢地走 (tā mànmàn de zǒu) = Dia berjalan dengan perlahan.
   • Contoh: 高兴地笑 (gāoxìng de xiào) = Tersenyum dengan gembira.

Semoga membantu! Semangat belajarnya ya! 🐼✨
''';
    }

    if (lower.contains('nada') || lower.contains('tone') || lower.contains('2 dan 3') || lower.contains('2') && lower.contains('3')) {
      return '''
Halo! Cara membedakan Nada 2 dan Nada 3 dalam bahasa Mandarin:

1. **Nada 2 (阳平 - Yángpíng - Nada Naik ˊ)**:
   • Nada bergerak naik dari nada sedang ke tinggi (skala 35).
   • Mirip intonasi bertanya kaget dalam bahasa Indonesia: "Hah?!", "Masa?".
   • Contoh: 
     - 阳 (yáng) = matahari
     - 白 (bái) = putih
     - 没 (méi) = tidak ada

2. **Nada 3 (上声 - Shǎngshēng - Nada Turun-Naik ˇ)**:
   • Nada turun dari rendah ke sangat rendah lalu sedikit naik (skala 214).
   • Mirip intonasi saat bergumam heran: "O... oh begitu".
   • Contoh:
     - 好 (hǎo) = baik
     - 你 (nǐ) = kamu
     - 水 (shuǐ) = air

💡 **Tips Rahasia Aturan Perubahan Nada (Tone Sandhi)**:
Jika dua Nada 3 bertemu berturut-turut, nada pertama otomatis dibaca sebagai Nada 2!
Misalnya: 你 (nǐ - nada 3) + 好 (hǎo - nada 3) dibaca menjadi ní hǎo! 🐼
''';
    }

    if (lower.contains('bu') || lower.contains('mei') || lower.contains('不') || lower.contains('没')) {
      return '''
Perbedaan penggunaan **不 (bù)** vs **没 (méi)**:

1. **不 (bù)** - Menolak kehendak, kebiasaan, masa sekarang & masa depan:
   • Dipakai untuk kata sifat, kehendak diri sendiri, atau kebiasaan umum.
   • Contoh: 我不去 (wǒ bù qù) = Saya tidak mau pergi.
   • Contoh: 他不是学生 (tā bù shì xuésheng) = Dia bukan siswa.
   • Contoh: 今天不冷 (jīntiān bù lěng) = Hari ini tidak dingin.

2. **没 (méi / méiyǒu)** - Fakta lampau atau ketidakhadiran:
   • Dipakai untuk menyatakan sesuatu belum/tidak terjadi, atau tidak punya.
   • Contoh: 我没去 (wǒ méi qù) = Saya tadi tidak pergi.
   • Contoh: 我没有钱 (wǒ méiyǒu qián) = Saya tidak punya uang.
   • Catatan: Kata 有 (yǒu) HANYA bisa disangkal dengan 没 (tidak pernah 不有)! 🐼
''';
    }

    if (lower.contains('makan') || lower.contains('pesan') || lower.contains('restoran') || lower.contains('kafe')) {
      return '''
Ini kalimat percakapan praktis saat memesan makanan di restoran/kafe Mandarin:

1. 服务员，请给我菜单 (Fúwùyuán, qǐng gěi wǒ càidān)
   = Pelayan, tolong beri saya buku menu.
2. 我想要一杯咖啡 (Wǒ xiǎng yào yībēi kāfēiguǎn)
   = Saya ingin segelas kopi.
3. 这个菜辣吗？(Zhège cài là ma?)
   = Apakah masakan ini pedas?
4. 请不要放味精 (Qǐng bù yào fàng wèijīng)
   = Tolong jangan pakai micin/MSG.
5. 买单！(Mǎidān!)
   = Minta bon / bayar!

Selamat mempraktikkannya ya! 🍽️🐼
''';
    }

    if (lower.contains('hafal') || lower.contains('tips') || lower.contains('hanzi')) {
      return '''
Ini 4 tips jitu menghafal Hanzi dari Xiao Xiong 🐼:

1. **Pahami Radikal (部首 - Bùshǒu)**:
   • Radikal adalah kunci arti! Contoh: 氵 (air) ada di 酒 (arak), 河 (sungai), 海 (laut).
2. **Cerita Visual**:
   • Hubungkan bentuk karakter dengan gambaran imajinasimu. Contoh: 休 (xiū - istirahat) = ada orang 人 bersandar di pohon 木.
3. **Tulis dengan Urutan Stroke yang Tepat**:
   • Gunakan fitur Hanzi Stroke Challenge di aplikasi ini untuk melatih memori otot jarimu!
4. **Spaced Repetition (SRS)**:
   • Ulangi kosakata di kartu kuis setiap 1, 3, dan 7 hari agar pindah ke memori jangka panjang.
''';
    }

    // Jawaban umum jika pertanyaan bebas
    return '''
Halo! Aku Xiao Xiong, tutor Mandarinmu 🐼.

Tentang pertanyaanmu: "$prompt"

Dalam bahasa Mandarin, mempelajari kosakata dan tata bahasa sangat menyenangkan! 
Beberapa kosakata dasar yang relevan:
• 学习 (xuéxí) = belajar
• 练习 (liànxí) = latihan
• 加油 (jiāyóu) = semangat!

Kamu juga bisa mengatur API Key Gemini, Claude, atau OpenAI di tombol Pengaturan (⚙️) di pojok kanan atas agar aku bisa menjawab lebih mendalam dengan model AI pilihanmu! 🐼✨
''';
  }
}

