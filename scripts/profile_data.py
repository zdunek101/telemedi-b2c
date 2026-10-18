"""Profil surowych plików CSV z data/ -> docs/data_quality.md.

Tylko opis danych: wiersze, kolumny i typy, zakresy dat, puste wartości, powtórzenia kluczy.
Bez konwersji stref czasowych i bez powiązań między tabelami (to krok audytu).

Uruchomienie z katalogu głównego repozytorium:
    .venv/Scripts/python.exe scripts/profile_data.py
"""

from datetime import datetime
from pathlib import Path

import duckdb

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / "data"
OUT = ROOT / "docs" / "data_quality.md"

EXPECTED_TOTAL = 1_082_369

# Liczby wierszy z tabeli w docs/zadanie.md
EXPECTED_ROWS = {
    "users.csv": 52_422,
    "sessions_2024q4.csv": 38_490,
    "sessions_2025q1.csv": 46_524,
    "sessions_2025q2.csv": 40_384,
    "sessions_2025q3.csv": 37_511,
    "sessions_2025q4.csv": 52_797,
    "sessions_2026q1.csv": 80_728,
    "sessions_2026q2.csv": 84_383,
    "sessions_2026q3.csv": 78_740,
    "events_2024h2.csv": 39_510,
    "events_2025h1.csv": 101_513,
    "events_2025h2.csv": 109_052,
    "events_2026h1.csv": 168_991,
    "events_2026h2.csv": 75_539,
    "orders.csv": 65_882,
    "go_memberships.csv": 4_227,
    "marketing_spend.csv": 5_676,
}

# Tabela -> pliki, klucz, kolumny kluczowe (puste), kolumny czasowe, dodatkowe sprawdzenia powtórzeń
TABLES = {
    "users": {
        "files": ["users.csv"],
        "key": ["user_id"],
        "key_cols": ["user_id", "registered_at"],
        "time_cols": ["registered_at"],
        "tz": "polski",
    },
    "sessions": {
        "files": sorted(p.name for p in DATA.glob("sessions_*.csv")),
        "key": ["session_id"],
        "key_cols": ["session_id", "visitor_id", "user_id", "started_at_utc"],
        "time_cols": ["started_at_utc"],
        "tz": "UTC",
    },
    "events": {
        "files": sorted(p.name for p in DATA.glob("events_*.csv")),
        "key": None,  # brak własnego klucza
        "extra_dup": [["session_id", "event_name"]],
        "key_cols": ["session_id", "event_name", "event_at_utc"],
        "time_cols": ["event_at_utc"],
        "tz": "UTC",
    },
    "orders": {
        "files": ["orders.csv"],
        "key": ["order_id"],
        "key_cols": ["order_id", "user_id", "session_id", "created_at", "status", "amount_paid"],
        "time_cols": ["created_at", "scheduled_at", "started_at"],
        "tz": "polski",
    },
    "go_memberships": {
        "files": ["go_memberships.csv"],
        "key": ["membership_id"],
        "key_cols": ["membership_id", "user_id", "purchased_at", "valid_until", "session_id"],
        "time_cols": ["purchased_at", "valid_until"],
        "tz": "polski",
    },
    "marketing_spend": {
        "files": ["marketing_spend.csv"],
        "key": ["date", "utm_source", "utm_medium", "utm_campaign"],
        "key_cols": ["date", "utm_source", "utm_medium", "utm_campaign", "spend_pln"],
        "time_cols": ["date"],
        "tz": "polski (data)",
    },
}

con = duckdb.connect()  # w pamięci, bez pliku bazy


def q(sql):
    return con.execute(sql).fetchall()


def fmt(n):
    return f"{n:,}".replace(",", " ") if isinstance(n, int) else str(n)


def csv_src(files):
    lst = ", ".join(f"'{(DATA / f).as_posix()}'" for f in files)
    return f"read_csv([{lst}], header=true, sample_size=-1)"


def describe(src):
    return [(r[0], r[1]) for r in q(f"DESCRIBE SELECT * FROM {src}")]


lines = []
w = lines.append
w("# Profil danych (data quality)")
w("")
w(f"Wygenerowane przez `scripts/profile_data.py` ({datetime.now():%Y-%m-%d %H:%M}), DuckDB {duckdb.__version__}.")
w("Czasy podane w strefie źródłowej, bez konwersji. Typy wykryte automatycznie przez DuckDB (próbka = cały plik).")
w("Puste = NULL po wczytaniu (DuckDB traktuje pusty łańcuch w CSV jako NULL).")
w("")

# ---------- Pliki ----------
w("## Pliki")
w("")
w("| plik | wiersze | wg zadania | różnica |")
w("|---|--:|--:|--:|")
file_rows = {}
for f in sorted(EXPECTED_ROWS):
    n = q(f"SELECT count(*) FROM {csv_src([f])}")[0][0]
    file_rows[f] = n
    exp = EXPECTED_ROWS[f]
    w(f"| {f} | {fmt(n)} | {fmt(exp)} | {fmt(n - exp)} |")
total = sum(file_rows.values())
w(f"| **razem** | **{fmt(total)}** | **{fmt(EXPECTED_TOTAL)}** | **{fmt(total - EXPECTED_TOTAL)}** |")
w("")
extra = sorted(p.name for p in DATA.glob("*.csv") if p.name not in EXPECTED_ROWS)
w(f"Pliki CSV spoza listy z zadania: {', '.join(extra) if extra else 'brak'}.")
w("")

# ---------- Grupy plików ----------
w("## Grupy plików: zgodność układu kolumn")
w("")
for t in ("sessions", "events"):
    files = TABLES[t]["files"]
    schemas = {f: describe(csv_src([f])) for f in files}
    ref_names = [c for c, _ in schemas[files[0]]]
    w(f"### {t} ({len(files)} plików)")
    w("")
    w(f"Kolumny wzorcowe ({files[0]}): `{', '.join(ref_names)}`")
    w("")
    tcol = TABLES[t]["time_cols"][0]
    w(f"| plik | kolumny jak wzorzec | typy różne od wzorca | wiersze | min {tcol} | max {tcol} |")
    w("|---|---|---|--:|---|---|")
    for f in files:
        names = [c for c, _ in schemas[f]]
        same = "tak" if names == ref_names else f"**NIE**: {', '.join(names)}"
        diff_types = [f"{c}: {ty} (wzorzec {dict(schemas[files[0]]).get(c)})"
                      for c, ty in schemas[f] if dict(schemas[files[0]]).get(c) != ty]
        mn, mx = q(f"SELECT min({tcol}), max({tcol}) FROM {csv_src([f])}")[0]
        w(f"| {f} | {same} | {'; '.join(diff_types) or '—'} | {fmt(file_rows[f])} | {mn} | {mx} |")
    w("")

# ---------- Tabele ----------
w("## Tabele")
for t, cfg in TABLES.items():
    src = csv_src(cfg["files"])
    con.execute(f"CREATE OR REPLACE TEMP TABLE {t} AS SELECT * FROM {src}")
    n = q(f"SELECT count(*) FROM {t}")[0][0]
    cols = describe(t)
    w("")
    w(f"### {t}")
    w("")
    w(f"Pliki: {', '.join(cfg['files'])}. Wiersze: **{fmt(n)}**. Czas: {cfg['tz']}.")
    w("")

    # kolumny, typy, puste, unikalne
    w("| kolumna | typ | puste | % pustych | unikalne |")
    w("|---|---|--:|--:|--:|")
    for c, ty in cols:
        nulls, distinct = q(f'SELECT count(*) - count("{c}"), count(DISTINCT "{c}") FROM {t}')[0]
        mark = " (kluczowa)" if c in cfg["key_cols"] else ""
        w(f"| `{c}`{mark} | {ty} | {fmt(nulls)} | {100 * nulls / n:.2f} | {fmt(distinct)} |")
    w("")
    missing = [c for c in cfg["key_cols"] + cfg["time_cols"] if c not in dict(cols)]
    if missing:
        w(f"**Brak oczekiwanych kolumn:** {', '.join(missing)}")
        w("")

    # zakresy dat
    w("| kolumna czasowa | typ | min | max | niepuste nieparsowalne jako czas |")
    w("|---|---|---|---|--:|")
    for c in cfg["time_cols"]:
        ty = dict(cols).get(c)
        mn, mx = q(f'SELECT min("{c}"), max("{c}") FROM {t}')[0]
        bad = q(f'SELECT count(*) FROM {t} WHERE "{c}" IS NOT NULL '
                f'AND TRY_CAST("{c}" AS TIMESTAMP) IS NULL')[0][0]
        w(f"| `{c}` | {ty} | {mn} | {mx} | {fmt(bad)} |")
    w("")

    # powtórzenia
    full_dup = q(f"SELECT count(*) - (SELECT count(*) FROM (SELECT DISTINCT * FROM {t})) FROM {t}")[0][0]
    w(f"- Wiersze będące pełnym duplikatem innego wiersza (nadmiarowe kopie): **{fmt(full_dup)}**")
    checks = ([cfg["key"]] if cfg["key"] else []) + cfg.get("extra_dup", [])
    for key in checks:
        k = ", ".join(f'"{c}"' for c in key)
        dup_vals, dup_rows = q(f"SELECT count(*), coalesce(sum(c), 0) FROM "
                               f"(SELECT count(*) c FROM {t} GROUP BY {k} HAVING count(*) > 1)")[0]
        label = "klucz" if key == cfg["key"] else "kombinacja"
        w(f"- {label} ({', '.join(key)}): wartości występujące więcej niż raz: **{fmt(dup_vals)}**, "
          f"w nich wierszy: **{fmt(int(dup_rows))}**")
    if not cfg["key"]:
        w("- Tabela nie ma własnego klucza.")

w("")

# Sekcja pisana ręcznie (od znacznika do końca) przetrwa ponowne uruchomienie skryptu.
MANUAL_MARKER = "## Wygląda podejrzanie"
manual = ""
if OUT.exists():
    old = OUT.read_text(encoding="utf-8")
    if MANUAL_MARKER in old:
        manual = old[old.index(MANUAL_MARKER):]
OUT.write_text("\n".join(lines) + "\n" + manual, encoding="utf-8", newline="\n")
print(f"Zapisano {OUT.relative_to(ROOT)}; wierszy razem: {total} (oczekiwane {EXPECTED_TOTAL})")
