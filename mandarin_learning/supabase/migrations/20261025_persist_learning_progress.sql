-- Persist lesson completion, quiz mastery, favorites, and daily activity.

ALTER TABLE public.user_progress
    ADD COLUMN IF NOT EXISTS is_quiz_mastered BOOLEAN NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS is_favorite BOOLEAN NOT NULL DEFAULT false;

ALTER TABLE public.app_users
    ADD COLUMN IF NOT EXISTS last_active_date DATE NOT NULL DEFAULT CURRENT_DATE;

ALTER TABLE public.user_progress ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "user_progress: select" ON public.user_progress;
DROP POLICY IF EXISTS "user_progress: insert" ON public.user_progress;
DROP POLICY IF EXISTS "user_progress: update" ON public.user_progress;

CREATE POLICY "user_progress: select" ON public.user_progress
    FOR SELECT TO anon, authenticated USING (true);

CREATE POLICY "user_progress: insert" ON public.user_progress
    FOR INSERT TO anon, authenticated WITH CHECK (true);

CREATE POLICY "user_progress: update" ON public.user_progress
    FOR UPDATE TO anon, authenticated USING (true) WITH CHECK (true);
