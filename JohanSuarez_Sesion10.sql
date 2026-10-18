USE MundialDB

SELECT 
	home_team,
	away_team,
	event_id,
	home_score,
	away_score
FROM Partidos
WHERE home_team = 'Spain'

SELECT TOP 10
	event_id,
	home_ball_possession,
	away_ball_possession,
	home_total_shots,
	away_total_shots,
	home_expected_goals,
	away_expected_goals
FROM EstadisticasPartido	

SELECT TOP 5
	event_id,
	event_date
FROM Partidos
ORDER BY event_id, event_date

---- EJERCICIO 6
DECLARE @seleccion varchar(30) = 'Tunisia';

WITH participacion as (
SELECT
	event_id,
	event_date,
	home_team as local,
	away_team as rival,
	'Local' as condicion,
	home_score as goles_favor,
	away_score as goles_contra
FROM Partidos
WHERE home_team = @seleccion
UNION ALL
SELECT
	event_id,
	event_date,
	away_team as local,
	home_team as rival,
	'Local' as condicion,
	away_score as goles_favor,
	home_score as goles_contra
FROM Partidos
WHERE away_team = @seleccion
)

SELECT 
	*,
	goles_favor - goles_contra as diferencia_gol,
	CASE 
		WHEN goles_favor > goles_contra THEN 3
		WHEN goles_favor = goles_contra THEN 1
		ELSE 0
	END as puntos
FROM participacion

'''
# EJERCICIO 7 — CASO: producción ofensiva frente a eficiencia --------------
# La dirección deportiva quiere comparar selecciones con al menos cuatro
# partidos. Construya en SQL una fila por selección con partidos, puntos por
# partido, goles, tiros, tiros a puerta, xG y posesión promedio. Agregue cada
# fuente antes de relacionarla para evitar duplicaciones. Python convertirá los
# DECIMAL, calculará goles menos xG y mostrará los extremos.
sql_7 = """
-- TODO: construir el resumen por selección con resultados y estadísticas.
"""
'''
WITH participacion as (
SELECT
	event_id,
	event_date,
	home_team as seleccion,
	home_score as gf,
	CASE 
		WHEN home_score > away_score THEN 3
		WHEN home_score = away_score THEN 1
		ELSE 0
	END as puntos
FROM Partidos
UNION ALL
SELECT
	event_id,
	event_date,
	away_team as seleccion,
	away_score as gf,
	CASE 
		WHEN away_score > home_score THEN 3
		WHEN away_score = home_score THEN 1
		ELSE 0
	END as puntos
FROM Partidos
),
estadisticas as(
SELECT
	p.event_id,
	p.home_team as seleccion,
	ep.home_total_shots as tiros,
	ep.home_shots_on_target as tiros_puerta,
	ep.home_ball_possession as posession,
	ep.home_expected_goals as xg
FROM Partidos p
JOIN EstadisticasPartido ep
	ON p.event_id = ep.event_id
UNION ALL
SELECT
	p.event_id,
	p.away_team as seleccion,
	ep.away_total_shots as tiros,
	ep.away_shots_on_target as tiros_puerta,
	ep.away_ball_possession as posession,
	ep.away_expected_goals as xg
FROM Partidos p
JOIN EstadisticasPartido ep
	ON p.event_id = ep.event_id
), 
detalle as (
SELECT
	p.event_id,
	p.seleccion,
	p.gf,
	p.puntos,
	e.tiros,
	e.tiros_puerta,
	e.xg,
	e.posession
FROM participacion p
INNER JOIN estadisticas e
	ON p.event_id = e.event_id and p.seleccion = e.seleccion
)
SELECT
	seleccion,
	COUNT(*) as camtidad_partidos,
	avg(puntos)*1.0 as puntos_partido,
	cast(sum(gf)*1.0/COUNT(*) as decimal (10,2)) as goles_partido,
	cast(sum(tiros)*1.0/COUNT(*) as decimal (10,2)) as tiros_partido,
	cast(sum(tiros_puerta)*1.0/COUNT(*) as decimal (10,2)) as tiros_puerta_partido,
	cast(sum(xg)*1.0/COUNT(*) as decimal (10,2)) as xg_partido,
	cast(AVG(posession*1.0) as decimal (10,2)) as promedio_posession
FROM detalle
--WHERE seleccion = 'Mexico'
GROUP BY seleccion
HAVING COUNT(*) >= 4
ORDER BY 2 DESC