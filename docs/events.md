# Zdarzenia: dni, w których coś się trwale zmieniło

SQL:
- `sql/11_daily_series.sql`: szeregi dzienne w segmentach,
- `sql/12_change_points.sql`: wykrywanie, placebo, kalendarz,
- `sql/12b_placebo_diag.sql`, `sql/12c_power_diag.sql`, `sql/12d_yoy.sql`: diagnostyka.

Dane dla narzędzia: `tool/data/daily_series.csv` (369 784 wierszy, 27 MB), `tool/data/change_points.csv`, `tool/data/calendar.csv`. Wyłącznie agregaty.

## Metoda (w skrócie)

- **Szeregi.** 17 metryk × segmenty (jeden wymiar naraz: urządzenie, przeglądarka, typ przeglądarki, źródło, strona wejścia), razem 544 szeregi (w tym 9 szeregów wydatków na kampanie). Baza A8 + A11, dzień polski.
  - Lejek liczony po sesjach. Krok „konto” = `account_completed` albo `user_id` w sesji.
  - Kohorty według Q1 a2 i Q4 b. Źródło kohorty według lnd, a pozostałe segmenty z sesji zamówienia otwierającego.
  - Zamówienia (L4, zwroty) z sesji zamówienia.
- **Porównanie okien.** Dla każdego dnia: średnia z 28 dni przed i 28 dni od tego dnia. Okno ma każdy dzień tygodnia dokładnie 4 razy.
- **Szum.** Mediana bezwzględnych różnic tydzień do tygodnia (MAD), czyli bez dnia tygodnia i odporna na zmianę poziomu.
- **Progi:** |z| ≥ 5, zmiana ≥ 15%, dla odsetków ≥ 1 pp, wolumen ≥ 20 dziennie.
- **Trwałość.** Okno od 29. do 56. dnia musi mieć ten sam kierunek i co najmniej połowę efektu.
- **Placebo.** Dni wymieszane w obrębie dnia tygodnia, 3 ziarna:

| zbiór | wykrycia | trwałe |
|---|--:|--:|
| dane | 91 | 89 |
| placebo 1 / 2 / 3 | 1 / 0 / 0 | 1 / 0 / 0 |

Przy tych progach fałszywych alarmów jest średnio ok. 0,3 na przebieg. **Korekta w trakcie:** pierwsze placebo dało 11–47 fałszywych wykryć. Pochodziły z szeregów TikToka, które przez cały P1 miały zera. Teraz każdy szereg zaczyna się od pierwszego dnia z danymi, a sam start widać w kalendarzu.

## Kalendarz (w środku okresu)

| dzień | wpis |
|---|---|
| 2025-11-03 | start kampanii `meta_prosp_l4_szybko` |
| 2025-11-04 | pierwsze użycie kodu `L4SZYBKO20` |
| 2026-02-09 | start kampanii `tt_prosp_l4_15min` |
| 2026-02-10 | pierwsze użycie kodu `TIKTOK25` |

Żadna kampania ani kod nie kończy się w środku okresu. Wykryte zmiany poziomu dziennych wydatków (ta sama metoda):

| kampania | dzień | przed (zł/dzień) | po | zmiana | z |
|---|---|--:|--:|--:|--:|
| google / gs_generic_l4 | 2025-05-01 | 219,87 | 163,72 | −25,5% | −5,1 |
| google / gs_brand | 2025-11-17 | 44,39 | 57,93 | +30,5% | 6,0 |
| google / gs_brand | 2026-01-08 | 56,78 | 73,32 | +29,1% | 7,3 |
| meta / meta_prosp_l4_szybko | 2026-01-10 | 297,94 | 492,67 | +65,4% | 9,0 |
| tiktok / tt_prosp_l4_15min | 2026-03-26 | 200,99 | 373,55 | +85,8% | 12,3 |
| meta / meta_rmkt_koszyk | 2026-04-21 | 43,34 | 33,32 | −23,1% | −5,3 |
| google / gs_brand | 2026-08-26 | 58,26 | 71,27 | +22,3% | 5,7 (bez okna trwałości) |

## Wykrycia (progi spełnione)

Kandydatów z różnych szeregów w odstępie ≤ 3 dni łączę w jedno zdarzenie. Pełna lista (77 wierszy w segmentach i 6 w całości) jest w `tool/data/change_points.csv`.

| zdarzenie | dni | co | w całości (przed → po, średnio dziennie) | rok wcześniej (te same okna) | kalendarz |
|---|---|---|---|---|---|
| 11 | 30.10–03.11.2025 | sesje +26,4% (z 14,3), nowi +29,9% (z 6,5). W segmentach: Chrome, google/cpc i organic, `/lekarz-online`. **Na `/zwolnienie-l4-online` spada konwersja:** sesja → usługa −19,5%, sesja → płatność −32% | sesje 13 208 → 16 693 (471,7 → 596,2); nowi 1 200 → 1 559 (42,9 → 55,7) | sesje +16,9%, nowi +15,6% | start `meta_prosp_l4_szybko` (03.11), `L4SZYBKO20` (04.11) |
| 13 | 11–21.11.2025 | ruch z Meta i przeglądarek w aplikacji: meta/paid_social +85%, Instagram +92%, `/zwolnienie-l4-online` +122% (z 25,1), mobile +27,5%; nowi pacjenci na mobile +29% | — | — | `L4SZYBKO20`; `gs_brand` +30,5% wydatków (17.11) |
| 16 | 02–12.01.2026 | nowi +35,3% (z 10,2), sesje w wielu segmentach +17–43% (meta/paid_social +43%) | nowi 1 594 → 2 156 (56,9 → 77,0) | nowi +13,0% | `meta_prosp_l4_szybko` +65% wydatków (10.01), `gs_brand` +29% (08.01) |
| 17 | 20–21.01.2026 | sesje +23,2% (z 19,1); przeglądarki w aplikacji +45%, mobile +26% | sesje 19 939 → 24 572 (712,1 → 877,6) | sesje +13,3% | jak wyżej |
| 19 | 09.02.2026 | sesje `/zwolnienie-l4-online` +34% (z 29,4) | — | — | start `tt_prosp_l4_15min` (09.02), `TIKTOK25` (10.02) |
| 21 | 24–26.03.2026 | TikTok +72% sesji, przeglądarki w aplikacji +19% | — | — | `tt_prosp_l4_15min` +86% wydatków (26.03) |
| 22–24 | 07.04–30.04.2026 | nowi w zwykłych przeglądarkach −22%; sesje direct −16%, organic −20%, Safari i desktop −16%, blog −27% | — | spadek sesji wiosną także rok wcześniej (−11%) | `meta_rmkt_koszyk` −23% (21.04) |
| 1–9 | X 2024 – IX 2025 | wzrosty i spadki sesji w zwykłych segmentach (listopad, styczeń, maj), pojedyncze sygnały lejka w małych segmentach (Firefox, w aplikacji w VII 2025) | sesje +15,6% (24.11.2024), +15,6% (19.01.2025) | — | brak wpisów |

## Czego metoda nie wykryła na progach, a co jest w danych

**Zmiany jakości są stopniowe, nie skokowe.** W całości żadna metryka powrotu, marży, L4, zwrotów ani konwersji lejka nie przekracza |z| = 5. Najsilniejsze sygnały (bez progów, `sql/12c_power_diag.sql`) skupiają się wokół listopada 2025. Rok wcześniej w tych samych oknach takiej zmiany nie ma:

| metryka | dzień | przed → po (28 / 28 dni) | zmiana | z | rok wcześniej | z rok wcześniej |
|---|---|---|--:|--:|--:|--:|
| marża 90 dni na pacjenta | 2025-11-01 | 71,24 → 64,18 zł | −9,9% | −3,8 | −1,3% | −0,5 |
| sesja → płatność | 2025-11-15 | 16,67% → 14,78% | −11,3% | −4,8 | +6,5% | 2,1 |
| powrót 90 dni | 2025-11-18 | 24,20% → 18,90% | −21,9% | −3,4 | +6,9% | 1,0 |
| L4 w pierwszym zamówieniu | 2025-11-19 | 22,56% → 30,52% | +35,3% | 4,6 | +5,6% | 0,7 |
| udział L4 w zamówieniach | 2025-11-26 | 19,62% → 25,61% | +30,5% | 4,8 | −1,3% | −0,2 |
| sesja → usługa | 2025-12-08 | 37,10% → 35,10% | −5,4% | −4,1 | +4,0% | 2,9 |

- **Dlaczego to nie przechodzi progów.** Przy ok. 50 nowych pacjentach dziennie dzienny powrót 90 dni ma szum ok. 5,8 pp. Błąd różnicy okien 28/28 to ok. 1,6 pp, więc nawet spadek o 5,3 pp daje tylko z ≈ 3,4. Próg |z| ≥ 5 wykrywa w tych metrykach tylko zmiany rzędu 8 pp i większe.
- **Moment z III 2026** (dalszy spadek powrotu i marży w widoku miesięcznym) nie ma skoku w żadnej metryce jakości. W tym czasie widać za to zmiany ruchu: TikTok +86% wydatków i +72% sesji od 26.03.
- **Zwroty `refunded`** rosną płynnie od X 2025 do IX 2026 (`docs/audit.md`, H3). Najsilniejszy sygnał skokowy ma z ≈ 2,9.

## Ograniczenia

- **Sezon.** Sesje i nowi pacjenci rosną w listopadzie i styczniu także w P1 (+13–17%). Wykryte skoki w P2 są wyraźnie większe (+23–35%), ale część to sezon. Przy dwóch latach danych nie da się go dokładnie odjąć.
- **Koniec danych.** Metryki kohort kończą się wcześniej: powrót 90 dni i marża 90 dni 2.07.2026, powrót 30 dni 31.08.2026. Wykrycie wymaga 28 dni po zmianie, a trwałość kolejnych 28.
- **Zdarzenie a przyczyna.** Zbieżność daty z kampanią to związek w czasie, nie dowód przyczyny.

## Powtarzalność

Kwoty sumowane są jako DECIMAL, a nie zmiennoprzecinkowo. Dwa kolejne przebiegi `sql/10`–`sql/12` dają identyczne pliki (zgodne sumy MD5 wszystkich CSV w `tool/data/`). Wcześniej kolejność sumowania zmieniała wyniki w ostatnim groszu wartości na pacjenta.

## Lista zdarzeń według siły (`sql/12e_event_list.sql`)

Pogrupowane po dacie, sortowane według największego |z| w grupie.

**Poza lejkiem (sesje, nowi pacjenci):**

| zdarzenie | dni | max \|z\| | najmocniejsze szeregi |
|---|---|--:|---|
| 19 | 09.02.2026 | 29,4 | sesje `/zwolnienie-l4-online` +34% |
| 13 | 11–21.11.2025 | 25,1 | sesje `/zwolnienie-l4-online` +122%, meta/paid_social +85%, w aplikacji +97%, Instagram +92%, mobile +28%; nowi na mobile +29% |
| 17 | 20–21.01.2026 | 22,8 | sesje w aplikacji +45%, wszystkie sesje +23%, mobile +26%, Instagram +37%, Facebook +46% |
| 16 | 02–12.01.2026 | 19,1 | sesje meta/paid_social +43%, zwykłe przeglądarki +20%; **nowi pacjenci +35%** (z 10,2) |
| 21 | 24–26.03.2026 | 18,3 | sesje w aplikacji +19%, TikTok +72%, tiktok/paid_social +70% |
| 11 | 02–03.11.2025 | 14,3 | wszystkie sesje +26%, zwykłe +18%, google/cpc +16%, organic +21%; **nowi pacjenci +30%** (z 6,5) |
| 14 | 25.11.2025 | 12,2 | sesje Facebook +73% |
| 5 | 18–21.01.2025 | 9,8 | sesje Chrome +20%, wszystkie +16% |
| 2 | 21–25.11.2024 | 9,2 | sesje zwykłe +18%, wszystkie +16%, desktop +23%, organic +24% |
| 24 | 30.04.2026 | 8,6 | sesje organic −20%, Safari −16%, desktop −16%, blog −27% |
| 1 | 02–07.11.2024 | 8,5 | sesje Chrome +22%, google/cpc +17%, blog +39% |
| 12 | 07.11.2025 | 8,4 | sesje Safari +24% |
| 22 | 07.04.2026 | 7,0 | nowi w zwykłych przeglądarkach −22% |
| 23 | 11.04.2026 | 6,9 | sesje direct −16% |
| 3 | 03–05.01.2025 | 6,4 | sesje desktop +19%, organic +20%, Edge +37% |
| 15, 18, 6, 4, 7, 9 | pojedyncze dni | 5,1–5,9 | pojedyncze segmenty sesji (blog, `/konto`, Edge, `/recepta-online`, organic, desktop) |

**Kroki lejka (F1–F6):**

| zdarzenie | dni | max \|z\| | co |
|---|---|--:|---|
| 20 | 17.03.2026 | 6,5 | termin → konto, Safari: 74,6% → 61,7% |
| 11 | 30.10–02.11.2025 | 5,9 | `/zwolnienie-l4-online`: sesja → usługa 36,0% → 29,0%, sesja → płatność 14,0% → 9,5% |
| 8 | 11.07.2025 | 5,5 | termin → konto, przeglądarki w aplikacji: 72,8% → 51,5%; sesja → płatność, Firefox: 15,0% → 24,7% |
| 10 | 05.09.2025 | 5,4 | usługa → termin, `/zwolnienie-l4-online`: 58,2% → 70,4% |
| 1 | 30.10.2024 | 5,3 | sesja → płatność, `/konto`: 56,1% → 46,3% |

W całości (segment „wszystko”) żaden krok lejka nie przekracza progu. Najsilniejszy jest sesja → płatność 15.11.2025, −11,3% (z −4,8).
