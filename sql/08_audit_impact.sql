-- Audyt: wpływ każdej hipotezy na KPI w pp, liczony OSOBNO (bez kumulacji) względem bazy:
-- zamówienia i przychód po deduplikacji (A8), nowi pacjenci i GO jak w dashboardzie.
-- Wymaga: 00_raw_views.sql, 03_audit_base.sql, 06_audit_h4.sql (tabela attribution). Niczego nie usuwa.

-- konta testowe (H1): wszystkie konta, które choć raz użyły kodu TEST-QA
CREATE OR REPLACE TABLE test_users AS SELECT DISTINCT user_id FROM o WHERE promo_code = 'TEST-QA';

-- kontrola H1/H5: czy visitor_id z >= 50 sesjami to konta testowe
SELECT count(*) AS visitorzy_50plus,
       count(*) FILTER (visitor_id IN (SELECT uv.visitor_id FROM user_visitor uv JOIN test_users USING (user_id))) AS nalezace_do_kont_testowych
FROM (SELECT visitor_id FROM s GROUP BY 1 HAVING count(*) >= 50);

-- kontrola H1: zamówienia kont testowych bez kodu TEST-QA (rabat, specjalizacja, czas wizyty)
SELECT discount_type, specialization, count(*) AS zamowienia, round(avg(duration_min), 1) AS sr_czas_min, round(avg(amount_paid), 2) AS sr_kwota
FROM o WHERE user_id IN (SELECT user_id FROM test_users) AND coalesce(promo_code, '') <> 'TEST-QA'
GROUP BY 1, 2 ORDER BY 3 DESC;

-- zamówienia oznaczone przez hipotezy (jedno zamówienie może mieć kilka oznaczeń)
CREATE OR REPLACE TABLE flag_orders AS
SELECT 'H1 konta testowe (22 konta TEST-QA)' AS h, order_id FROM o WHERE user_id IN (SELECT user_id FROM test_users)
UNION ALL SELECT 'H2 kody promo nowe w P2 (L4SZYBKO20, TIKTOK25)', order_id FROM o WHERE promo_code IN ('L4SZYBKO20', 'TIKTOK25')
UNION ALL SELECT 'H8 pierwsze zamówienie anulowane, nic więcej', f.order_id FROM first_order f
          WHERE f.status = 'cancelled' AND NOT EXISTS (SELECT 1 FROM o x WHERE x.user_id = f.user_id AND x.status <> 'cancelled');

-- nowi pacjenci oznaczeni przez hipotezy
CREATE OR REPLACE TABLE flag_new AS
SELECT h, f.user_id FROM flag_orders fo JOIN first_order f USING (order_id)
UNION ALL SELECT 'H4 nowi z kanałów płatnych za klik, przypisanie last', user_id FROM attribution WHERE paid_last
UNION ALL SELECT 'H4 nowi z kanałów płatnych za klik, przypisanie first', user_id FROM attribution WHERE paid_first;

-- wpływ na zamówienia i przychód
CREATE OR REPLACE TABLE impact_orders AS
SELECT h,
       count(*) FILTER (period(o.created_at) = 'P1') AS zam_p1,
       count(*) FILTER (period(o.created_at) = 'P2') AS zam_p2,
       round(sum(o.amount_paid) FILTER (period(o.created_at) = 'P1'), 2) AS przych_p1,
       round(sum(o.amount_paid) FILTER (period(o.created_at) = 'P2'), 2) AS przych_p2
FROM flag_orders JOIN o USING (order_id) GROUP BY 1;

-- wpływ na nowych pacjentów
CREATE OR REPLACE TABLE impact_new AS
SELECT h,
       count(*) FILTER (period(f.created_at) = 'P1') AS nowi_p1,
       count(*) FILTER (period(f.created_at) = 'P2') AS nowi_p2
FROM (SELECT DISTINCT h, user_id FROM flag_new) JOIN first_order f USING (user_id) GROUP BY 1;

-- wpływ na GO
CREATE OR REPLACE TABLE impact_go AS
SELECT 'H1 konta testowe (22 konta TEST-QA)' AS h,
       count(*) FILTER (period(purchased_at) = 'P1') AS go_p1,
       count(*) FILTER (period(purchased_at) = 'P2') AS go_p2
FROM g WHERE user_id IN (SELECT user_id FROM test_users);

-- tabela wpływu: skala (P1, P2) i zmiana wzrostu KPI w pp po wyłączeniu oznaczonych
SELECT coalesce(io.h, inw.h) AS hipoteza,
       io.zam_p1, io.zam_p2,
       round(growth(b.orders_p1 - coalesce(io.zam_p1, 0), b.orders_p2 - coalesce(io.zam_p2, 0)) - growth(b.orders_p1, b.orders_p2), 1) AS pp_zamowienia,
       io.przych_p1, io.przych_p2,
       round(growth(b.rev_p1 - coalesce(io.przych_p1, 0), b.rev_p2 - coalesce(io.przych_p2, 0)) - growth(b.rev_p1, b.rev_p2), 1) AS pp_przychod,
       inw.nowi_p1, inw.nowi_p2,
       round(growth(b.new_p1 - coalesce(inw.nowi_p1, 0), b.new_p2 - coalesce(inw.nowi_p2, 0)) - growth(b.new_p1, b.new_p2), 1) AS pp_nowi,
       ig.go_p1, ig.go_p2,
       round(growth(b.go_p1 - coalesce(ig.go_p1, 0), b.go_p2 - coalesce(ig.go_p2, 0)) - growth(b.go_p1, b.go_p2), 1) AS pp_go
FROM impact_orders io
FULL JOIN impact_new inw USING (h)
LEFT JOIN impact_go ig ON ig.h = coalesce(io.h, inw.h)
CROSS JOIN base b
ORDER BY 1;

-- H3: wpływ zwrotów na wzrost przychodu, osobno cancelled i refunded (baza: przychód brutto po deduplikacji)
SELECT status,
       round(sum(refund_amount) FILTER (period(created_at) = 'P1'), 2) AS zwroty_p1,
       round(sum(refund_amount) FILTER (period(created_at) = 'P2'), 2) AS zwroty_p2,
       round(growth(any_value(b.rev_p1) - sum(refund_amount) FILTER (period(created_at) = 'P1'),
                    any_value(b.rev_p2) - sum(refund_amount) FILTER (period(created_at) = 'P2'))
             - growth(any_value(b.rev_p1), any_value(b.rev_p2)), 1) AS pp_przychod
FROM o CROSS JOIN base b WHERE status IN ('cancelled', 'refunded') GROUP BY 1 ORDER BY 1;

-- H3: ile z wzrostu zwrotów refunded przypada na L4 u internisty i na kody L4SZYBKO20 / TIKTOK25 (kwota w P2 ponad poziom P1)
SELECT grupa,
       count(*) FILTER (period(created_at) = 'P1' AND status = 'refunded') AS refunded_p1,
       count(*) FILTER (period(created_at) = 'P2' AND status = 'refunded') AS refunded_p2,
       round(sum(refund_amount) FILTER (period(created_at) = 'P2' AND status = 'refunded'), 2) AS zwroty_refunded_p2
FROM (SELECT *, CASE WHEN promo_code IN ('L4SZYBKO20', 'TIKTOK25') THEN 'kody L4SZYBKO20 / TIKTOK25'
                     WHEN specialization = 'internista' AND visit_purpose = 'l4' THEN 'internista L4, bez tych kodów'
                     ELSE 'pozostałe' END AS grupa FROM o)
GROUP BY 1 ORDER BY 1;

-- pokrycie hipotez: zamówienia oznaczone przez więcej niż jedną hipotezę
SELECT n_hipotez, count(*) AS zamowienia
FROM (SELECT order_id, count(DISTINCT h) n_hipotez FROM flag_orders GROUP BY 1)
GROUP BY 1 ORDER BY 1;

-- pokrycie: nowi pacjenci z H4 (last) a pierwsze zamówienie z nowym kodem promo (H2)
SELECT a.paid_last, (f.promo_code IN ('L4SZYBKO20', 'TIKTOK25')) AS nowy_kod, count(*) AS nowi_p2
FROM attribution a JOIN first_order f USING (user_id)
WHERE a.okres = 'P2' GROUP BY 1, 2 ORDER BY 1, 2;

-- korekta H1/H3: zamówienia kont testowych bez TEST-QA są wszystkie `refunded` (pełny zwrot)
-- ile zwrotów `refunded` z H3 przypada na konta testowe
SELECT period(created_at) AS okres, visit_purpose, consultation_mode, count(*) AS refunded, round(sum(refund_amount), 2) AS zwroty_zl
FROM o WHERE status = 'refunded' AND user_id IN (SELECT user_id FROM test_users)
GROUP BY 1, 2, 3 ORDER BY 1, 2, 3;

-- H3 bez kont testowych: refunded i udział zwrotów w przychodzie
SELECT period(created_at) AS okres, count(*) AS zamowienia,
       count(*) FILTER (status = 'refunded') AS refunded,
       round(100.0 * count(*) FILTER (status = 'refunded') / count(*), 2) AS pct_refunded,
       round(100 * sum(refund_amount) / sum(amount_paid), 2) AS pct_zwrotow_w_przychodzie,
       count(*) FILTER (status = 'refunded' AND specialization = 'internista' AND visit_purpose = 'l4') AS refunded_internista_l4,
       count(*) FILTER (specialization = 'internista' AND visit_purpose = 'l4') AS internista_l4,
       round(100.0 * refunded_internista_l4 / internista_l4, 1) AS pct_refunded_internista_l4
FROM o WHERE user_id NOT IN (SELECT user_id FROM test_users) GROUP BY 1 ORDER BY 1;
