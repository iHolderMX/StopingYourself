-- ============================================================
-- FASE 8: Recordatorios (configuración en BD/UI)
-- ============================================================
-- Agrega la configuración de recordatorio a cada hábito.
--   reminder_enabled : si el recordatorio está activo.
--   reminder_time    : hora local en formato "HH:MM" (24h), nullable.
-- Idempotente.

ALTER TABLE public.activity_templates
  ADD COLUMN IF NOT EXISTS reminder_enabled BOOLEAN NOT NULL DEFAULT false;

ALTER TABLE public.activity_templates
  ADD COLUMN IF NOT EXISTS reminder_time TEXT;

-- Permisos (siempre incluirlos por el histórico de fallas 42501).
GRANT SELECT, INSERT, UPDATE, DELETE ON public.activity_templates TO authenticated;
GRANT USAGE ON SCHEMA public TO authenticated;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO authenticated;
