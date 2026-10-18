-- Wykrywanie trwałych zmian w szeregach dziennych. Wymaga: 11_daily_series.sql (series_long) i jego zależności.
--
-- Dla każdego szeregu (metric, dim, seg) i dnia d:
--   przed  = dni [d-28, d-1], po = [d, d+27], trwałość = [d+28, d+55]
--   wartość okna: count -> średnia dzienna num; rate / mean -> sum(num) / sum(den) (z licznikiem i mianownikiem)
--   okno 28 dni ma każdy dzień tygodnia dokładnie 4 razy, więc dzień tygodnia nie przekrzywia średnich
--   szum: sigma = 1.4826 * MAD(v_t - v_{t-7}) / sqrt(2); różnica tydzień do tygodnia usuwa dzień tygodnia
--         i nie rośnie przy trwałej zmianie poziomu (dotyka tylko 7 dni)
--   z = (po - przed) / (sigma * sqrt(2 / 28))
-- Progi (decyzja): |z| >= 5, |zmiana względna| >= 15%, dla odsetków dodatkowo >= 1 pp,
--   wolumen: średnio >= 20 w mianowniku na dzień (count: >= 20 w liczniku).
-- Trwałość: okno [d+28, d+55] w tym samym kierunku co zmiana i >= 50% efektu; gdy brak danych na to okno -> oznaczenie.
-- Szczyt: dzień z największym |z| w promieniu +-28 dni w tym samym szeregu.
-- Placebo: te same obliczenia na danych z wymieszaną kolejnością dni w obrębie dnia tygodnia (3 ziarna).

CREATE OR REPLACE MACRO detect(src) AS TABLE
WITH base AS (
    SELECT metric, kind, dim, seg, day, num, den,
           CASE WHEN kind = 'count' THEN num WHEN den > 0 THEN num / den END AS v,
           row_number() OVER w AS i
    FROM query_table(src)
    WINDOW w AS (PARTITION BY metric, dim, seg ORDER BY day)
),
vol AS (
    SELECT metric, dim, seg,
           avg(CASE WHEN kind = 'count' THEN num ELSE den END) AS sredni_wolumen
    FROM base GROUP BY 1, 2, 3
),
noise AS (
    SELECT metric, dim, seg,
           1.4826 * median(abs(dv - med)) / sqrt(2) AS sigma
    FROM (
        SELECT metric, dim, seg, dv, median(dv) OVER (PARTITION BY metric, dim, seg) AS med
        FROM (SELECT metric, dim, seg, v - lag(v, 7) OVER (PARTITION BY metric, dim, seg ORDER BY day) AS dv FROM base)
        WHERE dv IS NOT NULL
    ) GROUP BY 1, 2, 3
),
win AS (
    SELECT b.*,
           sum(num) OVER (PARTITION BY metric, dim, seg ORDER BY i ROWS BETWEEN 28 PRECEDING AND 1 PRECEDING) AS num_przed,
           sum(den) OVER (PARTITION BY metric, dim, seg ORDER BY i ROWS BETWEEN 28 PRECEDING AND 1 PRECEDING) AS den_przed,
           count(*) OVER (PARTITION BY metric, dim, seg ORDER BY i ROWS BETWEEN 28 PRECEDING AND 1 PRECEDING) AS n_przed,
           sum(num) OVER (PARTITION BY metric, dim, seg ORDER BY i ROWS BETWEEN CURRENT ROW AND 27 FOLLOWING) AS num_po,
           sum(den) OVER (PARTITION BY metric, dim, seg ORDER BY i ROWS BETWEEN CURRENT ROW AND 27 FOLLOWING) AS den_po,
           count(*) OVER (PARTITION BY metric, dim, seg ORDER BY i ROWS BETWEEN CURRENT ROW AND 27 FOLLOWING) AS n_po,
           sum(num) OVER (PARTITION BY metric, dim, seg ORDER BY i ROWS BETWEEN 28 FOLLOWING AND 55 FOLLOWING) AS num_tr,
           sum(den) OVER (PARTITION BY metric, dim, seg ORDER BY i ROWS BETWEEN 28 FOLLOWING AND 55 FOLLOWING) AS den_tr,
           count(*) OVER (PARTITION BY metric, dim, seg ORDER BY i ROWS BETWEEN 28 FOLLOWING AND 55 FOLLOWING) AS n_tr
    FROM base b
),
stat AS (
    SELECT w.metric, w.kind, w.dim, w.seg, w.day,
           w.num_przed, w.den_przed, w.num_po, w.den_po,
           CASE WHEN w.kind = 'count' THEN w.num_przed / 28 ELSE w.num_przed / nullif(w.den_przed, 0) END AS przed,
           CASE WHEN w.kind = 'count' THEN w.num_po / 28    ELSE w.num_po / nullif(w.den_po, 0) END AS po,
           CASE WHEN w.n_tr < 28 THEN NULL
                WHEN w.kind = 'count' THEN w.num_tr / 28 ELSE w.num_tr / nullif(w.den_tr, 0) END AS trwalosc,
           nz.sigma, vl.sredni_wolumen
    FROM win w JOIN noise nz USING (metric, dim, seg) JOIN vol vl USING (metric, dim, seg)
    WHERE w.n_przed = 28 AND w.n_po = 28
),
scored AS (
    SELECT *,
           po - przed AS efekt,
           (po - przed) / nullif(abs(przed), 0) AS efekt_wzgl,
           (po - przed) / nullif(sigma * sqrt(2.0 / 28), 0) AS z
    FROM stat
),
peaks AS (
    SELECT *, max(abs(z)) OVER (PARTITION BY metric, dim, seg ORDER BY day
                                RANGE BETWEEN INTERVAL 28 DAY PRECEDING AND INTERVAL 28 DAY FOLLOWING) AS max_abs_z_okolica
    FROM scored
)
SELECT metric, kind, dim, seg, day, round(sredni_wolumen, 1) AS sredni_wolumen,
       num_przed, den_przed, num_po, den_po,
       przed, po, trwalosc, efekt, efekt_wzgl, z, sigma,
       CASE WHEN trwalosc IS NULL THEN 'brak danych na okno trwałości'
            WHEN sign(trwalosc - przed) = sign(efekt) AND abs(trwalosc - przed) >= 0.5 * abs(efekt) THEN 'trwała'
            ELSE 'nietrwała' END AS trwalosc_ocena
FROM peaks
WHERE abs(z) = max_abs_z_okolica
  -- przy równym z w sąsiednich dniach bierzemy najwcześniejszy
  AND NOT EXISTS (SELECT 1 FROM peaks p2 WHERE p2.metric = peaks.metric AND p2.dim = peaks.dim AND p2.seg = peaks.seg
                  AND p2.day < peaks.day AND p2.day >= peaks.day - INTERVAL 28 DAY AND abs(p2.z) = abs(peaks.z))
  AND abs(z) >= 5
  AND abs(efekt_wzgl) >= 0.15
  AND (kind <> 'rate' OR abs(efekt) >= 0.01)
  AND sredni_wolumen >= 20;

-- ===================== wykrycia na danych =====================
CREATE OR REPLACE TABLE cp_all AS SELECT * FROM detect('series_long');

-- liczba kandydatów przed i po filtrze trwałości
SELECT trwalosc_ocena, count(*) AS kandydaci FROM cp_all GROUP BY 1 ORDER BY 1;

-- ===================== placebo: kolejność dni wymieszana w obrębie dnia tygodnia =====================
CREATE OR REPLACE MACRO shuffled(seed) AS TABLE
WITH r AS (
    SELECT metric, kind, dim, seg, day, num, den,
           row_number() OVER (PARTITION BY metric, dim, seg, dayofweek(day) ORDER BY day) AS rn_dzien,
           row_number() OVER (PARTITION BY metric, dim, seg, dayofweek(day) ORDER BY hash(day::VARCHAR || seed)) AS rn_los
    FROM series_long
)
SELECT a.metric, a.kind, a.dim, a.seg, a.day, b.num, b.den
FROM r a JOIN r b ON a.metric = b.metric AND a.dim = b.dim AND a.seg = b.seg
                 AND dayofweek(a.day) = dayofweek(b.day) AND a.rn_dzien = b.rn_los;

CREATE OR REPLACE TABLE placebo_1 AS SELECT * FROM shuffled('p1');
CREATE OR REPLACE TABLE placebo_2 AS SELECT * FROM shuffled('p2');
CREATE OR REPLACE TABLE placebo_3 AS SELECT * FROM shuffled('p3');

-- placebo: liczba „wykryć” (wszystkie i trwałe) na tych samych progach
SELECT 'dane' AS zbior, count(*) AS wykrycia, count(*) FILTER (trwalosc_ocena = 'trwała') AS trwale FROM cp_all
UNION ALL SELECT 'placebo 1', count(*), count(*) FILTER (trwalosc_ocena = 'trwała') FROM detect('placebo_1')
UNION ALL SELECT 'placebo 2', count(*), count(*) FILTER (trwalosc_ocena = 'trwała') FROM detect('placebo_2')
UNION ALL SELECT 'placebo 3', count(*), count(*) FILTER (trwalosc_ocena = 'trwała') FROM detect('placebo_3');

-- ===================== kalendarz: kampanie i kody =====================
CREATE OR REPLACE TABLE calendar_events AS
SELECT min(date) AS day, 'start kampanii ' || utm_source || ' / ' || utm_campaign AS opis FROM m GROUP BY utm_source, utm_campaign
UNION ALL SELECT max(date), 'koniec kampanii ' || utm_source || ' / ' || utm_campaign FROM m GROUP BY utm_source, utm_campaign
UNION ALL SELECT min(created_at)::DATE, 'pierwsze użycie kodu ' || promo_code FROM o WHERE promo_code IS NOT NULL GROUP BY promo_code
UNION ALL SELECT max(created_at)::DATE, 'ostatnie użycie kodu ' || promo_code FROM o WHERE promo_code IS NOT NULL GROUP BY promo_code;

-- tylko wpisy w środku okresu (start 2024-10-01 i koniec 2026-09-30 to granice danych, nie zdarzenia)
CREATE OR REPLACE TABLE calendar_inner AS
SELECT * FROM calendar_events WHERE day > DATE '2024-10-07' AND day < DATE '2026-09-24';

SELECT day, opis FROM calendar_inner ORDER BY 1;

-- ===================== grupowanie kandydatów w zdarzenia (±3 dni między kolejnymi) =====================
CREATE OR REPLACE TABLE cp_events AS
WITH c AS (
    SELECT *, CASE WHEN day - lag(day) OVER (ORDER BY day) > 3 OR lag(day) OVER (ORDER BY day) IS NULL THEN 1 ELSE 0 END AS nowe
    FROM cp_all WHERE trwalosc_ocena <> 'nietrwała' AND dim <> 'kampania'
)
SELECT *, sum(nowe) OVER (ORDER BY day ROWS UNBOUNDED PRECEDING) AS zdarzenie FROM c;

-- podsumowanie zdarzeń: zakres dni, liczba szeregów, metryki, najbliższy wpis kalendarza (±7 dni)
SELECT e.zdarzenie, min(e.day) AS od, max(e.day) AS do, count(*) AS szeregi,
       count(*) FILTER (e.dim = 'wszystko') AS w_calosci,
       string_agg(DISTINCT left(e.metric, 2), ' ') AS metryki,
       (SELECT string_agg(ci.opis || ' (' || ci.day || ')', '; ') FROM calendar_inner ci
        WHERE ci.day BETWEEN min(e.day) - INTERVAL 7 DAY AND max(e.day) + INTERVAL 7 DAY) AS kalendarz_7_dni
FROM cp_events e GROUP BY 1 ORDER BY 1;

-- zmiany poziomu wydatków na kampanie (szeregi K1)
SELECT seg AS kampania, day, round(przed, 2) AS przed_zl_dzien, round(po, 2) AS po_zl_dzien,
       round(100 * efekt_wzgl, 1) AS zmiana_pct, round(z, 1) AS z, trwalosc_ocena
FROM cp_all WHERE dim = 'kampania' ORDER BY day;

-- szczegóły kandydatów: segment 'wszystko'
SELECT zdarzenie, metric, day, num_przed, den_przed, num_po, den_po,
       round(przed, 4) AS przed, round(po, 4) AS po, round(100 * efekt_wzgl, 1) AS zmiana_pct, round(z, 1) AS z
FROM cp_events WHERE dim = 'wszystko' ORDER BY day, metric;

-- szczegóły kandydatów: segmenty
SELECT zdarzenie, metric, dim, seg, day,
       round(przed, 4) AS przed, round(po, 4) AS po, round(100 * efekt_wzgl, 1) AS zmiana_pct, round(z, 1) AS z, sredni_wolumen
FROM cp_events WHERE dim <> 'wszystko' ORDER BY zdarzenie, metric, dim, seg;

-- zapis wykryć i kalendarza dla narzędzia
COPY (SELECT c.*, e.zdarzenie FROM cp_all c LEFT JOIN cp_events e USING (metric, dim, seg, day) ORDER BY day, metric, dim, seg)
TO 'tool/data/change_points.csv' (HEADER, DELIMITER ',');
COPY (SELECT * FROM calendar_inner ORDER BY day) TO 'tool/data/calendar.csv' (HEADER, DELIMITER ',');
