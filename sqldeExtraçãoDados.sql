
WITH analisis AS (
WITH tiempos AS (
SELECT
         ca.id_camda,
         max(ca.DATA_RECEBEMENTO) AS momento_recebimento,
         min(ca.DATA_RECEBEMENTO) AS momento_recebimento_min,
         ca."data" AS momento_ejecucion,
         LEAD(ca."data") OVER (
ORDER BY
         ca.id_camda DESC) AS momento_ejecucion_anterior,
          LEAD(ca."data") OVER (
ORDER BY
         ca.id_camda ASC) AS momento_ejecucion_despues,
         avg(ci.TAMANHO_INTERFAZ) AS prom_tamano
FROM
         STG_S3.CONTROLFLAG_ARQUIVOS AS CA
INNER JOIN TRF_S3.TMP_CONTROLFLAG_INTERFACES AS CI ON
         ca.ID_CAMDA = ci.ID_CAMDA
         AND ca.NOME_BASE = ci.NOME_FLAG_GERAL
WHERE
         ci.TAMANHO_INTERFAZ IS NOT NULL
GROUP BY
         1,
         4
ORDER BY
         ca.ID_CAMDA DESC
),
diferencia AS (
SELECT
         t.ID_CAMDA,
         t.MOMENTO_RECEBIMENTO,
         momento_recebimento_min,
         t.MOMENTO_EJECUCION,
         EXTRACT(EPOCH FROM t.MOMENTO_EJECUCION-MOMENTO_RECEBIMENTO)::int AS dife,
         t.MOMENTO_EJECUCION_ANTERIOR,
         momento_ejecucion_despues,
         t.PROM_TAMANO
FROM
         tiempos AS t
ORDER BY
         1 DESC),
         conjunto AS (
SELECT
         d.id_camda,
         MOMENTO_RECEBIMENTO,
         momento_recebimento_min,
         MOMENTO_EJECUCION,
         dife,
         CASE
                  WHEN dife >65 THEN 'Manual'
                  ELSE 'Automatica'
         END AS tipo,
         MOMENTO_EJECUCION_ANTERIOR,
         momento_ejecucion_despues,
         PROM_TAMANO
FROM
         diferencia AS d),
         tmp_manuales AS (
SELECT
         *
FROM
         conjunto
WHERE
         tipo = 'Manual')
         ,
manuales AS (
SELECT
         *,
         momento_ejecucion-momento_recebimento AS duracion,
         1 AS orden
FROM
         tmp_manuales )
         ,
tmp_automatica AS (
SELECT
         *
FROM
         conjunto
WHERE
         tipo = 'Automatica'),
         automaticas AS (
SELECT
         * ,
         momento_ejecucion -momento_ejecucion_anterior,
         2 AS orden
FROM
         tmp_automatica),
         conjuntas AS (
SELECT
         id_camda,
         momento_recebimento,
         momento_ejecucion,
         momento_recebimento_min,
         dife,
         'Automatica' AS tipo,
         
         momento_ejecucion_anterior,
         momento_ejecucion_despues,
         prom_tamano,
         momento_ejecucion -momento_ejecucion_anterior AS duracion,
         3 AS orden
FROM
         conjunto
WHERE
         tipo = 'Manual'),
         relacion AS (
SELECT
         *
FROM
         conjuntas
UNION
SELECT
         *
FROM
         manuales
UNION
SELECT
         *
FROM
         automaticas
ORDER BY
         1 DESC)
SELECT
         ca.*
FROM
         relacion AS ca
ORDER BY
         1 DESC,
         ORDEn DESC)
SELECT
         id_camda,
         orden,
         tipo,
        -- dife,
         --       inicio_ejecucion,
         CASE WHEN orden =2 OR orden =3 THEN momento_ejecucion ELSE momento_recebimento END AS inicio_ejecucion,
         CASE
                  WHEN orden = 2 THEN momento_ejecucion-momento_ejecucion_anterior
                  WHEN orden = 1 THEN LAG(momento_ejecucion) OVER ( ORDER BY id_camda DESC) -momento_recebimento
                  WHEN orden  = 3 THEN momento_ejecucion_despues - momento_ejecucion
                  ELSE NULL
         END AS duracion,
         prom_tamano::int AS tamano
FROM
         analisis AS ana
ORDER BY 
         id_Camda DESC, orden DESC