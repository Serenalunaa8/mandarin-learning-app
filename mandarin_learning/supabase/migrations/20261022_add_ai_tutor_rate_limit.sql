CREATE TABLE IF NOT EXISTS public.ai_tutor_request_windows (
    client_key TEXT PRIMARY KEY,
    window_started_at TIMESTAMPTZ NOT NULL,
    request_count INT NOT NULL CHECK (request_count > 0)
);

ALTER TABLE public.ai_tutor_request_windows ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.ai_tutor_request_windows FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.consume_ai_tutor_quota(
    p_client_key TEXT,
    p_window_seconds INT,
    p_max_requests INT
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
    allowed BOOLEAN;
BEGIN
    IF p_window_seconds <= 0 OR p_max_requests <= 0 OR length(p_client_key) <> 64 THEN
        RAISE EXCEPTION 'Invalid AI quota parameters';
    END IF;

    INSERT INTO public.ai_tutor_request_windows AS current_window (
        client_key,
        window_started_at,
        request_count
    )
    VALUES (p_client_key, now(), 1)
    ON CONFLICT (client_key) DO UPDATE
    SET window_started_at = CASE
            WHEN current_window.window_started_at <
                now() - make_interval(secs => p_window_seconds)
            THEN now()
            ELSE current_window.window_started_at
        END,
        request_count = CASE
            WHEN current_window.window_started_at <
                now() - make_interval(secs => p_window_seconds)
            THEN 1
            ELSE current_window.request_count + 1
        END
    RETURNING request_count <= p_max_requests INTO allowed;

    RETURN allowed;
END;
$$;

REVOKE ALL ON FUNCTION public.consume_ai_tutor_quota(TEXT, INT, INT)
    FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.consume_ai_tutor_quota(TEXT, INT, INT)
    TO service_role;
