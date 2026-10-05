-- ============================================================
-- FIX: asegurar que TODAS las columnas nuevas de
-- activity_templates existen en Supabase.
-- Algunas migraciones previas (add_activity_reminders.sql y
-- add_activity_grace_days.sql) definieron columnas que
-- probablemente NO se aplicaron al entorno remoto, por lo
-- que PostgREST devuelve PGRST204 ("no se encuentra la
-- columna X en el schema cache").
--
-- Este script es IDEMPOTENTE (usa IF NOT EXISTS en todos
-- los ALTER TABLE y GRANTs) y puede ejecutarse varias veces
-- sin romper nada.
-- ============================================================

ALTER TABLE public.activity_templates
  ADD COLUMN IF NOT EXISTS step_value NUMERIC NOT NULL DEFAULT 1;

ALTER TABLE public.activity_templates
  ADD COLUMN IF NOT EXISTS category TEXT;

ALTER TABLE public.activity_templates
  ADD COLUMN IF NOT EXISTS grace_days INTEGER NOT NULL DEFAULT 0;

ALTER TABLE public.activity_templates
  ADD COLUMN IF NOT EXISTS reminder_enabled BOOLEAN NOT NULL DEFAULT false;

ALTER TABLE public.activity_templates
  ADD COLUMN IF NOT EXISTS reminder_time TEXT;

ALTER TABLE public.activity_templates
  ADD COLUMN IF NOT EXISTS is_archived BOOLEAN NOT NULL DEFAULT false;

-- ============================================================
-- GRANTs (regla del proyecto: siempre incluirlos)
-- ============================================================
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.activity_templates TO authenticated;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO authenticated;
