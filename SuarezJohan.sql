USE MundialDB;
GO

-- CASO 1 – EVOLUCIÓN DEL BALANCE DE GOLES
WITH partidos_normalizados AS (
    SELECT 
        home_team AS seleccion,
        event_id,
        event_date AS fecha,
        away_team AS rival,
        home_score AS GF,
        away_score AS GC
    FROM dbo.Partidos
    WHERE round_name IS NOT NULL AND round_name NOT LIKE '%Final%'
    
    UNION ALL
    
    SELECT 
        away_team AS seleccion,
        event_id,
        event_date AS fecha,
        home_team AS rival,
        away_score AS GF,
        home_score AS GC
    FROM dbo.Partidos
    WHERE round_name IS NOT NULL AND round_name NOT LIKE '%Final%'
),
historia_seleccion AS (
    SELECT 
        seleccion,
        event_id,
        fecha,
        rival,
        GF,
        GC,
        (GF - GC) AS diferencia_partido,
        ROW_NUMBER() OVER(
            PARTITION BY seleccion 
            ORDER BY fecha ASC, event_id ASC
        ) AS numero_partido
    FROM partidos_normalizados
)
SELECT 
    seleccion,
    event_id,
    fecha,
    rival,
    GF,
    GC,
    diferencia_partido,
    SUM(diferencia_partido) OVER(
        PARTITION BY seleccion 
        ORDER BY numero_partido ASC 
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS diferencia_acumulada,
    numero_partido,
    LAG(diferencia_partido) OVER(
        PARTITION BY seleccion 
        ORDER BY numero_partido ASC
    ) AS diferencia_partido_anterior
FROM historia_seleccion
ORDER BY seleccion, numero_partido;

-- CASO 2 – POSICIÓN OFENSIVA DENTRO DE CADA GRUPO
WITH tiros_resumen AS (
    SELECT 
        event_id,
        COUNT(*) AS tiros,
        COUNT(CASE WHEN LOWER(type) IN ('goal', 'save') THEN 1 END) AS tiros_puerta,
        SUM(COALESCE(xg, 0)) AS xg_total
    FROM dbo.Tiros
    GROUP BY event_id
),
partidos_normalizados AS (
    SELECT 
        COALESCE(p.round_name, 'Fase de Grupos') AS group_name,
        p.home_team AS seleccion,
        p.home_score AS goles,
        COALESCE(t.tiros, 0) AS tiros,
        COALESCE(t.tiros_puerta, 0) AS tiros_puerta,
        COALESCE(t.xg_total, 0) AS xg
    FROM dbo.Partidos p
    LEFT JOIN tiros_resumen t ON p.event_id = t.event_id
    
    UNION ALL
    
    SELECT 
        COALESCE(p.round_name, 'Fase de Grupos') AS group_name,
        p.away_team AS seleccion,
        p.away_score AS goles,
        COALESCE(t.tiros, 0) AS tiros,
        COALESCE(t.tiros_puerta, 0) AS tiros_puerta,
        COALESCE(t.xg_total, 0) AS xg
    FROM dbo.Partidos p
    LEFT JOIN tiros_resumen t ON p.event_id = t.event_id
),
resumen_grupo AS (
    SELECT 
        group_name,
        seleccion,
        SUM(COALESCE(goles, 0)) AS goles,
        SUM(COALESCE(tiros, 0)) AS tiros,
        SUM(COALESCE(tiros_puerta, 0)) AS tiros_puerta,
        SUM(COALESCE(xg, 0)) AS xg_acumulado
    FROM partidos_normalizados
    GROUP BY group_name, seleccion
)
SELECT 
    group_name,
    seleccion,
    goles,
    tiros,
    tiros_puerta,
    xg_acumulado,
    RANK() OVER(
        PARTITION BY group_name 
        ORDER BY xg_acumulado DESC
    ) AS posicion_xg
FROM resumen_grupo
ORDER BY group_name, posicion_xg ASC;

-- CASO 3 – COMPARACIÓN Y RANKING DE TIROS DEL PARTIDO 8388
WITH tiros_partido AS (
    SELECT 
        t.event_id,
        p.home_team AS equipo,
        t.sequence,
        t.min,
        t.type AS tipo,
        COALESCE(t.xg, 0) AS xg
    FROM dbo.Tiros t
    INNER JOIN dbo.Partidos p ON t.event_id = p.event_id
    WHERE t.event_id = 8388
)
SELECT 
    event_id,
    equipo,
    sequence,
    min,
    tipo,
    xg,
    LAG(xg) OVER(
        PARTITION BY equipo 
        ORDER BY sequence ASC
    ) AS xg_anterior,
    RANK() OVER(
        PARTITION BY equipo 
        ORDER BY xg DESC
    ) AS posicion_peligro
FROM tiros_partido
ORDER BY sequence ASC;
GO
