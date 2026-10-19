## **Functional Requirement, Product Backlog & Product Backlog Item** 

Studi Kasus: Aplikasi Pembelajaran Mandarin untuk Pemula · Scrum Framework 

##### **1. Pendahuluan** 

###### **1.1 Latar Belakang** 

Aplikasi Pembelajaran Mandarin untuk Pemula adalah aplikasi mobile (Android) yang membantu pengguna belajar kosakata HSK 1–6 secara mandiri. Alur utamanya Materi → Kuis Tebak Arti dan Pinyin → Latihan Pelafalan, didukung kamus, mini game, sensor perangkat, LBS dan kompas, konversi mata uang dan waktu, AI Tutor, progres, notifikasi, serta reward koin. Pengembangan memakai Scrum: kebutuhan fungsional dari PRD versi 3.0 diturunkan menjadi Product Backlog, lalu dirinci menjadi Product Backlog Item (PBI). 

###### **1.2 Tujuan Dokumen** 

Dokumen ini mendokumentasikan kebutuhan fungsional, menyusun Product Backlog berdasarkan prioritas, dan merinci setiap backlog menjadi PBI yang siap dikerjakan dalam tiap sprint oleh dua orang anggota tim. 

###### **1.3 Ruang Lingkup Sistem** 

Sistem mencakup 19 modul (PB-01 sampai PB-19): Akun, Materi HSK 1–6, Kuis Utama, Kamus, Progres, Notifikasi, Latihan Pelafalan, Analisis Nada, AI Tutor, Hanzi Matching, Hanzi Stroke Challenge, Reward Koin, Tilt to Answer, Mandarin Catcher, Mandarin Direction Explorer, Konversi Mata Uang, Konversi Waktu, Umpan Balik dan Pengaturan, serta Pengujian dan Rilis. Di luar ruang lingkup: tutor manusia langsung, interaksi sosial real-time, sertifikasi resmi, transaksi perjalanan, toko avatar, dan blockchain publik. 

###### **1.4 Stakeholder dan Tim** 

|Peran|Nama|Tanggung jawab|
|---|---|---|
|Pengguna|Pemula Bahasa Mandarin|Belajar kosakata HSK 1–6 secara<br>mandiri|
|Product Owner|[isi nama dosen/PO]|Review dan persetujuan hasil<br>sprint|
|Developer A|Serena Luna Halim|UI Flutter, mini game, sensor,<br>peta dan kompas|
|Developer B|Lucy Katarina Naibaho|Database, backend, ASR dan<br>analisis nada, AI Tutor, logika<br>reward|



###### **1.5 Jadwal dan Asumsi** 

Pekerjaan dibagi menjadi 7 sprint berdurasi 1 minggu, dimulai Senin 19 Oktober 2026 dan berakhir Minggu 6 Desember 2026. Tanggal 15–18 Oktober dipakai untuk persiapan (Sprint 0). Kapasitas rata-rata sekitar 18 Story Point per sprint untuk dua orang; Sprint 7 sengaja lebih ringan sebagai ruang cadangan. 

Asumsi teknologi (dapat diganti sesuai keputusan tim): Flutter/Dart, Supabase sebagai backend utama, FunASR Paraformer-zh untuk pengenalan ujaran, librosa/parselmouth untuk kontur nada, Qwen2.5 Instruct via Ollama untuk AI Tutor, serta Google Maps atau OpenStreetMap untuk peta. 

##### **2. Functional Requirements (Kebutuhan Fungsional)** 

Aplikasi memiliki 21 kebutuhan fungsional yang diambil langsung dari PRD versi 3.0. Setiap kebutuhan punya ID unik dan menjadi dasar penyusunan Product Backlog. 

|ID|Modul|Deskripsi Kebutuhan Fungsional|
|---|---|---|
|FR-01|Akun|Pengguna melakukan registrasi,<br>login, logout, dan progres<br>tersimpan sesuai akun.|
|FR-02|Materi|Sistem menampilkan kosakata<br>HSK 1–6: Hanzi, pinyin bertanda<br>nada, arti, contoh penggunaan,<br>dan audio pelafalan.|
|FR-03|Kuis Utama|Setelah materi, pengguna<br>mengerjakan kuis tebak arti dan<br>pinyin; hasilnya disimpan.|
|FR-04|Latihan Pelafalan|Pengguna merekam suara lewat<br>mikrofon; sistem menampilkan<br>hasil pengenalan ujaran dan<br>umpan balik nada bila analisis<br>tersedia.|
|FR-05|Analisis Nada|Sistem membandingkan kontur<br>nada rekaman dengan referensi<br>dan menampilkan indikasi<br>perbaikan, atau pesan tidak<br>dapat dinilai bila audio tidak<br>jelas.|
|FR-06|Kamus|Pengguna mencari kosakata<br>berdasarkan Hanzi, pinyin, atau<br>arti Bahasa Indonesia.|
|FR-07|Hanzi Matching|Pengguna mencocokkan Hanzi<br>dengan arti atau pinyin; sistem<br>mencatat kemenangan<br>berturut-turut.|
|FR-08|Stroke Challenge|Sistem menampilkan panduan<br>urutan goresan dan area latihan<br>menulis Hanzi.|



|ID|Modul|Deskripsi Kebutuhan Fungsional|
|---|---|---|
|FR-09|Tilt to Answer|Sistem membaca kemiringan<br>perangkat untuk memilih opsi<br>jawaban.|
|FR-10|Mandarin Catcher|Sistem memakai accelerometer<br>untuk menggerakkan objek dan<br>menghitung kosakata target<br>yang tertangkap.|
|FR-11|Direction Explorer|Sistem menampilkan lokasi dan<br>tempat sekitar di peta, jarak,<br>arah relatif, kompas, serta<br>kosakata Hanzi/pinyin/arti<br>terkait, tanpa kuis.|
|FR-12|Konversi Mata Uang|Sistem mengonversi IDR, CNY,<br>dan USD dengan waktu<br>pembaruan kurs.|
|FR-13|Konversi Waktu|Sistem mengonversi WIB, WITA,<br>WIT, London (dengan daylight<br>saving), dan China Standard<br>Time (UTC+8).|
|FR-14|AI Tutor|Sistem menjawab pertanyaan<br>pembelajaran dengan<br>penjelasan sederhana dan<br>contoh kosakata.|
|FR-15|Progres|Sistem mencatat materi selesai,<br>skor, latihan pelafalan, dan<br>aktivitas mini game.|
|FR-16|Notifikasi|Sistem mengirim pengingat<br>belajar yang dapat diatur atau<br>dimatikan pengguna.|
|FR-17|Reward Fitur Utama|Sistem memberi koin dari skor<br>kuis (15/10/5) dan penyelesaian<br>latihan pelafalan (5), satu kali<br>per attempt sah.|
|FR-18|Reward Streak|Sistem memberi bonus 25 koin<br>setiap 5 kemenangan Hanzi<br>Matching berturut-turut, satu<br>kali per streak.|
|FR-19|Penukaran Bantuan|Pengguna menukar koin untuk<br>bantuan Hanzi Matching (30)|



|ID|Modul|Deskripsi Kebutuhan Fungsional|
|---|---|---|
|||dan Kuis Tebak Arti (20) dengan<br>cek saldo dan konfirmasi.|
|FR-20|Riwayat Koin|Sistem menampilkan perolehan<br>dan penggunaan koin serta<br>mencegah transaksi ganda.|
|FR-21|Umpan Balik|Sistem menyediakan kanal<br>umpan balik pengguna terkait<br>materi dan fungsi aplikasi.|



##### **3. Product Backlog** 

###### **3.1 Prinsip Penyusunan** 

Product Backlog berisi 19 item (total 129 Story Point) dalam format User Story "Sebagai [peran], saya ingin [fitur] agar [manfaat]". Estimasi memakai skala Fibonacci (1, 2, 3, 5, 8, 13, 21). Berbeda dari contoh sistem pengawasan (1 Sprint = 1 Product Backlog), di sini 1 Sprint memuat 2–4 Product Backlog karena waktu hanya 7 minggu untuk 21 kebutuhan fungsional dan 2 orang. Urutan sprint mengikuti alur belajar: fondasi dan akun, belajar inti, suara dan AI, mini game, reward, fitur kontekstual, lalu pengujian. 

###### **3.2 Daftar Product Backlog** 

|ID|Modul|User Story|Prioritas|SP|FR Terkait|
|---|---|---|---|---|---|
|PB-01|Akun|Sebagai<br>pengguna,<br>saya ingin<br>registrasi,<br>login, dan<br>logout agar<br>progres belajar<br>saya tersimpan<br>di akun saya.|Tinggi|8|FR-01|
|PB-02|Materi HSK<br>1–6|Sebagai<br>pengguna,<br>saya ingin<br>melihat Hanzi,<br>pinyin<br>bertanda<br>nada, arti,<br>contoh, dan<br>audio agar<br>saya<br>memahami<br>kosakata.|Tinggi|8|FR-02|



|ID<br>PB-03|Modul<br>Kuis Utama|User Story<br>Sebagai<br>pengguna,<br>saya ingin<br>mengerjakan<br>kuis tebak arti<br>dan pinyin<br>agar saya tahu<br>tingkat<br>pemahaman<br>saya.|Prioritas<br>Tinggi|SP<br>5|FR Terkait<br>FR-03|
|---|---|---|---|---|---|
|PB-04|Kamus|Sebagai<br>pengguna,<br>saya ingin<br>mencari<br>kosakata lewat<br>Hanzi, pinyin,<br>atau arti agar<br>saya bisa<br>mengecek kata<br>dengan cepat.|Tinggi|5|FR-06|
|PB-05|Progres|Sebagai<br>pengguna,<br>saya ingin<br>melihat<br>materi, skor,<br>dan aktivitas<br>saya agar saya<br>bisa<br>memantau<br>kemajuan.|Tinggi|5|FR-15|
|PB-06|Notifikasi|Sebagai<br>pengguna,<br>saya ingin<br>pengingat<br>belajar yang<br>bisa diatur<br>agar saya<br>belajar secara<br>konsisten.|Tinggi|3|FR-16|
|PB-07|Latihan<br>Pelafalan|Sebagai<br>pengguna,<br>saya ingin<br>merekam|Tinggi|8|FR-04|



|ID|Modul|User Story<br>suara dan<br>melihat hasil<br>pengenalan<br>ujaran agar<br>saya tahu<br>pelafalan saya<br>terbaca.|Prioritas|SP|FR Terkait|
|---|---|---|---|---|---|
|PB-08|Analisis Nada|Sebagai<br>pengguna,<br>saya ingin<br>umpan balik<br>kontur nada<br>agar saya bisa<br>memperbaiki<br>nada pelafalan<br>saya.|Tinggi|13|FR-05|
|PB-09|AI Tutor|Sebagai<br>pengguna,<br>saya ingin<br>bertanya<br>kepada AI<br>Tutor agar saya<br>mendapat<br>penjelasan<br>kosakata dan<br>contoh<br>sederhana.|Tinggi|8|FR-14|
|PB-10|Hanzi<br>Matching|Sebagai<br>pengguna,<br>saya ingin<br>mencocokkan<br>Hanzi dengan<br>arti atau pinyin<br>agar saya<br>berlatih sambil<br>bermain.|Tinggi|5|FR-07|
|PB-11|Hanzi Stroke<br>Challenge|Sebagai<br>pengguna,<br>saya ingin<br>berlatih<br>menulis Hanzi<br>mengikuti<br>urutan|Tinggi|8|FR-08|



|ID|Modul|User Story<br>goresan agar<br>saya hafal<br>bentuk<br>karakter.|Prioritas|SP|FR Terkait|
|---|---|---|---|---|---|
|PB-12|Reward Koin|Sebagai<br>pengguna,<br>saya ingin<br>mendapat,<br>melihat, dan<br>memakai koin<br>untuk bantuan<br>agar saya<br>termotivasi<br>berlatih.|Tinggi|13|FR-17, FR-18,<br>FR-19, FR-20|
|PB-13|Tilt to Answer|Sebagai<br>pengguna,<br>saya ingin<br>menjawab soal<br>dengan<br>memiringkan<br>perangkat agar<br>belajar terasa<br>interaktif.|Tinggi|5|FR-09|
|PB-14|Mandarin<br>Catcher|Sebagai<br>pengguna,<br>saya ingin<br>menangkap<br>objek kosakata<br>target dengan<br>menggerakkan<br>perangkat agar<br>saya<br>mengenali<br>kata sambil<br>bermain.|Tinggi|5|FR-10|
|PB-15|Direction<br>Explorer|Sebagai<br>pengguna,<br>saya ingin<br>melihat<br>tempat sekitar,<br>jarak, arah,<br>dan<br>kosakatanya|Tinggi|13|FR-11|



|ID|Modul|User Story<br>agar saya<br>belajar<br>Mandarin<br>dalam konteks<br>nyata.|Prioritas|SP|FR Terkait|
|---|---|---|---|---|---|
|PB-16|Konversi Mata<br>Uang|Sebagai<br>pengguna,<br>saya ingin<br>mengonversi<br>IDR, CNY, dan<br>USD agar saya<br>paham nilai<br>uang dalam<br>konteks<br>Mandarin.|Tinggi|3|FR-12|
|PB-17|Konversi<br>Waktu|Sebagai<br>pengguna,<br>saya ingin<br>mengonversi<br>waktu WIB,<br>WITA, WIT,<br>London, dan<br>CST agar saya<br>tahu<br>perbedaan<br>zona waktu.|Tinggi|3|FR-13|
|PB-18|Umpan Balik<br>dan<br>Pengaturan|Sebagai<br>pengguna,<br>saya ingin<br>mengirim<br>umpan balik<br>dan mengatur<br>izin agar<br>aplikasi sesuai<br>kebutuhan<br>saya.|Sedang|3|FR-21|
|PB-19|Pengujian dan<br>Rilis|Sebagai tim,<br>kami ingin<br>menguji<br>seluruh alur<br>dan<br>membangun<br>APK rilis agar|Tinggi|8|Seluruh FR|



|ID|Modul|User Story|Prioritas|SP|FR Terkait|
|---|---|---|---|---|---|
|||aplikasi siap<br>dikumpulkan<br>sebelum 7<br>Desember<br>2026.||||



##### **4. Product Backlog Item (PBI)** 

###### **4.1 Prinsip Penyusunan PBI** 

PBI adalah penjabaran teknis Product Backlog berupa Task (desain database, implementasi, integrasi) dan Testing (unit test, integration test). Story Point tiap PBI memakai skala Fibonacci dan jumlahnya sama dengan SP Product Backlog induknya. Kolom PIC memuat pelaksana (Serena atau Lucy). Status awal semua PBI adalah To Do dan diubah menjadi Done setelah memenuhi Definition of Done. Tabel Evidence di akhir tiap sprint diisi screenshot atau hasil uji sebagai bukti. 

###### **4.2 Sprint 1: Fondasi, Akun, dan Materi (19–25 Okt 2026, PB-01 dan PB-02, Target 16 SP)** 

Sprint Goal: kerangka aplikasi Flutter dan backend siap; pengguna dapat registrasi, login, logout, lalu membuka materi HSK 1–6 lengkap dengan audio. 

|ID|Task / Sub-task|Tipe|SP|PIC|Status|
|---|---|---|---|---|---|
|PBI-001|Setup proyek<br>Flutter,<br>struktur folder,<br>navigasi dasar,<br>dan repositori<br>Git|Task|2|Serena|To Do|
|PBI-002|Desain skema<br>database<br>(users, profil)<br>dan setup<br>Supabase|Task|1|Lucy|To Do|
|PBI-003|Implementasi<br>registrasi dan<br>login dengan<br>validasi serta<br>penyimpanan<br>kredensial<br>aman|Task|2|Lucy|To Do|
|PBI-004|Implementasi<br>UI Login dan<br>Register|Task|1|Serena|To Do|



|ID|Task / Sub-task|Tipe|SP|PIC|Status|
|---|---|---|---|---|---|
|PBI-005|Implementasi<br>logout dan<br>penanganan<br>sesi|Task|1|Serena|To Do|
|PBI-006|Unit testing<br>modul akun|Testing|1|Lucy|To Do|
|PBI-007|Desain skema<br>tabel<br>materi/kosakat<br>a (Hanzi,<br>pinyin, arti,<br>contoh, audio)|Task|1|Lucy|To Do|
|PBI-008|Penyusunan<br>dan validasi<br>konten HSK<br>1–6 beserta<br>file audio|Task|2|Lucy|To Do|
|PBI-009|Implementasi<br>UI daftar level<br>dan topik<br>materi|Task|1|Serena|To Do|
|PBI-010|Implementasi<br>UI detail<br>materi (Hanzi,<br>pinyin<br>bertanda<br>nada, arti,<br>contoh)|Task|2|Serena|To Do|
|PBI-011|Implementasi<br>pemutar audio<br>pelafalan|Task|1|Serena|To Do|
|PBI-012|Unit testing<br>modul materi|Testing|1|Lucy|To Do|
|ID|||Evidence|||
|PBI-001 s.d.|PBI-012||[Lampirkan s<br>sini]|creenshot atau h|asil uji per PBI di|



###### **4.3 Sprint 2: Belajar Inti (26 Okt–1 Nov 2026, PB-03 sampai PB-06, Target 18 SP)** 

Sprint Goal: alur belajar inti berjalan; pengguna dapat mengerjakan kuis, memakai kamus, melihat progres, dan menerima pengingat belajar. 

|ID|Task / Sub-task|Tipe|SP|PIC|Status|
|---|---|---|---|---|---|
|PBI-013|Desain skema<br>tabel hasil kuis<br>(quiz_attempts<br>)|Task|1|Lucy|To Do|
|PBI-014|Implementasi<br>generator soal<br>tebak arti dan<br>pinyin|Task|1|Lucy|To Do|
|PBI-015|Implementasi<br>UI kuis dan<br>halaman hasil,<br>termasuk<br>penyimpanan<br>skor|Task|2|Serena|To Do|
|PBI-016|Unit testing<br>modul kuis|Testing|1|Lucy|To Do|
|PBI-017|Implementasi<br>pencarian<br>kamus<br>berdasarkan<br>Hanzi, pinyin,<br>dan arti|Task|2|Lucy|To Do|
|PBI-018|Implementasi<br>UI pencarian<br>dan detail<br>kosakata|Task|2|Serena|To Do|
|PBI-019|Unit testing<br>modul kamus|Testing|1|Lucy|To Do|
|PBI-020|Desain skema<br>tabel progres<br>dan<br>penyimpanan<br>materi selesai<br>serta skor|Task|2|Lucy|To Do|



|ID|Task / Sub-task|Tipe|SP|PIC|Status|
|---|---|---|---|---|---|
|PBI-021|Implementasi<br>UI halaman<br>progres|Task|2|Serena|To Do|
|PBI-022|Unit testing<br>modul progres|Testing|1|Lucy|To Do|
|PBI-023|Implementasi<br>notifikasi lokal<br>pengingat<br>belajar dan<br>izin notifikasi<br>Android|Task|2|Serena|To Do|
|PBI-024|Implementasi<br>pengaturan<br>aktif/nonaktif<br>pengingat dan<br>unit testing|Task|1|Lucy|To Do|



|ID|Evidence|
|---|---|
|PBI-013 s.d. PBI-024|[Lampirkan screenshot atau hasil uji per PBI di|
||sini]|



###### **4.4 Sprint 3: Latihan Pelafalan dan Analisis Nada (2–8 Nov 2026, PB-07 dan PB-08, Target 21 SP)** 

Sprint Goal: pengguna dapat merekam suara, melihat hasil pengenalan ujaran, dan menerima umpan balik kontur nada yang bersifat indikatif. 

|ID|Task / Sub-task|Tipe|SP|PIC|Status|
|---|---|---|---|---|---|
|PBI-025|Setup layanan<br>ASR FunASR<br>(Paraformer-zh<br>) dan endpoint<br>API|Task|3|Lucy|To Do|
|PBI-026|Implementasi<br>perekaman<br>suara, izin<br>mikrofon, dan<br>UI rekam|Task|2|Serena|To Do|
|PBI-027|Integrasi<br>pengiriman<br>rekaman,<br>tampilan|Task|2|Serena|To Do|



|ID|Task / Sub-task|Tipe|SP|PIC|Status|
|---|---|---|---|---|---|
||transkripsi,<br>status<br>pemrosesan,<br>dan pesan<br>error|||||
|PBI-028|Unit dan<br>integration<br>testing latihan<br>pelafalan|Testing|1|Lucy|To Do|
|PBI-029|Implementasi<br>ekstraksi<br>kontur<br>pitch/F0 dari<br>rekaman|Task|3|Lucy|To Do|
|PBI-030|Penyiapan<br>data referensi<br>kontur nada<br>untuk kosakata|Task|2|Lucy|To Do|
|PBI-031|Implementasi<br>perbandingan<br>kontur, skor<br>indikatif, dan<br>pesan "tidak<br>dapat dinilai"|Task|3|Lucy|To Do|
|PBI-032|Implementasi<br>UI umpan balik<br>nada (grafik<br>kontur dan<br>saran<br>perbaikan)|Task|3|Serena|To Do|
|PBI-033|Pengujian<br>dengan<br>sampel suara<br>beragam dan<br>unit testing<br>analisis nada|Testing|2|Serena|To Do|



|ID|Evidence|
|---|---|
|PBI-025 s.d. PBI-033|[Lampirkan screenshot atau hasil uji per PBI di<br>sini]|



###### **4.5 Sprint 4: AI Tutor, Hanzi Matching, dan Stroke Challenge (9–15 Nov 2026, PB-09 sampai PB-11, Target 21 SP)** 

Sprint Goal: pengguna dapat bertanya kepada AI Tutor (dengan fallback saat model gagal), memainkan Hanzi Matching, dan berlatih menulis Hanzi mengikuti urutan goresan. 

|ID|Task / Sub-task|Tipe|SP|PIC|Status|
|---|---|---|---|---|---|
|PBI-034|Setup Ollama<br>dengan<br>Qwen2.5<br>Instruct dan<br>endpoint API<br>AI Tutor|Task|3|Lucy|To Do|
|PBI-035|Implementasi<br>prompt<br>konteks<br>pembelajaran<br>dan jawaban<br>fallback saat<br>model/API<br>tidak tersedia|Task|2|Lucy|To Do|
|PBI-036|Implementasi<br>UI chat AI<br>Tutor|Task|2|Serena|To Do|
|PBI-037|Unit testing<br>modul AI Tutor|Testing|1|Lucy|To Do|
|PBI-038|Implementasi<br>logika<br>permainan<br>pasangan<br>Hanzi–arti/pin<br>yin dan<br>pencatatan<br>menang/kalah|Task|2|Serena|To Do|
|PBI-039|Implementasi<br>UI permainan<br>Hanzi<br>Matching|Task|2|Serena|To Do|
|PBI-040|Unit testing<br>Hanzi<br>Matching|Testing|1|Lucy|To Do|
|PBI-041|Penyiapan<br>data urutan|Task|2|Lucy|To Do|



|ID|Task / Sub-task|Tipe|SP|PIC|Status|
|---|---|---|---|---|---|
||goresan untuk<br>karakter<br>terpilih|||||
|PBI-042|Implementasi<br>kanvas<br>menulis dan<br>garis panduan<br>goresan|Task|3|Serena|To Do|
|PBI-043|Implementasi<br>logika urutan<br>goresan dan<br>umpan balik<br>terbatas|Task|2|Serena|To Do|
|PBI-044|Unit testing<br>Stroke<br>Challenge|Testing|1|Lucy|To Do|



|ID|Evidence|
|---|---|
|PBI-034 s.d. PBI-044|[Lampirkan screenshot atau hasil uji per PBI di|
||sini]|



###### **4.6 Sprint 5: Reward Koin dan Mini Game Sensor (16–22 Nov 2026, PB-12 sampai PB-14, Target 23 SP)** 

Sprint Goal: koin, streak, penukaran bantuan, dan riwayat koin berjalan tanpa transaksi ganda; Tilt to Answer dan Mandarin Catcher dapat dimainkan dengan fallback sensor. 

|ID|Task / Sub-task|Tipe|SP|PIC|Status|
|---|---|---|---|---|---|
|PBI-045|Desain skema<br>coin_ledger<br>dengan ID<br>attempt unik<br>dan status<br>streak|Task|2|Lucy|To Do|
|PBI-046|Implementasi<br>reward skor<br>kuis dan<br>latihan<br>pelafalan<br>sesuai tabel,|Task|3|Lucy|To Do|



|ID|Task / Sub-task|Tipe|SP|PIC|Status|
|---|---|---|---|---|---|
||satu kali per<br>attempt|||||
|PBI-047|Implementasi<br>bonus 25 koin<br>tiap 5<br>kemenangan<br>Hanzi<br>Matching<br>beruntun, satu<br>kali per streak|Task|2|Lucy|To Do|
|PBI-048|Implementasi<br>penukaran<br>koin untuk<br>bantuan (cek<br>saldo,<br>konfirmasi,<br>kurangi saldo<br>sekali)|Task|3|Serena|To Do|
|PBI-049|Implementasi<br>UI saldo dan<br>riwayat koin|Task|2|Serena|To Do|
|PBI-050|Unit testing<br>reward, streak,<br>dan ledger|Testing|1|Lucy|To Do|
|PBI-051|Implementasi<br>pembacaan<br>gyroscope dan<br>logika pilih<br>opsi Tilt to<br>Answer<br>beserta<br>fallback|Task|3|Serena|To Do|
|PBI-052|Implementasi<br>UI dan<br>penyimpanan<br>skor Tilt to<br>Answer|Task|1|Serena|To Do|
|PBI-053|Pengujian Tilt<br>to Answer di<br>perangkat fisik|Testing|1|Lucy|To Do|



|ID|Task / Sub-task|Tipe|SP|PIC|Status|
|---|---|---|---|---|---|
|PBI-054|Implementasi<br>accelerometer,<br>gerak objek,<br>dan logika<br>tangkap<br>kosakata<br>Mandarin<br>Catcher<br>beserta<br>fallback|Task|3|Serena|To Do|
|PBI-055|Implementasi<br>UI dan<br>penyimpanan<br>skor Mandarin<br>Catcher|Task|1|Serena|To Do|
|PBI-056|Pengujian<br>Mandarin<br>Catcher di<br>perangkat fisik|Testing|1|Lucy|To Do|



|ID|Evidence|
|---|---|
|PBI-045 s.d. PBI-056|[Lampirkan screenshot atau hasil uji per PBI di|
||sini]|



###### **4.7 Sprint 6: Direction Explorer dan Konversi (23–29 Nov 2026, PB-15 sampai PB-17, Target 19 SP)** 

Sprint Goal: pengguna dapat menjelajah tempat sekitar dengan peta, jarak, arah, dan kompas beserta kosakatanya, serta mengonversi mata uang dan waktu. 

|ID|Task / Sub-task|Tipe|SP|PIC|Status|
|---|---|---|---|---|---|
|PBI-057|Setup<br>penyedia<br>peta/Places,<br>izin lokasi, dan<br>fallback daftar<br>kosakata mata<br>angin bila izin<br>ditolak|Task|3|Lucy|To Do|
|PBI-058|Implementasi<br>tampilan peta<br>danpenanda|Task|3|Serena|To Do|



|ID|Task / Sub-task<br>tempat sekitar<br>per kategori|Tipe|SP|PIC|Status|
|---|---|---|---|---|---|
|PBI-059|Implementasi<br>detail tempat:<br>jarak dan arah<br>relatif dari<br>koordinat<br>pengguna dan<br>tujuan|Task|2|Lucy|To Do|
|PBI-060|Implementasi<br>tampilan<br>kompas<br>(magnetomete<br>r) dan instruksi<br>kalibrasi|Task|2|Serena|To Do|
|PBI-061|Implementasi<br>panel kosakata<br>tempat dan<br>mata angin<br>(Hanzi, pinyin,<br>arti, audio)|Task|2|Serena|To Do|
|PBI-062|Unit testing<br>dan pengujian<br>perangkat fisik<br>Direction<br>Explorer|Testing|1|Lucy|To Do|
|PBI-063|Integrasi API<br>kurs<br>IDR/CNY/USD<br>dengan<br>timestamp<br>pembaruan<br>dan cache|Task|1|Lucy|To Do|
|PBI-064|Implementasi<br>UI konversi<br>mata uang|Task|1|Serena|To Do|
|PBI-065|Unit testing<br>konversi mata<br>uang|Testing|1|Lucy|To Do|
|PBI-066|Implementasi<br>logika zona|Task|2|Lucy|To Do|



|ID|Task / Sub-task|Tipe|SP|PIC|Status|
|---|---|---|---|---|---|
||waktu WIB,<br>WITA, WIT,<br>London<br>(daylight<br>saving), dan<br>CST|||||
|PBI-067|Implementasi<br>UI konversi<br>waktu dan unit<br>testing|Task|1|Serena|To Do|



|ID|Evidence|
|---|---|
|PBI-057 s.d. PBI-067|[Lampirkan screenshot atau hasil uji per PBI di<br>sini]|



###### **4.8 Sprint 7: Umpan Balik, Pengujian, dan Rilis (30 Nov–6 Des 2026, PB-18 dan PB-19, Target 11 SP)** 

Sprint Goal: seluruh alur lulus integration test dan UAT, bug diperbaiki, dan APK rilis siap dikumpulkan sebelum 7 Desember 2026. Sprint ini sengaja ringan sebagai cadangan bila sprint sebelumnya tertunda. 

|ID|Task / Sub-task|Tipe|SP|PIC|Status|
|---|---|---|---|---|---|
|PBI-068|Implementasi<br>form umpan<br>balik<br>pengguna dan<br>penyimpanann<br>ya|Task|2|Serena|To Do|
|PBI-069|Implementasi<br>halaman<br>pengaturan<br>(izin mikrofon,<br>lokasi,<br>notifikasi)|Task|1|Lucy|To Do|
|PBI-070|Integration<br>testing alur<br>utama (materi,<br>kuis, pelafalan,<br>reward)|Testing|2|Lucy|To Do|
|PBI-071|Pengujian<br>perangkat fisik<br>(sensor,|Testing|2|Serena|To Do|



|ID|Task / Sub-task|Tipe|SP|PIC|Status|
|---|---|---|---|---|---|
||mikrofon,<br>lokasi) dan<br>penanganan<br>izin|||||
|PBI-072|Perbaikan bug<br>dan optimasi<br>performa|Task|2|Serena|To Do|
|PBI-073|User<br>Acceptance<br>Testing dan<br>verifikasi<br>kriteria<br>penerimaan<br>PRD|Testing|1|Lucy|To Do|
|PBI-074|Build APK rilis,<br>dokumentasi<br>teknis, dan<br>user guide|Task|1|Serena|To Do|



|ID|Evidence|
|---|---|
|PBI-068 s.d. PBI-074|[Lampirkan screenshot atau hasil uji per PBI di<br>sini]|



##### **5. Definition of Done (DoD)** 

Setiap PBI dianggap selesai (Done) bila memenuhi seluruh kriteria berikut: 

1. Kode telah ditulis dan memenuhi coding standard yang disepakati tim. 

2. Unit test telah dibuat dan lulus untuk fungsi yang dikerjakan. 

3. Kode telah ditinjau (code review) oleh anggota tim lainnya. 

4. Tidak ada bug kritis (critical/blocker) yang belum diselesaikan. 

5. Fitur diuji secara fungsional dan memenuhi kriteria penerimaan PRD. 

6. Fitur berjalan di perangkat Android fisik (untuk fitur sensor, mikrofon, dan lokasi). 

7. Evidence (screenshot atau hasil uji) telah dilampirkan pada tabel Evidence sprint terkait. 

8. Product Owner telah mereview dan menyetujui hasil sprint. 

##### **6. Ringkasan Sprint Plan** 

Tujuh sprint berdurasi 1 minggu memuat 19 Product Backlog, 129 Story Point, dan 74 PBI. Seluruh pekerjaan selesai pada 6 Desember 2026, satu hari sebelum batas 7 Desember 2026. 

|Sprint|Periode|Product<br>Backlog|SP|Jumlah PBI|Status|PIC|
|---|---|---|---|---|---|---|
|Sprint 1|19–25 Okt|PB-01 Akun,<br>PB-02<br>Materi HSK<br>1–6|16|12|To Do|Serena dan<br>Lucy|
|Sprint 2|26 Okt–1<br>Nov|PB-03 Kuis,<br>PB-04<br>Kamus,<br>PB-05<br>Progres,<br>PB-06<br>Notifikasi|18|12|To Do|Serena dan<br>Lucy|
|Sprint 3|2–8 Nov|PB-07<br>Latihan<br>Pelafalan,<br>PB-08<br>Analisis<br>Nada|21|9|To Do|Serena dan<br>Lucy|
|Sprint 4|9–15 Nov|PB-09 AI<br>Tutor, PB-10<br>Hanzi<br>Matching,<br>PB-11<br>Stroke<br>Challenge|21|11|To Do|Serena dan<br>Lucy|
|Sprint 5|16–22 Nov|PB-12<br>Reward<br>Koin, PB-13<br>Tilt to<br>Answer,<br>PB-14<br>Mandarin<br>Catcher|23|12|To Do|Serena dan<br>Lucy|
|Sprint 6|23–29 Nov|PB-15<br>Direction<br>Explorer,<br>PB-16<br>Konversi<br>Mata Uang,<br>PB-17<br>Konversi<br>Waktu|19|11|To Do|Serena dan<br>Lucy|



|Sprint|Periode|Product<br>Backlog|SP|Jumlah PBI|Status|PIC|
|---|---|---|---|---|---|---|
|Sprint 7|30 Nov–6<br>Des|PB-18<br>Umpan<br>Balik dan<br>Pengaturan,<br>PB-19<br>Pengujian<br>dan Rilis|11|7|To Do|Serena dan<br>Lucy|
|Total|19 Okt–6<br>Des 2026|19 Product<br>Backlog|129|74|||
