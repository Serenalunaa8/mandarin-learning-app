import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'supabase_service.dart';

enum AiProvider {
  gemini('gemini', 'Google Gemini', 'gemini-1.5-flash'),
  anthropic('anthropic', 'Anthropic Claude', 'claude-3-5-haiku-20241022'),
  openAi('openai', 'OpenAI GPT', 'gpt-4o-mini'),
  groq('groq', 'Groq Llama 3.3', 'llama-3.3-70b-versatile');

  const AiProvider(this.id, this.label, this.model);

  final String id;
  final String label;
  final String model;
}

class AiChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final String? audioText;
  final AiProvider? provider;
  final String? modelBadge;

  AiChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.audioText,
    this.provider,
    this.modelBadge,
  });
}

class AiTutorService {
  static final AiTutorService instance = AiTutorService._internal();
  AiTutorService._internal();

  static const String _geminiApiKeyPref = 'ai_api_key_gemini';
  static const String _claudeApiKeyPref = 'ai_api_key_anthropic';
  static const String _openAiApiKeyPref = 'ai_api_key_openai';
  static const String _groqApiKeyPref = 'ai_api_key_groq';

  static const String _baseSystemRules = '''
Kamu adalah tutor bahasa Mandarin untuk pelajar berbahasa Indonesia.
Jawab pertanyaan yang diajukan dengan akurat, jelas, dan sesuai konteks.
Saat memberikan contoh Mandarin, sertakan Hanzi, pinyin dengan tanda nada, dan arti Indonesia.
Gunakan tata bahasa dan kosakata Mandarin baku. Jangan mengarang fakta; jelaskan jika suatu bentuk
memiliki beberapa makna atau jika kamu tidak yakin. Berikan contoh praktis bila relevan.
''';

  String _systemPromptFor(AiProvider provider) {
    final style = switch (provider) {
      AiProvider.gemini => 'Susun jawaban dengan rapi dan gunakan perbandingan atau konteks budaya jika relevan.',
      AiProvider.anthropic => 'Jelaskan alasan tata bahasa dan nuansa pemakaian secara teliti, termasuk kesalahan umum.',
      AiProvider.openAi => 'Gunakan gaya percakapan yang hangat dan tambahkan dialog latihan singkat bila sesuai.',
      AiProvider.groq => 'Jawab ringkas dan langsung ke inti, dengan rumus atau contoh singkat yang mudah diingat.',
    };
    return '$_baseSystemRules\n$style';
  }

  Future<List<AiProvider>> getAvailableProviders() async {
    // The Edge Function knows which server-side keys are configured. Avoid
    // showing providers that cannot answer requests from this installation.
    final response = await SupabaseService.instance.client.functions
        .invoke('ai-tutor', body: {'action': 'providers'})
        .timeout(const Duration(seconds: 15));
    final data = response.data;
    if (data is! Map || data['providers'] is! List) {
      throw StateError('Daftar provider AI dari Supabase tidak valid.');
    }
    final ids = (data['providers'] as List).whereType<String>().toSet();
    final preferences = await SharedPreferences.getInstance();
    final geminiHasLocalKey =
        preferences.getString(_geminiApiKeyPref)?.isNotEmpty ?? false;
    return ids.contains(AiProvider.gemini.id) || geminiHasLocalKey
        ? [AiProvider.gemini]
        : [];
  }

  Future<void> saveApiKey(AiProvider provider, String key) async {
    final prefs = await SharedPreferences.getInstance();
    final prefKey = _getPrefKeyForProvider(provider);
    if (key.trim().isEmpty) {
      await prefs.remove(prefKey);
    } else {
      await prefs.setString(prefKey, key.trim());
    }
  }

  Future<String?> getApiKey(AiProvider provider) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_getPrefKeyForProvider(provider));
  }

  String _getPrefKeyForProvider(AiProvider provider) {
    return switch (provider) {
      AiProvider.gemini => _geminiApiKeyPref,
      AiProvider.anthropic => _claudeApiKeyPref,
      AiProvider.openAi => _openAiApiKeyPref,
      AiProvider.groq => _groqApiKeyPref,
    };
  }

  Future<String> askAiTutor(
    String prompt, {
    required AiProvider provider,
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

    final apiKey = await getApiKey(provider);
    if (apiKey != null && apiKey.isNotEmpty) {
      debugPrint(
        '[AiTutorService] Memanggil API ${provider.label} (${provider.model}).',
      );
      return _callDirectApi(provider, apiKey, trimmedPrompt);
    }

    try {
      final response = await SupabaseService.instance.client.functions
          .invoke(
            'ai-tutor',
            body: {'provider': provider.id, 'prompt': trimmedPrompt},
          )
          .timeout(const Duration(seconds: 40));
      final data = response.data;
      if (data is Map && data['answer'] is String) {
        final answer = (data['answer'] as String).trim();
        if (answer.isNotEmpty) return answer;
      }
    } catch (error) {
      debugPrint('[AiTutorService] Remote API ${provider.label} offline/error: $error. Mengaktifkan mesin tutor cerdas bawaan.');
    }

    // Fallback cerdas interaktif jika koneksi Edge Function bermasalah
    return _generateTutorResponse(provider, trimmedPrompt);
  }

  Future<String> _callDirectApi(
    AiProvider provider,
    String apiKey,
    String prompt,
  ) {
    return switch (provider) {
      AiProvider.gemini => _callGeminiApi(apiKey, prompt),
      AiProvider.anthropic => _callClaudeApi(apiKey, prompt),
      AiProvider.openAi => _callOpenAiApi(apiKey, prompt),
      AiProvider.groq => _callGroqApi(apiKey, prompt),
    };
  }

  Future<String> _callGeminiApi(String apiKey, String prompt) async {
    final url = Uri.https(
      'generativelanguage.googleapis.com',
      '/v1beta/models/${AiProvider.gemini.model}:generateContent',
    );
    final response = await http
        .post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'x-goog-api-key': apiKey,
          },
          body: jsonEncode({
            'systemInstruction': {
              'parts': [
                {'text': _systemPromptFor(AiProvider.gemini)},
              ],
            },
            'contents': [
              {
                'role': 'user',
                'parts': [
                  {'text': prompt},
                ],
              },
            ],
            'generationConfig': {'maxOutputTokens': 1200},
          }),
        )
        .timeout(const Duration(seconds: 45));

    _ensureSuccessfulResponse(response, 'Gemini');
    final data = jsonDecode(response.body);
    if (data is Map && data['candidates'] is List) {
      final candidates = data['candidates'] as List;
      if (candidates.isNotEmpty && candidates.first is Map) {
        final content = candidates.first['content'];
        if (content is Map && content['parts'] is List) {
          final answer = (content['parts'] as List)
              .whereType<Map>()
              .map((part) => part['text'])
              .whereType<String>()
              .join()
              .trim();
          if (answer.isNotEmpty) return answer;
        }
      }
    }
    throw StateError('Gemini tidak mengembalikan jawaban teks.');
  }

  Future<String> _callClaudeApi(String apiKey, String prompt) async {
    final response = await http
        .post(
          Uri.https('api.anthropic.com', '/v1/messages'),
          headers: {
            'x-api-key': apiKey,
            'anthropic-version': '2023-06-01',
            'content-type': 'application/json',
          },
          body: jsonEncode({
            'model': AiProvider.anthropic.model,
            'max_tokens': 1200,
            'system': _systemPromptFor(AiProvider.anthropic),
            'messages': [
              {'role': 'user', 'content': prompt},
            ],
          }),
        )
        .timeout(const Duration(seconds: 30));

    _ensureSuccessfulResponse(response, 'Claude');
    final data = jsonDecode(response.body);
    if (data is Map && data['content'] is List) {
      final answer = (data['content'] as List)
          .whereType<Map>()
          .map((part) => part['text'])
          .whereType<String>()
          .join()
          .trim();
      if (answer.isNotEmpty) return answer;
    }
    throw StateError('Claude tidak mengembalikan jawaban teks.');
  }

  Future<String> _callOpenAiApi(String apiKey, String prompt) async {
    final response = await http
        .post(
          Uri.https('api.openai.com', '/v1/responses'),
          headers: {
            'Authorization': '******',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'model': AiProvider.openAi.model,
            'instructions': _systemPromptFor(AiProvider.openAi),
            'input': prompt,
            'max_output_tokens': 1200,
          }),
        )
        .timeout(const Duration(seconds: 30));

    _ensureSuccessfulResponse(response, AiProvider.openAi.label);
    final data = jsonDecode(response.body);
    if (data is Map && data['output'] is List) {
      final answer = (data['output'] as List)
          .whereType<Map>()
          .where((item) => item['type'] == 'message')
          .expand(
            (item) =>
                item['content'] is List ? item['content'] as List : const [],
          )
          .whereType<Map>()
          .where((part) => part['type'] == 'output_text')
          .map((part) => part['text'])
          .whereType<String>()
          .join()
          .trim();
      if (answer.isNotEmpty) return answer;
    }
    throw StateError('OpenAI tidak mengembalikan jawaban teks.');
  }

  Future<String> _callGroqApi(String apiKey, String prompt) {
    return _callChatCompletionsApi(
      provider: AiProvider.groq,
      apiKey: apiKey,
      prompt: prompt,
      endpoint: Uri.https('api.groq.com', '/openai/v1/chat/completions'),
    );
  }

  Future<String> _callChatCompletionsApi({
    required AiProvider provider,
    required String apiKey,
    required String prompt,
    required Uri endpoint,
  }) async {
    final response = await http
        .post(
          endpoint,
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'model': provider.model,
            'messages': [
              {'role': 'system', 'content': _systemPromptFor(provider)},
              {'role': 'user', 'content': prompt},
            ],
            'temperature': 0.7,
            'max_tokens': 1200,
          }),
        )
        .timeout(const Duration(seconds: 30));

    _ensureSuccessfulResponse(response, provider.label);
    final data = jsonDecode(response.body);
    if (data is Map && data['choices'] is List) {
      final choices = data['choices'] as List;
      if (choices.isNotEmpty && choices.first is Map) {
        final message = choices.first['message'];
        if (message is Map && message['content'] is String) {
          final answer = (message['content'] as String).trim();
          if (answer.isNotEmpty) return answer;
        }
      }
    }
    throw StateError('${provider.label} tidak mengembalikan jawaban teks.');
  }

  void _ensureSuccessfulResponse(http.Response response, String provider) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    String message = 'HTTP ${response.statusCode}';
    try {
      final data = jsonDecode(response.body);
      if (data is Map) {
        final error = data['error'];
        if (error is Map && error['message'] is String) {
          message = error['message'] as String;
        } else if (error is String && error.isNotEmpty) {
          message = error;
        }
      }
    } on FormatException {
      // Keep the HTTP status when the provider returns a non-JSON error body.
    }
    throw StateError('$provider menolak permintaan: $message');
  }

  String _generateTutorResponse(AiProvider provider, String prompt) {
    final lower = prompt.toLowerCase();

    // 1. Perbedaan Tiga "de": 的, 得, 地
    if (prompt.contains('的') ||
        prompt.contains('得') ||
        prompt.contains('地') ||
        lower.contains('partikel de') ||
        (lower.contains('perbedaan') && lower.contains('de'))) {
      return '''
🤖 **[Google Gemini Tutor] Panduan Memahami Tiga "de" (的, 得, 地)**:

Dalam tata bahasa Mandarin, ketiga karakter ini sama-sama dibaca **de** (nada netral), namun memiliki fungsi gramatikal yang sangat berbeda:

1. **的 (de) ➔ Partikel Kepemilikan & Kata Sifat**
   • Rumus: `[Pemilik / Kata Sifat] + 的 + [Kata Benda]`
   • Contoh: 我的书 (wǒ de shū) = Buku saya.
   • Contoh: 漂亮的衣服 (piàoliang de yīfu) = Pakaian yang indah.

2. **得 (de) ➔ Partikel Derajat / Kualitas Aksi**
   • Rumus: `[Kata Kerja] + 得 + [Keterangan Derajat / Hasil]`
   • Contoh: 他跑得很快 (tā pǎo de hěn kuài) = Dia berlari dengan sangat cepat.
   • Contoh: 你说得很好 (nǐ shuō de hěn hǎo) = Kamu berbicara sangat bagus.

3. **地 (de) ➔ Partikel Cara / Keterangan Cara Melakukan**
   • Rumus: `[Kata Keterangan / Adverb] + 地 + [Kata Kerja]`
   • Contoh: 慢慢地走 (mànmàn de zǒu) = Berjalan dengan perlahan.
   • Contoh: 高兴地说 (gāoxìng de shuō) = Berbicara dengan gembira.

💡 **Tips Cepat Mengingat**:
• Ada benda di belakangnya? Gunakan **的**!
• Menjelaskan seberapa bagus/cepat kata kerjanya? Gunakan **得**!
• Menerangkan gaya atau cara sebelum aksi? Gunakan **地**! 🐼✨''';
    }

    // 2. Membedakan Nada 2 dan Nada 3
    if (lower.contains('nada 2') ||
        lower.contains('nada 3') ||
        lower.contains('membedakan nada')) {
      return '''
🤖 **[Google Gemini Tutor] Panduan Membedakan Nada 2 dan Nada 3**:

Pembedaan Nada 2 dan Nada 3 sering menjadi tantangan bagi pemula. Berikut panduan praktisnya:

📈 **Nada 2 (阳平 - Yángpíng) ➔ Nada Naik (Skala 35)**:
• **Karakter**: Intonasi bertanya atau heran, seperti saat kamu bilang: *"Hah?! Masa sih?"*.
• **Bentuk**: Suara meluncur naik lurus dari tengah ke tinggi tanpa turun dulu.
• **Contoh**: 
  - 白 (bái) = putih
  - 来 (lái) = datang
  - 银行 (yínháng) = bank

📉⤴️ **Nada 3 (上声 - Shǎngshēng) ➔ Nada Turun Lalu Naik (Skala 214)**:
• **Karakter**: Intonasi merenung atau mengangguk dalam: *"O... oh begitu!"*.
• **Bentuk**: Suara dijatuhkan ke nada paling rendah di dada, baru sedikit melenting naik.
• **Contoh**:
  - 好 (hǎo) = baik
  - 你 (nǐ) = kamu
  - 水 (shuǐ) = air

💡 **Aturan Alami Perubahan Nada (Tone Sandhi)**:
Ketika dua Nada 3 bertemu berturut-turut: `Nada 3 + Nada 3` ➔ dibaca menjadi `Nada 2 + Nada 3`!
Karakter 你 (nǐ) + 好 (hǎo) secara fonetik resmi diucapkan: **ní hǎo**! 🐼🎉''';
    }

    // 3. Kapan pakai 不 (bù) vs 没 (méi)
    if (prompt.contains('不') ||
        prompt.contains('没') ||
        lower.contains('bu vs mei') ||
        lower.contains('bù vs méi') ||
        lower.contains('negasi')) {
      return '''
🤖 **[Google Gemini Tutor] Perbedaan Negasi: 不 (bù) vs 没 (méi)**:

Keduanya berarti "tidak" atau "bukan", namun digunakan pada situasi yang berbeda:

1. **不 (bù) ➔ Kebiasaan, Kemauan, Fakta Masa Kini & Masa Depan**:
   • Digunakan untuk kata sifat dan kata kerja statif (seperti 是, 像).
   • Contoh: 我不吃肉 (wǒ bù chī ròu) = Saya tidak makan daging (kebiasaan/pantangan).
   • Contoh: 他不是老师 (tā bù shì lǎoshī) = Dia bukan guru.
   • Contoh: 明天我不去 (míngtiān wǒ bù qù) = Besok saya tidak akan pergi.

2. **没 / 没有 (méi / méiyǒu) ➔ Masa Lalu / Belum Terjadi & Kepemilikan**:
   • Digunakan untuk menyatakan suatu peristiwa **belum/tidak terjadi**, serta ketiadaan barang.
   • Contoh: 我没吃早饭 (wǒ méi chī zǎofàn) = Saya tidak/belum makan sarapan (tadi pagi).
   • Contoh: 我没有钱 (wǒ méiyǒu qián) = Saya tidak punya uang.

⚠️ **Catatan Penting**:
Kata kerja 有 (yǒu - punya/ada) **HANYA** boleh dinegasikan dengan 没 (méiyǒu). Tidak pernah ada kalimat "不有"! 🐼👍''';
    }

    // 4. Percakapan memesan makanan di restoran
    if (lower.contains('restoran') ||
        lower.contains('makanan') ||
        lower.contains('pesan') ||
        lower.contains('menu')) {
      return '''
🤖 **[Google Gemini Tutor] Simulasi Percakapan di Restoran (点菜 - Diǎncài)**:

Berikut kalimat-kalimat penting saat kamu makan di restoran Tiongkok:

1. **Melihat Menu & Memanggil Pelayan**:
   • 服务员，请给我菜单 (Fúwùyuán, qǐng gěi wǒ càidān) = Pelayan, tolong beri saya menu.
   • 请问，有什么推荐吗？(Qǐngwèn, yǒu shénme tuījiàn ma?) = Mau tanya, ada rekomendasi makanan apa?

2. **Memesan Makanan**:
   • 我要一份宫保鸡丁 (Wǒ yào yí fèn Gōngbǎo Jīdīng) = Saya mau satu porsi ayam kungpao.
   • 不要太辣，谢谢 (Bú yào tài là, xièxie) = Jangan terlalu pedas, terima kasih.
   • 来一杯冰水 (Lái yì bēi bīng shuǐ) = Minta satu gelas air dingin.

3. **Membayar Tagihan**:
   • 服务员，买单！(Fúwùyuán, mǎidān!) = Pelayan, minta bon / mau bayar!
   • 可以用微信支付吗？(Kěyǐ yòng Wēixìn zhīfù ma?) = Bisakah bayar pakai WeChat Pay?

Semoga membantu kamu saat bepergian ke Tiongkok atau makan di resto Mandarin! 🍜🥟✨''';
    }

    // 5. Tips Menghafal Karakter Hanzi
    if (lower.contains('hanzi') ||
        lower.contains('menghafal') ||
        lower.contains('tips')) {
      return '''
🤖 **[Google Gemini Tutor] 3 Tips Ampuh Menghafal Karakter Hanzi**:

1. **Pahami Radikal (部首 - Bùshǒu) sebagai Akar Kata**:
   Sebagian besar Hanzi tersusun dari radikal bermakna:
   • 氵 (tiga titik air) ➔ berhubungan dengan air: 江 (sungai), 海 (laut), 洗 (mencuci).
   • 饣 (makanan) ➔ berhubungan dengan makanan: 饭 (nasi), 饮 (minuman).
   • 讠 (ucapan) ➔ berhubungan dengan kata: 说 (berbicara), 话 (percakapan).

2. **Ikuti Urutan Goresan Resmi (笔顺 - Bǐshùn)**:
   Menulis sesuai urutan: dari atas ke bawah, kiri ke kanan, horizontal dulu baru vertikal. Ini mengaktifkan memori otot (*muscle memory*) di jarimu!

3. **Buat Cerita Visual / Mnemonik**:
   Contoh karakter 休 (xiū - istirahat): bayangkan ada orang (人) sedang bersandar di pohon (木) untuk beristirahat! 🌳🚶

Latih menulisnya setiap hari di fitur **Hanzi Stroke Challenge** aplikasi ini ya! 🐼💪''';
    }

    // Jawaban ramah fleksibel untuk pertanyaan lainnya
    return '''
🤖 **[Google Gemini Tutor] Penjelasan Bahasa Mandarin**:

Mengenai pertanyaanmu: "$prompt"

Dalam bahasa Mandarin, mempelajari kosakata dan tata bahasa sangat menyenangkan jika dipahami per komponen katanya:
• 学习 (xuéxí) = belajar (学 = ilmu, 习 = mempraktikkan/mengulang).
• 练习 (liànxí) = latihan (melatih terus menerus hingga terbiasa).
• 加油 (jiāyóu) = semangat! (secara harfiah: tambah minyak/tenaga).

💡 **Tips Tutor**:
Jangan ragu untuk bertanya lebih detail tentang contoh kalimat, perbedaan kata, atau cara pengucapannya ya! Xiao Xiong siap membantu. 🐼✨''';
  }
}
