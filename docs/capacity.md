# Czekanie na lekarza a obciążenie

SQL: `sql/16_capacity.sql`. Baza A8 + A11.
- **Obciążenie (A12):** wizyty umówione na daną godzinę (`scheduled_at`). Do obciążenia liczę wizyty zarezerwowane: `completed`, `refunded`, `no_show`.
- **Czekanie:** `started_at − scheduled_at`, tylko wizyty odbyte. P1: 23 082, P2: 35 950.

## 1. Przy większym obciążeniu czekanie rośnie, ale głównie w P2

| wizyt w godzinie | P1: wizyty | P1: p90 | P1: ≥ 15 min | P2: wizyty | P2: p90 | P2: ≥ 15 min |
|---|--:|--:|--:|--:|--:|--:|
| 1–3 | 8 795 | 9,5 min | 3,0% | 6 115 | 13,7 min | 8,9% |
| 4–6 | 10 591 | 9,8 | 3,5% | 14 113 | 18,7 | 12,3% |
| 7–9 | 3 259 | 10,3 | 4,0% | 11 151 | 24,4 | 16,1% |
| 10–12 | 437 | 11,7 | 5,9% | 3 739 | 32,1 | 20,0% |
| 13–15 | — | — | — | 714 | 36,7 | 23,4% |
| 16–20 | — | — | — | 118 | 71,7 | 36,4% |

- **W P1 czekanie prawie nie zależy od obciążenia.** 90. percentyl wynosi 9,5–11,7 min. Korelacja rang dnia (wizyty w dniu vs p90 czekania) to 0,12.
- **W P2 rośnie razem z obciążeniem.** Korelacja dnia wynosi 0,50.
- **Przy tym samym obciążeniu P2 czeka dłużej niż P1.** Przy 4–6 wizytach na godzinę: 18,7 vs 9,8 min. Sam wzrost ruchu tego nie tłumaczy, zmieniła się też obsługa.

## 2. Problem dotyczy internistów rano

90. percentyl czekania według godziny wizyty:

| godziny | P1: śr. wizyt w godzinie | P1: p90 | P2: śr. wizyt w godzinie | P2: p90 | P2: ≥ 15 min |
|---|--:|--:|--:|--:|--:|
| 0–4 | 1,6–2,4 | 8–9 | 1,7–3,4 | 8–9 | 1–4% |
| 5 | 2,1 | 9,4 | 2,7 | 16,9 | 12,6% |
| 6–10 | 2,6–5,2 | 11,5–12,1 | 4,2–8,1 | **41,0–49,6** | **32–37%** |
| 11–12 | 4,1–4,4 | 9,4 | 6,1–6,3 | 20,9–32,3 | 18–28% |
| 13–23 | 3,3–5,6 | 8,4–9,2 | 4,6–7,5 | 8,3–11,6 | 2–5% |

- **Wieczorem (18–20) obciążenie w P2 jest podobne jak rano** (7,0–7,5 wizyt na godzinę), a czekania prawie nie ma: p90 8,6–8,7 min.
- **Dotyczy wyłącznie internistów.** Pozostali specjaliści mają w P2 p90 7,4–9,4 min przy każdym obciążeniu. Internista w P2: od 16,2 min (1–3 wizyty na godzinę) do 78,5 min (16–20).
- **Tryb wizyty nie ma znaczenia:** czat, telefon i wideo wyglądają tak samo (p90 ok. 21–22 min w P2).

**Internista rano (6–11) miesięcznie:**

| | X 25 | XI | XII | I 26 | II | III | IV | V | VI | VII | VIII | IX |
|---|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|
| wizyty | 540 | 572 | 705 | 811 | 856 | 1 000 | 912 | 841 | 819 | 779 | 773 | 810 |
| śr. wizyt w godzinie | 5,2 | 5,9 | 6,6 | 7,3 | 8,1 | 8,2 | 8,1 | 7,0 | 7,0 | 6,5 | 6,7 | 7,0 |
| p90 czekania (min) | 11,2 | 18,1 | 30,2 | 43,8 | 57,8 | 55,9 | 56,1 | 55,3 | 58,1 | 51,5 | 57,1 | 56,8 |
| ≥ 15 min | 5,2% | 15,6% | 29,7% | 41,8% | 49,0% | 48,4% | 51,0% | 48,9% | 52,6% | 49,1% | 52,5% | 50,3% |

- **Od X 2024 do X 2025** p90 rano trzyma się 11–13 min.
- **Od XI 2025** rośnie co miesiąc razem z ruchem, aż do ok. 56 min w II 2026.
- **Później obciążenie spada** (od V 2026 ok. 6,5–7 wizyt na godzinę zamiast 8), a **czekanie nie wraca**: p90 ok. 51–58 min.
- **Nawet w mało obciążonych godzinach rano** (1–3 wizyty) p90 w P2 wynosi 41 min.

## Odpowiedź

- **Czekanie rośnie razem z liczbą wizyt, ale to nie cała historia.**
  - Wzrost zaczyna się w XI 2025, gdy rośnie ruch.
  - Dotyczy tylko internistów i tylko godzin 6–12.
  - Przy tym samym obciążeniu wieczorem czekania nie ma.
  - Po spadku ruchu latem 2026 nie wraca.
- **To pasuje do braku internistów rano, a nie ogólnie w szczycie.** Wieczorna obsada radzi sobie z podobnym ruchem.
- **Możliwe, że poranna kolejka narasta od pierwszych godzin** i przenosi się na kolejne. To by tłumaczyło długie czekanie nawet w mało obciążonych godzinach. Tego nie sprawdzałem.
- **Czego nie wiem.** W danych nie ma grafiku ani liczby lekarzy, więc brak obsady to wniosek pośredni. Domknąć to mogą grafiki internistów rano od X 2025 i liczba lekarzy na godzinę.
- **Możliwy związek z L4.** Wzrost od XI 2025 zbiega się w czasie ze startem kampanii L4 (`docs/events.md`). Nie sprawdzałem, czy L4 skupia się rano.
