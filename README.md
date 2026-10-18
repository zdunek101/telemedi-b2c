# Telemedi B2C — 24 miesiące

> Szkic. Sekcje oznaczone *(do uzupełnienia)* uzupełnimy w trakcie pracy.

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
| `scripts/` | skrypty pomocnicze *(do uzupełnienia)* |
| `tool/` | narzędzie z kohortami i lejkami; zawiera wyłącznie agregaty |
| `CLAUDE.md` | zasady pracy z AI w tym projekcie |

## Jak uruchomić *(do uzupełnienia)*

1. Pobierz paczkę `telemedi-b2c-dane.zip` (link w [docs/zadanie.md](docs/zadanie.md))
   i rozpakuj pliki CSV do `data/`.
2. Załaduj dane do DuckDB *(skrypt i polecenie do uzupełnienia)*.
3. Wygeneruj agregaty do narzędzia *(do uzupełnienia)*.
4. Otwórz narzędzie *(link i sposób uruchomienia do uzupełnienia)*.
