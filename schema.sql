-- ============================================================
-- ESQUEMA DE BASE DE DATOS: PRODUCTIVIDAD OPERARIOS
-- Trailer Logistics - Supabase/Postgres
-- ============================================================
-- Ejecutar en el SQL Editor de Supabase en orden

-- 1. TABLA DE OPERARIOS (maestro de personas)
-- ============================================================
CREATE TABLE IF NOT EXISTS operarios (
    id              SERIAL PRIMARY KEY,
    rut             TEXT UNIQUE NOT NULL,
    usuario         TEXT UNIQUE NOT NULL,       -- username del WMS (JESPINOZA, PLOPEZ, etc.)
    nombre          TEXT NOT NULL,              -- nombre completo
    cargo           TEXT NOT NULL,              -- OPERADOR GRUA, OPERADOR APILADOR, etc.
    tipo_equipo     TEXT,                       -- SIMPLE, DOBLE
    factor_ajustado NUMERIC(3,2) DEFAULT 1.00, -- factor 0.70 a 1.00
    activo          BOOLEAN DEFAULT TRUE,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- Insertar operarios actuales
INSERT INTO operarios (rut, usuario, nombre, cargo, tipo_equipo, factor_ajustado) VALUES
('14.444.633-K', 'JESPINOZA',   'ESPINOZA MONTECINOS, JOSE LUIS',           'OPERADOR GRUA DOBLE',              'DOBLE',  1.00),
('11.296.024-4', 'PLOPEZ',      'LOPEZ ROJAS, PEDRO NICOLAS',               'OPERADOR GRUA DOBLE',              'SIMPLE', 1.00),
('11.560.880-0', 'SNUNEZ',      'NUÑEZ SAAVEDRA, SIXTO SALVADOR',           'OPERADOR GRUA',                    'SIMPLE', 1.00),
('26.178.217-0', 'CAGUAS',      'AGUAS PINEDA, CARLOS ANDRES',              'OPERADOR GRUA',                    'SIMPLE', 1.00),
('18.556.907-1', 'GUVALENZUE',  'VALENZUELA MARTINEZ, GUSTAVO ESTEBAN',     'OPERADOR GRUA',                    'SIMPLE', 0.87),
('27.119.664-4', 'Jvalderrey',  'VALDERREY GARCIA, JESUS ELEAZAR',          'OPERADOR APILADOR',                'DOBLE',  0.80),
('17.072.976-5', 'JPEREZ',      'PEREZ ALVAREZ, JORGE ANDRES',              'OPERADOR APILADOR',                'DOBLE',  1.00),
('17.340.647-9', 'YGARRIDO',    'GARRIDO CURAQUEO, YESENIA LISETTE',        'OPERADOR APILADOR',                NULL,     1.00),
('15.485.429-0', 'IMORALES',    'MORALES ALARCON, IGNACIO ENRIQUE',          'OPERADOR APILADOR',                'DOBLE',  0.80),
('17.680.021-6', 'JALARCON',    'ALARCON DIAZ, JAVIER ANDRES',              'OPERADOR TRANSPALETA',             'DOBLE',  1.00),
('12.856.689-9', 'CGARCES',     'GARCES HENRIQUEZ, CESAR RODRIGO',          'OPERADOR TRANSPALETA',             'SIMPLE', 0.70),
('18.059.915-0', 'MSANCHEZ',    'SANCHEZ CASTRO, MILCA ELISA',              'RECEPCIONISTA Y DESPACHADOR (A)',   'SIMPLE', 0.70),
('20.836.056-6', 'CTESTA',      'TESTA CARDENAS, CRISTOPHER ANDRES',        'RECEPCIONISTA Y DESPACHADOR (A)',   'SIMPLE', 0.70),
('26.033.065-9', 'GCOLLAZOS',   'COLLAZOS MOLINA, GUSTAVO ADOLFO',          'RECEPCIONISTA Y DESPACHADOR (A)',   'SIMPLE', 0.70),
('26.434.008-K', 'EGALUE',      'GALUE GALUE, ERIANNIS DEL CARMEN',         'RECEPCIONISTA Y DESPACHADOR (A)',   NULL,     0.70),
('20.055.444-2', 'JMARDONES',   'MARDONES RIQUELME, JEANNETTE MARITZA',     'RECEPCIONISTA Y DESPACHADOR (A)',   NULL,     0.70),
('17.003.180-6', 'SMOLINA',     'MOLINA HUERTA, SEBASTIAN JACOB',           'RECEPCIONISTA Y DESPACHADOR (A)',   NULL,     0.70)
ON CONFLICT (usuario) DO NOTHING;


-- 2. TABLA HISTORIAL LPN CAJAS
-- ============================================================
CREATE TABLE IF NOT EXISTS historial_cajas (
    id              BIGSERIAL PRIMARY KEY,
    id_lpn          TEXT NOT NULL,
    producto        TEXT,
    empresa_prod    TEXT,
    ubicacion       TEXT,
    ubicacion_prev  TEXT,
    fecha_mod       TIMESTAMPTZ NOT NULL,
    usuario         TEXT NOT NULL,
    mar_qa          TEXT,
    -- Columnas calculadas almacenadas
    en_jornada      BOOLEAN GENERATED ALWAYS AS (EXTRACT(HOUR FROM fecha_mod) <= 18) STORED,
    es_mov_valido   BOOLEAN GENERATED ALWAYS AS (
        CASE
            WHEN ubicacion IS NOT NULL AND ubicacion_prev IS NOT NULL
                 AND ubicacion <> ubicacion_prev
                 AND ubicacion_prev <> '0'
            THEN TRUE
            ELSE FALSE
        END
    ) STORED,
    dia             DATE GENERATED ALWAYS AS (fecha_mod::date) STORED,
    semana_carga    TEXT  -- para identificar qué semana/archivo se cargó
);

-- Índice compuesto para las consultas de productividad
CREATE INDEX IF NOT EXISTS idx_cajas_usuario_dia
    ON historial_cajas (usuario, dia)
    WHERE en_jornada = TRUE AND es_mov_valido = TRUE;

CREATE INDEX IF NOT EXISTS idx_cajas_dia
    ON historial_cajas (dia);

CREATE INDEX IF NOT EXISTS idx_cajas_fecha_mod
    ON historial_cajas (fecha_mod);

-- UNIQUE constraint para evitar duplicados en la carga
-- Si se sube el mismo archivo dos veces, los registros duplicados se ignoran
ALTER TABLE historial_cajas ADD CONSTRAINT uq_cajas_dedup
    UNIQUE (id_lpn, ubicacion_prev, ubicacion, usuario, fecha_mod);


-- 3. TABLA HISTORIAL LPN DESTINO
-- ============================================================
CREATE TABLE IF NOT EXISTS historial_destino (
    id              BIGSERIAL PRIMARY KEY,
    id_lpn          TEXT NOT NULL,
    producto        TEXT,
    empresa_prod    TEXT,
    ubic_actual     TEXT,
    ubic_anterior   TEXT,
    fecha_mod       TIMESTAMPTZ NOT NULL,
    usuario         TEXT NOT NULL,
    -- Columnas calculadas almacenadas
    en_jornada      BOOLEAN GENERATED ALWAYS AS (EXTRACT(HOUR FROM fecha_mod) <= 18) STORED,
    es_mov_valido   BOOLEAN GENERATED ALWAYS AS (
        CASE
            WHEN ubic_actual IS NOT NULL AND ubic_anterior IS NOT NULL
                 AND ubic_actual <> ubic_anterior
                 AND ubic_anterior <> '0'
            THEN TRUE
            ELSE FALSE
        END
    ) STORED,
    dia             DATE GENERATED ALWAYS AS (fecha_mod::date) STORED,
    semana_carga    TEXT
);

CREATE INDEX IF NOT EXISTS idx_destino_usuario_dia
    ON historial_destino (usuario, dia)
    WHERE en_jornada = TRUE AND es_mov_valido = TRUE;

CREATE INDEX IF NOT EXISTS idx_destino_dia
    ON historial_destino (dia);

-- UNIQUE constraint para evitar duplicados
ALTER TABLE historial_destino ADD CONSTRAINT uq_destino_dedup
    UNIQUE (id_lpn, ubic_anterior, ubic_actual, usuario, fecha_mod);


-- 4. TABLA MINUTAS (Despacho + Recepción unificadas)
-- ============================================================
CREATE TABLE IF NOT EXISTS minutas (
    id                  BIGSERIAL PRIMARY KEY,
    tipo_flujo          TEXT NOT NULL CHECK (tipo_flujo IN ('IN', 'OUT')),  -- IN=Recepción, OUT=Despacho
    fecha               DATE NOT NULL,
    cliente             TEXT,
    anden_puerta        TEXT,
    asn_os              TEXT,
    contenedor          TEXT,
    tipo_carga          TEXT,
    n_guia              TEXT,
    sku                 TEXT,
    detalle_unidades    TEXT,
    cantidad_pallets    NUMERIC(10,2) DEFAULT 0,
    estado_operacion    TEXT,
    hora_presentacion   TIME,
    usuario_operador    TEXT,          -- DESPACHADO/CARGADO POR (operador grúa)
    usuario_recepcion   TEXT,          -- RECEPCIONADO/DESPACHADO POR (recepcionista)
    hora_inicio         TIME,
    hora_termino        TIME,
    hora_salida         TIME,
    cargo_snap          TEXT,
    invas               TEXT,
    observacion         TEXT,
    semana_carga        TEXT
);

CREATE INDEX IF NOT EXISTS idx_minutas_operador_fecha
    ON minutas (usuario_operador, fecha);

CREATE INDEX IF NOT EXISTS idx_minutas_recepcion_fecha
    ON minutas (usuario_recepcion, fecha);

CREATE INDEX IF NOT EXISTS idx_minutas_fecha
    ON minutas (fecha);


-- 5. TABLA CONFIGURACIÓN DE HORARIOS
-- ============================================================
CREATE TABLE IF NOT EXISTS config_horarios (
    id              SERIAL PRIMARY KEY,
    dia_semana      INT NOT NULL CHECK (dia_semana BETWEEN 1 AND 7),  -- 1=Lunes, 7=Domingo
    nombre_dia      TEXT NOT NULL,
    horas_jornada   NUMERIC(4,2) NOT NULL,
    efectividad     NUMERIC(4,2) NOT NULL DEFAULT 0.85,
    horas_efectivas NUMERIC(5,2) GENERATED ALWAYS AS (horas_jornada * efectividad) STORED
);

INSERT INTO config_horarios (dia_semana, nombre_dia, horas_jornada, efectividad) VALUES
(1, 'Lunes',     9, 0.85),   -- 7.65 hrs efectivas
(2, 'Martes',    9, 0.85),   -- 7.65 hrs efectivas
(3, 'Miércoles', 9, 0.85),   -- 6.65 hrs efectivas  (NOTA: ajustar horas_jornada si corresponde)
(4, 'Jueves',    9, 0.85),   -- 6.65 hrs efectivas
(5, 'Viernes',   9, 0.85),   -- 6.65 hrs efectivas
(6, 'Sábado',    0, 0.85),   -- No se trabaja
(7, 'Domingo',   0, 0.85)    -- No se trabaja
ON CONFLICT DO NOTHING;

-- NOTA IMPORTANTE: Matías, en tu mensaje indicaste:
-- Lun-Mar: 9 hrs → 7.65 efectivas (9 * 0.85 = 7.65) ✓
-- Mié-Vie: 9 hrs → 6.65 efectivas (¿? 6.65 / 0.85 = 7.82 hrs jornada?)
-- Revisar si Mié-Vie son 7.82 hrs jornada o si la efectividad cambia.
-- Por ahora dejo todo en 9 hrs y 0.85, ajustar según corresponda.


-- 6. TABLA LOG DE CARGAS (auditoría)
-- ============================================================
CREATE TABLE IF NOT EXISTS log_cargas (
    id              SERIAL PRIMARY KEY,
    archivo         TEXT NOT NULL,
    tipo_data       TEXT NOT NULL,  -- 'cajas', 'destino', 'minuta_despacho', 'minuta_recepcion'
    registros       INT NOT NULL,
    fecha_carga     TIMESTAMPTZ DEFAULT NOW(),
    semana_carga    TEXT,
    usuario_carga   TEXT DEFAULT 'sistema'
);


-- 7. VIEW: PRODUCTIVIDAD DIARIA POR OPERARIO
-- ============================================================
-- Esta vista reemplaza todas las fórmulas SUMIFS del Excel
CREATE OR REPLACE VIEW v_productividad_diaria AS
WITH
-- Movimientos válidos de CAJAS por usuario/día
mov_cajas AS (
    SELECT
        usuario,
        dia,
        COUNT(*) AS movimientos_cajas
    FROM historial_cajas
    WHERE en_jornada = TRUE
      AND es_mov_valido = TRUE
    GROUP BY usuario, dia
),
-- Movimientos válidos de DESTINO por usuario/día
mov_destino AS (
    SELECT
        usuario,
        dia,
        COUNT(*) AS movimientos_destino
    FROM historial_destino
    WHERE en_jornada = TRUE
      AND es_mov_valido = TRUE
    GROUP BY usuario, dia
),
-- Pallets de Minutas Despacho - por operador (grúa)
min_des_operador AS (
    SELECT
        usuario_operador AS usuario,
        fecha AS dia,
        COALESCE(SUM(cantidad_pallets), 0) AS pallets_despacho_op
    FROM minutas
    WHERE tipo_flujo = 'OUT'
      AND usuario_operador IS NOT NULL
    GROUP BY usuario_operador, fecha
),
-- Pallets de Minutas Despacho - por recepcionista (solo cliente EASY)
min_des_recep AS (
    SELECT
        usuario_recepcion AS usuario,
        fecha AS dia,
        COALESCE(SUM(cantidad_pallets), 0) AS pallets_despacho_rec
    FROM minutas
    WHERE tipo_flujo = 'OUT'
      AND usuario_recepcion IS NOT NULL
    GROUP BY usuario_recepcion, fecha
),
-- Pallets de Minutas Despacho - por recepcionista (cliente EASY)
min_des_recep_easy AS (
    SELECT
        usuario_recepcion AS usuario,
        fecha AS dia,
        COALESCE(SUM(cantidad_pallets), 0) AS pallets_despacho_easy
    FROM minutas
    WHERE tipo_flujo = 'OUT'
      AND UPPER(cliente) = 'EASY'
      AND usuario_recepcion IS NOT NULL
    GROUP BY usuario_recepcion, fecha
),
-- Pallets de Minutas Recepción - por recepcionista
min_rec AS (
    SELECT
        usuario_recepcion AS usuario,
        fecha AS dia,
        COALESCE(SUM(cantidad_pallets), 0) AS pallets_recepcion
    FROM minutas
    WHERE tipo_flujo = 'IN'
      AND usuario_recepcion IS NOT NULL
    GROUP BY usuario_recepcion, fecha
),
-- Unir todos los días y usuarios
todos_dias AS (
    SELECT usuario, dia FROM mov_cajas
    UNION
    SELECT usuario, dia FROM mov_destino
    UNION
    SELECT usuario, dia FROM min_des_operador
    UNION
    SELECT usuario, dia FROM min_des_recep
    UNION
    SELECT usuario, dia FROM min_rec
)
SELECT
    td.usuario,
    o.nombre,
    o.cargo,
    o.tipo_equipo,
    o.factor_ajustado,
    td.dia,
    EXTRACT(ISODOW FROM td.dia)::INT AS dia_semana,
    TO_CHAR(td.dia, 'TMDay') AS nombre_dia,
    EXTRACT(WEEK FROM td.dia)::INT AS semana,
    EXTRACT(MONTH FROM td.dia)::INT AS mes,
    EXTRACT(YEAR FROM td.dia)::INT AS anio,
    COALESCE(mc.movimientos_cajas, 0) AS mov_cajas,
    COALESCE(md.movimientos_destino, 0) AS mov_destino,
    COALESCE(mdo.pallets_despacho_op, 0) AS pallets_despacho_operador,
    COALESCE(mdr.pallets_despacho_rec, 0) AS pallets_despacho_recep,
    COALESCE(mdre.pallets_despacho_easy, 0) AS pallets_despacho_easy,
    COALESCE(mr.pallets_recepcion, 0) AS pallets_recepcion,
    -- Total movimientos (la fórmula del Excel)
    COALESCE(mc.movimientos_cajas, 0)
        + COALESCE(md.movimientos_destino, 0)
        + COALESCE(mdo.pallets_despacho_op, 0)
        + COALESCE(mdr.pallets_despacho_rec, 0)
        + COALESCE(mdre.pallets_despacho_easy, 0)
        + COALESCE(mr.pallets_recepcion, 0) AS total_movimientos,
    -- Horas efectivas del día
    ch.horas_efectivas,
    -- Productividad = total_movimientos / horas_efectivas
    CASE
        WHEN ch.horas_efectivas > 0 THEN
            ROUND(
                (COALESCE(mc.movimientos_cajas, 0)
                + COALESCE(md.movimientos_destino, 0)
                + COALESCE(mdo.pallets_despacho_op, 0)
                + COALESCE(mdr.pallets_despacho_rec, 0)
                + COALESCE(mdre.pallets_despacho_easy, 0)
                + COALESCE(mr.pallets_recepcion, 0))::NUMERIC
                / ch.horas_efectivas, 2)
        ELSE 0
    END AS productividad_hora
FROM todos_dias td
LEFT JOIN operarios o ON UPPER(o.usuario) = UPPER(td.usuario)
LEFT JOIN mov_cajas mc ON mc.usuario = td.usuario AND mc.dia = td.dia
LEFT JOIN mov_destino md ON md.usuario = td.usuario AND md.dia = td.dia
LEFT JOIN min_des_operador mdo ON UPPER(mdo.usuario) = UPPER(td.usuario) AND mdo.dia = td.dia
LEFT JOIN min_des_recep mdr ON UPPER(mdr.usuario) = UPPER(td.usuario) AND mdr.dia = td.dia
LEFT JOIN min_des_recep_easy mdre ON UPPER(mdre.usuario) = UPPER(td.usuario) AND mdre.dia = td.dia
LEFT JOIN min_rec mr ON UPPER(mr.usuario) = UPPER(td.usuario) AND mr.dia = td.dia
LEFT JOIN config_horarios ch ON ch.dia_semana = EXTRACT(ISODOW FROM td.dia)::INT
WHERE o.id IS NOT NULL;  -- Solo operarios registrados


-- 8. VIEW: RESUMEN MENSUAL POR OPERARIO (para bonos)
-- ============================================================
CREATE OR REPLACE VIEW v_resumen_mensual AS
SELECT
    usuario,
    nombre,
    cargo,
    tipo_equipo,
    factor_ajustado,
    anio,
    mes,
    SUM(total_movimientos) AS total_movimientos_mes,
    SUM(CASE WHEN horas_efectivas > 0 THEN horas_efectivas ELSE 0 END) AS total_horas_mes,
    ROUND(AVG(productividad_hora), 2) AS promedio_productividad,
    COUNT(dia) AS dias_trabajados,
    SUM(mov_cajas) AS total_mov_cajas,
    SUM(mov_destino) AS total_mov_destino,
    SUM(pallets_despacho_operador + pallets_despacho_recep + pallets_despacho_easy) AS total_pallets_despacho,
    SUM(pallets_recepcion) AS total_pallets_recepcion
FROM v_productividad_diaria
GROUP BY usuario, nombre, cargo, tipo_equipo, factor_ajustado, anio, mes;


-- 9. VIEW: RESUMEN SEMANAL POR OPERARIO
-- ============================================================
CREATE OR REPLACE VIEW v_resumen_semanal AS
SELECT
    usuario,
    nombre,
    cargo,
    anio,
    semana,
    MIN(dia) AS inicio_semana,
    MAX(dia) AS fin_semana,
    SUM(total_movimientos) AS total_movimientos_semana,
    ROUND(AVG(productividad_hora), 2) AS promedio_productividad,
    COUNT(dia) AS dias_trabajados,
    SUM(mov_cajas) AS mov_cajas_semana,
    SUM(mov_destino) AS mov_destino_semana
FROM v_productividad_diaria
GROUP BY usuario, nombre, cargo, anio, semana;


-- 10. VIEW: RANKING DIARIO
-- ============================================================
CREATE OR REPLACE VIEW v_ranking_diario AS
SELECT
    *,
    RANK() OVER (PARTITION BY dia ORDER BY productividad_hora DESC) AS ranking
FROM v_productividad_diaria
WHERE productividad_hora > 0;


-- 11. FUNCIÓN: Calcular bono mensual
-- ============================================================
CREATE OR REPLACE FUNCTION fn_calcular_bono(
    p_anio INT,
    p_mes INT,
    p_monto_total NUMERIC DEFAULT 896432.67
)
RETURNS TABLE (
    usuario TEXT,
    nombre TEXT,
    cargo TEXT,
    factor_ajustado NUMERIC,
    total_movimientos NUMERIC,
    movimientos_ajustados NUMERIC,
    porcentaje_participacion NUMERIC,
    bono NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    WITH base AS (
        SELECT
            rm.usuario,
            rm.nombre,
            rm.cargo,
            rm.factor_ajustado,
            rm.total_movimientos_mes,
            ROUND(rm.total_movimientos_mes * rm.factor_ajustado, 2) AS mov_ajustados
        FROM v_resumen_mensual rm
        WHERE rm.anio = p_anio AND rm.mes = p_mes
    ),
    totales AS (
        SELECT SUM(mov_ajustados) AS suma_total FROM base
    )
    SELECT
        b.usuario,
        b.nombre,
        b.cargo,
        b.factor_ajustado,
        b.total_movimientos_mes AS total_movimientos,
        b.mov_ajustados AS movimientos_ajustados,
        ROUND(b.mov_ajustados / NULLIF(t.suma_total, 0), 6) AS porcentaje_participacion,
        ROUND(b.mov_ajustados / NULLIF(t.suma_total, 0) * p_monto_total, 0) AS bono
    FROM base b
    CROSS JOIN totales t
    ORDER BY bono DESC;
END;
$$ LANGUAGE plpgsql;


-- 12. TABLA SNAPSHOT: Productividades finales respaldadas
-- ============================================================
-- Esta tabla guarda el cálculo final de productividad por operario/día
-- para tener un respaldo histórico permanente (no depende de las vistas)
CREATE TABLE IF NOT EXISTS productividad_final (
    id              BIGSERIAL PRIMARY KEY,
    usuario         TEXT NOT NULL,
    nombre          TEXT,
    cargo           TEXT,
    dia             DATE NOT NULL,
    dia_semana      INT,
    semana          INT,
    mes             INT,
    anio            INT,
    mov_cajas       INT DEFAULT 0,
    mov_destino     INT DEFAULT 0,
    pallets_despacho INT DEFAULT 0,
    pallets_recepcion INT DEFAULT 0,
    total_movimientos INT DEFAULT 0,
    horas_efectivas NUMERIC(5,2),
    productividad_hora NUMERIC(8,2),
    factor_ajustado NUMERIC(3,2),
    fecha_calculo   TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(usuario, dia)  -- Un registro por operario por día
);

CREATE INDEX IF NOT EXISTS idx_prod_final_usuario ON productividad_final (usuario, dia);
CREATE INDEX IF NOT EXISTS idx_prod_final_mes ON productividad_final (anio, mes);

-- Función para materializar productividades de un rango de fechas
CREATE OR REPLACE FUNCTION fn_guardar_productividad(
    p_fecha_desde DATE,
    p_fecha_hasta DATE
) RETURNS INT AS $$
DECLARE
    v_count INT;
BEGIN
    INSERT INTO productividad_final (
        usuario, nombre, cargo, dia, dia_semana, semana, mes, anio,
        mov_cajas, mov_destino, pallets_despacho, pallets_recepcion,
        total_movimientos, horas_efectivas, productividad_hora, factor_ajustado
    )
    SELECT
        usuario, nombre, cargo, dia, dia_semana, semana, mes, anio,
        mov_cajas, mov_destino,
        pallets_despacho_operador + pallets_despacho_recep + pallets_despacho_easy,
        pallets_recepcion,
        total_movimientos, horas_efectivas, productividad_hora, factor_ajustado
    FROM v_productividad_diaria
    WHERE dia BETWEEN p_fecha_desde AND p_fecha_hasta
    ON CONFLICT (usuario, dia) DO UPDATE SET
        mov_cajas = EXCLUDED.mov_cajas,
        mov_destino = EXCLUDED.mov_destino,
        pallets_despacho = EXCLUDED.pallets_despacho,
        pallets_recepcion = EXCLUDED.pallets_recepcion,
        total_movimientos = EXCLUDED.total_movimientos,
        horas_efectivas = EXCLUDED.horas_efectivas,
        productividad_hora = EXCLUDED.productividad_hora,
        factor_ajustado = EXCLUDED.factor_ajustado,
        fecha_calculo = NOW();

    GET DIAGNOSTICS v_count = ROW_COUNT;
    RETURN v_count;
END;
$$ LANGUAGE plpgsql;

-- Ejemplo de uso:
-- SELECT fn_guardar_productividad('2026-02-01', '2026-02-28');
-- Esto guarda/actualiza todas las productividades de febrero 2026


-- 13. FUNCIÓN: Limpieza automática de data cruda > 2 meses
-- ============================================================
-- Elimina registros de historial_cajas e historial_destino con más de 2 meses
-- La tabla productividad_final NO se toca (se mantiene para siempre)
CREATE OR REPLACE FUNCTION fn_limpiar_historial_antiguo()
RETURNS JSON AS $$
DECLARE
    v_cajas INT;
    v_destino INT;
    v_fecha_limite DATE;
BEGIN
    v_fecha_limite := CURRENT_DATE - INTERVAL '2 months';

    DELETE FROM historial_cajas WHERE dia < v_fecha_limite;
    GET DIAGNOSTICS v_cajas = ROW_COUNT;

    DELETE FROM historial_destino WHERE dia < v_fecha_limite;
    GET DIAGNOSTICS v_destino = ROW_COUNT;

    RETURN json_build_object(
        'fecha_limite', v_fecha_limite,
        'cajas_eliminadas', v_cajas,
        'destino_eliminadas', v_destino
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Se ejecuta automáticamente al final de cada carga de datos
-- desde la página carga_datos_supabase.html


-- 14. RLS (Row Level Security) - Opcional
-- ============================================================
-- Si querés restringir acceso por usuario en el futuro:
-- ALTER TABLE historial_cajas ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE historial_destino ENABLE ROW LEVEL SECURITY;
-- CREATE POLICY "read_all" ON historial_cajas FOR SELECT USING (true);
