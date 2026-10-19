-- ====================================================================
-- SUPABASE SQL SCHEMA: MANDARIN LEARNING APP (HSK 1-6)
-- Sesuai PRD Versi 3.0 & Ketentuan Database Keamanan (RLS)
-- ====================================================================

-- 1. EXTENSIONS
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- 2. TABEL PROFILES (Terhubung ke auth.users)
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    full_name TEXT,
    avatar_url TEXT,
    current_hsk_level INT DEFAULT 1 CHECK (current_hsk_level BETWEEN 1 AND 6),
    streak INT DEFAULT 0,
    last_active_date DATE DEFAULT CURRENT_DATE,
    total_xp INT DEFAULT 0,
    coins INT DEFAULT 50 CHECK (coins >= 0),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. TABEL VOCABULARY (Kosakata HSK 1-6)
CREATE TABLE IF NOT EXISTS public.vocabulary (
    id INT PRIMARY KEY,
    hanzi TEXT NOT NULL,
    pinyin TEXT NOT NULL,
    arti_indonesia TEXT NOT NULL,
    translations JSONB DEFAULT '[]'::jsonb,
    hsk_level INT NOT NULL CHECK (hsk_level BETWEEN 1 AND 6),
    jenis_kata TEXT,
    contoh_kalimat JSONB DEFAULT '[]'::jsonb,
    sumber TEXT DEFAULT 'HSK 2.0 Official Vocabulary (Mandarin-Indonesia)',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_vocab_hsk_level ON public.vocabulary(hsk_level);
CREATE INDEX IF NOT EXISTS idx_vocab_hanzi ON public.vocabulary(hanzi);
CREATE INDEX IF NOT EXISTS idx_vocab_pinyin ON public.vocabulary(pinyin);
CREATE INDEX IF NOT EXISTS idx_vocab_arti ON public.vocabulary USING gin (arti_indonesia gin_trgm_ops);

-- 4. TABEL USER_PROGRESS (Pencatatan Materi Selesai)
CREATE TABLE IF NOT EXISTS public.user_progress (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    vocab_id INT NOT NULL REFERENCES public.vocabulary(id) ON DELETE CASCADE,
    hsk_level INT NOT NULL CHECK (hsk_level BETWEEN 1 AND 6),
    is_learned BOOLEAN DEFAULT true,
    review_count INT DEFAULT 1,
    last_studied_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, vocab_id)
);

CREATE INDEX IF NOT EXISTS idx_user_progress_user ON public.user_progress(user_id);
CREATE INDEX IF NOT EXISTS idx_user_progress_level ON public.user_progress(user_id, hsk_level);

-- 5. TABEL QUIZ_ATTEMPTS (Hasil Kuis Tebak Arti & Pinyin)
CREATE TABLE IF NOT EXISTS public.quiz_attempts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    attempt_id TEXT NOT NULL UNIQUE,
    hsk_level INT NOT NULL CHECK (hsk_level BETWEEN 1 AND 6),
    quiz_type TEXT NOT NULL, -- 'arti', 'pinyin', 'campuran'
    score INT NOT NULL CHECK (score BETWEEN 0 AND 100),
    total_questions INT NOT NULL,
    correct_answers INT NOT NULL,
    coins_earned INT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_quiz_user ON public.quiz_attempts(user_id);

-- 6. TABEL SPEECH_ATTEMPTS (Hasil Latihan Pelafalan & Nada)
CREATE TABLE IF NOT EXISTS public.speech_attempts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    attempt_id TEXT NOT NULL UNIQUE,
    vocab_id INT NOT NULL REFERENCES public.vocabulary(id) ON DELETE CASCADE,
    transcription TEXT,
    pitch_score INT CHECK (pitch_score BETWEEN 0 AND 100),
    pitch_feedback TEXT,
    is_correct BOOLEAN DEFAULT false,
    coins_earned INT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_speech_user ON public.speech_attempts(user_id);

-- 7. TABEL COIN_LEDGER (Buku Besar Transaksi Koin & Anti Duplikasi)
CREATE TABLE IF NOT EXISTS public.coin_ledger (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    attempt_id TEXT, -- Unik untuk attempt tertentu guna mencegah duplikasi reward
    amount INT NOT NULL, -- Positif untuk pendapatan, negatif untuk pengeluaran
    transaction_type TEXT NOT NULL, -- 'quiz_reward', 'speech_reward', 'streak_bonus', 'hint_quiz', 'hint_matching', 'initial_bonus'
    description TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT uq_attempt_reward UNIQUE NULLS NOT DISTINCT (user_id, attempt_id)
);

CREATE INDEX IF NOT EXISTS idx_ledger_user ON public.coin_ledger(user_id);

-- 8. TABEL FEEDBACK (Umpan Balik Pengguna)
CREATE TABLE IF NOT EXISTS public.feedback (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    category TEXT NOT NULL,
    message TEXT NOT NULL,
    rating INT CHECK (rating BETWEEN 1 AND 5),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ====================================================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- ====================================================================

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vocabulary ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_progress ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.quiz_attempts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.speech_attempts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.coin_ledger ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.feedback ENABLE ROW LEVEL SECURITY;

-- 1. Vocabulary: Publik bisa membaca (SELECT), hanya service role yang bisa memodifikasi
CREATE POLICY "Vocabulary is readable by everyone"
    ON public.vocabulary FOR SELECT
    USING (true);

-- 2. Profiles: Pengguna hanya dapat membaca dan memperbarui profil mereka sendiri
CREATE POLICY "Users can view own profile"
    ON public.profiles FOR SELECT
    USING (auth.uid() = id);

CREATE POLICY "Users can update own profile"
    ON public.profiles FOR UPDATE
    USING (auth.uid() = id);

-- 3. User Progress: Pengguna hanya dapat mengelola progres mereka sendiri
CREATE POLICY "Users can view own progress"
    ON public.user_progress FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own progress"
    ON public.user_progress FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own progress"
    ON public.user_progress FOR UPDATE
    USING (auth.uid() = user_id);

-- 4. Quiz Attempts: Pengguna hanya dapat melihat dan menambah percobaan kuis mereka
CREATE POLICY "Users can view own quiz attempts"
    ON public.quiz_attempts FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own quiz attempts"
    ON public.quiz_attempts FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- 5. Speech Attempts: Pengguna hanya dapat melihat dan menambah rekaman suara mereka
CREATE POLICY "Users can view own speech attempts"
    ON public.speech_attempts FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own speech attempts"
    ON public.speech_attempts FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- 6. Coin Ledger: Pengguna hanya dapat membaca transaksi koin mereka
CREATE POLICY "Users can view own coin ledger"
    ON public.coin_ledger FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own coin transactions"
    ON public.coin_ledger FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- 7. Feedback: Pengguna terautentikasi dapat mengirim umpan balik
CREATE POLICY "Anyone authenticated can insert feedback"
    ON public.feedback FOR INSERT
    WITH CHECK (auth.uid() = user_id OR user_id IS NULL);

-- ====================================================================
-- TRIGGERS & FUNCTIONS
-- ====================================================================

-- Trigger otomatis saat user baru mendaftar di auth.users -> buat profil publik
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (id, full_name, avatar_url, coins, streak, total_xp)
    VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data->>'full_name', 'Siswa Mandarin'),
        COALESCE(NEW.raw_user_meta_data->>'avatar_url', ''),
        50, -- Bonus koin awal
        1,  -- Streak awal
        0
    );
    -- Catat transaksi koin awal
    INSERT INTO public.coin_ledger (user_id, amount, transaction_type, description)
    VALUES (NEW.id, 50, 'initial_bonus', 'Bonus koin selamat datang');
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Trigger untuk sinkronisasi saldo koin di profiles setiap ada transaksi di coin_ledger
CREATE OR REPLACE FUNCTION public.sync_user_coin_balance()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE public.profiles
    SET coins = coins + NEW.amount,
        updated_at = NOW()
    WHERE id = NEW.user_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_coin_transaction ON public.coin_ledger;
CREATE TRIGGER on_coin_transaction
    AFTER INSERT ON public.coin_ledger
    FOR EACH ROW EXECUTE FUNCTION public.sync_user_coin_balance();
