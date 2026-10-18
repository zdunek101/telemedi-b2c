-- Audyt H4: czy wzrost nowych pacjentów jest kupiony reklamą (marketing_spend).
-- Wymaga: 00_raw_views.sql, 03_audit_base.sql. Niczego nie usuwa.
-- Przypisanie źródła jest otwartym pytaniem (Q3); tu trzy PROWIZORYCZNE warianty obok siebie:
--   last  = UTM sesji, w której zapłacono pierwsze zamówienie (orders.session_id)
--   first = UTM najwcześniejszej sesji pacjenta, szukanej po wszystkich visitor_id,
--           z którymi pacjent kiedykolwiek był zalogowany lub zapłacił, do momentu pierwszego zamówienia
--   lnd   = UTM ostatniej sesji z niepustym utm_source do momentu pierwszego zamówienia (te same visitor_id);
--           jeśli takiej nie ma: (direct)

-- H4.1 wartości UTM w sesjach
SELECT coalesce(utm_source, '(direct)') AS utm_source, coalesce(utm_medium, '(direct)') AS utm_medium,
       count(*) AS sesje, count(DISTINCT utm_campaign) AS kampanie
FROM s GROUP BY 1, 2 ORDER BY 3 DESC;

-- H4.2 wydatki według źródła i okresu
SELECT utm_source, utm_medium,
       round(sum(spend_pln) FILTER (period(date::TIMESTAMP) = 'P1'), 2) AS spend_p1,
       round(sum(spend_pln) FILTER (period(date::TIMESTAMP) = 'P2'), 2) AS spend_p2,
       sum(clicks) FILTER (period(date::TIMESTAMP) = 'P1') AS clicks_p1,
       sum(clicks) FILTER (period(date::TIMESTAMP) = 'P2') AS clicks_p2,
       growth(sum(spend_pln) FILTER (period(date::TIMESTAMP) = 'P1'), sum(spend_pln) FILTER (period(date::TIMESTAMP) = 'P2')) AS wzrost_spend_pct
FROM m GROUP BY 1, 2 ORDER BY 1, 2;

-- H4.3 wydatki według kampanii: od kiedy do kiedy
SELECT utm_source, utm_campaign, min(date) AS od, max(date) AS do,
       round(sum(spend_pln), 2) AS spend, sum(clicks) AS clicks
FROM m GROUP BY 1, 2 ORDER BY od, 1, 2;

-- kanał = source/medium; płatny = para występująca w marketing_spend
CREATE OR REPLACE TABLE paid_pairs AS SELECT DISTINCT utm_source, utm_medium FROM m;

CREATE OR REPLACE MACRO channel(src, med) AS
    CASE WHEN src IS NULL THEN '(direct)' ELSE src || ' / ' || med END;

-- powiązania pacjent <-> visitor_id
CREATE OR REPLACE TABLE user_visitor AS
    SELECT DISTINCT user_id, visitor_id FROM s WHERE user_id IS NOT NULL
    UNION
    SELECT DISTINCT o.user_id, s.visitor_id FROM o JOIN s USING (session_id);

CREATE OR REPLACE TABLE attribution AS
WITH last_touch AS (
    SELECT f.user_id, f.created_at, period(f.created_at) AS okres,
           channel(s.utm_source, s.utm_medium) AS ch_last,
           s.utm_source AS src_last, s.utm_medium AS med_last
    FROM first_order f LEFT JOIN s USING (session_id)
),
first_touch AS (
    -- jedna, najwcześniejsza sesja (arg_min pomija NULL, więc źródło i kanał mogłyby pochodzić z różnych sesji)
    SELECT l.user_id,
           channel(s.utm_source, s.utm_medium) AS ch_first,
           s.utm_source AS src_first,
           s.utm_medium AS med_first
    FROM last_touch l
    JOIN user_visitor uv USING (user_id)
    JOIN s ON s.visitor_id = uv.visitor_id AND s.started_at <= l.created_at
    QUALIFY row_number() OVER (PARTITION BY l.user_id ORDER BY s.started_at, s.session_id) = 1
),
last_non_direct AS (
    -- ostatnia sesja z UTM (nie bezpośrednia) przed pierwszym zamówieniem lub w jego trakcie
    SELECT l.user_id,
           channel(s.utm_source, s.utm_medium) AS ch_lnd,
           s.utm_source AS src_lnd,
           s.utm_medium AS med_lnd
    FROM last_touch l
    JOIN user_visitor uv USING (user_id)
    JOIN s ON s.visitor_id = uv.visitor_id AND s.started_at <= l.created_at AND s.utm_source IS NOT NULL
    QUALIFY row_number() OVER (PARTITION BY l.user_id ORDER BY s.started_at DESC, s.session_id DESC) = 1
)
SELECT l.*, f.ch_first, f.src_first, f.med_first,
       coalesce(n.ch_lnd, '(direct)') AS ch_lnd, n.src_lnd, n.med_lnd,
       EXISTS (SELECT 1 FROM paid_pairs p WHERE p.utm_source = l.src_last AND p.utm_medium = l.med_last) AS paid_last,
       EXISTS (SELECT 1 FROM paid_pairs p WHERE p.utm_source = f.src_first AND p.utm_medium = f.med_first) AS paid_first,
       EXISTS (SELECT 1 FROM paid_pairs p WHERE p.utm_source = n.src_lnd AND p.utm_medium = n.med_lnd) AS paid_lnd
FROM last_touch l LEFT JOIN first_touch f USING (user_id) LEFT JOIN last_non_direct n USING (user_id);

-- H4.4 kontrola przypisania: pierwsze zamówienia bez sesji płatności / bez pierwszej sesji
SELECT count(*) AS nowi_pacjenci,
       count(*) FILTER (src_last IS NULL AND ch_last = '(direct)') AS last_direct_lub_brak_sesji,
       count(*) FILTER (ch_first IS NULL) AS first_brak_sesji
FROM attribution;

-- H4.5 nowi pacjenci według kanału, oba warianty
SELECT 'last' AS wariant, ch_last AS kanal, paid_last AS platny,
       count(*) FILTER (okres = 'P1') AS nowi_p1, count(*) FILTER (okres = 'P2') AS nowi_p2,
       growth(count(*) FILTER (okres = 'P1'), count(*) FILTER (okres = 'P2')) AS wzrost_pct
FROM attribution GROUP BY 1, 2, 3
UNION ALL
SELECT 'first', ch_first, paid_first,
       count(*) FILTER (okres = 'P1'), count(*) FILTER (okres = 'P2'),
       growth(count(*) FILTER (okres = 'P1'), count(*) FILTER (okres = 'P2'))
FROM attribution GROUP BY 1, 2, 3
UNION ALL
SELECT 'lnd', ch_lnd, paid_lnd,
       count(*) FILTER (okres = 'P1'), count(*) FILTER (okres = 'P2'),
       growth(count(*) FILTER (okres = 'P1'), count(*) FILTER (okres = 'P2'))
FROM attribution GROUP BY 1, 2, 3
ORDER BY 1 DESC, 5 DESC;

-- H4.6 wpływ: wzrost nowych pacjentów ogółem vs bez kanałów płatnych (za klik) vs bez płatnych i afiliacji
SELECT wariant,
       count(*) FILTER (okres = 'P1') AS nowi_p1, count(*) FILTER (okres = 'P2') AS nowi_p2,
       growth(count(*) FILTER (okres = 'P1'), count(*) FILTER (okres = 'P2')) AS wzrost_ogolem,
       count(*) FILTER (okres = 'P1' AND NOT platny) AS bez_platnych_p1,
       count(*) FILTER (okres = 'P2' AND NOT platny) AS bez_platnych_p2,
       growth(count(*) FILTER (okres = 'P1' AND NOT platny), count(*) FILTER (okres = 'P2' AND NOT platny)) AS wzrost_bez_platnych,
       growth(count(*) FILTER (okres = 'P1' AND NOT platny AND med <> 'affiliate'),
              count(*) FILTER (okres = 'P2' AND NOT platny AND med <> 'affiliate')) AS wzrost_bez_platnych_i_afiliacji
FROM (
    SELECT 'last' wariant, okres, paid_last platny, coalesce(med_last, '') med FROM attribution
    UNION ALL SELECT 'first', okres, paid_first, coalesce(med_first, '') FROM attribution
    UNION ALL SELECT 'lnd', okres, paid_lnd, coalesce(med_lnd, '') FROM attribution
) GROUP BY 1 ORDER BY 1 DESC;

-- H4.7 koszt pozyskania: wydatki na klik + afiliacja (25 zł x pierwsze zamówienia z afiliacji wg last), na nowego płatnego pacjenta
SELECT a.okres,
       round(sp.spend, 2) AS spend_za_klik,
       count(*) FILTER (a.paid_last) AS nowi_platni_last,
       count(*) FILTER (a.paid_first) AS nowi_platni_first,
       count(*) FILTER (a.paid_lnd) AS nowi_platni_lnd,
       round(sp.spend / count(*) FILTER (a.paid_last), 2) AS cac_last,
       round(sp.spend / count(*) FILTER (a.paid_first), 2) AS cac_first,
       round(sp.spend / count(*) FILTER (a.paid_lnd), 2) AS cac_lnd,
       count(*) FILTER (a.med_last = 'affiliate') * 25 AS afiliacja_zl
FROM attribution a
JOIN (SELECT period(date::TIMESTAMP) okres, sum(spend_pln) spend FROM m GROUP BY 1) sp USING (okres)
GROUP BY a.okres, sp.spend ORDER BY 1;

-- ===================== H4.8: nowi z kodem kampanii, ale bez płatnej sesji płatności =====================
-- 963 pacjentów z P2: pierwsze zamówienie z L4SZYBKO20 / TIKTOK25, a sesja płatności nie z kanału płatnego
CREATE OR REPLACE TABLE code_nonpaid AS
SELECT a.*, f.promo_code, f.session_id AS order_session
FROM attribution a JOIN first_order f USING (user_id)
WHERE a.okres = 'P2' AND f.promo_code IN ('L4SZYBKO20', 'TIKTOK25') AND NOT a.paid_last;

-- H4.8a kanał sesji płatności (last) według kodu
SELECT promo_code, ch_last, count(*) AS pacjenci FROM code_nonpaid GROUP BY 1, 2 ORDER BY 1, 3 DESC;

-- H4.8b czy wcześniej była sesja z kanału płatnego (dowolna, nie tylko ostatnia), według kodu
SELECT c.promo_code,
       count(*) AS pacjenci,
       count(*) FILTER (wcz.n_sesji_przed > 0) AS mieli_wczesniejsze_sesje,
       count(*) FILTER (wcz.n_platnych > 0) AS mieli_wczesniej_platna,
       count(*) FILTER (wcz.n_kampania_kodu > 0) AS mieli_wczesniej_kampanie_kodu
FROM code_nonpaid c
LEFT JOIN (
    SELECT c2.user_id,
           count(*) AS n_sesji_przed,
           count(*) FILTER (EXISTS (SELECT 1 FROM paid_pairs p WHERE p.utm_source = s.utm_source AND p.utm_medium = s.utm_medium)) AS n_platnych,
           count(*) FILTER (s.utm_campaign IN ('meta_prosp_l4_szybko', 'tt_prosp_l4_15min')) AS n_kampania_kodu
    FROM code_nonpaid c2
    JOIN user_visitor uv USING (user_id)
    JOIN s ON s.visitor_id = uv.visitor_id AND s.started_at < c2.created_at AND s.session_id <> c2.order_session
    GROUP BY 1
) wcz USING (user_id)
GROUP BY 1 ORDER BY 1;

-- H4.8c sesja płatności tych pacjentów: urządzenie, przeglądarka, strona wejścia
SELECT s.device, s.browser, s.landing_page, count(*) AS pacjenci
FROM code_nonpaid c JOIN s ON s.session_id = c.order_session
GROUP BY 1, 2, 3 ORDER BY 4 DESC LIMIT 10;

-- H4.8d dla porównania: pacjenci z kodem i płatną sesją płatności, kampania sesji
SELECT f.promo_code, s.utm_campaign, count(*) AS pacjenci
FROM attribution a JOIN first_order f USING (user_id) JOIN s ON s.session_id = f.session_id
WHERE a.okres = 'P2' AND f.promo_code IN ('L4SZYBKO20', 'TIKTOK25') AND a.paid_last
GROUP BY 1, 2 ORDER BY 1, 3 DESC;
