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