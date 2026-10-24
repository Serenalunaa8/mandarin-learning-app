-- ====================================================================
-- SCRIPT RESET & REBUILD TOTAL DATABASE SUPABASE (AMAN DARI ERROR)
-- Mandarin Learning App (Custom Auth SHA-256 + SQLite Sync)
-- Jalankan di: Supabase Dashboard > SQL Editor > New Query
-- ====================================================================

-- 1. HAPUS POLICY LAMA (JIKA ADA) AGAR TIDAK ERROR SAAT DROP TABLE
DO $$ 
DECLARE
    r RECORD;
BEGIN
    FOR r IN (
        SELECT tablename, policyname 
        FROM pg_policies 
        WHERE schemaname = 'public'
    ) LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', r.policyname, r.tablename);
    END LOOP;
END $$;

-- 2. HAPUS TABEL-TABEL LAMA SECARA BERSIH
-- Memakai block DO agar jika tabel belum pernah ada, tidak menghasilkan error
DO $$ 
BEGIN
    DROP TABLE IF EXISTS public.hanzi_game_scores CASCADE;
    DROP TABLE IF EXISTS public.feedback CASCADE;
    DROP TABLE IF EXISTS public.coin_ledger CASCADE;
    DROP TABLE IF EXISTS public.speech_attempts CASCADE;
    DROP TABLE IF EXISTS public.quiz_attempts CASCADE;
    DROP TABLE IF EXISTS public.user_progress CASCADE;
    DROP TABLE IF EXISTS public.vocabulary CASCADE;
    DROP TABLE IF EXISTS public.app_users CASCADE;
    DROP TABLE IF EXISTS public.profiles CASCADE;
EXCEPTION
    WHEN OTHERS THEN NULL;
END $$;

-- 3. EXTENSIONS
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- 4. BUAT TABEL UTAMA PENGGUNA (app_users)
CREATE TABLE public.app_users (
    id TEXT PRIMARY KEY,
    username TEXT UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    full_name TEXT NOT NULL,
    email TEXT DEFAULT '',
    avatar_url TEXT DEFAULT '',
    current_hsk_level INT DEFAULT 1 CHECK (current_hsk_level BETWEEN 1 AND 6),
    streak INT DEFAULT 1 CHECK (streak >= 0),
    coins INT DEFAULT 50 CHECK (coins >= 0),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_app_users_username ON public.app_users(LOWER(username));

-- 5. TABEL VOCABULARY
CREATE TABLE public.vocabulary (
    id INT PRIMARY KEY,
    hanzi TEXT NOT NULL,
    pinyin TEXT NOT NULL,
    arti_indonesia TEXT NOT NULL,
    translations JSONB DEFAULT '[]'::jsonb,
    hsk_level INT NOT NULL CHECK (hsk_level BETWEEN 1 AND 6),
    jenis_kata TEXT DEFAULT '',
    contoh_kalimat JSONB DEFAULT '[]'::jsonb,
    sumber TEXT DEFAULT 'HSK 2.0 Official Vocabulary',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_vocab_hsk_level ON public.vocabulary(hsk_level);
CREATE INDEX IF NOT EXISTS idx_vocab_hanzi ON public.vocabulary(hanzi);
CREATE INDEX IF NOT EXISTS idx_vocab_pinyin ON public.vocabulary(pinyin);

-- 6. TABEL USER_PROGRESS
CREATE TABLE public.user_progress (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id TEXT NOT NULL REFERENCES public.app_users(id) ON DELETE CASCADE,
    vocab_id INT NOT NULL REFERENCES public.vocabulary(id) ON DELETE CASCADE,
    hsk_level INT NOT NULL CHECK (hsk_level BETWEEN 1 AND 6),
    is_learned BOOLEAN DEFAULT true,
    review_count INT DEFAULT 1,
    last_studied_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT uq_user_vocab_progress UNIQUE (user_id, vocab_id)
);

CREATE INDEX IF NOT EXISTS idx_user_progress_user ON public.user_progress(user_id);
CREATE INDEX IF NOT EXISTS idx_user_progress_level ON public.user_progress(user_id, hsk_level);

-- 7. TABEL QUIZ_ATTEMPTS
CREATE TABLE public.quiz_attempts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id TEXT NOT NULL REFERENCES public.app_users(id) ON DELETE CASCADE,
    attempt_id TEXT NOT NULL UNIQUE,
    hsk_level INT NOT NULL CHECK (hsk_level BETWEEN 1 AND 6),
    quiz_type TEXT NOT NULL,
    score INT NOT NULL CHECK (score BETWEEN 0 AND 100),
    total_questions INT NOT NULL CHECK (total_questions > 0),
    correct_answers INT NOT NULL CHECK (correct_answers >= 0),
    coins_earned INT DEFAULT 0 CHECK (coins_earned >= 0),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_quiz_user ON public.quiz_attempts(user_id);

-- 8. TABEL SPEECH_ATTEMPTS
CREATE TABLE public.speech_attempts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id TEXT NOT NULL REFERENCES public.app_users(id) ON DELETE CASCADE,
    attempt_id TEXT NOT NULL UNIQUE,
    vocab_id INT NOT NULL REFERENCES public.vocabulary(id) ON DELETE CASCADE,
    transcription TEXT DEFAULT '',
    pitch_score INT CHECK (pitch_score BETWEEN 0 AND 100),
    pitch_feedback TEXT DEFAULT '',
    is_correct BOOLEAN DEFAULT false,
    coins_earned INT DEFAULT 0 CHECK (coins_earned >= 0),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_speech_user ON public.speech_attempts(user_id);

-- 9. TABEL COIN_LEDGER
CREATE TABLE public.coin_ledger (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id TEXT NOT NULL REFERENCES public.app_users(id) ON DELETE CASCADE,
    attempt_id TEXT,
    amount INT NOT NULL,
    transaction_type TEXT NOT NULL,
    description TEXT DEFAULT '',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT uq_ledger_attempt UNIQUE NULLS NOT DISTINCT (user_id, attempt_id)
);

CREATE INDEX IF NOT EXISTS idx_ledger_user ON public.coin_ledger(user_id);

-- 10. TABEL FEEDBACK
CREATE TABLE public.feedback (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id TEXT REFERENCES public.app_users(id) ON DELETE SET NULL,
    category TEXT NOT NULL,
    message TEXT NOT NULL,
    rating INT CHECK (rating BETWEEN 1 AND 5),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 11. TABEL HANZI_GAME_SCORES
CREATE TABLE public.hanzi_game_scores (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id TEXT NOT NULL REFERENCES public.app_users(id) ON DELETE CASCADE,
    game_type TEXT NOT NULL,
    hsk_level INT CHECK (hsk_level BETWEEN 1 AND 6),
    score INT DEFAULT 0,
    streak_count INT DEFAULT 0,
    coins_earned INT DEFAULT 0 CHECK (coins_earned >= 0),
    played_at TIMESTAMPTZ DEFAULT NOW()
);

-- 12. ROW LEVEL SECURITY (RLS) FULL ACCESS UNTUK ANON & AUTHENTICATED
ALTER TABLE public.app_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vocabulary ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_progress ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.quiz_attempts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.speech_attempts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.coin_ledger ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.feedback ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hanzi_game_scores ENABLE ROW LEVEL SECURITY;

CREATE POLICY "allow_all_app_users" ON public.app_users
    FOR ALL TO anon, authenticated
    USING (true) WITH CHECK (true);

CREATE POLICY "allow_all_vocabulary" ON public.vocabulary
    FOR ALL TO anon, authenticated
    USING (true) WITH CHECK (true);

CREATE POLICY "allow_all_user_progress" ON public.user_progress
    FOR ALL TO anon, authenticated
    USING (true) WITH CHECK (true);

CREATE POLICY "allow_all_quiz_attempts" ON public.quiz_attempts
    FOR ALL TO anon, authenticated
    USING (true) WITH CHECK (true);

CREATE POLICY "allow_all_speech_attempts" ON public.speech_attempts
    FOR ALL TO anon, authenticated
    USING (true) WITH CHECK (true);

CREATE POLICY "allow_all_coin_ledger" ON public.coin_ledger
    FOR ALL TO anon, authenticated
    USING (true) WITH CHECK (true);

CREATE POLICY "allow_all_feedback" ON public.feedback
    FOR ALL TO anon, authenticated
    USING (true) WITH CHECK (true);

CREATE POLICY "allow_all_hanzi_game_scores" ON public.hanzi_game_scores
    FOR ALL TO anon, authenticated
    USING (true) WITH CHECK (true);

-- 13. OTOMATISASI TRIGGER UPDATE TIMESTAMP
CREATE OR REPLACE FUNCTION public.fn_update_app_users_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_app_users_updated_at ON public.app_users;
CREATE TRIGGER trg_app_users_updated_at
    BEFORE UPDATE ON public.app_users
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_update_app_users_timestamp();
