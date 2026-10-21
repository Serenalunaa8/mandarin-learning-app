-- ====================================================================
-- PERBAIKAN TABEL APP_USERS + RLS POLICIES
-- Jalankan di Supabase Dashboard > SQL Editor > New Query
-- Copy-paste SEMUA isi file ini, lalu klik "Run"
-- ====================================================================

-- LANGKAH 1: Hapus tabel app_users yang lama (jika ada masalah struktur)
-- PERINGATAN: Ini akan menghapus data yang ada di tabel app_users!
-- Jika tidak mau kehilangan data, skip langkah ini.
-- DROP TABLE IF EXISTS public.app_users CASCADE;

-- LANGKAH 2: Buat tabel app_users (jika belum ada / baru dihapus)
CREATE TABLE IF NOT EXISTS public.app_users (
    id TEXT PRIMARY KEY,
    username TEXT UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    full_name TEXT NOT NULL,
    email TEXT DEFAULT '',
    avatar_url TEXT DEFAULT '',
    current_hsk_level INT DEFAULT 1,
    streak INT DEFAULT 1,
    total_xp INT DEFAULT 0,
    coins INT DEFAULT 50,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- LANGKAH 3: Pastikan RLS aktif
ALTER TABLE public.app_users ENABLE ROW LEVEL SECURITY;

-- LANGKAH 4: Hapus semua policy lama yang mungkin bentrok
DROP POLICY IF EXISTS "app_users: select" ON public.app_users;
DROP POLICY IF EXISTS "app_users: insert" ON public.app_users;
DROP POLICY IF EXISTS "app_users: update" ON public.app_users;
DROP POLICY IF EXISTS "allow_select_all" ON public.app_users;
DROP POLICY IF EXISTS "allow_insert_all" ON public.app_users;
DROP POLICY IF EXISTS "allow_update_all" ON public.app_users;
DROP POLICY IF EXISTS "Enable read access for all users" ON public.app_users;
DROP POLICY IF EXISTS "Enable insert for all users" ON public.app_users;
DROP POLICY IF EXISTS "Enable update for all users" ON public.app_users;

-- LANGKAH 5: Buat RLS policy yang mengizinkan anon role (paling penting!)
-- Tanpa ini, Flutter app TIDAK BISA insert/select karena pakai anon key
CREATE POLICY "anon_select_app_users" ON public.app_users
    FOR SELECT TO anon, authenticated
    USING (true);

CREATE POLICY "anon_insert_app_users" ON public.app_users
    FOR INSERT TO anon, authenticated
    WITH CHECK (true);

CREATE POLICY "anon_update_app_users" ON public.app_users
    FOR UPDATE TO anon, authenticated
    USING (true);

-- LANGKAH 6: Verifikasi — coba insert data test
INSERT INTO public.app_users (id, username, password_hash, full_name, email)
VALUES (
    'test_verify_001',
    'test_user_verify',
    'hash_test_only',
    'Test User',
    'test@test.com'
) ON CONFLICT (id) DO NOTHING;

-- Cek apakah data masuk
SELECT * FROM public.app_users;

-- Hapus data test setelah verifikasi
DELETE FROM public.app_users WHERE id = 'test_verify_001';

-- ====================================================================
-- PERBAIKI JUGA TABEL LAIN (RLS untuk anon role)
-- ====================================================================

-- vocabulary
ALTER TABLE public.vocabulary ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "vocabulary: select" ON public.vocabulary;
DROP POLICY IF EXISTS "allow_select_all" ON public.vocabulary;
CREATE POLICY "anon_select_vocabulary" ON public.vocabulary
    FOR SELECT TO anon, authenticated USING (true);

-- user_progress
ALTER TABLE public.user_progress ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "user_progress: select" ON public.user_progress;
DROP POLICY IF EXISTS "user_progress: insert" ON public.user_progress;
DROP POLICY IF EXISTS "user_progress: update" ON public.user_progress;
DROP POLICY IF EXISTS "allow_select_all" ON public.user_progress;
DROP POLICY IF EXISTS "allow_insert_all" ON public.user_progress;
DROP POLICY IF EXISTS "allow_update_all" ON public.user_progress;
CREATE POLICY "anon_select_user_progress" ON public.user_progress
    FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY "anon_insert_user_progress" ON public.user_progress
    FOR INSERT TO anon, authenticated WITH CHECK (true);
CREATE POLICY "anon_update_user_progress" ON public.user_progress
    FOR UPDATE TO anon, authenticated USING (true);

-- quiz_attempts
ALTER TABLE public.quiz_attempts ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "quiz_attempts: select" ON public.quiz_attempts;
DROP POLICY IF EXISTS "quiz_attempts: insert" ON public.quiz_attempts;
DROP POLICY IF EXISTS "allow_select_all" ON public.quiz_attempts;
DROP POLICY IF EXISTS "allow_insert_all" ON public.quiz_attempts;
CREATE POLICY "anon_select_quiz_attempts" ON public.quiz_attempts
    FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY "anon_insert_quiz_attempts" ON public.quiz_attempts
    FOR INSERT TO anon, authenticated WITH CHECK (true);

-- speech_attempts
ALTER TABLE public.speech_attempts ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "speech_attempts: select" ON public.speech_attempts;
DROP POLICY IF EXISTS "speech_attempts: insert" ON public.speech_attempts;
DROP POLICY IF EXISTS "allow_select_all" ON public.speech_attempts;
DROP POLICY IF EXISTS "allow_insert_all" ON public.speech_attempts;
CREATE POLICY "anon_select_speech_attempts" ON public.speech_attempts
    FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY "anon_insert_speech_attempts" ON public.speech_attempts
    FOR INSERT TO anon, authenticated WITH CHECK (true);

-- coin_ledger
ALTER TABLE public.coin_ledger ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "coin_ledger: select" ON public.coin_ledger;
DROP POLICY IF EXISTS "coin_ledger: insert" ON public.coin_ledger;
DROP POLICY IF EXISTS "allow_select_all" ON public.coin_ledger;
DROP POLICY IF EXISTS "allow_insert_all" ON public.coin_ledger;
CREATE POLICY "anon_select_coin_ledger" ON public.coin_ledger
    FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY "anon_insert_coin_ledger" ON public.coin_ledger
    FOR INSERT TO anon, authenticated WITH CHECK (true);

-- feedback
ALTER TABLE public.feedback ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "feedback: select" ON public.feedback;
DROP POLICY IF EXISTS "feedback: insert" ON public.feedback;
DROP POLICY IF EXISTS "allow_select_all" ON public.feedback;
DROP POLICY IF EXISTS "allow_insert_all" ON public.feedback;
CREATE POLICY "anon_select_feedback" ON public.feedback
    FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY "anon_insert_feedback" ON public.feedback
    FOR INSERT TO anon, authenticated WITH CHECK (true);

-- hanzi_game_scores
ALTER TABLE public.hanzi_game_scores ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "hanzi_game_scores: select" ON public.hanzi_game_scores;
DROP POLICY IF EXISTS "hanzi_game_scores: insert" ON public.hanzi_game_scores;
DROP POLICY IF EXISTS "allow_select_all" ON public.hanzi_game_scores;
DROP POLICY IF EXISTS "allow_insert_all" ON public.hanzi_game_scores;
CREATE POLICY "anon_select_hanzi_game_scores" ON public.hanzi_game_scores
    FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY "anon_insert_hanzi_game_scores" ON public.hanzi_game_scores
    FOR INSERT TO anon, authenticated WITH CHECK (true);

-- ====================================================================
-- SELESAI! Setelah run SQL ini, coba daftar ulang di aplikasi Flutter.
-- Data seharusnya masuk ke tabel app_users.
-- ====================================================================
