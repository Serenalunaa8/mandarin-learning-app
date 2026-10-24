-- Jalankan sekali di Supabase SQL Editor untuk mengaktifkan riwayat AI Tutor.
-- Aplikasi menggunakan app_users (autentikasi khusus), sehingga user_id disimpan
-- sebagai ID akun aplikasi dan setiap query Flutter difilter dengan ID tersebut.

CREATE TABLE IF NOT EXISTS public.ai_conversations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id TEXT NOT NULL REFERENCES public.app_users(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    messages JSONB NOT NULL DEFAULT '[]'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_ai_conversations_user_updated
    ON public.ai_conversations(user_id, updated_at DESC);

ALTER TABLE public.ai_conversations ENABLE ROW LEVEL SECURITY;

-- Mengikuti pola tabel aplikasi lain yang memakai Supabase anon key dan
-- autentikasi app_users. Flutter selalu membatasi read/update/delete ke user_id.
DROP POLICY IF EXISTS "ai_conversations: select" ON public.ai_conversations;
CREATE POLICY "ai_conversations: select" ON public.ai_conversations
    FOR SELECT TO anon, authenticated USING (true);

DROP POLICY IF EXISTS "ai_conversations: insert" ON public.ai_conversations;
CREATE POLICY "ai_conversations: insert" ON public.ai_conversations
    FOR INSERT TO anon, authenticated
    WITH CHECK (EXISTS (
        SELECT 1 FROM public.app_users WHERE app_users.id = ai_conversations.user_id
    ));

DROP POLICY IF EXISTS "ai_conversations: update" ON public.ai_conversations;
CREATE POLICY "ai_conversations: update" ON public.ai_conversations
    FOR UPDATE TO anon, authenticated
    USING (true)
    WITH CHECK (EXISTS (
        SELECT 1 FROM public.app_users WHERE app_users.id = ai_conversations.user_id
    ));

DROP POLICY IF EXISTS "ai_conversations: delete" ON public.ai_conversations;
CREATE POLICY "ai_conversations: delete" ON public.ai_conversations
    FOR DELETE TO anon, authenticated USING (true);
