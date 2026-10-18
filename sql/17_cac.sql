-- CAC na kanał i kampanię w P2 obok marży 90 i 180 dni na pacjenta. Czy kampanie L4 się zwracają?
-- Wymaga: 00_raw_views.sql, 03_audit_base.sql, 06_audit_h4.sql (attribution: pierwsze zamówienie dowolny status, ch_lnd),
--         10_cohorts_daily.sql (patients, patient_windows), 11_daily_series.sql (patient_channel),
--         13_mix_by_source.sql (patient_campaign: kampania lnd).
-- Decyzje: Q1 a2 (pacjenci), Q3 lnd główny + first / last jako zakres, A13 (afiliacja 25 zł za każde pierwsze
--          zamówienie, także anulowane; mianownik = pacjenci a2), A14 (koszt i marża z tych samych miesięcy):
--   okno 90 dni:  kohorty i koszty 2025-10-01 – 2026-07-02
--   okno 180 dni: kohorty i koszty 2025-10-01 – 2026-04-03
-- Marża na pacjenta = przychód netto + opłaty GO − koszt lekarza w oknie (A1–A3), bez kosztu pozyskania.

CREATE OR REPLACE TABLE cac_windows AS
SELECT * FROM (VALUES (90, DATE '2025-10-01', DATE '2026-07-02'), (180, DATE '2025-10-01', DATE '2026-04-03')) t(okno, od, do_);

-- przypisanie first / last (zakres) dla pacjentów a2: kanał i kampania
CREATE OR REPLACE TABLE patient_attr AS
SELECT p.user_id, p.cohort_day,
       pc.ch_lnd, coalesce(pk.kampania, '') AS kamp_lnd,
       channel(ls.utm_source, ls.utm_medium) AS ch_last, coalesce(ls.utm_campaign, '') AS kamp_last,
       (SELECT channel(s2.utm_source, s2.utm_medium) FROM user_visitor uv JOIN s s2 USING (visitor_id)
        WHERE uv.user_id = p.user_id AND s2.started_at <= p.t0 ORDER BY s2.started_at, s2.session_id LIMIT 1) AS ch_first,
       coalesce((SELECT s2.utm_campaign FROM user_visitor uv JOIN s s2 USING (visitor_id)
        WHERE uv.user_id = p.user_id AND s2.started_at <= p.t0 ORDER BY s2.started_at, s2.session_id LIMIT 1), '') AS kamp_first
FROM patients p
JOIN patient_channel pc USING (user_id)
JOIN patient_campaign pk USING (user_id)
JOIN o ao ON ao.order_id = p.anchor_order_id
LEFT JOIN s ls ON ls.session_id = ao.session_id;

-- jednostka analizy: kampania płatna ('źródło / kampania') albo kanał bezpłatny / afiliacja
CREATE OR REPLACE MACRO unit(ch, kamp) AS
    CASE WHEN ch IN ('google / cpc', 'meta / paid_social', 'tiktok / paid_social') THEN ch || ' | ' || kamp ELSE ch END;

-- koszty w oknie: kampanie za klik
CREATE OR REPLACE TABLE unit_cost AS
SELECT w.okno, (m.utm_source || ' / ' || m.utm_medium) || ' | ' || m.utm_campaign AS jednostka, sum(m.spend_pln::DECIMAL(14, 2)) AS koszt
FROM m JOIN cac_windows w ON m.date BETWEEN w.od AND w.do_
GROUP BY 1, 2
UNION ALL
-- afiliacja (A13): 25 zł za każde pierwsze zamówienie (dowolny status) przypisane lnd do afiliacji, z datą w oknie
SELECT w.okno, 'rankinglekarzy / affiliate', 25 * count(*)
FROM attribution a JOIN cac_windows w ON a.created_at::DATE BETWEEN w.od AND w.do_
WHERE a.ch_lnd = 'rankinglekarzy / affiliate'
GROUP BY 1, 2;

-- pacjenci i marża w oknie według jednostki (lnd), plus liczba pacjentów według first i last (zakres CAC)
CREATE OR REPLACE TABLE unit_patients AS
SELECT w.okno, x.wariant, x.jednostka,
       count(*) AS pacjenci,
       sum((pw.netto_zamowienia + pw.oplaty_go - pw.koszt_lekarza)::DECIMAL(14, 2)) AS marza_suma,
       count(*) FILTER (pw.powrot) AS powrot_licznik
FROM (
    SELECT user_id, cohort_day, 'lnd' AS wariant, unit(ch_lnd, kamp_lnd) AS jednostka FROM patient_attr
    UNION ALL SELECT user_id, cohort_day, 'first', unit(ch_first, kamp_first) FROM patient_attr
    UNION ALL SELECT user_id, cohort_day, 'last', unit(ch_last, kamp_last) FROM patient_attr
) x
JOIN cac_windows w ON x.cohort_day BETWEEN w.od AND w.do_
JOIN patient_windows pw ON pw.user_id = x.user_id AND pw.okno = w.okno
GROUP BY 1, 2, 3;

-- kontrola: pacjenci w oknach (każdy wariant musi dać tę samą sumę) i suma kosztów
SELECT okno, wariant, sum(pacjenci) AS pacjenci FROM unit_patients GROUP BY 1, 2 ORDER BY 1, 2;
SELECT okno, round(sum(koszt), 2) AS koszt_razem, round(sum(koszt) FILTER (jednostka LIKE '%affiliate%'), 2) AS afiliacja FROM unit_cost GROUP BY 1 ORDER BY 1;

-- C1 tabela główna: jednostka × okno, CAC (lnd) z zakresem (first, last), marża na pacjenta, marża − CAC
CREATE OR REPLACE TABLE cac_table AS
SELECT l.okno, l.jednostka,
       coalesce(c.koszt, 0) AS koszt,
       l.pacjenci AS pacjenci_lnd,
       f.pacjenci AS pacjenci_first, la.pacjenci AS pacjenci_last,
       round(coalesce(c.koszt, 0) / l.pacjenci, 2) AS cac_lnd,
       round(coalesce(c.koszt, 0) / nullif(f.pacjenci, 0), 2) AS cac_first,
       round(coalesce(c.koszt, 0) / nullif(la.pacjenci, 0), 2) AS cac_last,
       round(l.marza_suma / l.pacjenci, 2) AS marza_na_pacjenta,
       round(100.0 * l.powrot_licznik / l.pacjenci, 1) AS powrot_pct,
       round(l.marza_suma / l.pacjenci - coalesce(c.koszt, 0) / l.pacjenci, 2) AS marza_minus_cac,
       round((l.marza_suma / l.pacjenci) / nullif(coalesce(c.koszt, 0) / l.pacjenci, 0), 2) AS marza_do_cac
FROM (SELECT * FROM unit_patients WHERE wariant = 'lnd') l
LEFT JOIN (SELECT * FROM unit_patients WHERE wariant = 'first') f USING (okno, jednostka)
LEFT JOIN (SELECT * FROM unit_patients WHERE wariant = 'last') la USING (okno, jednostka)
LEFT JOIN unit_cost c USING (okno, jednostka);

SELECT okno, jednostka, round(koszt, 2) AS koszt, pacjenci_lnd, pacjenci_first, pacjenci_last,
       cac_lnd, cac_first, cac_last, marza_na_pacjenta, powrot_pct, marza_minus_cac, marza_do_cac
FROM cac_table WHERE pacjenci_lnd >= 30 OR koszt > 0
ORDER BY okno, koszt DESC, pacjenci_lnd DESC;

-- C2 kampanie z kosztem bez przypisanych pacjentów (koszt nie trafia do żadnej jednostki w tabeli C1)
SELECT c.okno, c.jednostka, round(c.koszt, 2) AS koszt
FROM unit_cost c LEFT JOIN (SELECT * FROM unit_patients WHERE wariant = 'lnd') l USING (okno, jednostka)
WHERE l.jednostka IS NULL ORDER BY 1, 3 DESC;

-- C3 podsumowanie: kampanie L4 vs pozostałe płatne vs bezpłatne (okno 180 i 90)
SELECT okno,
       CASE WHEN jednostka LIKE '%meta_prosp_l4_szybko%' OR jednostka LIKE '%tt_prosp_l4_15min%' THEN '1 kampanie L4 (Meta, TikTok)'
            WHEN koszt > 0 THEN '2 pozostałe płatne (kampanie za klik i afiliacja)'
            ELSE '3 bezpłatne (organic, direct, polecenia, e-mail, sms)' END AS grupa,
       round(sum(koszt), 2) AS koszt, sum(pacjenci_lnd) AS pacjenci,
       round(sum(koszt) / sum(pacjenci_lnd), 2) AS cac,
       round(sum(marza_na_pacjenta * pacjenci_lnd) / sum(pacjenci_lnd), 2) AS marza_na_pacjenta,
       round(sum(marza_na_pacjenta * pacjenci_lnd) / sum(pacjenci_lnd) - sum(koszt) / sum(pacjenci_lnd), 2) AS marza_minus_cac
FROM cac_table GROUP BY 1, 2 ORDER BY 1, 2;
