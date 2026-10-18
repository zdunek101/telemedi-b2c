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
    print(f"== {path}")
    for stmt in statements:
        rel = con.sql(stmt.query)
        if rel is not None and stmt.type == duckdb.StatementType.SELECT:
            # pierwsza linia komentarza nad zapytaniem jako nagłówek wyniku
            head = next((l.strip() for l in stmt.query.strip().splitlines() if l.strip().startswith("--")), "")
            if head:
                print(head)
            rel.show(max_rows=1000, max_width=10000)
