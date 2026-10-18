"""Buduje dane dla narzędzia (tool/data/*.json) i kopiuje treści (tool/content/*.md).

Uruchamia istniejące pliki SQL w jednej sesji DuckDB (w pamięci) i eksportuje wyłącznie agregaty:
dzienne liczniki i mianowniki na segment, tabele mostu i CAC, kalendarz i zdarzenia.

    .venv/Scripts/python.exe scripts/build_tool_data.py
"""

import json
import os
import shutil
from datetime import date, datetime
from decimal import Decimal
from pathlib import Path

import duckdb

ROOT = Path(__file__).resolve().parent.parent
os.chdir(ROOT)
OUT = ROOT / "tool" / "data"
CONTENT = ROOT / "tool" / "content"

PIPELINE = [
    "sql/00_raw_views.sql",
    "sql/03_audit_base.sql",
    "sql/06_audit_h4.sql",
    "sql/09_definition_variants.sql",
    "sql/10_cohorts_daily.sql",
    "sql/11_daily_series.sql",
    "sql/12_change_points.sql",
    "sql/13_mix_by_source.sql",
    "sql/17_cac.sql",
]

# źródła z dużą liczbą pacjentów; pozostałe (bing, e-mail, sms) łączymy w „pozostałe” (decyzja: małe komórki)
SOURCES = ["google / cpc", "meta / paid_social", "tiktok / paid_social", "google / organic",
           "(direct)", "polecenie / referral", "rankinglekarzy / affiliate"]

con = duckdb.connect()


def run_file(path):
    for stmt in con.extract_statements(Path(path).read_text(encoding="utf-8")):
        con.sql(stmt.query)


def rows(sql):
    rel = con.sql(sql)
    cols = rel.columns
    return [dict(zip(cols, r)) for r in rel.fetchall()]


def clean(v):
    if isinstance(v, Decimal):
        return float(v)
    if isinstance(v, (date, datetime)):
        return v.isoformat()[:10]
    if isinstance(v, float):
        return round(v, 4)
    return v


def dump(name, obj):
    def conv(o):
        if isinstance(o, dict):
            return {k: conv(v) for k, v in o.items()}
        if isinstance(o, list):
            return [conv(v) for v in o]
        return clean(o)
    path = OUT / name
    path.write_text(json.dumps(conv(obj), ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    print(f"{name}: {path.stat().st_size / 1024:.0f} KB")


for f in PIPELINE:
    print("SQL", f)
    run_file(f)
print("SQL sql/02_most.sql")
run_file("sql/02_most.sql")

src_list = ", ".join(f"'{s}'" for s in SOURCES)
con.sql(f"CREATE OR REPLACE MACRO src_group(ch) AS CASE WHEN ch IN ({src_list}) THEN ch ELSE 'pozostałe' END")

days = [r["day"] for r in rows("SELECT day FROM calendar ORDER BY day")]
day_idx = {d: i for i, d in enumerate(days)}


def daily_arrays(sql, key_cols, value_cols):
    """Zwraca {klucz: {kolumna: [wartość na każdy dzień]}}; brak wiersza = 0 (dla liczników)."""
    out = {}
    for r in rows(sql):
        key = " | ".join(str(r[k]) for k in key_cols)
        series = out.setdefault(key, {c: [0] * len(days) for c in value_cols})
        i = day_idx[r["day"]]
        for c in value_cols:
            series[c][i] = clean(r[c]) if r[c] is not None else 0
    return out


# ---------- most ----------
most = rows("""
    SELECT kpi, krok, opis, max(v) FILTER (p = 'P1') AS p1, max(v) FILTER (p = 'P2') AS p2
    FROM most GROUP BY ALL ORDER BY kpi DESC, krok""")
paid_free = rows("""
    SELECT count(*) FILTER (okres = 'P1' AND NOT paid_lnd) AS lnd_p1, count(*) FILTER (okres = 'P2' AND NOT paid_lnd) AS lnd_p2,
           count(*) FILTER (okres = 'P1' AND NOT paid_first) AS first_p1, count(*) FILTER (okres = 'P2' AND NOT paid_first) AS first_p2,
           count(*) FILTER (okres = 'P1' AND NOT paid_last) AS last_p1, count(*) FILTER (okres = 'P2' AND NOT paid_last) AS last_p2
    FROM attribution_a2""")[0]
most.append({"kpi": "nowi pacjenci", "krok": 4, "opis": "w tym bez kanałów płatnych (przypisanie lnd)",
             "p1": paid_free["lnd_p1"], "p2": paid_free["lnd_p2"], "w_tym": True,
             "zakres": {"first": [paid_free["first_p1"], paid_free["first_p2"]], "last": [paid_free["last_p1"], paid_free["last_p2"]]}})
retention = rows("""
    SELECT count(*) FILTER (p.cohort_day BETWEEN DATE '2024-10-01' AND DATE '2025-10-31') AS a_pacjenci,
           count(*) FILTER (p.cohort_day BETWEEN DATE '2024-10-01' AND DATE '2025-10-31' AND w.powrot) AS a_powrot,
           count(*) FILTER (p.cohort_day BETWEEN DATE '2026-03-01' AND DATE '2026-06-30') AS w_pacjenci,
           count(*) FILTER (p.cohort_day BETWEEN DATE '2026-03-01' AND DATE '2026-06-30' AND w.powrot) AS w_powrot
    FROM patients p JOIN patient_windows w ON w.user_id = p.user_id AND w.okno = 90""")[0]
dump("most.json", {"kroki": most, "retencja_90": retention})

# ---------- kohorty dzienne według źródła (lnd) ----------
cohort_sql = """
    WITH base AS (
        -- grupa L4 (jak docs/mix.md, M6): kampania lnd L4 albo kod L4 w zamówieniu otwierającym
        SELECT p.user_id, p.cohort_day AS day, src_group(pc.ch_lnd) AS zrodlo,
               CASE WHEN coalesce(pk.kampania, '') IN ('meta_prosp_l4_szybko', 'tt_prosp_l4_15min')
                      OR coalesce(ao.promo_code, '') IN ('L4SZYBKO20', 'TIKTOK25') THEN 'kampanie L4' ELSE 'bez kampanii L4' END AS grupa
        FROM patients p JOIN patient_channel pc USING (user_id) JOIN patient_campaign pk USING (user_id)
        JOIN o ao ON ao.order_id = p.anchor_order_id
    ),
    pp AS (
        SELECT user_id, day, g.grupa, z.zrodlo FROM base,
             (SELECT unnest(['wszyscy', base.grupa]) AS grupa) g,
             (SELECT unnest(['wszystko', base.zrodlo]) AS zrodlo) z
    )
    SELECT pp.grupa, pp.zrodlo, pp.day,
           count(*) AS nowi,
           count(w30.user_id) AS m30, count(*) FILTER (w30.powrot) AS r30,
           count(w90.user_id) AS m90, count(*) FILTER (w90.powrot) AS r90,
           count(w180.user_id) AS m180, count(*) FILTER (w180.powrot) AS r180,
           coalesce(sum((w90.netto_zamowienia + w90.oplaty_go - w90.koszt_lekarza)::DECIMAL(14, 2)), 0) AS marza90,
           coalesce(sum((w180.netto_zamowienia + w180.oplaty_go - w180.koszt_lekarza)::DECIMAL(14, 2)), 0) AS marza180
    FROM pp
    LEFT JOIN patient_windows w30  ON w30.user_id  = pp.user_id AND w30.okno  = 30
    LEFT JOIN patient_windows w90  ON w90.user_id  = pp.user_id AND w90.okno  = 90
    LEFT JOIN patient_windows w180 ON w180.user_id = pp.user_id AND w180.okno = 180
    GROUP BY 1, 2, 3"""
cohorts = daily_arrays(cohort_sql, ["grupa", "zrodlo"], ["nowi", "m30", "r30", "m90", "r90", "m180", "r180", "marza90", "marza180"])
full_window = {w: rows(f"SELECT max(cohort_day) AS d FROM cohorts_daily WHERE powrot_{w}_mianownik IS NOT NULL")[0]["d"]
               for w in (30, 90, 180)}
dump("cohorts.json", {"days": days, "grupy": ["wszyscy", "kampanie L4", "bez kampanii L4"], "zrodla": ["wszystko"] + SOURCES + ["pozostałe"],
                      "ostatni_dzien_pelnego_okna": full_window, "series": cohorts})

# ---------- lejek: dzienne liczniki kroków na segment ----------
funnel_sql = """
    WITH seg AS (
        SELECT session_id, 'wszystko' AS seg FROM s
        UNION ALL SELECT session_id, 'urządzenie: ' || device FROM s
        UNION ALL SELECT session_id, 'źródło: ' || src_group(channel(utm_source, utm_medium)) FROM s
        UNION ALL SELECT session_id, 'przeglądarka: ' || browser FROM s
    )
    SELECT seg.seg, f.day, count(*) AS sesje,
           count(*) FILTER (k1) AS k1, count(*) FILTER (k2) AS k2, count(*) FILTER (k3) AS k3,
           count(*) FILTER (k4) AS k4, count(*) FILTER (k5) AS k5
    FROM session_funnel f JOIN seg USING (session_id) GROUP BY 1, 2"""
funnel = daily_arrays(funnel_sql, ["seg"], ["sesje", "k1", "k2", "k3", "k4", "k5"])
dump("funnel.json", {"days": days, "kroki": ["sesje", "usługa", "termin", "konto", "start płatności", "płatność"],
                     "series": funnel})

# ---------- kalendarz i zdarzenia ----------
calendar = rows("SELECT day, opis FROM calendar_inner ORDER BY day")
events = rows("""
    SELECT zdarzenie, min(day) AS od, max(day) AS "do", round(max(abs(z)), 1) AS max_z, count(*) AS szeregi,
           bool_or(regexp_matches(metric, '^F[1-6] ')) AS lejek,
           string_agg(metric || ' | ' || dim || ': ' || seg || ' ' || CASE WHEN efekt_wzgl > 0 THEN '+' ELSE '' END
                      || round(100 * efekt_wzgl, 0) || '% (z ' || round(z, 1) || ')', '; ' ORDER BY abs(z) DESC) AS opis
    FROM cp_events GROUP BY 1 ORDER BY max_z DESC""")
spend_changes = rows("""
    SELECT seg AS kampania, day, round(przed, 2) AS przed, round(po, 2) AS po, round(100 * efekt_wzgl, 1) AS zmiana_pct, round(z, 1) AS z
    FROM cp_all WHERE dim = 'kampania' ORDER BY day""")
dump("events.json", {"kalendarz": calendar, "zdarzenia": events, "zmiany_wydatkow": spend_changes})

# ---------- CAC ----------
cac = rows("""SELECT okno, jednostka, koszt, pacjenci_lnd, pacjenci_first, pacjenci_last, cac_lnd, cac_first, cac_last,
                     marza_na_pacjenta, powrot_pct, marza_minus_cac, marza_do_cac
              FROM cac_table WHERE pacjenci_lnd >= 30 OR koszt > 0 ORDER BY okno, koszt DESC, pacjenci_lnd DESC""")
cac_groups = rows("""
    SELECT okno,
           CASE WHEN jednostka LIKE '%meta_prosp_l4_szybko%' OR jednostka LIKE '%tt_prosp_l4_15min%' THEN 'kampanie L4 (Meta, TikTok)'
                WHEN koszt > 0 THEN 'pozostałe płatne' ELSE 'bezpłatne' END AS grupa,
           sum(koszt) AS koszt, sum(pacjenci_lnd) AS pacjenci,
           round(sum(koszt) / sum(pacjenci_lnd), 2) AS cac,
           round(sum(marza_na_pacjenta * pacjenci_lnd) / sum(pacjenci_lnd), 2) AS marza_na_pacjenta
    FROM cac_table GROUP BY 1, 2 ORDER BY 1, 2""")
cac_windows = rows("SELECT okno, od, do_ AS \"do\" FROM cac_windows ORDER BY okno")
dump("cac.json", {"okna": cac_windows, "jednostki": cac, "grupy": cac_groups})

# ---------- meta ----------
dump("meta.json", {"zbudowano": datetime.now().isoformat(timespec="minutes"),
                   "okres": {"od": days[0], "do": days[-1]}})

# ---------- treści (jedno źródło prawdy: docs/) ----------
CONTENT.mkdir(parents=True, exist_ok=True)
for name in ("priorytety.md", "nierozstrzygniete.md", "decisions.md"):
    shutil.copyfile(ROOT / "docs" / name, CONTENT / name)
    print("kopia", name)
