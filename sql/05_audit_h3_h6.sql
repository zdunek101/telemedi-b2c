-- Audyt H3 (wzrost zwrotów 6,3% -> 8,5% przychodu) i H6 (rabat GO bez aktywnego członkostwa).
-- Wymaga: 00_raw_views.sql, 03_audit_base.sql. Niczego nie usuwa.

-- ===================== H3: zwroty =====================

-- H3.1 zwroty według statusu i okresu: liczba zamówień, kwota zwrotu, udział w przychodzie brutto
SELECT period(created_at) AS okres, status,
       count(*) AS zamowienia,
       round(sum(refund_amount), 2) AS zwroty_zl,
       round(100 * sum(refund_amount) / sum(sum(amount_paid)) OVER (PARTITION BY period(created_at)), 2) AS pct_przychodu,
       round(100 * count(*) / sum(count(*)) OVER (PARTITION BY period(created_at)), 2) AS pct_zamowien
FROM o GROUP BY 1, 2 ORDER BY 1, 2;

-- H3.2 zwroty miesięcznie: udział cancelled i refunded w zamówieniach
SELECT date_trunc('month', created_at)::DATE AS miesiac, count(*) AS zamowienia,
       count(*) FILTER (status = 'cancelled') AS cancelled,
       count(*) FILTER (status = 'refunded')  AS refunded,
       round(100.0 * count(*) FILTER (status = 'cancelled') / count(*), 2) AS pct_cancelled,
       round(100.0 * count(*) FILTER (status = 'refunded')  / count(*), 2) AS pct_refunded,
       round(100 * sum(refund_amount) / sum(amount_paid), 2) AS pct_zwrotu_w_przychodzie
FROM o GROUP BY 1 ORDER BY 1;

-- H3.3 refunded według specjalizacji, celu wizyty i trybu: P1 vs P2 (udział w zamówieniach danej grupy)
SELECT specialization, visit_purpose,
       count(*) FILTER (period(created_at) = 'P1') AS zam_p1,
       count(*) FILTER (period(created_at) = 'P1' AND status = 'refunded') AS ref_p1,
       count(*) FILTER (period(created_at) = 'P2') AS zam_p2,
       count(*) FILTER (period(created_at) = 'P2' AND status = 'refunded') AS ref_p2,
       round(100.0 * ref_p1 / nullif(zam_p1, 0), 1) AS pct_p1,
       round(100.0 * ref_p2 / nullif(zam_p2, 0), 1) AS pct_p2
FROM o GROUP BY 1, 2 HAVING zam_p2 >= 200 ORDER BY ref_p2 - ref_p1 DESC;

-- H3.4 refunded według trybu konsultacji i rodzaju rabatu
SELECT consultation_mode, discount_type, coalesce(promo_code, '') AS kod,
       count(*) FILTER (period(created_at) = 'P1') AS zam_p1,
       count(*) FILTER (period(created_at) = 'P1' AND status = 'refunded') AS ref_p1,
       count(*) FILTER (period(created_at) = 'P2') AS zam_p2,
       count(*) FILTER (period(created_at) = 'P2' AND status = 'refunded') AS ref_p2,
       round(100.0 * ref_p1 / nullif(zam_p1, 0), 1) AS pct_p1,
       round(100.0 * ref_p2 / nullif(zam_p2, 0), 1) AS pct_p2
FROM o GROUP BY 1, 2, 3 HAVING zam_p2 >= 200 ORDER BY ref_p2 - ref_p1 DESC;

-- H3.5 opóźnienie lekarza (started_at - scheduled_at, minuty) a status, wizyty odbyte
SELECT period(created_at) AS okres, status,
       count(*) AS wizyty,
       round(median(date_diff('second', scheduled_at, started_at) / 60.0), 1) AS mediana_opoznienia_min,
       round(quantile_cont(date_diff('second', scheduled_at, started_at) / 60.0, 0.9), 1) AS p90_opoznienia_min,
       round(median(duration_min), 1) AS mediana_czasu_min
FROM o WHERE started_at IS NOT NULL GROUP BY 1, 2 ORDER BY 1, 2;

-- H3.6 czas od zakupu do terminu (godziny) a anulowanie
SELECT period(created_at) AS okres,
       CASE WHEN date_diff('minute', created_at, scheduled_at) < 60 THEN '0 <1h'
            WHEN date_diff('minute', created_at, scheduled_at) < 24 * 60 THEN '1 1-24h'
            ELSE '2 >24h' END AS do_terminu,
       count(*) AS zamowienia,
       count(*) FILTER (status = 'cancelled') AS cancelled,
       round(100.0 * count(*) FILTER (status = 'cancelled') / count(*), 2) AS pct_cancelled
FROM o GROUP BY 1, 2 ORDER BY 1, 2;

-- ===================== H6: rabat GO bez aktywnego członkostwa =====================

-- H6.1 zamówienia z discount_type = go: czy pacjent miał ważne GO w dniu zamówienia
-- ważne = purchased_at <= created_at i created_at::DATE <= valid_until
-- (GO kupione przy tym samym zamówieniu ma purchased_at równe created_at)
CREATE OR REPLACE TABLE go_orders AS
SELECT o.order_id, o.user_id, o.created_at, o.amount_paid, o.list_price, o.status,
       EXISTS (SELECT 1 FROM g WHERE g.user_id = o.user_id
               AND g.purchased_at <= o.created_at AND o.created_at::DATE <= g.valid_until) AS ma_wazne_go,
       EXISTS (SELECT 1 FROM g WHERE g.user_id = o.user_id) AS mial_kiedykolwiek_go
FROM o WHERE o.discount_type = 'go';

SELECT period(created_at) AS okres, count(*) AS zamowienia_go,
       count(*) FILTER (ma_wazne_go) AS z_waznym_go,
       count(*) FILTER (NOT ma_wazne_go AND mial_kiedykolwiek_go) AS go_poza_waznoscia,
       count(*) FILTER (NOT mial_kiedykolwiek_go) AS bez_zadnego_go,
       round(sum(list_price - amount_paid) FILTER (NOT ma_wazne_go), 2) AS rabat_bez_waznego_go_zl
FROM go_orders GROUP BY 1 ORDER BY 1;

-- H6.2 rabat GO bez ważnego członkostwa miesięcznie (od kiedy)
SELECT date_trunc('month', created_at)::DATE AS miesiac, count(*) AS zamowienia_go,
       count(*) FILTER (NOT ma_wazne_go) AS bez_waznego_go
FROM go_orders GROUP BY 1 ORDER BY 1;

-- H6.3 czy brak członkostwa dotyczy wizyt, które dostały rabat po wygaśnięciu (dni po valid_until)
SELECT CASE WHEN dni IS NULL THEN 'brak GO' WHEN dni <= 7 THEN '1-7 dni' WHEN dni <= 30 THEN '8-30 dni' ELSE '>30 dni' END AS po_wygasnieciu,
       count(*) AS zamowienia
FROM (
    SELECT go.order_id,
           min(date_diff('day', g.valid_until, go.created_at::DATE)) FILTER (g.valid_until < go.created_at::DATE) AS dni
    FROM go_orders go LEFT JOIN g ON g.user_id = go.user_id
    WHERE NOT go.ma_wazne_go GROUP BY 1
) GROUP BY 1 ORDER BY 1;

-- H6.4 GO z dwoma członkostwami (85 pacjentów): czy okresy ważności się nakładają
SELECT count(*) AS pacjenci_z_2_go,
       count(*) FILTER (drugie_kupno <= pierwsze_do) AS nakladajace_sie,
       count(*) FILTER (drugie_kupno > pierwsze_do) AS po_wygasnieciu
FROM (
    SELECT user_id,
           min(valid_until) AS pierwsze_do,
           max(purchased_at)::DATE AS drugie_kupno
    FROM g GROUP BY 1 HAVING count(*) = 2
);
