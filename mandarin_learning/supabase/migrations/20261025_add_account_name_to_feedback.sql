-- ====================================================================
-- MIGRATION: 20261025_add_account_name_to_feedback.sql
-- Menambahkan kolom account_name pada tabel feedback agar nama akun pengirim tersimpan langsung
-- ====================================================================

ALTER TABLE public.feedback ADD COLUMN IF NOT EXISTS account_name TEXT;

-- Index untuk pencarian berdasarkan account_name jika diperlukan
CREATE INDEX IF NOT EXISTS idx_feedback_account_name ON public.feedback(account_name);
