# **PRODUCT REQUIREMENTS DOCUMENT (PRD)** 

#### **Aplikasi Pembelajaran Bahasa Mandarin untuk Pemula** 

Versi 3.0 | 15 Oktober 2026 

Dokumen ini merupakan PRD terpadu yang memuat kebutuhan produk, fitur, prioritas, spesifikasi teknis, risiko, dan kriteria penerimaan dalam satu dokumen. Tidak ada bagian pembaruan terpisah. 

### **1. Ringkasan Produk (Overview)** 

Aplikasi ini adalah aplikasi mobile untuk membantu pengguna pemula belajar Bahasa Mandarin secara mandiri, terutama kosakata level HSK 1–6. Materi menggabungkan Hanzi, pinyin, arti Bahasa Indonesia, contoh penggunaan, audio pelafalan, latihan pengenalan nada, dan aktivitas interaktif. 

Alur belajar utama adalah Materi → Kuis Tebak Arti dan Pinyin → Latihan Pelafalan. Setelah menyelesaikan materi, pengguna dapat berlatih mengucapkan kosakata melalui mikrofon. Sistem menganalisis hasil pengenalan ujaran dan kontur nada untuk memberikan umpan balik pembelajaran. 

Fitur pendukung meliputi Kamus Mandarin, Hanzi Matching, Hanzi Stroke Challenge, permainan berbasis sensor Tilt to Answer dan Mandarin Catcher, Mandarin Direction Explorer yang menggabungkan LBS dan kompas, konversi mata uang dan waktu, AI Tutor, progres, notifikasi, serta sistem reward koin. 

###### **1.1 Tujuan Produk** 

- Menyediakan pembelajaran kosakata Mandarin yang terstruktur untuk pemula. 

- Membantu pengguna memahami hubungan Hanzi, pinyin, arti, pelafalan, dan nada. 

- Memberikan umpan balik pelafalan yang membantu pengguna memperbaiki pengucapan. 

- Meningkatkan keterlibatan melalui mini game, sensor perangkat, dan reward. 

- Menghubungkan kosakata dengan lingkungan nyata melalui LBS dan kompas. 

- Mendukung belajar mandiri dengan kamus, AI Tutor, progres, dan pengingat. 

###### **1.2 Ringkasan Fitur** 

|**Fitur**|**Deskripsi**|
|---|---|
|Materi Mandarin|Materi HSK 1–6 dengan Hanzi, pinyin bertanda nada,<br>arti, contoh, dan audio.|
|Kuis utama|Kuis tebakartidanpinyinsetelah materi.|
|Latihan Pelafalan|Rekam suara pengguna, deteksi ujaran dan evaluasi<br>kontur nada dengan umpan balik.|
|Kamus Mandarin|Pencarian berdasarkan Hanzi, pinyin, atau arti Bahasa<br>Indonesia.|
|Hanzi Matching|Mini game memasangkan Hanzi dengan arti atau<br>pinyin.|
|Hanzi Stroke Challenge|Latihan menulis Hanzi mengikuti garis panduan dan<br>urutan goresan.|
|Tilt to Answer & Mandarin Catcher|Mini game yang memanfaatkan sensor gerak perangkat.|
|Mandarin Direction Explorer|Peta tempat sekitar, arah relatif, kompas, serta kosakata<br>Mandarin tempat dan mata angin; tanpa kuis.|



|Konversi|Konversi mata uang dan waktu, termasuk China<br>Standard Time (CST).|
|---|---|
|AI Tutor|Bantuan belajar berbasis LLM untuk penjelasan<br>kosakata dan contoh sederhana.|
|Reward|Koin dari hasil fitur utama dan bonus streak Hanzi<br>Matching; koin dipakai untuk bantuan pada mini<br>game/kuis, bukan membeli avatar.|
|Progres & notifikasi|Menyimpan kemajuan dan mengingatkan pengguna<br>untukbelajar.|



### **2. Latar Belakang dan Masalah** 

###### **2.1 Latar Belakang** 

Pembelajar pemula perlu mempelajari karakter Hanzi, pinyin, arti, serta empat nada utama dan nada netral dalam Bahasa Mandarin. Materi statis saja belum cukup untuk melatih ingatan, tulisan, dan pelafalan. Karena itu, aplikasi menggabungkan materi bertahap, latihan suara, mini game, kamus, dan pengalaman kontekstual. 

###### **2.2 Rumusan Masalah** 

- Bagaimana menyajikan materi kosakata Mandarin secara mudah dipahami dan berurutan? 

- Bagaimana membantu pengguna melatih arti, pinyin, tulisan Hanzi, dan nada pelafalan? 

- Bagaimana menyediakan umpan balik suara tanpa menjanjikan akurasi seperti penilai manusia? 

- Bagaimana membuat mini game dan reward mendorong latihan tanpa mengganggu alur utama? 

- Bagaimana menghubungkan kosakata tempat dan arah dengan lingkungan nyata? 

- Bagaimana menyediakan konversi, AI Tutor, serta pemantauan progres untuk belajar mandiri? 

###### **2.3 Manfaat** 

Pengguna memperoleh sarana belajar mandiri yang menggabungkan materi, latihan, umpan balik, permainan, dan konteks sehari-hari. Pengembang dapat menerapkan pemrograman mobile, basis data, API, sensor, pemrosesan suara, LLM, notifikasi, dan mekanisme pencatatan reward. 

### **3. Tujuan dan Metrik Keberhasilan** 

|**Tujuan**|**Metrik yang diukur**|
|---|---|
|Keterlibatan belajar|Jumlah materi selesai per pengguna dan frekuensi sesi<br>belajar.|
|Pemahaman kosakata|Persentase jawaban benar pada kuis tebak arti dan<br>pinyin.|
|Latihan pelafalan|Persentase rekaman yang berhasil diproses serta jumlah<br>latihan yang diselesaikan.|
|Kegunaan fitur|Jumlah penggunaan kamus, mini game, AI Tutor, dan<br>Direction Explorer.|
|Konsistensi reward|Jumlah streak Hanzi Matching yang tercatat dan<br>transaksi koin yang berhasil.|
|Keandalan aplikasi|Persentase alur utama yang selesai tanpa crash atau<br>kehilanganprogres.|



Target angka ditetapkan setelah uji coba awal, karena baseline performa dan jumlah pengguna belum tersedia. 

### **4. Target Pengguna (User Persona)** 

Pengguna utama adalah pemula Bahasa Mandarin, seperti pelajar atau mahasiswa yang ingin belajar kosakata HSK 1–6 secara mandiri. Pengguna membutuhkan penjelasan berbahasa Indonesia, latihan singkat, audio yang mudah diputar ulang, serta umpan balik yang sederhana dan tidak mengintimidasi. 

### **5. Ruang Lingkup (Scope)** 

###### **5.1 In Scope** 

- Registrasi, login, dan penyimpanan profil/progres. 

- Materi kosakata HSK 1–6 berisi Hanzi, pinyin dengan tanda nada, arti, contoh kalimat, dan audio. 

- Kuis utama tebak arti dan pinyin setelah materi. 

- Latihan pelafalan menggunakan mikrofon dengan pengenalan ujaran dan analisis nada. 

- Kamus Mandarin dengan pencarian Hanzi, pinyin, dan arti. 

- Hanzi Matching dan Hanzi Stroke Challenge. 

- Tilt to Answer berbasis sensor kemiringan/gyroscope dan Mandarin Catcher berbasis accelerometer. 

- Mandarin Direction Explorer dengan peta, lokasi sekitar, arah tempat, kompas, serta kosakata tempat dan mata angin; fitur ini tidak memiliki kuis. 

- Konversi mata uang IDR, CNY, dan USD menggunakan sumber kurs yang ditentukan tim. 

- Konversi waktu WIB, WITA, WIT, London, dan China Standard Time (CST, UTC+8). 

- AI Tutor berbasis LLM untuk penjelasan kosakata dan contoh kalimat sederhana. 

- Progres, notifikasi pengingat, dan umpan balik pengguna. 

- Reward koin dari fitur utama dan bonus setiap lima kemenangan Hanzi Matching berturut-turut; koin dapat digunakan untuk bantuan belajar. 

###### **5.2 Out of Scope** 

- Kelas langsung atau konsultasi terjadwal dengan tutor manusia. 

- Percakapan sosial real-time antar pengguna. 

- Sertifikasi resmi atau penilaian setara ujian resmi Bahasa Mandarin. 

- Jaminan penilaian pelafalan setara ahli fonetik atau penutur asli. 

- Evaluasi tulisan otomatis untuk semua karakter Hanzi tanpa batas; evaluasi dibatasi pada karakter yang memiliki data panduan dan metode yang disiapkan. 

- Transaksi penukaran mata uang, pembelian tiket, dan reservasi hotel. 

- Blockchain publik atau aset kripto. Jika kebutuhan tugas meminta blockchain, implementasi dibatasi pada pencatatan hash/integritas data yang tidak memuat informasi pribadi. 

- Pembelian avatar menggunakan koin atau toko avatar. 

### **6. Kebutuhan Fungsional** 

|**ID**|**Persyaratan**|
|---|---|
|FR-01 Akun|Sistem menyediakan registrasi, login, logout, dan<br>penyimpanan progres sesuai akun pengguna.|
|FR-02 Materi|Sistem menampilkan kosakata HSK 1–6 berupa Hanzi,<br>pinyin bertanda nada, arti, contoh penggunaan, dan<br>audio pelafalan.|
|FR-03 Kuis utama|Setelah materi, sistem menyediakan kuis tebak arti dan<br>pinyin serta menyimpan hasilnya.|
|FR-04 Latihan pelafalan|Setelah materi/kuis pada alur utama, pengguna dapat<br>merekam suara melalui mikrofon. Sistem memproses<br>rekaman dan menampilkan hasil pengenalan ujaran<br>serta umpan balik nada jika analisis tersedia.|
|FR-05 Analisis nada|Sistem membandingkan kontur nada rekaman dengan<br>contoh referensi untuk kosakata yang sedang dilatih dan<br>menampilkan indikasi perbaikan. Sistem menampilkan<br>pesan tidak dapat dinilai bila audio tidak jelas atau<br>analisis gagal.|
|FR-06 Kamus|Sistem mencari kosakata melalui Hanzi, pinyin, atau arti<br>Bahasa Indonesia.|
|FR-07 Hanzi Matching|Sistem menyediakan permainan mencocokkan Hanzi<br>dengan arti atau pinyin dan mencatat kemenangan<br>berturut-turut.|
|FR-08 Stroke Challenge|Sistem menampilkan panduan urutan goresan dan area<br>latihan menulis Hanzi pada layar.|
|FR-09 Tilt to Answer|Sistem membaca kemiringan perangkat untuk memilih<br>opsi sesuai aturan permainan.|
|FR-10 Mandarin Catcher|Sistem menggunakan accelerometer untuk<br>menggerakkan objek permainan dan menghitung objek<br>kosakata target yang tertangkap.|
|FR-11 Direction Explorer|Sistem menampilkan lokasi pengguna dan tempat<br>sekitar pada peta, detail tempat, jarak, arah relatif,<br>kompas, serta kosakata Hanzi/pinyin/arti terkait. Fitur<br>tidak menampilkan kuis.|
|FR-12 Konversi mata uang|Sistem mengonversi IDR, CNY, dan USD<br>menggunakan kurs dari sumber yang ditetapkan dan<br>menampilkan waktu pembaruan data.|
|FR-13 Konversi waktu|Sistem mengonversi waktu antara WIB, WITA, WIT,<br>London, dan China Standard Time (CST, UTC+8),<br>dengan penanganan daylight saving untuk London.|
|FR-14 AI Tutor|Sistem menerima pertanyaan pembelajaran dan<br>memberikan penjelasan sederhana, contoh, atau<br>klarifikasi kosakata Mandarin.|
|FR-15 Progres|Sistem mencatat materi selesai, skor, latihan pelafalan,<br>dan aktivitas mini game.|
|FR-16 Notifikasi|<br>Sistem mengirim pengingat belajar yang dapat diatur<br>atau dimatikan pengguna.|
|FR-17 Reward dari fitur utama|Sistem memberikan koin berdasarkan skor kuis utama<br>danpenyelesaian latihanpelafalansesuai aturan reward.|



|FR-18 Reward streak Hanzi Matching|Sistem memberikan bonus koin setiap kali pengguna<br>mencapai lima kemenangan Hanzi Matching<br>berturut-turut. Streak kembali ke nol saat<br>kalah/percobaan gagal sesuai aturan permainan. Bonus<br>untuk streak yang sama hanya diberikan sekali.|
|---|---|
|FR-19 Penukaran bantuan|Sistem memungkinkan pengguna menukar koin untuk<br>bantuan pada Hanzi Matching dan Kuis Tebak Arti;<br>sistem memeriksa saldo, meminta konfirmasi,<br>mengurangi saldo hanya ketika bantuan berhasil<br>diberikan, dan menolak jika saldo kurang.|
|FR-20 Riwayat koin|Sistem menampilkan perolehan dan penggunaan koin<br>serta mencegah transaksi ganda. Tidak ada penukaran<br>koin untuk avatar.|
|FR-21 Umpan balik|Sistem menyediakan kanal umpan balik pengguna<br>terkait materi dan fungsi aplikasi.|



###### **6.1 Aturan Reward** 

|**Aktivitas**|**Koin**|
|---|---|
|Skor kuis utama 90–100|15 koin|
|Skor kuis utama 70–89|10 koin|
|Skor kuis utama 50–69|5 koin|
|Menyelesaikan latihanpelafalan|5koin|
|Setiap 5 kemenangan Hanzi Matching berturut-turut|Bonus 25 koin (satu kali per pencapaian streak)|
|Bantuan Hanzi Matching: menghilangkan beberapa<br>pasangan salah|30 koin|
|Bantuan Kuis Tebak Arti: petunjuk makna/konteks<br>tanpa jawaban|20 koin|



Nilai bonus streak 25 koin merupakan nilai awal yang diusulkan untuk PRD dan dapat disesuaikan sebelum implementasi. Koin dari skor hanya diberikan sekali untuk satu hasil/attempt yang sah agar pengulangan tidak dapat dieksploitasi. Sistem XP tidak digunakan; hanya koin yang dapat diperoleh dan dibelanjakan.

###### **6.2 Aturan Mandarin Direction Explorer** 

1. Pengguna memberi izin lokasi; jika ditolak, sistem tetap menyediakan daftar kosakata mata angin tanpa peta berbasis lokasi. 

2. Beranda fitur menampilkan peta dan tempat sekitar dengan kategori seperti kampus, kafe, restoran, taman, atau halte. 

3. Ketika pengguna memilih tempat, sistem menampilkan nama, kategori, jarak, arah relatif dari pengguna, dan tombol membuka rute/peta. 

4. Tampilan kompas menunjukkan orientasi perangkat dan arah tujuan. Sistem perlu menggunakan koordinat pengguna dan tujuan untuk menghitung arah relatif; kompas saja tidak menentukan arah tujuan. 

5. Panel kosakata menampilkan Hanzi, pinyin, arti Indonesia, dan audio jika tersedia. Contoh: 东 (dōng, timur), 西 (xī, barat), 南 (nán, selatan), 北 (běi, utara), 咖啡馆 (kāfēiguǎn, kafe). 

6. Fitur hanya untuk eksplorasi dan pembelajaran kontekstual, tanpa kuis atau mini game tambahan. 

### **7. Kebutuhan Non-Fungsional** 

- Usability: antarmuka sederhana, konsisten, dan mudah digunakan oleh pemula. 

- Performance: halaman materi dan kamus harus tetap responsif; proses AI/suara menampilkan status pemrosesan dan penanganan kegagalan. 

- Reliability: progres dan saldo koin tidak hilang atau berubah ganda saat aplikasi ditutup atau jaringan terputus. 

- Privacy: mikrofon dan lokasi hanya digunakan setelah izin diberikan; pengguna diberi penjelasan penggunaan data dan pilihan menonaktifkan izin. 

- Security: kredensial tidak disimpan dalam bentuk teks biasa; akses data pengguna dibatasi sesuai akun. 

- Accessibility: teks mudah dibaca, tombol cukup besar, dan informasi suara juga disampaikan dalam bentuk teks/visual. 

- Compatibility: aplikasi menargetkan perangkat Android yang mendukung sensor yang dibutuhkan; fitur sensor memberi fallback jika perangkat tidak mendukungnya. 

- Transparency: hasil analisis nada merupakan estimasi pembelajaran, bukan penilaian sertifikasi atau jaminan akurasi seperti ahli. 

### **8. Alur Pengguna dan Rancangan Tampilan** 

###### **8.1 Alur utama pembelajaran** 

7. Pengguna membuka aplikasi dan login. 

8. Pengguna memilih level atau topik materi. 

9. Sistem menampilkan Hanzi, pinyin bertanda nada, arti, contoh, dan audio. 

10. Pengguna menyelesaikan kuis tebak arti dan pinyin. 

11. Pengguna berlatih melafalkan kosakata dengan mikrofon. 

12. Sistem menampilkan transkripsi/pengenalan ujaran dan umpan balik kontur nada jika tersedia. 

13. Sistem menyimpan skor dan progres serta memberikan koin sesuai aturan. 

14. Pengguna melanjutkan ke materi berikutnya atau mengulang materi. 

###### **8.2 Alur fitur tambahan** 

- Kamus: masukkan Hanzi, pinyin, atau arti → lihat hasil → buka detail kosakata. 

- Hanzi Matching: mulai permainan → cocokkan pasangan → catat hasil dan streak → beri bonus tiap lima kemenangan beruntun. 

- Hanzi Stroke Challenge: pilih karakter → ikuti urutan goresan → tulis pada area latihan → lihat umpan balik. 

- Tilt to Answer/Mandarin Catcher: buka permainan → baca instruksi → izinkan sensor bila diperlukan → mainkan → simpan skor. 

- Mandarin Direction Explorer: izinkan lokasi → lihat peta dan tempat sekitar → pilih tempat → lihat jarak dan arah → gunakan kompas → pelajari kosakata tempat/mata angin. 

- Konversi: pilih jenis konversi → masukkan nilai/waktu → pilih zona atau mata uang → lihat hasil dan keterangan sumber data. 

- AI Tutor: masukkan pertanyaan → sistem mengirim konteks pembelajaran yang relevan ke LLM → tampilkan jawaban dan pesan batasan bila jawaban tidak pasti. 

Wireframe minimum: Login/Register, Beranda, Daftar Materi, Detail Materi, Kuis Utama, Latihan Pelafalan dan Nada, Kamus, Hanzi Matching, Hanzi Stroke Challenge, Tilt to Answer, Mandarin Catcher, Mandarin Direction Explorer (peta, detail tempat, kompas, kosakata), Konversi, AI Tutor, Progres, Reward/Riwayat Koin, Pengaturan dan Umpan Balik. 

### **9. Spesifikasi Teknis** 

|**Komponen**|**Pilihan awal**|**Catatan implementasi**|
|---|---|---|
|Mobile app|Flutter / Dart|Satu codebase Android; sesuaikan<br>dengan teknologi yang ditetapkan<br>tim.|
|Database|SQLite lokal dan/atau<br>Firebase/Supabase|Menyimpan akun/progres, kosakata,<br>skor, streak, dan ledger koin. Pilih<br>satu backend utama untuk<br>menghindariduplikasi.|
|Pengenalan suara Mandarin|FunASR dengan model<br>Paraformer-zh atau model Mandarin<br>yang sesuai|FunASR menyediakan model ASR<br>Mandarin; periksa lisensi model<br>checkpoint secara terpisah sebelum<br>distribusi.|
|Pengenalan nada|Analisis kontur pitch/F0 dari audio,<br>misalnya menggunakan librosa atau<br>Praat/parselmouth, dibandingkan<br>dengan referensi kata|ASR biasa terutama mengenali teks<br>dan tidak otomatis membuktikan<br>nada diucapkan benar. Nada<br>memerlukan pipeline evaluasi<br>akustik yang diuji dengan sampel<br>suara. Beri umpan balik indikatif,<br>bukan klaim akurasi ahli.|
|AI/LLM|Qwen2.5 Instruct melalui Ollama<br>sebagai opsi open-weight lokal;<br>alternatif API gratis sesuai kuota<br>dan syarat penyedia|Open-weight lokal menghindari<br>biaya per panggilan API tetapi<br>membutuhkan server/perangkat<br>yang cukup kuat. Periksa lisensi<br>model, kebutuhan RAM, dan batas<br>penggunaan. API gratis dapat<br>berubah kuota/kebijakan.|
|Peta dan tempat|OpenStreetMap tiles dan OpenStreetMap<br>Overpass API untuk POI|Tampilkan atribusi OpenStreetMap,<br>batasi pencarian POI di sekitar lokasi,<br>tampilkan nama tempat yang tersedia<br>beserta kosakata Mandarin (Hanzi,<br>pinyin, dan arti Indonesia). Hormati<br>kebijakan tile/API dan jangan<br>mengarang lokasi/tempat saat data<br>atau izin lokasi tidak tersedia.|
|Lokasi|Geolocator/location plugin|Minta izin saat fitur digunakan dan<br>sediakan fallback bila izin ditolak.|
|Kompas|Sensor magnetometer melalui plugin<br>sensor/orientation|Kalibrasi perangkat dan tampilkan<br>pesan jika sensor tidak tersedia atau<br>akurasinya buruk.|



|Sensor mini game|Accelerometer dan gyroscope<br>melalui plugin Flutter sensors_plus<br>atau setara|Uji pada perangkat fisik karena<br>simulator mungkin tidak<br>merepresentasikan sensor dengan<br>baik.|
|---|---|---|
|Konversi mata uang|API kurs dengan timestamp atau<br>data kurs yang diperbarui|Jangan menampilkan kurs sebagai<br>real-time jika sumber tidak<br>menjamin pembaruan real-time.|
|Konversi waktu|Database zona waktu IANA / library<br>timezone|Gunakan zona Asia/Jakarta,<br>Asia/Makassar, Asia/Jayapura,<br>Europe/London, dan Asia/Shanghai.<br>China Standard Time adalah<br>UTC+8; London mengikuti<br>perubahan waktu musiman.|
|Notifikasi|Local notifications atau layanan<br>push|Memerlukan izin notifikasi sesuai<br>versi Android.|
|Blockchain/integritas data bila<br>diwajibkan|SHA-256 untuk hash catatan yang<br>tidak berisi data pribadi|Hash hanya membuktikan<br>konsistensi terhadap data<br>pembanding; tidak dengan<br>sendirinya membuktikan kebenaran<br>data.|



Referensi teknis awal: dokumentasi dan repositori FunASR untuk model pengenalan suara Mandarin: https://github.com/modelscope/FunASR. Model, runtime, dan lisensi checkpoint harus diverifikasi sebelum dipilih final. 

### **10. Prioritas Fitur** 

|**Prioritas**|**Fitur**|
|---|---|
|Must Have|Akun, materi HSK 1–6, kuis utama, latihan pelafalan<br>dan evaluasi nada, kamus, Hanzi Matching, Hanzi<br>Stroke Challenge, dua mini game berbasis sensor,<br>Mandarin Direction Explorer (LBS + kompas), konversi<br>mata uang, konversi waktu termasuk CST, AI<br>Tutor/LLM, progres, notifikasi, reward koin dan streak,<br>serta fitur/ketentuan lain yang diwajibkan dosen.|
|Should Have|Riwayat latihan lebih detail, pengaturan pengingat yang<br>lebih lengkap, filter kategori tempat, penyimpanan<br>kosakata favorit.|
|Could Have|Statistik penguasaan kosakata, personalisasi<br>rekomendasi materi, mode latihan tambahan.|
|Won’t Have (versi ini)|Tutor manusia langsung, interaksi sosial real-time,<br>transaksi perjalanan, sertifikasi resmi, toko/pembelian<br>avatar, dan blockchain publik.|



Seluruh persyaratan yang diwajibkan dosen diperlakukan sebagai Must Have untuk perencanaan proyek. Daftar final harus dicocokkan dengan rubrik atau instruksi dosen yang berlaku. 

**11. Asumsi, Risiko, dan Ketergantungan** 

|**Risiko/ketergantungan**|**Dampak**|**Mitigasi**|
|---|---|---|
|Pengenalan nada tidak akurat untuk<br>aksen/perangkat tertentu|Umpan balik menyesatkan|Uji dengan beragam sampel;<br>tampilkan skor indikatif; sediakan|



|||contoh audio dan pesan ketika tidak<br>yakin.|
|---|---|---|
|Model LLM berat atau API gratis<br>mencapai batas|Tutor lambat/tidak tersedia|Batasi panjang prompt, tangani<br>error, siapkan jawaban materi statis<br>sebagai fallback, dan periksa<br>lisensi/kuota.|
|Izin lokasi ditolak atau GPS tidak<br>akurat|Peta tidak dapat dipersonalisasi|Sediakan tampilan kosakata mata<br>angin tanpa lokasi dan pilihan<br>mengaktifkan izin.|
|Kompas tidak tersedia atau perlu<br>kalibrasi|Arah tidak akurat|Deteksi dukungan sensor, tampilkan<br>instruksi kalibrasi, dan tetap<br>tampilkan arah pada peta.|
|API peta/kurs memiliki batas atau<br>biaya|Fitur gagal atau biaya meningkat|Periksa kuota, cache data yang<br>diizinkan, tampilkan timestamp, dan<br>pilih penyedia sesuai ketentuan.|
|Reward dieksploitasi dengan<br>mengulang hasil|Saldo koin tidak adil|Simpan ledger transaksi, ID attempt,<br>batas satu reward per hasil, dan<br>status streak yang idempoten.|
|Materi kosakata atau contoh tidak<br>tepat|Pembelajaran salah|Validasi konten dan audio sebelum<br>rilis.|
|Rubrik dosen berubah atau memiliki<br>persyaratan spesifik|Scope dan timeline bergeser|Jadikan seluruh persyaratan dosen<br>Must Have dan verifikasi terhadap<br>rubrikterbaru.|



### **12. Rencana Rilis / Timeline** 

|**Tahap**|**Aktivitas**|**Hasil**|
|---|---|---|
|Tahap 1: Analisis|Validasi rubrik dosen, konten HSK,<br>scope, dan rancangan layar.|PRD dan desain final.|
|Tahap 2: Fondasi|Setup Flutter, struktur navigasi,<br>autentikasi, dan database.|Kerangka aplikasi dan akun.|
|Tahap 3: Belajar inti|Materi, audio, kuis utama, kamus,<br>danpenyimpananprogres.|Alur belajar utama berjalan.|
|Tahap 4: Suara dan AI|Integrasi ASR, evaluasi kontur nada,<br>AI Tutor, dan penanganan error.|Latihan suara dan tutor diuji.|
|Tahap 5: Mini game dan reward|Hanzi Matching, Stroke Challenge,<br>sensor games, aturan koin dan<br>streak.|Mini game dan reward berjalan.|
|Tahap 6: LBS dan konversi|Direction Explorer, kompas,<br>konversi mata uang/waktu,<br>notifikasi.|Fitur pendukung terintegrasi.|
|Tahap 7: Pengujian|Uji fungsional, perangkat fisik, izin,<br>performa, dan acceptance criteria.|Build kandidat rilis dan laporan<br>pengujian.|



Durasi dan tanggal setiap tahap ditentukan setelah pembagian tugas kelompok dan tenggat pengumpulan dikonfirmasi. 

### **13. Kriteria Penerimaan (Acceptance Criteria)** 

- Pengguna dapat login dan membuka materi HSK 1–6 tanpa error. 

- Materi menampilkan Hanzi, pinyin bertanda nada, arti, contoh, dan audio yang sesuai. 

- Setelah materi, pengguna dapat menyelesaikan kuis tebak arti/pinyin dan melihat hasil. 

- Pengguna dapat merekam suara; sistem memproses rekaman atau memberi pesan yang jelas jika gagal. 

- Jika analisis nada aktif, sistem menampilkan perbandingan/umpan balik kontur nada dan tidak mengklaim penilaian ahli. 

- Kamus menghasilkan hasil yang relevan berdasarkan Hanzi, pinyin, atau arti. 

- Hanzi Matching dan Hanzi Stroke Challenge dapat dimainkan dan menyimpan hasil sesuai rancangan. 

- Tilt to Answer dan Mandarin Catcher menggunakan sensor yang sesuai serta memiliki fallback jika sensor tidak tersedia. 

- Mandarin Direction Explorer menampilkan peta dan tempat sekitar setelah izin diberikan, memperlihatkan detail tempat dan arah relatif, menggunakan kompas untuk orientasi perangkat, dan tidak menampilkan kuis. 

- Konversi waktu menyediakan WIB, WITA, WIT, London, dan China Standard Time (CST); konversi London mengikuti aturan waktu musiman. 

- Konversi mata uang menampilkan hasil dan waktu/sumber pembaruan kurs. 

- AI Tutor memberikan jawaban terkait pembelajaran atau pesan fallback ketika model/API tidak tersedia. 

- Reward skor diberikan sesuai tabel dan tidak berulang untuk attempt yang sama. 

- Bonus Hanzi Matching diberikan tepat pada pencapaian lima kemenangan berturut-turut dan tidak diberikan dua kali untuk streak yang sama. 

- Penukaran bantuan memeriksa saldo, meminta konfirmasi, mengurangi koin satu kali, dan tidak mengurangi saldo jika gagal/tidak cukup. 

- Tidak ada fungsi membeli avatar menggunakan koin. 

- Progres dan saldo tetap konsisten setelah aplikasi ditutup dan dibuka kembali. 

- Izin mikrofon, lokasi, sensor, dan notifikasi ditangani secara jelas dan sesuai kebutuhan. 

### **Lampiran Referensi Teknis** 

FunASR – toolkit pengenalan suara open-source dan daftar model: https://github.com/modelscope/FunASR 

Catatan implementasi: pengenalan ujaran (ASR) dan penilaian nada adalah dua tugas berbeda. Pipeline nada perlu diuji khusus pada audio Mandarin dengan label nada yang diketahui. Semua model dan layanan pihak ketiga harus diperiksa lisensi, kuota, serta kebijakan privasinya sebelum dipakai.

> Catatan: wireframe Mandarin Direction Explorer dan referensi tampilan aplikasi ada di PDF aslinya (gambar, tidak ikut dikonversi).
