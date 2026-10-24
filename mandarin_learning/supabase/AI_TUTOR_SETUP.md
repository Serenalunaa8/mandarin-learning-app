# Menyiapkan AI Tutor

AI Tutor memanggil Edge Function `ai-tutor`. Mode `app_api` mencari kosakata
pembelajaran publik di tabel `vocabulary`, lalu meminta Gemini menjawab dengan
konteks relevan. Mode `gemini` adalah asisten umum dan tidak membaca konteks
database aplikasi. Fungsi tidak membaca tabel akun atau profil sehingga
password, username, dan data pribadi tidak dikirim ke Gemini.

Pada proyek Supabase tertaut, migrasi pembatas penggunaan dan secret
`GEMINI_API_KEY` sudah disiapkan. Untuk proyek Supabase lain, jalankan migrasi
`supabase/migrations/20261022_add_ai_tutor_rate_limit.sql`, simpan
`GEMINI_API_KEY` sebagai secret Supabase, lalu deploy:

```powershell
supabase functions deploy ai-tutor --project-ref <project-ref>
```

`supabase/config.toml` mematikan pemeriksaan JWT hanya untuk fungsi ini karena
aplikasi memakai sesi login sendiri, bukan Supabase Auth. Fungsi dibatasi hingga
20 pertanyaan per jam per alamat IP.
