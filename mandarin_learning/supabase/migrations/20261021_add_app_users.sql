-- Migration: Add app_users table for custom encrypted auth & session
CREATE TABLE IF NOT EXISTS public.app_users (
    id TEXT PRIMARY KEY,
    username TEXT UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    full_name TEXT NOT NULL,
    email TEXT,
    current_hsk_level INT DEFAULT 1 CHECK (current_hsk_level BETWEEN 1 AND 6),
    streak INT DEFAULT 1,
    total_xp INT DEFAULT 0,
    coins INT DEFAULT 50 CHECK (coins >= 0),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_app_users_username ON public.app_users(username);

ALTER TABLE public.app_users ENABLE ROW LEVEL SECURITY;

DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE tablename = 'app_users' AND policyname = 'Allow select on app_users'
    ) THEN
        CREATE POLICY "Allow select on app_users" ON public.app_users FOR SELECT USING (true);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE tablename = 'app_users' AND policyname = 'Allow insert on app_users'
    ) THEN
        CREATE POLICY "Allow insert on app_users" ON public.app_users FOR INSERT WITH CHECK (true);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE tablename = 'app_users' AND policyname = 'Allow update on app_users'
    ) THEN
        CREATE POLICY "Allow update on app_users" ON public.app_users FOR UPDATE USING (true);
    END IF;
END $$;
