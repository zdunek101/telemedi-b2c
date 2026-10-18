# Audyt: co jeszcze może zawyżać liczby

Okresy: **P1** = X 2024 – IX 2025, **P2** = X 2025 – IX 2026, czas polski (A4), zamówienia po `created_at` (A10).
Baza: zamówienia i przychód **po deduplikacji** (A8), nowi pacjenci i GO jak w dashboardzie (Q1).
Niczego nie usunięto. Wpływ każdej hipotezy liczony **osobno**: wzrost KPI po wyłączeniu oznaczonych wierszy minus wzrost w bazie.

| KPI w bazie | P1 | P2 | wzrost |
|---|--:|--:|--:|
| zamówienia | 25 269 | 40 009 | +58,3% |
| przychód z konsultacji (brutto) | 2 381 880,60 zł | 3 528 635,60 zł | +48,1% |
| nowi pacjenci | 16 251 | 24 689 | +51,9% |
| sprzedane GO | 1 759 | 2 468 | +40,3% |

SQL: `sql/03_audit_base.sql` (baza), `04` (H1, H2), `05` (H3, H6), `06` (H4), `07` (H5, H7, H8), `08` (wpływ i pokrycie).
Uruchomienie: `.venv/Scripts/python.exe scripts/run_sql.py sql/00_raw_views.sql sql/03_audit_base.sql sql/06_audit_h4.sql sql/08_audit_impact.sql`.

## Podsumowanie

| # | hipoteza | wynik | skala P1 → P2 | wpływ na wzrost KPI |
|---|---|---|---|---|
| H1 | konta testowe / wewnętrzne | **potwierdzona** | 22 konta, 553 → 1 518 zamówień | zamówienia −2,6 pp, przychód −0,4 pp, nowi +0,2 pp, GO 0 |
| H2 | dziwne kwoty / kody | kwoty w porządku; **kod testowy TEST-QA** (= H1); **dwa nowe kody w P2** | kody L4SZYBKO20 + TIKTOK25: 0 → 5 176 zamówień (wszystkie to pierwsze zamówienia) | bez nich: zamówienia −20,5 pp, przychód −16,1 pp, nowi −31,8 pp |
| H3 | wzrost zwrotów 6,3% → 8,5% | **potwierdzona, rosną tylko `refunded`** | `refunded` 567 → 1 841 (2,2% → 4,6% zamówień) | przychód netto: −3,4 pp od `refunded`, +0,3 pp od `cancelled` |
| H4 | wzrost kupiony reklamą | **w dużej części tak** (zależnie od przypisania) | wydatki za klik 367 632 → 649 675 zł (+76,7%) | nowi bez kanałów płatnych: −26,6 pp (last) / −34,4 pp (lnd) / −39,6 pp (first) |
| H5 | sesje bez zdarzeń = boty | **nie znaleziono botów** | sesje bez zdarzeń 61–67% miesięcznie | KPI 0; konwersja sesja → płatność 15,65% → 13,64% |
| H6 | rabat GO bez członkostwa | **odrzucona** | 0 z 9 738 zamówień z rabatem GO | 0 |
| H7 | jedna osoba, kilka kont | **nie da się wykryć** dostępnym sygnałem | każdy `visitor_id` ma dokładnie 1 konto | 0 (przy tej metodzie) |
| H8 | anulowanie i ponowne zamówienie | **marginalna** | ponowne zamówienie w 48 h: 2 → 0; pierwsze zamówienie anulowane i nic więcej: 539 → 893 | nowi −0,4 pp, zamówienia −0,1 pp |

Pokrycie: 8 255 zamówień ma jedno oznaczenie (H1, H2, H8), 212 ma dwa. Nowi pacjenci z H2 i H4 w dużej części się pokrywają: z 5 176 pierwszych zamówień z nowymi kodami 4 213 ma sesję płatności z kanału płatnego (last). Wpływów H2 i H4 **nie wolno sumować**.

## H1. Konta testowe / wewnętrzne — potwierdzona

- 22 konta użyły kodu `TEST-QA` (88 zł zniżki, kwota 1 zł). Mają razem 2 071 zamówień: 1 781 z `TEST-QA` i 290 bez rabatu (89 zł).
- Wspólny profil wszystkich 22: województwo mazowieckie, `marketing_consent = 0`, jedna specjalizacja (internista), każda wizyta trwa 1 min, zawsze czat.
- Statusy: 1 781 zamówień z `TEST-QA` to `completed` bez zwrotu. Wszystkie 290 zamówień bez kodu to `refunded` z pełnym zwrotem 89 zł (razem 25 810 zł; P1 75 zamówień, P2 215).
  **Korekta:** w pierwszej wersji audytu było tu „status zawsze `completed`, 0 zwrotów”. Sprawdziłem wtedy status tylko dla zamówień z `TEST-QA`. Błąd wyszedł przy dodawaniu kont testowych do mostu.
- To te same konta, które mają najwięcej zamówień (48–148 na konto). Poza nimi najaktywniejsi pacjenci mają 10–19 zamówień (273 osoby).
- 21 `visitor_id` z ≥ 50 sesjami (2 044 sesje) należy do tych kont, więc to one tłumaczą „ciężkich” odwiedzających z H5.
- Inne heurystyki niczego nie znalazły:
  - `birth_year` mieści się w 1942–2008,
  - najwięcej rejestracji w jednej minucie to 4,
  - najwięcej zamówień jednego pacjenta jednego dnia to 5 (3 przypadki),
  - nie ma zamówień sprzed rejestracji ani bez konta.
- Konta testowe rosną z 553 zamówień w P1 do 1 518 w P2.
- Skutek dla marży (A1): wszystkie wizyty się odbyły (`completed` lub `refunded`), więc koszt lekarza wynosi 2 071 × 25 zł = 51 775 zł. Przychód brutto z tych kont to 27 591 zł, a po zwrotach 1 781 zł.
- **Decyzja (A11):** konta testowe wykluczamy w całości. Uwzględnia to most (`docs/most.md`, krok 2). Liczby w tym audycie liczone są jeszcze na bazie z tymi kontami.

## H2. Kwoty i kody rabatowe

- **Kwoty są spójne.** 0 zamówień z kwotą 0 zł, ujemną lub wyższą od ceny katalogowej. 0 niezgodności z regułą rabatu: `none` = cena katalogowa, `go` = 50% u internisty i 20% u pozostałych, `promo` < cena katalogowa.
- **Ceny katalogowe się nie zmieniały.** Każda specjalizacja ma jedną cenę przez cały okres.
- **Kody:**

| kod | zniżka | zamówienia P1 | P2 | od |
|---|--:|--:|--:|---|
| L4SZYBKO20 | 20 zł | 0 | 3 511 | 2025-11-04 |
| START10 | 10 zł | 1 500 | 1 886 | 2024-10-01 |
| TEST-QA | 88 zł | 478 | 1 303 | 2024-10-21 |
| TIKTOK25 | 25 zł | 0 | 1 665 | 2026-02-10 |
| RANKING10 | 10 zł | 300 | 295 | 2024-10-02 |
| WRACAM15 | 15 zł | 148 | 207 | 2024-10-06 |

- `L4SZYBKO20` i `TIKTOK25` występują tylko w P2. Każde ich użycie to pierwsze zamówienie pacjenta. Daty startu zgadzają się z kampaniami `meta_prosp_l4_szybko` (od 2025-11-03) i `tt_prosp_l4_15min` (od 2026-02-09).
- To nie jest błąd danych, tylko źródło wzrostu w P2. Bez tych kodów nowych pacjentów byłoby +20,1% zamiast +51,9%. Przy tym te kody mają najwyższy odsetek `refunded` (H3).

## H3. Zwroty — rosną wyłącznie `refunded`

| | P1 | P2 |
|---|--:|--:|
| `cancelled`: zamówienia / % zamówień | 1 030 / 4,08% | 1 542 / 3,85% |
| `cancelled`: zwroty / % przychodu | 98 577,40 zł / 4,14% | 141 323,40 zł / 4,01% |
| `refunded`: zamówienia / % zamówień | 567 / 2,24% | 1 841 / 4,60% |
| `refunded`: zwroty / % przychodu | 52 558,70 zł / 2,21% | 157 666,80 zł / 4,47% |

- **Od kiedy.** Udział `refunded` w zamówieniach wynosi ok. 2–2,9% do IX 2025. Potem rośnie co miesiąc: X 2025 2,76%, XII 3,48%, III 2026 4,77%, VI 6,17%, IX 6,05%. Udział zwrotów w przychodzie: IX 2026 10,66%.
- **W czym.** Z 1 841 zwrotów `refunded` w P2:
  - 730 to kody `L4SZYBKO20` / `TIKTOK25`. Odsetek `refunded` w tych kodach wynosi 11–15% zależnie od trybu.
  - 590 to L4 u internisty bez tych kodów. Odsetek dla całego L4 u internisty: 5,6% → 11,0%.
  - 521 to pozostałe. Z tego 215 to konta testowe (H1), a bez nich zostaje 306 (P1: 300 − 75 = 225).
  - **Korekta:** pierwsza wersja podawała wzrost przy czacie bez rabatu 3,9% → 6,4%. Bez kont testowych jest to 2,3% (103 / 4 523) → 2,8% (157 / 5 624). Wzrost wynikał prawie w całości z kont testowych.
- **Bez kont testowych (A11) wniosek się trzyma:**
  - `refunded` 492 → 1 626 (1,99% → 4,22% zamówień),
  - L4 u internisty 260 / 4 680 = 5,6% → 1 247 / 11 398 = 10,9%,
  - zwroty w przychodzie 6,08% → 7,98%.
- **Psychiatra L4:** 5,2% → 12,4%, ale na małej liczbie (379 zamówień w P2).
- **Opóźnienie lekarza** (`started_at − scheduled_at`) dla wizyt odbytych: mediana 3,1 → 3,8 min, ale 90. percentyl 9,6 → 20,2 min. Kolejka się wydłuża. To związek w czasie, nie dowód przyczyny zwrotów.
- **`cancelled` nie rośnie** i nie zależy od czasu do terminu: ok. 4% przy < 1 h, 1–24 h i > 24 h.

## H4. Wzrost kupiony reklamą

Przypisanie źródła jest otwarte (Q3). Poniżej trzy **prowizoryczne** warianty:
- **last:** UTM sesji pierwszej płatności,
- **first:** UTM najwcześniejszej sesji pacjenta przed pierwszym zamówieniem, szukanej po wszystkich jego `visitor_id`,
- **lnd** (last non-direct): UTM ostatniej sesji z niepustym `utm_source` do momentu pierwszego zamówienia, po tych samych `visitor_id`. Jeśli takiej sesji nie ma: direct.

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
| wszyscy | 16 251 | 24 689 | +51,9% |
| bez kanałów płatnych, last | 8 334 | 10 440 | +25,3% |
| bez kanałów płatnych, first | 7 699 | 8 649 | +12,3% |
| bez kanałów płatnych, lnd | 7 370 | 8 658 | +17,5% |
| z kanałów płatnych, last | 7 917 | 14 249 | +80,0% |
| z kanałów płatnych, first | 8 552 | 16 040 | +87,6% |
| z kanałów płatnych, lnd | 8 881 | 16 031 | +80,5% |

- **lnd:** kanał direct spada do 2 583 → 2 924 (last: 4 067 → 5 299). Ok. 2 400 pacjentów z „direct” w P2 miało wcześniej sesję z UTM. Wpływ na wzrost nowych: −34,4 pp. Wynik leży między last (−26,6 pp) a first (−39,6 pp).

- Wzrost według kanałów (last):
  - meta 1 636 → 5 657,
  - tiktok 0 → 1 593,
  - google/cpc 6 281 → 6 999 (+11,4%),
  - direct +30,3%, organic +24,3%,
  - afiliacja 437 → 405 (−7,3%).
- **Koszt na nowego płatnego pacjenta** (tylko kampanie za klik): last 46,44 → 45,59 zł, first 42,99 → 40,50 zł, lnd 41,40 → 40,53 zł. Na tym poziomie pozyskanie nie drożeje. Nie liczy to jakości tych pacjentów (zwroty H3, retencja), bo to temat kohort.
- **Afiliacja** (25 zł × pierwsze zamówienia, last): 10 925 → 10 125 zł.

### Nowi z kodem kampanii, ale bez płatnej sesji płatności (963)

W P2 5 176 nowych pacjentów ma pierwsze zamówienie z `L4SZYBKO20` lub `TIKTOK25`. 4 213 z nich zapłaciło w sesji z kanału płatnego. Najczęstsze kampanie: `meta_prosp_l4_szybko` 2 468, `tt_prosp_l4_15min` 1 191, `gs_brand` 342, `meta_rmkt_koszyk` 212. Pozostałe 963 (`sql/06_audit_h4.sql`, H4.8):

| kod | pacjenci | sesja płatności | wcześniej sesja z kampanii tego kodu | bez wcześniejszej sesji |
|---|--:|---|--:|--:|
| L4SZYBKO20 | 679 | direct 437, google/organic 242 | 596 | 83 |
| TIKTOK25 | 284 | direct 181, google/organic 103 | 257 | 27 |

- **853 z 963 (89%) miało wcześniej sesję z kampanii L4** (`meta_prosp_l4_szybko` lub `tt_prosp_l4_15min`). Wśród tych, którzy w ogóle mieli wcześniejszą sesję, każdy miał sesję z jednej z tych kampanii. Zapytanie nie sprawdza, czy kampania pasuje do konkretnego kodu. Zapłacili później, wchodząc bezpośrednio albo z wyszukiwarki. To potwierdza Twoją hipotezę: zobaczyli reklamę, a weszli inaczej. W wariantach first i lnd ci pacjenci trafiają do kanałów płatnych.
- **Sesje płatności to głównie przeglądarki wbudowane** (Instagram, TikTok, Facebook), np. Instagram + `/` 94, Instagram + `/zwolnienie-l4-online` 90, TikTok + `/` 77. Prawdopodobne wyjaśnienie: ponowne wejście z aplikacji, które nie przekazało UTM. To przypuszczenie, w danych nie da się go sprawdzić.
- **110 pacjentów (83 + 27) nie ma żadnej wcześniejszej sesji.** Kod mógł dojść do nich poza śledzonymi sesjami (np. przekazany dalej, wpisany z reklamy bez kliknięcia). Ich źródła nie da się ustalić.
- **Wyszukiwanie marki:** 342 pacjentów z tymi kodami zapłaciło w sesji z kampanii `gs_brand`. Ruch brandowy z płatnego wyszukiwania częściowo przechwytuje pacjentów pozyskanych przez Meta i TikTok.

## H5. Sesje bez zdarzeń — boty nieznalezione

- **Udział sesji bez zdarzeń:** 61–67% w każdym miesiącu. Spada do 60,8% w IX 2025, potem rośnie do 67–67,5% od IV 2026.
- **Gdzie jest najwyższy:**
  - przeglądarki wbudowane w aplikacje (Instagram, Facebook, TikTok): 73–81%, wobec 58–63% w zwykłych przeglądarkach,
  - strony bloga: ok. 91%,
  - `/zwolnienie-l4-online`: 73,2%.
- **Udział aplikacji w ruchu** rośnie: Instagram z 9 494 do 39 406 sesji, TikTok z 0 do 30 991. Dlatego rośnie też udział sesji bez zdarzeń.
- **Sygnałów botów brak.** Nie ma sesji tego samego `visitor_id` w odstępie < 10 s. 21 `visitor_id` z ≥ 50 sesjami to konta testowe (H1).
- **Wpływ:** 0 na KPI dashboardu, bo sesje bez zdarzeń nie płacą. Na lejek:
  - konwersja z wszystkich sesji do płatności: 15,65% (25 495 / 162 909) → 13,64% (40 469 / 296 648), czyli −2,0 pp,
  - konwersja z sesji ze zdarzeniem: 42,15% → 39,85%.
- **Zgodność śledzenia:** sesje z `payment_succeeded` w P1 to 25 495. Zamówienia (25 269) plus samo GO (225) dają 25 494. Śledzenie płatności zgadza się z transakcjami.

## H6. Rabat GO bez członkostwa — odrzucona

- Wszystkie 9 738 zamówień z `discount_type = go` (P1 3 235, P2 6 503) mają ważne członkostwo w dniu zamówienia. To się zgadza w każdym miesiącu.
- Rabatów GO jest +101% przy sprzedaży GO +40%, bo członkowie GO zamawiają więcej. To nie jest przeciek rabatu.
- 85 pacjentów z dwoma członkostwami kupiło drugie po wygaśnięciu pierwszego, w 85 na 85 przypadków. Nakładania się okresów nie ma.

## H7. Jedna osoba, kilka kont — nie da się wykryć

- Każdy `visitor_id` łączy się z dokładnie jednym kontem: 57 495 `visitor_id` z kontem, 0 z dwoma i więcej. Liczyłem łączenie przez zalogowanie albo zapłatę w sesji.
- Dlatego metoda nie znajduje żadnych wspólnych kont. To nie dowodzi, że ich nie ma, bo osoba na nowym urządzeniu ma nowy `visitor_id`. Innego identyfikatora osoby (e-mail, telefon) w danych nie ma. Wpisane do `docs/nierozstrzygniete.md` (N1).

## H8. Anulowanie i ponowne zamówienie — marginalna

- `cancelled`, po którym ten sam pacjent w ciągu 48 h zamawia tę samą specjalizację: P1 2 z 1 030, P2 0 z 1 542.
- Pacjenci, których pierwsze zamówienie anulowano i którzy nie opłacili nic więcej: 539 → 893. Są w KPI nowych pacjentów (Q1). Ich wyłączenie zmienia wzrost o −0,4 pp.

## Do decyzji

- [x] Czy wyłączamy 22 konta testowe (H1) z całej analizy (zamówienia, przychód, nowi, marża, sesje). **Tak, w całości (A11).**
- [ ] Czy w KPI nowych pacjentów zostają ci z samym anulowanym zamówieniem (H8 / Q1).
- [ ] Przypisanie źródła (Q3): wynik H4 zależy od wariantu (−26,6 / −34,4 / −39,6 pp).
- [x] Mianownik lejka (Q2): sesje bez zdarzeń i ruch z przeglądarek w aplikacjach przesuwają konwersję. **Zamknięte: wszystkie sesje.**
