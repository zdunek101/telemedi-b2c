-- Lista zdarzeń pogrupowana po dacie, najmocniejsze na górze; osobno kroki lejka (F1–F6).
-- Czyta tool/data/change_points.csv (wynik 12_change_points.sql), bez wykryć wydatków na kampanie i nietrwałych.
CREATE OR REPLACE TABLE cp AS SELECT * FROM read_csv('tool/data/change_points.csv') WHERE zdarzenie IS NOT NULL;

-- poza lejkiem: sesje (F0), nowi pacjenci (C1) i pozostałe metryki
SELECT zdarzenie, min(day) AS od, max(day) AS "do", round(max(abs(z)), 1) AS max_z, count(*) AS szeregi,
       string_agg(metric || ' | ' || dim || ': ' || seg || ' ' || CASE WHEN efekt_wzgl > 0 THEN '+' ELSE '' END
                  || round(100 * efekt_wzgl, 0) || '% (z ' || round(z, 1) || ')', '; ' ORDER BY abs(z) DESC) AS co
FROM cp WHERE NOT regexp_matches(metric, '^F[1-6] ') GROUP BY 1 ORDER BY max_z DESC;

-- kroki lejka (F1–F6)
SELECT zdarzenie, min(day) AS od, max(day) AS "do", round(max(abs(z)), 1) AS max_z, count(*) AS szeregi,
       string_agg(metric || ' | ' || dim || ': ' || seg || ' ' || round(100 * przed, 1) || '% → ' || round(100 * po, 1)
                  || '% (z ' || round(z, 1) || ')', '; ' ORDER BY abs(z) DESC) AS co
FROM cp WHERE regexp_matches(metric, '^F[1-6] ') GROUP BY 1 ORDER BY max_z DESC;
