# Telemedi B2C — 24 miesiące

**Narzędzie:** https://zdunek101.github.io/telemedi-b2c/

## Co to jest

Rozwiązanie zadania rekrutacyjnego Telemedi B2C ([docs/zadanie.md](docs/zadanie.md)). Pytanie: czy wzrost z dashboardu (X 2025 – IX 2026 wobec X 2024 – IX 2025) to prawdziwy wzrost, czyli więcej pacjentów i lepsza retencja.

Repozytorium zawiera:
- **narzędzie** (`tool/`): statyczna strona z kohortami dziennymi, lejkiem, CAC, priorytetami i listą niewiadomych, otwierana z linku bez konta,
- **analizę** w DuckDB SQL (`sql/`) z opisami wyników (`docs/`),
- **ślad pracy**: historię commitów, decyzje definicyjne ([docs/decisions.md](docs/decisions.md)), zasady pracy z AI ([CLAUDE.md](CLAUDE.md)) i podsumowanie przebiegu ([docs/przebieg.md](docs/przebieg.md)).

Eksport rozmowy z AI jest w załączniku maila (zawiera dane osobowe, dlatego nie ma go w repo).

**Odpowiedź w skrócie: tylko częściowo.**
- Po oczyszczeniu danych zamówienia rosną o +55,7% zamiast +60,7%, a przychód netto o +44,8% zamiast +50,3%.
- Nowych pacjentów bez kanałów płatnych przybywa tylko o +17,7% (zakres +12,7% do +25,4%).
- Powrót w 90 dni spada z ok. 24% do ok. 15% w kohortach z wiosny 2026.
- Szczegóły: zakładka „Czy wzrost jest prawdziwy” w narzędziu i [docs/most.md](docs/most.md).

## Co gdzie leży

| Ścieżka | Zawartość |
|---|---|
| `data/` | surowe dane od Telemedi: CSV poza repozytorium (`.gitignore`), w repo tylko `README.md` ze słownikiem |
| `tool/` | narzędzie: `index.html`, `app.js`, `style.css`; `data/*.json` (agregaty dla strony), `data/*.csv` (agregaty dzienne), `content/*.md` (kopie priorytetów, niewiadomych i decyzji z `docs/`) |
| `sql/` | zapytania DuckDB; każdy plik ma w nagłówku opis i zależności |
| `scripts/` | `profile_data.py` (profil plików), `run_sql.py` (uruchamianie SQL), `build_tool_data.py` (dane dla narzędzia) |
| `docs/` | opisy wyników i decyzje (lista niżej) |
| `.github/workflows/pages.yml` | publikacja folderu `tool/` na GitHub Pages |
| `CLAUDE.md` | zasady pracy z AI w tym projekcie |

**Dokumenty w `docs/`:**

| Plik | Co zawiera |
|---|---|
| [zadanie.md](docs/zadanie.md), [dane_readme.md](docs/dane_readme.md) | treść zadania i słownik danych |
| [decisions.md](docs/decisions.md) | założenia A1–A14 i decyzje definicyjne Q1–Q4 (kohorta, lejek, przypisanie źródła, powrót) |
| [data_quality.md](docs/data_quality.md) | profil 17 plików CSV |
| [most.md](docs/most.md) | most od liczb z dashboardu do realnych |
| [audit.md](docs/audit.md) | audyt 8 hipotez, co zawyża liczby |
| [cohorts.md](docs/cohorts.md) | kohorty dzienne: definicje, kontrole, ręczna weryfikacja |
| [events.md](docs/events.md) | wykrywanie trwałych zmian (okna 28/28 dni, placebo, kalendarz) |
| [mix.md](docs/mix.md) | spadek powrotu i marży: mieszanka czy zmiana wewnątrz źródeł |
| [funnel_drilldown.md](docs/funnel_drilldown.md) | rozbicie zdarzeń lejka (Safari na iPhonie, przeglądarki w aplikacjach) |
| [return_drivers.md](docs/return_drivers.md) | powrót a czekanie na lekarza i zwroty |
| [capacity.md](docs/capacity.md) | czekanie a obciążenie lekarzy |
| [cac.md](docs/cac.md) | CAC na kanał i kampanię obok marży 90 i 180 dni |
| [priorytety.md](docs/priorytety.md) | lista priorytetów: wartość, pomiar, czas wdrożenia |
| [nierozstrzygniete.md](docs/nierozstrzygniete.md) | czego dane nie rozstrzygają (N1–N6) i co by to domknęło |
| [przebieg.md](docs/przebieg.md) | podsumowanie przebiegu pracy (wygenerowane przez AI z historii repo) |

**Pliki w `sql/`:**

| Plik | Co liczy |
|---|---|
| `00_raw_views.sql` | widoki na surowe CSV |
| `01_dashboard_reproduction.sql` | odtworzenie 4 KPI z dashboardu w wariantach definicji |
| `02_most.sql` | most od dashboardu do liczb realnych |
| `03_audit_base.sql` | baza analizy: deduplikacja (A8), bez kont testowych (A11), czas polski |
| `04`–`08_audit_*.sql` | audyt hipotez H1–H8 i ich wpływ na KPI |
| `09_definition_variants.sql` | warianty definicji Q1, Q3, Q4 |
| `10_cohorts_daily.sql` | kohorty dzienne, kontrole, ręczna weryfikacja pacjentów |
| `11_daily_series.sql` | szeregi dzienne w segmentach |
| `12_change_points.sql`, `12b`–`12e` | wykrywanie zdarzeń, placebo, czułość, rok do roku, lista zdarzeń |
| `13_mix_by_source.sql` | mieszanka źródeł i kampanii |
| `14_funnel_drilldown.sql` | rozbicie zdarzeń w kroku termin → konto |
| `15_return_wait_refund.sql` | powrót a czekanie i zwroty |
| `16_capacity.sql` | czekanie a wizyty na godzinę |
| `17_cac.sql` | CAC na kanał i kampanię |
| `18_priorities.sql` | liczby do listy priorytetów |

## Jak odtworzyć wszystko od zera

Wymagania: Windows z Pythonem 3.13 (`py`) albo inny system z Pythonem 3.11+ (wtedy `python` zamiast `py` i `.venv/bin/python` zamiast `.venv/Scripts/python.exe`).

1. **Dane.** Pobierz `telemedi-b2c-dane.zip` (link w [docs/zadanie.md](docs/zadanie.md)) i rozpakuj 17 plików CSV do `data/`.
2. **Środowisko:**
   ```
   py -3.13 -m venv .venv
   .venv/Scripts/python.exe -m pip install duckdb
   ```
   Użyta wersja: DuckDB 1.5.6.
3. **Profil danych** (opcjonalnie, odtwarza [docs/data_quality.md](docs/data_quality.md)):
   ```
   .venv/Scripts/python.exe scripts/profile_data.py
   ```
4. **Dane dla narzędzia.** Uruchamia potrzebne pliki SQL w jednej sesji DuckDB w pamięci, zapisuje agregaty do `tool/data/` i kopiuje treści z `docs/` do `tool/content/`. Trwa ok. 10 s.
   ```
   .venv/Scripts/python.exe scripts/build_tool_data.py
   ```
5. **Narzędzie lokalnie:**
   ```
   py -m http.server 8765 --directory tool
   ```
   Potem otwórz http://localhost:8765.
6. **Pojedyncze analizy.** Każdy plik SQL ma w nagłówku listę plików, których wymaga. Przykład dla CAC:
   ```
   .venv/Scripts/python.exe scripts/run_sql.py sql/00_raw_views.sql sql/03_audit_base.sql sql/06_audit_h4.sql sql/10_cohorts_daily.sql sql/11_daily_series.sql sql/13_mix_by_source.sql sql/17_cac.sql
   ```
   Skrypt wypisuje wynik każdego zapytania SELECT. Pliki `sql/10`–`sql/12` zapisują też agregaty CSV do `tool/data/`.
7. **Publikacja.** Po pushu do gałęzi `main` workflow `.github/workflows/pages.yml` publikuje folder `tool/`. W ustawieniach repozytorium ustaw Pages → Source: GitHub Actions. Dane JSON trzeba zbudować lokalnie (krok 4) i zacommitować, bo surowych CSV nie ma w repozytorium.

Wyniki są powtarzalne: kwoty sumowane są jako DECIMAL, a dwa kolejne przebiegi dają identyczne pliki w `tool/data/`.
