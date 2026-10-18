-- Liczby do szkicu listy priorytetów (wartość w zł / miesiąc). Wymaga: 00, 03, 06, 10, 11, 13, 14, 15, 16, 17.
-- Wszystkie wartości to szacunki na podstawie P2; założenia przy każdym zapytaniu.

-- P1 Safari na iPhonie: utracone zamówienia od 17.03.2026 (z D9 w 14_funnel_drilldown.sql)
WITH base AS (
    SELECT f.day, (o2.session_id IS NOT NULL) AS zam, o2.netto
    FROM session_funnel f JOIN s USING (session_id)
    LEFT JOIN (SELECT session_id, sum(amount_paid - refund_amount) netto FROM o GROUP BY 1) o2 USING (session_id)
    WHERE s.browser = 'Safari' AND s.device = 'mobile' AND f.k2
)
SELECT 'P1 Safari iPhone' AS pozycja,
       round(count(*) FILTER (day >= DATE '2026-03-17')
             * (count(*) FILTER (zam AND day >= DATE '2026-02-17' AND day < DATE '2026-03-17')::DOUBLE
                / count(*) FILTER (day >= DATE '2026-02-17' AND day < DATE '2026-03-17'))
             - count(*) FILTER (zam AND day >= DATE '2026-03-17'), 0) AS utracone_zamowienia,
       DATE '2026-09-30' - DATE '2026-03-17' + 1 AS dni,
       round(sum(netto) FILTER (zam AND day >= DATE '2026-03-17') / count(*) FILTER (zam AND day >= DATE '2026-03-17'), 2) AS netto_na_zamowienie
FROM base;

-- P1b marża na zamówienie w Safari na iPhonie (netto - koszt lekarza), żeby przeliczyć utracony przychód na marżę
SELECT round(avg(x.amount_paid - x.refund_amount
                 - CASE WHEN x.status IN ('completed', 'refunded') THEN doctor_cost(x.specialization) ELSE 0 END), 2) AS marza_na_zamowienie,
       count(*) AS zamowienia
FROM o x JOIN s USING (session_id)
WHERE s.browser = 'Safari' AND s.device = 'mobile' AND x.created_at >= TIMESTAMP '2026-03-17';

-- P2 poranne czekanie u internistów: ilu nowych pacjentów (wszystkich) miesięcznie czeka >= 15 min
--    i ile powrotów 90 dni tracimy względem grupy < 15 min; wartość powrotu = średnia marża z kolejnych zamówień w 90 dniach
WITH pw AS (
    SELECT p.user_id, p.cohort_day,
           date_diff('second', ao.scheduled_at, ao.started_at) / 60.0 AS czekanie,
           w.powrot
    FROM patients p JOIN o ao ON ao.order_id = p.anchor_order_id
    JOIN patient_windows w ON w.user_id = p.user_id AND w.okno = 90
    WHERE p.cohort_day BETWEEN DATE '2026-01-01' AND DATE '2026-07-02' AND ao.started_at IS NOT NULL
),
nxt AS (
    -- marża z kolejnych zamówień w 90 dniach u powracających (bez zamówienia otwierającego)
    SELECT avg(m) AS marza_kolejnych_na_powracajacego FROM (
        SELECT p.user_id, sum(x.amount_paid - x.refund_amount
               - CASE WHEN x.status IN ('completed', 'refunded') THEN doctor_cost(x.specialization) ELSE 0 END) AS m
        FROM patients p JOIN o x ON x.user_id = p.user_id AND x.order_id <> p.anchor_order_id
             AND x.created_at >= p.t0 AND x.created_at < p.t0 + INTERVAL 90 DAY
        WHERE p.cohort_day BETWEEN DATE '2026-01-01' AND DATE '2026-07-02'
        GROUP BY 1
    )
)
SELECT 'P2 czekanie' AS pozycja,
       count(*) AS pacjenci, round(count(*) / 6.07, 0) AS pacjenci_miesiecznie,   -- 1.01–2.07.2026 = 6,07 miesiąca
       count(*) FILTER (czekanie >= 15) AS czekali_15_plus,
       round(100.0 * count(*) FILTER (czekanie >= 15) / count(*), 1) AS pct_15_plus,
       round(100.0 * avg(powrot::INT) FILTER (czekanie < 15), 1) AS powrot_ponizej_15,
       round(100.0 * avg(powrot::INT) FILTER (czekanie >= 15), 1) AS powrot_15_plus,
       round(count(*) FILTER (czekanie >= 15) / 6.07
             * (avg(powrot::INT) FILTER (czekanie < 15) - avg(powrot::INT) FILTER (czekanie >= 15)), 1) AS utracone_powroty_miesiecznie,
       round(any_value(n.marza_kolejnych_na_powracajacego), 2) AS marza_kolejnych_na_powracajacego
FROM pw CROSS JOIN nxt n;

-- P3 kampanie L4 i gs_generic_specjalisci: pacjenci miesięcznie i (marża − CAC) na pacjenta z cac_table (okno 180 i 90)
SELECT okno, jednostka, pacjenci_lnd, round(koszt, 2) AS koszt,
       round(pacjenci_lnd / CASE okno WHEN 180 THEN 6.1 ELSE 9.07 END, 0) AS pacjenci_miesiecznie,   -- 1.10–3.04 = 6,1 mies.; 1.10–2.07 = 9,07 mies.
       marza_minus_cac,
       round(marza_minus_cac * pacjenci_lnd / CASE okno WHEN 180 THEN 6.1 ELSE 9.07 END, 0) AS wynik_miesiecznie_zl
FROM cac_table
WHERE jednostka LIKE '%l4_szybko%' OR jednostka LIKE '%l4_15min%' OR jednostka LIKE '%specjalisci%'
ORDER BY jednostka, okno;

-- P3b wydatki miesięczne na kampanie L4 i specjalistów w ostatnich 3 miesiącach (VII–IX 2026)
SELECT utm_campaign, round(sum(spend_pln) / 3, 0) AS wydatki_miesiecznie_vii_ix
FROM m WHERE date >= DATE '2026-07-01' AND utm_campaign IN ('meta_prosp_l4_szybko', 'tt_prosp_l4_15min', 'gs_generic_specjalisci')
GROUP BY 1 ORDER BY 1;

-- P4 zwroty refunded przy L4 (internista, wszystkie kody): miesięcznie w VII–IX 2026 i nadwyżka ponad poziom z P1
SELECT round(count(*) FILTER (status = 'refunded' AND created_at >= TIMESTAMP '2026-07-01') / 3.0, 0) AS refunded_l4_miesiecznie,
       round(sum(refund_amount) FILTER (status = 'refunded' AND created_at >= TIMESTAMP '2026-07-01') / 3.0, 0) AS zwroty_l4_zl_miesiecznie,
       round(100.0 * count(*) FILTER (status = 'refunded' AND created_at >= TIMESTAMP '2026-07-01')
             / count(*) FILTER (created_at >= TIMESTAMP '2026-07-01'), 1) AS pct_refunded_vii_ix,
       round(100.0 * count(*) FILTER (status = 'refunded' AND period(created_at) = 'P1')
             / count(*) FILTER (period(created_at) = 'P1'), 1) AS pct_refunded_p1,
       round((count(*) FILTER (status = 'refunded' AND created_at >= TIMESTAMP '2026-07-01')
              - count(*) FILTER (created_at >= TIMESTAMP '2026-07-01')
                * (count(*) FILTER (status = 'refunded' AND period(created_at) = 'P1')::DOUBLE / count(*) FILTER (period(created_at) = 'P1')))
             / 3.0 * avg(refund_amount) FILTER (status = 'refunded' AND created_at >= TIMESTAMP '2026-07-01'), 0) AS nadwyzka_zwrotow_zl_miesiecznie
FROM o WHERE specialization = 'internista' AND visit_purpose = 'l4';

-- P5 skala decyzji dla testu przyrostowości (N2): wydatki za klik miesięcznie w VII–IX 2026
SELECT round(sum(spend_pln) / 3, 0) AS wydatki_za_klik_miesiecznie_vii_ix FROM m WHERE date >= DATE '2026-07-01';
