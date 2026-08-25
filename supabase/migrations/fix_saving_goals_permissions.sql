-- ============================================================
-- REPARACION: permisos de metas de ahorro + bucket de imagenes
-- ============================================================
-- Idempotente: se puede correr varias veces sin romper nada.
-- Cubre el error "no tienes permiso para esta operacion" al guardar una meta.

-- ── 1. Tabla y columna ──────────────────────────────────────
-- Por si la tabla no existia o le falta la columna de la imagen.
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

ALTER TABLE public.saving_goals
  ADD COLUMN IF NOT EXISTS image_path TEXT;

-- ── 2. Politicas de la tabla ────────────────────────────────
ALTER TABLE public.saving_goals ENABLE ROW LEVEL SECURITY;

-- Se recrean todas para que queden iguales aunque una haya quedado a medias.
DROP POLICY IF EXISTS "Ver metas propias" ON public.saving_goals;
CREATE POLICY "Ver metas propias" ON public.saving_goals
  FOR SELECT TO authenticated USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Insertar meta propia" ON public.saving_goals;
CREATE POLICY "Insertar meta propia" ON public.saving_goals
  FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Actualizar meta propia" ON public.saving_goals;
CREATE POLICY "Actualizar meta propia" ON public.saving_goals
  FOR UPDATE TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Eliminar meta propia" ON public.saving_goals;
CREATE POLICY "Eliminar meta propia" ON public.saving_goals
  FOR DELETE TO authenticated USING (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS idx_saving_goals_user_id
  ON public.saving_goals(user_id);

-- ── 3. Bucket de imagenes ───────────────────────────────────
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'saving-goal-images',
  'saving-goal-images',
  false,
  5242880,  -- 5 MB
  ARRAY['image/jpeg', 'image/png', 'image/webp']
)
ON CONFLICT (id) DO UPDATE SET
  file_size_limit    = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types;

-- ── 4. Politicas del bucket ─────────────────────────────────
-- Ruta esperada: {user_id}/{goal_id}/{image_id}.{ext}
-- El primer segmento debe ser el id del usuario.
DROP POLICY IF EXISTS "Ver mis imagenes de metas" ON storage.objects;
CREATE POLICY "Ver mis imagenes de metas" ON storage.objects
  FOR SELECT TO authenticated USING (
    bucket_id = 'saving-goal-images'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

DROP POLICY IF EXISTS "Subir mis imagenes de metas" ON storage.objects;
CREATE POLICY "Subir mis imagenes de metas" ON storage.objects
  FOR INSERT TO authenticated WITH CHECK (
    bucket_id = 'saving-goal-images'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

DROP POLICY IF EXISTS "Reemplazar mis imagenes de metas" ON storage.objects;
CREATE POLICY "Reemplazar mis imagenes de metas" ON storage.objects
  FOR UPDATE TO authenticated
  USING (
    bucket_id = 'saving-goal-images'
    AND (storage.foldername(name))[1] = auth.uid()::text
  )
  WITH CHECK (
    bucket_id = 'saving-goal-images'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

DROP POLICY IF EXISTS "Borrar mis imagenes de metas" ON storage.objects;
CREATE POLICY "Borrar mis imagenes de metas" ON storage.objects
  FOR DELETE TO authenticated USING (
    bucket_id = 'saving-goal-images'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- ── 5. Verificacion ─────────────────────────────────────────
SELECT 'Politicas de la tabla' AS que, count(*) AS total
FROM pg_policies
WHERE schemaname = 'public' AND tablename = 'saving_goals'
UNION ALL
SELECT 'Politicas del bucket', count(*)
FROM pg_policies
WHERE schemaname = 'storage' AND tablename = 'objects'
  AND policyname ILIKE '%imagenes de metas%'
UNION ALL
SELECT 'Columna image_path', count(*)
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'saving_goals'
  AND column_name = 'image_path';
-- Esperado: 4, 4, 1
