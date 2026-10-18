# Spadek powrotu i marży od XI 2025: mieszanka czy zmiana wewnątrz źródeł

SQL: `sql/13_mix_by_source.sql`. Kohorty Q1 a2, powrót Q4 b (90 dni), marża 90 dni bez kosztu pozyskania, źródło według lnd (Q3). Tylko kohorty z pełnym oknem 90 dni (do 2.07.2026).
Okresy kohort: **A** = X 2024 – X 2025, **B** = XI 2025 – II 2026, **C** = III 2026 – 2.07.2026.

| okres | pacjenci | powrót 90 | marża 90 / pacjent |
|---|--:|--:|--:|
| A | 17 004 | 23,91% | 68,80 zł |
| B | 8 014 | 19,95% | 63,10 zł |
| C | 8 941 | 14,81% | 56,18 zł |

## 1. Na poziomie źródeł mieszanka nie wystarcza

Rozkład zmiany na efekt mieszanki (zmiana udziałów źródeł przy starych wartościach), efekt wewnątrz źródeł (zmiana wartości przy starych udziałach) i interakcję:

| zmiana | metryka | całkowita | mieszanka | wewnątrz źródeł | interakcja |
|---|---|--:|--:|--:|--:|
| A → B | powrót 90 | −3,95 pp | −0,16 pp | −2,22 pp | −1,56 pp |
| B → C | powrót 90 | −5,14 pp | −2,50 pp | −3,00 pp | +0,36 pp |
| A → C | powrót 90 | −9,10 pp | −2,30 pp | −5,37 pp | −1,42 pp |
| A → B | marża 90 | −5,70 zł | −0,06 zł | −3,14 zł | −2,49 zł |
| B → C | marża 90 | −6,92 zł | −4,35 zł | −3,03 zł | +0,47 zł |
| A → C | marża 90 | −12,61 zł | −3,49 zł | −6,08 zł | −3,05 zł |

Główna przyczyna to jedno źródło, które zmieniło się od środka: **meta / paid_social**. Powrót: A 23,4% (428 / 1 830), B 9,9% (186 / 1 871), C 8,3% (205 / 2 472). Marża: 69,15 → 48,50 → 45,10 zł.

## 2. Na poziomie kampanii to mieszanka: nowe kampanie L4

| źródło / kampania | okres | pacjenci | powrót 90 | marża 90 / pacjent |
|---|---|--:|--:|--:|
| meta / `meta_prosp_l4_szybko` (od 3.11.2025) | B | 1 126 | 5,1% | 39,93 zł |
| | C | 1 763 | 4,7% | 38,52 zł |
| tiktok / `tt_prosp_l4_15min` (od 9.02.2026) | B | 49 | 4,1% | 33,04 zł |
| | C | 948 | 3,1% | 34,61 zł |
| meta / `meta_prosp_lekarz_online` | A → B → C | 889 → 335 → 284 | 21,3% → 16,7% → 16,5% | 68,06 → 64,25 → 63,17 zł |
| meta / `meta_rmkt_koszyk` | A → B → C | 941 → 410 → 425 | 25,4% → 17,8% → 17,9% | 70,18 → 59,14 → 60,34 zł |
| google / `gs_brand` | A → B → C | 2 676 → 1 159 → 1 143 | 24,8% → 23,1% → 18,7% | 68,74 → 68,23 → 61,38 zł |
| google / `gs_generic_erecepta` | A → B → C | 1 366 → 458 → 439 | 31,0% → 29,7% → 27,8% | 79,40 → 80,32 → 78,21 zł |
| google / `gs_generic_l4` | A → B → C | 1 155 → 390 → 363 | 16,2% → 14,9% → 17,4% | 67,68 → 68,60 → 70,62 zł |
| google / `gs_generic_lekarz_online` | A → B → C | 1 554 → 561 → 420 | 23,0% → 22,8% → 20,2% | 68,36 → 69,04 → 67,49 zł |
| google / `gs_generic_specjalisci` | A → B → C | 696 → 281 → 254 | 23,4% → 17,1% → 19,3% | 34,24 → 29,76 → 36,45 zł |

Pacjenci bez kampanii L4 (`meta_prosp_l4_szybko`, `tt_prosp_l4_15min`) i bez kodów `L4SZYBKO20` / `TIKTOK25`:

| okres | wszyscy: powrót / marża | bez kampanii i kodów L4: pacjenci | powrót 90 | marża 90 / pacjent |
|---|---|--:|--:|--:|
| A | 23,91% / 68,80 zł | 17 004 | 23,91% | 68,80 zł |
| B | 19,95% / 63,10 zł | 6 672 | 22,95% | 67,88 zł |
| C | 14,81% / 56,18 zł | 5 778 | 20,77% | 67,11 zł |

- **Marża** bez kampanii L4 jest prawie stabilna: 68,80 → 67,88 → 67,11 zł. Spadek marży to efekt mieszanki. Pacjenci z kampanii L4 mają marżę ok. 34–40 zł.
- **Powrót** bez kampanii L4 w B spada tylko o 1,0 pp (z −4,0 pp w całości), więc w B to głównie mieszanka. W C spada o 3,1 pp (z −9,1 pp w całości). Ta część **nie jest** mieszanką.

## 3. Co zostaje po odjęciu mieszanki (wiosna 2026)

Te same miesiące kalendarzowe (III–VI) w 2025 i 2026, pacjenci spoza kampanii i kodów L4, żeby ominąć sezon:

| rok | pierwsza wizyta | pacjenci | udział | powrót 90 | marża 90 / pacjent |
|---|---|--:|--:|--:|--:|
| 2025 | nie L4 | 4 032 | 77,1% | 26,1% (1 053) | 68,64 zł |
| 2025 | L4 | 1 196 | 22,9% | 15,9% (190) | 72,11 zł |
| 2026 | nie L4 | 4 380 | 76,6% | 23,3% (1 021) | 66,48 zł |
| 2026 | L4 | 1 336 | 23,4% | 12,6% (168) | 69,14 zł |

- Udział L4 w tej grupie się nie zmienił (22,9% → 23,4%), a powrót spadł w obu częściach: −2,8 pp bez L4 i −3,3 pp przy L4.
- To samo widać w źródłach bez kampanii L4 w miesiącach III–VI: google/organic ok. 22–25% w 2025 i 15–19% w 2026, google/cpc 22–27% i 18–22%. Direct spadł mniej: 21–23% i 20–22%.
- **Tego, co spowodowało ten spadek, te zapytania nie pokazują.** Kandydaci do sprawdzenia:
  - dłuższe czekanie na lekarza (90. percentyl opóźnienia 9,7 → 21,0 min, `docs/audit.md`, H3),
  - wzrost zwrotów `refunded`,
  - pacjenci, którzy widzieli reklamę L4, a przyszli z wyszukiwarki lub bezpośrednio. Przypisanie lnd widzi tylko sesje z UTM na tym samym `visitor_id` (H4.8).

## Odpowiedź na hipotezę

- **Częściowo tak.** Od XI 2025 do II 2026 spadek powrotu i marży to głównie mieszanka: nowe kampanie L4 przyprowadzają pacjentów, którzy prawie nie wracają (3–5%) i dają ok. 35–40 zł marży. W pozostałych źródłach do II 2026 jest prawie stabilnie.
- **Od III 2026** marża bez kampanii L4 nadal jest stabilna. Powrót spada jednak także poza nimi, o ok. 3 pp rok do roku, i to w każdym celu wizyty. Tej części mieszanka nie tłumaczy.
- **Meta poza kampanią L4** (`meta_rmkt_koszyk`, `meta_prosp_lekarz_online`) też ma niższy powrót od B (25,4% → 17,8% i 21,3% → 16,7%). Jedno możliwe wyjaśnienie: remarketing koszyka łapie teraz także porzucających z kampanii L4. Danych do sprawdzenia tego nie mam.
