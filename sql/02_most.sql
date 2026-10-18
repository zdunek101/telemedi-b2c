-- Most od KPI z dashboardu do wartości realnych, krok po kroku (kroki kumulują się).
-- Okresy: P1 = X 2024 – IX 2025, P2 = X 2025 – IX 2026, po created_at w czasie polskim (A4, A10).
-- Kroki: 0 = jak dashboard (surowe dane, sql/01), 1 = bez duplikatów (A8),
--        2 = bez kont testowych (A11), 3 = przychód netto po zwrotach.

CREATE OR REPLACE MACRO period(ts) AS
    CASE WHEN ts >= TIMESTAMP '2024-10-01' AND ts < TIMESTAMP '2025-10-01' THEN 'P1'
         WHEN ts >= TIMESTAMP '2025-10-01' AND ts < TIMESTAMP '2026-10-01' THEN 'P2' END;

CREATE OR REPLACE TEMP TABLE o_dedup AS SELECT DISTINCT * FROM raw_orders;
-- konta testowe (A11): każde konto, które choć raz użyło kodu TEST-QA; wykluczamy wszystkie ich zamówienia
CREATE OR REPLACE TEMP TABLE test_users AS SELECT DISTINCT user_id FROM raw_orders WHERE promo_code = 'TEST-QA';
CREATE OR REPLACE TEMP TABLE o_clean AS SELECT * FROM o_dedup WHERE user_id NOT IN (SELECT user_id FROM test_users);

-- pierwsze zamówienie pacjenta jak w dashboardzie (Q1: dowolny status)
CREATE OR REPLACE MACRO first_orders(tbl) AS TABLE
    SELECT user_id, min(created_at) AS created_at FROM query_table(tbl) GROUP BY 1;

CREATE OR REPLACE TEMP TABLE most AS
SELECT 'zamówienia' kpi, 0 krok, 'dashboard: wszystkie wiersze surowe' opis, period(created_at) p, count(*)::DOUBLE v FROM raw_orders GROUP BY ALL
UNION ALL SELECT 'zamówienia', 1, 'minus duplikaty (A8)', period(created_at), count(*) FROM o_dedup GROUP BY ALL
UNION ALL SELECT 'zamówienia', 2, 'minus konta testowe (A11)', period(created_at), count(*) FROM o_clean GROUP BY ALL
UNION ALL SELECT 'przychód z konsultacji', 0, 'dashboard: suma amount_paid, surowe, brutto', period(created_at), sum(amount_paid) FROM raw_orders GROUP BY ALL
UNION ALL SELECT 'przychód z konsultacji', 1, 'minus duplikaty (A8)', period(created_at), sum(amount_paid) FROM o_dedup GROUP BY ALL
UNION ALL SELECT 'przychód z konsultacji', 2, 'minus konta testowe (A11)', period(created_at), sum(amount_paid) FROM o_clean GROUP BY ALL
UNION ALL SELECT 'przychód z konsultacji', 3, 'minus zwroty (refund_amount)', period(created_at), sum(amount_paid - refund_amount) FROM o_clean GROUP BY ALL
UNION ALL SELECT 'nowi pacjenci', 0, 'dashboard: pierwsze zamówienie, dowolny status', period(created_at), count(*) FROM first_orders('raw_orders') GROUP BY ALL
UNION ALL SELECT 'nowi pacjenci', 2, 'minus konta testowe (A11)', period(created_at), count(*) FROM first_orders('o_clean') GROUP BY ALL;

WITH w AS (
    SELECT kpi, krok, opis,
           max(v) FILTER (p = 'P1') p1, max(v) FILTER (p = 'P2') p2
    FROM most GROUP BY ALL
)
SELECT kpi, krok, opis,
       round(p1, 2) AS p1_x24_ix25,
       round(p2, 2) AS p2_x25_ix26,
       round(p1 - lag(p1) OVER k, 2) AS zmiana_p1,
       round(p2 - lag(p2) OVER k, 2) AS zmiana_p2,
       round(100 * (p2 / p1 - 1), 1) AS wzrost_pct,
       round(100 * (p2 / p1 - 1) - lag(100 * (p2 / p1 - 1)) OVER k, 1) AS zmiana_wzrostu_pp
FROM w
WINDOW k AS (PARTITION BY kpi ORDER BY krok)
ORDER BY kpi DESC, krok;
