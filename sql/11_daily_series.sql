-- Szeregi dzienne w segmentach do wykrywania zdarzeń. Wymaga: 00_raw_views.sql, 03_audit_base.sql,
-- 06_audit_h4.sql (paid_pairs, user_visitor, channel), 10_cohorts_daily.sql (patients, patient_windows).
-- Format długi: metric, dim, seg, day, num, den. Dzień polski (A4). Baza A8 + A11.
--   rodzaj 'count': wartość = num (den = NULL)
--   rodzaj 'rate' : wartość = num / den (odsetek)
--   rodzaj 'mean' : wartość = num / den (średnia na pacjenta)
-- Segmenty: jeden wymiar naraz, bez krzyżowania.

CREATE OR REPLACE TABLE calendar AS
SELECT range::DATE AS day FROM range(DATE '2024-10-01', DATE '2026-10-01', INTERVAL 1 DAY);

CREATE OR REPLACE MACRO landing_group(lp) AS
    CASE WHEN lp LIKE '/blog/%' THEN '/blog/*'
         WHEN lp LIKE '/specjalisci%' THEN '/specjalisci*'
         ELSE lp END;

CREATE OR REPLACE MACRO browser_type(b) AS
    CASE WHEN b IN ('Instagram', 'Facebook', 'TikTok') THEN 'w aplikacji' ELSE 'zwykła' END;

-- segmenty sesji w formacie długim (sesja -> kilka par dim/seg)
CREATE OR REPLACE TABLE session_segments AS
SELECT session_id, 'wszystko' AS dim, 'wszystko' AS seg FROM s
UNION ALL SELECT session_id, 'urządzenie', device FROM s
UNION ALL SELECT session_id, 'przeglądarka', browser FROM s
UNION ALL SELECT session_id, 'typ przeglądarki', browser_type(browser) FROM s
UNION ALL SELECT session_id, 'źródło', channel(utm_source, utm_medium) FROM s
UNION ALL SELECT session_id, 'strona wejścia', landing_group(landing_page) FROM s;

-- ===================== lejek (sesje) =====================
CREATE OR REPLACE TABLE session_funnel AS
WITH ev AS (
    SELECT session_id,
           bool_or(event_name = 'service_selected')  AS e1,
           bool_or(event_name = 'slot_selected')     AS e2,
           bool_or(event_name = 'account_completed') AS e3,
           bool_or(event_name = 'payment_started')   AS e4,
           bool_or(event_name = 'payment_succeeded') AS e5
    FROM e GROUP BY 1
)
SELECT s.session_id, s.started_at::DATE AS day,
       coalesce(ev.e1, false) AS k1,
       coalesce(ev.e1 AND ev.e2, false) AS k2,
       coalesce(ev.e1 AND ev.e2 AND (ev.e3 OR s.user_id IS NOT NULL), false) AS k3,   -- konto: account_completed albo user_id
       coalesce(ev.e1 AND ev.e2 AND (ev.e3 OR s.user_id IS NOT NULL) AND ev.e4, false) AS k4,
       coalesce(ev.e1 AND ev.e2 AND (ev.e3 OR s.user_id IS NOT NULL) AND ev.e4 AND ev.e5, false) AS k5
FROM s LEFT JOIN ev USING (session_id);

CREATE OR REPLACE TABLE series_funnel AS
SELECT ss.dim, ss.seg, f.day,
       count(*) AS sesje,
       count(*) FILTER (k1) AS k1, count(*) FILTER (k2) AS k2, count(*) FILTER (k3) AS k3,
       count(*) FILTER (k4) AS k4, count(*) FILTER (k5) AS k5
FROM session_funnel f JOIN session_segments ss USING (session_id)
GROUP BY 1, 2, 3;

-- ===================== zamówienia (dzień created_at, segment z sesji zamówienia) =====================
CREATE OR REPLACE TABLE series_orders AS
SELECT ss.dim, ss.seg, o.created_at::DATE AS day,
       count(*) AS zamowienia,
       count(*) FILTER (o.visit_purpose = 'l4') AS l4,
       count(*) FILTER (o.status = 'refunded')  AS refunded,
       count(*) FILTER (o.status = 'cancelled') AS cancelled
FROM o JOIN session_segments ss USING (session_id)
GROUP BY 1, 2, 3;

-- ===================== kohorty (dzień kohorty, segment z sesji zamówienia otwierającego; źródło wg lnd, Q3) =====================
CREATE OR REPLACE TABLE patient_channel AS
SELECT p.user_id,
       coalesce((SELECT channel(s2.utm_source, s2.utm_medium) FROM user_visitor uv JOIN s s2 USING (visitor_id)
                 WHERE uv.user_id = p.user_id AND s2.started_at <= p.t0 AND s2.utm_source IS NOT NULL
                 ORDER BY s2.started_at DESC, s2.session_id DESC LIMIT 1), '(direct)') AS ch_lnd
FROM patients p;

CREATE OR REPLACE TABLE patient_segments AS
SELECT p.user_id, 'wszystko' AS dim, 'wszystko' AS seg FROM patients p
UNION ALL SELECT p.user_id, 'urządzenie', s.device FROM patients p JOIN o ON o.order_id = p.anchor_order_id JOIN s USING (session_id)
UNION ALL SELECT p.user_id, 'przeglądarka', s.browser FROM patients p JOIN o ON o.order_id = p.anchor_order_id JOIN s USING (session_id)
UNION ALL SELECT p.user_id, 'typ przeglądarki', browser_type(s.browser) FROM patients p JOIN o ON o.order_id = p.anchor_order_id JOIN s USING (session_id)
UNION ALL SELECT p.user_id, 'strona wejścia', landing_group(s.landing_page) FROM patients p JOIN o ON o.order_id = p.anchor_order_id JOIN s USING (session_id)
UNION ALL SELECT user_id, 'źródło', ch_lnd FROM patient_channel;

CREATE OR REPLACE TABLE series_cohorts AS
SELECT ps.dim, ps.seg, p.cohort_day AS day,
       count(*) AS nowi,
       count(*) FILTER (ao.visit_purpose = 'l4') AS l4_pierwsze,
       count(*) FILTER (ao.status = 'refunded') AS refunded_pierwsze,
       count(w30.user_id) AS m30, count(*) FILTER (w30.powrot) AS r30,
       count(w90.user_id) AS m90, count(*) FILTER (w90.powrot) AS r90,
       sum((w90.netto_zamowienia + w90.oplaty_go - w90.koszt_lekarza)::DECIMAL(14, 2)) AS marza90
FROM patients p
JOIN patient_segments ps USING (user_id)
JOIN o ao ON ao.order_id = p.anchor_order_id
LEFT JOIN patient_windows w30 ON w30.user_id = p.user_id AND w30.okno = 30
LEFT JOIN patient_windows w90 ON w90.user_id = p.user_id AND w90.okno = 90
GROUP BY 1, 2, 3;

-- ===================== kampanie: wydatki dzienne =====================
CREATE OR REPLACE TABLE series_spend AS
SELECT 'kampania' AS dim, utm_source || ' / ' || utm_campaign AS seg, date AS day, sum(spend_pln::DECIMAL(14, 2)) AS spend
FROM m GROUP BY 1, 2, 3;

-- ===================== format długi + uzupełnienie dni bez zdarzeń =====================
CREATE OR REPLACE TABLE series_long_raw AS
          SELECT 'F0 sesje' metric, 'count' kind, dim, seg, day, sesje::DOUBLE num, NULL::DOUBLE den FROM series_funnel
UNION ALL SELECT 'F1 sesja → usługa', 'rate', dim, seg, day, k1, sesje FROM series_funnel
UNION ALL SELECT 'F2 usługa → termin', 'rate', dim, seg, day, k2, k1 FROM series_funnel
UNION ALL SELECT 'F3 termin → konto', 'rate', dim, seg, day, k3, k2 FROM series_funnel
UNION ALL SELECT 'F4 konto → start płatności', 'rate', dim, seg, day, k4, k3 FROM series_funnel
UNION ALL SELECT 'F5 start → płatność', 'rate', dim, seg, day, k5, k4 FROM series_funnel
UNION ALL SELECT 'F6 sesja → płatność', 'rate', dim, seg, day, k5, sesje FROM series_funnel
UNION ALL SELECT 'O1 udział L4 w zamówieniach', 'rate', dim, seg, day, l4, zamowienia FROM series_orders
UNION ALL SELECT 'O2 refunded', 'rate', dim, seg, day, refunded, zamowienia FROM series_orders
UNION ALL SELECT 'O3 cancelled', 'rate', dim, seg, day, cancelled, zamowienia FROM series_orders
UNION ALL SELECT 'C1 nowi pacjenci', 'count', dim, seg, day, nowi, NULL FROM series_cohorts
UNION ALL SELECT 'C2 L4 w pierwszym zamówieniu', 'rate', dim, seg, day, l4_pierwsze, nowi FROM series_cohorts
UNION ALL SELECT 'C3 refunded w pierwszym zamówieniu', 'rate', dim, seg, day, refunded_pierwsze, nowi FROM series_cohorts
UNION ALL SELECT 'C4 powrót 30 dni', 'rate', dim, seg, day, r30, m30 FROM series_cohorts WHERE m30 > 0
UNION ALL SELECT 'C5 powrót 90 dni', 'rate', dim, seg, day, r90, m90 FROM series_cohorts WHERE m90 > 0
UNION ALL SELECT 'C6 marża 90 dni na pacjenta', 'mean', dim, seg, day, marza90, m90 FROM series_cohorts WHERE m90 > 0
UNION ALL SELECT 'K1 wydatki na kampanię', 'count', dim, seg, day, spend, NULL FROM series_spend;

-- zakres dni każdego szeregu: od pierwszego dnia z danymi do ostatniego dnia z danymi okna
-- (metryki C4–C6 kończą się na ostatnim dniu z pełnym oknem; dni bez zdarzeń w środku = 0).
-- Start od pierwszego dnia z danymi: szereg, który zaczyna się w środku okresu (np. TikTok od II 2026),
-- nie ma sztucznych zer przed startem; sam start widać w kalendarzu kampanii i kodów (placebo to wykazało).
CREATE OR REPLACE TABLE series_long AS
WITH rng AS (
    SELECT metric, kind, dim, seg,
           CASE WHEN metric = 'C4 powrót 30 dni' THEN DATE '2026-08-31'
                WHEN metric IN ('C5 powrót 90 dni', 'C6 marża 90 dni na pacjenta') THEN DATE '2026-07-02'
                ELSE DATE '2026-09-30' END AS last_day,
           min(day) AS first_day
    FROM series_long_raw GROUP BY metric, kind, dim, seg
)
SELECT r.metric, r.kind, r.dim, r.seg, c.day,
       coalesce(x.num, 0) AS num,
       CASE WHEN r.kind = 'count' THEN NULL ELSE coalesce(x.den, 0) END AS den
FROM rng r JOIN calendar c ON c.day BETWEEN r.first_day AND r.last_day
LEFT JOIN series_long_raw x ON x.metric = r.metric AND x.dim = r.dim AND x.seg = r.seg AND x.day = c.day;

-- kontrola: liczba szeregów i wierszy według metryki
SELECT metric, kind, count(DISTINCT dim || '|' || seg) AS szeregi, count(*) AS wiersze, min(day) AS od, max(day) AS do
FROM series_long GROUP BY 1, 2 ORDER BY 1;

-- kontrola spójności: segment 'wszystko' zgadza się z bazą
SELECT 'sesje' AS co, (SELECT sum(num) FROM series_long WHERE metric = 'F0 sesje' AND dim = 'wszystko') AS z_szeregu, (SELECT count(*) FROM s) AS z_bazy
UNION ALL SELECT 'nowi pacjenci', (SELECT sum(num) FROM series_long WHERE metric = 'C1 nowi pacjenci' AND dim = 'wszystko'), (SELECT count(*) FROM patients)
UNION ALL SELECT 'zamówienia (mianownik O2)', (SELECT sum(den) FROM series_long WHERE metric = 'O2 refunded' AND dim = 'wszystko'), (SELECT count(*) FROM o)
UNION ALL SELECT 'płatności lejka k5 vs sesje z payment_succeeded i usługą', (SELECT sum(num) FROM series_long WHERE metric = 'F6 sesja → płatność' AND dim = 'wszystko'),
          (SELECT count(*) FROM session_funnel WHERE k5);

-- zapis agregatów dziennych dla narzędzia (bez danych na poziomie pacjenta / sesji / zamówienia)
COPY (SELECT metric, kind, dim, seg, day, num, den FROM series_long ORDER BY metric, dim, seg, day)
TO 'tool/data/daily_series.csv' (HEADER, DELIMITER ',');
