-- ============================================================
-- StopingYourself - Schema SQL para Supabase
-- Ejecutar en: SQL Editor de Supabase (https://supabase.com/dashboard)
-- ============================================================

-- 1. Tabla de perfiles de usuario
CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT NOT NULL,
  display_name TEXT NOT NULL DEFAULT 'Usuario',
  avatar_url TEXT,
  streak INTEGER NOT NULL DEFAULT 0,
  total_xp INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2. Tabla de categorías
CREATE TABLE IF NOT EXISTS public.categories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  emoji TEXT NOT NULL DEFAULT '📚',
  color_hex TEXT NOT NULL DEFAULT '#D4AF37',
  sort_order INTEGER NOT NULL DEFAULT 0
);

-- 3. Tabla de lecciones
CREATE TABLE IF NOT EXISTS public.lessons (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  category_id UUID NOT NULL REFERENCES public.categories(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  difficulty_level INTEGER NOT NULL DEFAULT 1 CHECK (difficulty_level BETWEEN 1 AND 3),
  sort_order INTEGER NOT NULL DEFAULT 0,
  content JSONB DEFAULT NULL
);

-- 4. Tabla de progreso del usuario
CREATE TABLE IF NOT EXISTS public.user_progress (
  id TEXT PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  lesson_id UUID NOT NULL REFERENCES public.lessons(id) ON DELETE CASCADE,
  completed BOOLEAN NOT NULL DEFAULT false,
  score INTEGER NOT NULL DEFAULT 0,
  completed_at TIMESTAMPTZ
);

-- ============================================================
-- Índices
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_user_progress_user_id ON public.user_progress(user_id);
CREATE INDEX IF NOT EXISTS idx_user_progress_lesson_id ON public.user_progress(lesson_id);
CREATE INDEX IF NOT EXISTS idx_lessons_category_id ON public.lessons(category_id);

-- ============================================================
-- Row Level Security (RLS)
-- ============================================================

-- Profiles: usuarios leen su propio perfil, pueden insertar/actualizar el suyo
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Ver perfil propio" ON public.profiles;
CREATE POLICY "Ver perfil propio" ON public.profiles
  FOR SELECT USING (auth.uid() = id);

DROP POLICY IF EXISTS "Insertar perfil propio" ON public.profiles;
CREATE POLICY "Insertar perfil propio" ON public.profiles
  FOR INSERT WITH CHECK (auth.uid() = id);

DROP POLICY IF EXISTS "Actualizar perfil propio" ON public.profiles;
CREATE POLICY "Actualizar perfil propio" ON public.profiles
  FOR UPDATE USING (auth.uid() = id);

-- Categories: lectura pública (todos los autenticados pueden ver)
ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Ver categorías" ON public.categories;
CREATE POLICY "Ver categorías" ON public.categories
  FOR SELECT USING (auth.role() = 'authenticated');

-- Lessons: lectura pública (todos los autenticados pueden ver)
ALTER TABLE public.lessons ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Ver lecciones" ON public.lessons;
CREATE POLICY "Ver lecciones" ON public.lessons
  FOR SELECT USING (auth.role() = 'authenticated');

-- User Progress: CRUD solo del propio usuario
ALTER TABLE public.user_progress ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Ver progreso propio" ON public.user_progress;
CREATE POLICY "Ver progreso propio" ON public.user_progress
  FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Insertar progreso propio" ON public.user_progress;
CREATE POLICY "Insertar progreso propio" ON public.user_progress
  FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Actualizar progreso propio" ON public.user_progress;
CREATE POLICY "Actualizar progreso propio" ON public.user_progress
  FOR UPDATE USING (auth.uid() = user_id);

-- ============================================================
-- Trigger: Crear perfil automáticamente al registrarse
-- ============================================================
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, email, display_name)
  VALUES (NEW.id, NEW.email, COALESCE(NEW.raw_user_meta_data ->> 'display_name', 'Usuario'));
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ============================================================
-- Datos semilla (opcional)
-- ============================================================
INSERT INTO public.categories (name, emoji, color_hex, sort_order) VALUES
  ('Ansiedad', '🧠', '#8B5A2B', 1),
  ('Autoestima', '💪', '#D4AF37', 2),
  ('Hábitos', '🌱', '#228B22', 3),
  ('Mindfulness', '🧘', '#808080', 4)
ON CONFLICT DO NOTHING;

-- Insertar lecciones de ejemplo para la categoría Ansiedad
DO $$
DECLARE
  ansiedad_id UUID;
  autoestima_id UUID;
  habitos_id UUID;
  mindfulness_id UUID;
BEGIN
  SELECT id INTO ansiedad_id FROM public.categories WHERE name = 'Ansiedad' LIMIT 1;
  SELECT id INTO autoestima_id FROM public.categories WHERE name = 'Autoestima' LIMIT 1;
  SELECT id INTO habitos_id FROM public.categories WHERE name = 'Hábitos' LIMIT 1;
  SELECT id INTO mindfulness_id FROM public.categories WHERE name = 'Mindfulness' LIMIT 1;

  IF ansiedad_id IS NOT NULL THEN
    INSERT INTO public.lessons (category_id, title, description, difficulty_level, sort_order, content) VALUES
    (
      ansiedad_id, 'Entendiendo la ansiedad',
      'Aprende qué es la ansiedad y cómo se manifiesta en tu cuerpo y mente.',
      1, 1,
      '{"sections":[{"type":"heading","value":"¿Qué es la ansiedad?"},{"type":"text","value":"La ansiedad es una respuesta natural del cuerpo ante situaciones que percibimos como amenazantes. Es como una alarma interna que nos prepara para actuar."},{"type":"quote","value":"La ansiedad no es tu enemiga, es un mensaje que tu cuerpo te envía."},{"type":"heading","value":"Señales comunes"},{"type":"text","value":"Palpitaciones, respiración acelerada, tensión muscular, pensamientos repetitivos y dificultad para concentrarte son algunas de las señales más comunes."}]}'::jsonb
    ),
    (
      ansiedad_id, 'Técnicas de respiración',
      'Domina la respiración diafragmática y otras técnicas para calmar la ansiedad.',
      1, 2,
      '{"sections":[{"type":"heading","value":"Respiración 4-7-8"},{"type":"text","value":"Inhala por la nariz durante 4 segundos, mantén el aire 7 segundos, exhala lentamente por la boca durante 8 segundos. Repite 4 veces."},{"type":"quote","value":"Tu respiración es el ancla que te conecta con el presente."}]}'::jsonb
    ),
    (
      ansiedad_id, 'Reestructuración cognitiva',
      'Identifica y transforma los pensamientos que alimentan tu ansiedad.',
      2, 3,
      '{"sections":[{"type":"heading","value":"¿Qué es la reestructuración cognitiva?"},{"type":"text","value":"Es una técnica que te ayuda a identificar pensamientos distorsionados y reemplazarlos por otros más realistas y equilibrados."},{"type":"heading","value":"Pasos"},{"type":"text","value":"1. Identifica el pensamiento automático. 2. Cuestiona su veracidad. 3. Busca evidencias a favor y en contra. 4. Crea un pensamiento alternativo más realista."}]}'::jsonb
    ),
    (
      ansiedad_id, 'Plan de acción personal',
      'Crea tu propio plan para manejar momentos de ansiedad intensa.',
      3, 4,
      '{"sections":[{"type":"heading","value":"Tu kit de emergencia"},{"type":"text","value":"Prepara una lista de 5 acciones que puedes hacer cuando la ansiedad aparezca: llamar a un amigo, dar un paseo, escuchar música relajante, escribir en un diario, practicar respiración."},{"type":"quote","value":"Tener un plan te da poder sobre la ansiedad."}]}'::jsonb
    )
    ON CONFLICT DO NOTHING;
  END IF;

  IF autoestima_id IS NOT NULL THEN
    INSERT INTO public.lessons (category_id, title, description, difficulty_level, sort_order, content) VALUES
    (
      autoestima_id, 'Conociendo tu valor',
      'Descubre por qué eres valioso tal y como eres, sin condiciones.',
      1, 1,
      '{"sections":[{"type":"heading","value":"Tu valor no se negocia"},{"type":"text","value":"La autoestima no depende de logros, apariencia o la opinión de otros. Es el reconocimiento de tu valor inherente como persona."},{"type":"quote","value":"Eres suficiente. No necesitas demostrar nada."}]}'::jsonb
    ),
    (
      autoestima_id, 'Diario de gratitud personal',
      'Aprende a reconocer tus cualidades y fortalezas cada día.',
      1, 2,
      '{"sections":[{"type":"heading","value":"El poder de la gratitud"},{"type":"text","value":"Cada noche, escribe 3 cosas que hiciste bien hoy y 3 cualidades tuyas que aprecias. Verás cómo cambia tu percepción en pocas semanas."}]}'::jsonb
    )
    ON CONFLICT DO NOTHING;
  END IF;

  IF habitos_id IS NOT NULL THEN
    INSERT INTO public.lessons (category_id, title, description, difficulty_level, sort_order, content) VALUES
    (
      habitos_id, 'El poder de las pequeñas acciones',
      'Cómo los micro-hábitos transforman tu vida sin esfuerzo aparente.',
      1, 1,
      '{"sections":[{"type":"heading","value":"La regla del 1%"},{"type":"text","value":"Mejorar solo un 1% cada día parece poco, pero en un año serás 37 veces mejor. Los pequeños cambios sostenidos generan grandes transformaciones."},{"type":"quote","value":"No busques cambios radicales, busca consistencia."}]}'::jsonb
    ),
    (
      habitos_id, 'Rompiendo patrones',
      'Identifica y reemplaza los hábitos que te alejan de tus objetivos.',
      2, 2,
      '{"sections":[{"type":"heading","value":"El ciclo del hábito"},{"type":"text","value":"Señal → Rutina → Recompensa. Para cambiar un hábito, mantén la señal y la recompensa, pero cambia la rutina."}]}'::jsonb
    )
    ON CONFLICT DO NOTHING;
  END IF;

  IF mindfulness_id IS NOT NULL THEN
    INSERT INTO public.lessons (category_id, title, description, difficulty_level, sort_order, content) VALUES
    (
      mindfulness_id, 'Introducción al mindfulness',
      'Aprende a vivir el presente con atención plena, sin juicios.',
      1, 1,
      '{"sections":[{"type":"heading","value":"¿Qué es mindfulness?"},{"type":"text","value":"Mindfulness es la capacidad de prestar atención al momento presente de forma intencional y sin juzgar. Es una habilidad que todos podemos entrenar."},{"type":"quote","value":"El presente es el único momento donde la vida realmente ocurre."}]}'::jsonb
    ),
    (
      mindfulness_id, 'Body scan guiado',
      'Una meditación de exploración corporal para conectar con tus sensaciones.',
      2, 2,
      '{"sections":[{"type":"heading","value":"Body Scan de 5 minutos"},{"type":"text","value":"Siéntate cómodamente. Cierra los ojos. Lleva tu atención a los pies. Nota las sensaciones sin juzgar. Sube lentamente por tobillos, piernas, caderas, abdomen, pecho, hombros, brazos, manos, cuello y cabeza."}]}'::jsonb
    )
    ON CONFLICT DO NOTHING;
  END IF;
END $$;

-- ============================================================
-- 5. Tabla de recaidas
-- ============================================================
CREATE TABLE IF NOT EXISTS public.relapse_records (
  id TEXT PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  relapse_type TEXT NOT NULL,
  custom_type TEXT,
  relapse_date TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.relapse_records ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Ver recaidas propias" ON public.relapse_records;
CREATE POLICY "Ver recaidas propias" ON public.relapse_records
  FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Insertar recaida propia" ON public.relapse_records;
CREATE POLICY "Insertar recaida propia" ON public.relapse_records
  FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Eliminar recaida propia" ON public.relapse_records;
CREATE POLICY "Eliminar recaida propia" ON public.relapse_records
  FOR DELETE USING (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS idx_relapse_user_id ON public.relapse_records(user_id);

-- ============================================================
-- 6. Tabla de dinero / ahorros
-- ============================================================
CREATE TABLE IF NOT EXISTS public.money_records (
  id TEXT PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  type TEXT NOT NULL,
  amount NUMERIC(12, 2) NOT NULL,
  annual_yield NUMERIC(5, 2) NOT NULL DEFAULT 0,
  description TEXT,
  date TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Migracion para tablas existentes (ejecutar si ya tenias registros)
ALTER TABLE public.money_records ADD COLUMN IF NOT EXISTS annual_yield NUMERIC(5, 2) NOT NULL DEFAULT 0;

ALTER TABLE public.money_records ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Ver finanzas propias" ON public.money_records;
CREATE POLICY "Ver finanzas propias" ON public.money_records
  FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Insertar finanza propia" ON public.money_records;
CREATE POLICY "Insertar finanza propia" ON public.money_records
  FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Eliminar finanza propia" ON public.money_records;
CREATE POLICY "Eliminar finanza propia" ON public.money_records
  FOR DELETE USING (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS idx_money_user_id ON public.money_records(user_id);

-- ============================================================
-- 7. Tabla de gastos fijos mensuales
-- ============================================================
CREATE TABLE IF NOT EXISTS public.fixed_expenses (
  id TEXT PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  category TEXT NOT NULL DEFAULT 'Otros',
  name TEXT NOT NULL DEFAULT '',
  amount NUMERIC(10, 2) NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.fixed_expenses ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Ver gastos propios" ON public.fixed_expenses;
CREATE POLICY "Ver gastos propios" ON public.fixed_expenses
  FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Insertar gasto propio" ON public.fixed_expenses;
CREATE POLICY "Insertar gasto propio" ON public.fixed_expenses
  FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Eliminar gasto propio" ON public.fixed_expenses;
CREATE POLICY "Eliminar gasto propio" ON public.fixed_expenses
  FOR DELETE USING (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS idx_fixed_expenses_user_id ON public.fixed_expenses(user_id);

-- ============================================================
-- 8. Tabla de configuracion de salario (un registro por usuario)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.salary_settings (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  monthly_salary NUMERIC(12, 2) NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.salary_settings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Ver salario propio" ON public.salary_settings;
CREATE POLICY "Ver salario propio" ON public.salary_settings
  FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Insertar salario propio" ON public.salary_settings;
CREATE POLICY "Insertar salario propio" ON public.salary_settings
  FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Actualizar salario propio" ON public.salary_settings;
CREATE POLICY "Actualizar salario propio" ON public.salary_settings
  FOR UPDATE USING (auth.uid() = user_id);
