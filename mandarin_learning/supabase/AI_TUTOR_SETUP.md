# Menyiapkan AI Tutor

LingLing dan Gemini memakai Edge Function terpisah. `lingling-ai` membaca
kosakata pembelajaran publik dari tabel `vocabulary` dan hanya menjawab panduan,
fitur, navigasi, serta isi database Nihaoki. `gemini-ai` tidak membaca konteks
database dan menjawab pertanyaan umum secara ringkas. Fungsi tidak membaca
tabel akun atau profil sehingga password, username, dan data pribadi tidak
dikirim ke Gemini. Fungsi lama `ai-tutor` tetap tersedia sebagai kompatibilitas
untuk klien lama.

Pada proyek Supabase tertaut, migrasi pembatas penggunaan dan secret
`GEMINI_API_KEY` sudah disiapkan. Untuk proyek Supabase lain, jalankan migrasi
`supabase/migrations/20261022_add_ai_tutor_rate_limit.sql`, simpan
`GEMINI_API_KEY` sebagai secret Supabase, lalu deploy:

```powershell
supabase functions deploy ai-tutor --project-ref <project-ref>
supabase functions deploy lingling-ai --project-ref <project-ref>
supabase functions deploy gemini-ai --project-ref <project-ref>
```

`supabase/config.toml` mematikan pemeriksaan JWT untuk ketiga fungsi karena
aplikasi memakai sesi login sendiri, bukan Supabase Auth. Semua fungsi memakai
pembatasan hingga 20 pertanyaan per jam per alamat IP.
