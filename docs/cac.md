# CAC na kanał i kampanię (P2) obok marży 90 i 180 dni

SQL: `sql/17_cac.sql`.
- **Pacjenci:** Q1 a2, przypisanie lnd (Q3), a first i last jako zakres CAC.
- **Koszt:** wydatki za klik plus afiliacja 25 zł za każde pierwsze zamówienie, także anulowane (A13).
- **Marża na pacjenta:** przychód netto plus opłaty GO minus koszt lekarza, bez kosztu pozyskania.
- **Okresy (A14), koszt i marża z tych samych miesięcy:**
  - okno 90 dni: kohorty i koszty 1.10.2025 – 2.07.2026 (18 280 pacjentów, koszt 481 873,79 zł, w tym afiliacja 9 550 zł),
  - okno 180 dni: 1.10.2025 – 3.04.2026 (12 166 pacjentów, koszt 296 807,78 zł, w tym afiliacja 6 825 zł).

Kontrole: każdy wariant przypisania daje tę samą liczbę pacjentów, a cały koszt trafia do jednostek z pacjentami (C2: 0 kampanii bez pacjentów).

## Okno 180 dni (kohorty X 2025 – 3.04.2026)

| kampania / kanał | koszt | pacjenci (lnd) | CAC lnd | zakres CAC first / last (min – max) | marża 180 / pacjent | powrót 180 | marża − CAC |
|---|--:|--:|--:|---|--:|--:|--:|
| meta `meta_prosp_l4_szybko` | 61 645,00 | 1 641 | 37,57 | 31,76 – 43,60 | 39,38 | 5,4% | **+1,82** |
| tiktok `tt_prosp_l4_15min` | 9 680,16 | 242 | 40,00 | 34,57 – 44,20 | 31,93 | 2,9% | **−8,07** |
| google `gs_generic_erecepta` | 51 550,62 | 686 | 75,15 | 62,79 – 88,73 | 91,02 | 31,6% | +15,87 |
| google `gs_generic_lekarz_online` | 49 367,78 | 826 | 59,77 | 49,12 – 69,63 | 78,91 | 26,3% | +19,14 |
| google `gs_generic_l4` | 43 050,83 | 606 | 71,04 | 57,63 – 84,75 | 75,48 | 18,6% | +4,44 |
| meta `meta_prosp_lekarz_online` | 31 023,35 | 482 | 64,36 | 55,60 – 73,00 | 68,86 | 19,3% | +4,49 |
| google `gs_generic_specjalisci` | 26 707,89 | 422 | 63,29 | 52,16 – 73,37 | 36,44 | 21,8% | −26,85 |
| google `gs_brand` | 11 545,18 | 1 736 | 6,65 | 7,23 – 9,33 | 74,91 | 26,3% | +68,26 |
| afiliacja `rankinglekarzy` | 6 825,00 | 263 | 25,95 | 20,50 – 30,88 | 63,91 | 20,9% | +37,96 |
| meta `meta_rmkt_koszyk` | 5 411,97 | 644 | 8,40 | 8,43 – 65,20 | 69,44 | 23,0% | +61,03 |
| google / organic | 0 | 2 512 | 0 | — | 76,23 | 26,6% | +76,23 |
| direct | 0 | 1 669 | 0 | — | 82,05 | 28,5% | +82,05 |
| polecenia | 0 | 315 | 0 | — | 78,43 | 29,2% | +78,43 |

## Okno 90 dni (kohorty X 2025 – 2.07.2026)

| kampania / kanał | koszt | pacjenci (lnd) | CAC lnd | zakres CAC first / last (min – max) | marża 90 / pacjent | powrót 90 | marża − CAC |
|---|--:|--:|--:|---|--:|--:|--:|
| meta `meta_prosp_l4_szybko` | 113 677,31 | 2 889 | 39,35 | 33,16 – 45,58 | 39,07 | 4,8% | **−0,28** |
| tiktok `tt_prosp_l4_15min` | 46 219,85 | 997 | 46,36 | 38,91 – 52,58 | 34,53 | 3,1% | **−11,82** |
| google `gs_generic_erecepta` | 73 740,63 | 995 | 74,11 | 62,12 – 87,79 | 78,32 | 27,9% | +4,21 |
| google `gs_generic_lekarz_online` | 68 786,05 | 1 093 | 62,93 | 51,64 – 72,64 | 68,99 | 21,7% | +6,05 |
| google `gs_generic_l4` | 57 179,54 | 846 | 67,59 | 55,30 – 80,08 | 70,17 | 16,3% | +2,58 |
| meta `meta_prosp_lekarz_online` | 45 855,12 | 689 | 66,55 | 57,03 – 75,92 | 63,08 | 16,4% | −3,47 |
| google `gs_generic_specjalisci` | 40 319,17 | 583 | 69,16 | 57,19 – 79,52 | 33,80 | 18,9% | −35,36 |
| google `gs_brand` | 17 899,19 | 2 503 | 7,15 | 7,70 – 10,69 | 64,98 | 21,1% | +57,83 |
| afiliacja `rankinglekarzy` | 9 550,00 | 368 | 25,95 | 20,54 – 31,11 | 58,61 | 17,9% | +32,66 |
| meta `meta_rmkt_koszyk` | 8 646,93 | 928 | 9,32 | 9,34 – 75,19 | 61,24 | 18,6% | +51,92 |

## Podsumowanie grup

| okno | grupa | koszt | pacjenci | CAC | marża / pacjent | marża − CAC |
|---|---|--:|--:|--:|--:|--:|
| 180 | kampanie L4 (Meta, TikTok) | 71 325,16 | 1 883 | 37,88 | 38,42 | +0,54 |
| 180 | pozostałe płatne | 225 482,62 | 5 665 | 39,80 | 72,99 | +33,19 |
| 180 | bezpłatne | 0 | 4 618 | 0 | 78,89 | +78,89 |
| 90 | kampanie L4 (Meta, TikTok) | 159 897,16 | 3 886 | 41,15 | 37,91 | −3,24 |
| 90 | pozostałe płatne | 321 976,63 | 8 005 | 40,22 | 64,57 | +24,35 |
| 90 | bezpłatne | 0 | 6 389 | 0 | 68,53 | +68,53 |

## Czy kampanie L4 się zwracają

- **`meta_prosp_l4_szybko`** wychodzi na zero. Po 180 dniach marża minus CAC wynosi +1,82 zł na pacjenta (z CAC według first albo last przy marży lnd: od +7,62 do −4,22), a po 90 dniach −0,28 zł. Powrót to tylko 5%, więc dalszej marży z tych pacjentów będzie niewiele.
- **`tt_prosp_l4_15min`** się nie zwraca. Po 180 dniach −8,07 zł na pacjenta (z CAC według first albo last: od −2,64 do −12,27), po 90 dniach −11,82 zł. Okno 180 dni obejmuje tylko 242 pacjentów z kohort 9.02 – 3.04.2026.
- **Dlaczego się nie zwracają.** CAC kampanii L4 nie jest wysoki: 38–46 zł, czyli tyle co innych kampanii płatnych. Problemem jest marża na pacjenta: 32–39 zł wobec 63–91 zł w pozostałych płatnych. Powodują to:
  - pojedyncza wizyta,
  - rabat z kodu (`L4SZYBKO20` −20 zł, `TIKTOK25` −25 zł przy cenie 89 zł),
  - zwroty (11–15%, `docs/audit.md`, H3),
  - prawie zerowy powrót.
- **Koszty, których tu nie liczę.** Kampanie L4 obciążają poranne godziny internistów (`docs/capacity.md`). Tego kosztu nie ma w marży.

## Inne obserwacje

- **`gs_generic_specjalisci` nie zwraca się w żadnym wariancie** (−26,85 zł po 180 dniach). CAC jest zwykły (63 zł), ale marża pierwszej wizyty u specjalisty jest niska: cena 109–119 zł minus 100 zł kosztu lekarza.
- **Bardzo niski CAC `gs_brand` i `meta_rmkt_koszyk` wynika z przypisania lnd.** Te kampanie zbierają pacjentów, którzy zwykle przyszli wcześniej innym kanałem. W wariancie first `meta_rmkt_koszyk` kosztuje 65–75 zł. Ile z tych pacjentów przyszłoby i tak, nie wiadomo (N2).
- **Wszystkie CAC wynikają z przypisania, nie z przyrostu (N2).** Przy kampaniach, które przejmują pacjentów z innych kanałów, przyrostowy CAC jest wyższy.
