-- ============================================================
-- Migracion: Permitir actualizar registros de recaidas
-- Objetivo: Posibilitar registrar/editar recaidas pasadas
-- ============================================================

-- Politica RLS UPDATE para relapse_records
DROP POLICY IF EXISTS "Actualizar recaida propia" ON public.relapse_records;
CREATE POLICY "Actualizar recaida propia" ON public.relapse_records
  FOR UPDATE USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);
