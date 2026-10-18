-- Baza audytu: wspólne makra i tabele robocze. Wymaga sql/00_raw_views.sql.
-- Niczego nie usuwa z plików; tabele robocze: deduplikacja zamówień (A8) i bez kont testowych (A11).
-- Czas: wszystko w Europe/Warsaw (A4). Sesje i zdarzenia konwertowane z UTC strefą, nie stałym przesunięciem.

SET TimeZone = 'Europe/Warsaw';

CREATE OR REPLACE MACRO period(ts) AS
    CASE WHEN ts >= TIMESTAMP '2024-10-01' AND ts < TIMESTAMP '2025-10-01' THEN 'P1'
         WHEN ts >= TIMESTAMP '2025-10-01' AND ts < TIMESTAMP '2026-10-01' THEN 'P2' END;

-- UTC (TIMESTAMP bez strefy) -> czas polski (TIMESTAMP bez strefy)
CREATE OR REPLACE MACRO utc_to_pl(ts) AS timezone('Europe/Warsaw', timezone('UTC', ts));

-- wzrost P2/P1 w %
CREATE OR REPLACE MACRO growth(p1, p2) AS round(100.0 * (p2 / p1 - 1), 1);

CREATE OR REPLACE TABLE o_all AS SELECT DISTINCT * FROM raw_orders;        -- 65 278 zamówień (A8), z kontami testowymi

-- A11: konta testowe = każde konto, które choć raz użyło kodu TEST-QA; wykluczamy je w całości
CREATE OR REPLACE TABLE test_users AS SELECT DISTINCT user_id FROM o_all WHERE promo_code = 'TEST-QA';
-- przeglądarki kont testowych: zalogowanie albo zapłata w sesji tego visitor_id
CREATE OR REPLACE TABLE test_visitors AS
    SELECT DISTINCT visitor_id FROM raw_sessions WHERE user_id IN (SELECT user_id FROM test_users)
    UNION
    SELECT DISTINCT s.visitor_id FROM o_all JOIN raw_sessions s USING (session_id)
    WHERE o_all.user_id IN (SELECT user_id FROM test_users);

CREATE OR REPLACE TABLE o AS SELECT * FROM o_all WHERE user_id NOT IN (SELECT user_id FROM test_users);   -- 63 207 (A8 + A11)
CREATE OR REPLACE TABLE g AS SELECT * FROM raw_go_memberships WHERE user_id NOT IN (SELECT user_id FROM test_users);
CREATE OR REPLACE TABLE u AS SELECT * FROM raw_users WHERE user_id NOT IN (SELECT user_id FROM test_users);
CREATE OR REPLACE TABLE s AS
    SELECT * EXCLUDE (started_at_utc), utc_to_pl(started_at_utc) AS started_at
    FROM raw_sessions WHERE visitor_id NOT IN (SELECT visitor_id FROM test_visitors);
CREATE OR REPLACE TABLE e AS
    SELECT * EXCLUDE (event_at_utc), utc_to_pl(event_at_utc) AS event_at
    FROM raw_events WHERE session_id IN (SELECT session_id FROM s);

-- kontrola A11: liczba wierszy przed i po wykluczeniu
SELECT 'orders' AS tabela, (SELECT count(*) FROM o_all) AS przed, (SELECT count(*) FROM o) AS po
UNION ALL SELECT 'users', (SELECT count(*) FROM raw_users), (SELECT count(*) FROM u)
UNION ALL SELECT 'go_memberships', (SELECT count(*) FROM raw_go_memberships), (SELECT count(*) FROM g)
UNION ALL SELECT 'sessions', (SELECT count(*) FROM raw_sessions), (SELECT count(*) FROM s)
UNION ALL SELECT 'events', (SELECT count(*) FROM raw_events), (SELECT count(*) FROM e)
UNION ALL SELECT 'test_visitors', NULL, (SELECT count(*) FROM test_visitors);
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
