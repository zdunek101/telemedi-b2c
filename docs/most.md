# Most: od liczb z dashboardu do realnych

Okresy: **P1** = X 2024 – IX 2025, **P2** = X 2025 – IX 2026, po `created_at` w czasie polskim (A4, A10).
Kroki kumulują się: każdy wiersz liczony jest na wyniku poprzedniego.
Krok 0 odtwarza dashboard na surowych danych (`sql/01_dashboard_reproduction.sql`); most liczy `sql/02_most.sql`.

## Zamówienia

| krok | opis | P1 | P2 | zmiana P1 | zmiana P2 | wzrost P2/P1 | zmiana wzrostu |
|--:|---|--:|--:|--:|--:|--:|--:|
| 0 | dashboard: wszystkie wiersze `orders`, surowe | 25 269 | 40 613 | | | +60,7% | |
| 1 | minus duplikaty (A8) | 25 269 | 40 009 | 0 | −604 | +58,3% | −2,4 pp |

## Przychód z konsultacji (zł)

| krok | opis | P1 | P2 | zmiana P1 | zmiana P2 | wzrost P2/P1 | zmiana wzrostu |
|--:|---|--:|--:|--:|--:|--:|--:|
| 0 | dashboard: suma `amount_paid`, surowe, brutto | 2 381 880,60 | 3 579 928,60 | | | +50,3% | |
| 1 | minus duplikaty (A8) | 2 381 880,60 | 3 528 635,60 | 0,00 | −51 293,00 | +48,1% | −2,2 pp |
| 2 | minus zwroty (`refund_amount`) | 2 230 744,50 | 3 229 645,40 | −151 136,10 | −298 990,20 | +44,8% | −3,4 pp |

## Uwagi

- Wszystkie 604 duplikaty mają `created_at` w P2 (10–24.06.2026), dlatego zawyżają tylko drugi okres.
- Zwroty to `refund_amount` ze wszystkich statusów (`cancelled` z pełnym zwrotem, `refunded` ze zwrotem po wizycie), przypisane do dnia zamówienia (`created_at`), a nie do dnia zwrotu (tego dnia w danych nie ma).
- Zwroty stanowią 6,3% przychodu brutto po deduplikacji w P1 (151 136,10 / 2 381 880,60) i 8,5% w P2 (298 990,20 / 3 528 635,60).
- KPI „pacjenci z pierwszym zakupem” i „sprzedane TelemediGO” nie zmieniają się przy deduplikacji (duplikaty to kopie istniejących zamówień, `go_memberships` nie ma duplikatów).
