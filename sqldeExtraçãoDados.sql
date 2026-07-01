WITH tiempos AS (
    SELECT
        ca.id_camda,
        MAX(ca.data_recebemento) AS momento_recebimento,
        MIN(ca.data_recebemento) AS momento_recebimento_min,
        ca."data" AS momento_ejecucion,
        LEAD(ca."data") OVER (
            ORDER BY ca.id_camda DESC
        ) AS momento_ejecucion_anterior,
        LEAD(ca."data") OVER (
            ORDER BY ca.id_camda ASC
        ) AS momento_ejecucion_despues,
        AVG(ci.tamanho_interfaz) AS prom_tamano
    FROM stg_s3.controlflag_arquivos ca
    LEFT JOIN trf_s3.tmp_controlflag_interfaces ci
        ON ca.id_camda = ci.id_camda
       AND ca.nome_base = ci.nome_flag_geral
    WHERE ci.tamanho_interfaz >= 400 AND ci.TAMANHO_INTERFAZ IS NOT null
    GROUP BY
        ca.id_camda,
        ca."data"                       ORDER by     ca.ID_CAMDA DESC
),

conjunto AS (
    SELECT
        t.*,
        EXTRACT(
            EPOCH FROM (
                t.momento_ejecucion - t.momento_recebimento
            )
        )::int AS dife,
        CASE
            WHEN EXTRACT(
                EPOCH FROM (
                    t.momento_ejecucion - t.momento_recebimento
                )
            )::int > 65
            THEN 'Manual'
            ELSE 'Automatica'
        END AS tipo
    FROM tiempos t
),

relacion AS (

    -- Manual
    SELECT
        id_camda,
        1 AS orden,
        tipo,
        momento_recebimento AS inicio_ejecucion,
        prom_tamano::int AS tamano,
        momento_ejecucion,
        momento_ejecucion_anterior,
        momento_ejecucion_despues
    FROM conjunto
    WHERE tipo = 'Manual'

    UNION ALL

    -- Automática
    SELECT
        id_camda,
        2 AS orden,
        tipo,
        momento_ejecucion AS inicio_ejecucion,
        prom_tamano::int AS tamano,
        momento_ejecucion,
        momento_ejecucion_anterior,
        momento_ejecucion_despues
    FROM conjunto
    WHERE tipo = 'Automatica'

    UNION ALL

    -- Relación posterior de manuales
    SELECT
        id_camda,
        3 AS orden,
        'Automatica' AS tipo,
        momento_ejecucion AS inicio_ejecucion,
        prom_tamano::int AS tamano,
        momento_ejecucion,
        momento_ejecucion_anterior,
        momento_ejecucion_despues
    FROM conjunto
    WHERE tipo = 'Manual'
),

final_base AS (
    SELECT
        id_camda,
        orden,
        tipo,
        inicio_ejecucion,
        tamano,
        ROW_NUMBER() OVER (
            ORDER BY id_camda DESC, orden DESC
        ) AS rn
    FROM relacion
),

final_calc AS (
    SELECT
        id_camda,
        orden,
        tipo,
        inicio_ejecucion,
        LAG(inicio_ejecucion) OVER (
            ORDER BY id_camda DESC, orden DESC
        ) - inicio_ejecucion AS duracion,
        tamano,
        rn
    FROM final_base
)

SELECT
    id_camda,
    orden,
    tipo,
    inicio_ejecucion + INTERVAL '3 hours' AS inicio_ejecucion,
    duracion,
    CASE
        WHEN orden = 1 THEN 0
        ELSE tamano
    END AS tamano
FROM final_calc
WHERE rn > 1
ORDER BY
    id_camda DESC,
    orden DESC;