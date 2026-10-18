# Audyt: co jeszcze może zawyżać liczby

Okresy: **P1** = X 2024 – IX 2025, **P2** = X 2025 – IX 2026, czas polski (A4), zamówienia po `created_at` (A10).
Baza: **po deduplikacji (A8) i bez kont testowych (A11)**. Nowi pacjenci liczeni według definicji dashboardu (Q1 a).
Niczego nie usunięto z plików. Wpływ każdej hipotezy liczony jest **osobno**: wzrost KPI po wyłączeniu oznaczonych wierszy minus wzrost w bazie.

| KPI w bazie | P1 | P2 | wzrost |
|---|--:|--:|--:|
| zamówienia | 24 716 | 38 491 | +55,7% |
| przychód z konsultacji (brutto) | 2 374 727,60 zł | 3 508 197,60 zł | +47,7% |
| nowi pacjenci | 16 231 | 24 687 | +52,1% |
| sprzedane GO | 1 759 | 2 468 | +40,3% |

Wykluczenie A11 (`sql/03_audit_base.sql`, wiersze przed → po):

| tabela | przed | po |
|---|--:|--:|
| orders | 65 278 | 63 207 |
| users | 52 422 | 52 400 |
| go_memberships | 4 227 | 4 227 |
| sessions | 459 557 | 457 464 |
| events | 494 605 | 484 228 |

Sesje usuwamy po `visitor_id` kont testowych (22 przeglądarki), zdarzenia po sesjach.

SQL: `sql/03_audit_base.sql` (baza), `04` (H1, H2), `05` (H3, H6), `06` (H4), `07` (H5, H7, H8), `08` (wpływ i pokrycie).
Uruchomienie: `.venv/Scripts/python.exe scripts/run_sql.py sql/00_raw_views.sql sql/03_audit_base.sql sql/06_audit_h4.sql sql/08_audit_impact.sql`.

> Historia: pierwsza wersja audytu była liczona razem z kontami testowymi. Zawierała też błąd w H1: 290 zamówień kont testowych opisałem jako `completed`, a mają status `refunded`. Ten błąd zawyżył wzrost zwrotów przy czacie w H3. Obecna wersja jest przeliczona na bazie A8 + A11. Poprzednia jest w historii gita (commit `29206ef`).

## Podsumowanie

| # | hipoteza | wynik | skala P1 → P2 | wpływ na wzrost KPI |
|---|---|---|---|---|
| H1 | konta testowe / wewnętrzne | **potwierdzona → wykluczone (A11)** | 22 konta, 553 → 1 518 zamówień | zamówienia −2,6 pp, przychód −0,4 pp, nowi +0,2 pp, GO 0 (`docs/most.md`, krok 2) |
| H2 | dziwne kwoty / kody | kwoty w porządku; **dwa nowe kody w P2** | `L4SZYBKO20` + `TIKTOK25`: 0 → 5 176 zamówień (wszystkie to pierwsze zamówienia) | bez nich: zamówienia −20,9 pp, przychód −16,2 pp, nowi −31,9 pp |
| H3 | wzrost zwrotów | **potwierdzona, rosną tylko `refunded`** | `refunded` 492 → 1 626 (1,99% → 4,22% zamówień) | przychód netto: −3,0 pp od `refunded`, +0,2 pp od `cancelled` |
| H4 | wzrost kupiony reklamą | **w dużej części tak** (zależnie od przypisania) | wydatki za klik 367 632 → 649 675 zł (+76,7%) | nowi bez kanałów płatnych: −26,6 pp (last) / −34,3 pp (lnd) / −39,5 pp (first) |
| H5 | sesje bez zdarzeń = boty | **botów nie znaleziono** | sesje bez zdarzeń 61–68% miesięcznie | KPI 0; konwersja sesja → płatność 15,36% → 13,20% |
| H6 | rabat GO bez członkostwa | **odrzucona** | 0 z 9 738 zamówień z rabatem GO | 0 |
| H7 | jedna osoba, kilka kont | **nie da się wykryć** dostępnym sygnałem (N1) | każdy `visitor_id` ma dokładnie 1 konto | 0 (przy tej metodzie) |
| H8 | anulowanie i ponowne zamówienie | **marginalna** | ponowne zamówienie w 48 h: 2 → 0; pierwsze zamówienie anulowane i nic więcej: 539 → 893 | nowi −0,5 pp, zamówienia −0,2 pp, przychód −0,1 pp |

Pokrycie: 6 184 zamówienia mają jedno oznaczenie (H2, H8), 212 mają dwa. Nowi pacjenci z H2 i H4 w dużej części się pokrywają: z 5 176 pierwszych zamówień z nowymi kodami 4 213 ma sesję płatności z kanału płatnego (last). Wpływów H2 i H4 **nie wolno sumować**.

## H1. Konta testowe / wewnętrzne — potwierdzona, wykluczone (A11)

Wykrywanie liczone na danych z kontami testowymi (`sql/04_audit_h1_h2.sql`).

- 22 konta użyły kodu `TEST-QA` (88 zł zniżki, kwota 1 zł). Mają razem 2 071 zamówień:
  - 1 781 z `TEST-QA`, wszystkie `completed`, bez zwrotu,
  - 290 bez kodu po 89 zł, wszystkie `refunded` z pełnym zwrotem (25 810 zł; P1 75, P2 215).
- Wspólny profil wszystkich 22: województwo mazowieckie, `marketing_consent = 0`, internista, czat, każda wizyta trwa 1 min.
- To konta z największą liczbą zamówień (48–148 na konto). Poza nimi najaktywniejsi pacjenci mają 10–19 zamówień (273 osoby).
- 21 `visitor_id` z ≥ 50 sesjami (2 044 sesje) należy do tych kont.
- Inne heurystyki nic nie dały:
  - `birth_year` mieści się w 1942–2008,
  - najwięcej rejestracji w jednej minucie to 4,
  - najwięcej zamówień jednego pacjenta jednego dnia to 5 (3 przypadki),
  - nie ma zamówień sprzed rejestracji ani bez konta.
- Skutek dla marży (A1): wszystkie 2 071 wizyt się odbyło, więc koszt lekarza wynosi 2 071 × 25 zł = 51 775 zł. Przychód brutto z tych kont to 27 591 zł, netto 1 781 zł.

## H2. Kwoty i kody rabatowe

- **Kwoty są spójne.** 0 zamówień z kwotą 0 zł, ujemną lub wyższą od ceny katalogowej. 0 niezgodności z regułą rabatu: `none` = cena katalogowa, `go` = 50% u internisty i 20% u pozostałych, `promo` < cena katalogowa.
- **Ceny katalogowe się nie zmieniały.** Każda specjalizacja ma jedną cenę przez cały okres.
- **Kody** (bez kont testowych; `TEST-QA` należał wyłącznie do nich):

| kod | zniżka | zamówienia P1 | P2 | od |
|---|--:|--:|--:|---|
| L4SZYBKO20 | 20 zł | 0 | 3 511 | 2025-11-04 |
| START10 | 10 zł | 1 500 | 1 886 | 2024-10-01 |
| TIKTOK25 | 25 zł | 0 | 1 665 | 2026-02-10 |
| RANKING10 | 10 zł | 300 | 295 | 2024-10-02 |
| WRACAM15 | 15 zł | 148 | 207 | 2024-10-06 |

- `L4SZYBKO20` i `TIKTOK25` występują tylko w P2. Każde ich użycie to pierwsze zamówienie pacjenta. Daty startu zgadzają się z kampaniami `meta_prosp_l4_szybko` (od 2025-11-03) i `tt_prosp_l4_15min` (od 2026-02-09).
- To nie jest błąd danych, tylko źródło wzrostu w P2. Bez tych kodów nowych pacjentów byłoby +20,2% zamiast +52,1%. Te kody mają przy tym najwyższy odsetek `refunded` (H3).

## H3. Zwroty — rosną wyłącznie `refunded`

| | P1 | P2 |
|---|--:|--:|
| `cancelled`: zamówienia / % zamówień | 1 030 / 4,17% | 1 542 / 4,01% |
| `cancelled`: zwroty / % przychodu | 98 577,40 zł / 4,15% | 141 323,40 zł / 4,03% |
| `refunded`: zamówienia / % zamówień | 492 / 1,99% | 1 626 / 4,22% |
| `refunded`: zwroty / % przychodu | 45 883,70 zł / 1,93% | 138 531,80 zł / 3,95% |
| wszystkie zwroty / % przychodu | 144 461,10 zł / 6,08% | 279 855,20 zł / 7,98% |

- **Od kiedy.** Udział `refunded` w zamówieniach wynosi 1,3–2,5% do IX 2025. Potem rośnie: X 2025 2,34%, XII 3,11%, III 2026 4,41%, VI 5,72%, IX 5,77%. Udział zwrotów w przychodzie w IX 2026: 10,2%.
- **W czym.** Z 1 626 zwrotów `refunded` w P2:
  - 730 to kody `L4SZYBKO20` / `TIKTOK25` (w P1: 0). Odsetek `refunded` w tych kodach wynosi 11–15% zależnie od trybu.
  - 561 to L4 u internisty bez tych kodów (w P1: 260). Odsetek dla całego L4 u internisty: 260 / 4 680 = 5,6% → 1 247 / 11 398 = 10,9%.
  - 335 to pozostałe (w P1: 232).
- **Psychiatra L4:** 5,2% → 12,4%, na małej liczbie (379 zamówień w P2). E-recepta u internisty: bez zmian (1,1% → 1,1%). Czat bez rabatu: 2,3% → 2,8%.
- **Opóźnienie lekarza** (`started_at − scheduled_at`, wizyty `completed`): mediana 3,2 → 4,1 min, 90. percentyl 9,7 → 21,0 min. Przy `refunded` 90. percentyl 10,0 → 25,4 min. To związek w czasie, nie dowód przyczyny zwrotów.
- **`cancelled` nie rośnie** i nie zależy od czasu do terminu: ok. 4% przy < 1 h, 1–24 h i > 24 h.

## H4. Wzrost kupiony reklamą

Przypisanie źródła jest otwarte (Q3). Poniżej trzy **prowizoryczne** warianty:
- **last:** UTM sesji pierwszej płatności,
- **first:** UTM najwcześniejszej sesji pacjenta przed pierwszym zamówieniem, szukanej po wszystkich jego `visitor_id`,
- **lnd** (last non-direct): UTM ostatniej sesji z niepustym `utm_source` do momentu pierwszego zamówienia. Jeśli takiej sesji nie ma: direct.

„Płatny” = para source/medium występująca w `marketing_spend` (google/cpc, meta/paid_social, tiktok/paid_social).

| wydatki za klik | P1 | P2 | wzrost |
|---|--:|--:|--:|
| google / cpc | 303 650,18 zł | 332 460,82 zł | +9,5% |
| meta / paid_social | 63 982,07 zł | 234 749,94 zł | +266,9% |
| tiktok / paid_social | 0 zł | 82 464,30 zł | — |
| **razem** | **367 632,25 zł** | **649 675,06 zł** | **+76,7%** |

Nowe kampanie w P2: `meta_prosp_l4_szybko` (od 2025-11-03, 163 322,48 zł) i `tt_prosp_l4_15min` (od 2026-02-09, 82 464,30 zł).

| nowi pacjenci | P1 | P2 | wzrost |
|---|--:|--:|--:|
| wszyscy | 16 231 | 24 687 | +52,1% |
| bez kanałów płatnych, last | 8 314 | 10 438 | +25,5% |
| bez kanałów płatnych, lnd | 7 350 | 8 656 | +17,8% |
| bez kanałów płatnych, first | 7 679 | 8 647 | +12,6% |
| z kanałów płatnych, last | 7 917 | 14 249 | +80,0% |
| z kanałów płatnych, lnd | 8 881 | 16 031 | +80,5% |
| z kanałów płatnych, first | 8 552 | 16 040 | +87,6% |

- **Wzrost według kanałów (last):**
  - meta 1 636 → 5 657,
  - tiktok 0 → 1 593,
  - google/cpc 6 281 → 6 999 (+11,4%),
  - direct 4 047 → 5 297 (+30,9%),
  - google/organic +24,3%,
  - afiliacja 437 → 405 (−7,3%).
- **W wariancie lnd** direct spada do 2 563 → 2 922. Ok. 2 400 pacjentów z „direct” w P2 miało wcześniej sesję z UTM.
- **Koszt na nowego płatnego pacjenta** (tylko kampanie za klik): last 46,44 → 45,59 zł, first 42,99 → 40,50 zł, lnd 41,40 → 40,53 zł. Na tym poziomie pozyskanie nie drożeje. Jakość tych pacjentów pokazuje porównanie wariantów Q3 (`sql/09_definition_variants.sql`).
- **Afiliacja** (25 zł × pierwsze zamówienia, last): 10 925 → 10 125 zł.

### Nowi z kodem kampanii, ale bez płatnej sesji płatności (963)

W P2 5 176 nowych pacjentów ma pierwsze zamówienie z `L4SZYBKO20` lub `TIKTOK25`. 4 213 z nich zapłaciło w sesji z kanału płatnego. Najczęstsze kampanie: `meta_prosp_l4_szybko` 2 468, `tt_prosp_l4_15min` 1 191, `gs_brand` 342, `meta_rmkt_koszyk` 212. Pozostałe 963 (`sql/06_audit_h4.sql`, H4.8):

| kod | pacjenci | sesja płatności | wcześniej sesja z kampanii L4 | bez wcześniejszej sesji |
|---|--:|---|--:|--:|
| L4SZYBKO20 | 679 | direct 437, google/organic 242 | 596 | 83 |
| TIKTOK25 | 284 | direct 181, google/organic 103 | 257 | 27 |

- **853 z 963 (89%) miało wcześniej sesję z kampanii L4** (`meta_prosp_l4_szybko` lub `tt_prosp_l4_15min`). Wśród tych, którzy mieli jakąkolwiek wcześniejszą sesję, każdy miał sesję z jednej z tych kampanii. Zapytanie nie sprawdza, czy kampania pasuje do konkretnego kodu. Zapłacili później, wchodząc bezpośrednio albo z wyszukiwarki. W wariantach first i lnd ci pacjenci trafiają do kanałów płatnych.
- **Sesje płatności to głównie przeglądarki wbudowane** (Instagram, TikTok, Facebook), np. Instagram + `/` 94, Instagram + `/zwolnienie-l4-online` 90, TikTok + `/` 77. Prawdopodobne wyjaśnienie: ponowne wejście z aplikacji bez UTM. To przypuszczenie, w danych nie da się go sprawdzić.
- **110 pacjentów (83 + 27) nie ma żadnej wcześniejszej sesji.** Ich źródła nie da się ustalić.
- **Wyszukiwanie marki:** 342 pacjentów z tymi kodami zapłaciło w sesji z `gs_brand`. Płatne wyszukiwanie marki częściowo przechwytuje pacjentów pozyskanych przez Meta i TikTok.

## H5. Sesje bez zdarzeń — boty nieznalezione

- **Udział sesji bez zdarzeń:** 61–68% w każdym miesiącu. Spada do 61,2% w IX 2025, potem rośnie do 67,5–67,9% od IV 2026.
- **Gdzie jest najwyższy:**
  - przeglądarki wbudowane w aplikacje (Instagram, Facebook, TikTok): 73–81%, wobec 58–63% w zwykłych przeglądarkach,
  - strony bloga: ok. 91%,
  - `/zwolnienie-l4-online`: 73,2%.
- **Udział aplikacji w ruchu** rośnie: Instagram z 9 494 do 39 406 sesji, TikTok z 0 do 30 991.
- **Sygnałów botów brak.** Nie ma sesji tego samego `visitor_id` w odstępie < 10 s. Po wykluczeniu kont testowych żaden `visitor_id` nie ma ≥ 50 sesji (najwięcej: 52 `visitor_id` z 20+ sesjami, razem 1 146).
- **Wpływ:** 0 na KPI dashboardu, bo sesje bez zdarzeń nie płacą. Na lejek (mianownik = wszystkie sesje, Q2):
  - konwersja do płatności: 15,36% (24 942 / 162 336) → 13,20% (38 951 / 295 128), czyli −2,2 pp,
  - konwersja z sesji ze zdarzeniem: 41,63% → 38,94%.
- **Zgodność śledzenia:** sesje z `payment_succeeded` w P1 to 24 942. Zamówienia (24 716) plus samo GO (225) dają 24 941.

## H6. Rabat GO bez członkostwa — odrzucona

- Wszystkie 9 738 zamówień z `discount_type = go` (P1 3 235, P2 6 503) mają ważne członkostwo w dniu zamówienia. To się zgadza w każdym miesiącu.
- Rabatów GO jest +101% przy sprzedaży GO +40%, bo członkowie GO zamawiają więcej. To nie jest przeciek rabatu.
- 85 pacjentów z dwoma członkostwami kupiło drugie po wygaśnięciu pierwszego, w 85 na 85 przypadków. Nakładania się okresów nie ma.

## H7. Jedna osoba, kilka kont — nie da się wykryć

- Każdy `visitor_id` łączy się z dokładnie jednym kontem: 57 473 `visitor_id` z kontem, 0 z dwoma i więcej. Liczyłem łączenie przez zalogowanie albo zapłatę w sesji.
- Dlatego metoda nie znajduje żadnych wspólnych kont. To nie dowodzi, że ich nie ma, bo osoba na nowym urządzeniu ma nowy `visitor_id`. Innego identyfikatora osoby nie ma. Wpisane do `docs/nierozstrzygniete.md` (N1).

## H8. Anulowanie i ponowne zamówienie — marginalna

- `cancelled`, po którym ten sam pacjent w ciągu 48 h zamawia tę samą specjalizację: P1 2 z 1 030, P2 0 z 1 542.
- Pacjenci, których pierwsze zamówienie anulowano i którzy nie opłacili nic więcej: 539 → 893. Są w KPI nowych pacjentów (definicja dashboardu). Ich wyłączenie zmienia wzrost nowych o −0,5 pp.

## Do decyzji

- [x] Czy wyłączamy 22 konta testowe (H1) z całej analizy. **Tak, w całości (A11).**
- [x] Czy w KPI nowych pacjentów zostają ci z samym anulowanym zamówieniem (H8 / Q1). **Nie: Q1 = a2.**
- [x] Przypisanie źródła (Q3): wynik H4 zależy od wariantu (−26,6 / −34,3 / −39,5 pp). **Zamknięte: lnd główny, first i last jako zakres.**
- [x] Mianownik lejka (Q2). **Zamknięte: wszystkie sesje.**
