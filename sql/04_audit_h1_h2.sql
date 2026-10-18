-- Audyt H1 (konta testowe / wewnętrzne) i H2 (dziwne kwoty, kody rabatowe).
-- Wymaga: 00_raw_views.sql, 03_audit_base.sql. Niczego nie usuwa.
-- H1 liczone na danych Z kontami testowymi (o_all, raw_users), bo służy do ich wykrycia; H2 na danych bez nich (A11).

-- kontrola konwersji stref: pierwsza sesja w czasie polskim (UTC 2024-09-30 22:01:31 -> PL 2024-10-01 00:01:31)
SELECT min(started_at) AS pierwsza_sesja_pl FROM s;

-- ===================== H1: konta testowe / wewnętrzne =====================

-- H1.1 rozkład liczby zamówień na pacjenta (top)
SELECT n_zamowien, count(*) AS pacjenci
FROM (SELECT user_id, count(*) n_zamowien FROM o_all GROUP BY 1)
GROUP BY 1 ORDER BY 1 DESC LIMIT 15;

-- H1.2 najwięcej zamówień jednego pacjenta jednego dnia
SELECT n_dzien, count(*) AS pacjento_dni
FROM (SELECT user_id, created_at::DATE d, count(*) n_dzien FROM o_all GROUP BY 1, 2)
GROUP BY 1 ORDER BY 1 DESC LIMIT 10;

-- H1.3 rok urodzenia: zakres i skrajne wartości
SELECT min(birth_year) AS min_rok, max(birth_year) AS max_rok,
       count(*) FILTER (birth_year < 1925) AS przed_1925,
       count(*) FILTER (birth_year > 2008) AS po_2008, count(*) AS wszyscy
FROM raw_users u;

-- H1.4 rejestracje w tej samej sekundzie
SELECT kont_w_sekundzie, count(*) AS sekundy
FROM (SELECT registered_at, count(*) kont_w_sekundzie FROM raw_users u GROUP BY 1)
GROUP BY 1 ORDER BY 1;

-- H1.5 najwięcej rejestracji w jednej minucie
SELECT date_trunc('minute', registered_at) AS minuta, count(*) AS konta
FROM raw_users u GROUP BY 1 ORDER BY 2 DESC LIMIT 5;

-- H1.6 zamówienia przed rejestracją konta i zamówienia pacjentów spoza users
SELECT count(*) FILTER (o.created_at < u.registered_at) AS przed_rejestracja,
       count(*) FILTER (u.user_id IS NULL)              AS brak_konta,
       count(*)                                         AS zamowienia
FROM o_all o LEFT JOIN raw_users u USING (user_id);

-- ===================== H2: kwoty i kody rabatowe =====================

-- H2.1 kwoty skrajne
SELECT min(amount_paid) min_kwota, max(amount_paid) max_kwota,
       count(*) FILTER (amount_paid = 0)          AS kwota_0,
       count(*) FILTER (amount_paid < 0)          AS kwota_ujemna,
       count(*) FILTER (amount_paid > list_price) AS powyzej_cennika,
       count(*) AS zamowienia
FROM o;

-- H2.2 ceny katalogowe według specjalizacji i okresu
SELECT specialization, list_price, count(*) AS zamowienia,
       min(created_at)::DATE AS od, max(created_at)::DATE AS do
FROM o GROUP BY 1, 2 ORDER BY 1, 2;

-- H2.3 kody rabatowe: użycia, zniżka w zł, okres
SELECT discount_type, promo_code, count(*) AS zamowienia,
       min(list_price - amount_paid) AS min_znizka, max(list_price - amount_paid) AS max_znizka,
       min(created_at)::DATE AS od, max(created_at)::DATE AS do,
       count(*) FILTER (period(created_at) = 'P1') AS p1, count(*) FILTER (period(created_at) = 'P2') AS p2
FROM o WHERE discount_type <> 'none' OR promo_code IS NOT NULL
GROUP BY 1, 2 ORDER BY 1, 3 DESC;

-- H2.4 spójność kwoty z regułą rabatu
-- none: amount = list_price; go: internista 50%, pozostali 20%; promo: amount < list_price
SELECT discount_type,
       count(*) AS zamowienia,
       count(*) FILTER (
           (discount_type = 'none' AND amount_paid <> list_price)
        OR (discount_type = 'go' AND abs(amount_paid - list_price * CASE WHEN specialization = 'internista' THEN 0.5 ELSE 0.8 END) > 0.01)
        OR (discount_type = 'promo' AND amount_paid >= list_price)
       ) AS niezgodne_z_regula
FROM o GROUP BY 1 ORDER BY 1;

-- ===================== H1 + H2: kod TEST-QA i najaktywniejsze konta =====================

-- H1.7 konta z kodem TEST-QA: ile kont, ile ich zamówień, ile z kodem
SELECT count(DISTINCT user_id) AS konta_z_test_qa,
       (SELECT count(*) FROM o_all WHERE user_id IN (SELECT user_id FROM o_all WHERE promo_code = 'TEST-QA')) AS wszystkie_ich_zamowienia,
       count(*) AS zamowienia_z_test_qa
FROM o_all WHERE promo_code = 'TEST-QA';

-- H1.8 konta z >= 20 zamówieniami: zamówienia, w tym TEST-QA, rejestracja, okres
SELECT o.user_id, count(*) AS zamowienia,
       count(*) FILTER (promo_code = 'TEST-QA') AS test_qa,
       count(DISTINCT specialization) AS specjalizacje,
       min(created_at)::DATE AS pierwsze, max(created_at)::DATE AS ostatnie,
       any_value(u.birth_year) AS rok_ur, any_value(u.region) AS region, any_value(u.marketing_consent) AS zgoda
FROM o_all o JOIN raw_users u USING (user_id)
GROUP BY 1 HAVING count(*) >= 20 ORDER BY 2 DESC;

-- H1.9 rozkład liczby zamówień na pacjenta poza kontami TEST-QA (czy jest naturalny ogon)
SELECT CASE WHEN n >= 20 THEN '20+' WHEN n >= 10 THEN '10-19' WHEN n >= 5 THEN '5-9' ELSE n::VARCHAR END AS n_zamowien,
       count(*) AS pacjenci
FROM (SELECT user_id, count(*) n FROM o_all
      WHERE user_id NOT IN (SELECT user_id FROM o_all WHERE promo_code = 'TEST-QA') GROUP BY 1)
GROUP BY 1 ORDER BY min(n);

-- H1.10 TEST-QA: statusy, specjalizacje, metoda płatności, sesje
SELECT status, payment_method, count(*) AS zamowienia, round(avg(duration_min), 1) AS sr_czas_min
FROM o_all WHERE promo_code = 'TEST-QA' GROUP BY ALL ORDER BY 3 DESC;
