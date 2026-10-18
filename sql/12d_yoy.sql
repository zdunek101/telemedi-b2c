-- Rok do roku dla zdarzeń z P2: te same okna 28/28 dni przesunięte o 364 dni (ten sam dzień tygodnia).
-- Wymaga 12_change_points.sql i 12c_power_diag.sql (tabela nothr: segment 'wszystko' bez progów).
CREATE OR REPLACE TABLE check_days AS
SELECT DISTINCT metric, day, 'wykrycie (próg)' AS typ FROM cp_all WHERE dim = 'wszystko' AND day >= DATE '2025-10-29'
UNION ALL SELECT * FROM (VALUES
    ('C5 powrót 90 dni', DATE '2025-11-18', 'słaby sygnał'),
    ('C6 marża 90 dni na pacjenta', DATE '2025-11-01', 'słaby sygnał'),
    ('C2 L4 w pierwszym zamówieniu', DATE '2025-11-19', 'słaby sygnał'),
    ('O1 udział L4 w zamówieniach', DATE '2025-11-26', 'słaby sygnał'),
    ('F6 sesja → płatność', DATE '2025-11-15', 'słaby sygnał'),
    ('F1 sesja → usługa', DATE '2025-12-08', 'słaby sygnał'),
    ('C1 nowi pacjenci', DATE '2026-04-05', 'słaby sygnał'),
    ('F0 sesje', DATE '2026-04-30', 'słaby sygnał')) t(metric, day, typ);

SELECT c.typ, c.metric, c.day,
       round(t.przed, 4) AS przed, round(t.po, 4) AS po, round(100 * (t.po / t.przed - 1), 1) AS zmiana_pct,
       round((t.po - t.przed) / (t.sigma * sqrt(2.0 / 28)), 1) AS z,
       r.day AS dzien_rok_wczesniej,
       round(r.przed, 4) AS przed_rok_wczesniej, round(r.po, 4) AS po_rok_wczesniej,
       round(100 * (r.po / r.przed - 1), 1) AS zmiana_rok_wczesniej_pct,
       round((r.po - r.przed) / (r.sigma * sqrt(2.0 / 28)), 1) AS z_rok_wczesniej
FROM check_days c
JOIN nothr t ON t.metric = c.metric AND t.day = c.day
LEFT JOIN nothr r ON r.metric = c.metric AND r.day = c.day - INTERVAL 364 DAY
ORDER BY c.day, c.metric;
