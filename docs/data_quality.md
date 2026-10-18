# Profil danych (data quality)

Wygenerowane przez `scripts/profile_data.py` (2026-10-18 17:03), DuckDB 1.5.6.
Czasy podane w strefie źródłowej, bez konwersji. Typy wykryte automatycznie przez DuckDB (próbka = cały plik).
Puste = NULL po wczytaniu (DuckDB traktuje pusty łańcuch w CSV jako NULL).

## Pliki

| plik | wiersze | wg zadania | różnica |
|---|--:|--:|--:|
| events_2024h2.csv | 39 510 | 39 510 | 0 |
| events_2025h1.csv | 101 513 | 101 513 | 0 |
| events_2025h2.csv | 109 052 | 109 052 | 0 |
| events_2026h1.csv | 168 991 | 168 991 | 0 |
| events_2026h2.csv | 75 539 | 75 539 | 0 |
| go_memberships.csv | 4 227 | 4 227 | 0 |
| marketing_spend.csv | 5 676 | 5 676 | 0 |
| orders.csv | 65 882 | 65 882 | 0 |
| sessions_2024q4.csv | 38 490 | 38 490 | 0 |
| sessions_2025q1.csv | 46 524 | 46 524 | 0 |
| sessions_2025q2.csv | 40 384 | 40 384 | 0 |
| sessions_2025q3.csv | 37 511 | 37 511 | 0 |
| sessions_2025q4.csv | 52 797 | 52 797 | 0 |
| sessions_2026q1.csv | 80 728 | 80 728 | 0 |
| sessions_2026q2.csv | 84 383 | 84 383 | 0 |
| sessions_2026q3.csv | 78 740 | 78 740 | 0 |
| users.csv | 52 422 | 52 422 | 0 |
| **razem** | **1 082 369** | **1 082 369** | **0** |

Pliki CSV spoza listy z zadania: brak.

## Grupy plików: zgodność układu kolumn

### sessions (8 plików)

Kolumny wzorcowe (sessions_2024q4.csv): `session_id, visitor_id, user_id, started_at_utc, utm_source, utm_medium, utm_campaign, device, os, browser, landing_page`

| plik | kolumny jak wzorzec | typy różne od wzorca | wiersze | min started_at_utc | max started_at_utc |
|---|---|---|--:|---|---|
| sessions_2024q4.csv | tak | — | 38 490 | 2024-09-30 22:01:31 | 2024-12-31 22:55:51 |
| sessions_2025q1.csv | tak | — | 46 524 | 2024-12-31 23:08:01 | 2025-03-31 21:51:31 |
| sessions_2025q2.csv | tak | — | 40 384 | 2025-03-31 22:03:33 | 2025-06-30 21:41:50 |
| sessions_2025q3.csv | tak | — | 37 511 | 2025-06-30 22:13:06 | 2025-09-30 21:57:58 |
| sessions_2025q4.csv | tak | — | 52 797 | 2025-09-30 22:00:58 | 2025-12-31 22:55:13 |
| sessions_2026q1.csv | tak | — | 80 728 | 2025-12-31 23:00:22 | 2026-03-31 21:59:28 |
| sessions_2026q2.csv | tak | — | 84 383 | 2026-03-31 22:00:19 | 2026-06-30 21:59:15 |
| sessions_2026q3.csv | tak | — | 78 740 | 2026-06-30 22:01:41 | 2026-09-30 21:26:12 |

### events (5 plików)

Kolumny wzorcowe (events_2024h2.csv): `session_id, event_name, event_at_utc`

| plik | kolumny jak wzorzec | typy różne od wzorca | wiersze | min event_at_utc | max event_at_utc |
|---|---|---|--:|---|---|
| events_2024h2.csv | tak | — | 39 510 | 2024-09-30 22:14:45 | 2024-12-31 22:56:28 |
| events_2025h1.csv | tak | — | 101 513 | 2024-12-31 23:09:16 | 2025-06-30 21:43:09 |
| events_2025h2.csv | tak | — | 109 052 | 2025-06-30 22:14:41 | 2025-12-31 22:55:28 |
| events_2026h1.csv | tak | — | 168 991 | 2025-12-31 23:29:14 | 2026-06-30 21:54:02 |
| events_2026h2.csv | tak | — | 75 539 | 2026-06-30 22:01:56 | 2026-09-30 21:34:11 |

## Tabele

### users

Pliki: users.csv. Wiersze: **52 422**. Czas: polski.

| kolumna | typ | puste | % pustych | unikalne |
|---|---|--:|--:|--:|
| `user_id` (kluczowa) | BIGINT | 0 | 0.00 | 52 422 |
| `registered_at` (kluczowa) | TIMESTAMP | 0 | 0.00 | 52 387 |
| `birth_year` | BIGINT | 0 | 0.00 | 67 |
| `gender` | VARCHAR | 0 | 0.00 | 2 |
| `region` | VARCHAR | 0 | 0.00 | 16 |
| `city_size` | VARCHAR | 0 | 0.00 | 4 |
| `marketing_consent` | BIGINT | 0 | 0.00 | 2 |

| kolumna czasowa | typ | min | max | niepuste nieparsowalne jako czas |
|---|---|---|---|--:|
| `registered_at` | TIMESTAMP | 2024-10-01 00:18:07 | 2026-09-30 23:32:58 | 0 |

- Wiersze będące pełnym duplikatem innego wiersza (nadmiarowe kopie): **0**
- klucz (user_id): wartości występujące więcej niż raz: **0**, w nich wierszy: **0**

### sessions

Pliki: sessions_2024q4.csv, sessions_2025q1.csv, sessions_2025q2.csv, sessions_2025q3.csv, sessions_2025q4.csv, sessions_2026q1.csv, sessions_2026q2.csv, sessions_2026q3.csv. Wiersze: **459 557**. Czas: UTC.

| kolumna | typ | puste | % pustych | unikalne |
|---|---|--:|--:|--:|
| `session_id` (kluczowa) | BIGINT | 0 | 0.00 | 459 557 |
| `visitor_id` (kluczowa) | VARCHAR | 0 | 0.00 | 365 078 |
| `user_id` (kluczowa) | BIGINT | 354 726 | 77.19 | 52 422 |
| `started_at_utc` (kluczowa) | TIMESTAMP | 0 | 0.00 | 457 193 |
| `utm_source` | VARCHAR | 61 245 | 13.33 | 8 |
| `utm_medium` | VARCHAR | 61 245 | 13.33 | 7 |
| `utm_campaign` | VARCHAR | 163 903 | 35.67 | 14 |
| `device` | VARCHAR | 0 | 0.00 | 3 |
| `os` | VARCHAR | 0 | 0.00 | 5 |
| `browser` | VARCHAR | 0 | 0.00 | 9 |
| `landing_page` | VARCHAR | 0 | 0.00 | 21 |

| kolumna czasowa | typ | min | max | niepuste nieparsowalne jako czas |
|---|---|---|---|--:|
| `started_at_utc` | TIMESTAMP | 2024-09-30 22:01:31 | 2026-09-30 21:26:12 | 0 |

- Wiersze będące pełnym duplikatem innego wiersza (nadmiarowe kopie): **0**
- klucz (session_id): wartości występujące więcej niż raz: **0**, w nich wierszy: **0**

### events

Pliki: events_2024h2.csv, events_2025h1.csv, events_2025h2.csv, events_2026h1.csv, events_2026h2.csv. Wiersze: **494 605**. Czas: UTC.

| kolumna | typ | puste | % pustych | unikalne |
|---|---|--:|--:|--:|
| `session_id` (kluczowa) | BIGINT | 0 | 0.00 | 162 033 |
| `event_name` (kluczowa) | VARCHAR | 0 | 0.00 | 5 |
| `event_at_utc` (kluczowa) | TIMESTAMP | 0 | 0.00 | 492 142 |

| kolumna czasowa | typ | min | max | niepuste nieparsowalne jako czas |
|---|---|---|---|--:|
| `event_at_utc` | TIMESTAMP | 2024-09-30 22:14:45 | 2026-09-30 21:34:11 | 0 |

- Wiersze będące pełnym duplikatem innego wiersza (nadmiarowe kopie): **0**
- kombinacja (session_id, event_name): wartości występujące więcej niż raz: **0**, w nich wierszy: **0**
- Tabela nie ma własnego klucza.

### orders

Pliki: orders.csv. Wiersze: **65 882**. Czas: polski.

| kolumna | typ | puste | % pustych | unikalne |
|---|---|--:|--:|--:|
| `order_id` (kluczowa) | BIGINT | 0 | 0.00 | 65 278 |
| `user_id` (kluczowa) | BIGINT | 0 | 0.00 | 40 940 |
| `session_id` (kluczowa) | BIGINT | 0 | 0.00 | 65 278 |
| `created_at` (kluczowa) | TIMESTAMP | 0 | 0.00 | 65 246 |
| `specialization` | VARCHAR | 0 | 0.00 | 10 |
| `visit_purpose` | VARCHAR | 0 | 0.00 | 4 |
| `consultation_mode` | VARCHAR | 0 | 0.00 | 3 |
| `scheduled_at` | TIMESTAMP | 0 | 0.00 | 53 610 |
| `started_at` | TIMESTAMP | 4 185 | 6.35 | 61 043 |
| `duration_min` | BIGINT | 4 185 | 6.35 | 35 |
| `list_price` | DOUBLE | 0 | 0.00 | 6 |
| `discount_type` | VARCHAR | 0 | 0.00 | 3 |
| `promo_code` | VARCHAR | 54 423 | 82.61 | 6 |
| `amount_paid` (kluczowa) | DOUBLE | 0 | 0.00 | 28 |
| `payment_method` | VARCHAR | 0 | 0.00 | 3 |
| `status` (kluczowa) | VARCHAR | 0 | 0.00 | 4 |
| `refund_amount` | DOUBLE | 0 | 0.00 | 27 |
| `rating` | BIGINT | 47 043 | 71.40 | 5 |

| kolumna czasowa | typ | min | max | niepuste nieparsowalne jako czas |
|---|---|---|---|--:|
| `created_at` | TIMESTAMP | 2024-10-01 05:24:16 | 2026-09-30 23:34:11 | 0 |
| `scheduled_at` | TIMESTAMP | 2024-10-01 06:35:00 | 2026-10-02 23:00:00 | 0 |
| `started_at` | TIMESTAMP | 2024-10-01 06:36:48 | 2026-10-02 23:06:31 | 0 |

- Wiersze będące pełnym duplikatem innego wiersza (nadmiarowe kopie): **604**
- klucz (order_id): wartości występujące więcej niż raz: **604**, w nich wierszy: **1 208**

### go_memberships

Pliki: go_memberships.csv. Wiersze: **4 227**. Czas: polski.

| kolumna | typ | puste | % pustych | unikalne |
|---|---|--:|--:|--:|
| `membership_id` (kluczowa) | BIGINT | 0 | 0.00 | 4 227 |
| `user_id` (kluczowa) | BIGINT | 0 | 0.00 | 4 142 |
| `purchased_at` (kluczowa) | TIMESTAMP | 0 | 0.00 | 4 226 |
| `valid_until` (kluczowa) | DATE | 0 | 0.00 | 720 |
| `amount_paid` | DOUBLE | 0 | 0.00 | 1 |
| `order_id` | BIGINT | 686 | 16.23 | 3 541 |
| `session_id` (kluczowa) | BIGINT | 0 | 0.00 | 4 227 |

| kolumna czasowa | typ | min | max | niepuste nieparsowalne jako czas |
|---|---|---|---|--:|
| `purchased_at` | TIMESTAMP | 2024-10-01 05:24:16 | 2026-09-30 20:48:08 | 0 |
| `valid_until` | DATE | 2025-10-01 | 2027-09-30 | 0 |

- Wiersze będące pełnym duplikatem innego wiersza (nadmiarowe kopie): **0**
- klucz (membership_id): wartości występujące więcej niż raz: **0**, w nich wierszy: **0**

### marketing_spend

Pliki: marketing_spend.csv. Wiersze: **5 676**. Czas: polski (data).

| kolumna | typ | puste | % pustych | unikalne |
|---|---|--:|--:|--:|
| `date` (kluczowa) | DATE | 0 | 0.00 | 730 |
| `utm_source` (kluczowa) | VARCHAR | 0 | 0.00 | 3 |
| `utm_medium` (kluczowa) | VARCHAR | 0 | 0.00 | 2 |
| `utm_campaign` (kluczowa) | VARCHAR | 0 | 0.00 | 9 |
| `impressions` | BIGINT | 0 | 0.00 | 2 405 |
| `clicks` | BIGINT | 0 | 0.00 | 292 |
| `spend_pln` (kluczowa) | DOUBLE | 0 | 0.00 | 5 238 |

| kolumna czasowa | typ | min | max | niepuste nieparsowalne jako czas |
|---|---|---|---|--:|
| `date` | DATE | 2024-10-01 | 2026-09-30 | 0 |

- Wiersze będące pełnym duplikatem innego wiersza (nadmiarowe kopie): **0**
- klucz (date, utm_source, utm_medium, utm_campaign): wartości występujące więcej niż raz: **0**, w nich wierszy: **0**

## Wygląda podejrzanie

Sekcja pisana ręcznie, skrypt jej nie nadpisuje. Same obserwacje z danych, bez wniosków biznesowych.
Liczby z dodatkowych zapytań kontrolnych (poza tabelami powyżej) są oznaczone jako „kontrola”.

1. **`orders`: 604 zamówienia występują dwa razy, jako identyczne kopie.** 604 wartości `order_id` mają po 2 wiersze (1 208 wierszy), a 604 wiersze są pełnymi duplikatami. Żadne zamówienie nie ma więcej niż 2 kopie (kontrola). Wszystkie duplikaty mają `created_at` od 2026-06-10 00:07 do 2026-06-24 23:59 (kontrola). Duplikaty są więc skupione w ok. 2 tygodniach czerwca 2026, a nie rozproszone. Po deduplikacji: 65 882 → 65 278 zamówień. Ta okolica czasu jest w okresie porównywanym na dashboardzie (X 2025 – IX 2026).
2. **Sesje mają źródło bez kampanii.** 102 658 sesji ma `utm_source` i `utm_medium`, ale puste `utm_campaign` (kontrola): `google / organic` 88 698, `rankinglekarzy / affiliate` 10 016, `bing / organic` 3 944. Dla ruchu organicznego to normalne. Dla afiliacji oznacza, że kampanii afiliacyjnej nie da się rozróżnić.
3. **Podział plików nie odpowiada kolumnom UTC.** Pliki `sessions_*` i `events_*` są podzielone według kalendarza polskiego, a nie UTC. Np. `sessions_2024q4` kończy się 2024-12-31 22:55 UTC (23:55 w Polsce), a `sessions_2025q1` zaczyna się 2024-12-31 23:08 UTC (00:08 w Polsce). Granice przesuwają się z czasem letnim (22:00 UTC latem, 23:00 zimą). Nie ma luk ani nakładania się. Przy łączeniu nie trzeba nic poprawiać, ale filtrowanie po dacie UTC da inne wyniki niż po nazwie pliku.
4. **`go_memberships`: 85 pacjentów ma po 2 członkostwa** (4 057 ma jedno; kontrola). Do sprawdzenia w audycie, czy okresy ważności się nakładają (zakup nowego GO w trakcie ważnego).
5. **`orders.scheduled_at` i `started_at` wychodzą poza okres danych.** Max to 2026-10-02, czyli dwa dni po 30.09.2026. Wygląda na wizyty umówione przed końcem okresu na termin po nim. Notuję, bo filtry po `scheduled_at` lub `started_at` dadzą inny zakres niż po `created_at`.

Sprawdzone i bez zastrzeżeń:
- suma wierszy zgodna z zadaniem: 1 082 369, każdy plik zgodny co do wiersza,
- układ kolumn identyczny we wszystkich 8 plikach `sessions` i wszystkich 5 plikach `events`, typy też,
- brak powtórzeń kluczy w `users`, `sessions`, `go_memberships`, `marketing_spend`,
- w `events` żadna sesja nie ma dwa razy tego samego kroku,
- wszystkie kolumny czasowe parsują się jako czas,
- puste `started_at` / `duration_min` (4 185) to dokładnie `cancelled` (2 590) + `no_show` (1 595). Statusy `completed` i `refunded` mają wszystkie `started_at` (kontrola, liczone z duplikatami),
- `utm_source` i `utm_medium` są puste zawsze razem (61 245 sesji); to wejścia bezpośrednie wg README.
