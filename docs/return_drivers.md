# Spadek powrotu od III 2026: czekanie na lekarza i zwroty

SQL: `sql/15_return_wait_refund.sql`. Pacjenci spoza kampanii i kodów L4 (jak w `docs/mix.md`, M7), kohorty Q1 a2 z miesięcy III–VI 2025 i III–VI 2026. Powrót = Q4 b, okno 90 dni.
Cechy liczone na zamówieniu otwierającym: czekanie = `started_at − scheduled_at`, status = `completed` / `refunded` / `no_show`.

| rok | pacjenci | powrót 90 |
|---|--:|--:|
| 2025 | 5 228 | 23,8% (1 243) |
| 2026 | 5 716 | 20,8% (1 189) |

## Czekanie na lekarza

| czekanie | 2025: pacjenci | udział | powrót 90 | 2026: pacjenci | udział | powrót 90 |
|---|--:|--:|--:|--:|--:|--:|
| < 5 min | 3 406 | 65,1% | 24,8% (846) | 3 152 | 55,1% | 22,9% (723) |
| 5–15 min | 1 495 | 28,6% | 22,8% (341) | 1 609 | 28,1% | 21,1% (340) |
| 15–30 min | 144 | 2,8% | 18,8% (27) | 437 | 7,6% | 16,7% (73) |
| ≥ 30 min | 44 | 0,8% | 9,1% (4) | 371 | 6,5% | 7,5% (28) |
| brak wizyty (`no_show`) | 139 | 2,7% | 18,0% (25) | 147 | 2,6% | 17,0% (25) |

- **Im dłużej pacjent czekał, tym rzadziej wraca.** W obu latach: z ok. 23–25% przy czekaniu poniżej 5 min do 7–9% przy 30 min i więcej.
- **Czekanie w 2026 wyraźnie się wydłużyło.** Udział wizyt z czekaniem ≥ 15 min wzrósł z 3,6% do 14,1%. Mediana czekania: 3,0 → 4,1 min, 90. percentyl: 9,9 → 21,6 min.
- **Ten sam wzorzec bez L4.** Wśród wizyt innych niż L4 (bez `no_show`) jest tak samo: 27,2% / 24,9% / 22,0% / 10,5% w 2025 i 25,3% / 23,0% / 20,4% / 9,1% w 2026. Zależność nie wynika więc z tego, że L4 czeka dłużej.
- **Mała próba w 2025.** Grupa ≥ 30 min to tylko 44 pacjentów, więc odsetek 9,1% jest niepewny.

## Zwrot (`refunded`)

| status | 2025: pacjenci | udział | powrót 90 | 2026: pacjenci | udział | powrót 90 |
|---|--:|--:|--:|--:|--:|--:|
| `completed` | 4 981 | 95,3% | 24,3% (1 212) | 5 432 | 95,0% | 21,4% (1 160) |
| `refunded` | 108 | 2,1% | 5,6% (6) | 137 | 2,4% | 2,9% (4) |
| `no_show` | 139 | 2,7% | 18,0% (25) | 147 | 2,6% | 17,0% (25) |

- Pacjent ze zwrotem po pierwszej wizycie prawie nie wraca: 3–6% (liczby bardzo małe: 6 i 4 osoby).
- W tej grupie (spoza kampanii L4) zwrotów prawie nie przybyło: 2,1% → 2,4% pierwszych zamówień. Zwroty mocno rosną w kampaniach L4 (`docs/audit.md`, H3), a tych pacjentów tu nie ma.

## Ile spadku to tłumaczy

Rozkład zmiany 2025 → 2026 według grup czekanie × status:

| | pp |
|---|--:|
| zmiana całkowita | −2,97 |
| efekt doświadczenia (więcej długiego czekania i zwrotów przy odsetkach powrotu z 2025) | **−1,23** |
| efekt wewnątrz grup (niższy powrót przy tym samym czekaniu i statusie) | −1,72 |
| interakcja | −0,02 |

- **Dłuższe czekanie tłumaczy ok. 40% spadku** powrotu poza kampaniami L4. Zwroty dokładają w tej grupie bardzo mało.
- **Pozostałe ok. 60% to niższy powrót w każdej grupie czekania**, o 1,5–2 pp. Tego te dane nie wyjaśniają. Kandydaci:
  - doświadczenie przy kolejnych wizytach (tu liczę tylko pierwszą),
  - zmiana mieszanki specjalizacji,
  - osoby, które widziały reklamę L4, a przyszły innym kanałem.

## Zastrzeżenia

- To związek, nie dowód przyczyny. Długie czekanie może się wiązać z porą dnia, dniem tygodnia albo specjalizacją, które same wpływają na powrót. Kontrolowałem tylko cel wizyty (L4 vs pozostałe).
- Sprawdzić przyczynowo pomógłby test: limit czasu oczekiwania albo aktywne przesuwanie pacjentów do wolnego lekarza w części ruchu. Mierzylibyśmy powrót 90 dni w obu grupach.
