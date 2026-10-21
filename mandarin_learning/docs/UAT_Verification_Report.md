# LAPORAN USER ACCEPTANCE TESTING (UAT) & VERIFIKASI KEBUTUHAN PRD
**Aplikasi Pembelajaran Bahasa Mandarin HSK 1–6 untuk Pemula**  
*Studi Kasus: Proyek Akhir Pemrograman Aplikasi Mobile (Semester 5)*  
*Disusun oleh: Serena Luna Halim (Developer A) & Lucy Katarina Naibaho (Developer B)*  
*Tanggal: 21 Oktober 2026*  

---

## 1. Ringkasan Eksekutif
Aplikasi Pembelajaran Bahasa Mandarin untuk Pemula telah selesai dikembangkan mengikuti metodologi Scrum dari **Sprint 0 sampai Sprint 7**, mencakup seluruh **21 Kebutuhan Fungsional (FR-01 s.d. FR-21)** dan **19 Product Backlog (PB-01 s.d. PB-19)** yang tercantum dalam PRD.

* **Status Analisis Statis (`flutter analyze`):** `No issues found!` (0 error, 0 warning, 0 lint issue).
* **Status Pengujian Otomatis (`flutter test`):** **40 / 40 Tests Lulus (100%)**.
* **Database Utama:** Cloud Supabase terhubung 100% dengan dataset 5.000 kosakata HSK 1–6 dan fallback aset offline lokal.

---

## 2. Matriks Verifikasi Kebutuhan Fungsional (FR-01 s.d. FR-21)

| ID | Modul | Kebutuhan Fungsional (PRD) | Implementasi Kode | Status UAT |
|---|---|---|---|:---:|
| **FR-01** | Akun | Registrasi, login, logout, dan progres tersimpan sesuai akun. Mode tamu didukung tanpa login. | `lib/services/supabase_service.dart`<br>`lib/providers/auth_provider.dart`<br>`lib/screens/auth/*` | **LULUS (Passed)** |
| **FR-02** | Materi HSK 1–6 | Menampilkan kosakata HSK 1–6: Hanzi, Pinyin bertanda nada, arti Indonesia, contoh kalimat, dan audio TTS zh-CN. | `lib/screens/lesson/lesson_path_screen.dart`<br>`lib/screens/lesson/vocabulary_detail_screen.dart`<br>`lib/services/audio_service.dart` | **LULUS (Passed)** |
| **FR-03** | Kuis Utama | Kuis tebak arti dan pinyin setelah materi; skor dan hasil tercatat di riwayat. | `lib/screens/practice/quiz_screen.dart`<br>`lib/models/quiz_attempt_model.dart` | **LULUS (Passed)** |
| **FR-04** | Latihan Pelafalan | Perekaman suara mikrofon, durasi minimal 350ms, evaluasi pengenalan suara. | `lib/screens/practice/speech_practice_screen.dart`<br>`android/app/src/main/AndroidManifest.xml` | **LULUS (Passed)** |
| **FR-05** | Analisis Nada | Perbandingan kontur nada pitch F0 dengan skala Chao 5 tingkat; umpan balik perbaikan dan penolakan audio tidak jelas. | `lib/services/tone_analysis_service.dart`<br>`test/tahap4_voice_ai_test.dart` | **LULUS (Passed)** |
| **FR-06** | Kamus | Pencarian 5.000 kosakata real-time melalui Hanzi, Pinyin, atau Arti Indonesia dengan filter level HSK & koleksi tersimpan. | `lib/screens/practice/dictionary_screen.dart` | **LULUS (Passed)** |
| **FR-07** | Hanzi Matching | Permainan mencocokkan pasangan Hanzi dengan arti/pinyin dan pencatatan kemenangan beruntun (streak). | `lib/screens/games/hanzi_matching_screen.dart` | **LULUS (Passed)** |
| **FR-08** | Stroke Challenge | Panduan urutan goresan karakter Hanzi dan kanvas layar sentuh untuk latihan menulis goresan. | `lib/screens/games/stroke_challenge_screen.dart` | **LULUS (Passed)** |
| **FR-09** | Tilt to Answer | Pembacaan sensor kemiringan (gyroscope) untuk memilih opsi kuis dengan fallback sentuh layar jika sensor tidak tersedia. | `lib/screens/games/tilt_to_answer_screen.dart` | **LULUS (Passed)** |
| **FR-10** | Mandarin Catcher | Sensor gerak accelerometer untuk menggerakkan keranjang menangkap kata target dengan tombol fallback manual (←/→). | `lib/screens/games/mandarin_catcher_screen.dart` | **LULUS (Passed)** |
| **FR-11** | Direction Explorer | Peta tempat sekitar (LBS GPS), jarak Haversine, bearing arah relatif, kompas interaktif, dan kosakata mata angin tanpa kuis. | `lib/screens/tools/direction_explorer_screen.dart` | **LULUS (Passed)** |
| **FR-12** | Konversi Mata Uang | Kalkulator konversi kurs IDR, CNY, dan USD dengan waktu pembaruan kurs, tabel pecahan populer, dan istilah Mandarin. | `lib/screens/tools/currency_converter_screen.dart` | **LULUS (Passed)** |
| **FR-13** | Konversi Waktu | Konversi 5 zona waktu: WIB, WITA, WIT, London (dengan logika British Summer Time DST), dan China Standard Time (CST/UTC+8). | `lib/screens/tools/time_converter_screen.dart` | **LULUS (Passed)** |
| **FR-14** | AI Tutor | AI Tutor interaktif (Xiao Xiong) dengan Qwen2.5 via Ollama dan fallback tanggap darurat saat jaringan offline. | `lib/screens/practice/ai_tutor_screen.dart`<br>`lib/services/ai_tutor_service.dart` | **LULUS (Passed)** |
| **FR-15** | Progres Belajar | Pemantauan materi selesai, riwayat kuis, rasio penguasaan per level HSK, dan persentase keseluruhan. | `lib/screens/progress/progress_overview_screen.dart`<br>`lib/providers/vocabulary_provider.dart` | **LULUS (Passed)** |
| **FR-16** | Notifikasi | Pengingat belajar lokal harian yang dapat diatur jamnya atau dimatikan oleh pengguna di Pengaturan. | `lib/services/notification_service.dart`<br>`lib/screens/settings/settings_screen.dart` | **LULUS (Passed)** |
| **FR-17** | Reward Fitur Utama | Pemberian koin dari kuis (15/10/5 koin) dan pelafalan (5 koin) satu kali per attempt sah. | `lib/providers/auth_provider.dart`<br>`lib/screens/practice/quiz_screen.dart` | **LULUS (Passed)** |
| **FR-18** | Reward Streak | Bonus 25 koin setiap 5 kemenangan Hanzi Matching berturut-turut (idempoten per milestone streak). | `lib/screens/games/hanzi_matching_screen.dart`<br>`test/tahap5_games_and_coins_test.dart` | **LULUS (Passed)** |
| **FR-19** | Penukaran Bantuan | Pengurangan koin untuk bantuan Hanzi Matching (30 koin) dan Kuis (20 koin) dengan validasi saldo dan dialog konfirmasi. | `lib/screens/games/hanzi_matching_screen.dart`<br>`lib/screens/practice/quiz_screen.dart` | **LULUS (Passed)** |
| **FR-20** | Riwayat Koin (Ledger) | Menampilkan mutasi transaksi koin di buku besar (`coin_ledger`) dan mencegah duplikasi transaksi ganda. | `lib/screens/coins/coin_ledger_screen.dart`<br>`lib/providers/auth_provider.dart` | **LULUS (Passed)** |
| **FR-21** | Umpan Balik | Form umpan balik dengan rating bintang 1–5, kategori masukan, dan penyimpanan ke Supabase. | `lib/screens/tools/feedback_screen.dart`<br>`lib/services/supabase_service.dart` | **LULUS (Passed)** |

---

## 3. Rincian Suite Pengujian Otomatis

1. **`test/models_and_vocab_test.dart`** (4 Tests)
   * Serialisasi `UserProfile`, `CoinTransaction`, dan `VocabularyItem`.
   * Parsing karakter Unicode Mandarin, tanda nada Pinyin, dan contoh kalimat.

2. **`test/tahap4_belajar_inti_test.dart`** (6 Tests)
   * Logika reward kuis (15/10/5 koin) dan penukaran bantuan (20 koin).
   * Algoritma pencarian kamus 3 arah (Hanzi, Pinyin, Arti).
   * Perhitungan rasio progres pembelajaran per level HSK.

3. **`test/tahap4_voice_ai_test.dart`** (9 Tests)
   * Deteksi nomor nada Mandarin dari tanda Pinyin.
   * Kurva nada ideal skala Chao 5 tingkat.
   * Penolakan audio terlalu singkat (<350ms).
   * Respon AI Tutor dengan fallback konteks tata bahasa dan percakapan.

4. **`test/tahap5_games_and_coins_test.dart`** (10 Tests)
   * Idempotensi ledger koin (pencegahan transaksi ganda via attemptId unik).
   * Bonus 25 koin kelipatan 5 streak Hanzi Matching.
   * Pemetaan kemiringan gyroscope Tilt to Answer ke 4 arah dan fallback sentuh.
   * Batas koordinat keranjang dan deteksi tabrakan Mandarin Catcher.
   * Toleransi jumlah goresan Hanzi Stroke Challenge.

5. **`test/tahap6_tools_and_context_test.dart`** (10 Tests)
   * Jarak Haversine dan konversi derajat ke 8 arah mata angin Mandarin.
   * Mode fallback daftar tempat saat GPS offline.
   * Konversi multi-mata uang (CNY, IDR, USD) dan identitas bolak-balik (*round-trip*).
   * Komparasi 5 zona waktu (WIB, WITA, WIT, London BST, CST Beijing).
   * Validasi rating umpan balik bintang 1–5.

6. **`test/integration_core_learning_flow_test.dart`** (1 Test)
   * Simulasi terpadu alur utama: Pemilihan Materi ➔ Kuis ➔ Pelafalan ➔ Reward Koin ➔ Ledger ➔ Penukaran Bantuan.

---

## 4. Kesimpulan Kesiapan Rilis
Seluruh kriteria penerimaan PRD telah terpenuhi, seluruh issue kode telah terselesaikan, dan aplikasi siap untuk dibuild menjadi APK rilis Android untuk pengumpulan proyek akhir.
