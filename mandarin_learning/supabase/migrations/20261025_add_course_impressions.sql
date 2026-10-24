-- ====================================================================
-- MIGRATION: 20261025_add_course_impressions.sql
-- TABEL COURSE_IMPRESSIONS (Kesan & Pesan Mata Kuliah Pemrograman Aplikasi Mobile)
-- ====================================================================

CREATE TABLE IF NOT EXISTS public.course_impressions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id TEXT REFERENCES public.app_users(id) ON DELETE SET NULL,
    account_name TEXT NOT NULL,
    message TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Memastikan kolom kompatibel jika tabel dibuat dari versi sebelumnya
ALTER TABLE public.course_impressions ADD COLUMN IF NOT EXISTS account_name TEXT;
ALTER TABLE public.course_impressions ADD COLUMN IF NOT EXISTS message TEXT;

-- Index pencarian dan penyortiran
CREATE INDEX IF NOT EXISTS idx_course_impressions_user ON public.course_impressions(user_id);
CREATE INDEX IF NOT EXISTS idx_course_impressions_created ON public.course_impressions(created_at DESC);

-- Enable Row Level Security (RLS)
ALTER TABLE public.course_impressions ENABLE ROW LEVEL SECURITY;

-- Hapus policy lama terlebih dahulu agar tidak bentrok saat query dijalankan ulang
DROP POLICY IF EXISTS "course_impressions: select" ON public.course_impressions;
DROP POLICY IF EXISTS "course_impressions: insert" ON public.course_impressions;

-- Kebijakan Akses (RLS Policies)
CREATE POLICY "course_impressions: select" ON public.course_impressions
    FOR SELECT TO anon, authenticated USING (true);

CREATE POLICY "course_impressions: insert" ON public.course_impressions
    FOR INSERT TO anon, authenticated WITH CHECK (true);
