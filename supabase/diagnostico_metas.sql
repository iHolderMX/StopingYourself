-- ============================================================
-- DIAGNOSTICO: por que no se puede guardar una meta de ahorro
-- ============================================================
-- Corre este script en el SQL Editor de Supabase y revisa los resultados.
-- No modifica nada, solo reporta el estado actual.

-- 1. Columnas reales de saving_goals.
--    Debe aparecer 'image_path'. Si falta, la migracion no se aplico.
SELECT 'COLUMNAS' AS chequeo, column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'saving_goals'
ORDER BY ordinal_position;

-- 2. RLS activo en la tabla.
SELECT 'RLS TABLA' AS chequeo, relname, relrowsecurity AS rls_activo
FROM pg_class
WHERE oid = 'public.saving_goals'::regclass;

-- 3. Politicas de saving_goals.
--    Deben salir 4: SELECT, INSERT, UPDATE, DELETE.
--    Si no sale la de INSERT, ese es el motivo del error de permisos.
SELECT 'POLITICAS TABLA' AS chequeo, policyname, cmd, qual, with_check
FROM pg_policies
WHERE schemaname = 'public' AND tablename = 'saving_goals';

-- 4. Bucket de imagenes.
--    Debe salir una fila con id = 'saving-goal-images'.
SELECT 'BUCKET' AS chequeo, id, public, file_size_limit, allowed_mime_types
FROM storage.buckets
WHERE id = 'saving-goal-images';

-- 5. Politicas del bucket sobre storage.objects.
--    Deben salir 4 con nombres '... mis imagenes de metas'.
SELECT 'POLITICAS STORAGE' AS chequeo, policyname, cmd
FROM pg_policies
WHERE schemaname = 'storage' AND tablename = 'objects'
  AND policyname ILIKE '%imagenes de metas%';
