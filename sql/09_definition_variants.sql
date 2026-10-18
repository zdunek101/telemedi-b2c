-- Warianty definicji do decyzji: Q1 (kotwica kohorty), Q3 (przypisanie źródła), Q4 (definicja powrotu).
-- Wymaga: 00_raw_views.sql, 03_audit_base.sql, 06_audit_h4.sql (attribution). Baza: A8 + A11.
-- Okna obserwacji: liczymy tylko kohorty, które mają pełne okno do 2026-09-30 (koniec danych).

CREATE OR REPLACE MACRO data_end() AS TIMESTAMP '2026-10-01';

-- zamówienia nieanulowane i zakupy GO osobno (bez zamówienia) jako zdarzenia pacjenta
CREATE OR REPLACE TABLE ev AS
SELECT user_id, created_at AS t, 'order' AS typ, status, amount_paid - refund_amount AS netto FROM o
UNION ALL
SELECT user_id, purchased_at, 'go', NULL, amount_paid FROM g WHERE order_id IS NULL;

-- ===================== Q1: kotwica kohorty =====================

-- kotwice dla każdego pacjenta/konta
CREATE OR REPLACE TABLE anchors AS
WITH first_any AS (SELECT user_id, min(created_at) t FROM o GROUP BY 1),
     first_nc  AS (SELECT user_id, min(created_at) t FROM o WHERE status <> 'cancelled' GROUP BY 1),
     reg       AS (SELECT user_id, registered_at t FROM u),
     first_ses AS (
         SELECT uv.user_id, min(s.started_at) t
         FROM user_visitor uv JOIN s USING (visitor_id) GROUP BY 1
     )
SELECT 'a) pierwsze zamówienie, dowolny status (dashboard)' AS wariant, user_id, t FROM first_any
UNION ALL SELECT 'a2) pierwsze zamówienie nieanulowane', user_id, t FROM first_nc
UNION ALL SELECT 'b) rejestracja konta', user_id, t FROM reg
UNION ALL SELECT 'c) pierwsza sesja (po visitor_id konta)', user_id, t FROM first_ses;

-- Q1.1 wielkość kohort i wynik 90 dni od kotwicy (tylko kohorty z pełnymi 90 dniami)
-- kupujący_90 = >= 1 zamówienie nieanulowane w [kotwica, kotwica + 90 d]
-- powrót_90  = >= 2 zamówienia nieanulowane w tym oknie (dla a/a2: pierwsze + kolejne)
SELECT a.wariant,
       count(DISTINCT a.user_id) FILTER (period(a.t) = 'P1') AS kohorta_p1,
       count(DISTINCT a.user_id) FILTER (period(a.t) = 'P2') AS kohorta_p2,
       growth(count(DISTINCT a.user_id) FILTER (period(a.t) = 'P1'), count(DISTINCT a.user_id) FILTER (period(a.t) = 'P2')) AS wzrost_kohorty_pct,
       count(DISTINCT a.user_id) FILTER (a.t < data_end() - INTERVAL 90 DAY) AS z_pelnym_oknem_90,
       round(100.0 * count(DISTINCT a.user_id) FILTER (a.t < data_end() - INTERVAL 90 DAY AND x.n_nc >= 1)
             / count(DISTINCT a.user_id) FILTER (a.t < data_end() - INTERVAL 90 DAY), 1) AS pct_kupujacy_90,
       round(100.0 * count(DISTINCT a.user_id) FILTER (a.t < data_end() - INTERVAL 90 DAY AND x.n_nc >= 2)
             / count(DISTINCT a.user_id) FILTER (a.t < data_end() - INTERVAL 90 DAY), 1) AS pct_2plus_zamowien_90,
       round(avg(coalesce(x.netto, 0)) FILTER (a.t < data_end() - INTERVAL 90 DAY), 2) AS netto_na_osobe_90_zl
FROM anchors a
LEFT JOIN (
    SELECT a2.wariant, a2.user_id,
           count(*) FILTER (ev.typ = 'order' AND ev.status <> 'cancelled') AS n_nc,
           sum(ev.netto) AS netto
    FROM anchors a2 JOIN ev ON ev.user_id = a2.user_id AND ev.t >= a2.t AND ev.t < a2.t + INTERVAL 90 DAY
    GROUP BY 1, 2
) x USING (wariant, user_id)
GROUP BY 1 ORDER BY 1;

-- Q1.2 kotwica b i c: odstęp do pierwszego zamówienia (dni) wśród tych, którzy kupili
SELECT a.wariant, count(*) AS kupujacy,
       round(median(date_diff('hour', a.t, f.t) / 24.0), 2) AS mediana_dni,
       round(100.0 * count(*) FILTER (date_diff('hour', a.t, f.t) < 24) / count(*), 1) AS pct_tego_samego_dnia,
       round(100.0 * count(*) FILTER (date_diff('day', a.t, f.t) > 30) / count(*), 1) AS pct_po_30_dniach
FROM anchors a JOIN (SELECT user_id, t FROM anchors WHERE wariant LIKE 'a)%') f USING (user_id)
WHERE a.wariant LIKE 'b)%' OR a.wariant LIKE 'c)%'
GROUP BY 1 ORDER BY 1;

-- Q1.3 konta bez zakupu (tylko w wariancie b): ile i jak się zmienia
SELECT period(registered_at) AS okres, count(*) AS konta,
       count(*) FILTER (user_id NOT IN (SELECT user_id FROM o)) AS bez_zamowienia,
       round(100.0 * count(*) FILTER (user_id NOT IN (SELECT user_id FROM o)) / count(*), 1) AS pct_bez_zamowienia
FROM u GROUP BY 1 ORDER BY 1;

-- ===================== Q4: definicja powrotu =====================
-- kohorta: pierwsze zamówienie, dowolny status (Q1 a). Powrót = zdarzenie PO pierwszym zamówieniu w oknie.
--   a) kolejne zamówienie dowolnego statusu
--   b) kolejne zamówienie nieanulowane
--   c) kolejne zamówienie dowolnego statusu albo zakup samego GO

CREATE OR REPLACE TABLE ret AS
SELECT f.user_id, f.created_at AS t0, period(f.created_at) AS okres,
       min(n.created_at) FILTER (TRUE)                         AS next_any,
       min(n.created_at) FILTER (n.status <> 'cancelled')      AS next_nc,
       least(min(n.created_at), (SELECT min(gg.purchased_at) FROM g gg
                                 WHERE gg.user_id = f.user_id AND gg.order_id IS NULL AND gg.purchased_at > f.created_at)) AS next_any_or_go,
       count(n.order_id) FILTER (n.created_at < f.created_at + INTERVAL 90 DAY) AS kolejne_90,
       coalesce(sum(n.amount_paid - n.refund_amount) FILTER (n.created_at < f.created_at + INTERVAL 90 DAY), 0) AS netto_kolejne_90
FROM first_order f
LEFT JOIN o n ON n.user_id = f.user_id AND (n.created_at > f.created_at OR (n.created_at = f.created_at AND n.order_id > f.order_id))
GROUP BY 1, 2, 3;

-- Q4.1 odsetek powracających w 30 / 90 / 180 dniach, P1 vs P2, tylko kohorty z pełnym oknem
SELECT okno_dni, okres,
       count(*) AS kohorta_z_pelnym_oknem,
       round(100.0 * count(*) FILTER (next_any       < t0 + to_days(okno_dni)) / count(*), 1) AS a_dowolne_pct,
       round(100.0 * count(*) FILTER (next_nc        < t0 + to_days(okno_dni)) / count(*), 1) AS b_nieanulowane_pct,
       round(100.0 * count(*) FILTER (next_any_or_go < t0 + to_days(okno_dni)) / count(*), 1) AS c_zamowienie_lub_go_pct
FROM ret, (VALUES (30), (90), (180)) w(okno_dni)
WHERE t0 + to_days(okno_dni) <= data_end()
GROUP BY 1, 2 ORDER BY 1, 2;

-- Q4.2 miary wartości zamiast odsetka: kolejne zamówienia i przychód netto z kolejnych zamówień w 90 dniach
SELECT okres, count(*) AS kohorta_z_pelnym_oknem_90,
       round(avg(kolejne_90), 3) AS kolejne_zamowienia_na_pacjenta_90,
       round(avg(netto_kolejne_90), 2) AS netto_z_kolejnych_na_pacjenta_90_zl
FROM ret WHERE t0 + INTERVAL 90 DAY <= data_end()
GROUP BY 1 ORDER BY 1;

-- Q4.3 różnica między wariantami: kogo b) i c) liczą inaczej niż a)
SELECT okres,
       count(*) FILTER (next_any < t0 + INTERVAL 90 DAY AND (next_nc IS NULL OR next_nc >= t0 + INTERVAL 90 DAY)) AS a_tak_b_nie_powrot_tylko_anulowany,
       count(*) FILTER (next_any_or_go < t0 + INTERVAL 90 DAY AND (next_any IS NULL OR next_any >= t0 + INTERVAL 90 DAY)) AS c_tak_a_nie_powrot_tylko_go
FROM ret WHERE t0 + INTERVAL 90 DAY <= data_end()
GROUP BY 1 ORDER BY 1;

-- ===================== Q3: przypisanie źródła =====================

-- Q3.1 udział kanałów płatnych wśród nowych pacjentów i koszt na nowego płatnego, trzy warianty
SELECT wariant,
       round(100.0 * count(*) FILTER (okres = 'P1' AND platny) / count(*) FILTER (okres = 'P1'), 1) AS pct_platnych_p1,
       round(100.0 * count(*) FILTER (okres = 'P2' AND platny) / count(*) FILTER (okres = 'P2'), 1) AS pct_platnych_p2,
       count(*) FILTER (okres = 'P1' AND kanal = '(direct)') AS direct_p1,
       count(*) FILTER (okres = 'P2' AND kanal = '(direct)') AS direct_p2,
       growth(count(*) FILTER (okres = 'P1' AND NOT platny), count(*) FILTER (okres = 'P2' AND NOT platny)) AS wzrost_bez_platnych_pct
FROM (
    SELECT 'b) last: sesja płatności' wariant, okres, paid_last platny, ch_last kanal FROM attribution
    UNION ALL SELECT 'a) first: pierwsza sesja', okres, paid_first, ch_first FROM attribution
    UNION ALL SELECT 'c) lnd: ostatnia niebezpośrednia', okres, paid_lnd, ch_lnd FROM attribution
) GROUP BY 1 ORDER BY 1;

-- Q3.2 jakość kanałów zależnie od wariantu: powrót w 90 dniach (Q4 b) i zwroty refunded w pierwszym zamówieniu
SELECT wariant, kanal,
       count(*) FILTER (r.t0 + INTERVAL 90 DAY <= data_end()) AS nowi_z_oknem_90,
       round(100.0 * count(*) FILTER (r.t0 + INTERVAL 90 DAY <= data_end() AND r.next_nc < r.t0 + INTERVAL 90 DAY)
             / nullif(count(*) FILTER (r.t0 + INTERVAL 90 DAY <= data_end()), 0), 1) AS powrot_90_pct,
       round(100.0 * count(*) FILTER (f.status = 'refunded') / count(*), 1) AS pierwsze_refunded_pct
FROM (
    SELECT 'b) last' wariant, user_id, ch_last kanal FROM attribution
    UNION ALL SELECT 'a) first', user_id, ch_first FROM attribution
    UNION ALL SELECT 'c) lnd', user_id, ch_lnd FROM attribution
) x JOIN ret r USING (user_id) JOIN first_order f USING (user_id)
WHERE kanal IN ('google / cpc', 'meta / paid_social', 'tiktok / paid_social', 'google / organic', '(direct)')
GROUP BY 1, 2 ORDER BY 2, 1;
