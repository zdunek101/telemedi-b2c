-- Audyt H5 (sesje bez zdarzeń / boty), H7 (jedna osoba, kilka kont), H8 (anulowanie i ponowne zamówienie).
-- Wymaga: 00_raw_views.sql, 03_audit_base.sql. Niczego nie usuwa.

-- ===================== H5: sesje bez zdarzeń =====================

CREATE OR REPLACE TABLE s_ev AS
SELECT s.*, (e.session_id IS NOT NULL) AS ma_zdarzenia,
       coalesce(e.ma_platnosc, false) AS ma_platnosc
FROM s LEFT JOIN (
    SELECT session_id, bool_or(event_name = 'payment_succeeded') ma_platnosc FROM e GROUP BY 1
) e USING (session_id);

-- H5.1 udział sesji bez zdarzeń miesięcznie
SELECT date_trunc('month', started_at)::DATE AS miesiac, count(*) AS sesje,
       count(*) FILTER (NOT ma_zdarzenia) AS bez_zdarzen,
       round(100.0 * count(*) FILTER (NOT ma_zdarzenia) / count(*), 1) AS pct_bez_zdarzen
FROM s_ev GROUP BY 1 ORDER BY 1;

-- H5.2 sesje bez zdarzeń według urządzenia, przeglądarki i okresu
SELECT device, browser,
       count(*) FILTER (period(started_at) = 'P1') AS sesje_p1,
       round(100.0 * count(*) FILTER (period(started_at) = 'P1' AND NOT ma_zdarzenia) / nullif(count(*) FILTER (period(started_at) = 'P1'), 0), 1) AS pct_bez_p1,
       count(*) FILTER (period(started_at) = 'P2') AS sesje_p2,
       round(100.0 * count(*) FILTER (period(started_at) = 'P2' AND NOT ma_zdarzenia) / nullif(count(*) FILTER (period(started_at) = 'P2'), 0), 1) AS pct_bez_p2
FROM s_ev GROUP BY 1, 2 ORDER BY 5 DESC;

-- H5.3 sesje bez zdarzeń według landing_page (top 21)
SELECT landing_page, count(*) AS sesje,
       round(100.0 * count(*) FILTER (NOT ma_zdarzenia) / count(*), 1) AS pct_bez_zdarzen
FROM s_ev GROUP BY 1 ORDER BY 2 DESC;

-- H5.4 sygnały botów: visitor_id z bardzo dużą liczbą sesji, sesje tego samego visitor_id w odstępie < 10 s
SELECT 'visitor z >= 50 sesjami' AS sygnal, count(*) AS visitorzy, sum(n) AS sesje
FROM (SELECT visitor_id, count(*) n FROM s GROUP BY 1 HAVING count(*) >= 50)
UNION ALL
SELECT 'kolejna sesja tego samego visitor_id < 10 s', count(DISTINCT visitor_id), count(*)
FROM (SELECT visitor_id, started_at - lag(started_at) OVER (PARTITION BY visitor_id ORDER BY started_at) AS odstep FROM s)
WHERE odstep < INTERVAL 10 SECOND;

-- H5.5 rozkład liczby sesji na visitor_id
SELECT CASE WHEN n >= 20 THEN '20+' WHEN n >= 5 THEN '5-19' ELSE n::VARCHAR END AS sesji_na_visitor,
       count(*) AS visitorzy, sum(n) AS sesje
FROM (SELECT visitor_id, count(*) n FROM s GROUP BY 1) GROUP BY 1 ORDER BY min(n);

-- H5.6 wpływ na lejek: konwersja sesja -> payment_succeeded, wszystkie sesje vs tylko sesje ze zdarzeniem
SELECT period(started_at) AS okres, count(*) AS sesje,
       count(*) FILTER (ma_zdarzenia) AS sesje_ze_zdarzeniem,
       count(*) FILTER (ma_platnosc) AS sesje_z_platnoscia,
       round(100.0 * count(*) FILTER (ma_platnosc) / count(*), 2) AS konw_wszystkie_pct,
       round(100.0 * count(*) FILTER (ma_platnosc) / count(*) FILTER (ma_zdarzenia), 2) AS konw_ze_zdarzeniem_pct
FROM s_ev GROUP BY 1 ORDER BY 1;

-- ===================== H7: jedna osoba, kilka kont =====================

-- H7.1 visitor_id powiązane z kilkoma kontami (zalogowanie lub zapłata w sesji tego visitor_id)
CREATE OR REPLACE TABLE uv AS
    SELECT DISTINCT user_id, visitor_id FROM s WHERE user_id IS NOT NULL
    UNION
    SELECT DISTINCT o.user_id, s.visitor_id FROM o JOIN s USING (session_id);

SELECT kont_na_visitor, count(*) AS visitorzy
FROM (SELECT visitor_id, count(DISTINCT user_id) kont_na_visitor FROM uv GROUP BY 1)
GROUP BY 1 ORDER BY 1;

-- konta, które dzielą visitor_id z wcześniej zarejestrowanym kontem
CREATE OR REPLACE TABLE shared_accounts AS
SELECT DISTINCT b.user_id AS pozniejsze_konto, a.user_id AS wczesniejsze_konto
FROM uv a JOIN uv b ON a.visitor_id = b.visitor_id AND a.user_id <> b.user_id
JOIN u ua ON ua.user_id = a.user_id
JOIN u ub ON ub.user_id = b.user_id AND ub.registered_at > ua.registered_at;

-- H7.2 nowi pacjenci (pierwsze zamówienie), których konto dzieli visitor_id z wcześniejszym kontem
SELECT period(f.created_at) AS okres, count(*) AS nowi,
       count(*) FILTER (f.user_id IN (SELECT pozniejsze_konto FROM shared_accounts)) AS z_wczesniejszym_kontem,
       count(*) FILTER (f.user_id IN (SELECT pozniejsze_konto FROM shared_accounts)
                        AND f.user_id IN (SELECT pozniejsze_konto FROM shared_accounts sa
                                          JOIN first_order fw ON fw.user_id = sa.wczesniejsze_konto
                                          WHERE fw.created_at < f.created_at)) AS wczesniejsze_konto_juz_kupilo,
       count(*) FILTER (f.user_id IN (SELECT pozniejsze_konto FROM shared_accounts) AND f.promo_code = 'START10') AS z_start10
FROM first_order f GROUP BY 1 ORDER BY 1;

-- H7.3 profil par kont: ten sam rok urodzenia i płeć (jedna osoba) czy różne (rodzina na jednym urządzeniu)
SELECT (ua.birth_year = ub.birth_year AND ua.gender = ub.gender) AS ten_sam_rok_i_plec, count(*) AS pary
FROM shared_accounts sa JOIN u ua ON ua.user_id = sa.wczesniejsze_konto JOIN u ub ON ub.user_id = sa.pozniejsze_konto
GROUP BY 1;

-- ===================== H8: anulowanie i ponowne zamówienie =====================

-- H8.1 cancelled, po którym ten sam pacjent zamawia tę samą specjalizację w ciągu 48 h
CREATE OR REPLACE TABLE rebook AS
SELECT c.order_id AS cancelled_id, c.user_id, c.created_at,
       min(n.created_at) AS kolejne_at
FROM o c JOIN o n ON n.user_id = c.user_id AND n.specialization = c.specialization
     AND n.created_at > c.created_at AND n.created_at <= c.created_at + INTERVAL 48 HOUR
WHERE c.status = 'cancelled'
GROUP BY 1, 2, 3;

SELECT period(c.created_at) AS okres,
       count(*) AS cancelled,
       count(r.cancelled_id) AS z_ponownym_w_48h,
       round(100.0 * count(r.cancelled_id) / count(*), 1) AS pct
FROM o c LEFT JOIN rebook r ON r.cancelled_id = c.order_id
WHERE c.status = 'cancelled' GROUP BY 1 ORDER BY 1;

-- H8.2 pierwsze zamówienie pacjenta anulowane: ile, czy pacjent potem coś opłacił bez anulowania
SELECT period(f.created_at) AS okres, count(*) AS nowi,
       count(*) FILTER (f.status = 'cancelled') AS pierwsze_anulowane,
       count(*) FILTER (f.status = 'cancelled' AND NOT EXISTS (
           SELECT 1 FROM o x WHERE x.user_id = f.user_id AND x.status <> 'cancelled')) AS nigdy_nic_nieanulowanego
FROM first_order f GROUP BY 1 ORDER BY 1;
