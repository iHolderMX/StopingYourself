-- ============================================================
-- REPARACION 2: GRANTs de las tablas de finanzas
-- ============================================================
-- Postgres tiene DOS capas de permisos y ambas fallan con el codigo 42501:
--   1. GRANT: si el rol 'authenticated' puede tocar la tabla.
--   2. RLS:   que filas puede tocar.
-- Sin el GRANT las politicas RLS ni se llegan a evaluar, asi que recrearlas
-- no sirve de nada. Este script arregla la capa 1.
--
-- Las tablas creadas a mano por SQL pueden quedarse sin los GRANT que
-- Supabase aplica por defecto a las tablas nuevas.
--
-- Idempotente: se puede correr varias veces sin romper nada.

-- ── 1. Antes: que permisos hay hoy ──────────────────────────
SELECT
  'ANTES' AS momento,
  table_name,
  grantee,
  string_agg(privilege_type, ', ' ORDER BY privilege_type) AS permisos
FROM information_schema.role_table_grants
WHERE table_schema = 'public'
  AND grantee IN ('authenticated', 'anon')
  AND table_name IN (
    'saving_goals', 'money_records', 'fixed_expenses', 'salary_settings',
    'debts', 'debt_payments', 'monthly_payments', 'quincena_expenses',
    'emergency_funds', 'emergency_fund_entries'
  )
GROUP BY table_name, grantee
ORDER BY table_name, grantee;

-- ── 2. Conceder permisos, tabla por tabla ───────────────────
-- Se hace en un bloque que primero verifica que la tabla exista.
-- Si se pusieran los GRANT sueltos, una tabla inexistente abortaria el
-- script completo (el editor lo corre en una transaccion) y no se aplicaria
-- ninguno, ni el de saving_goals.
DO $$
DECLARE
  tabla  text;
  tablas text[] := ARRAY[
    'saving_goals', 'money_records', 'fixed_expenses', 'salary_settings',
    'debts', 'debt_payments', 'monthly_payments', 'quincena_expenses',
    'emergency_funds', 'emergency_fund_entries'
  ];
BEGIN
  FOREACH tabla IN ARRAY tablas LOOP
    IF EXISTS (
      SELECT 1 FROM information_schema.tables
      WHERE table_schema = 'public' AND table_name = tabla
    ) THEN
      EXECUTE format(
        'GRANT SELECT, INSERT, UPDATE, DELETE ON public.%I TO authenticated',
        tabla
      );
      RAISE NOTICE 'OK      -> GRANT aplicado en %', tabla;
    ELSE
      RAISE NOTICE 'OMITIDA -> la tabla % no existe', tabla;
    END IF;
  END LOOP;
END $$;

-- El rol necesita poder usar el esquema, no solo las tablas.
GRANT USAGE ON SCHEMA public TO authenticated;

-- ── 3. Que las tablas futuras nazcan con permisos ───────────
-- Evita repetir este problema la proxima vez que se cree una tabla a mano.
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO authenticated;

-- ── 4. Despues: confirmar que quedaron ──────────────────────
-- Cada tabla existente debe mostrar: DELETE, INSERT, SELECT, UPDATE
SELECT
  'DESPUES' AS momento,
  table_name,
  string_agg(privilege_type, ', ' ORDER BY privilege_type) AS permisos
FROM information_schema.role_table_grants
WHERE table_schema = 'public'
  AND grantee = 'authenticated'
  AND table_name IN (
    'saving_goals', 'money_records', 'fixed_expenses', 'salary_settings',
    'debts', 'debt_payments', 'monthly_payments', 'quincena_expenses',
    'emergency_funds', 'emergency_fund_entries'
  )
GROUP BY table_name
ORDER BY table_name;
