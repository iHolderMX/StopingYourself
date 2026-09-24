-- ============================================================
-- Fase 3: paso configurable en registros diarios
-- Agrega step_value a daily_activities para que cada registro
-- generado desde una plantilla conserve su incremento (+/-).
-- ============================================================
ALTER TABLE public.daily_activities
  ADD COLUMN IF NOT EXISTS step_value NUMERIC NOT NULL DEFAULT 1;

-- ============================================================
-- GRANTs (regla del proyecto: siempre incluirlos; idempotente)
-- ============================================================
GRANT SELECT, INSERT, UPDATE, DELETE ON public.daily_activities TO authenticated;
GRANT USAGE ON SCHEMA public TO authenticated;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO authenticated;
