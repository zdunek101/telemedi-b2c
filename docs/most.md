# Most: od liczb z dashboardu do realnych

Okresy: **P1** = X 2024 – IX 2025, **P2** = X 2025 – IX 2026, po `created_at` w czasie polskim (A4, A10).
Kroki kumulują się: każdy wiersz liczony jest na wyniku poprzedniego.
Krok 0 odtwarza dashboard na surowych danych (`sql/01_dashboard_reproduction.sql`); most liczy `sql/02_most.sql`.

## Zamówienia

| krok | opis | P1 | P2 | zmiana P1 | zmiana P2 | wzrost P2/P1 | zmiana wzrostu |
|--:|---|--:|--:|--:|--:|--:|--:|
| 0 | dashboard: wszystkie wiersze `orders`, surowe | 25 269 | 40 613 | | | +60,7% | |
| 1 | minus duplikaty (A8) | 25 269 | 40 009 | 0 | −604 | +58,3% | −2,4 pp |
| 2 | minus konta testowe (A11) | 24 716 | 38 491 | −553 | −1 518 | +55,7% | −2,6 pp |

## Przychód z konsultacji (zł)

| krok | opis | P1 | P2 | zmiana P1 | zmiana P2 | wzrost P2/P1 | zmiana wzrostu |
|--:|---|--:|--:|--:|--:|--:|--:|
| 0 | dashboard: suma `amount_paid`, surowe, brutto | 2 381 880,60 | 3 579 928,60 | | | +50,3% | |
| 1 | minus duplikaty (A8) | 2 381 880,60 | 3 528 635,60 | 0,00 | −51 293,00 | +48,1% | −2,2 pp |
| 2 | minus konta testowe (A11) | 2 374 727,60 | 3 508 197,60 | −7 153,00 | −20 438,00 | +47,7% | −0,4 pp |
| 3 | minus zwroty (`refund_amount`) | 2 230 266,50 | 3 228 342,40 | −144 461,10 | −279 855,20 | +44,8% | −3,0 pp |

## Nowi pacjenci (pierwsze zamówienie, dowolny status — definicja dashboardu, Q1)

| krok | opis | P1 | P2 | zmiana P1 | zmiana P2 | wzrost P2/P1 | zmiana wzrostu |
|--:|---|--:|--:|--:|--:|--:|--:|
| 0 | dashboard | 16 251 | 24 689 | | | +51,9% | |
| 2 | minus konta testowe (A11) | 16 231 | 24 687 | −20 | −2 | +52,1% | +0,2 pp |

Duplikaty (krok 1) nie zmieniają liczby nowych pacjentów.

## Uwagi

- Wszystkie 604 duplikaty mają `created_at` w P2 (10–24.06.2026), dlatego zawyżają tylko drugi okres.
- Konta testowe (A11): 22 konta, wszystkie ich 2 071 zamówień (1 781 z kodem `TEST-QA` za 1 zł, 290 bez kodu za 89 zł ze statusem `refunded` i pełnym zwrotem). Ich zwroty (P1 6 675 zł, P2 19 135 zł) odpadają w kroku 2 razem z przychodem, dlatego krok 3 jest mniejszy niż w poprzedniej wersji mostu.
- Zwroty to `refund_amount` ze wszystkich statusów (`cancelled` z pełnym zwrotem, `refunded` ze zwrotem po wizycie), przypisane do dnia zamówienia (`created_at`), a nie do dnia zwrotu (tego dnia w danych nie ma).
- Udział zwrotów w przychodzie brutto po krokach 1–2: P1 6,08% (144 461,10 / 2 374 727,60), P2 7,98% (279 855,20 / 3 508 197,60).
- „Sprzedane TelemediGO” nie zmienia się w żadnym kroku (`go_memberships` nie ma duplikatów, konta testowe nie kupowały GO).
