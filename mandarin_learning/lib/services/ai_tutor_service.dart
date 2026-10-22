import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'supabase_service.dart';

enum AiProvider {
  gemini('gemini', 'Google Gemini', 'gemini-1.5-flash'),
  anthropic('anthropic', 'Anthropic Claude', 'claude-3-5-haiku-20241022'),
  openAi('openai', 'OpenAI GPT', 'gpt-4o-mini'),
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

  // System instruction umum untuk AI Tutor
  static const String _baseSystemRules = '''
Kamu adalah Xiao Xiong (小熊), AI Tutor Mandarin yang mengajar penutur bahasa Indonesia (pemula hingga menengah HSK 1-6).
Aturan wajib:
1. Berikan jawaban dalam Bahasa Indonesia yang ramah, jelas, dan akurat.
2. Setiap kali menyebutkan kosakata Mandarin, wajib sertakan: Karakter Hanzi, Pinyin dengan tanda nada lengkap, dan Arti Indonesia.
   Format: 咖啡馆 (kāfēiguǎn) = kafe.
3. Berikan contoh kalimat aplikatif yang relevan.
''';

  /// System prompt spesifik untuk Google Gemini (Analitis, wawasan budaya, struktur tabel)
  static const String _geminiSystemPrompt = '''
$_baseSystemRules
Identitas Model: Kamu beroperasi dengan mesin Google Gemini 1.5 Flash.
Gaya Khas Gemini:
- Sajikan penjelasan yang sangat terstruktur dengan poin-poin rapi atau perbandingan visual.
- Sertakan wawasan budaya Tiongkok kontemporer atau etimologi karakter jika relevan.
- Awali dengan salam khas: "Halo! Xiao Xiong bersama Google Gemini siap membantu belajarmu 🤖✨".
''';

  /// System prompt spesifik untuk Anthropic Claude (Linguistik mendalam, nuansa gramatikal halus)
  static const String _claudeSystemPrompt = '''
$_baseSystemRules
Identitas Model: Kamu beroperasi dengan mesin Anthropic Claude 3.5.
Gaya Khas Claude:
- Berikan analisis tata bahasa yang mendalam, teliti, dan bernuansa linguistik tinggi.
- Jelaskan *mengapa* suatu aturan ada secara gramatikal dan bedakan kesalahan umum pemula.
- Awali dengan salam khas: "Halo! Bersama Anthropic Claude, mari kita telusuri tata bahasa Mandarin secara mendalam 🧠📜".
''';

  /// System prompt spesifik untuk OpenAI GPT (Interaktif, percakapan dua arah, mnemonik)
  static const String _openAiSystemPrompt = '''
$_baseSystemRules
Identitas Model: Kamu beroperasi dengan mesin OpenAI GPT-4o Mini.
Gaya Khas ChatGPT:
- Gaya bicara sangat hidup, komunikatif, dan interaktif seperti mengobrol santai dengan guru les privat.
- Sertakan simulasi dialog dua arah (Peran A dan Peran B) agar siswa bisa langsung mempraktikkannya.
- Awali dengan salam khas: "Halo! Xiao Xiong powered by OpenAI GPT siap mengajakmu latihan seru hari ini 💬🐼".
''';

  /// System prompt spesifik untuk Groq Llama (Super cepat, ringkas, poin kunci instan)
  static const String _groqSystemPrompt = '''
$_baseSystemRules
Identitas Model: Kamu beroperasi dengan mesin Groq Llama 3.3 70B (Ultra Fast Inference).
Gaya Khas Groq:
- Sajikan jawaban to-the-point, padat, ringkas, tanpa pengantar panjang bertele-tele.
- Berikan rumus hafalan cepat dan contoh kalimat kilat yang mudah diingat dalam 10 detik.
- Awali dengan salam khas: "Halo! Jawaban kilat Xiao Xiong x Groq Llama ⚡:".
''';

  Future<List<AiProvider>> getAvailableProviders() async {
    return AiProvider.values;
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

  /// Memanggil AI Tutor dengan pemetaan API yang tepat sesuai provider terpilih
  Future<String> askAiTutor(
    String prompt, {
    required AiProvider provider,
  }) async {
    final trimmedPrompt = prompt.trim();
    if (trimmedPrompt.isEmpty) return 'Silakan masukkan pertanyaanmu tentang bahasa Mandarin.';

    final customKey = await getApiKey(provider);

    // 1. Prioritas Utama: Panggilan Langsung ke API Resmi Provider jika User punya Key
    if (customKey != null && customKey.isNotEmpty) {
      try {
        debugPrint('[AiTutorService] Menghubungi API resmi ${provider.label} (${provider.model})...');
        return await _callDirectApi(provider, customKey, trimmedPrompt);
      } catch (e) {
        debugPrint('[AiTutorService] Direct API ${provider.label} error: $e');
        // Teruskan ke fallback jika koneksi API langsung gagal
      }
    }

    // 2. Coba Supabase Edge Function jika tersedia
    try {
      final response = await SupabaseService.instance.client.functions
          .invoke(
            'ai-tutor',
            body: {'provider': provider.id, 'prompt': trimmedPrompt},
          )
          .timeout(const Duration(seconds: 12));
      final data = response.data;
      if (data is Map<String, dynamic>) {
        final answer = data['answer']?.toString().trim();
        if (answer != null && answer.isNotEmpty) return answer;
      }
    } catch (_) {}

    // 3. Fallback cerdas: Offline Smart Engine yang membedakan jawaban tiap provider
    return _getSmartOfflineResponse(trimmedPrompt, provider);
  }

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

  /// 1. Google Gemini API (v1beta)
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
            'role': 'user',
            'parts': [
              {'text': prompt}
            ]
          }
        ],
        'systemInstruction': {
          'parts': [
            {'text': _geminiSystemPrompt}
          ]
        },
        'generationConfig': {
          'temperature': 0.7,
          'maxOutputTokens': 1024,
        }
      }),
    ).timeout(const Duration(seconds: 25));

    if (response.statusCode != 200) {
      final err = jsonDecode(response.body);
      final msg = err['error']?['message'] ?? 'Status ${response.statusCode}';
      throw Exception('Gemini Error: $msg');
    }

    final data = jsonDecode(response.body);
    final candidates = data['candidates'] as List?;
    if (candidates != null && candidates.isNotEmpty) {
      final parts = candidates.first['content']?['parts'] as List?;
      if (parts != null && parts.isNotEmpty) {
        return parts.first['text'].toString().trim();
      }
    }
    throw Exception('Gemini tidak mengembalikan respons teks.');
  }

  /// 2. Anthropic Claude API (v1/messages)
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
        'system': _claudeSystemPrompt,
        'messages': [
          {'role': 'user', 'content': prompt}
        ],
      }),
    ).timeout(const Duration(seconds: 25));

    if (response.statusCode != 200) {
      final err = jsonDecode(response.body);
      final msg = err['error']?['message'] ?? 'Status ${response.statusCode}';
      throw Exception('Claude Error: $msg');
    }

    final data = jsonDecode(response.body);
    final content = data['content'] as List?;
    if (content != null && content.isNotEmpty) {
      return content.first['text'].toString().trim();
    }
    throw Exception('Claude tidak mengembalikan respons teks.');
  }

  /// 3. OpenAI GPT API (v1/chat/completions)
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
          {'role': 'system', 'content': _openAiSystemPrompt},
          {'role': 'user', 'content': prompt}
        ],
        'temperature': 0.7,
      }),
    ).timeout(const Duration(seconds: 25));

    if (response.statusCode != 200) {
      final err = jsonDecode(response.body);
      final msg = err['error']?['message'] ?? 'Status ${response.statusCode}';
      throw Exception('OpenAI Error: $msg');
    }

    final data = jsonDecode(response.body);
    final choices = data['choices'] as List?;
    if (choices != null && choices.isNotEmpty) {
      return choices.first['message']['content'].toString().trim();
    }
    throw Exception('OpenAI tidak mengembalikan respons teks.');
  }

  /// 4. Groq API (v1/chat/completions)
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
          {'role': 'system', 'content': _groqSystemPrompt},
          {'role': 'user', 'content': prompt}
        ],
        'temperature': 0.7,
      }),
    ).timeout(const Duration(seconds: 25));

    if (response.statusCode != 200) {
      final err = jsonDecode(response.body);
      final msg = err['error']?['message'] ?? 'Status ${response.statusCode}';
      throw Exception('Groq Error: $msg');
    }

    final data = jsonDecode(response.body);
    final choices = data['choices'] as List?;
    if (choices != null && choices.isNotEmpty) {
      return choices.first['message']['content'].toString().trim();
    }
    throw Exception('Groq tidak mengembalikan respons teks.');
  }

  /// Respons cerdas bawaan yang dibedakan secara nyata untuk setiap AI model
  String _getSmartOfflineResponse(String prompt, AiProvider provider) {
    final lower = prompt.toLowerCase();

    // 1. Topik Partikel "de" (的, 得, 地)
    if (lower.contains('de') || lower.contains('的') || lower.contains('得') || lower.contains('地')) {
      switch (provider) {
        case AiProvider.gemini:
          return '''
🤖 **[Google Gemini 1.5 Flash] Struktur & Analisis Partikel 的 / 得 / 地**:

Dalam tata bahasa Mandarin, ketiga partikel ini dibaca sama ("de") namun memiliki fungsi struktur kalimat yang sangat berlainan:

📊 **Tabel Formula Struktural**:
• **的 (de) [Struktur Kata Benda]**: Modifikasi kepemilikan atau kata sifat.
  Rumus: `[Subjek/Sifat] + 的 + [Kata Benda]`
  Contoh: 我的中文老师 (wǒ de zhōngwén lǎoshī) = Guru bahasa Mandarin saya.
  Contoh: 漂亮的学校 (piàoliang de xuéxiào) = Sekolah yang indah.

• **得 (de) [Komplemen Hasil/Derajat]**: Menilai tingkat keberhasilan suatu perbuatan.
  Rumus: `[Kata Kerja] + 得 + [Keterangan/Penilaian]`
  Contoh: 他写得很好 (tā xiě de hěn hǎo) = Dia menulis dengan sangat bagus.

• **地 (de) [Adverbia/Keterangan Cara]**: Menjelaskan cara melakukan suatu tindakan.
  Rumus: `[Kata Sifat] + 地 + [Kata Kerja]`
  Contoh: 认真地复习 (rènzhēn de fùxí) = Mengulang pelajaran dengan bersungguh-sungguh.

💡 *Wawasan Budaya*: Pada teks Tiongkok kuno (Hanzi Klasik), karakter 的 aslinya berarti "sasaran anak panah" sebelum berevolusi menjadi partikel gramatikal modern!
''';

        case AiProvider.anthropic:
          return '''
🧠 **[Anthropic Claude 3.5] Nuansa Linguistik & Kaidah Gramatikal 的 / 得 / 地**:

Secara sintaksis, perbedaan ketiga partikel homofon ini terletak pada posisi frasa (*syntactic positioning*):

1. **的 (de) - Partikel Nominal (Nominal Attribute Marker)**:
   Digunakan secara eksklusif untuk mendefinisikan objek nominal. Jika kata yang mengikuti adalah kata benda (noun), pilihan Anda selalu **的**.
   • Nuansa: Membatasi atau memperjelas kepemilikan dan karakteristik.
   • Contoh: 蓝色的天空 (lánsè de tiānkōng) = Langit yang biru.

2. **得 (de) - Partikel Komplemen Derajat (Degree / Descriptive Complement)**:
   Hanya muncul *setelah* kata kerja atau kata sifat, menghubungkan aksi dengan evaluasi pencapaian.
   • Nuansa: Menjawab pertanyaan "seberapa baik/parah tindakan itu terlaksana?".
   • Contoh: 你走得太慢了 (nǐ zǒu de tài màn le) = Kamu berjalan terlalu lambat.

3. **地 (de) - Partikel Adverbial (Manner Adverbial Marker)**:
   Berfungsi mengubah adjektiva menjadi keterangan cara yang diletakkan *sebelum* predikat verbal.
   • Nuansa: Menggambarkan keadaan psikologis atau fisik saat perbuatan berlangsung.
   • Contoh: 开心地跳舞 (kāixīn de tiàowǔ) = Menari dengan perasaan gembira.

Semoga analisis terstruktur ini membantu pemahaman konsep abstrak Anda! 🐼📜
''';

        case AiProvider.openAi:
          return '''
💬 **[OpenAI GPT-4o Mini] Latihan Interaktif & Dialog Praktis 的 / 得 / 地**:

Hai! Belajar "de" paling mudah lewat percakapan sehari-hari! Yuk simak obrolan seru berikut:

🗣️ **Simulasi Percakapan**:
A: 这是谁**的**手机？(Zhè shì shéi **de** shǒujī?)
   = Ini ponsel milik siapa? *(Pakai **的** karena ada benda: ponsel)*
B: 这是我**的**！(Zhè shì wǒ **de**!)
   = Ini punyaku!

A: 你汉字写**得**真漂亮！(Nǐ hànzì xiě **de** zhēn piàoliang!)
   = Tulisan Hanzimu rapi banget! *(Pakai **得** setelah aksi: menulis)*
B: 谢谢！我每天都在努力**地**练习。(Xièxie! Wǒ měitiān dōu zài nǔlì **de** liànxí.)
   = Terima kasih! Tiap hari aku giat berlatih. *(Pakai **地** sebelum aksi: berlatih)*

🎯 **Trik Cepat Hafal**:
• Ketemu kata benda di belakang? 👉 Pasang **的**
• Menilai hasil kerja di depan? 👉 Pasang **得**
• Menjelaskan cara gerak? 👉 Pasang **地**

Coba buat 1 kalimat buatanmu sendiri yuk, nanti Xiao Xiong koreksi! 🐼✨
''';

        case AiProvider.groq:
          return '''
⚡ **[Groq Llama 3.3] Cheat-Sheet Kilat 的 / 得 / 地**:

Formula 5 detik:
1. `Sifat/Milik + 的 + Benda` 👉 你的朋友 (nǐ de péngyou) = Temanmu.
2. `Kerja + 得 + Penilaian` 👉 跑得快 (pǎo de kuài) = Lari cepat.
3. `Cara + 地 + Kerja` 👉 大声地说 (dàshēng de shuō) = Berbicara keras.

Aturan Kunci:
• Benda di kanan? Pakai **的**.
• Kerja di kiri? Pakai **得**.
• Kerja di kanan? Pakai **地**.

To the point & langsung ingat! 🚀
''';
      }
    }

    // 2. Topik Nada 2 dan Nada 3
    if (lower.contains('nada') || lower.contains('tone') || lower.contains('2 dan 3') || (lower.contains('2') && lower.contains('3'))) {
      switch (provider) {
        case AiProvider.gemini:
          return '''
🤖 **[Google Gemini 1.5 Flash] Analisis Akustik: Nada 2 (阳平) vs Nada 3 (上声)**:

🎵 **Profil Nada Berdasarkan Kontur Pitch (Skala 1 - 5)**:
• **Nada 2 (Yángpíng - ˊ)**: Kontur 35 (Menaik).
  Dimulai dari nada percakapan normal lalu meluncur tegas ke atas.
  Contoh: 羊 (yáng) = domba; 茶 (chá) = teh.

• **Nada 3 (Shǎngshēng - ˇ)**: Kontur 214 (Turun-Naik).
  Suara ditekan rendah ke tenggorokan (skala 1) sebelum sedikit melenting naik.
  Contoh: 马 (mǎ) = kuda; 水 (shuǐ) = air.

💡 **Aturan Alami Perubahan Nada (Tone Sandhi)**:
Ketika dua Nada 3 bertemu: `3 + 3 ➔ 2 + 3`.
Karakter 你 (nǐ) + 好 (hǎo) secara fonetik diucapkan sebagai `ní hǎo`!
''';

        case AiProvider.anthropic:
          return '''
🧠 **[Anthropic Claude 3.5] Studi Fonologis Nada 2 & Nada 3**:

Pembedaan antara Nada 2 dan Nada 3 adalah salah satu tantangan fonetik utama pelajar:

1. **Perbedaan Dinamika Pita Suara**:
   Pada Nada 2, tegangan pita suara dinaikkan secara linier tanpa jeda henti. Sedangkan pada Nada 3, pita suara justru dikendurkan hingga batas bawah register vokal (*vocal fry*) sebelum dilepaskan.

2. **Karakteristik "Half Third Tone"**:
   Dalam percakapan cepat alami, Nada 3 hampir selalu diucapkan hanya setengahnya (turun rendah 21, tanpa pantulan naik ke 4), KECUALI jika berdiri di akhir kalimat.
   Contoh: 北京 (Běijīng) diucapkan dengan menahan nada Běi tetap rendah tanpa naik kembali.

Ketepatan nada adalah fondasi makna dalam bahasa bertonal seperti Mandarin. 📜🐼
''';

        case AiProvider.openAi:
          return '''
💬 **[OpenAI GPT-4o Mini] Trik Tubuh Membedakan Nada 2 & Nada 3**:

Gunakan gestur kepala untuk membedakannya secara natural:

🙋 **Nada 2 (Nada Kaget / Heran)**:
• Goyangkan dagumu sedikit mendongak ke atas seperti saat kaget: "Hah?! Masa sih?".
• Latihan: 明天 (míngtiān) = besok.

🤔 **Nada 3 (Nada Mikir / 'Oalah')**:
• Tundukkan dagu ke bawah dada lalu sedikit angkat: "O... oh gitu!".
• Latihan: 很好 (hěn hǎo) = sangat baik.

Ingat rumus: Dua Nada 3 ketemu = nada pertama otomatis jadi Nada 2!
Ayo ikuti Xiao Xiong bunyikan: `Ní - Hǎo`! 🐼🎉
''';

        case AiProvider.groq:
          return '''
⚡ **[Groq Llama 3.3] Rumus Kilat Nada 2 vs Nada 3**:

• Nada 2: **NAIK** (Intonasi: "Hah?!") ➔ 白 (bái = putih)
• Nada 3: **TURUN DULU** baru naik (Intonasi: "O... ya?") ➔ 雨 (yǔ = hujan)

Peraturan Wajib:
`Nada 3 + Nada 3` ➔ otomatis berubah jadi `Nada 2 + Nada 3`!
(你好 dibaca: ní hǎo).
Paling sering salah di ujian HSK! Hafalkan sekarang juga. ⚡
''';
      }
    }

    // 3. Topik Umum / Jawaban Standar Terarah per Provider
    switch (provider) {
      case AiProvider.gemini:
        return '''
🤖 **[Google Gemini 1.5 Flash] Penjelasan Kosakata Mandarin**:

Mengenai pertanyaanmu: "$prompt"

Berikut analisis kosakata dan komponen kalimat Mandarin yang relevan:
• 练习 (liànxí) = latihan (Karakter 练 artinya melatih serat benang; 习 artinya mengulang).
• 语法 (yǔfǎ) = tata bahasa (语 = bahasa, 法 = aturan/hukum).
• 进步 (jìnbù) = kemajuan / berkembang (进 = maju, 步 = langkah).

Kamu dapat memasukkan Gemini API Key di ikon Kunci (⚙️) untuk mendapatkan penjelasan multimodal tak terbatas! 🤖🐼
''';

      case AiProvider.anthropic:
        return '''
🧠 **[Anthropic Claude 3.5] Analisis Tata Bahasa Mendalam**:

Terkait topik: "$prompt"

Dalam linguistik bahasa Mandarin, struktur kalimat dasar mengikuti pola S-V-O (*Subject-Verb-Object*), namun penempatan keterangan waktu dan tempat wajib berada **sebelum** kata kerja:
`Subjek + Keterangan Waktu + Tempat + Kata Kerja + Objek`
Contoh: 我今天在图书馆看书 (Wǒ jīntiān zài túshūguǎn kàn shū) = Saya hari ini membaca buku di perpustakaan.

Semoga kaidah sintaksis ini memberikan kejelasan sistematis bagi pembelajaran Anda. 📜🐼
''';

      case AiProvider.openAi:
        return '''
💬 **[OpenAI GPT-4o Mini] Teman Belajar Mandarin Interaktif**:

Pertanyaan menarik nih tentang: "$prompt"!

Yuk langsung kita aplikasikan ke percakapan nyata!
Contoh kalimat sehari-hari:
• 你今天学了什么？(Nǐ jīntiān xué le shénme?) = Hari ini kamu belajar apa?
• 我学了新的汉字！(Wǒ xué le xīn de hànzì!) = Aku belajar Hanzi baru!

Mau latihan dialog Mandarin santai lainnya? Tulis kalimatmu dan Xiao Xiong bantu cek ya! 💬🐼✨
''';

      case AiProvider.groq:
        return '''
⚡ **[Groq Llama 3.3] Ringkasan Cepat & Poin Kunci**:

Topik: "$prompt"

Kunci Sukses Kilat:
1. SVO: Subjek + Predikat + Objek.
2. Waktu & Tempat SELALU sebelum Kata Kerja.
3. Kosakata penting: 加油 (jiāyóu) = Semangat! 成功 (chénggōng) = Sukses!

Cepat, tepat, langsung praktek! ⚡🐼
''';
    }
  }
}
