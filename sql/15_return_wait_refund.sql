-- Czy rzadziej wraca ten, kto dłużej czekał na lekarza albo dostał zwrot? Pacjenci spoza kampanii i kodów L4.
-- Wymaga: 10_cohorts_daily.sql (patients, patient_windows), 13_mix_by_source.sql (patient_campaign).
-- Cechy liczone na zamówieniu otwierającym kohortę (Q1 a2):
--   czekanie = started_at - scheduled_at w minutach (no_show nie ma started_at -> osobna grupa)
--   status   = completed / refunded / no_show
-- Powrót = Q4 b, okno 90 dni, tylko kohorty z pełnym oknem. Te same miesiące kalendarzowe (III–VI) 2025 vs 2026.

CREATE OR REPLACE TABLE rw AS
SELECT p.user_id, p.cohort_day, year(p.cohort_day) AS rok,
       ao.status, ao.visit_purpose,
       CASE WHEN ao.started_at IS NULL THEN 'brak wizyty (no_show)'
            WHEN date_diff('second', ao.scheduled_at, ao.started_at) / 60.0 < 5  THEN '1 < 5 min'
            WHEN date_diff('second', ao.scheduled_at, ao.started_at) / 60.0 < 15 THEN '2 5–15 min'
            WHEN date_diff('second', ao.scheduled_at, ao.started_at) / 60.0 < 30 THEN '3 15–30 min'
            ELSE '4 ≥ 30 min' END AS czekanie,
       date_diff('second', ao.scheduled_at, ao.started_at) / 60.0 AS czekanie_min,
       w.powrot
FROM patients p
JOIN o ao ON ao.order_id = p.anchor_order_id
JOIN patient_windows w ON w.user_id = p.user_id AND w.okno = 90
JOIN patient_campaign pc ON pc.user_id = p.user_id
WHERE month(p.cohort_day) BETWEEN 3 AND 6
  AND coalesce(pc.kampania, '') NOT IN ('meta_prosp_l4_szybko', 'tt_prosp_l4_15min')
  AND coalesce(ao.promo_code, '') NOT IN ('L4SZYBKO20', 'TIKTOK25');

-- R0 kontrola: liczba pacjentów (powinna się zgadzać z M7 w 13_mix_by_source.sql: 2025 5 228, 2026 5 716)
SELECT rok, count(*) AS pacjenci, count(*) FILTER (powrot) AS powrot_licznik, round(100.0 * avg(powrot::INT), 1) AS powrot_90_pct
FROM rw GROUP BY 1 ORDER BY 1;

-- R1 czekanie na lekarza: udział i powrót 90, 2025 vs 2026
SELECT czekanie,
       count(*) FILTER (rok = 2025) AS pacjenci_2025,
       round(100.0 * count(*) FILTER (rok = 2025) / sum(count(*) FILTER (rok = 2025)) OVER (), 1) AS udzial_2025,
       count(*) FILTER (rok = 2025 AND powrot) AS powrot_2025,
       round(100.0 * count(*) FILTER (rok = 2025 AND powrot) / nullif(count(*) FILTER (rok = 2025), 0), 1) AS powrot_2025_pct,
       count(*) FILTER (rok = 2026) AS pacjenci_2026,
       round(100.0 * count(*) FILTER (rok = 2026) / sum(count(*) FILTER (rok = 2026)) OVER (), 1) AS udzial_2026,
       count(*) FILTER (rok = 2026 AND powrot) AS powrot_2026,
       round(100.0 * count(*) FILTER (rok = 2026 AND powrot) / nullif(count(*) FILTER (rok = 2026), 0), 1) AS powrot_2026_pct
FROM rw GROUP BY 1 ORDER BY 1;

-- R2 status zamówienia otwierającego: udział i powrót 90, 2025 vs 2026
SELECT status,
       count(*) FILTER (rok = 2025) AS pacjenci_2025,
       round(100.0 * count(*) FILTER (rok = 2025) / sum(count(*) FILTER (rok = 2025)) OVER (), 1) AS udzial_2025,
       count(*) FILTER (rok = 2025 AND powrot) AS powrot_2025,
       round(100.0 * count(*) FILTER (rok = 2025 AND powrot) / nullif(count(*) FILTER (rok = 2025), 0), 1) AS powrot_2025_pct,
       count(*) FILTER (rok = 2026) AS pacjenci_2026,
       round(100.0 * count(*) FILTER (rok = 2026) / sum(count(*) FILTER (rok = 2026)) OVER (), 1) AS udzial_2026,
       count(*) FILTER (rok = 2026 AND powrot) AS powrot_2026,
       round(100.0 * count(*) FILTER (rok = 2026 AND powrot) / nullif(count(*) FILTER (rok = 2026), 0), 1) AS powrot_2026_pct
FROM rw GROUP BY 1 ORDER BY 1;

-- R3 rozkład spadku 2025 -> 2026 na: zmianę doświadczenia (więcej czekania / zwrotów przy starych odsetkach powrotu)
--    i zmianę wewnątrz grup (niższy powrót przy tym samym doświadczeniu). Grupa = czekanie × status.
WITH cells AS (
    SELECT czekanie || ' | ' || status AS grupa, rok, count(*) AS n, avg(powrot::INT) AS r
    FROM rw GROUP BY 1, 2
),
sh AS (SELECT grupa, rok, n, r, n::DOUBLE / sum(n) OVER (PARTITION BY rok) AS s FROM cells),
j AS (
    SELECT coalesce(a.grupa, b.grupa) AS grupa,
           coalesce(a.s, 0) s1, coalesce(b.s, 0) s2,
           coalesce(a.r, b.r) r1, coalesce(b.r, a.r) r2
    FROM (SELECT * FROM sh WHERE rok = 2025) a FULL JOIN (SELECT * FROM sh WHERE rok = 2026) b USING (grupa)
)
SELECT round(100 * (sum(s2 * r2) - sum(s1 * r1)), 2) AS zmiana_calkowita_pp,
       round(100 * sum((s2 - s1) * r1), 2) AS efekt_doswiadczenia_pp,
       round(100 * sum(s1 * (r2 - r1)), 2) AS efekt_wewnatrz_grup_pp,
       round(100 * sum((s2 - s1) * (r2 - r1)), 2) AS interakcja_pp
FROM j;

-- R4 kontrola zakłócenia: czekanie a cel wizyty (L4 może mieć inny powrót i inne czekanie), wizyty nie-L4
SELECT czekanie,
       count(*) FILTER (rok = 2025) AS pacjenci_2025,
       round(100.0 * count(*) FILTER (rok = 2025 AND powrot) / nullif(count(*) FILTER (rok = 2025), 0), 1) AS powrot_2025_pct,
       count(*) FILTER (rok = 2026) AS pacjenci_2026,
       round(100.0 * count(*) FILTER (rok = 2026 AND powrot) / nullif(count(*) FILTER (rok = 2026), 0), 1) AS powrot_2026_pct
FROM rw WHERE visit_purpose <> 'l4' AND status <> 'no_show' GROUP BY 1 ORDER BY 1;

-- R5 rozkład czekania (wizyty odbyte): mediana i 90. percentyl, 2025 vs 2026
SELECT rok, count(*) AS wizyty,
       round(median(czekanie_min), 1) AS mediana_min, round(quantile_cont(czekanie_min, 0.9), 1) AS p90_min
FROM rw WHERE czekanie_min IS NOT NULL GROUP BY 1 ORDER BY 1;
