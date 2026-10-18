-- Czy spadek powrotu 90 i marży 90 od XI 2025 to efekt mieszanki źródeł?
-- Wymaga: 10_cohorts_daily.sql (patients, patient_windows), 11_daily_series.sql (patient_channel: źródło wg lnd, Q3).
-- Tylko kohorty z pełnym oknem 90 dni (do 2026-07-02).
-- Okresy kohort: A = X 2024 – X 2025 (przed), B = XI 2025 – II 2026, C = III 2026 – 2.07.2026.

CREATE OR REPLACE TABLE mix_base AS
SELECT p.user_id, p.cohort_day, date_trunc('month', p.cohort_day)::DATE AS miesiac,
       CASE WHEN p.cohort_day < DATE '2025-11-01' THEN 'A X24–X25'
            WHEN p.cohort_day < DATE '2026-03-01' THEN 'B XI25–II26'
            ELSE 'C III26–VII26' END AS okres_mix,
       pc.ch_lnd AS zrodlo,
       w.powrot,
       (w.netto_zamowienia + w.oplaty_go - w.koszt_lekarza)::DECIMAL(14, 2) AS marza
FROM patients p
JOIN patient_channel pc USING (user_id)
JOIN patient_windows w ON w.user_id = p.user_id AND w.okno = 90;

-- M1 źródło × okres: pacjenci, udział, powrót 90 (licznik / mianownik), marża 90 na pacjenta
SELECT zrodlo, okres_mix,
       count(*) AS pacjenci,
       round(100.0 * count(*) / sum(count(*)) OVER (PARTITION BY okres_mix), 1) AS udzial_pct,
       count(*) FILTER (powrot) AS powrot_licznik,
       round(100.0 * count(*) FILTER (powrot) / count(*), 1) AS powrot_90_pct,
       round(avg(marza), 2) AS marza_90_na_pacjenta
FROM mix_base GROUP BY 1, 2 ORDER BY 1, 2;

-- M2 źródło × miesiąc: powrót 90 i marża 90
CREATE OR REPLACE TABLE mix_month AS
SELECT miesiac, zrodlo, count(*) AS pacjenci, count(*) FILTER (powrot) AS powrot_licznik,
       round(100.0 * count(*) FILTER (powrot) / count(*), 1) AS powrot_90_pct,
       round(avg(marza), 2) AS marza_90_na_pacjenta
FROM mix_base GROUP BY 1, 2;

-- M2 powrót 90 (%) według miesiąca kohorty i źródła
SELECT miesiac,
       max(powrot_90_pct) FILTER (zrodlo = 'google / cpc') AS cpc,
       max(powrot_90_pct) FILTER (zrodlo = 'meta / paid_social') AS meta,
       max(powrot_90_pct) FILTER (zrodlo = 'tiktok / paid_social') AS tiktok,
       max(powrot_90_pct) FILTER (zrodlo = 'google / organic') AS organic,
       max(powrot_90_pct) FILTER (zrodlo = '(direct)') AS direct,
       max(powrot_90_pct) FILTER (zrodlo = 'polecenie / referral') AS polecenie,
       max(powrot_90_pct) FILTER (zrodlo = 'rankinglekarzy / affiliate') AS afiliacja
FROM mix_month GROUP BY 1 ORDER BY 1;

-- M2 marża 90 na pacjenta (zł) według miesiąca kohorty i źródła
SELECT miesiac,
       max(marza_90_na_pacjenta) FILTER (zrodlo = 'google / cpc') AS cpc,
       max(marza_90_na_pacjenta) FILTER (zrodlo = 'meta / paid_social') AS meta,
       max(marza_90_na_pacjenta) FILTER (zrodlo = 'tiktok / paid_social') AS tiktok,
       max(marza_90_na_pacjenta) FILTER (zrodlo = 'google / organic') AS organic,
       max(marza_90_na_pacjenta) FILTER (zrodlo = '(direct)') AS direct,
       max(marza_90_na_pacjenta) FILTER (zrodlo = 'polecenie / referral') AS polecenie,
       max(marza_90_na_pacjenta) FILTER (zrodlo = 'rankinglekarzy / affiliate') AS afiliacja
FROM mix_month GROUP BY 1 ORDER BY 1;

-- M2 liczba pacjentów (mianownik) według miesiąca kohorty i źródła
SELECT miesiac,
       max(pacjenci) FILTER (zrodlo = 'google / cpc') AS cpc,
       max(pacjenci) FILTER (zrodlo = 'meta / paid_social') AS meta,
       max(pacjenci) FILTER (zrodlo = 'tiktok / paid_social') AS tiktok,
       max(pacjenci) FILTER (zrodlo = 'google / organic') AS organic,
       max(pacjenci) FILTER (zrodlo = '(direct)') AS direct,
       max(pacjenci) FILTER (zrodlo = 'polecenie / referral') AS polecenie,
       max(pacjenci) FILTER (zrodlo = 'rankinglekarzy / affiliate') AS afiliacja
FROM mix_month GROUP BY 1 ORDER BY 1;

-- M3 rozkład zmiany (shift-share) między okresami:
--   całkowita zmiana = efekt mieszanki (zmiana udziałów przy starych wartościach)
--                    + efekt wewnątrz źródeł (zmiana wartości przy starych udziałach)
--                    + interakcja
CREATE OR REPLACE TABLE mix_cells AS
SELECT okres_mix, zrodlo, count(*) AS n,
       count(*)::DOUBLE / sum(count(*)) OVER (PARTITION BY okres_mix) AS udzial,
       avg(powrot::INT) AS powrot, avg(marza)::DOUBLE AS marza
FROM mix_base GROUP BY 1, 2;

SELECT para, metryka,
       round(sum(s2 * v2) - sum(s1 * v1), 4) AS zmiana_calkowita,
       round(sum((s2 - s1) * v1), 4) AS efekt_mieszanki,
       round(sum(s1 * (v2 - v1)), 4) AS efekt_wewnatrz_zrodel,
       round(sum((s2 - s1) * (v2 - v1)), 4) AS interakcja
FROM (
    SELECT p.para, m.metryka, z.zrodlo,
           coalesce(a.udzial, 0) s1, coalesce(b.udzial, 0) s2,
           -- źródło nieobecne w okresie bazowym (TikTok): wartość bazowa = wartość z okresu porównywanego
           CASE m.metryka WHEN 'powrót 90' THEN coalesce(a.powrot, b.powrot) ELSE coalesce(a.marza, b.marza) END v1,
           CASE m.metryka WHEN 'powrót 90' THEN coalesce(b.powrot, a.powrot) ELSE coalesce(b.marza, a.marza) END v2
    FROM (VALUES ('A → B', 'A X24–X25', 'B XI25–II26'), ('B → C', 'B XI25–II26', 'C III26–VII26'), ('A → C', 'A X24–X25', 'C III26–VII26')) p(para, o1, o2)
    CROSS JOIN (VALUES ('powrót 90'), ('marża 90')) m(metryka)
    CROSS JOIN (SELECT DISTINCT zrodlo FROM mix_cells) z
    LEFT JOIN mix_cells a ON a.okres_mix = p.o1 AND a.zrodlo = z.zrodlo
    LEFT JOIN mix_cells b ON b.okres_mix = p.o2 AND b.zrodlo = z.zrodlo
) GROUP BY 1, 2 ORDER BY 2, 1;

-- M4 kontrola: wartość całkowita w okresach (musi się zgadzać z sumą z M1)
SELECT okres_mix, count(*) AS pacjenci, round(100.0 * avg(powrot::INT), 2) AS powrot_90_pct, round(avg(marza), 2) AS marza_90_na_pacjenta
FROM mix_base GROUP BY 1 ORDER BY 1;

-- M5 kampanie w źródłach płatnych: kampania ostatniej niebezpośredniej sesji (lnd) przed pierwszym zamówieniem
CREATE OR REPLACE TABLE patient_campaign AS
SELECT p.user_id,
       (SELECT s2.utm_campaign FROM user_visitor uv JOIN s s2 USING (visitor_id)
        WHERE uv.user_id = p.user_id AND s2.started_at <= p.t0 AND s2.utm_source IS NOT NULL
        ORDER BY s2.started_at DESC, s2.session_id DESC LIMIT 1) AS kampania
FROM patients p;

SELECT mb.zrodlo, coalesce(pc.kampania, '(brak)') AS kampania, mb.okres_mix,
       count(*) AS pacjenci,
       count(*) FILTER (mb.powrot) AS powrot_licznik,
       round(100.0 * count(*) FILTER (mb.powrot) / count(*), 1) AS powrot_90_pct,
       round(avg(mb.marza), 2) AS marza_90_na_pacjenta
FROM mix_base mb JOIN patient_campaign pc USING (user_id)
WHERE mb.zrodlo IN ('google / cpc', 'meta / paid_social', 'tiktok / paid_social')
GROUP BY 1, 2, 3 ORDER BY 1, 2, 3;

-- M6 powrót 90 i marża 90 bez kampanii L4 (meta_prosp_l4_szybko, tt_prosp_l4_15min) i bez kodów L4SZYBKO20 / TIKTOK25
SELECT mb.okres_mix,
       count(*) AS pacjenci,
       round(100.0 * avg(mb.powrot::INT), 2) AS powrot_90_pct,
       round(avg(mb.marza), 2) AS marza_90_na_pacjenta,
       count(*) FILTER (NOT l4) AS pacjenci_bez_l4_kampanii,
       round(100.0 * avg(mb.powrot::INT) FILTER (NOT l4), 2) AS powrot_90_bez_l4_kampanii_pct,
       round(avg(mb.marza) FILTER (NOT l4), 2) AS marza_90_bez_l4_kampanii
FROM (
    SELECT mb.*, (coalesce(pc.kampania, '') IN ('meta_prosp_l4_szybko', 'tt_prosp_l4_15min')
                  OR coalesce(ao.promo_code, '') IN ('L4SZYBKO20', 'TIKTOK25')) AS l4
    FROM mix_base mb JOIN patient_campaign pc USING (user_id)
    JOIN patients p USING (user_id) JOIN o ao ON ao.order_id = p.anchor_order_id
) mb GROUP BY 1 ORDER BY 1;

-- M7 pacjenci spoza kampanii i kodów L4: powrót 90 według celu pierwszej wizyty (L4 vs pozostałe),
--    te same miesiące kalendarzowe (III–VI) w 2025 i 2026, żeby ominąć sezon
SELECT year(mb.cohort_day) AS rok,
       (ao.visit_purpose = 'l4') AS pierwsza_wizyta_l4,
       count(*) AS pacjenci,
       round(100.0 * count(*) / sum(count(*)) OVER (PARTITION BY year(mb.cohort_day)), 1) AS udzial_pct,
       count(*) FILTER (mb.powrot) AS powrot_licznik,
       round(100.0 * avg(mb.powrot::INT), 1) AS powrot_90_pct,
       round(avg(mb.marza), 2) AS marza_90_na_pacjenta
FROM mix_base mb
JOIN patient_campaign pc USING (user_id)
JOIN patients p USING (user_id) JOIN o ao ON ao.order_id = p.anchor_order_id
WHERE month(mb.cohort_day) BETWEEN 3 AND 6
  AND coalesce(pc.kampania, '') NOT IN ('meta_prosp_l4_szybko', 'tt_prosp_l4_15min')
  AND coalesce(ao.promo_code, '') NOT IN ('L4SZYBKO20', 'TIKTOK25')
GROUP BY 1, 2 ORDER BY 1, 2;
