-- Imagenes para las metas de ahorro.
--
-- El archivo vive en Supabase Storage y la tabla solo guarda la RUTA dentro
-- del bucket (no la URL). Se guarda la ruta y no la URL porque el bucket es
-- privado: las URLs son firmadas y expiran, asi que hay que poder regenerarlas.
--
-- Guardar la imagen dentro de la tabla (bytea o base64) se descarto a
-- proposito: `saving_goals` se consulta con `select()` completo cada vez que
-- se abre Finanzas, asi que cada refresco arrastraria todas las fotos.

-- 1. Ruta de la imagen en el bucket
ALTER TABLE public.saving_goals
  ADD COLUMN IF NOT EXISTS image_path TEXT;

-- 2. Bucket privado, con limite de peso y tipos permitidos.
--    El limite tambien se valida en la app para dar un mensaje claro antes
--    de gastar la subida.
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

-- 3. Cada usuario solo toca su propia carpeta.
--    Convencion de rutas: {user_id}/{goal_id}/{image_id}.{ext}
DROP POLICY IF EXISTS "Ver mis imagenes de metas" ON storage.objects;
CREATE POLICY "Ver mis imagenes de metas" ON storage.objects
  FOR SELECT USING (
    bucket_id = 'saving-goal-images'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

DROP POLICY IF EXISTS "Subir mis imagenes de metas" ON storage.objects;
CREATE POLICY "Subir mis imagenes de metas" ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id = 'saving-goal-images'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

DROP POLICY IF EXISTS "Reemplazar mis imagenes de metas" ON storage.objects;
CREATE POLICY "Reemplazar mis imagenes de metas" ON storage.objects
  FOR UPDATE USING (
    bucket_id = 'saving-goal-images'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

DROP POLICY IF EXISTS "Borrar mis imagenes de metas" ON storage.objects;
CREATE POLICY "Borrar mis imagenes de metas" ON storage.objects
  FOR DELETE USING (
    bucket_id = 'saving-goal-images'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );
