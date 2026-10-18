-- Diagnoza czułości: najsilniejsze zmiany w metrykach jakości (bez progów), segment 'wszystko'.
-- Wymaga 12_change_points.sql (makro detect pomija progi tylko tu, przez osobne zapytanie).
CREATE OR REPLACE TABLE nothr AS
WITH base AS (
    SELECT metric, kind, dim, seg, day, num, den,
           CASE WHEN kind = 'count' THEN num WHEN den > 0 THEN num / den END AS v,
           row_number() OVER (PARTITION BY metric, dim, seg ORDER BY day) AS i
    FROM series_long WHERE dim = 'wszystko' AND metric NOT LIKE 'K%'
),
noise AS (
    SELECT metric, 1.4826 * median(abs(dv - med)) / sqrt(2) AS sigma
    FROM (SELECT metric, dv, median(dv) OVER (PARTITION BY metric) med
          FROM (SELECT metric, v - lag(v, 7) OVER (PARTITION BY metric ORDER BY day) dv FROM base) WHERE dv IS NOT NULL)
    GROUP BY 1
),
w AS (
    SELECT b.metric, b.kind, b.day,
           sum(num) OVER k1 np, sum(den) OVER k1 dp, count(*) OVER k1 cp,
           sum(num) OVER k2 na, sum(den) OVER k2 da, count(*) OVER k2 ca
    FROM base b
    WINDOW k1 AS (PARTITION BY metric ORDER BY i ROWS BETWEEN 28 PRECEDING AND 1 PRECEDING),
           k2 AS (PARTITION BY metric ORDER BY i ROWS BETWEEN CURRENT ROW AND 27 FOLLOWING)
)
SELECT w.metric, w.day,
       CASE WHEN kind = 'count' THEN np / 28 ELSE np / dp END AS przed,
       CASE WHEN kind = 'count' THEN na / 28 ELSE na / da END AS po,
       n.sigma
FROM w JOIN noise n USING (metric) WHERE cp = 28 AND ca = 28;

-- najsilniejszy spadek i wzrost w każdej metryce (|z| bez progów), z błędem standardowym różnicy
SELECT metric,
       arg_min(day, (po - przed) / (sigma * sqrt(2.0 / 28))) AS dzien_najwiekszego_spadku,
       round(min((po - przed) / (sigma * sqrt(2.0 / 28))), 1) AS z_spadku,
       arg_max(day, (po - przed) / (sigma * sqrt(2.0 / 28))) AS dzien_najwiekszego_wzrostu,
       round(max((po - przed) / (sigma * sqrt(2.0 / 28))), 1) AS z_wzrostu,
       round(any_value(sigma * sqrt(2.0 / 28)), 4) AS blad_roznicy_okien,
       round(any_value(sigma), 4) AS sigma_dzienna
FROM nothr GROUP BY 1 ORDER BY 1;
