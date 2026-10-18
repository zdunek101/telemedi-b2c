-- Kohorty dzienne. Wymaga: 00_raw_views.sql, 03_audit_base.sql (baza A8 + A11).
-- Kohorta = dzień polski pierwszego nieanulowanego zamówienia (Q1 a2).
-- Powrót = kolejne nieanulowane zamówienie po zamówieniu otwierającym w ciągu W dni (Q4 b).
-- Przychód netto w oknie = suma (amount_paid - refund_amount) wszystkich zamówień pacjenta w [t0, t0 + W)
--   łącznie z zamówieniem otwierającym, plus opłaty GO kupione w tym oknie (A3).
-- Marża w oknie = przychód netto - koszt lekarza za wizyty odbyte (completed, refunded) zamówione w oknie
--   (A1, A2: internista 25, psychiatra 200, pozostali 100 zł; datowanie po created_at, A10).
-- Bez kosztu pozyskania (CAC liczony osobno na kanał i okres).
-- Pełne okno W: dzień kohorty d <= 2026-09-30 - W dni (ostatni pacjent dnia d ma całe okno przed końcem danych).
-- Do narzędzia trafiają wyłącznie agregaty dzienne (tool/data/cohorts_daily.csv).

CREATE OR REPLACE MACRO doctor_cost(spec) AS
    CASE spec WHEN 'internista' THEN 25 WHEN 'psychiatra' THEN 200 ELSE 100 END;

CREATE OR REPLACE MACRO full_window(d, w) AS d <= DATE '2026-09-30' - to_days(w);

-- pacjent i zamówienie otwierające (Q1 a2)
CREATE OR REPLACE TABLE patients AS
SELECT user_id, order_id AS anchor_order_id, created_at AS t0, created_at::DATE AS cohort_day
FROM o WHERE status <> 'cancelled'
QUALIFY row_number() OVER (PARTITION BY user_id ORDER BY created_at, order_id) = 1;

-- wartości na poziomie pacjenta dla okien 30 / 90 / 180 (tabela robocza, nie trafia do narzędzia)
CREATE OR REPLACE TABLE patient_windows AS
SELECT p.user_id, p.cohort_day, w.okno,
       -- powrót: inne nieanulowane zamówienie w oknie, po zamówieniu otwierającym
       EXISTS (SELECT 1 FROM o x WHERE x.user_id = p.user_id AND x.status <> 'cancelled'
               AND x.order_id <> p.anchor_order_id
               AND x.created_at >= p.t0 AND x.created_at < p.t0 + to_days(w.okno)) AS powrot,
       coalesce((SELECT sum(x.amount_paid - x.refund_amount) FROM o x
                 WHERE x.user_id = p.user_id AND x.created_at >= p.t0 AND x.created_at < p.t0 + to_days(w.okno)), 0) AS netto_zamowienia,
       coalesce((SELECT sum(gg.amount_paid) FROM g gg
                 WHERE gg.user_id = p.user_id AND gg.purchased_at >= p.t0 AND gg.purchased_at < p.t0 + to_days(w.okno)), 0) AS oplaty_go,
       coalesce((SELECT sum(doctor_cost(x.specialization)) FROM o x
                 WHERE x.user_id = p.user_id AND x.status IN ('completed', 'refunded')
                 AND x.created_at >= p.t0 AND x.created_at < p.t0 + to_days(w.okno)), 0) AS koszt_lekarza
FROM patients p, (VALUES (30), (90), (180)) w(okno)
WHERE full_window(p.cohort_day, w.okno);

-- kohorty dzienne: wszystkie dni z nowymi pacjentami; metryki okna puste, gdy okno niepełne
CREATE OR REPLACE TABLE cohorts_daily AS
WITH n AS (SELECT cohort_day, count(*) AS nowi FROM patients GROUP BY 1),
     agg AS (
         SELECT cohort_day, okno,
                count(*) AS pacjenci,
                count(*) FILTER (powrot) AS powracajacy,
                sum(netto_zamowienia + oplaty_go) AS netto,
                sum(netto_zamowienia + oplaty_go - koszt_lekarza) AS marza
         FROM patient_windows GROUP BY 1, 2
     )
SELECT n.cohort_day,
       period(n.cohort_day::TIMESTAMP) AS okres,
       n.nowi,
       a30.powracajacy  AS powrot_30_licznik,  a30.pacjenci  AS powrot_30_mianownik,
       round(100.0 * a30.powracajacy / a30.pacjenci, 2)   AS powrot_30_pct,
       a90.powracajacy  AS powrot_90_licznik,  a90.pacjenci  AS powrot_90_mianownik,
       round(100.0 * a90.powracajacy / a90.pacjenci, 2)   AS powrot_90_pct,
       a180.powracajacy AS powrot_180_licznik, a180.pacjenci AS powrot_180_mianownik,
       round(100.0 * a180.powracajacy / a180.pacjenci, 2) AS powrot_180_pct,
       round(a90.netto, 2)  AS netto_90_zl,  round(a90.netto / a90.pacjenci, 2)   AS netto_90_na_pacjenta_zl,
       round(a90.marza, 2)  AS marza_90_zl,  round(a90.marza / a90.pacjenci, 2)   AS marza_90_na_pacjenta_zl,
       round(a180.netto, 2) AS netto_180_zl, round(a180.netto / a180.pacjenci, 2) AS netto_180_na_pacjenta_zl,
       round(a180.marza, 2) AS marza_180_zl, round(a180.marza / a180.pacjenci, 2) AS marza_180_na_pacjenta_zl
FROM n
LEFT JOIN agg a30  ON a30.cohort_day  = n.cohort_day AND a30.okno  = 30
LEFT JOIN agg a90  ON a90.cohort_day  = n.cohort_day AND a90.okno  = 90
LEFT JOIN agg a180 ON a180.cohort_day = n.cohort_day AND a180.okno = 180
ORDER BY 1;

-- ===================== kontrole =====================

-- K1 liczba dni i suma nowych (oczekiwane: 730 dni, 39 486 = 15 679 + 23 807)
SELECT count(*) AS dni, sum(nowi) AS nowi_razem,
       sum(nowi) FILTER (okres = 'P1') AS nowi_p1, sum(nowi) FILTER (okres = 'P2') AS nowi_p2,
       min(cohort_day) AS od, max(cohort_day) AS do,
       min(nowi) AS min_nowi_dzien, round(median(nowi), 1) AS mediana_nowi_dzien, max(nowi) AS max_nowi_dzien
FROM cohorts_daily;

-- K2 ostatni dzień z pełnym oknem dla każdej metryki i liczba takich dni
SELECT max(cohort_day) FILTER (powrot_30_mianownik IS NOT NULL)  AS ostatni_dzien_30,
       count(*)        FILTER (powrot_30_mianownik IS NOT NULL)  AS dni_30,
       max(cohort_day) FILTER (powrot_90_mianownik IS NOT NULL)  AS ostatni_dzien_90,
       count(*)        FILTER (powrot_90_mianownik IS NOT NULL)  AS dni_90,
       max(cohort_day) FILTER (powrot_180_mianownik IS NOT NULL) AS ostatni_dzien_180,
       count(*)        FILTER (powrot_180_mianownik IS NOT NULL) AS dni_180,
       count(*) FILTER (powrot_90_mianownik IS NOT NULL AND powrot_90_mianownik <> nowi) AS dni_90_mianownik_rozny_od_nowych
FROM cohorts_daily;

-- K3 powrót 90 dni dwiema drogami: suma po dniach vs bezpośrednio na pacjentach (P1 i P2)
SELECT d.okres, d.licznik_z_dni, d.mianownik_z_dni,
       p.licznik_z_pacjentow, p.mianownik_z_pacjentow,
       round(100.0 * d.licznik_z_dni / d.mianownik_z_dni, 2) AS powrot_90_pct
FROM (SELECT okres, sum(powrot_90_licznik) licznik_z_dni, sum(powrot_90_mianownik) mianownik_z_dni
      FROM cohorts_daily GROUP BY 1) d
JOIN (SELECT period(pp.t0) okres,
             count(*) FILTER (EXISTS (SELECT 1 FROM o x WHERE x.user_id = pp.user_id AND x.status <> 'cancelled'
                                      AND x.order_id <> pp.anchor_order_id AND x.created_at >= pp.t0
                                      AND x.created_at < pp.t0 + INTERVAL 90 DAY))  AS licznik_z_pacjentow,
             count(*) AS mianownik_z_pacjentow
      FROM patients pp WHERE pp.cohort_day <= DATE '2026-09-30' - INTERVAL 90 DAY GROUP BY 1) p USING (okres)
ORDER BY 1;

-- K4 przychód netto 90 dni z kohort vs suma netto zamówień + GO policzona z drugiej strony (od zamówień do pacjentów)
SELECT (SELECT round(sum(netto_90_zl), 2) FROM cohorts_daily) AS netto_90_z_kohort,
       round(sum(x.amount_paid - x.refund_amount), 2)
       + (SELECT round(sum(gg.amount_paid), 2) FROM g gg JOIN patients p2 USING (user_id)
          WHERE p2.cohort_day <= DATE '2026-09-30' - INTERVAL 90 DAY
          AND gg.purchased_at >= p2.t0 AND gg.purchased_at < p2.t0 + INTERVAL 90 DAY) AS netto_90_z_zamowien
FROM o x JOIN patients p USING (user_id)
WHERE p.cohort_day <= DATE '2026-09-30' - INTERVAL 90 DAY
  AND x.created_at >= p.t0 AND x.created_at < p.t0 + INTERVAL 90 DAY;

-- K5 przegląd: średnie z kohort P1 vs P2 (ważone liczbą pacjentów)
SELECT okres,
       sum(nowi) AS nowi,
       round(100.0 * sum(powrot_30_licznik)  / sum(powrot_30_mianownik), 2)  AS powrot_30_pct,
       round(100.0 * sum(powrot_90_licznik)  / sum(powrot_90_mianownik), 2)  AS powrot_90_pct,
       round(100.0 * sum(powrot_180_licznik) / sum(powrot_180_mianownik), 2) AS powrot_180_pct,
       round(sum(netto_90_zl)  / sum(powrot_90_mianownik), 2)  AS netto_90_na_pacjenta,
       round(sum(marza_90_zl)  / sum(powrot_90_mianownik), 2)  AS marza_90_na_pacjenta,
       round(sum(netto_180_zl) / sum(powrot_180_mianownik), 2) AS netto_180_na_pacjenta,
       round(sum(marza_180_zl) / sum(powrot_180_mianownik), 2) AS marza_180_na_pacjenta
FROM cohorts_daily GROUP BY 1 ORDER BY 1;

-- ===================== weryfikacja ręczna: 2 losowych pacjentów =====================
-- losowanie powtarzalne: kolejność po hash(user_id || 'telemedi-2026'), kohorty z pełnym oknem 180 dni
CREATE OR REPLACE TABLE sample_patients AS
SELECT user_id, anchor_order_id, t0, cohort_day FROM patients
WHERE full_window(cohort_day, 180)
ORDER BY hash(user_id::VARCHAR || 'telemedi-2026') LIMIT 2;

-- W1 wszystkie zamówienia wylosowanych pacjentów
SELECT o.user_id, o.order_id, o.created_at, o.status, o.specialization, o.amount_paid, o.refund_amount,
       (o.order_id = sp.anchor_order_id) AS otwierajace,
       date_diff('day', sp.t0, o.created_at) AS dni_od_t0
FROM o JOIN sample_patients sp USING (user_id) ORDER BY 1, 3;

-- W2 zakupy GO wylosowanych pacjentów
SELECT gg.user_id, gg.membership_id, gg.purchased_at, gg.amount_paid, gg.order_id,
       date_diff('day', sp.t0, gg.purchased_at) AS dni_od_t0
FROM g gg JOIN sample_patients sp USING (user_id) ORDER BY 1, 3;

-- W3 wartości z SQL dla tych pacjentów
SELECT pw.user_id, pw.cohort_day, pw.okno, pw.powrot, pw.netto_zamowienia, pw.oplaty_go, pw.koszt_lekarza,
       pw.netto_zamowienia + pw.oplaty_go AS netto, pw.netto_zamowienia + pw.oplaty_go - pw.koszt_lekarza AS marza
FROM patient_windows pw JOIN sample_patients USING (user_id) ORDER BY 1, 3;

-- zapis agregatów dziennych dla narzędzia
COPY cohorts_daily TO 'tool/data/cohorts_daily.csv' (HEADER, DELIMITER ',');

-- ===================== weryfikacja dodatkowa: 2 pacjentów z trudnymi przypadkami =====================
-- D1: pacjent z GO w oknie 180, zwrotem refunded i powrotem; D2: pacjent z anulowanym zamówieniem PRZED t0 (Q1 a2)
CREATE OR REPLACE TABLE hard_patients AS
(SELECT p.user_id, p.anchor_order_id, p.t0, p.cohort_day, 'D1 GO + refunded + powrót' AS przypadek FROM patients p
 WHERE full_window(p.cohort_day, 180)
   AND EXISTS (SELECT 1 FROM g WHERE g.user_id = p.user_id AND g.purchased_at >= p.t0 AND g.purchased_at < p.t0 + INTERVAL 180 DAY)
   AND EXISTS (SELECT 1 FROM o x WHERE x.user_id = p.user_id AND x.status = 'refunded' AND x.created_at < p.t0 + INTERVAL 180 DAY)
   AND (SELECT count(*) FROM o x WHERE x.user_id = p.user_id AND x.created_at < p.t0 + INTERVAL 180 DAY) BETWEEN 3 AND 6
 ORDER BY hash(p.user_id::VARCHAR || 'telemedi-2026') LIMIT 1)
UNION ALL
(SELECT p.user_id, p.anchor_order_id, p.t0, p.cohort_day, 'D2 anulowane przed t0' FROM patients p
 WHERE full_window(p.cohort_day, 180)
   AND EXISTS (SELECT 1 FROM o x WHERE x.user_id = p.user_id AND x.status = 'cancelled' AND x.created_at < p.t0)
   AND (SELECT count(*) FROM o x WHERE x.user_id = p.user_id) BETWEEN 3 AND 6
 ORDER BY hash(p.user_id::VARCHAR || 'telemedi-2026') LIMIT 1);

-- D3 zamówienia
SELECT hp.przypadek, o.user_id, o.order_id, o.created_at, o.status, o.specialization, o.amount_paid, o.refund_amount,
       (o.order_id = hp.anchor_order_id) AS otwierajace, round(date_diff('second', hp.t0, o.created_at) / 86400.0, 2) AS dni_od_t0
FROM o JOIN hard_patients hp USING (user_id) ORDER BY 2, 4;

-- D4 GO
SELECT hp.przypadek, gg.user_id, gg.purchased_at, gg.amount_paid, gg.order_id,
       round(date_diff('second', hp.t0, gg.purchased_at) / 86400.0, 2) AS dni_od_t0
FROM g gg JOIN hard_patients hp USING (user_id) ORDER BY 2, 3;

-- D5 wartości z SQL
SELECT pw.user_id, pw.cohort_day, pw.okno, pw.powrot, pw.netto_zamowienia, pw.oplaty_go, pw.koszt_lekarza,
       pw.netto_zamowienia + pw.oplaty_go AS netto, pw.netto_zamowienia + pw.oplaty_go - pw.koszt_lekarza AS marza
FROM patient_windows pw JOIN hard_patients USING (user_id) ORDER BY 1, 3;
