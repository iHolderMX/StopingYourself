-- Fondo de Emergencia
CREATE TABLE IF NOT EXISTS public.emergency_funds (
  id TEXT PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  source_record_id TEXT NOT NULL,
  amount NUMERIC(12, 2) NOT NULL DEFAULT 0,
  annual_yield NUMERIC(5, 2) NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.emergency_funds ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Ver fondos propios" ON public.emergency_funds;
CREATE POLICY "Ver fondos propios" ON public.emergency_funds
  FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Insertar fondo propio" ON public.emergency_funds;
CREATE POLICY "Insertar fondo propio" ON public.emergency_funds
  FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Actualizar fondo propio" ON public.emergency_funds;
CREATE POLICY "Actualizar fondo propio" ON public.emergency_funds
  FOR UPDATE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Eliminar fondo propio" ON public.emergency_funds;
CREATE POLICY "Eliminar fondo propio" ON public.emergency_funds
  FOR DELETE USING (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS idx_emergency_funds_user_id
  ON public.emergency_funds(user_id);

-- Sub-divisiones del fondo de emergencia
CREATE TABLE IF NOT EXISTS public.emergency_fund_entries (
  id TEXT PRIMARY KEY,
  emergency_fund_id TEXT NOT NULL REFERENCES public.emergency_funds(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  amount NUMERIC(12, 2) NOT NULL DEFAULT 0,
  annual_yield NUMERIC(5, 2) NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.emergency_fund_entries ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Ver entries propias" ON public.emergency_fund_entries;
CREATE POLICY "Ver entries propias" ON public.emergency_fund_entries
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.emergency_funds
      WHERE emergency_funds.id = emergency_fund_entries.emergency_fund_id
      AND emergency_funds.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Insertar entry propia" ON public.emergency_fund_entries;
CREATE POLICY "Insertar entry propia" ON public.emergency_fund_entries
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.emergency_funds
      WHERE emergency_funds.id = emergency_fund_entries.emergency_fund_id
      AND emergency_funds.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Actualizar entry propia" ON public.emergency_fund_entries;
CREATE POLICY "Actualizar entry propia" ON public.emergency_fund_entries
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM public.emergency_funds
      WHERE emergency_funds.id = emergency_fund_entries.emergency_fund_id
      AND emergency_funds.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Eliminar entry propia" ON public.emergency_fund_entries;
CREATE POLICY "Eliminar entry propia" ON public.emergency_fund_entries
  FOR DELETE USING (
    EXISTS (
      SELECT 1 FROM public.emergency_funds
      WHERE emergency_funds.id = emergency_fund_entries.emergency_fund_id
      AND emergency_funds.user_id = auth.uid()
    )
  );

CREATE INDEX IF NOT EXISTS idx_emergency_fund_entries_fund_id
  ON public.emergency_fund_entries(emergency_fund_id);
