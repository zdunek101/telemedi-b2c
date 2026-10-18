# B2C, 24 miesiące

*Zadanie rekrutacyjne*

459 557 sesji · 52 422 kont · 24 miesiące

> Źródło: https://claude.ai/artifact/B6qdqJiRuYmFEMbjizPWyD

---

## Kontekst

B2C to ta część Telemedi, w której pacjent płaci z własnej kieszeni na telemedi.com. Dziś sprzedajemy tam konsultacje online i TelemediGO, nasz program zniżkowy.

Poniżej masz dwa lata tego biznesu: każdą sesję na stronie, każdy krok lejka zakupowego, każde zamówienie, każdy zakup TelemediGO i każdą złotówkę wydaną na kampanie. Dane pochodzą z analityki strony i z systemu transakcyjnego. Nikt ich wcześniej nie czyścił.

Na dashboardzie wygląda to dobrze. Ostatnie 12 miesięcy w porównaniu z poprzednimi dwunastoma:

| Wskaźnik | Zmiana |
|---|---|
| pacjentów z pierwszym zakupem | **+52%** |
| zamówień | **+61%** |
| przychodu z konsultacji | **+50%** |
| sprzedanych TelemediGO | **+40%** |

`X 2025 – IX 2026 wobec X 2024 – IX 2025`

Dla nas wzrost to dwie rzeczy naraz: więcej pacjentów i lepsza retencja. Chcemy wiedzieć, czy to, co widać na dashboardzie, jest wzrostem.

Ten biznes prowadzimy na kohortach. Codziennie patrzymy, jak zachowują się kolejne kohorty, i chcemy rozumieć, które zdarzenie albo która nasza decyzja zmieniła ich zachowanie i wynik. To jest najważniejsza umiejętność w tej roli i najważniejsza część tego zadania.

---

## Czego oczekujemy

**01. Analiza kohortowa**
Obowiązkowa i najważniejsza. Kohorty w rozdzielczości dziennej, pocięte tak, żeby było widać, co się wydarzyło, kiedy, i jak zmieniło zachowanie pacjentów i wynik biznesu. Listy zmian w produkcie ani kalendarza kampanii nie dajemy. Zdarzenia trzeba znaleźć w danych.

**02. Lejki**
Obowiązkowe. Od wejścia na stronę do płatności, w podziale, który pokazuje, gdzie i od kiedy tracimy pacjentów.

**03. Narzędzie, nie raport**
Kohorty i lejki zbuduj z AI jako działające narzędzie, na którym sam(a) prowadził(a)byś ten biznes na co dzień. Ma działać na tych danych i otwierać się z linku.

**04. Lista priorytetów**
Co robisz po kolei, od najważniejszego. Każda pozycja ma wynikać z danych i mieć trzy rzeczy: ile jest warta, po czym poznamy, że zadziałała, i ile zajmie wdrożenie.

**05. Czego nie da się rozstrzygnąć**
Co z tych danych nie wynika i jakiego testu albo jakich informacji brakuje, żeby to domknąć.

---

## Co oddajesz

| | |
|---|---|
| **Link do narzędzia** | Działające, otwierane w przeglądarce bez instalacji i bez zakładania konta. Kohorty i lejki muszą w nim być. Stack dowolny. |
| **Lista priorytetów** | Od najważniejszego, z wartością, sposobem pomiaru i szacunkiem czasu wdrożenia każdej pozycji. Może być częścią narzędzia. |
| **Ślad pracy** | Repozytorium albo eksport rozmów z AI: prompty, ślepe uliczki, poprawki. Nie sprzątaj go. Chcemy zobaczyć, jak pracujesz, a nie tylko co wyszło. |

Linki odeślij tą samą drogą, którą przyszło do Ciebie zadanie.

---

## Dane

17 plików CSV, 1 082 369 wierszy, razem 84 MB po rozpakowaniu. Okres od 1 października 2024 do 30 września 2026. Do okna czatu się to nie zmieści.

`telemedi-b2c-dane.zip · ok. 14 MB spakowane · wszystkie pliki i słownik danych` — [Pobierz komplet](https://drive.google.com/file/d/16_tYjg95bkix5Y_HGtKBgtjO_NYZxNNo/view?usp=sharing)

| plik | wiersze | MB | jeden wiersz to |
|---|--:|--:|---|
| users.csv | 52 422 | 3.2 | konto pacjenta |
| sessions_2024q4.csv | 38 490 | 3.9 | sesja na telemedi.com |
| sessions_2025q1.csv | 46 524 | 4.7 | sesja na telemedi.com |
| sessions_2025q2.csv | 40 384 | 4.1 | sesja na telemedi.com |
| sessions_2025q3.csv | 37 511 | 3.8 | sesja na telemedi.com |
| sessions_2025q4.csv | 52 797 | 5.4 | sesja na telemedi.com |
| sessions_2026q1.csv | 80 728 | 8.5 | sesja na telemedi.com |
| sessions_2026q2.csv | 84 383 | 9.1 | sesja na telemedi.com |
| sessions_2026q3.csv | 78 740 | 8.6 | sesja na telemedi.com |
| events_2024h2.csv | 39 510 | 1.8 | krok lejka zakupowego |
| events_2025h1.csv | 101 513 | 4.6 | krok lejka zakupowego |
| events_2025h2.csv | 109 052 | 5.0 | krok lejka zakupowego |
| events_2026h1.csv | 168 991 | 7.7 | krok lejka zakupowego |
| events_2026h2.csv | 75 539 | 3.4 | krok lejka zakupowego |
| orders.csv | 65 882 | 10.0 | opłacone zamówienie konsultacji |
| go_memberships.csv | 4 227 | 0.3 | zakup TelemediGO |
| marketing_spend.csv | 5 676 | 0.3 | dzień × kampania płatna za klik |
| README.md | | < 0.1 | słownik danych |

Przycisk otwiera plik na Dysku Google w nowej karcie. Pobierzesz go stamtąd ikoną pobierania. W paczce jest wszystko, co widać w tabeli.

Sesje i zdarzenia pochodzą z analityki strony i mają czas w UTC. Pozostałe tabele pochodzą z systemu transakcyjnego i mają czas polski. Źródła pozyskania pacjenta nie ma w żadnej tabeli: trzeba je wyprowadzić z sesji i samemu zdecydować, jak je przypisać.

### `users.csv`

Konta pacjentów.

| kolumna | opis |
|---|---|
| `user_id` | identyfikator konta |
| `registered_at` | moment założenia konta |
| `birth_year` | rok urodzenia |
| `gender` | K lub M |
| `region` | województwo |
| `city_size` | wieś albo miasto w trzech przedziałach wielkości |
| `marketing_consent` | 1, jeśli pacjent zgodził się na komunikację marketingową |

### `sessions_2024q4.csv … sessions_2026q3.csv`

Sesje na telemedi.com, eksport kwartalny. Czas w UTC.

| kolumna | opis |
|---|---|
| `session_id` | identyfikator sesji |
| `visitor_id` | identyfikator przeglądarki (cookie); jeden pacjent może mieć kilka |
| `user_id` | wypełnione tylko wtedy, gdy pacjent był w tej sesji zalogowany |
| `started_at_utc` | początek sesji |
| `utm_source` | źródło wejścia; puste przy wejściu bezpośrednim |
| `utm_medium` | rodzaj ruchu |
| `utm_campaign` | kampania |
| `device` | mobile, desktop, tablet |
| `os` | system operacyjny |
| `browser` | przeglądarka; Instagram, Facebook i TikTok to przeglądarki wbudowane w aplikacje |
| `landing_page` | pierwsza strona sesji |

### `events_2024h2.csv … events_2026h2.csv`

Kroki lejka zakupowego, eksport półroczny. Czas w UTC. Sesja bez żadnego zdarzenia to sesja, w której pacjent nie wybrał usługi.

| kolumna | opis |
|---|---|
| `session_id` | sesja, w której zaszło zdarzenie |
| `event_name` | kolejno: `service_selected`, `slot_selected`, `account_completed` (logowanie albo rejestracja), `payment_started`, `payment_succeeded` |
| `event_at_utc` | moment zdarzenia |

### `orders.csv`

Opłacone zamówienia konsultacji.

| kolumna | opis |
|---|---|
| `order_id` | identyfikator zamówienia |
| `user_id` | konto pacjenta |
| `session_id` | sesja, w której zapłacono |
| `created_at` | moment płatności |
| `specialization` | internista, pediatra albo jeden z ośmiu specjalistów |
| `visit_purpose` | konsultacja, e_recepta, l4, skierowanie |
| `consultation_mode` | phone, chat, video |
| `scheduled_at` | termin, na który pacjent umówił wizytę |
| `started_at` | moment, w którym lekarz faktycznie zaczął wizytę |
| `duration_min` | czas trwania wizyty |
| `list_price` | cena katalogowa |
| `discount_type` | none, go (TelemediGO), promo (kod rabatowy) |
| `promo_code` | użyty kod |
| `amount_paid` | kwota zapłacona za konsultację, bez opłaty za TelemediGO |
| `payment_method` | blik, card, transfer |
| `status` | `completed`, `cancelled` (przed wizytą, pełny zwrot), `no_show` (pacjent nie odebrał, bez zwrotu), `refunded` (wizyta odbyta, zwrot po niej) |
| `refund_amount` | kwota zwrotu |
| `rating` | ocena wizyty 1–5; większość pacjentów nie ocenia |

### `go_memberships.csv`

Zakupy TelemediGO. Jednorazowa opłata 89 zł za 12 miesięcy daje 50% zniżki na wizyty u internisty (w tym e-receptę, L4 i skierowanie) oraz 20% na pozostałych specjalistów. Pacjent kupuje je przy kasie razem z konsultacją albo osobno. Członkostwo nie odnawia się samo.

| kolumna | opis |
|---|---|
| `membership_id` | identyfikator członkostwa |
| `user_id` | konto pacjenta |
| `purchased_at` | moment zakupu |
| `valid_until` | ostatni dzień ważności |
| `amount_paid` | 89.00 |
| `order_id` | zamówienie, przy którym kupiono GO; puste, jeśli kupiono osobno |
| `session_id` | sesja zakupu |

### `marketing_spend.csv`

Dzienne wydatki na kampanie płatne za klik: Google Ads, Meta, TikTok. Afiliacja jest rozliczana prowizją 25 zł za pierwsze opłacone zamówienie pacjenta i w tej tabeli jej nie ma. Koszt e-maili i SMS-ów pomiń.

| kolumna | opis |
|---|---|
| `date` | dzień według czasu polskiego |
| `utm_source` | jak w sesjach |
| `utm_medium` | jak w sesjach |
| `utm_campaign` | jak w sesjach |
| `impressions` | wyświetlenia |
| `clicks` | kliknięcia |
| `spend_pln` | koszt netto |

**Kosztu lekarza w danych nie ma.** Jeśli liczysz marżę, przyjmij za każdą odbytą wizytę 25 zł u internisty, 200 zł u psychiatry i 100 zł u każdego innego specjalisty. Lekarz dostaje wynagrodzenie także za wizytę, za którą zwróciliśmy pacjentowi opłatę.

Pełny słownik, z kilkoma dodatkowymi objaśnieniami, jest w pliku `README.md` w paczce.

Pierwsze wiersze `orders.csv` dla orientacji:

| order_id | user_id | session_id | created_at | specialization | visit_purpose | consultation_mode | scheduled_at | started_at | duration_min | list_price | discount_type | promo_code | amount_paid | payment_method | status | refund_amount | rating |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 5000001 | 100005 | 30000019 | 2024-10-01 05:24:16 | internista | e_recepta | phone | 2024-10-02 23:30:00 | 2024-10-02 23:33:01 | 8 | 89.00 | go | | 44.50 | blik | completed | 0.00 | |
| 5000002 | 100006 | 30000025 | 2024-10-01 06:12:16 | ginekolog | e_recepta | chat | 2024-10-01 06:35:00 | 2024-10-01 06:36:48 | 19 | 119.00 | none | | 119.00 | blik | completed | 0.00 | 4 |
| 5000003 | 100008 | 30000040 | 2024-10-01 07:29:42 | internista | l4 | phone | 2024-10-01 08:15:00 | 2024-10-01 08:19:01 | 9 | 89.00 | promo | START10 | 79.00 | blik | completed | 0.00 | |
| 5000004 | 100009 | 30000043 | 2024-10-01 07:41:14 | dermatolog | konsultacja | phone | 2024-10-01 19:20:00 | 2024-10-01 19:20:50 | 22 | 109.00 | none | | 109.00 | blik | completed | 0.00 | |
| 5000005 | 100013 | 30000071 | 2024-10-01 08:14:49 | internista | e_recepta | video | 2024-10-01 08:25:00 | 2024-10-01 08:29:34 | 6 | 89.00 | none | | 89.00 | blik | completed | 0.00 | |
| 5000008 | 100015 | 30000088 | 2024-10-01 08:47:51 | internista | l4 | phone | 2024-10-01 17:20:00 | 2024-10-01 17:24:54 | 8 | 89.00 | none | | 89.00 | blik | completed | 0.00 | |
| 5000015 | 100016 | 30000108 | 2024-10-01 09:46:19 | endokrynolog | e_recepta | phone | 2024-10-01 10:20:00 | 2024-10-01 10:25:20 | 14 | 119.00 | none | | 119.00 | card | completed | 0.00 | 4 |
| 5000016 | 100017 | 30000110 | 2024-10-01 09:48:39 | psycholog | konsultacja | phone | 2024-10-01 10:00:00 | 2024-10-01 10:02:21 | 22 | 99.00 | none | | 99.00 | card | completed | 0.00 | |

---

## Zasady

- **Nie rób slajdów.** Pokaż to, na czym faktycznie pracujesz.
- **Pracuj z AI tak, jak pracujesz na co dzień.** Nie oceniamy wyboru narzędzi. Oceniamy wnioski, to, co zbudujesz, i sposób, w jaki do tego dojdziesz.
- **Nie pytaj nas o definicje.** Jeśli czegoś brakuje, przyjmij założenie i je nazwij. Tak samo będzie w tej pracy.
- **Jeśli coś w danych wygląda podejrzanie, powiedz o tym.** To też jest odpowiedź.
- **Dane są wygenerowane na potrzeby tego zadania.** Nie opisują prawdziwych pacjentów ani prawdziwych wyników Telemedi; skala, kampanie i koszty są fikcyjne. Możesz z nimi zrobić, co chcesz.

---

Telemedi · B2C · zadanie rekrutacyjne
