-- Tabla usuarios
CREATE TABLE usuarios (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email VARCHAR(255) UNIQUE NOT NULL,
    nombre VARCHAR(255),
    sexo VARCHAR(50),
    fecha_nacimiento DATE,
    peso DECIMAL(5,2),
    altura DECIMAL(5,2),
    cintura DECIMAL(5,2),
    cadera DECIMAL(5,2),
    alergias TEXT,
    patologia TEXT,
    nivel_actividad VARCHAR(100),
    factor_actividad DECIMAL(3,2),
    objetivo_nutricional VARCHAR(100),
    numero_comidas INTEGER DEFAULT 3,
    tmb INTEGER,
    get_calorico INTEGER,
    calorias_objetivo INTEGER,
    proteinas_gramos INTEGER,
    carbohidratos_gramos INTEGER,
    grasas_gramos INTEGER,
    porciones_carbo INTEGER,
    porciones_proteina INTEGER,
    porciones_grasa INTEGER,
    onboarding_completo BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Tabla preferencias
CREATE TABLE preferencias_alimentarias (
    id SERIAL PRIMARY KEY,
    usuario_id UUID REFERENCES usuarios(id) ON DELETE CASCADE,
    preferencia VARCHAR(100) NOT NULL,
    UNIQUE(usuario_id, preferencia)
);

-- Tabla recetas
CREATE TABLE recetas (
    id SERIAL PRIMARY KEY,
    usuario_id UUID REFERENCES usuarios(id) ON DELETE CASCADE,
    contenido TEXT NOT NULL,
    tipo_comida VARCHAR(50),
    calorias_objetivo INTEGER,
    proteinas_objetivo INTEGER,
    carbos_objetivo INTEGER,
    grasas_objetivo INTEGER,
    objetivo_nutricional VARCHAR(100),
    modelo VARCHAR(50),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Índices para mejor rendimiento
CREATE INDEX idx_recetas_usuario ON recetas(usuario_id);
CREATE INDEX idx_recetas_fecha ON recetas(created_at DESC);

-- Habilitar Row Level Security
ALTER TABLE usuarios ENABLE ROW LEVEL SECURITY;
ALTER TABLE preferencias_alimentarias ENABLE ROW LEVEL SECURITY;
ALTER TABLE recetas ENABLE ROW LEVEL SECURITY;

-- Políticas de seguridad para usuarios
CREATE POLICY "Los usuarios pueden ver solo sus datos" 
    ON usuarios FOR SELECT 
    USING (auth.uid() = id);

CREATE POLICY "Los usuarios pueden actualizar solo sus datos" 
    ON usuarios FOR UPDATE 
    USING (auth.uid() = id);

CREATE POLICY "Los usuarios pueden insertar solo sus datos" 
    ON usuarios FOR INSERT 
    WITH CHECK (auth.uid() = id);

-- Políticas para preferencias
CREATE POLICY "Los usuarios pueden ver sus preferencias" 
    ON preferencias_alimentarias FOR SELECT 
    USING (auth.uid() = usuario_id);

CREATE POLICY "Los usuarios pueden insertar sus preferencias" 
    ON preferencias_alimentarias FOR INSERT 
    WITH CHECK (auth.uid() = usuario_id);

CREATE POLICY "Los usuarios pueden eliminar sus preferencias" 
    ON preferencias_alimentarias FOR DELETE 
    USING (auth.uid() = usuario_id);

-- Políticas para recetas
CREATE POLICY "Los usuarios pueden ver sus recetas" 
    ON recetas FOR SELECT 
    USING (auth.uid() = usuario_id);

CREATE POLICY "Los usuarios pueden insertar sus recetas" 
    ON recetas FOR INSERT 
    WITH CHECK (auth.uid() = usuario_id);

-- Trigger para actualizar updated_at automáticamente
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_usuarios_updated_at 
    BEFORE UPDATE ON usuarios
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

ALTER TABLE recetas 
ADD COLUMN IF NOT EXISTS dia_semana TEXT,
ADD COLUMN IF NOT EXISTS semana_numero INTEGER,
ADD COLUMN IF NOT EXISTS es_sugerencia BOOLEAN DEFAULT false;

-- Índice para búsquedas rápidas
CREATE INDEX IF NOT EXISTS idx_recetas_usuario_semana 
ON recetas(usuario_id, semana_numero, dia_semana);

-- =====================================================
-- 1. CREAR TABLAS CATÁLOGO
-- =====================================================

-- Catálogo de niveles de actividad
CREATE TABLE IF NOT EXISTS cat_niveles_actividad (
  id SERIAL PRIMARY KEY,
  codigo VARCHAR(50) UNIQUE NOT NULL,
  descripcion VARCHAR(200) NOT NULL,
  factor_actividad NUMERIC(3,2) NOT NULL,
  activo BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Catálogo de objetivos nutricionales
CREATE TABLE IF NOT EXISTS cat_objetivos_nutricionales (
  id SERIAL PRIMARY KEY,
  codigo VARCHAR(50) UNIQUE NOT NULL,
  descripcion VARCHAR(200) NOT NULL,
  ajuste_calorico INT NOT NULL,
  distribucion_proteinas NUMERIC(4,2) DEFAULT 22.5,
  distribucion_carbohidratos NUMERIC(4,2) DEFAULT 50.0,
  distribucion_grasas NUMERIC(4,2) DEFAULT 27.5,
  activo BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Catálogo de tipos de comida
CREATE TABLE IF NOT EXISTS cat_tipos_comida (
  id SERIAL PRIMARY KEY,
  codigo VARCHAR(30) UNIQUE NOT NULL,
  nombre VARCHAR(100) NOT NULL,
  orden_dia INT NOT NULL,
  icono VARCHAR(50),
  activo BOOLEAN DEFAULT true
);

-- =====================================================
-- 2. POBLAR CATÁLOGOS CON DATOS
-- =====================================================

-- Insertar niveles de actividad
INSERT INTO cat_niveles_actividad (codigo, descripcion, factor_actividad) VALUES
('sedentario', 'Sedentario (mínimo ejercicio)', 1.2),
('ligera', 'Ligera (1-3 días/sem de ejercicio)', 1.375),
('moderada', 'Moderada (3-5 días/sem)', 1.55),
('intensa', 'Intensa (6-7 días/sem)', 1.725),
('muy_intensa', 'Muy intensa (entrenamiento diario)', 1.9)
ON CONFLICT (codigo) DO NOTHING;

-- Insertar objetivos nutricionales
INSERT INTO cat_objetivos_nutricionales (
  codigo, 
  descripcion, 
  ajuste_calorico,
  distribucion_proteinas,
  distribucion_carbohidratos,
  distribucion_grasas
) VALUES
('deficit', 'Déficit calórico (pérdida de grasa)', -500, 27.5, 45.0, 27.5),
('recomposicion', 'Recomposición corporal', -300, 27.5, 45.0, 27.5),
('mantenimiento', 'Mantenimiento', 0, 22.5, 50.0, 27.5),
('superavit', 'Superávit (ganancia muscular)', 400, 22.5, 52.5, 22.5)
ON CONFLICT (codigo) DO NOTHING;

-- Insertar tipos de comida
INSERT INTO cat_tipos_comida (codigo, nombre, orden_dia, icono) VALUES
('desayuno', 'Desayuno', 1, 'wb_sunny_outlined'),
('almuerzo', 'Almuerzo', 2, 'restaurant'),
('cena', 'Cena', 3, 'dinner_dining'),
('snack', 'Snack', 4, 'cookie_outlined')
ON CONFLICT (codigo) DO NOTHING;

-- =====================================================
-- 3. AGREGAR COLUMNAS NUEVAS
-- =====================================================

-- Agregar referencias a catálogos en tabla usuarios
-- NOTA: Mantiene las columnas viejas para no romper la app
ALTER TABLE usuarios 
  ADD COLUMN IF NOT EXISTS nivel_actividad_id INT REFERENCES cat_niveles_actividad(id),
  ADD COLUMN IF NOT EXISTS objetivo_nutricional_id INT REFERENCES cat_objetivos_nutricionales(id);

-- Agregar referencia en tabla recetas
ALTER TABLE recetas
  ADD COLUMN IF NOT EXISTS tipo_comida_id INT REFERENCES cat_tipos_comida(id);

-- =====================================================
-- 4. MIGRAR DATOS EXISTENTES
-- =====================================================

-- Migrar nivel_actividad de usuarios
UPDATE usuarios u
SET nivel_actividad_id = na.id
FROM cat_niveles_actividad na
WHERE u.nivel_actividad_id IS NULL
  AND (
    LOWER(u.nivel_actividad) LIKE '%sedentario%' AND na.codigo = 'sedentario'
    OR LOWER(u.nivel_actividad) LIKE '%ligera%' AND na.codigo = 'ligera'
    OR LOWER(u.nivel_actividad) LIKE '%moderada%' AND na.codigo = 'moderada'
    OR LOWER(u.nivel_actividad) LIKE '%intensa%' AND na.codigo = 'intensa'
    OR LOWER(u.nivel_actividad) LIKE '%muy%' AND na.codigo = 'muy_intensa'
  );

-- Migrar objetivo_nutricional de usuarios
UPDATE usuarios u
SET objetivo_nutricional_id = obj.id
FROM cat_objetivos_nutricionales obj
WHERE u.objetivo_nutricional_id IS NULL
  AND (
    LOWER(u.objetivo_nutricional) LIKE '%déficit%' AND obj.codigo = 'deficit'
    OR LOWER(u.objetivo_nutricional) LIKE '%deficit%' AND obj.codigo = 'deficit'
    OR LOWER(u.objetivo_nutricional) LIKE '%recomposición%' AND obj.codigo = 'recomposicion'
    OR LOWER(u.objetivo_nutricional) LIKE '%recomposicion%' AND obj.codigo = 'recomposicion'
    OR LOWER(u.objetivo_nutricional) LIKE '%mantenimiento%' AND obj.codigo = 'mantenimiento'
    OR LOWER(u.objetivo_nutricional) LIKE '%superávit%' AND obj.codigo = 'superavit'
    OR LOWER(u.objetivo_nutricional) LIKE '%superavit%' AND obj.codigo = 'superavit'
  );

-- Migrar tipo_comida de recetas
UPDATE recetas r
SET tipo_comida_id = tc.id
FROM cat_tipos_comida tc
WHERE r.tipo_comida_id IS NULL
  AND LOWER(r.tipo_comida) = tc.codigo;

-- =====================================================
-- 5. CREAR FUNCIÓN DE CÁLCULO NUTRICIONAL
-- =====================================================

CREATE OR REPLACE FUNCTION calcular_datos_nutricionales(p_usuario_id UUID)
RETURNS JSON AS $$
DECLARE
  v_resultado JSON;
  v_sexo VARCHAR;
  v_peso NUMERIC;
  v_altura NUMERIC;
  v_edad INT;
  v_factor_actividad NUMERIC;
  v_ajuste_calorico INT;
  v_tmb NUMERIC;
  v_get NUMERIC;
  v_calorias_objetivo NUMERIC;
  v_dist_prot NUMERIC;
  v_dist_carb NUMERIC;
  v_dist_grasas NUMERIC;
BEGIN
  -- Obtener datos del usuario
  SELECT 
    u.sexo,
    u.peso,
    u.altura,
    EXTRACT(YEAR FROM AGE(u.fecha_nacimiento))::INT,
    na.factor_actividad,
    obj.ajuste_calorico,
    obj.distribucion_proteinas,
    obj.distribucion_carbohidratos,
    obj.distribucion_grasas
  INTO 
    v_sexo, v_peso, v_altura, v_edad, v_factor_actividad, 
    v_ajuste_calorico, v_dist_prot, v_dist_carb, v_dist_grasas
  FROM usuarios u
  LEFT JOIN cat_niveles_actividad na ON na.id = u.nivel_actividad_id
  LEFT JOIN cat_objetivos_nutricionales obj ON obj.id = u.objetivo_nutricional_id
  WHERE u.id = p_usuario_id;

  -- Calcular TMB según sexo
  IF v_sexo = 'Masculino' THEN
    v_tmb := 66 + (13.7 * v_peso) + (5 * v_altura) - (6.8 * v_edad);
  ELSE
    v_tmb := 655 + (9.6 * v_peso) + (1.8 * v_altura) - (4.7 * v_edad);
  END IF;

  -- Calcular GET
  v_get := v_tmb * COALESCE(v_factor_actividad, 1.2);

  -- Calcular calorías objetivo
  v_calorias_objetivo := v_get + COALESCE(v_ajuste_calorico, 0);

  -- Construir JSON de respuesta
  v_resultado := json_build_object(
    'tmb', ROUND(v_tmb),
    'get', ROUND(v_get),
    'calorias_objetivo', ROUND(v_calorias_objetivo),
    'proteinas_gramos', ROUND((v_calorias_objetivo * v_dist_prot / 100) / 4),
    'carbohidratos_gramos', ROUND((v_calorias_objetivo * v_dist_carb / 100) / 4),
    'grasas_gramos', ROUND((v_calorias_objetivo * v_dist_grasas / 100) / 9),
    'porciones_proteina', ROUND(((v_calorias_objetivo * v_dist_prot / 100) / 4) / 7),
    'porciones_carbo', ROUND(((v_calorias_objetivo * v_dist_carb / 100) / 4) / 15),
    'porciones_grasa', ROUND(((v_calorias_objetivo * v_dist_grasas / 100) / 9) / 5)
  );

  RETURN v_resultado;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- 6. CREAR VISTA PARA CONSULTAS SIMPLIFICADAS
-- =====================================================

CREATE OR REPLACE VIEW v_usuarios_completo AS
SELECT 
  u.id,
  u.email,
  u.nombre,
  u.sexo,
  u.fecha_nacimiento,
  EXTRACT(YEAR FROM AGE(u.fecha_nacimiento))::INT as edad,
  u.peso,
  u.altura,
  u.cintura,
  u.cadera,
  u.alergias,
  u.patologia,
  u.onboarding_completo,
  
  -- Datos normalizados
  na.codigo as nivel_actividad_codigo,
  na.descripcion as nivel_actividad_desc,
  na.factor_actividad,
  
  obj.codigo as objetivo_codigo,
  obj.descripcion as objetivo_desc,
  obj.ajuste_calorico,
  
  -- Valores calculados actuales (legacy)
  u.tmb as tmb_guardado,
  u.get_calorico as get_guardado,
  u.calorias_objetivo as calorias_guardadas,
  
  u.created_at,
  u.updated_at
FROM usuarios u
LEFT JOIN cat_niveles_actividad na ON na.id = u.nivel_actividad_id
LEFT JOIN cat_objetivos_nutricionales obj ON obj.id = u.objetivo_nutricional_id;

-- =====================================================
-- 7. CREAR ÍNDICES PARA PERFORMANCE
-- =====================================================

CREATE INDEX IF NOT EXISTS idx_usuarios_nivel_actividad 
  ON usuarios(nivel_actividad_id);

CREATE INDEX IF NOT EXISTS idx_usuarios_objetivo 
  ON usuarios(objetivo_nutricional_id);

CREATE INDEX IF NOT EXISTS idx_recetas_tipo_comida 
  ON recetas(tipo_comida_id);

CREATE INDEX IF NOT EXISTS idx_recetas_usuario_semana 
  ON recetas(usuario_id, semana_numero);

-- =====================================================
-- 8. COMENTARIOS PARA DOCUMENTACIÓN
-- =====================================================

COMMENT ON TABLE cat_niveles_actividad IS 
  'Catálogo de niveles de actividad física con sus factores multiplicadores';

COMMENT ON TABLE cat_objetivos_nutricionales IS 
  'Catálogo de objetivos nutricionales con ajustes calóricos y distribución de macros';

COMMENT ON TABLE cat_tipos_comida IS 
  'Catálogo de tipos de comidas del día';

COMMENT ON FUNCTION calcular_datos_nutricionales IS 
  'Calcula todos los datos nutricionales de un usuario en tiempo real basado en sus datos actuales';

COMMENT ON VIEW v_usuarios_completo IS 
  'Vista consolidada de usuarios con datos normalizados y descriptivos';

-- =====================================================
-- 9. VERIFICACIÓN
-- =====================================================

-- Contar registros migrados
DO $$
DECLARE
  v_usuarios_total INT;
  v_usuarios_migrados INT;
  v_recetas_total INT;
  v_recetas_migradas INT;
BEGIN
  SELECT COUNT(*) INTO v_usuarios_total FROM usuarios;
  SELECT COUNT(*) INTO v_usuarios_migrados 
    FROM usuarios 
    WHERE nivel_actividad_id IS NOT NULL 
      AND objetivo_nutricional_id IS NOT NULL;
  
  SELECT COUNT(*) INTO v_recetas_total FROM recetas;
  SELECT COUNT(*) INTO v_recetas_migradas 
    FROM recetas 
    WHERE tipo_comida_id IS NOT NULL;

  RAISE NOTICE '==============================================';
  RAISE NOTICE 'RESUMEN DE MIGRACIÓN';
  RAISE NOTICE '==============================================';
  RAISE NOTICE 'Usuarios totales: %', v_usuarios_total;
  RAISE NOTICE 'Usuarios migrados: % (%.2f%%)', 
    v_usuarios_migrados, 
    (v_usuarios_migrados::NUMERIC / NULLIF(v_usuarios_total, 0) * 100);
  RAISE NOTICE '----------------------------------------------';
  RAISE NOTICE 'Recetas totales: %', v_recetas_total;
  RAISE NOTICE 'Recetas migradas: % (%.2f%%)', 
    v_recetas_migradas,
    (v_recetas_migradas::NUMERIC / NULLIF(v_recetas_total, 0) * 100);
  RAISE NOTICE '==============================================';
END $$;

-- Crear tabla catálogo objetivos
CREATE TABLE cat_objetivos (
  id SERIAL PRIMARY KEY,
  codigo VARCHAR(30) UNIQUE NOT NULL,
  nombre VARCHAR(100) NOT NULL,
  descripcion VARCHAR(200),
  ajuste_calorias INT NOT NULL,
  activo BOOLEAN DEFAULT true,
  created_at TIMESTAMP DEFAULT NOW()
);

-- Insertar datos
INSERT INTO cat_objetivos (codigo, nombre, descripcion, ajuste_calorias) VALUES
('deficit', 'Déficit Calórico', 'Pérdida de grasa', -500),
('recomposicion', 'Recomposición Corporal', 'Ganar músculo y perder grasa', -300),
('mantenimiento', 'Mantenimiento', 'Mantener peso actual', 0),
('superavit', 'Superávit Calórico', 'Ganancia muscular', 400);

ALTER TABLE recetas ADD COLUMN imagen_url TEXT;

-- =====================================================
-- TABLA HISTORIAL DE RECETAS
-- =====================================================

CREATE TABLE IF NOT EXISTS historial_recetas (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  usuario_id UUID NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,

  -- Información de la receta
  nombre VARCHAR(300) NOT NULL,
  tipo_comida VARCHAR(50) NOT NULL,
  contenido_completo TEXT NOT NULL,

  -- Información nutricional
  calorias INTEGER,
  proteinas INTEGER,
  carbohidratos INTEGER,
  grasas INTEGER,

  -- Detalles adicionales
  tiempo_preparacion VARCHAR(100),
  imagen_url TEXT,

  -- Referencias (si proviene de una receta generada)
  receta_id INTEGER REFERENCES recetas(id) ON DELETE SET NULL,

  -- Estado
  is_favorito BOOLEAN DEFAULT false,
  veces_vista INTEGER DEFAULT 1,
  ultima_vista TIMESTAMPTZ DEFAULT NOW(),

  -- Metadatos
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- =====================================================
-- ÍNDICES PARA MEJORAR PERFORMANCE
-- =====================================================

-- Índice principal para búsquedas por usuario
CREATE INDEX IF NOT EXISTS idx_historial_usuario
  ON historial_recetas(usuario_id);

-- Índice para ordenar por fecha
CREATE INDEX IF NOT EXISTS idx_historial_fecha
  ON historial_recetas(usuario_id, created_at DESC);

-- Índice para filtrar favoritos
CREATE INDEX IF NOT EXISTS idx_historial_favoritos
  ON historial_recetas(usuario_id, is_favorito)
  WHERE is_favorito = true;

-- Índice para búsquedas por tipo de comida
CREATE INDEX IF NOT EXISTS idx_historial_tipo
  ON historial_recetas(usuario_id, tipo_comida);

-- Índice compuesto para queries más complejas
CREATE INDEX IF NOT EXISTS idx_historial_completo
  ON historial_recetas(usuario_id, is_favorito, created_at DESC);

-- =====================================================
-- ROW LEVEL SECURITY (RLS)
-- =====================================================

-- Habilitar RLS
ALTER TABLE historial_recetas ENABLE ROW LEVEL SECURITY;

-- Política para ver solo las recetas propias
CREATE POLICY "Los usuarios pueden ver solo sus recetas del historial"
  ON historial_recetas FOR SELECT
  USING (auth.uid() = usuario_id);

-- Política para insertar recetas propias
CREATE POLICY "Los usuarios pueden insertar en su historial"
  ON historial_recetas FOR INSERT
  WITH CHECK (auth.uid() = usuario_id);

-- Política para actualizar (favoritos, veces vista, etc.)
CREATE POLICY "Los usuarios pueden actualizar su historial"
  ON historial_recetas FOR UPDATE
  USING (auth.uid() = usuario_id);

-- Política para eliminar
CREATE POLICY "Los usuarios pueden eliminar de su historial"
  ON historial_recetas FOR DELETE
  USING (auth.uid() = usuario_id);

-- =====================================================
-- TRIGGER PARA UPDATED_AT AUTOMÁTICO
-- =====================================================

CREATE TRIGGER update_historial_recetas_updated_at
  BEFORE UPDATE ON historial_recetas
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- =====================================================
-- FUNCIÓN PARA AGREGAR AL HISTORIAL
-- =====================================================

CREATE OR REPLACE FUNCTION agregar_a_historial(
  p_usuario_id UUID,
  p_nombre VARCHAR,
  p_tipo_comida VARCHAR,
  p_contenido_completo TEXT,
  p_calorias INTEGER DEFAULT NULL,
  p_proteinas INTEGER DEFAULT NULL,
  p_carbohidratos INTEGER DEFAULT NULL,
  p_grasas INTEGER DEFAULT NULL,
  p_tiempo_preparacion VARCHAR DEFAULT NULL,
  p_imagen_url TEXT DEFAULT NULL,
  p_receta_id INTEGER DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
  v_id UUID;
  v_existe BOOLEAN;
BEGIN
  -- Verificar si ya existe una receta similar reciente (mismo nombre y tipo en las últimas 24h)
  SELECT EXISTS (
    SELECT 1 FROM historial_recetas
    WHERE usuario_id = p_usuario_id
      AND nombre = p_nombre
      AND tipo_comida = p_tipo_comida
      AND created_at > NOW() - INTERVAL '24 hours'
  ) INTO v_existe;

  IF v_existe THEN
    -- Si existe, actualizar veces_vista y ultima_vista
    UPDATE historial_recetas
    SET veces_vista = veces_vista + 1,
        ultima_vista = NOW(),
        updated_at = NOW()
    WHERE usuario_id = p_usuario_id
      AND nombre = p_nombre
      AND tipo_comida = p_tipo_comida
      AND created_at > NOW() - INTERVAL '24 hours'
    RETURNING id INTO v_id;
  ELSE
    -- Si no existe, insertar nueva
    INSERT INTO historial_recetas (
      usuario_id,
      nombre,
      tipo_comida,
      contenido_completo,
      calorias,
      proteinas,
      carbohidratos,
      grasas,
      tiempo_preparacion,
      imagen_url,
      receta_id
    ) VALUES (
      p_usuario_id,
      p_nombre,
      p_tipo_comida,
      p_contenido_completo,
      p_calorias,
      p_proteinas,
      p_carbohidratos,
      p_grasas,
      p_tiempo_preparacion,
      p_imagen_url,
      p_receta_id
    )
    RETURNING id INTO v_id;
  END IF;

  RETURN v_id;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- FUNCIÓN PARA EXTRAER INFORMACIÓN NUTRICIONAL DEL CONTENIDO
-- =====================================================

CREATE OR REPLACE FUNCTION extraer_info_nutricional(p_contenido TEXT)
RETURNS JSON AS $$
DECLARE
  v_resultado JSON;
  v_nombre TEXT;
  v_tiempo TEXT;
  v_calorias INTEGER;
  v_proteinas INTEGER;
  v_carbohidratos INTEGER;
  v_grasas INTEGER;
BEGIN
  -- Extraer nombre
  v_nombre := (regexp_match(p_contenido, 'NOMBRE:\s*(.+)', 'i'))[1];
  v_nombre := TRIM(v_nombre);

  -- Extraer tiempo de preparación
  v_tiempo := (regexp_match(p_contenido, 'TIEMPO DE PREPARACIÓN:\s*(.+)', 'i'))[1];
  v_tiempo := TRIM(v_tiempo);

  -- Extraer información nutricional usando expresiones regulares
  v_proteinas := (regexp_match(p_contenido, 'Proteínas:\s*(\d+)', 'i'))[1]::INTEGER;
  v_carbohidratos := (regexp_match(p_contenido, 'Carbohidratos:\s*(\d+)', 'i'))[1]::INTEGER;
  v_grasas := (regexp_match(p_contenido, 'Grasas:\s*(\d+)', 'i'))[1]::INTEGER;
  v_calorias := (regexp_match(p_contenido, 'Calorías:\s*(\d+)', 'i'))[1]::INTEGER;

  -- Construir JSON
  v_resultado := json_build_object(
    'nombre', v_nombre,
    'tiempo_preparacion', v_tiempo,
    'calorias', v_calorias,
    'proteinas', v_proteinas,
    'carbohidratos', v_carbohidratos,
    'grasas', v_grasas
  );

  RETURN v_resultado;
EXCEPTION
  WHEN OTHERS THEN
    -- Si hay error, devolver valores nulos
    RETURN json_build_object(
      'nombre', NULL,
      'tiempo_preparacion', NULL,
      'calorias', NULL,
      'proteinas', NULL,
      'carbohidratos', NULL,
      'grasas', NULL
    );
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- VISTA PARA CONSULTAS OPTIMIZADAS
-- =====================================================

CREATE OR REPLACE VIEW v_historial_completo AS
SELECT
  h.id,
  h.usuario_id,
  h.nombre,
  h.tipo_comida,
  h.contenido_completo,
  h.calorias,
  h.proteinas,
  h.carbohidratos,
  h.grasas,
  h.tiempo_preparacion,
  h.imagen_url,
  h.is_favorito,
  h.veces_vista,
  h.ultima_vista,
  h.created_at,
  h.updated_at,

  -- Información adicional del tipo de comida desde catálogo
  tc.nombre as tipo_comida_nombre,
  tc.icono as tipo_comida_icono,
  tc.orden_dia,

  -- Fecha formateada
  TO_CHAR(h.created_at, 'DD/MM/YYYY HH24:MI') as fecha_formateada,

  -- Hace cuánto tiempo
  CASE
    WHEN h.created_at > NOW() - INTERVAL '1 day' THEN 'Hoy'
    WHEN h.created_at > NOW() - INTERVAL '2 days' THEN 'Ayer'
    WHEN h.created_at > NOW() - INTERVAL '7 days' THEN 'Esta semana'
    WHEN h.created_at > NOW() - INTERVAL '30 days' THEN 'Este mes'
    ELSE 'Hace más de un mes'
  END as tiempo_relativo

FROM historial_recetas h
LEFT JOIN cat_tipos_comida tc ON tc.codigo = h.tipo_comida
ORDER BY h.created_at DESC;

-- 1. Agregar columna para rastrear regeneraciones en la tabla recetas
ALTER TABLE recetas
ADD COLUMN IF NOT EXISTS veces_regenerada INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS puede_regenerar BOOLEAN DEFAULT true,
ADD COLUMN IF NOT EXISTS semana_numero INTEGER,
ADD COLUMN IF NOT EXISTS anio INTEGER;

-- 2. Crear índice para búsqueda rápida por semana
CREATE INDEX IF NOT EXISTS idx_recetas_semana ON recetas(usuario_id, semana_numero, anio);

-- 3. Función para obtener el número de semana del año
CREATE OR REPLACE FUNCTION get_week_number(fecha TIMESTAMPTZ)
RETURNS INTEGER AS $$
BEGIN
  RETURN EXTRACT(WEEK FROM fecha)::INTEGER;
END;
$$ LANGUAGE plpgsql;

-- 4. Función para obtener el año
CREATE OR REPLACE FUNCTION get_year(fecha TIMESTAMPTZ)
RETURNS INTEGER AS $$
BEGIN
  RETURN EXTRACT(YEAR FROM fecha)::INTEGER;
END;
$$ LANGUAGE plpgsql;

-- 5. Actualizar recetas existentes con número de semana y año
-- Solo actualizar si las columnas existen y created_at no es nulo
UPDATE recetas
SET
  semana_numero = get_week_number(created_at),
  anio = get_year(created_at)
WHERE created_at IS NOT NULL
  AND (semana_numero IS NULL OR anio IS NULL);

-- 6. Función para verificar si una receta puede regenerarse
CREATE OR REPLACE FUNCTION puede_regenerar_receta(receta_id INTEGER)
RETURNS BOOLEAN AS $$
DECLARE
  veces_regen INTEGER;
BEGIN
  SELECT veces_regenerada INTO veces_regen
  FROM recetas
  WHERE id = receta_id;

  RETURN veces_regen < 3;
END;
$$ LANGUAGE plpgsql;

-- 7. Función para regenerar una receta (incrementa contador)
CREATE OR REPLACE FUNCTION registrar_regeneracion(receta_id INTEGER)
RETURNS void AS $$
BEGIN
  UPDATE recetas
  SET
    veces_regenerada = veces_regenerada + 1,
    puede_regenerar = CASE
      WHEN veces_regenerada + 1 >= 3 THEN false
      ELSE true
    END
  WHERE id = receta_id;
END;
$$ LANGUAGE plpgsql;

ALTER TABLE recetas ADD COLUMN is_favorito BOOLEAN DEFAULT FALSE;

-- Tabla para registrar comidas consumidas
CREATE TABLE registro_comidas (
    id BIGSERIAL PRIMARY KEY,
    usuario_id UUID NOT NULL REFERENCES auth.users(id),
    receta_id BIGINT REFERENCES recetas(id),
    tipo_comida TEXT NOT NULL,
    nombre_comida TEXT NOT NULL,
    calorias INTEGER NOT NULL,
    proteinas INTEGER,
    carbohidratos INTEGER,
    grasas INTEGER,
    fecha DATE NOT NULL DEFAULT CURRENT_DATE,
    hora TIME NOT NULL DEFAULT CURRENT_TIME,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Tabla para registrar consumo de agua
CREATE TABLE registro_agua (
    id BIGSERIAL PRIMARY KEY,
    usuario_id UUID NOT NULL REFERENCES auth.users(id),
    cantidad_ml INTEGER NOT NULL,
    fecha DATE NOT NULL DEFAULT CURRENT_DATE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Tabla para registrar peso
CREATE TABLE registro_peso (
    id BIGSERIAL PRIMARY KEY,
    usuario_id UUID NOT NULL REFERENCES auth.users(id),
    peso DECIMAL(5,2) NOT NULL,
    fecha DATE NOT NULL DEFAULT CURRENT_DATE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Índices para mejorar el rendimiento
CREATE INDEX idx_registro_comidas_usuario_fecha ON registro_comidas(usuario_id, fecha);
CREATE INDEX idx_registro_agua_usuario_fecha ON registro_agua(usuario_id, fecha);
CREATE INDEX idx_registro_peso_usuario_fecha ON registro_peso(usuario_id, fecha);

-- Crear tabla plan_seguimiento
CREATE TABLE IF NOT EXISTS plan_seguimiento (
    id BIGSERIAL PRIMARY KEY,
    usuario_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    fecha_inicio DATE NOT NULL,
    activo BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Crear índices para mejorar el rendimiento
CREATE INDEX IF NOT EXISTS idx_plan_seguimiento_usuario ON plan_seguimiento(usuario_id);
CREATE INDEX IF NOT EXISTS idx_plan_seguimiento_activo ON plan_seguimiento(activo);

-- Habilitar RLS (Row Level Security)
ALTER TABLE plan_seguimiento ENABLE ROW LEVEL SECURITY;

-- Política para que los usuarios solo puedan ver y modificar sus propios planes
CREATE POLICY "Los usuarios pueden ver sus propios planes"
    ON plan_seguimiento FOR SELECT
    USING (auth.uid() = usuario_id);

CREATE POLICY "Los usuarios pueden insertar sus propios planes"
    ON plan_seguimiento FOR INSERT
    WITH CHECK (auth.uid() = usuario_id);

CREATE POLICY "Los usuarios pueden actualizar sus propios planes"
    ON plan_seguimiento FOR UPDATE
    USING (auth.uid() = usuario_id);

CREATE POLICY "Los usuarios pueden eliminar sus propios planes"
    ON plan_seguimiento FOR DELETE
    USING (auth.uid() = usuario_id);

-- Tabla para guardar los items comprados de la lista de compras
CREATE TABLE IF NOT EXISTS lista_compras_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  semana_offset INT NOT NULL, -- 0 = semana actual, 1 = próxima semana
  categoria VARCHAR(100) NOT NULL, -- 'Verduras', 'Frutas', 'Carnes', etc.
  ingrediente TEXT NOT NULL, -- Nombre del ingrediente
  comprado BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

  -- Constraint para evitar duplicados
  UNIQUE(user_id, semana_offset, categoria, ingrediente)
);

-- Índices para mejorar performance
CREATE INDEX IF NOT EXISTS idx_lista_compras_user_semana
  ON lista_compras_items(user_id, semana_offset);

CREATE INDEX IF NOT EXISTS idx_lista_compras_comprado
  ON lista_compras_items(comprado);

-- Política de seguridad RLS (Row Level Security)
ALTER TABLE lista_compras_items ENABLE ROW LEVEL SECURITY;

-- Política: Los usuarios solo pueden ver/modificar sus propios items
CREATE POLICY "Users can view their own shopping list items"
  ON lista_compras_items
  FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own shopping list items"
  ON lista_compras_items
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own shopping list items"
  ON lista_compras_items
  FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own shopping list items"
  ON lista_compras_items
  FOR DELETE
  USING (auth.uid() = user_id);

-- Función para actualizar updated_at automáticamente
CREATE OR REPLACE FUNCTION update_lista_compras_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger para actualizar updated_at
CREATE TRIGGER update_lista_compras_items_updated_at
  BEFORE UPDATE ON lista_compras_items
  FOR EACH ROW
  EXECUTE FUNCTION update_lista_compras_updated_at();

-- Función para limpiar items antiguos (opcional - ejecutar manualmente o con cron)
-- Limpia items de semanas anteriores (más de 2 semanas atrás)
CREATE OR REPLACE FUNCTION cleanup_old_shopping_list_items()
RETURNS void AS $$
BEGIN
  DELETE FROM lista_compras_items
  WHERE created_at < NOW() - INTERVAL '14 days';
END;
$$ LANGUAGE plpgsql;

COMMENT ON TABLE lista_compras_items IS 'Almacena los items de la lista de compras marcados como comprados por los usuarios';
COMMENT ON COLUMN lista_compras_items.semana_offset IS '0 = semana actual, 1 = próxima semana';
COMMENT ON COLUMN lista_compras_items.categoria IS 'Categoría del ingrediente: Verduras, Frutas, Carnes, Lácteos, Granos, Condimentos, Otros';

-- Tabla para guardar mensajes del chat con IA
CREATE TABLE IF NOT EXISTS chat_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role VARCHAR(20) NOT NULL CHECK (role IN ('user', 'assistant', 'system')),
  content TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

  -- Metadatos opcionales
  tokens_used INT,
  model VARCHAR(50) DEFAULT 'gpt-3.5-turbo'
);

-- Índices para mejorar performance
CREATE INDEX IF NOT EXISTS idx_chat_messages_user_created
  ON chat_messages(user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_chat_messages_user_role
  ON chat_messages(user_id, role);

-- Política de seguridad RLS (Row Level Security)
ALTER TABLE chat_messages ENABLE ROW LEVEL SECURITY;

-- Política: Los usuarios solo pueden ver/modificar sus propios mensajes
CREATE POLICY "Users can view their own messages"
  ON chat_messages
  FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own messages"
  ON chat_messages
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own messages"
  ON chat_messages
  FOR DELETE
  USING (auth.uid() = user_id);

-- Función para limpiar mensajes antiguos (opcional - ejecutar manualmente o con cron)
-- Limpia mensajes de más de 30 días
CREATE OR REPLACE FUNCTION cleanup_old_chat_messages()
RETURNS void AS $$
BEGIN
  DELETE FROM chat_messages
  WHERE created_at < NOW() - INTERVAL '30 days';
END;
$$ LANGUAGE plpgsql;

-- Función para obtener estadísticas de uso del chat por usuario
CREATE OR REPLACE FUNCTION get_chat_stats(p_user_id UUID)
RETURNS TABLE(
  total_messages BIGINT,
  user_messages BIGINT,
  assistant_messages BIGINT,
  total_tokens BIGINT,
  first_message_date TIMESTAMP WITH TIME ZONE,
  last_message_date TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    COUNT(*) as total_messages,
    COUNT(*) FILTER (WHERE role = 'user') as user_messages,
    COUNT(*) FILTER (WHERE role = 'assistant') as assistant_messages,
    COALESCE(SUM(tokens_used), 0) as total_tokens,
    MIN(created_at) as first_message_date,
    MAX(created_at) as last_message_date
  FROM chat_messages
  WHERE user_id = p_user_id;
END;
$$ LANGUAGE plpgsql;

COMMENT ON TABLE chat_messages IS 'Almacena el historial de conversaciones del chatbot con IA para cada usuario';
COMMENT ON COLUMN chat_messages.role IS 'user = mensaje del usuario, assistant = respuesta de la IA, system = mensaje del sistema';
COMMENT ON COLUMN chat_messages.tokens_used IS 'Número de tokens consumidos en la petición (para tracking de costos)';

-- Agregar campo avatar_url a la tabla usuarios
ALTER TABLE usuarios
ADD COLUMN IF NOT EXISTS avatar_url TEXT;

-- Comentario para documentar el campo
COMMENT ON COLUMN usuarios.avatar_url IS 'URL del avatar seleccionado por el usuario desde Supabase Storage';


-- Crear tabla para recetas generadas desde el chat
CREATE TABLE IF NOT EXISTS recetas_generadas (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    usuario_id UUID REFERENCES usuarios(id) ON DELETE CASCADE,
    nombre TEXT NOT NULL,
    descripcion TEXT,
    tiempo_preparacion TEXT,
    dificultad TEXT CHECK (dificultad IN ('Fácil', 'Media', 'Difícil')),
    porciones INTEGER DEFAULT 1,
    calorias_totales INTEGER,
    calorias_por_porcion INTEGER,
    proteinas DECIMAL(10,2),
    carbohidratos DECIMAL(10,2),
    grasas DECIMAL(10,2),
    ingredientes JSONB,  -- Array de objetos {nombre, cantidad, categoria}
    pasos JSONB,         -- Array de strings
    imagen_url TEXT,
    origen TEXT DEFAULT 'manual' CHECK (origen IN ('chat', 'manual', 'api')),
    fecha_generacion TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Índices para búsquedas rápidas
CREATE INDEX IF NOT EXISTS idx_recetas_generadas_usuario ON recetas_generadas(usuario_id);
CREATE INDEX IF NOT EXISTS idx_recetas_generadas_fecha ON recetas_generadas(fecha_generacion DESC);
CREATE INDEX IF NOT EXISTS idx_recetas_generadas_origen ON recetas_generadas(origen);

-- Trigger para actualizar updated_at
CREATE OR REPLACE FUNCTION update_recetas_generadas_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_recetas_generadas_updated_at
    BEFORE UPDATE ON recetas_generadas
    FOR EACH ROW
    EXECUTE FUNCTION update_recetas_generadas_updated_at();

-- Comentarios en las columnas
COMMENT ON TABLE recetas_generadas IS 'Recetas generadas por el chat o creadas manualmente';
COMMENT ON COLUMN recetas_generadas.origen IS 'Origen de la receta: chat, manual, api';
COMMENT ON COLUMN recetas_generadas.ingredientes IS 'Array de objetos JSON con nombre, cantidad y categoria';
COMMENT ON COLUMN recetas_generadas.pasos IS 'Array de strings con los pasos de preparación';


UPDATE recetas
SET es_sugerencia = true
WHERE usuario_id = '25d15aec-4995-455d-acd1-508336449ac4'
  AND semana_numero = 47
  AND es_sugerencia = false;

SELECT COUNT(*) as total, es_sugerencia
FROM recetas
WHERE usuario_id = '25d15aec-4995-455d-acd1-508336449ac4'
  AND semana_numero = 47
GROUP BY es_sugerencia;

SELECT contenido
FROM recetas
WHERE usuario_id = '25d15aec-4995-455d-acd1-508336449ac4'
  AND semana_numero = 47
LIMIT 1;