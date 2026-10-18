-- Rozbicie dwóch zdarzeń w kroku termin → konto (F3):
--   Z1: 2026-03-17, przeglądarka Safari
--   Z2: 2025-07-11, przeglądarki w aplikacji (Instagram, Facebook, TikTok)
-- Wymaga: 00_raw_views.sql, 03_audit_base.sql, 06_audit_h4.sql, 11_daily_series.sql (session_funnel).
-- Okna jak w wykrywaniu: przed = 28 dni przed dniem zdarzenia, po = 28 dni od dnia zdarzenia (dzień polski).
-- Krok konto (decisions.md, Q2) = account_completed albo user_id w sesji.
-- Status logowania sesji (do rozbicia):
--   'zalogowany na wejściu'  = user_id w sesji i brak account_completed (README: kto wszedł zalogowany, nie ma tego zdarzenia)
--   'niezalogowany'          = pozostałe; dla nich konto = account_completed (logowanie albo rejestracja w trakcie)

CREATE OR REPLACE TABLE dd_events AS
SELECT * FROM (VALUES
    ('Z1 2026-03-17 Safari', DATE '2026-03-17'),
    ('Z2 2025-07-11 w aplikacji', DATE '2025-07-11')) t(zdarzenie, dzien);

-- sesje, które doszły do wyboru terminu (mianownik F3), z cechami i wynikiem
CREATE OR REPLACE TABLE dd_sessions AS
WITH acc AS (SELECT session_id, min(event_at) AS acc_at FROM e WHERE event_name = 'account_completed' GROUP BY 1),
     ord AS (SELECT session_id, count(*) AS zamowienia, sum(amount_paid - refund_amount) AS netto FROM o GROUP BY 1)
SELECT d.zdarzenie, d.dzien,
       CASE WHEN f.day < d.dzien THEN 'przed' ELSE 'po' END AS okno,
       f.session_id, f.day, s.device, s.os, s.browser,
       CASE WHEN s.user_id IS NOT NULL AND acc.session_id IS NULL THEN 'zalogowany na wejściu' ELSE 'niezalogowany' END AS logowanie,
       -- dla niezalogowanych, którzy przeszli krok: rejestracja (konto założone w tej sesji) czy logowanie
       CASE WHEN acc.session_id IS NULL THEN NULL
            WHEN uu.registered_at >= s.started_at THEN 'rejestracja'
            WHEN uu.registered_at < s.started_at THEN 'logowanie'
            ELSE 'konto nieznane' END AS sposob_konta,
       f.k3 AS konto, f.k4 AS start_platnosci, f.k5 AS platnosc_zdarzenie,
       coalesce(ord.zamowienia, 0) > 0 AS zamowienie, coalesce(ord.netto, 0) AS netto
FROM dd_events d
JOIN session_funnel f ON f.day >= d.dzien - INTERVAL 28 DAY AND f.day < d.dzien + INTERVAL 28 DAY
JOIN s USING (session_id)
LEFT JOIN acc USING (session_id)
LEFT JOIN u uu ON uu.user_id = s.user_id
LEFT JOIN ord USING (session_id)
WHERE f.k2
  AND ((d.zdarzenie LIKE 'Z1%' AND s.browser = 'Safari')
    OR (d.zdarzenie LIKE 'Z2%' AND s.browser IN ('Instagram', 'Facebook', 'TikTok')));

-- D0 kontrola: odtworzenie wykrycia (F3 przed i po w segmencie)
SELECT zdarzenie, okno, count(*) AS sesje_z_terminem, count(*) FILTER (konto) AS konto,
       round(100.0 * count(*) FILTER (konto) / count(*), 1) AS f3_pct
FROM dd_sessions GROUP BY 1, 2 ORDER BY 1, 2 DESC;

-- D1 urządzenie i system
SELECT zdarzenie, device, os,
       count(*) FILTER (okno = 'przed') AS termin_przed, count(*) FILTER (okno = 'przed' AND konto) AS konto_przed,
       round(100.0 * count(*) FILTER (okno = 'przed' AND konto) / nullif(count(*) FILTER (okno = 'przed'), 0), 1) AS f3_przed,
       count(*) FILTER (okno = 'po') AS termin_po, count(*) FILTER (okno = 'po' AND konto) AS konto_po,
       round(100.0 * count(*) FILTER (okno = 'po' AND konto) / nullif(count(*) FILTER (okno = 'po'), 0), 1) AS f3_po
FROM dd_sessions GROUP BY 1, 2, 3 ORDER BY 1, termin_po DESC;

-- D1b przeglądarka w Z2 (Instagram / Facebook osobno)
SELECT zdarzenie, browser,
       count(*) FILTER (okno = 'przed') AS termin_przed,
       round(100.0 * count(*) FILTER (okno = 'przed' AND konto) / nullif(count(*) FILTER (okno = 'przed'), 0), 1) AS f3_przed,
       count(*) FILTER (okno = 'po') AS termin_po,
       round(100.0 * count(*) FILTER (okno = 'po' AND konto) / nullif(count(*) FILTER (okno = 'po'), 0), 1) AS f3_po
FROM dd_sessions WHERE zdarzenie LIKE 'Z2%' GROUP BY 1, 2 ORDER BY 1, 2;

-- D2 status logowania; wśród niezalogowanych: rejestracja vs logowanie przy przejściu kroku
SELECT zdarzenie, logowanie,
       count(*) FILTER (okno = 'przed') AS termin_przed, count(*) FILTER (okno = 'przed' AND konto) AS konto_przed,
       round(100.0 * count(*) FILTER (okno = 'przed' AND konto) / nullif(count(*) FILTER (okno = 'przed'), 0), 1) AS f3_przed,
       count(*) FILTER (okno = 'po') AS termin_po, count(*) FILTER (okno = 'po' AND konto) AS konto_po,
       round(100.0 * count(*) FILTER (okno = 'po' AND konto) / nullif(count(*) FILTER (okno = 'po'), 0), 1) AS f3_po
FROM dd_sessions GROUP BY 1, 2 ORDER BY 1, 2;

SELECT zdarzenie, sposob_konta,
       count(*) FILTER (okno = 'przed') AS przed, count(*) FILTER (okno = 'po') AS po,
       round(100.0 * count(*) FILTER (okno = 'przed') / sum(count(*) FILTER (okno = 'przed')) OVER (PARTITION BY zdarzenie), 1) AS udzial_przed,
       round(100.0 * count(*) FILTER (okno = 'po') / sum(count(*) FILTER (okno = 'po')) OVER (PARTITION BY zdarzenie), 1) AS udzial_po
FROM dd_sessions WHERE logowanie = 'niezalogowany' AND konto GROUP BY 1, 2 ORDER BY 1, 2;

-- D3 zdarzenia vs zamówienia: czy spadek widać w transakcjach (orders), czy tylko w analityce (events)
SELECT zdarzenie, okno, count(*) AS sesje_z_terminem,
       count(*) FILTER (konto) AS konto_zdarzenie,
       count(*) FILTER (platnosc_zdarzenie) AS platnosc_zdarzenie,
       count(*) FILTER (zamowienie) AS sesje_z_zamowieniem,
       round(100.0 * count(*) FILTER (platnosc_zdarzenie) / count(*), 2) AS platnosc_zdarzenie_na_termin_pct,
       round(100.0 * count(*) FILTER (zamowienie) / count(*), 2) AS zamowienie_na_termin_pct,
       count(*) FILTER (zamowienie AND NOT konto) AS zamowienie_bez_kroku_konto,
       count(*) FILTER (zamowienie AND NOT platnosc_zdarzenie) AS zamowienie_bez_zdarzenia_platnosci
FROM dd_sessions GROUP BY 1, 2 ORDER BY 1, 2 DESC;

-- D3b niezalogowani: czy zamówienia bez account_completed rosną (zdarzenie gubione przy realnym przejściu)
SELECT zdarzenie, okno,
       count(*) FILTER (logowanie = 'niezalogowany') AS niezalogowani_z_terminem,
       count(*) FILTER (logowanie = 'niezalogowany' AND zamowienie) AS z_zamowieniem,
       count(*) FILTER (logowanie = 'niezalogowany' AND zamowienie AND NOT konto) AS zamowienie_bez_account_completed
FROM dd_sessions GROUP BY 1, 2 ORDER BY 1, 2 DESC;

-- D4 miesięcznie w segmencie: sesje z terminem, F3, zamówienia na sesję z terminem (czy zmiana trwa)
CREATE OR REPLACE TABLE dd_month AS
WITH ord AS (SELECT session_id, sum(amount_paid - refund_amount) AS netto FROM o GROUP BY 1)
SELECT CASE WHEN s.browser = 'Safari' THEN 'Safari' ELSE 'w aplikacji' END AS segment,
       date_trunc('month', f.day)::DATE AS miesiac,
       count(*) FILTER (f.k2) AS sesje_z_terminem,
       count(*) FILTER (f.k3) AS konto,
       count(*) FILTER (f.k2 AND ord.session_id IS NOT NULL) AS zamowienia_z_terminem,
       sum(ord.netto) FILTER (f.k2) AS netto_z_terminem
FROM session_funnel f JOIN s USING (session_id) LEFT JOIN ord USING (session_id)
WHERE s.browser IN ('Safari', 'Instagram', 'Facebook', 'TikTok')
GROUP BY 1, 2;

SELECT segment, miesiac, sesje_z_terminem, konto,
       round(100.0 * konto / sesje_z_terminem, 1) AS f3_pct,
       zamowienia_z_terminem,
       round(100.0 * zamowienia_z_terminem / sesje_z_terminem, 1) AS zamowienie_na_termin_pct
FROM dd_month ORDER BY 1, 2;

-- D5 ile płatności tracimy miesięcznie:
--   utracone zamówienia / 28 dni = sesje z terminem po × (zamówienia na termin przed − po); × 30,44 / 28 na miesiąc
--   wartość = utracone zamówienia × średnie netto zamówienia po (amount_paid − refund_amount)
SELECT zdarzenie,
       count(*) FILTER (okno = 'po') AS termin_po,
       round(100.0 * count(*) FILTER (okno = 'przed' AND zamowienie) / count(*) FILTER (okno = 'przed'), 2) AS zam_na_termin_przed_pct,
       round(100.0 * count(*) FILTER (okno = 'po' AND zamowienie) / count(*) FILTER (okno = 'po'), 2) AS zam_na_termin_po_pct,
       count(*) FILTER (okno = 'po' AND zamowienie) AS zamowienia_po,
       round(count(*) FILTER (okno = 'po') * (count(*) FILTER (okno = 'przed' AND zamowienie)::DOUBLE / count(*) FILTER (okno = 'przed')
             - count(*) FILTER (okno = 'po' AND zamowienie)::DOUBLE / count(*) FILTER (okno = 'po')), 1) AS utracone_zamowienia_28_dni,
       round(count(*) FILTER (okno = 'po') * (count(*) FILTER (okno = 'przed' AND zamowienie)::DOUBLE / count(*) FILTER (okno = 'przed')
             - count(*) FILTER (okno = 'po' AND zamowienie)::DOUBLE / count(*) FILTER (okno = 'po')) * 30.44 / 28, 1) AS utracone_zamowienia_miesiac,
       round(sum(netto) FILTER (okno = 'po' AND zamowienie) / count(*) FILTER (okno = 'po' AND zamowienie), 2) AS netto_na_zamowienie_po,
       round(count(*) FILTER (okno = 'po') * (count(*) FILTER (okno = 'przed' AND zamowienie)::DOUBLE / count(*) FILTER (okno = 'przed')
             - count(*) FILTER (okno = 'po' AND zamowienie)::DOUBLE / count(*) FILTER (okno = 'po')) * 30.44 / 28
             * sum(netto) FILTER (okno = 'po' AND zamowienie) / count(*) FILTER (okno = 'po' AND zamowienie), 0) AS utracone_netto_miesiac_zl
FROM dd_sessions GROUP BY 1 ORDER BY 1;

-- D6 kontrola statusu logowania w całych danych: sesje z user_id a zdarzenie account_completed
SELECT (s.user_id IS NOT NULL) AS user_id_w_sesji,
       (acc.session_id IS NOT NULL) AS account_completed,
       count(*) AS sesje,
       count(*) FILTER (f.k2) AS sesje_z_terminem,
       count(*) FILTER (f.k5) AS sesje_z_platnoscia
FROM s JOIN session_funnel f USING (session_id)
LEFT JOIN (SELECT DISTINCT session_id FROM e WHERE event_name = 'account_completed') acc USING (session_id)
GROUP BY 1, 2 ORDER BY 1, 2;

-- D7 nowi czy znani: odwiedzający znany = jego visitor_id miał wcześniej sesję z user_id (konto znane przed tą sesją)
--    (podział 'zalogowany na wejściu' jest pusty: każda sesja z płatnością ma account_completed, D6)
SELECT d.zdarzenie,
       CASE WHEN EXISTS (SELECT 1 FROM s p WHERE p.visitor_id = s.visitor_id AND p.user_id IS NOT NULL AND p.started_at < s.started_at)
            THEN 'znany (konto wcześniej)' ELSE 'nowy odwiedzający' END AS kto,
       count(*) FILTER (d.okno = 'przed') AS termin_przed, count(*) FILTER (d.okno = 'przed' AND d.konto) AS konto_przed,
       round(100.0 * count(*) FILTER (d.okno = 'przed' AND d.konto) / nullif(count(*) FILTER (d.okno = 'przed'), 0), 1) AS f3_przed,
       count(*) FILTER (d.okno = 'po') AS termin_po, count(*) FILTER (d.okno = 'po' AND d.konto) AS konto_po,
       round(100.0 * count(*) FILTER (d.okno = 'po' AND d.konto) / nullif(count(*) FILTER (d.okno = 'po'), 0), 1) AS f3_po
FROM dd_sessions d JOIN s USING (session_id)
GROUP BY 1, 2 ORDER BY 1, 2;

-- D8 Z1 w czasie: iOS mobile Safari vs pozostały Safari, F3 miesięcznie (czy problem trwa do końca danych)
SELECT date_trunc('month', f.day)::DATE AS miesiac,
       count(*) FILTER (f.k2 AND s.browser = 'Safari' AND s.device = 'mobile') AS termin_ios_mobile,
       round(100.0 * count(*) FILTER (f.k3 AND s.browser = 'Safari' AND s.device = 'mobile') / nullif(count(*) FILTER (f.k2 AND s.browser = 'Safari' AND s.device = 'mobile'), 0), 1) AS f3_ios_mobile,
       count(*) FILTER (f.k2 AND s.browser = 'Safari' AND s.device <> 'mobile') AS termin_safari_inne,
       round(100.0 * count(*) FILTER (f.k3 AND s.browser = 'Safari' AND s.device <> 'mobile') / nullif(count(*) FILTER (f.k2 AND s.browser = 'Safari' AND s.device <> 'mobile'), 0), 1) AS f3_safari_inne,
       count(*) FILTER (f.k2 AND s.os = 'iOS' AND s.browser <> 'Safari') AS termin_ios_inne_przegladarki,
       round(100.0 * count(*) FILTER (f.k3 AND s.os = 'iOS' AND s.browser <> 'Safari') / nullif(count(*) FILTER (f.k2 AND s.os = 'iOS' AND s.browser <> 'Safari'), 0), 1) AS f3_ios_inne_przegladarki
FROM session_funnel f JOIN s USING (session_id)
WHERE (s.browser = 'Safari' OR s.os = 'iOS') AND f.day >= DATE '2025-09-01'
GROUP BY 1 ORDER BY 1;

-- D9 Z1 straty od 17.03 do końca danych: iOS mobile Safari, zamówienia na sesję z terminem vs poziom z 28 dni przed
WITH base AS (
    SELECT f.day, f.k2, (o2.session_id IS NOT NULL) AS zam, o2.netto
    FROM session_funnel f JOIN s USING (session_id)
    LEFT JOIN (SELECT session_id, sum(amount_paid - refund_amount) netto FROM o GROUP BY 1) o2 USING (session_id)
    WHERE s.browser = 'Safari' AND s.device = 'mobile' AND f.k2
)
SELECT count(*) FILTER (day >= DATE '2026-02-17' AND day < DATE '2026-03-17') AS termin_przed,
       round(100.0 * count(*) FILTER (zam AND day >= DATE '2026-02-17' AND day < DATE '2026-03-17')
             / count(*) FILTER (day >= DATE '2026-02-17' AND day < DATE '2026-03-17'), 2) AS zam_na_termin_przed_pct,
       count(*) FILTER (day >= DATE '2026-03-17') AS termin_od_17_03,
       count(*) FILTER (zam AND day >= DATE '2026-03-17') AS zamowienia_od_17_03,
       round(100.0 * count(*) FILTER (zam AND day >= DATE '2026-03-17') / count(*) FILTER (day >= DATE '2026-03-17'), 2) AS zam_na_termin_po_pct,
       round(count(*) FILTER (day >= DATE '2026-03-17')
             * count(*) FILTER (zam AND day >= DATE '2026-02-17' AND day < DATE '2026-03-17')::DOUBLE / count(*) FILTER (day >= DATE '2026-02-17' AND day < DATE '2026-03-17')
             - count(*) FILTER (zam AND day >= DATE '2026-03-17'), 0) AS utracone_zamowienia_od_17_03,
       (DATE '2026-09-30' - DATE '2026-03-17' + 1) AS dni,
       round(sum(netto) FILTER (zam AND day >= DATE '2026-03-17') / count(*) FILTER (zam AND day >= DATE '2026-03-17'), 2) AS netto_na_zamowienie
FROM base;

-- D10 Z1 w transakcjach: opłacone pierwsze zamówienia nowych pacjentów (Q1 a2) z sesji Safari na iPhonie,
--     28 dni przed i po 17.03.2026, na tle sesji nowych odwiedzających z wybranym terminem
SELECT CASE WHEN p.cohort_day < DATE '2026-03-17' THEN 'przed' ELSE 'po' END AS okno,
       count(*) AS nowi_pacjenci_safari_iphone,
       count(*) FILTER (ao.status <> 'cancelled') AS w_tym_oplacone_nieanulowane
FROM patients p JOIN o ao ON ao.order_id = p.anchor_order_id JOIN s USING (session_id)
WHERE s.browser = 'Safari' AND s.device = 'mobile'
  AND p.cohort_day >= DATE '2026-02-17' AND p.cohort_day < DATE '2026-04-14'
GROUP BY 1 ORDER BY 1 DESC;

SELECT CASE WHEN f.day < DATE '2026-03-17' THEN 'przed' ELSE 'po' END AS okno,
       count(*) AS sesje_nowych_z_terminem,
       count(*) FILTER (o2.session_id IS NOT NULL) AS z_oplaconym_zamowieniem,
       round(100.0 * count(*) FILTER (o2.session_id IS NOT NULL) / count(*), 2) AS pct
FROM session_funnel f JOIN s USING (session_id)
LEFT JOIN (SELECT DISTINCT session_id FROM o) o2 USING (session_id)
WHERE f.k2 AND s.browser = 'Safari' AND s.device = 'mobile'
  AND f.day >= DATE '2026-02-17' AND f.day < DATE '2026-04-14'
  AND NOT EXISTS (SELECT 1 FROM s p WHERE p.visitor_id = s.visitor_id AND p.user_id IS NOT NULL AND p.started_at < s.started_at)
GROUP BY 1 ORDER BY 1 DESC;
