# Telemedi B2C — zadanie rekrutacyjne

Treść zadania: `docs/zadanie.md`. Słownik danych: `docs/dane_readme.md`.
Założenia i otwarte pytania: `docs/decisions.md`.

## Zasady pracy

- Znasz całe zadanie, ale robisz tylko to, o co proszę w danym kroku.
  Nie wybiegasz do kolejnych etapów i nie rozbudowujesz zakresu na własną rękę.
- Przy większym kroku najpierw przedstawiasz plan. Kod piszesz dopiero po mojej akceptacji.
- Definicje (kohorta, lejek, przypisanie źródła, powrót i każda nowa) ustalam ja.
  Pokazujesz warianty z konsekwencjami, nie wybierasz za mnie.
  Przyjętą definicję zapisujesz w `docs/decisions.md`.
- Każda metryka ma podany licznik i mianownik, nie tylko wynik w procentach.
- Przy każdym filtrze podajesz liczbę wierszy przed i po.
- Przy dziwnych wynikach (100%, 0, nagły skok, niezgodne sumy) najpierw je weryfikujesz
  i informujesz mnie, co wyszło. Dalej idziemy dopiero potem.
- Jak czegoś nie wiesz albo czegoś nie sprawdziłeś, mówisz to wprost.
  Nie zgadujesz i nie przedstawiasz przypuszczeń jako faktów.

## Dane i kod

- Analiza w DuckDB SQL. Zapytania trzymamy w `sql/`.
- Do narzędzia (`tool/`) trafiają wyłącznie agregaty, nigdy dane na poziomie
  pacjenta, sesji ani zamówienia.
- Surowe pliki w `data/` są tylko do odczytu i nie trafiają do gita
  (`data/*.csv` oraz pliki bazy są w `.gitignore`).
- Czas: wszystko w Europe/Warsaw, dzień = dzień polski (założenie A4).
