import 'package:flutter/foundation.dart';

import 'supabase_service.dart';
import 'vocabulary_service.dart';

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
      debugPrint(
        '[AiTutorService] Request backend gagal (${mode.id}), beralih ke database cerdas: $error',
      );
      final localAnswer = await _generateDatabaseFallbackAnswer(trimmedPrompt);
      if (localAnswer != null && localAnswer.isNotEmpty) {
        return _cleanAnswer(localAnswer);
      }
      if (error is StateError) rethrow;
      throw StateError(
        'AI belum bisa dihubungi. Periksa koneksi lalu coba lagi.',
      );
    }
  }

  String _cleanAnswer(String answer) {
    var cleaned = answer;
    // 1. Ganti **teks** menjadi teks (ambil teks di dalamnya tanpa $1)
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'\*\*(.*?)\*\*', dotAll: true),
      (m) => m.group(1) ?? '',
    );
    // 2. Ganti __teks__ menjadi teks
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'__(.*?)__', dotAll: true),
      (m) => m.group(1) ?? '',
    );
    // 3. Ganti *teks* (italic dalam teks) menjadi teks
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'(?<![\*\s])\*([^\*\n]+)\*(?![\*\s])'),
      (m) => m.group(1) ?? '',
    );
    // 4. Ubah bullet points markdown (* / - / + di awal baris) menjadi bullet point bersih '• '
    cleaned = cleaned.replaceAll(
      RegExp(r'^\s*[\*\-\+]\s+', multiLine: true),
      '• ',
    );
    // 5. Hapus header markdown seperti ### atau ## di awal baris
    cleaned = cleaned.replaceAll(
      RegExp(r'^\s{0,3}#{1,6}\s*', multiLine: true),
      '',
    );
    // 6. Hapus backticks `
    cleaned = cleaned.replaceAll('`', '');
    // 7. Hapus sisa-sisa tanda bintang liar (*) yang masih tertinggal
    cleaned = cleaned.replaceAll('*', '');
    // 8. Rapikan newline berlebih
    cleaned = cleaned.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return cleaned.trim();
  }

  Future<String?> _generateDatabaseFallbackAnswer(String prompt) async {
    final lower = prompt.toLowerCase().trim();

    // 1. Cek penolakan topik umum di luar konsep aplikasi dan Mandarin
    final nonMandarinKeywords = [
      'presiden',
      'politik',
      'pemilu',
      'pilpres',
      'menteri',
      'dpr',
      'python',
      'javascript',
      'php',
      'golang',
      'c++',
      'html',
      'css',
      'coding',
      'program',
      'flutter',
      'react',
      'database sql',
      'sepak bola',
      'liga champion',
      'piala dunia',
      'ronaldo',
      'messi',
      'saham',
      'crypto',
      'bitcoin',
      'reksadana',
      'investasi',
      'cuaca hari ini',
      'gempa',
      'tsunami',
      'ramalan',
      'zodiak',
      'resep rendang',
      'resep soto',
      'masak nasi',
      'bahasa inggris',
      'bahasa jepang',
      'bahasa korea',
      'bahasa arab',
      'bahasa jerman',
      'bahasa prancis',
    ];
    if (nonMandarinKeywords.any((k) => lower.contains(k))) {
      return 'Halo! Sebagai LingLing (玲玲) AI Tutor, saya khusus membantu pembelajaran bahasa Mandarin dan fitur aplikasi ini (kosakata HSK, tata bahasa, pelafalan nada, kuis, peta, dan budget trip).\n\nSaya tidak dapat membahas topik di luar bahasa Mandarin. Yuk, tanyakan seputar percakapan, kosakata, festival, atau materi Mandarin! 🐼';
    }

    // 2. Salam & Sapaan
    if (RegExp(
          r'^(halo|hai|hi|hey|hei|pagi|siang|sore|malam|ni hao|nǐ hǎo|你好)',
          caseSensitive: false,
        ).hasMatch(lower) &&
        lower.length < 25) {
      return 'Nǐ hǎo (你好)! Halo! Aku LingLing (玲玲), AI Tutor Mandarin pribadimu 🐼.\n\nAda festival budaya, percakapan, kosakata HSK, atau tata bahasa Mandarin yang ingin kamu pelajari hari ini?';
    }

    // 3. Budaya & Festival Tradisional Tiongkok
    if (lower.contains('kue gelang') ||
        lower.contains('kue bulan') ||
        lower.contains('mid autumn') ||
        lower.contains('zhongqiu') ||
        lower.contains('festival')) {
      if (lower.contains('kue gelang') ||
          lower.contains('kue bulan') ||
          lower.contains('bulan') ||
          lower.contains('zhongqiu')) {
        return 'Festival Kue Bulan (中秋节 - Zhōngqiūjié), yang dalam tradisi peranakan sering diasosiasikan dengan kue bulan atau kue pia/gelang tradisional, adalah perayaan panen musim gugur terbesar kedua di Tiongkok setelah Tahun Baru Imlek. Dirayakan setiap tanggal 15 bulan 8 penanggalan Imlek saat bulan purnama bersinar paling terang dan bulat sempurna.\n\n'
            'Makna utama festival ini adalah "Reuni dan Keutuhan Keluarga" (团圆 - Tuányuán). Bentuk kue bulan yang bulat melambangkan kebersamaan keluarga yang utuh tanpa terputus. Tradisi yang dilakukan meliputi makan kue bulan bersama keluarga, menikmati pemandangan bulan purnama (赏月 - Shǎngyuè), dan menyalakan lampion.\n\n'
            'Kosakata Mandarin Terkait:\n'
            '• 中秋节 (Zhōngqiūjié) : Festival Musim Gugur / Kue Bulan [HSK 4]\n'
            '• 月饼 (yuèbǐng) : Kue Bulan [HSK 3]\n'
            '  Contoh: 我喜欢吃红豆月饼。(Wǒ xǐhuan chī hóngdòu yuèbǐng. - Saya suka makan kue bulan kacang merah.)\n'
            '• 月亮 (yuèliang) : Bulan [HSK 1]\n'
            '• 团圆 (tuányuán) : Berkumpul bersama / Reuni keluarga [HSK 4]\n'
            '• 节日 (jiérì) : Hari raya / Festival [HSK 3]';
      }
      if (lower.contains('imlek') ||
          lower.contains('tahun baru') ||
          lower.contains('chunjie')) {
        return 'Tahun Baru Imlek atau Festival Musim Semi (春节 - Chūnjié) adalah perayaan terpenting bagi masyarakat Tionghoa yang menandai awal tahun baru dalam kalender lunar. Tradisinya meliputi membersihkan rumah, makan malam bersama keluarga (年夜饭), membagikan angpao (红包), dan menyalakan kembang api.\n\n'
            'Kosakata Mandarin Terkait:\n'
            '• 春节 (Chūnjié) : Tahun Baru Imlek [HSK 3]\n'
            '• 新年快乐 (Xīnnián kuàilè) : Selamat Tahun Baru [HSK 1]\n'
            '• 红包 (hóngbāo) : Amplop merah / Angpao [HSK 3]\n'
            '• 饺子 (jiǎozi) : Pangsit [HSK 2]';
      }
      if (lower.contains('perahu naga') ||
          lower.contains('duanwu') ||
          lower.contains('bakcang')) {
        return 'Festival Perahu Naga (端午节 - Duānwǔjié) adalah festival tradisional Tiongkok yang diperingati setiap tanggal 5 bulan 5 kalender lunar untuk mengenang penyair patriotik Qu Yuan. Tradisi utamanya adalah perlombaan perahu naga (赛龙舟) dan memakan bakcang (粽子).\n\n'
            'Kosakata Mandarin Terkait:\n'
            '• 端午节 (Duānwǔjié) : Festival Perahu Naga [HSK 4]\n'
            '• 粽子 (zòngzi) : Bakcang [HSK 3]\n'
            '• 龙舟 (lóngzhōu) : Perahu naga [HSK 4]';
      }
    }

    // 4. Situasi Percakapan Nyata
    if (lower.contains('kari') || lower.contains('curry')) {
      return 'Untuk memesan nasi kari dalam bahasa Mandarin, gunakan frasa berikut:\n\n'
          '顾客 (Pelanggan):\n'
          '我要一份咖喱饭。\n'
          '(Wǒ yào yí fèn gālǐfàn. - Saya mau satu porsi nasi kari.)\n\n'
          '服务员 (Pelayan):\n'
          '好的，要牛肉还是鸡肉？\n'
          '(Hǎo de, yào niúròu háishi jīròu? - Baik, mau daging sapi atau ayam?)\n\n'
          '顾客 (Pelanggan):\n'
          '鸡肉的，谢谢！\n'
          '(Jīròu de, xièxie! - Yang ayam, terima kasih!)\n\n'
          'Kosakata Terkait:\n'
          '• 咖喱饭 (gālǐfàn) : Nasi kari\n'
          '• 鸡肉 (jīròu) : Daging ayam [HSK 2]\n'
          '• 牛肉 (niúròu) : Daging sapi [HSK 3]\n'
          '• 米饭 (mǐfàn) : Nasi putih [HSK 1]';
    }

    if (lower.contains('pesan makanan') ||
        lower.contains('makan') ||
        lower.contains('restoran') ||
        lower.contains('menu')) {
      return 'Berikut contoh percakapan memesan makanan di restoran (点餐 - Diǎncān):\n\n'
          '服务员 (Pelayan):\n'
          '您好，请问要点什么？\n'
          '(Nǐ hǎo, qǐngwèn yào diǎn shénme? - Halo, mau pesan apa?)\n\n'
          '顾客 (Pelanggan):\n'
          '我要一份牛肉面和一杯冰水。\n'
          '(Wǒ yào yí fèn niúròumiàn hé yì bēi bīngshuǐ. - Saya mau satu porsi mie sapi dan segelas air es.)\n\n'
          '服务员 (Pelayan):\n'
          '好的，要辣的吗？\n'
          '(Hǎo de, yào là de ma? - Baik, apakah mau yang pedas?)\n\n'
          '顾客 (Pelanggan):\n'
          '不要辣，谢谢！买单多少钱？\n'
          '(Bú yào là, xièxie! Mǎidān duōshao qián? - Jangan pedas, terima kasih! Berapa total tagihannya?)\n\n'
          'Kosakata Terkait:\n'
          '• 点菜 (diǎncài) : Memesan makanan [HSK 2]\n'
          '• 买单 (mǎidān) : Membayar tagihan [HSK 3]\n'
          '• 好吃 (hǎochī) : Enak / Lezat [HSK 1]';
    }

    if (lower.contains('tanya jalan') ||
        lower.contains('arah') ||
        lower.contains('tersesat') ||
        lower.contains('stasiun') ||
        lower.contains('di mana')) {
      return 'Berikut contoh percakapan menanyakan arah jalan (问路 - Wènlù):\n\n'
          '路人 (Pejalan Kaki):\n'
          '请问，地铁站在哪里？\n'
          '(Qǐngwèn, dìtiězhàn zài nǎlǐ? - Permisi, stasiun kereta bawah tanah di mana?)\n\n'
          '当地人 (Warga Lokal):\n'
          '一直往前走，在第二个路口往右拐。\n'
          '(Yìzhí wǎng qián zǒu, zài dì èr gè lùkǒu wǎng yòu guǎi. - Jalan lurus terus, di persimpangan kedua belok kanan.)\n\n'
          '路人 (Pejalan Kaki):\n'
          '离这里远吗？\n'
          '(Lí zhèlǐ yuǎn ma? - Apakah jauh dari sini?)\n\n'
          '当地人 (Warga Lokal):\n'
          '不远，走路大约五分钟。\n'
          '(Bù yuǎn, zǒulù dàyuē wǔ fēnzhōng. - Tidak jauh, jalan kaki sekitar 5 menit.)\n\n'
          'Kosakata Terkait:\n'
          '• 地铁站 (dìtiězhàn) : Stasiun metro [HSK 2]\n'
          '• 往右拐 (wǎng yòu guǎi) : Belok kanan [HSK 3]';
    }

    if (lower.contains('belanja') ||
        lower.contains('harga') ||
        lower.contains('menawar') ||
        lower.contains('berapa harganya')) {
      return 'Berikut contoh percakapan berbelanja dan menawar harga (买东西 - Mǎi dōngxi):\n\n'
          '顾客 (Pembeli):\n'
          '老板，这件衣服多少钱？\n'
          '(Lǎobǎn, zhè jiàn yīfu duōshao qián? - Bos, baju ini berapa harganya?)\n\n'
          '售货员 (Penjual):\n'
          '一百块。\n'
          '(Yìbǎi kuài. - Seratus Yuan.)\n\n'
          '顾客 (Pembeli):\n'
          '太贵了，可以便宜一点吗？八十块行不行？\n'
          '(Tài guì le, kěyǐ piányi yìdiǎn ma? Bāshí kuài xíng bu xíng? - Terlalu mahal, boleh lebih murah sedikit? 80 Yuan boleh tidak?)\n\n'
          '售货员 (Penjual):\n'
          '行吧，卖给你了！\n'
          '(Xíng ba, mài gěi nǐ le! - Baiklah, saya jual kepadamu!)\n\n'
          'Kosakata Terkait:\n'
          '• 便宜 (piányi) : Murah [HSK 2]\n'
          '• 多少钱 (duōshao qián) : Berapa harga [HSK 1]';
    }

    if (lower.contains('perkenalan') ||
        lower.contains('kenalan') ||
        lower.contains('nama')) {
      return 'Berikut contoh percakapan perkenalan diri (自我介绍 - Zìwǒ jièshào):\n\n'
          'A: 你好！你叫什么名字？\n'
          '(Nǐ hǎo! Nǐ jiào shénme míngzi? - Halo! Siapa namamu?)\n\n'
          'B: 你好！我叫大卫。我是印尼人。很高兴认识你！\n'
          '(Nǐ hǎo! Wǒ jiào Dàwèi. Wǒ shì Yìnní rén. Hěn gāoxìng rènshi nǐ! - Halo! Nama saya David. Saya orang Indonesia. Senang berkenalan denganmu!)\n\n'
          'A: 我也很高兴认识你！你是学生吗？\n'
          '(Wǒ yě hěn gāoxìng rènshi nǐ! Nǐ shì xuésheng ma? - Saya juga senang berkenalan denganmu! Apakah kamu pelajar?)\n\n'
          'B: 是的，我正在学习中文。\n'
          '(Shì de, wǒ zhèngzài xuéxí zhōngwén. - Ya, saya sedang belajar bahasa Mandarin.)';
    }

    // 5. Tips Menghafal Hanzi
    if (lower.contains('tips') &&
        (lower.contains('hanzi') ||
            lower.contains('karakter') ||
            lower.contains('menghafal'))) {
      return 'Berikut 3 tips efektif menghafal karakter Hanzi (汉字):\n\n'
          '1. Kenali Radikal (部首 - Bùshǒu): Sebagian besar Hanzi tersusun dari radikal bermakna. Contoh radikal air (氵) selalu ada pada kata yang berhubungan dengan cairan: 水 (air), 河 (sungai), 海 (laut).\n\n'
          '2. Visualisasi Cerita: Hubungkan bentuk goresan dengan gambar nyata. Contoh: 木 (pohon), 林 (hutan kecil / 2 pohon), 森 (hutan rimba / 3 pohon).\n\n'
          '3. Latih Urutan Goresan (笔画): Latihlah menulis di fitur Hanzi Stroke aplikasi ini agar memori motorik tanganmu terbentuk kuat!';
    }

    // 6. Struktur Kalimat Dasar Mandarin
    if (lower.contains('struktur kalimat') ||
        lower.contains('tata bahasa dasar') ||
        lower.contains('urutan kalimat')) {
      return 'Struktur dasar kalimat bahasa Mandarin mengikuti pola:\n\n'
          'Subjek + Waktu + Tempat + Kata Kerja + Objek\n\n'
          'Contoh kalimat:\n'
          '我 今天 在家 学习 中文。\n'
          '(Wǒ jīntiān zàijiā xuéxí zhōngwén.)\n'
          '• Subjek: 我 (Saya)\n'
          '• Waktu: 今天 (Hari ini)\n'
          '• Tempat: 在家 (Di rumah)\n'
          '• Kata Kerja: 学习 (Belajar)\n'
          '• Objek: 中文 (Bahasa Mandarin)\n\n'
          'Ingat: Penanda waktu dan tempat selalu diletakkan SEBELUM kata kerja, berbeda dengan bahasa Indonesia!';
    }

    // 7. Tata Bahasa Mandarin Umum
    if (lower.contains('的') && lower.contains('得') && lower.contains('地')) {
      return 'Perbedaan penggunaan partikel 的, 得, dan 地 (de):\n\n'
          '• 的 (de): Menghubungkan kepemilikan atau kata sifat dengan kata benda. Pola: Sifat/Pemilik + 的 + Benda.\n'
          'Contoh: 我的书 (wǒ de shū - buku saya), 漂亮的衣服 (piàoliang de yīfu - baju yang cantik).\n\n'
          '• 得 (de): Menjelaskan derajat atau hasil setelah kata kerja. Pola: Kerja + 得 + Derajat.\n'
          'Contoh: 跑得很快 (pǎo de hěn kuài - berlari dengan sangat cepat), 学得很好 (xué de hěn hǎo - belajar dengan sangat baik).\n\n'
          '• 地 (de): Mengubah kata sifat menjadi kata keterangan sebelum kata kerja. Pola: Sifat + 地 + Kerja.\n'
          'Contoh: 慢慢地走 (mànmàn de zǒu - berjalan dengan perlahan), 高兴地笑 (gāoxìng de xiào - tertawa dengan gembira).';
    }

    if (lower.contains('不') && lower.contains('没')) {
      return 'Perbedaan penggunaan 不 (bù) dan 没 (méi):\n\n'
          '• 不 (bù): Digunakan untuk menyangkal masa kini, masa depan, kebiasaan, atau keinginan hati.\n'
          'Contoh: 我不吃肉 (wǒ bù chī ròu - saya tidak makan daging / kebiasaan), 我明天不去 (wǒ míngtiān bù qù - saya besok tidak pergi).\n\n'
          '• 没 (méi): Digunakan untuk menyangkal kejadian yang sudah lewat (masa lalu) atau peristiwa yang belum terjadi, serta menyangkal kepemilikan (没有).\n'
          'Contoh: 我没去 (wǒ méi qù - saya tidak/belum pergi), 我没有钱 (wǒ méiyǒu qián - saya tidak punya uang).\n\n'
          'Catatan: Kata 有 (yǒu/punya) HANYA bisa disangkal dengan 没, tidak boleh menggunakan 不有!';
    }

    if (lower.contains('想') && lower.contains('要')) {
      return 'Perbedaan kata 想 (xiǎng) dan 要 (yào):\n\n'
          '• 想 (xiǎng): Berarti "ingin" atau "berpikir". Keinginan ini berada dalam angan-angan/niat di dalam hati yang belum tentu langsung diwujudkan.\n'
          'Contoh: 我想去中国 (wǒ xiǎng qù Zhōngguó - saya ingin pergi ke Tiongkok suatu saat nanti).\n\n'
          '• 要 (yào): Berarti "mau" atau "harus". Menunjukkan keputusan kuat, rencana pasti, atau kebutuhan mendesak yang segera dilakukan.\n'
          'Contoh: 我要买这张票 (wǒ yào mǎi zhè zhāng piào - saya mau beli tiket ini sekarang juga).';
    }

    if (lower.contains('能') || lower.contains('会') || lower.contains('可以')) {
      return 'Perbedaan 会 (huì), 能 (néng), dan 可以 (kěyǐ):\n\n'
          '• 会 (huì): Menunjukkan kemampuan yang didapat melalui proses belajar atau latihan.\n'
          'Contoh: 我会说中文 (wǒ huì shuō zhōngwén - saya bisa bicara Mandarin karena pernah belajar).\n\n'
          '• 能 (néng): Menunjukkan kapasitas fisik atau kondisi situasi yang memungkinkan.\n'
          'Contoh: 我今天能来 (wǒ jīntiān néng lái - saya hari ini bisa datang / punya waktu luang), 我能喝十杯水 (saya sanggup minum 10 gelas).\n\n'
          '• 可以 (kěyǐ): Menunjukkan izin atau kebolehan.\n'
          'Contoh: 我可以坐这里吗？(Wǒ kěyǐ zuò zhèlǐ ma? - Bolehkah saya duduk di sini?).';
    }

    if (lower.contains('nada 2') ||
        lower.contains('nada 3') ||
        lower.contains('membedakan nada')) {
      return 'Cara membedakan Nada 2 (阳平 - Yángpíng) dan Nada 3 (上声 - Shǎngshēng):\n\n'
          '• Nada 2 (/): Nada naik (dari sedang ke tinggi, seperti bertanya "Hah? / Apa?").\n'
          'Contoh: má (麻 - mati rasa), láo (劳 - bekerja keras).\n\n'
          '• Nada 3 (v): Nada turun lalu naik (suara diturunkan ke titik terendah tenggorokan baru sedikit melenting naik).\n'
          'Contoh: mǎ (马 - kuda), hǎo (好 - baik).\n\n'
          'Tips Praktis: Di percakapan cepat, Nada 3 sering hanya diucapkan turunnya saja (separuh nada 3). Kamu bisa melatih nada ini di menu Latihan Pelafalan Suara!';
    }

    // 8. Pencarian Kosakata Spesifik dari Database (Dijelaskan Makna dan Penggunaannya Dulu)
    try {
      final vocabList = VocabularyService.instance.allVocabulary;
      if (vocabList.isNotEmpty) {
        final rawWords = prompt
            .replaceAll(RegExp(r'[^a-zA-Z0-9]+'), ' ')
            .split(' ')
            .map((w) => w.trim().toLowerCase())
            .where(
              (w) =>
                  w.length > 1 &&
                  ![
                    'apa',
                    'arti',
                    'adalah',
                    'dari',
                    'yang',
                    'ini',
                    'itu',
                    'kosakata',
                    'kata',
                    'bagaimana',
                    'tolong',
                  ].contains(w),
            )
            .toList();

        final matches = vocabList
            .where((item) {
              final hanziMatch = prompt.contains(item.hanzi);
              final pinyinMatch = rawWords.any(
                (w) => item.pinyin.toLowerCase() == w,
              );
              final artiMatch = rawWords.any(
                (w) => item.artiIndonesia.toLowerCase().contains(w),
              );
              return hanziMatch || pinyinMatch || artiMatch;
            })
            .take(3)
            .toList();

        if (matches.isNotEmpty) {
          final buffer = StringBuffer(
            'Berikut penjelasan makna dan kosakata terkait:\n\n',
          );
          for (final item in matches) {
            buffer.writeln(
              '• ${item.hanzi} (${item.pinyin}) artinya "${item.artiIndonesia}" [Tingkat HSK ${item.hskLevel}].',
            );
            if (item.contohKalimat.isNotEmpty) {
              final ex = item.contohKalimat.first;
              buffer.writeln(
                '  Contoh penggunaan: ${ex.hanzi} (${ex.pinyin ?? ''})\n  Artinya: ${ex.arti}',
              );
            }
            buffer.writeln();
          }
          buffer.write(
            'Kamu bisa mempraktikkan pelafalan kata ini di menu Latihan Pelafalan Suara! 🐼',
          );
          return buffer.toString().trim();
        }
      }
    } catch (e) {
      debugPrint('[AiTutorService] Vocab lookup error: $e');
    }

    return 'LingLing (玲玲) siap membantumu belajar bahasa Mandarin! 🐼\n\nSilakan tanyakan seputar tradisi & festival Tiongkok (seperti Festival Kue Bulan atau Imlek), contoh percakapan situasional, arti kosakata HSK, atau tata bahasa Mandarin.';
  }
}
