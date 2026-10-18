-- Diagnoza placebo: gdzie powstają fałszywe wykrycia. Wymaga 12_change_points.sql.
CREATE OR REPLACE TABLE pl_all AS
SELECT 'p1' AS ziarno, * FROM detect('placebo_1')
UNION ALL SELECT 'p2', * FROM detect('placebo_2')
UNION ALL SELECT 'p3', * FROM detect('placebo_3');

-- placebo według metryki i wymiaru
SELECT metric, dim, count(*) AS wykrycia, round(median(abs(z)), 1) AS mediana_z, round(max(abs(z)), 1) AS max_z,
       round(median(sredni_wolumen), 1) AS mediana_wolumenu
FROM pl_all GROUP BY 1, 2 ORDER BY 3 DESC LIMIT 20;

-- rozkład |z| w placebo i w danych
SELECT 'placebo' AS zbior, count(*) FILTER (abs(z) >= 5 AND abs(z) < 7) z5_7, count(*) FILTER (abs(z) >= 7 AND abs(z) < 10) z7_10,
       count(*) FILTER (abs(z) >= 10 AND abs(z) < 15) z10_15, count(*) FILTER (abs(z) >= 15) z15plus FROM pl_all
UNION ALL SELECT 'dane', count(*) FILTER (abs(z) >= 5 AND abs(z) < 7), count(*) FILTER (abs(z) >= 7 AND abs(z) < 10),
       count(*) FILTER (abs(z) >= 10 AND abs(z) < 15), count(*) FILTER (abs(z) >= 15) FROM cp_all;

-- przykłady placebo z największym z
SELECT ziarno, metric, dim, seg, day, round(przed, 4) przed, round(po, 4) po, round(z, 1) z, round(sigma, 5) sigma, sredni_wolumen
FROM pl_all ORDER BY abs(z) DESC LIMIT 10;
