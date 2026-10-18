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

Marża robocza: `amount_paid − refund_amount − koszt lekarza + opłaty GO`. Koszty pozyskania (kampanie, afiliacja) liczone osobno, przy CAC.

## Otwarte pytania (decyzja po zobaczeniu danych)

### Q1. Definicja kohorty

- **a) Dzień pierwszego opłaconego zamówienia.** Retencja kupujących, zgodna z „pacjentami z pierwszym zakupem” na dashboardzie.
- **b) Dzień rejestracji.** Obejmuje konta bez zakupu; mierzy raczej aktywację niż retencję.
- **c) Dzień pierwszej sesji.** Wymaga łączenia sesji z pacjentem przez `visitor_id`.

Do rozstrzygnięcia przy okazji:
- czy pierwsze zamówienie później anulowane (`cancelled`) otwiera kohortę,
- czy zakup samego GO (bez konsultacji) czyni kogoś pacjentem,
- jak dokładnie dashboard liczy „pacjentów z pierwszym zakupem” (odtworzyć przed podważaniem),
- obsługa uciętego okna obserwacji: porównujemy tylko stałe okna (np. 30/60/90 dni) dla kohort, które je mają,
- szum kohort dziennych: wygładzanie i/lub przedziały ufności.

### Q2. Mianownik lejka

- **a) Wszystkie sesje.** Zawiera powracających zalogowanych, wejścia na strony nieofertowe, wielokrotne sesje i ewentualne boty.
- **b) Sesje z określonym `landing_page`** (strony ofertowe).
- **c) Unikalni odwiedzający na dzień** (`visitor_id` × dzień).
- **d) Lejek od `service_selected`.**

Do uwzględnienia niezależnie od wariantu:
- kroki nie są obowiązkowe po kolei: zalogowany pacjent nie ma `account_completed`, zakup samego GO ma tylko `payment_started` i `payment_succeeded`,
- pacjent może wybrać usługę w jednej sesji, a zapłacić w innej (lejek sesyjny vs pacjenta),
- zdarzenia mogą być zdublowane (eksport surowy) — liczymy unikalne sesje na krok.

### Q3. Przypisanie źródła pacjenta

- **a) Pierwszy kontakt** — pierwsza sesja pacjenta.
- **b) Ostatni kontakt** — sesja płatności (`orders.session_id`).
- **c) Ostatni kontakt niebezpośredni** — ostatnia sesja z niepustym UTM przed zakupem.

Ograniczenie: sesje sprzed zalogowania łączymy z pacjentem tylko przez `visitor_id`, a pacjent może mieć ich kilka.
Przy CAC pamiętać: wydatki przyciągają też powracających pacjentów; opóźnienie kliknięcie → zakup; kanały bez kosztu (direct, organic, e-mail, polecenia) to nie darmowe pozyskanie; możliwa kanibalizacja ruchu brandowego przez płatne kampanie.

### Q4. Definicja powrotu (retencji)

- **a) Kolejne zamówienie dowolnego statusu.**
- **b) Kolejne zamówienie bez `cancelled`.**
- **c) Kolejne zamówienie lub zakup GO.**

Oraz miara: odsetek powracających vs przychód / marża na pacjenta kohorty.

## Do sprawdzenia w audycie danych

- [ ] Dashboard: +61% zamówień przy +50% przychodu — czy „zamówienia” obejmują `cancelled`, co obniża średnią kwotę (rabaty, zmiana mieszanki usług).
- [ ] `discount_type = go` a aktywne członkostwo GO w dniu zamówienia.
- [ ] `refund_amount` zgodny ze `status`.
- [ ] Zamówienia sprzed `registered_at`.
- [ ] Zamówienia z `session_id`, którego nie ma w sesjach.
- [ ] `payment_succeeded` w zdarzeniach vs wiersze w `orders` + `go_memberships` (utrata śledzenia, np. przeglądarki w aplikacjach).
- [ ] Sesje na granicy plików (kwartalne sesje vs półroczne zdarzenia, przełom dni UTC/PL).
