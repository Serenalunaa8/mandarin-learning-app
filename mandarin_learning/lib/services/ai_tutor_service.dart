import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

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

  // URL Ollama lokal default jika berjalan di PC/emulator
  String ollamaBaseUrl = 'http://10.0.2.2:11434';
  String modelName = 'qwen2.5:latest';

  /// Mengirim pertanyaan ke AI Tutor dengan sistem fallback cerdas (PBI-035)
  Future<String> askAiTutor(String prompt) async {
    // 1. Coba hubungi Ollama endpoint
    try {
      final response = await http.post(
        Uri.parse('$ollamaBaseUrl/api/generate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'model': modelName,
          'prompt': 'Kamu adalah Tutor AI Bahasa Mandarin ramah untuk pemula Indonesia. '
              'Jawablah dengan ringkas, jelas, gunakan pinyin dan arti. '
              'Pertanyaan: $prompt',
          'stream': false,
        }),
      ).timeout(const Duration(milliseconds: 1500));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final answer = data['response']?.toString();
        if (answer != null && answer.trim().isNotEmpty) {
          return answer.trim();
        }
      }
    } catch (e) {
      debugPrint('[AiTutorService] Ollama offline/unreachable: $e. Mengaktifkan fallback statis.');
    }

    // 2. Jawaban Cerdas Fallback Offline (PRD FR-14 & PBI-035)
    return _generateFallbackAnswer(prompt);
  }

  String _generateFallbackAnswer(String query) {
    final q = query.toLowerCase();

    if (q.contains('的') || q.contains('得') || q.contains('地') || q.contains('partikel de')) {
      return '✨ **Perbedaan Tiga "de" (的, 得, 地) dalam Bahasa Mandarin:**\n\n'
          '1. **的 (de) - Kepemilikan & Kata Sifat**\n'
          '   Rumus: Kata Sifat/Kepemilikan + 的 + Kata Benda\n'
          '   Contoh: 我的书 (wǒ de shū) = Buku saya; 漂亮的花 (piàoliang de huā) = Bunga yang indah.\n\n'
          '2. **得 (de) - Menilai Tingkat Perbuatan**\n'
          '   Rumus: Kata Kerja + 得 + Keterangan Hasil\n'
          '   Contoh: 他跑得很快 (tā pǎo de hěn kuài) = Dia berlari dengan sangat cepat.\n\n'
          '3. **地 (de) - Menjelaskan Cara Tindakan (Adverb)**\n'
          '   Rumus: Keterangan Keadaan + 地 + Kata Kerja\n'
          '   Contoh: 慢慢地走 (mànman de zǒu) = Berjalan dengan perlahan.';
    }

    if (q.contains('nada 2') || q.contains('nada 3') || q.contains('bedanya nada') || q.contains('intonasi')) {
      return '🎵 **Cara Membedakan Nada 2 dan Nada 3:**\n\n'
          '• **Nada 2 (Naik / 阳平 / 3-5):**\n'
          '  Intonasi menanjak lurus dari sedang ke tinggi, persis seperti orang heran atau bertanya: *"Hah? Benarkah?"*\n'
          '  Contoh: 麻 (má - rami/mati rasa), 谁 (shéi - siapa).\n\n'
          '• **Nada 3 (Turun-Naik / 上声 / 2-1-4):**\n'
          '  Mulai dari nada sedang-rendah, diturunkan ke rongga dada yang paling dalam, lalu diangkat kembali ke atas di akhir.\n'
          '  Contoh: 马 (mǎ - kuda), 你 (nǐ - kamu).\n\n'
          '💡 *Tips:* Jika ada dua Nada 3 berdampingan (seperti 你好 nǐ hǎo), suku kata pertama otomatis berubah dibaca Nada 2 (*ní hǎo*)!';
    }

    if (q.contains('tidak') || q.contains('bù') || q.contains('bu') || q.contains('mei') || q.contains('没')) {
      return '💡 **Perbedaan 不 (bù) dan 没 (méi):**\n\n'
          '1. **不 (bù):**\n'
          '   Digunakan untuk negasi waktu sekarang/masa depan, kebiasaan, atau kemauan.\n'
          '   Contoh: 我不去 (wǒ bù qù) = Saya tidak mau/akan pergi.\n'
          '   Digunakan bersama kata sifat: 不好 (bù hǎo) = Tidak bagus.\n\n'
          '2. **没 (méi):**\n'
          '   Digunakan untuk negasi masa lalu (sesuatu yang belum/tidak terjadi) dan kepemilikan.\n'
          '   Khusus kata "ada/punya" (有 yǒu) selalu memakai 没: 没有 (méiyǒu = tidak ada/tidak punya).\n'
          '   Contoh: 我没去 (wǒ méi qù) = Saya tidak pergi (kemarin/tadi).';
    }

    if (q.contains('pesan makanan') || q.contains('restoran') || q.contains('kafe') || q.contains('menu')) {
      return '🍜 **Percakapan Singkat Memesan Makanan di Restoran:**\n\n'
          '• Pelayan: 请问，你们几位？(Qǐngwèn, nǐmen jǐ wèi?)\n'
          '  *Permisi, untuk berapa orang?*\n\n'
          '• Kamu: 两位。请给我菜单。(Liǎng wèi. Qǐng gěi wǒ càidān.)\n'
          '  *Dua orang. Tolong beri kami buku menu.*\n\n'
          '• Kamu: 我要一份宫保鸡丁和一碗米饭。(Wǒ yào yī fèn gōngbǎo jīdīng hé yī wǎn mǐfàn.)\n'
          '  *Saya mau satu porsi ayam kung pao dan semangkuk nasi.*\n\n'
          '• Minta Bon: 服务员，买单！(Fúwùyuán, mǎidān!)\n'
          '  *Pelayan, minta bon / tagihan!*';
    }

    if (q.contains('menghafal') || q.contains('tips hanzi') || q.contains('radikal') || q.contains('stroke')) {
      return '✍️ **Tips Efektif Menghafal Karakter Hanzi untuk Pemula:**\n\n'
          '1. **Pahami Radikal (部首 - bùshǒu):**\n'
          '   Radikal memberi petunjuk arti. Contoh: radikal air (氵) selalu berkaitan dengan cairan (水, 河, 海), radikal orang (亻) terkait manusia (你, 他).\n\n'
          '2. **Gunakan Asosiasi Cerita:**\n'
          '   Contoh: 休 (xiū - istirahat) = ada orang (亻) bersandar di samping pohon (木).\n\n'
          '3. **Latihan Urutan Goresan (笔顺):**\n'
          '   Menulis sesuai urutan: dari atas ke bawah, dari kiri ke kanan. Gunakan fitur *Stroke Challenge* di aplikasi ini untuk berlatih!';
    }

    // Jawaban pembuka umum yang informatif
    return 'Halo! Senang bisa membantumu belajar Mandarin. '
        'Kamu bisa menanyakan apapun tentang kosakata HSK, tata bahasa Mandarin, contoh kalimat, atau pelafalan nada. '
        'Misalnya: *"Bagaimana membedakan nada 2 dan 3?"* atau *"Jelaskan cara pakai partikel 了 (le)"*.';
  }
}
