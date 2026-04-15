-- ============================================================
-- TABLA: "3-detalle_diario_operario"
-- Guarda por operario/día el desglose de:
--   - Movimientos LPN Cajas
--   - Movimientos LPN Destino
--   - Pallets Minuta (despacho grúa, despacho recep, recepción)
-- Permite filtrar por operario y descargar por día específico
-- ============================================================

-- 1. CREAR TABLA
-- ============================================================
CREATE TABLE IF NOT EXISTS "3-detalle_diario_operario" (
    id                      BIGSERIAL PRIMARY KEY,
    usuario                 TEXT NOT NULL,
    nombre                  TEXT,
    cargo                   TEXT,
    dia                     DATE NOT NULL,
    semana                  INT,
    mes                     INT,
    anio                    INT,

    -- LPN Cajas (movimientos válidos en jornada)
    mov_lpn_cajas           INT DEFAULT 0,

    -- LPN Destino (movimientos válidos en jornada)
    mov_lpn_destino         INT DEFAULT 0,

    -- Minutas desglosadas
    pallets_despacho_grua   NUMERIC(10,2) DEFAULT 0,   -- cargado por (operador grúa)
    pallets_despacho_recep  NUMERIC(10,2) DEFAULT 0,   -- despachado por (recepcionista)
    pallets_recepcion       NUMERIC(10,2) DEFAULT 0,   -- recepcionado por
    total_minuta            NUMERIC(10,2) DEFAULT 0,   -- suma de los 3 anteriores

    -- Total y productividad
    total_movimientos       NUMERIC(10,2) DEFAULT 0,
    horas_efectivas         NUMERIC(5,2),
    productividad_hora      NUMERIC(8,2),

    -- Auditoría
    actualizado_en          TIMESTAMPTZ DEFAULT NOW(),

    UNIQUE(usuario, dia)
);

CREATE INDEX IF NOT EXISTS idx_detalle_diario_usuario ON "3-detalle_diario_operario" (usuario, dia);
CREATE INDEX IF NOT EXISTS idx_detalle_diario_dia     ON "3-detalle_diario_operario" (dia);
CREATE INDEX IF NOT EXISTS idx_detalle_diario_mes     ON "3-detalle_diario_operario" (anio, mes);


-- 2. FUNCIÓN: Poblar/actualizar la tabla para un rango de fechas
-- ============================================================
-- Uso: SELECT fn_guardar_detalle_diario('2026-01-01', '2026-12-31');
-- Si el registro ya existe, lo actualiza (upsert).

CREATE OR REPLACE FUNCTION fn_guardar_detalle_diario(
    p_fecha_desde DATE,
    p_fecha_hasta DATE
) RETURNS INT AS $$
DECLARE
    v_count INT;
BEGIN
    INSERT INTO "3-detalle_diario_operario" (
        usuario, nombre, cargo,
        dia, semana, mes, anio,
        mov_lpn_cajas,
        mov_lpn_destino,
        pallets_despacho_grua,
        pallets_despacho_recep,
        pallets_recepcion,
        total_minuta,
        total_movimientos,
        horas_efectivas,
        productividad_hora,
        actualizado_en
    )
    SELECT
        v.usuario,
        v.nombre,
        v.cargo,
        v.dia,
        v.semana,
        v.mes,
        v.anio,
        v.mov_cajas,
        v.mov_destino,
        v.pallets_despacho_operador,
        v.pallets_despacho_recep + v.pallets_despacho_easy,
        v.pallets_recepcion,
        v.pallets_despacho_operador
            + v.pallets_despacho_recep
            + v.pallets_despacho_easy
            + v.pallets_recepcion,
        v.total_movimientos,
        v.horas_efectivas,
        v.productividad_hora,
        NOW()
    FROM v_productividad_diaria v
    WHERE v.dia BETWEEN p_fecha_desde AND p_fecha_hasta
    ON CONFLICT (usuario, dia) DO UPDATE SET
        nombre                  = EXCLUDED.nombre,
        cargo                   = EXCLUDED.cargo,
        semana                  = EXCLUDED.semana,
        mes                     = EXCLUDED.mes,
        anio                    = EXCLUDED.anio,
        mov_lpn_cajas           = EXCLUDED.mov_lpn_cajas,
        mov_lpn_destino         = EXCLUDED.mov_lpn_destino,
        pallets_despacho_grua   = EXCLUDED.pallets_despacho_grua,
        pallets_despacho_recep  = EXCLUDED.pallets_despacho_recep,
        pallets_recepcion       = EXCLUDED.pallets_recepcion,
        total_minuta            = EXCLUDED.total_minuta,
        total_movimientos       = EXCLUDED.total_movimientos,
        horas_efectivas         = EXCLUDED.horas_efectivas,
        productividad_hora      = EXCLUDED.productividad_hora,
        actualizado_en          = NOW();

    GET DIAGNOSTICS v_count = ROW_COUNT;
    RETURN v_count;
END;
$$ LANGUAGE plpgsql;


-- 3. POBLAR CON DATOS HISTÓRICOS (ejecutar una sola vez)
-- ============================================================
SELECT fn_guardar_detalle_diario('2026-01-01', CURRENT_DATE);


-- 4. EJEMPLOS DE CONSULTA
-- ============================================================

-- Todos los movimientos de un operario en un día:
-- SELECT * FROM "3-detalle_diario_operario"
-- WHERE usuario = 'JPEREZ' AND dia = '2026-04-14';

-- Ranking de operarios en un día específico:
-- SELECT usuario, nombre, cargo,
--        mov_lpn_cajas, mov_lpn_destino, total_minuta,
--        total_movimientos, productividad_hora
-- FROM "3-detalle_diario_operario"
-- WHERE dia = '2026-04-14'
-- ORDER BY productividad_hora DESC;

-- Historial de un operario en el mes:
-- SELECT dia, mov_lpn_cajas, mov_lpn_destino,
--        pallets_despacho_grua, pallets_despacho_recep, pallets_recepcion,
--        total_minuta, total_movimientos, productividad_hora
-- FROM "3-detalle_diario_operario"
-- WHERE usuario = 'JPEREZ'
--   AND anio = 2026 AND mes = 4
-- ORDER BY dia DESC;
