-- Modulo "Gasto Diario": gastos del dia por categoria.
-- Es informativo: por ahora NO afecta los calculos de finanzas.
--
-- El script es idempotente y auto-reparable: puedes volver a correrlo sobre
-- una tabla ya existente y solo agregara lo que falte (columnas, FK, indices).

CREATE TABLE IF NOT EXISTS public.daily_expenses (
  id TEXT PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  category TEXT NOT NULL DEFAULT 'Otros',
  name TEXT NOT NULL DEFAULT '',
  amount NUMERIC(10, 2) NOT NULL DEFAULT 0,
  spent_on DATE NOT NULL DEFAULT CURRENT_DATE,
  is_recurring BOOLEAN NOT NULL DEFAULT FALSE,
  recurring_id TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Un cargo recurrente se repite todos los dias. Una fila con recurring_id
-- apunta a su plantilla y guarda el monto distinto de un dia puntual.
ALTER TABLE public.daily_expenses
  ADD COLUMN IF NOT EXISTS is_recurring BOOLEAN NOT NULL DEFAULT FALSE;

ALTER TABLE public.daily_expenses
  ADD COLUMN IF NOT EXISTS recurring_id TEXT;

-- FK autorreferencial (idempotente).
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'daily_expenses_recurring_id_fkey'
      AND conrelid = 'public.daily_expenses'::regclass
  ) THEN
    ALTER TABLE public.daily_expenses
      ADD CONSTRAINT daily_expenses_recurring_id_fkey
      FOREIGN KEY (recurring_id) REFERENCES public.daily_expenses(id)
      ON DELETE CASCADE;
  END IF;
END $$;

-- Una sola excepcion por (cargo recurrente, dia).
CREATE UNIQUE INDEX IF NOT EXISTS idx_daily_expenses_override
  ON public.daily_expenses(recurring_id, spent_on)
  WHERE recurring_id IS NOT NULL;

-- Permisos base sobre la tabla (evita errores de "permission denied").
GRANT USAGE ON SCHEMA public TO authenticated, service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.daily_expenses TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.daily_expenses TO service_role;

ALTER TABLE public.daily_expenses ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Ver gastos diarios propios" ON public.daily_expenses;
CREATE POLICY "Ver gastos diarios propios" ON public.daily_expenses
  FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Insertar gasto diario propio" ON public.daily_expenses;
CREATE POLICY "Insertar gasto diario propio" ON public.daily_expenses
  FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Actualizar gasto diario propio" ON public.daily_expenses;
CREATE POLICY "Actualizar gasto diario propio" ON public.daily_expenses
  FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Eliminar gasto diario propio" ON public.daily_expenses;
CREATE POLICY "Eliminar gasto diario propio" ON public.daily_expenses
  FOR DELETE USING (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS idx_daily_expenses_user_id
  ON public.daily_expenses(user_id);

CREATE INDEX IF NOT EXISTS idx_daily_expenses_user_spent_on
  ON public.daily_expenses(user_id, spent_on);

-- ─────────────────────────────────────────────────────────────────
-- Categorias personalizadas del gasto diario.
-- El usuario puede agregar sus propias categorias (ademas de las
-- que vienen por defecto). Cada usuario ve solo las suyas.
CREATE TABLE IF NOT EXISTS public.daily_expense_categories (
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  sort_order INT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (user_id, name)
);

GRANT USAGE ON SCHEMA public TO authenticated, service_role;
GRANT SELECT, INSERT, UPDATE, DELETE
  ON public.daily_expense_categories TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE
  ON public.daily_expense_categories TO service_role;

ALTER TABLE public.daily_expense_categories ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Ver categorias propias"
  ON public.daily_expense_categories;
CREATE POLICY "Ver categorias propias"
  ON public.daily_expense_categories
  FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Insertar categoria propia"
  ON public.daily_expense_categories;
CREATE POLICY "Insertar categoria propia"
  ON public.daily_expense_categories
  FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Actualizar categoria propia"
  ON public.daily_expense_categories;
CREATE POLICY "Actualizar categoria propia"
  ON public.daily_expense_categories
  FOR UPDATE USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Eliminar categoria propia"
  ON public.daily_expense_categories;
CREATE POLICY "Eliminar categoria propia"
  ON public.daily_expense_categories
  FOR DELETE USING (auth.uid() = user_id);
