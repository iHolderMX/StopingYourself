-- Crear tabla saving_goals (no existia en Supabase)
CREATE TABLE IF NOT EXISTS public.saving_goals (
  id TEXT PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  target_amount NUMERIC(12, 2) NOT NULL DEFAULT 0,
  current_amount NUMERIC(12, 2) NOT NULL DEFAULT 0,
  url TEXT,
  is_completed BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.saving_goals ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Ver metas propias" ON public.saving_goals;
CREATE POLICY "Ver metas propias" ON public.saving_goals
  FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Insertar meta propia" ON public.saving_goals;
CREATE POLICY "Insertar meta propia" ON public.saving_goals
  FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Actualizar meta propia" ON public.saving_goals;
CREATE POLICY "Actualizar meta propia" ON public.saving_goals
  FOR UPDATE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Eliminar meta propia" ON public.saving_goals;
CREATE POLICY "Eliminar meta propia" ON public.saving_goals
  FOR DELETE USING (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS idx_saving_goals_user_id
  ON public.saving_goals(user_id);

-- Agregar politica DELETE para salary_settings (faltaba)
DROP POLICY IF EXISTS "Eliminar salario propio" ON public.salary_settings;
CREATE POLICY "Eliminar salario propio" ON public.salary_settings
  FOR DELETE USING (auth.uid() = user_id);
