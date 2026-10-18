-- Odtworzenie KPI z dashboardu (docs/zadanie.md) na surowych danych, bez czyszczenia.
-- Okresy: P1 = X 2024 – IX 2025, P2 = X 2025 – IX 2026, po czasie polskim
-- (orders.created_at, go_memberships.purchased_at i users.registered_at już są w czasie polskim).
-- Każdy KPI liczony w kilku wariantach definicji; wynik: wartość P1, wartość P2, zmiana.

CREATE OR REPLACE MACRO period(ts) AS
    CASE WHEN ts >= TIMESTAMP '2024-10-01' AND ts < TIMESTAMP '2025-10-01' THEN 'P1'
         WHEN ts >= TIMESTAMP '2025-10-01' AND ts < TIMESTAMP '2026-10-01' THEN 'P2' END;

CREATE OR REPLACE TEMP TABLE o_raw AS SELECT * FROM raw_orders;
CREATE OR REPLACE TEMP TABLE o_dedup AS SELECT DISTINCT * FROM raw_orders;

-- pierwszy zakup pacjenta w różnych wariantach
CREATE OR REPLACE TEMP TABLE first_any AS            -- pierwsze zamówienie, dowolny status
    SELECT user_id, min(created_at) t FROM o_raw GROUP BY 1;
CREATE OR REPLACE TEMP TABLE first_not_cancelled AS  -- pierwsze zamówienie nieanulowane
    SELECT user_id, min(created_at) t FROM o_raw WHERE status <> 'cancelled' GROUP BY 1;
CREATE OR REPLACE TEMP TABLE first_incl_go AS        -- pierwszy zakup: zamówienie albo GO kupione osobno
    SELECT user_id, min(t) t FROM (
        SELECT user_id, created_at t FROM o_raw
        UNION ALL SELECT user_id, purchased_at FROM raw_go_memberships
    ) GROUP BY 1;

CREATE OR REPLACE TEMP TABLE kpi AS
-- 1. pacjenci z pierwszym zakupem (dashboard +52%)
SELECT '1 pacjenci z pierwszym zakupem' kpi, 'a) pierwsze zamówienie, dowolny status' wariant, period(t) p, count(*) v FROM first_any GROUP BY ALL
UNION ALL SELECT '1 pacjenci z pierwszym zakupem', 'b) pierwsze zamówienie nieanulowane', period(t), count(*) FROM first_not_cancelled GROUP BY ALL
UNION ALL SELECT '1 pacjenci z pierwszym zakupem', 'c) pierwszy zakup: zamówienie lub samo GO', period(t), count(*) FROM first_incl_go GROUP BY ALL
UNION ALL SELECT '1 pacjenci z pierwszym zakupem', 'd) unikalni kupujący w okresie (nie tylko nowi)', period(created_at), count(DISTINCT user_id) FROM o_raw GROUP BY ALL
UNION ALL SELECT '1 pacjenci z pierwszym zakupem', 'e) nowe konta (registered_at)', period(registered_at), count(*) FROM raw_users GROUP BY ALL
-- 2. zamówienia (dashboard +61%)
UNION ALL SELECT '2 zamówienia', 'a) wiersze surowe, wszystkie statusy', period(created_at), count(*) FROM o_raw GROUP BY ALL
UNION ALL SELECT '2 zamówienia', 'b) unikalne order_id, wszystkie statusy', period(created_at), count(DISTINCT order_id) FROM o_raw GROUP BY ALL
UNION ALL SELECT '2 zamówienia', 'c) wiersze surowe bez cancelled', period(created_at), count(*) FROM o_raw WHERE status <> 'cancelled' GROUP BY ALL
UNION ALL SELECT '2 zamówienia', 'd) wiersze surowe completed', period(created_at), count(*) FROM o_raw WHERE status = 'completed' GROUP BY ALL
UNION ALL SELECT '2 zamówienia', 'e) wiersze surowe + zakupy samego GO', period(t), count(*) FROM (
        SELECT created_at t FROM o_raw UNION ALL SELECT purchased_at FROM raw_go_memberships WHERE order_id IS NULL) GROUP BY ALL
-- 3. przychód z konsultacji (dashboard +50%)
UNION ALL SELECT '3 przychód z konsultacji', 'a) suma amount_paid, wiersze surowe', period(created_at), round(sum(amount_paid), 2) FROM o_raw GROUP BY ALL
UNION ALL SELECT '3 przychód z konsultacji', 'b) suma amount_paid, bez duplikatów', period(created_at), round(sum(amount_paid), 2) FROM o_dedup GROUP BY ALL
UNION ALL SELECT '3 przychód z konsultacji', 'c) amount_paid − refund_amount, wiersze surowe', period(created_at), round(sum(amount_paid - refund_amount), 2) FROM o_raw GROUP BY ALL
UNION ALL SELECT '3 przychód z konsultacji', 'd) suma list_price, wiersze surowe', period(created_at), round(sum(list_price), 2) FROM o_raw GROUP BY ALL
UNION ALL SELECT '3 przychód z konsultacji', 'e) amount_paid + opłaty GO, wiersze surowe', period(t), round(sum(x), 2) FROM (
        SELECT created_at t, amount_paid x FROM o_raw UNION ALL SELECT purchased_at, amount_paid FROM raw_go_memberships) GROUP BY ALL
-- 4. sprzedane TelemediGO (dashboard +40%)
UNION ALL SELECT '4 sprzedane TelemediGO', 'a) wszystkie członkostwa', period(purchased_at), count(*) FROM raw_go_memberships GROUP BY ALL
UNION ALL SELECT '4 sprzedane TelemediGO', 'b) tylko kupione przy zamówieniu', period(purchased_at), count(*) FROM raw_go_memberships WHERE order_id IS NOT NULL GROUP BY ALL
UNION ALL SELECT '4 sprzedane TelemediGO', 'c) tylko kupione osobno', period(purchased_at), count(*) FROM raw_go_memberships WHERE order_id IS NULL GROUP BY ALL
UNION ALL SELECT '4 sprzedane TelemediGO', 'd) unikalni pacjenci z GO', period(purchased_at), count(DISTINCT user_id) FROM raw_go_memberships GROUP BY ALL
UNION ALL SELECT '4 sprzedane TelemediGO', 'e) zamówienia z discount_type = go', period(created_at), count(*) FROM o_raw WHERE discount_type = 'go' GROUP BY ALL;

SELECT kpi, wariant,
       max(v) FILTER (p = 'P1') AS p1_x24_ix25,
       max(v) FILTER (p = 'P2') AS p2_x25_ix26,
       round(100.0 * (max(v) FILTER (p = 'P2') / max(v) FILTER (p = 'P1') - 1), 1) AS zmiana_pct,
       max(v) FILTER (p IS NULL) AS poza_okresem
FROM kpi GROUP BY ALL ORDER BY kpi, wariant;
