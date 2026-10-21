-- ====================================================================
-- SKEMA LENGKAP SUPABASE: MANDARIN LEARNING APP (HSK 1-6)
-- Autentikasi Enkripsi SHA-256 + Session + Biometrik (Tanpa Firebase)
-- Database Lokal (SQLite) & Online (Supabase PostgreSQL)
-- Versi PRD 3.0 | Sprint 1 | 21 Oktober 2026
-- ====================================================================

-- 1. EXTENSIONS
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- ====================================================================
-- 2. TABEL APP_USERS
-- Tabel utama akun pengguna: username, password terenkripsi SHA-256,
-- profil belajar, dan statistik (koin, streak, XP, level HSK).
-- Digunakan untuk login TANPA Firebase / Supabase Auth native.
-- ====================================================================
CREATE TABLE IF NOT EXISTS public.app_users (
    id TEXT PRIMARY KEY,
    username TEXT UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,  -- SHA-256 + Salt, BUKAN plain text
    full_name TEXT NOT NULL,
    email TEXT DEFAULT '',
    avatar_url TEXT DEFAULT '',
    current_hsk_level INT DEFAULT 1 CHECK (current_hsk_level BETWEEN 1 AND 6),
    streak INT DEFAULT 1 CHECK (streak >= 0),
    total_xp INT DEFAULT 0 CHECK (total_xp >= 0),
    coins INT DEFAULT 50 CHECK (coins >= 0),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index cepat untuk login berdasarkan username (case-insensitive)
CREATE INDEX IF NOT EXISTS idx_app_users_username ON public.app_users(LOWER(username));

-- ====================================================================
-- 3. TABEL VOCABULARY
-- Master data kosakata HSK 1-6: Hanzi, Pinyin bertanda nada,
-- Arti Indonesia, Contoh Kalimat, dan Audio referensi.
-- ====================================================================
CREATE TABLE IF NOT EXISTS public.vocabulary (
    id INT PRIMARY KEY,
    hanzi TEXT NOT NULL,
    pinyin TEXT NOT NULL,
    arti_indonesia TEXT NOT NULL,
    translations JSONB DEFAULT '[]'::jsonb,
    hsk_level INT NOT NULL CHECK (hsk_level BETWEEN 1 AND 6),
    jenis_kata TEXT DEFAULT '',
    contoh_kalimat JSONB DEFAULT '[]'::jsonb,
    sumber TEXT DEFAULT 'HSK 2.0 Official Vocabulary (Mandarin-Indonesia)',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indeks performa pencarian kosakata
CREATE INDEX IF NOT EXISTS idx_vocab_hsk_level ON public.vocabulary(hsk_level);
CREATE INDEX IF NOT EXISTS idx_vocab_hanzi ON public.vocabulary(hanzi);
CREATE INDEX IF NOT EXISTS idx_vocab_pinyin ON public.vocabulary(pinyin);
CREATE INDEX IF NOT EXISTS idx_vocab_arti ON public.vocabulary USING gin (arti_indonesia gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_vocab_hanzi_trgm ON public.vocabulary USING gin (hanzi gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_vocab_pinyin_trgm ON public.vocabulary USING gin (pinyin gin_trgm_ops);

-- ====================================================================
-- 4. TABEL USER_PROGRESS
-- Mencatat kosakata yang sudah dipelajari oleh setiap pengguna.
-- Digunakan untuk menghitung progres dan menampilkan progres belajar.
-- ====================================================================
CREATE TABLE IF NOT EXISTS public.user_progress (
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
CREATE INDEX IF NOT EXISTS idx_user_progress_learned ON public.user_progress(user_id, is_learned);

-- ====================================================================
-- 5. TABEL QUIZ_ATTEMPTS
-- Mencatat hasil pengerjaan kuis tebak arti dan pinyin.
-- Digunakan untuk menghitung reward koin dan menampilkan riwayat kuis.
-- ====================================================================
CREATE TABLE IF NOT EXISTS public.quiz_attempts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id TEXT NOT NULL REFERENCES public.app_users(id) ON DELETE CASCADE,
    attempt_id TEXT NOT NULL UNIQUE,      -- ID unik per sesi kuis
    hsk_level INT NOT NULL CHECK (hsk_level BETWEEN 1 AND 6),
    quiz_type TEXT NOT NULL,              -- 'arti', 'pinyin', 'campuran'
    score INT NOT NULL CHECK (score BETWEEN 0 AND 100),
    total_questions INT NOT NULL CHECK (total_questions > 0),
    correct_answers INT NOT NULL CHECK (correct_answers >= 0),
    coins_earned INT DEFAULT 0 CHECK (coins_earned >= 0),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_quiz_user ON public.quiz_attempts(user_id);
CREATE INDEX IF NOT EXISTS idx_quiz_user_level ON public.quiz_attempts(user_id, hsk_level);
CREATE INDEX IF NOT EXISTS idx_quiz_created ON public.quiz_attempts(created_at DESC);

-- ====================================================================
-- 6. TABEL SPEECH_ATTEMPTS
-- Mencatat hasil latihan pelafalan dan analisis nada (pitch contour).
-- Menyimpan transkripsi ASR, skor nada indikatif, dan umpan balik.
-- ====================================================================
CREATE TABLE IF NOT EXISTS public.speech_attempts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id TEXT NOT NULL REFERENCES public.app_users(id) ON DELETE CASCADE,
    attempt_id TEXT NOT NULL UNIQUE,      -- ID unik per sesi latihan suara
    vocab_id INT NOT NULL REFERENCES public.vocabulary(id) ON DELETE CASCADE,
    transcription TEXT DEFAULT '',        -- Hasil ASR (pengenalan ujaran)
    pitch_score INT CHECK (pitch_score BETWEEN 0 AND 100),
    pitch_feedback TEXT DEFAULT '',       -- Umpan balik kontur nada
    is_correct BOOLEAN DEFAULT false,
    coins_earned INT DEFAULT 0 CHECK (coins_earned >= 0),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_speech_user ON public.speech_attempts(user_id);
CREATE INDEX IF NOT EXISTS idx_speech_vocab ON public.speech_attempts(vocab_id);
CREATE INDEX IF NOT EXISTS idx_speech_created ON public.speech_attempts(created_at DESC);

-- ====================================================================
-- 7. TABEL COIN_LEDGER
-- Buku besar mutasi koin: catat setiap reward dan pengeluaran koin.
-- Kolom attempt_id dipakai sebagai kunci anti-duplikasi reward.
-- ====================================================================
CREATE TABLE IF NOT EXISTS public.coin_ledger (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id TEXT NOT NULL REFERENCES public.app_users(id) ON DELETE CASCADE,
    attempt_id TEXT,                      -- Ref ke quiz_attempts / speech_attempts (nullable)
    amount INT NOT NULL,                  -- Positif = reward, Negatif = penggunaan hint
    transaction_type TEXT NOT NULL,
    -- Nilai: 'quiz_reward', 'speech_reward', 'streak_bonus',
    --        'hint_quiz', 'hint_matching', 'initial_bonus'
    description TEXT DEFAULT '',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT uq_ledger_attempt UNIQUE NULLS NOT DISTINCT (user_id, attempt_id)
);

CREATE INDEX IF NOT EXISTS idx_ledger_user ON public.coin_ledger(user_id);
CREATE INDEX IF NOT EXISTS idx_ledger_created ON public.coin_ledger(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_ledger_type ON public.coin_ledger(transaction_type);

-- ====================================================================
-- 8. TABEL FEEDBACK
-- Umpan balik pengguna terkait materi, fitur, atau bug dalam aplikasi.
-- ====================================================================
CREATE TABLE IF NOT EXISTS public.feedback (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id TEXT REFERENCES public.app_users(id) ON DELETE SET NULL,
    category TEXT NOT NULL,               -- 'materi', 'fitur', 'bug', 'saran', 'lainnya'
    message TEXT NOT NULL,
    rating INT CHECK (rating BETWEEN 1 AND 5),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_feedback_user ON public.feedback(user_id);
CREATE INDEX IF NOT EXISTS idx_feedback_category ON public.feedback(category);

-- ====================================================================
-- 9. TABEL HANZI_GAME_SCORES
-- Mencatat skor mini-game: Hanzi Matching, Streak beruntun,
-- Tilt to Answer, dan Mandarin Catcher.
-- ====================================================================
CREATE TABLE IF NOT EXISTS public.hanzi_game_scores (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id TEXT NOT NULL REFERENCES public.app_users(id) ON DELETE CASCADE,
    game_type TEXT NOT NULL,              -- 'hanzi_matching', 'tilt_answer', 'mandarin_catcher', 'stroke_challenge'
    hsk_level INT CHECK (hsk_level BETWEEN 1 AND 6),
    score INT DEFAULT 0,
    streak_count INT DEFAULT 0,           -- Jumlah kemenangan berturut-turut
    coins_earned INT DEFAULT 0 CHECK (coins_earned >= 0),
    played_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_game_user ON public.hanzi_game_scores(user_id);
CREATE INDEX IF NOT EXISTS idx_game_type ON public.hanzi_game_scores(game_type);

-- ====================================================================
-- 10. ROW LEVEL SECURITY (RLS)
-- Kebijakan akses menggunakan Supabase Anon Key.
-- Semua tabel dapat diakses dari aplikasi Flutter via REST API.
-- ====================================================================

-- Aktifkan RLS untuk semua tabel
ALTER TABLE public.app_users          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vocabulary          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_progress       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.quiz_attempts       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.speech_attempts     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.coin_ledger         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.feedback            ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hanzi_game_scores   ENABLE ROW LEVEL SECURITY;

-- ----- app_users: Kebijakan Akses -----
CREATE POLICY "app_users: select" ON public.app_users
    FOR SELECT TO anon, authenticated USING (true);

CREATE POLICY "app_users: insert" ON public.app_users
    FOR INSERT TO anon, authenticated WITH CHECK (true);

CREATE POLICY "app_users: update" ON public.app_users
    FOR UPDATE TO anon, authenticated USING (true);

-- ----- vocabulary: Hanya bisa dibaca, tidak bisa dimodifikasi -----
CREATE POLICY "vocabulary: select" ON public.vocabulary
    FOR SELECT TO anon, authenticated USING (true);

-- ----- user_progress -----
CREATE POLICY "user_progress: select" ON public.user_progress
    FOR SELECT TO anon, authenticated USING (true);

CREATE POLICY "user_progress: insert" ON public.user_progress
    FOR INSERT TO anon, authenticated WITH CHECK (true);

CREATE POLICY "user_progress: update" ON public.user_progress
    FOR UPDATE TO anon, authenticated USING (true);

-- ----- quiz_attempts -----
CREATE POLICY "quiz_attempts: select" ON public.quiz_attempts
    FOR SELECT TO anon, authenticated USING (true);

CREATE POLICY "quiz_attempts: insert" ON public.quiz_attempts
    FOR INSERT TO anon, authenticated WITH CHECK (true);

-- ----- speech_attempts -----
CREATE POLICY "speech_attempts: select" ON public.speech_attempts
    FOR SELECT TO anon, authenticated USING (true);

CREATE POLICY "speech_attempts: insert" ON public.speech_attempts
    FOR INSERT TO anon, authenticated WITH CHECK (true);

-- ----- coin_ledger -----
CREATE POLICY "coin_ledger: select" ON public.coin_ledger
    FOR SELECT TO anon, authenticated USING (true);

CREATE POLICY "coin_ledger: insert" ON public.coin_ledger
    FOR INSERT TO anon, authenticated WITH CHECK (true);

-- ----- feedback -----
CREATE POLICY "feedback: select" ON public.feedback
    FOR SELECT TO anon, authenticated USING (true);

CREATE POLICY "feedback: insert" ON public.feedback
    FOR INSERT TO anon, authenticated WITH CHECK (true);

-- ----- hanzi_game_scores -----
CREATE POLICY "hanzi_game_scores: select" ON public.hanzi_game_scores
    FOR SELECT TO anon, authenticated USING (true);

CREATE POLICY "hanzi_game_scores: insert" ON public.hanzi_game_scores
    FOR INSERT TO anon, authenticated WITH CHECK (true);

-- ====================================================================
-- 11. FUNGSI OTOMATIS: Update timestamp updated_at pada app_users
-- ====================================================================
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

-- ====================================================================
-- 12. DATA AWAL: Koin bonus awal pengguna baru
-- (Diproses oleh backend/Flutter saat registrasi, bukan trigger SQL)
-- Catatan: password_hash = SHA-256("MandarinLearning_SecureSalt_2026:<password>")
-- Gunakan service SecurityService.hashPassword() di Flutter.
-- ====================================================================

-- Contoh INSERT akun (HANYA untuk testing lokal, hapus di production):
-- INSERT INTO public.app_users (id, username, password_hash, full_name, email)
-- VALUES (
--     'usr_test_001',
--     'lucy_mandarin',
--     '<hash dari SecurityService.hashPassword("password123")>',
--     'Lucy Naibaho',
--     'lucy@test.com'
-- );
