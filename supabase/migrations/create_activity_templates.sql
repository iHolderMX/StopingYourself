-- ============================================================
-- Plantillas de actividades (hábitos recurrentes)
-- Separa la DEFINICIÓN de un hábito del REGISTRO diario.
-- ============================================================
CREATE TABLE IF NOT EXISTS public.activity_templates (
  id TEXT PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  activity_type TEXT NOT NULL DEFAULT 'boolean' CHECK (activity_type IN ('boolean', 'numeric')),
  target_value NUMERIC,
  unit TEXT,
  step_value NUMERIC NOT NULL DEFAULT 1,
  category TEXT,
  frequency_type TEXT NOT NULL DEFAULT 'daily' CHECK (frequency_type IN ('daily', 'weekly', 'monthly', 'custom')),
  frequency_config JSONB NOT NULL DEFAULT '{}'::jsonb,
  position INTEGER NOT NULL DEFAULT 0,
  priority INTEGER NOT NULL DEFAULT 0,
  is_archived BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.activity_templates ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Ver plantillas propias" ON public.activity_templates;
CREATE POLICY "Ver plantillas propias" ON public.activity_templates
  FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Insertar plantilla propia" ON public.activity_templates;
CREATE POLICY "Insertar plantilla propia" ON public.activity_templates
  FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Actualizar plantilla propia" ON public.activity_templates;
CREATE POLICY "Actualizar plantilla propia" ON public.activity_templates
  FOR UPDATE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Eliminar plantilla propia" ON public.activity_templates;
CREATE POLICY "Eliminar plantilla propia" ON public.activity_templates
  FOR DELETE USING (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS idx_activity_templates_user_id ON public.activity_templates(user_id);

-- Vincula (opcionalmente) un registro diario a su plantilla de origen.
-- ON DELETE SET NULL: al borrar una plantilla no se pierde el historial.
ALTER TABLE public.daily_activities
  ADD COLUMN IF NOT EXISTS template_id TEXT REFERENCES public.activity_templates(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_daily_activities_template_id ON public.daily_activities(template_id);

-- ============================================================
-- GRANTs (permisos de rol 'authenticated')
-- Sin esto, las RLS ni se evalúan (error 42501).
-- ============================================================
GRANT SELECT, INSERT, UPDATE, DELETE ON public.activity_templates TO authenticated;
GRANT USAGE ON SCHEMA public TO authenticated;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO authenticated;
