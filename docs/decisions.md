# Decyzje i założenia

## Przyjęte założenia

| # | Założenie | Skąd |
|---|---|---|
| A1 | Koszt lekarza za wizytę odbytą (`completed`, `refunded`): internista 25 zł, psychiatra 200 zł, każdy inny specjalista 100 zł. Za `cancelled` i `no_show` kosztu lekarza nie ma. | zadanie, README |
| A2 | Pediatra i psycholog liczeni jak „inny specjalista”: 100 zł za odbytą wizytę. | **nasze założenie** (README nie wymienia ich wprost) |
| A3 | Opłaty za TelemediGO (89 zł z `go_memberships.csv`) wliczamy do przychodu i marży. Zniżka GO jest już w `amount_paid`. | decyzja |
| A4 | Wszystkie czasy w strefie Europe/Warsaw. Sesje i zdarzenia (UTC) konwertujemy strefą, nie stałym przesunięciem (zmiana czasu letni/zimowy). „Dzień” = dzień kalendarzowy w czasie polskim, wszędzie: kohorty, lejki, wydatki. | decyzja |
| A5 | Afiliacja: 25 zł za pierwsze opłacone zamówienie pacjenta, bez dodatkowych reguł partnera. Według README liczy się także pierwsze zamówienie później anulowane albo zwrócone. | zadanie, README, decyzja |
| A6 | E-mail i SMS: koszt zerowy. Program poleceń: bez kosztu w danych. | zadanie, README |
| A7 | 1 października 2024 to pierwszy dzień sprzedaży; wcześniejszej historii nie ma, więc pierwsze zamówienie w danych jest prawdziwym pierwszym zamówieniem. | README |
| A8 | Zdublowane zamówienia usuwamy, zostaje jedna kopia. Dotyczy 604 `order_id` z identycznymi 2 wierszami (wszystkie `created_at` 10–24.06.2026); `orders` 65 882 → 65 278 wierszy. | profil (`docs/data_quality.md`), decyzja |
| A9 | Afiliacja (`utm_medium = affiliate`) to jeden partner (`rankinglekarzy`); brak `utm_campaign` w jej sesjach nie jest problemem. Puste `utm_campaign` w ruchu organicznym to stan normalny. | profil, decyzja |
| A10 | Zamówienia przypisujemy do dnia po `created_at` (moment płatności). `scheduled_at` / `started_at` mogą wychodzić poza okres danych (do 2026-10-02) i nie służą do datowania. | profil, decyzja |
| A11 | Konta testowe wykluczamy w całości z całej analizy: 22 konta, które choć raz użyły kodu `TEST-QA`, ze wszystkimi 2 071 zamówieniami (1 781 z `TEST-QA` za 1 zł i 290 bez kodu za 89 zł, wszystkie 290 `refunded` z pełnym zwrotem). Wspólny profil: mazowieckie, brak zgody marketingowej, internista, wizyty po 1 min. | audyt H1 (`docs/audit.md`), decyzja |

Marża robocza: `amount_paid − refund_amount − koszt lekarza + opłaty GO`. Koszty pozyskania (kampanie, afiliacja) liczone osobno, przy CAC.

## Pytania definicyjne (Q1–Q4 zamknięte po zobaczeniu danych)

### Q1. Definicja kohorty — **ZAMKNIĘTE**

**Decyzja:** kohorta = dzień **pierwszego nieanulowanego zamówienia** (wariant a2, dzień polski). Kto anulował i nic nie opłacił, nie jest pacjentem. Pacjent, który anulował pierwsze zamówienie, a opłacił później, wchodzi do kohorty z dniem tego opłaconego. Nowi pacjenci: P1 15 679, P2 23 807, +51,8%. Różnica do definicji dashboardu jest w moście (`docs/most.md`, nowi pacjenci, krok 3). Porównanie wariantów: `sql/09_definition_variants.sql`, Q1.1–Q1.3.

Rozważane warianty:

- **a) Dzień pierwszego opłaconego zamówienia.** Retencja kupujących, zgodna z „pacjentami z pierwszym zakupem” na dashboardzie.
- **b) Dzień rejestracji.** Obejmuje konta bez zakupu; mierzy raczej aktywację niż retencję.
- **c) Dzień pierwszej sesji.** Wymaga łączenia sesji z pacjentem przez `visitor_id`.

Do rozstrzygnięcia przy okazji:
- czy pierwsze zamówienie później anulowane (`cancelled`) otwiera kohortę,
- czy zakup samego GO (bez konsultacji) czyni kogoś pacjentem,
- jak dokładnie dashboard liczy „pacjentów z pierwszym zakupem” (odtworzyć przed podważaniem),
  **ustalone:** dashboard liczy nowych pacjentów łącznie z tymi, których pierwsze zamówienie anulowano (najwcześniejsze `created_at`, dowolny status): P1 16 251 → P2 24 689, +51,9% (`sql/01_dashboard_reproduction.sql`, wariant a). Zastrzeżenie: wariant bez anulowanych daje 15 699 → 23 809, +51,7%, co też zaokrągla się do +52%,
- obsługa uciętego okna obserwacji: porównujemy tylko stałe okna (np. 30/60/90 dni) dla kohort, które je mają,
- szum kohort dziennych: wygładzanie i/lub przedziały ufności.

### Q2. Mianownik lejka — **ZAMKNIĘTE**

**Decyzja:** mianownik lejka = **wszystkie sesje** (wariant a). Audyt H5 nie znalazł botów: brak sesji tego samego `visitor_id` w odstępie < 10 s, a 21 `visitor_id` z ≥ 50 sesjami to konta testowe (wykluczone przez A11). Sesje bez zdarzeń (61–67%) wynikają z bloga i przeglądarek w aplikacjach (`docs/audit.md`, H5).

**Kroki lejka.** Kolejność jest ścisła: krok liczy się, jeśli sesja doszła do poprzedniego.
1. `service_selected`,
2. `slot_selected`,
3. **konto** = `account_completed` **albo** `user_id` w sesji (zalogowany pacjent nie ma `account_completed`),
4. `payment_started`,
5. `payment_succeeded`.

Zakup samego GO (bez `service_selected`) nie wchodzi do lejka konsultacji. Kontrola: sesje, które przeszły wszystkie 5 kroków = 63 207 = liczba zamówień w bazie A8 + A11 (`sql/11_daily_series.sql`).

Rozważane warianty:

- **a) Wszystkie sesje.** Zawiera powracających zalogowanych, wejścia na strony nieofertowe, wielokrotne sesje i ewentualne boty.
- **b) Sesje z określonym `landing_page`** (strony ofertowe).
- **c) Unikalni odwiedzający na dzień** (`visitor_id` × dzień).
- **d) Lejek od `service_selected`.**

Do uwzględnienia niezależnie od wariantu:
- kroki nie są obowiązkowe po kolei: zalogowany pacjent nie ma `account_completed`, zakup samego GO ma tylko `payment_started` i `payment_succeeded`,
- pacjent może wybrać usługę w jednej sesji, a zapłacić w innej (lejek sesyjny vs pacjenta),
- zdarzenia mogą być zdublowane (eksport surowy) — liczymy unikalne sesje na krok.

### Q3. Przypisanie źródła pacjenta — **ZAMKNIĘTE**

**Decyzja:** wariant główny = **ostatnia sesja niebezpośrednia przed pierwszym zakupem** (lnd), szukana po wszystkich `visitor_id` pacjenta. Jeśli takiej sesji nie ma: direct. Jak ktoś przyszedł z reklamy i wrócił bezpośrednio, to zasługa reklamy. Jak wrócił z innej reklamy, to zasługa tej drugiej. Warianty **first** i **last** pokazujemy obok jako zakres niepewności. Przykład (nowi według Q1 a2): wzrost nowych bez kanałów płatnych +17,7% (lnd), zakres +12,7% (first) do +25,4% (last). Ile wzrostu reklama daje naprawdę, nie wynika z tych danych (`docs/nierozstrzygniete.md`, N2).

Rozważane warianty:

- **a) Pierwszy kontakt** — pierwsza sesja pacjenta.
- **b) Ostatni kontakt** — sesja płatności (`orders.session_id`).
- **c) Ostatni kontakt niebezpośredni** — ostatnia sesja z niepustym UTM przed zakupem.

Ograniczenie: sesje sprzed zalogowania łączymy z pacjentem tylko przez `visitor_id`, a pacjent może mieć ich kilka.
Przy CAC pamiętać: wydatki przyciągają też powracających pacjentów; opóźnienie kliknięcie → zakup; kanały bez kosztu (direct, organic, e-mail, polecenia) to nie darmowe pozyskanie; możliwa kanibalizacja ruchu brandowego przez płatne kampanie.

### Q4. Definicja powrotu (retencji) — **ZAMKNIĘTE**

**Decyzja:** powrót = **kolejne zamówienie nieanulowane** po zamówieniu otwierającym kohortę (wariant b). Okno główne **90 dni**, obok pokazujemy 30 i 180 dni. Liczymy tylko kohorty z pełnym oknem (do 30.09.2026). Uzupełniająca miara wartości: kolejne zamówienia i przychód netto z kolejnych zamówień na pacjenta w oknie. Wariant c (zamówienie lub samo GO) w tych danych daje to samo co a, bo nikt nie wrócił samym GO. Porównanie: `sql/09_definition_variants.sql`, Q4.1–Q4.3.

Rozważane warianty:

- **a) Kolejne zamówienie dowolnego statusu.**
- **b) Kolejne zamówienie bez `cancelled`.**
- **c) Kolejne zamówienie lub zakup GO.**

Oraz miara: odsetek powracających vs przychód / marża na pacjenta kohorty.

## Do sprawdzenia w audycie danych

- [x] Czy dashboard liczył zdublowane zamówienia z 10–24.06.2026 (A8). Jeśli tak, 604 duplikaty są częścią pokazanego wzrostu zamówień (+61%) i przychodu.
  **Wynik:** tak. +61% zamówień i +50% przychodu wychodzą tylko z duplikatami; bez nich +58,3% i +48,1% (`docs/most.md`).
- [x] 85 pacjentów z dwoma członkostwami GO: czy drugie kupiono po wygaśnięciu pierwszego, czy w trakcie jego ważności (nakładające się okresy).
  **Wynik:** wszystkie 85 po wygaśnięciu, 0 nakładających się (`docs/audit.md`, H6).

- [ ] Dashboard: +61% zamówień przy +50% przychodu — czy „zamówienia” obejmują `cancelled`, co obniża średnią kwotę (rabaty, zmiana mieszanki usług).
- [x] `discount_type = go` a aktywne członkostwo GO w dniu zamówienia.
  **Wynik:** wszystkie 9 738 zamówień z rabatem GO mają ważne członkostwo (`docs/audit.md`, H6).
- [ ] `refund_amount` zgodny ze `status`.
- [x] Zamówienia sprzed `registered_at`.
  **Wynik:** 0, i 0 zamówień bez konta w `users` (`sql/04_audit_h1_h2.sql`, H1.6).
- [ ] Zamówienia z `session_id`, którego nie ma w sesjach.
- [x] `payment_succeeded` w zdarzeniach vs wiersze w `orders` + `go_memberships` (utrata śledzenia, np. przeglądarki w aplikacjach).
  **Wynik:** zgodne: sesje z płatnością P1 25 495 vs zamówienia + samo GO 25 494 (`docs/audit.md`, H5).
- [ ] Sesje na granicy plików (kwartalne sesje vs półroczne zdarzenia, przełom dni UTC/PL).
