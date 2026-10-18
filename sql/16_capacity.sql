-- Czy czekanie na lekarza rośnie razem z obciążeniem? Wymaga: 00_raw_views.sql, 03_audit_base.sql (baza A8 + A11).
-- Obciążenie (A12) = wizyty umówione na daną godzinę: scheduled_at, dzień × godzina, czas polski.
--   Do obciążenia liczymy wizyty zarezerwowane: completed, refunded, no_show (cancelled nie zajmuje lekarza).
-- Czekanie = started_at - scheduled_at w minutach, tylko wizyty odbyte (completed, refunded).
-- Okres P1 / P2 według scheduled_at (moment wizyty).

CREATE OR REPLACE TABLE visits AS
SELECT order_id, specialization, consultation_mode, status, scheduled_at,
       date_trunc('hour', scheduled_at) AS godzina_slotu,
       scheduled_at::DATE AS dzien_wizyty,
       hour(scheduled_at) AS godzina_dnia,
       period(scheduled_at) AS okres,
       CASE WHEN started_at IS NOT NULL THEN date_diff('second', scheduled_at, started_at) / 60.0 END AS czekanie_min
FROM o
WHERE status IN ('completed', 'refunded', 'no_show') AND period(scheduled_at) IS NOT NULL;

CREATE OR REPLACE TABLE hourly_load AS
SELECT godzina_slotu, count(*) AS wizyty_w_godzinie FROM visits GROUP BY 1;

CREATE OR REPLACE TABLE daily_load AS
SELECT dzien_wizyty, count(*) AS wizyty_w_dniu FROM visits GROUP BY 1;

CREATE OR REPLACE TABLE v AS
SELECT vi.*, h.wizyty_w_godzinie, d.wizyty_w_dniu
FROM visits vi JOIN hourly_load h USING (godzina_slotu) JOIN daily_load d USING (dzien_wizyty);

-- kontrola: liczba wizyt i wizyt z czekaniem
SELECT okres, count(*) AS wizyty_zarezerwowane, count(czekanie_min) AS wizyty_odbyte_z_czekaniem,
       count(*) FILTER (status = 'no_show') AS no_show
FROM v GROUP BY 1 ORDER BY 1;

-- rozkład obciążenia godzinowego (z perspektywy wizyty): percentyle liczby wizyt w tej samej godzinie
SELECT okres, round(quantile_cont(wizyty_w_godzinie, 0.25), 0) AS p25, round(median(wizyty_w_godzinie), 0) AS mediana,
       round(quantile_cont(wizyty_w_godzinie, 0.75), 0) AS p75, round(quantile_cont(wizyty_w_godzinie, 0.95), 0) AS p95,
       max(wizyty_w_godzinie) AS max
FROM v GROUP BY 1 ORDER BY 1;

-- K1 czekanie według obciążenia godzinowego, P1 vs P2 (te same przedziały obciążenia)
CREATE OR REPLACE MACRO load_bucket(n) AS
    CASE WHEN n <= 3 THEN '01  1–3' WHEN n <= 6 THEN '02  4–6' WHEN n <= 9 THEN '03  7–9'
         WHEN n <= 12 THEN '04 10–12' WHEN n <= 15 THEN '05 13–15' WHEN n <= 20 THEN '06 16–20' ELSE '07 21+' END;

SELECT load_bucket(wizyty_w_godzinie) AS wizyt_w_godzinie, okres,
       count(czekanie_min) AS wizyty_odbyte,
       round(median(czekanie_min), 1) AS mediana_min,
       round(quantile_cont(czekanie_min, 0.9), 1) AS p90_min,
       count(*) FILTER (czekanie_min >= 15) AS czekanie_15_plus,
       round(100.0 * count(*) FILTER (czekanie_min >= 15) / count(czekanie_min), 1) AS pct_15_plus
FROM v WHERE czekanie_min IS NOT NULL GROUP BY 1, 2 ORDER BY 1, 2;

-- K2 czekanie według obciążenia dziennego, P1 vs P2
CREATE OR REPLACE MACRO day_bucket(n) AS
    CASE WHEN n < 50 THEN '1 <50' WHEN n < 75 THEN '2 50–74' WHEN n < 100 THEN '3 75–99'
         WHEN n < 125 THEN '4 100–124' WHEN n < 150 THEN '5 125–149' ELSE '6 150+' END;

SELECT day_bucket(wizyty_w_dniu) AS wizyt_w_dniu, okres,
       count(DISTINCT dzien_wizyty) AS dni,
       count(czekanie_min) AS wizyty_odbyte,
       round(median(czekanie_min), 1) AS mediana_min,
       round(quantile_cont(czekanie_min, 0.9), 1) AS p90_min,
       round(100.0 * count(*) FILTER (czekanie_min >= 15) / count(czekanie_min), 1) AS pct_15_plus
FROM v WHERE czekanie_min IS NOT NULL GROUP BY 1, 2 ORDER BY 1, 2;

-- K3 korelacja rang (Spearman): obciążenie a czekanie, poziom wizyty (godzina) i poziom dnia (p90 czekania dnia)
WITH rk AS (
    SELECT okres, rank() OVER (PARTITION BY okres ORDER BY wizyty_w_godzinie) AS r1,
           rank() OVER (PARTITION BY okres ORDER BY czekanie_min) AS r2
    FROM v WHERE czekanie_min IS NOT NULL
),
dd AS (
    SELECT okres, dzien_wizyty, any_value(wizyty_w_dniu) AS n, quantile_cont(czekanie_min, 0.9) AS p90
    FROM v WHERE czekanie_min IS NOT NULL GROUP BY 1, 2
),
rkd AS (
    SELECT okres, rank() OVER (PARTITION BY okres ORDER BY n) AS r1, rank() OVER (PARTITION BY okres ORDER BY p90) AS r2 FROM dd
)
SELECT 'wizyta: wizyty w godzinie vs czekanie' AS poziom, okres, round(corr(r1, r2), 3) AS spearman, count(*) AS n FROM rk GROUP BY 1, 2
UNION ALL
SELECT 'dzień: wizyty w dniu vs p90 czekania', okres, round(corr(r1, r2), 3), count(*) FROM rkd GROUP BY 1, 2
ORDER BY 1, 2;

-- K4 profil godzin dnia: średnie obciążenie godziny i czekanie, P1 vs P2
SELECT godzina_dnia,
       round(avg(wizyty_w_godzinie) FILTER (okres = 'P1'), 1) AS sr_wizyt_w_godzinie_p1,
       round(quantile_cont(czekanie_min, 0.9) FILTER (okres = 'P1'), 1) AS p90_p1,
       round(avg(wizyty_w_godzinie) FILTER (okres = 'P2'), 1) AS sr_wizyt_w_godzinie_p2,
       round(quantile_cont(czekanie_min, 0.9) FILTER (okres = 'P2'), 1) AS p90_p2,
       round(100.0 * count(*) FILTER (okres = 'P2' AND czekanie_min >= 15) / nullif(count(czekanie_min) FILTER (okres = 'P2'), 0), 1) AS pct_15_plus_p2
FROM v GROUP BY 1 ORDER BY 1;

-- K5 specjalizacja (internista vs pozostali) i tryb: czekanie według obciążenia, P2
SELECT CASE WHEN specialization = 'internista' THEN 'internista' ELSE 'pozostali' END AS grupa,
       load_bucket(wizyty_w_godzinie) AS wizyt_w_godzinie,
       count(czekanie_min) FILTER (okres = 'P1') AS wizyty_p1,
       round(quantile_cont(czekanie_min, 0.9) FILTER (okres = 'P1'), 1) AS p90_p1,
       count(czekanie_min) FILTER (okres = 'P2') AS wizyty_p2,
       round(quantile_cont(czekanie_min, 0.9) FILTER (okres = 'P2'), 1) AS p90_p2
FROM v WHERE czekanie_min IS NOT NULL GROUP BY 1, 2 ORDER BY 1, 2;

SELECT consultation_mode AS tryb,
       count(czekanie_min) FILTER (okres = 'P1') AS wizyty_p1,
       round(quantile_cont(czekanie_min, 0.9) FILTER (okres = 'P1'), 1) AS p90_p1,
       count(czekanie_min) FILTER (okres = 'P2') AS wizyty_p2,
       round(quantile_cont(czekanie_min, 0.9) FILTER (okres = 'P2'), 1) AS p90_p2
FROM v WHERE czekanie_min IS NOT NULL GROUP BY 1 ORDER BY 1;

-- K6 miesięcznie: obciążenie i czekanie (czy czekanie rośnie razem z ruchem)
SELECT date_trunc('month', scheduled_at)::DATE AS miesiac,
       count(*) AS wizyty_zarezerwowane,
       round(avg(wizyty_w_godzinie), 1) AS sr_wizyt_w_godzinie_wizyty,
       round(median(czekanie_min), 1) AS mediana_min,
       round(quantile_cont(czekanie_min, 0.9), 1) AS p90_min,
       round(100.0 * count(*) FILTER (czekanie_min >= 15) / count(czekanie_min), 1) AS pct_15_plus
FROM v GROUP BY 1 ORDER BY 1;

-- K7 internista: rano (6–11) vs reszta dnia, miesięcznie: obciążenie i 90. percentyl czekania
SELECT date_trunc('month', scheduled_at)::DATE AS miesiac,
       count(*) FILTER (godzina_dnia BETWEEN 6 AND 11) AS wizyty_rano,
       round(avg(wizyty_w_godzinie) FILTER (godzina_dnia BETWEEN 6 AND 11), 1) AS sr_obciazenie_rano,
       round(quantile_cont(czekanie_min, 0.9) FILTER (godzina_dnia BETWEEN 6 AND 11), 1) AS p90_rano,
       round(100.0 * count(*) FILTER (godzina_dnia BETWEEN 6 AND 11 AND czekanie_min >= 15)
             / nullif(count(czekanie_min) FILTER (godzina_dnia BETWEEN 6 AND 11), 0), 1) AS pct_15_plus_rano,
       count(*) FILTER (godzina_dnia NOT BETWEEN 6 AND 11) AS wizyty_reszta,
       round(avg(wizyty_w_godzinie) FILTER (godzina_dnia NOT BETWEEN 6 AND 11), 1) AS sr_obciazenie_reszta,
       round(quantile_cont(czekanie_min, 0.9) FILTER (godzina_dnia NOT BETWEEN 6 AND 11), 1) AS p90_reszta
FROM v WHERE specialization = 'internista' GROUP BY 1 ORDER BY 1;

-- K8 internista rano, P2: czekanie a obciążenie w tej samej godzinie (czy rośnie z ruchem także rano)
SELECT load_bucket(wizyty_w_godzinie) AS wizyt_w_godzinie,
       count(czekanie_min) AS wizyty, round(median(czekanie_min), 1) AS mediana_min,
       round(quantile_cont(czekanie_min, 0.9), 1) AS p90_min,
       round(100.0 * count(*) FILTER (czekanie_min >= 15) / count(czekanie_min), 1) AS pct_15_plus
FROM v WHERE specialization = 'internista' AND okres = 'P2' AND godzina_dnia BETWEEN 6 AND 11 AND czekanie_min IS NOT NULL
GROUP BY 1 ORDER BY 1;
