-- Most od KPI z dashboardu do wartości realnych, krok po kroku (kroki kumulują się).
-- Okresy: P1 = X 2024 – IX 2025, P2 = X 2025 – IX 2026, po created_at w czasie polskim (A4, A10).
-- Kroki: 0 = jak dashboard (surowe dane, sql/01), 1 = bez duplikatów (A8), 2 = przychód netto po zwrotach.

CREATE OR REPLACE MACRO period(ts) AS
    CASE WHEN ts >= TIMESTAMP '2024-10-01' AND ts < TIMESTAMP '2025-10-01' THEN 'P1'
         WHEN ts >= TIMESTAMP '2025-10-01' AND ts < TIMESTAMP '2026-10-01' THEN 'P2' END;

CREATE OR REPLACE TEMP TABLE o_dedup AS SELECT DISTINCT * FROM raw_orders;

CREATE OR REPLACE TEMP TABLE most AS
SELECT 'zamówienia' kpi, 0 krok, 'dashboard: wszystkie wiersze surowe' opis, period(created_at) p, count(*)::DOUBLE v FROM raw_orders GROUP BY ALL
UNION ALL SELECT 'zamówienia', 1, 'minus duplikaty (A8)', period(created_at), count(*) FROM o_dedup GROUP BY ALL
UNION ALL SELECT 'przychód z konsultacji', 0, 'dashboard: suma amount_paid, surowe, brutto', period(created_at), sum(amount_paid) FROM raw_orders GROUP BY ALL
UNION ALL SELECT 'przychód z konsultacji', 1, 'minus duplikaty (A8)', period(created_at), sum(amount_paid) FROM o_dedup GROUP BY ALL
UNION ALL SELECT 'przychód z konsultacji', 2, 'minus zwroty (refund_amount)', period(created_at), sum(amount_paid - refund_amount) FROM o_dedup GROUP BY ALL;

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
