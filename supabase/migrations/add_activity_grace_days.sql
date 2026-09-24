-- ============================================================
-- Fase 5: rachas con días de gracia
-- Agrega grace_days a activity_templates (cuántos fallos
-- consecutivos se toleran sin romper la racha).
-- ============================================================
ALTER TABLE public.activity_templates
  ADD COLUMN IF NOT EXISTS grace_days INTEGER NOT NULL DEFAULT 0;

-- ============================================================
-- GRANTs (regla del proyecto: siempre incluirlos; idempotente)
-- ============================================================
GRANT SELECT, INSERT, UPDATE, DELETE ON public.activity_templates TO authenticated;
GRANT USAGE ON SCHEMA public TO authenticated;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO authenticated;
