# Kohorty dzienne

SQL: `sql/10_cohorts_daily.sql` (wymaga `00_raw_views.sql` i `03_audit_base.sql`).
Wynik dla narzędzia: `tool/data/cohorts_daily.csv`, 730 wierszy po jednym na dzień, wyłącznie agregaty.

## Definicje

| pojęcie | definicja | źródło |
|---|---|---|
| baza | zamówienia bez duplikatów i bez kont testowych | A8, A11 |
| kohorta | dzień polski pierwszego nieanulowanego zamówienia; pacjent z samymi anulowanymi zamówieniami nie jest pacjentem | Q1 a2, A4 |
| t0 | moment płatności zamówienia otwierającego kohortę | A10 |
| powrót w W dniach | inne nieanulowane zamówienie pacjenta w [t0, t0 + W) | Q4 b |
| przychód netto w W dniach | suma `amount_paid − refund_amount` wszystkich zamówień pacjenta w [t0, t0 + W) **łącznie z zamówieniem otwierającym**, plus opłaty GO kupione w tym oknie | decyzja, A3 |
| marża w W dniach | przychód netto minus koszt lekarza za wizyty odbyte (`completed`, `refunded`), zamówione w oknie: internista 25 zł, psychiatra 200 zł, pozostali 100 zł | A1, A2, A10 |
| koszt pozyskania | **nie** jest odejmowany. CAC liczymy osobno na kanał i okres, bo wydatek z danego dnia nie przekłada się na pacjentów z tego dnia | decyzja |
| pełne okno | dzień kohorty d ≤ 30.09.2026 − W; dni bez pełnego okna mają w danej metryce wartość pustą, nie zero | decyzja |

Zamówienia sprzed t0 (anulowane przed pierwszym opłaconym) nie wchodzą do okna kohorty.

| okno | ostatni dzień kohorty | liczba dni z pełnym oknem |
|---|---|--:|
| 30 dni | 2026-08-31 | 700 |
| 90 dni | 2026-07-02 | 640 |
| 180 dni | 2026-04-03 | 550 |

## Kolumny `cohorts_daily.csv`

`cohort_day`, `okres` (P1/P2), `nowi`. Dla W = 30, 90, 180: `powrot_W_licznik`, `powrot_W_mianownik`, `powrot_W_pct`. Dla W = 90, 180: `netto_W_zl`, `netto_W_na_pacjenta_zl`, `marza_W_zl`, `marza_W_na_pacjenta_zl`.

## Kontrole

| # | kontrola | wynik |
|---|---|---|
| K1 | liczba dni i suma nowych | 730 dni (2024-10-01 … 2026-09-30), 39 486 = 15 679 (P1) + 23 807 (P2), zgodnie z mostem. Nowych na dzień: min 16, mediana 52, max 109 |
| K2 | granice pełnego okna | jak w tabeli wyżej; w dniach z pełnym oknem 90 mianownik = liczba nowych (0 rozbieżności) |
| K3 | powrót 90 dni dwiema drogami (suma po dniach vs bezpośrednio na pacjentach) | P1: 3 745 / 15 679 po obu stronach; P2: 3 243 / 18 280 po obu stronach |
| K4 | przychód netto 90 dni z kohort vs suma zamówień i GO w oknach liczona od strony zamówień | 4 251 053,40 zł po obu stronach |
| W | ręczne przeliczenie pacjentów | 2 losowych + 2 dobranych (trudne przypadki): zgodne, szczegóły niżej |

**Ręczne przeliczenie.** Pacjentów losuje się powtarzalnie po `hash(user_id || 'telemedi-2026')` spośród kohort z pełnym oknem 180 dni. Identyfikatory i zamówienia tych pacjentów są tylko w wyniku zapytań W1–W3 i D3–D5, nie w narzędziu. Przypadki:
- **2 losowi pacjenci:** każdy ma jedno zamówienie (kardiolog 109 zł; internista 89 zł). Bez powrotu w żadnym oknie. Marża 109 − 100 = 9 zł i 89 − 25 = 64 zł we wszystkich oknach. Zgodne z SQL.
- **Dobrany D1** (GO, zwrot `refunded`, powroty; 5 wizyt u internisty):
  - 30 dni: 2 zamówienia → netto 178, koszt 50, marża 128, powrót tak,
  - 90 dni: 3 zamówienia → 267 / 75 / 192,
  - 180 dni: kolejne zamówienie z rabatem GO 44,50 zł, zakup GO 89 zł w tym samym momencie i wizyta `refunded` 44,50 − 44,50 = 0 → netto 311,50 + 89 = 400,50, koszt 5 × 25 = 125 (wizyta `refunded` też kosztuje), marża 275,50.

  Zgodne z SQL.
- **Dobrany D2** (anulowane zamówienie 61 dni przed pierwszym opłaconym):
  - anulowane zamówienie nie wchodzi do kohorty, a dzień kohorty to dzień pierwszego opłaconego,
  - 30 dni: netto 89, marża 64, bez powrotu,
  - 90 i 180 dni: kolejne zamówienie po 74 dniach → 178 / 50 / 128, powrót tak.

  Zgodne z SQL.

Dobrani pacjenci to dodatek do Twojej prośby. Obaj losowi mieli po jednym zamówieniu, więc sprawdzali tylko najprostszy przypadek.

## Przegląd P1 vs P2 (ważone liczbą pacjentów, tylko kohorty z pełnym oknem)

| okres | nowi | powrót 30 | powrót 90 | powrót 180 | netto 90 / pacjent | marża 90 / pacjent | netto 180 / pacjent | marża 180 / pacjent |
|---|--:|--:|--:|--:|--:|--:|--:|--:|
| P1 | 15 679 | 10,86% | 23,89% | 27,48% | 134,33 zł | 68,61 zł | 154,37 zł | 78,27 zł |
| P2 | 23 807 | 7,89% | 17,74% | 22,74% | 117,34 zł | 60,29 zł | 137,14 zł | 69,88 zł |

W P2 okna 90 i 180 dni obejmują tylko część kohort: przy 90 dniach 18 280 z 23 807 pacjentów (kohorty do 2026-07-02), przy 180 dniach kohorty do 2026-04-03. Mianowniki dla każdego okna są w kolumnach `powrot_W_mianownik`.
