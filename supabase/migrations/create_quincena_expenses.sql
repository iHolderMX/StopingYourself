-- Crear tabla quincena_expenses (gastos planeados de la proxima quincena)
CREATE TABLE IF NOT EXISTS public.quincena_expenses (
  id TEXT PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  amount NUMERIC(10, 2) NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Permisos base sobre la tabla (evita errores de "permission denied")
GRANT USAGE ON SCHEMA public TO authenticated, service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.quincena_expenses TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.quincena_expenses TO service_role;

ALTER TABLE public.quincena_expenses ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Ver gastos de quincena propios" ON public.quincena_expenses;
CREATE POLICY "Ver gastos de quincena propios" ON public.quincena_expenses
  FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Insertar gasto de quincena propio" ON public.quincena_expenses;
CREATE POLICY "Insertar gasto de quincena propio" ON public.quincena_expenses
  FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Actualizar gasto de quincena propio" ON public.quincena_expenses;
CREATE POLICY "Actualizar gasto de quincena propio" ON public.quincena_expenses
  FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Eliminar gasto de quincena propio" ON public.quincena_expenses;
CREATE POLICY "Eliminar gasto de quincena propio" ON public.quincena_expenses
  FOR DELETE USING (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS idx_quincena_expenses_user_id
  ON public.quincena_expenses(user_id);
