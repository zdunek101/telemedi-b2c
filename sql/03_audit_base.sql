-- Baza audytu: wspólne makra i tabele robocze. Wymaga sql/00_raw_views.sql.
-- Niczego nie usuwa z danych; deduplikacja zamówień (A8) jest bazą dla zamówień i przychodu.
-- Czas: wszystko w Europe/Warsaw (A4). Sesje i zdarzenia konwertowane z UTC strefą, nie stałym przesunięciem.

SET TimeZone = 'Europe/Warsaw';

CREATE OR REPLACE MACRO period(ts) AS
    CASE WHEN ts >= TIMESTAMP '2024-10-01' AND ts < TIMESTAMP '2025-10-01' THEN 'P1'
         WHEN ts >= TIMESTAMP '2025-10-01' AND ts < TIMESTAMP '2026-10-01' THEN 'P2' END;

-- UTC (TIMESTAMP bez strefy) -> czas polski (TIMESTAMP bez strefy)
CREATE OR REPLACE MACRO utc_to_pl(ts) AS timezone('Europe/Warsaw', timezone('UTC', ts));

-- wzrost P2/P1 w %
CREATE OR REPLACE MACRO growth(p1, p2) AS round(100.0 * (p2 / p1 - 1), 1);

CREATE OR REPLACE TABLE o AS SELECT DISTINCT * FROM raw_orders;            -- 65 278 zamówień (A8)
CREATE OR REPLACE TABLE g AS SELECT * FROM raw_go_memberships;
CREATE OR REPLACE TABLE u AS SELECT * FROM raw_users;
CREATE OR REPLACE TABLE s AS
    SELECT * EXCLUDE (started_at_utc), utc_to_pl(started_at_utc) AS started_at
    FROM raw_sessions;
CREATE OR REPLACE TABLE e AS
    SELECT * EXCLUDE (event_at_utc), utc_to_pl(event_at_utc) AS event_at
    FROM raw_events;
CREATE OR REPLACE TABLE m AS SELECT * FROM raw_marketing_spend;

-- pierwszy zakup pacjenta jak w dashboardzie (Q1: najwcześniejsze created_at, dowolny status)
CREATE OR REPLACE TABLE first_order AS
    SELECT * FROM o QUALIFY row_number() OVER (PARTITION BY user_id ORDER BY created_at, order_id) = 1;

-- bazowe wartości KPI
CREATE OR REPLACE TABLE base AS
SELECT
    count(*) FILTER (period(created_at) = 'P1')                                  AS orders_p1,
    count(*) FILTER (period(created_at) = 'P2')                                  AS orders_p2,
    sum(amount_paid) FILTER (period(created_at) = 'P1')                          AS rev_p1,
    sum(amount_paid) FILTER (period(created_at) = 'P2')                          AS rev_p2,
    (SELECT count(*) FROM first_order WHERE period(created_at) = 'P1')           AS new_p1,
    (SELECT count(*) FROM first_order WHERE period(created_at) = 'P2')           AS new_p2,
    (SELECT count(*) FROM g WHERE period(purchased_at) = 'P1')                   AS go_p1,
    (SELECT count(*) FROM g WHERE period(purchased_at) = 'P2')                   AS go_p2
FROM o;

SELECT orders_p1, orders_p2, growth(orders_p1, orders_p2) orders_g,
       round(rev_p1, 2) rev_p1, round(rev_p2, 2) rev_p2, growth(rev_p1, rev_p2) rev_g,
       new_p1, new_p2, growth(new_p1, new_p2) new_g,
       go_p1, go_p2, growth(go_p1, go_p2) go_g
FROM base;
