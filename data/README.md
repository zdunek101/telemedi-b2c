# Telemedi B2C: dane do zadania rekrutacyjnego

Dane są wygenerowane na potrzeby zadania. Nie opisują prawdziwych pacjentów ani prawdziwych wyników Telemedi. Skala, kampanie i koszty są fikcyjne; ceny katalogowe i zasady TelemediGO odpowiadają publicznemu cennikowi.

Okres: 1 października 2024 – 30 września 2026 (24 miesiące). Zbiór zaczyna się od zera: przyjmij, że 1 października 2024 to pierwszy dzień sprzedaży i wcześniejszej historii nie ma. Eksport jest surowy: nic nie zostało policzone, odfiltrowane ani zdeduplikowane.

## Pliki

| Plik | Jeden wiersz to | Czas |
|---|---|---|
| `users.csv` | konto pacjenta | polski |
| `sessions_2024q4.csv` … `sessions_2026q3.csv` | sesja na telemedi.com (eksport kwartalny, 8 plików) | UTC |
| `events_2024h2.csv` … `events_2026h2.csv` | zdarzenie lejka zakupowego (eksport półroczny, 5 plików) | UTC |
| `orders.csv` | opłacone zamówienie konsultacji | polski |
| `go_memberships.csv` | zakup TelemediGO | polski |
| `marketing_spend.csv` | dzień × kampania płatna za klik | data |

Sesje i zdarzenia pochodzą z analityki strony i mają czas w UTC (kolumny `*_utc`). Pozostałe tabele pochodzą z systemu transakcyjnego i mają czas polski (Europe/Warsaw).

## users.csv

- `user_id`: identyfikator konta
- `registered_at`: moment założenia konta
- `birth_year`: rok urodzenia
- `gender`: K lub M
- `region`: województwo
- `city_size`: `wies`, `miasto_do_50k`, `miasto_50_200k`, `miasto_pow_200k`
- `marketing_consent`: 1, jeśli pacjent zgodził się na komunikację marketingową

## sessions_*.csv

- `session_id`: identyfikator sesji
- `visitor_id`: identyfikator przeglądarki (cookie). Ten sam pacjent może mieć kilka, jeśli zmienia urządzenie albo czyści dane
- `user_id`: wypełnione tylko wtedy, gdy pacjent był w tej sesji zalogowany. Pacjent, który wszedł już zalogowany, ma `user_id` bez zdarzenia `account_completed`
- `started_at_utc`: początek sesji
- `utm_source`, `utm_medium`, `utm_campaign`: źródło wejścia. Wszystkie trzy puste oznaczają wejście bezpośrednie
- `device`: `mobile`, `desktop`, `tablet`
- `os`, `browser`: system i przeglądarka. `Instagram`, `Facebook` i `TikTok` to przeglądarki wbudowane w aplikacje
- `landing_page`: pierwsza strona sesji

## events_*.csv

- `session_id`
- `event_name`: jeden z pięciu kroków, w kolejności
  1. `service_selected`: wybór usługi
  2. `slot_selected`: wybór terminu
  3. `account_completed`: zalogowanie albo założenie konta
  4. `payment_started`: wejście na płatność
  5. `payment_succeeded`: płatność przyjęta (za konsultację albo za samo TelemediGO)
- `event_at_utc`

Sesja bez żadnego zdarzenia to sesja, w której pacjent nie wybrał usługi. Zakup samego TelemediGO ma tylko dwa ostatnie kroki.

Źródła pozyskania pacjenta nie ma w żadnej tabeli. Trzeba je wyprowadzić z sesji i samemu zdecydować, jak je przypisać.

## orders.csv

- `order_id`
- `user_id`
- `session_id`: sesja, w której zapłacono
- `created_at`: moment płatności
- `specialization`: `internista`, `pediatra`, `dermatolog`, `ginekolog`, `psychiatra`, `kardiolog`, `endokrynolog`, `urolog`, `neurolog`, `psycholog`
- `visit_purpose`: `konsultacja`, `e_recepta`, `l4`, `skierowanie`
- `consultation_mode`: `phone`, `chat`, `video`
- `scheduled_at`: termin, na który pacjent umówił wizytę
- `started_at`: moment, w którym lekarz faktycznie rozpoczął wizytę. Puste, jeśli wizyta się nie odbyła
- `duration_min`: czas trwania wizyty
- `list_price`: cena katalogowa
- `discount_type`: `none`, `go` (zniżka TelemediGO), `promo` (kod rabatowy)
- `promo_code`: użyty kod
- `amount_paid`: kwota zapłacona za konsultację. Nie zawiera opłaty za TelemediGO, ta jest w `go_memberships.csv`
- `payment_method`: `blik`, `card`, `transfer`
- `status`:
  - `completed`: wizyta odbyta
  - `cancelled`: anulowana przed wizytą, pełny zwrot
  - `no_show`: pacjent nie odebrał, bez zwrotu
  - `refunded`: wizyta odbyta, opłata zwrócona po wizycie (na przykład lekarz nie stwierdził wskazań)
- `refund_amount`: kwota zwrotu
- `rating`: ocena wizyty 1–5. Większość pacjentów nie ocenia

## go_memberships.csv

TelemediGO to program zniżkowy: jednorazowa opłata 89 zł za 12 miesięcy. Daje 50% zniżki na wizyty u internisty (w tym e-receptę, L4 i skierowanie) oraz 20% na pozostałych specjalistów. Pacjent kupuje je przy kasie razem z konsultacją albo osobno. Członkostwo nie odnawia się samo.

- `membership_id`
- `user_id`
- `purchased_at`: moment zakupu
- `valid_until`: ostatni dzień ważności
- `amount_paid`: 89.00
- `order_id`: zamówienie, przy którym kupiono GO. Puste, jeśli GO kupiono osobno
- `session_id`: sesja zakupu

## marketing_spend.csv

- `date`: dzień według czasu polskiego
- `utm_source`, `utm_medium`, `utm_campaign`: jak w sesjach
- `impressions`, `clicks`
- `spend_pln`: koszt netto

Tabela obejmuje tylko kampanie rozliczane za klik (Google Ads, Meta, TikTok). Poza nią:

- afiliacja (`utm_medium = affiliate`): prowizja 25 zł za każde pierwsze opłacone zamówienie pacjenta, także wtedy, gdy zostało potem anulowane albo zwrócone
- e-mail i SMS: koszt pomijalny
- program poleceń: bez kosztu w danych

## Czego w danych nie ma

Kosztu lekarza. Jeśli liczysz marżę, przyjmij za każdą odbytą wizytę 25 zł u internisty, 200 zł u psychiatry i 100 zł u każdego innego specjalisty. Lekarz dostaje wynagrodzenie za każdą wizytę, która się odbyła (`completed` i `refunded`), także wtedy, gdy zwróciliśmy pacjentowi opłatę. Za `cancelled` i `no_show` kosztu lekarza nie ma.

Nie ma też listy zmian w produkcie ani kalendarza kampanii. Co się wydarzyło i kiedy, trzeba odczytać z danych.
