# Telemedi B2C — 24 miesiące

## Cel

Zadanie rekrutacyjne Telemedi: sprawdzić, czy wzrost widoczny na dashboardzie B2C
(X 2025 – IX 2026 wobec X 2024 – IX 2025) jest prawdziwym wzrostem, czyli czy rośnie
liczba pacjentów i ich retencja.

Do oddania:
- działające narzędzie z kohortami (rozdzielczość dzienna) i lejkami, otwierane z linku,
- lista priorytetów z wartością, sposobem pomiaru i czasem wdrożenia,
- lista tego, czego dane nie rozstrzygają,
- ślad pracy (to repozytorium).

Pełna treść: [docs/zadanie.md](docs/zadanie.md).

## Struktura

| Folder / plik | Zawartość |
|---|---|
| `data/` | surowe dane od Telemedi (CSV nie są w repozytorium) i `README.md` ze słownikiem |
| `docs/` | treść zadania, słownik danych, założenia i otwarte pytania (`decisions.md`) |
| `sql/` | zapytania DuckDB SQL |
| `scripts/` | `profile_data.py` (profil danych), `run_sql.py` (uruchamianie SQL), `build_tool_data.py` (dane narzędzia) |
| `tool/` | narzędzie z kohortami i lejkami; zawiera wyłącznie agregaty |
| `CLAUDE.md` | zasady pracy z AI w tym projekcie |

## Jak uruchomić

1. Pobierz paczkę `telemedi-b2c-dane.zip` (link w [docs/zadanie.md](docs/zadanie.md)) i rozpakuj pliki CSV do `data/`.
2. Środowisko: `py -3.13 -m venv .venv` i `.venv/Scripts/python.exe -m pip install duckdb`.
3. Dane dla narzędzia (uruchamia SQL z `sql/`, zapisuje agregaty JSON do `tool/data/` i kopiuje treści z `docs/` do `tool/content/`):
   `.venv/Scripts/python.exe scripts/build_tool_data.py`
4. Narzędzie lokalnie: `py -m http.server 8765 --directory tool` i http://localhost:8765.
5. Publikacja: GitHub Pages przez workflow `.github/workflows/pages.yml` (publikuje folder `tool/` po pushu do `main`;
   w ustawieniach repozytorium Pages → Source: GitHub Actions).

Pojedyncze pliki SQL: `.venv/Scripts/python.exe scripts/run_sql.py sql/00_raw_views.sql sql/03_audit_base.sql ...`
(zależności każdego pliku są opisane w jego nagłówku).
