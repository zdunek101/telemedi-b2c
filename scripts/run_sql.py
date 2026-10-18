"""Uruchamia pliki SQL w DuckDB (w pamięci) i wypisuje wynik ostatniego zapytania z każdego pliku.

    .venv/Scripts/python.exe scripts/run_sql.py sql/00_raw_views.sql sql/01_dashboard_reproduction.sql
"""

import os
import sys
from pathlib import Path

import duckdb

ROOT = Path(__file__).resolve().parent.parent
os.chdir(ROOT)  # ścieżki do data/ w SQL są względne

con = duckdb.connect()
for path in sys.argv[1:]:
    statements = con.extract_statements(Path(path).read_text(encoding="utf-8"))
    for i, stmt in enumerate(statements):
        rel = con.sql(stmt.query)
        if i == len(statements) - 1 and rel is not None:
            print(f"== {path}")
            rel.show(max_rows=1000, max_width=10000)
