# Rozbicie zdarzeń w kroku termin → konto

SQL: `sql/14_funnel_drilldown.sql`. Okna jak w wykrywaniu: 28 dni przed i 28 dni od dnia zdarzenia. Mianownik: sesje, które doszły do wyboru terminu.

## Uwaga o danych: kto „wchodzi zalogowany”

Każda sesja z płatnością (63 207) ma zdarzenie `account_completed`, także u osób z istniejącym kontem (D6):

| `user_id` w sesji | `account_completed` | sesje | z terminem | z płatnością |
|---|---|--:|--:|--:|
| nie | nie | 354 726 | 31 066 | 0 |
| tak | nie | 22 754 | 112 | 0 |
| tak | tak | 79 984 | 79 984 | 63 207 |

- Sesje „zalogowane bez `account_completed`”, o których pisze README, prawie nie wybierają terminu (112) i nigdy nie płacą.
- W lejku definicja konta „`account_completed` albo `user_id`” daje więc prawie to samo co samo `account_completed`. Różnica to 112 sesji.
- Dlatego podziału „zalogowany na wejściu” nie da się użyć. Zamiast niego:
  - **nowy odwiedzający** albo **znany**: jego `visitor_id` miał wcześniej sesję z kontem,
  - **rejestracja** albo **logowanie**: konto założone w tej sesji albo wcześniej.

## Z1: 17.03.2026, Safari

| przekrój | termin przed | konto przed | F3 przed | termin po | konto po | F3 po |
|---|--:|--:|--:|--:|--:|--:|
| **cały Safari** | 1 277 | 953 | 74,6% | 1 252 | 772 | 61,7% |
| mobile, iOS | 1 018 | 766 | 75,2% | 1 025 | 609 | **59,4%** |
| desktop, macOS | 187 | 136 | 72,7% | 166 | 122 | 73,5% |
| tablet, iOS | 72 | 51 | 70,8% | 61 | 41 | 67,2% |
| nowy odwiedzający | 967 | 644 | 66,6% | 961 | 482 | **50,2%** |
| znany (konto wcześniej) | 310 | 309 | 99,7% | 291 | 290 | 99,7% |

- **Gdzie.** Spadek dotyczy Safari na iPhonie. Safari na Macu się nie zmienia.
- **Inne przeglądarki na iOS** w tych samych miesiącach: 65–69% przed, 62–65% po, czyli lekki spadek, bez skoku (D8).
- **Kogo.** Tracimy tylko nowych odwiedzających. Znani przechodzą krok w 99,7% przed i po.
- **Rejestracja czy logowanie.** Wśród niezalogowanych, którzy przeszli krok: rejestracje 587 → 423 (−28%), logowania 365 → 348 (−5%). **Psuje się zakładanie konta.**
- **Tracking czy realny spadek.** Spadek jest realny. Sesje z zamówieniem w tabeli `orders` to dokładnie tyle samo co sesje z `payment_succeeded`: 774 → 631. Zamówienia na sesję z terminem spadają z 60,61% do 50,40%. Nie ma zamówień bez kroku konto, więc zdarzenie nie gubi się przy realnym przejściu.
- **W transakcjach nowych pacjentów (D10).**
  - Pierwsze opłacone zamówienia nowych pacjentów (Q1 a2) z sesji Safari na iPhonie: 374 w 28 dniach przed, 254 w 28 dniach po (−32%).
  - Sesje nowych odwiedzających z wybranym terminem: 769 przed i 788 po. Z opłaconym zamówieniem: 404 (52,54%) przed i 293 (37,18%) po.
- **Czy trwa.** Tak, do końca danych. F3 dla Safari na iPhonie miesięcznie:

| | IX 25 | X | XI | XII | I 26 | II | III | IV | V | VI | VII | VIII | IX |
|---|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|
| sesje z terminem | 692 | 767 | 861 | 971 | 1 108 | 1 019 | 1 137 | 1 051 | 927 | 918 | 875 | 822 | 867 |
| F3 | 78,0% | 73,9% | 76,1% | 74,6% | 74,5% | 73,1% | 68,5% | 58,9% | 63,0% | 59,0% | 59,9% | 59,5% | 59,6% |

- **Ile tracimy** (Safari na iPhonie, D9). Od 17.03 do 30.09 (198 dni) było 6 013 sesji z terminem i 2 890 zamówień, czyli 48,06%. Przy poziomie z 28 dni przed zdarzeniem (60,51%, 1 018 sesji) byłoby ok. 3 639 zamówień.
  - **Utracone: ok. 749 zamówień, czyli ok. 115 miesięcznie.**
  - Przy średnim netto 86,26 zł na zamówienie to ok. 64,6 tys. zł przychodu netto, czyli **ok. 9,9 tys. zł miesięcznie**.
  - Nie wliczam późniejszych zamówień tych pacjentów (powrót), więc to dolna granica.
  - Estymata zakłada, że bez zmiany zostałby poziom sprzed 17.03. Sezonu tu nie odejmuję.
- **Czego nie wiem.** W danych nie ma wersji systemu, aplikacji ani listy wdrożeń, więc przyczyny (np. aktualizacja iOS albo zmiana formularza rejestracji) nie da się ustalić. Do sprawdzenia: wdrożenia z okolic 17.03.2026 i logi błędów formularza rejestracji w mobilnym Safari.

## Z2: 11.07.2025, przeglądarki w aplikacji (Instagram, Facebook)

| przekrój | termin przed | konto przed | F3 przed | termin po | konto po | F3 po |
|---|--:|--:|--:|--:|--:|--:|
| **całość** | 162 | 118 | 72,8% | 136 | 70 | 51,5% |
| mobile, Android | 100 | 69 | 69,0% | 86 | 46 | 53,5% |
| mobile, iOS | 60 | 47 | 78,3% | 46 | 22 | 47,8% |
| Instagram | 102 | 74 | 72,5% | 79 | 44 | 55,7% |
| Facebook | 60 | 44 | 73,3% | 57 | 26 | 45,6% |
| nowy odwiedzający | 135 | 91 | 67,4% | 123 | 57 | 46,3% |
| znany (konto wcześniej) | 27 | 27 | 100% | 13 | 13 | 100% |

Tablety pominięte (1–3 sesje).

- **Tracking czy realny spadek.** Spadek jest realny: zamówienia = płatności w zdarzeniach, 88 → 53 (54,32% → 38,97% sesji z terminem).
- **Ale to raczej powrót z chwilowego szczytu niż trwała zmiana.** F3 miesięcznie:

| | X 24 | XI | XII | I 25 | II | III | IV | V | **VI** | VII | VIII | IX | X |
|---|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|
| sesje z terminem | 144 | 126 | 157 | 152 | 143 | 157 | 155 | 169 | 171 | 166 | 155 | 165 | 163 |
| F3 | 57,6% | 55,6% | 58,0% | 55,9% | 56,6% | 61,1% | 65,8% | 63,3% | **70,2%** | 57,8% | 58,7% | 64,2% | 64,4% |

  - Okno „przed” (14.06–10.07.2025) przypada na najlepszy miesiąc w historii segmentu.
  - Lipiec i sierpień wracają do poziomu z X 2024 – V 2025, a od IX 2025 przez cały P2 F3 wynosi ok. 59–64%.
  - Wykrycie spełniło kryterium trwałości tylko dlatego, że sierpień był niżej niż czerwiec.
- **Skala.** Ok. 150–170 sesji z terminem miesięcznie, więc dzienne wahania są duże.
- **Ile tracimy.** Względem czerwcowego szczytu ok. 23 zamówienia miesięcznie (ok. 2,0 tys. zł netto). Względem zwykłego poziomu segmentu przed szczytem: w praktyce nic. Nie traktowałbym tego jako straty, tylko jako dowód, że w czerwcu 2025 coś na krótko działało lepiej. Danych do sprawdzenia, co to było, nie ma.
