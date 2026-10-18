# Przebieg pracy

> **To podsumowanie zostało wygenerowane przez AI (Claude) z historii repozytorium:** commitów, `docs/decisions.md` oraz opisów i komentarzy w `docs/` i `sql/`. Nie jest pełnym zapisem rozmowy. Poprawki zrobione przed commitem i nieopisane w repozytorium tu nie występują. Pełny ślad: `git log` i pliki w `docs/`.

Praca trwała jeden dzień: 14 commitów od 16:32 do 21:35, a ten dokument jest w piętnastym. Tryb pracy określał `CLAUDE.md`:
- plan przed każdym większym krokiem,
- definicje wybiera człowiek, AI pokazuje warianty,
- każda metryka z licznikiem i mianownikiem,
- dziwne wyniki najpierw weryfikowane.

## Fazy

| faza | commity | co powstało |
|---|---|---|
| 1. Przygotowanie | `3118f35`, `50edb28` | Struktura repozytorium i treść zadania. Założenia A1–A7: koszt lekarza, opłaty GO w marży, czas polski, afiliacja. Zasady pracy w `CLAUDE.md`. |
| 2. Profil danych | `fad6bc4` | Profil 17 plików: suma 1 082 369 wierszy zgodna z zadaniem. Wykryte 604 zdublowane zamówienia (10–24.06.2026). Decyzje A8–A10. |
| 3. Odtworzenie dashboardu | `0ba2587` | Wszystkie 4 KPI odtworzone na surowych danych. +61% zamówień i +50% przychodu wychodzą tylko z duplikatami. Początek mostu do liczb realnych. |
| 4. Audyt | `29206ef`, `5c8da2b` | 8 hipotez (H1–H8). Wykryte 22 konta testowe z kodem `TEST-QA` (A11). Dwa nowe kody w P2 jako źródło wzrostu, wzrost zwrotów `refunded`, wzrost kupiony reklamą. Zamknięte definicje Q1–Q4. |
| 5. Kohorty dzienne | `e27c2d2` | Kohorty według pierwszego nieanulowanego zamówienia: powrót 30/90/180 dni, przychód i marża 90/180 dni, tylko pełne okna. Kontrole sum i ręczne przeliczenie 4 pacjentów. |
| 6. Zdarzenia i mieszanka | `f607658` | 544 szeregi dzienne, wykrywanie trwałych zmian (okna 28/28 dni, test placebo, kalendarz kampanii). Rozkład spadku retencji na mieszankę źródeł i zmianę wewnątrz źródeł. |
| 7. Pogłębienie | `dc60278`, `b03bf84`, `4f9ad3f` | Spadek rejestracji w Safari na iPhonie od 17.03.2026. Powrót a czekanie na lekarza i zwroty. Poranny problem z czekaniem u internistów. CAC na kampanię obok marży 90 i 180 dni. Decyzje A12–A14. |
| 8. Narzędzie i priorytety | `3aec60e`, `cd44c6e`, `fe187e3` | Statyczna strona (`tool/`) z 6 zakładkami. Lista priorytetów 1–5 z wartością, pomiarem i czasem. Lista niewiadomych N1–N6. |

## Kluczowe decyzje (`docs/decisions.md`)

- **Czyszczenie danych:**
  - duplikaty zamówień usunięte (A8),
  - 22 konta testowe wykluczone w całości, razem z 290 zamówieniami bez kodu (A11).
- **Pacjent i kohorta (Q1):** dzień pierwszego **nieanulowanego** zamówienia. Kto tylko anulował, nie jest pacjentem. Dashboard liczył także anulowane.
- **Mianownik lejka (Q2):** wszystkie sesje. Audyt nie znalazł botów. Krok konto = `account_completed` albo `user_id` w sesji.
- **Przypisanie źródła (Q3):** ostatnia sesja niebezpośrednia (lnd) jako wynik główny, pierwsza sesja i sesja płatności jako zakres. Uzasadnienie: kto przyszedł z reklamy i wrócił bezpośrednio, przyszedł dzięki reklamie.
- **Powrót (Q4):** kolejne nieanulowane zamówienie. Okno główne 90 dni, obok 30 i 180.
- **Obciążenie lekarzy (A12):** wizyty umówione na godzinę według `scheduled_at`, czyli moment wizyty, a nie płatności.
- **CAC (A13, A14):**
  - afiliacja 25 zł za każde pierwsze zamówienie, także anulowane,
  - koszt i marża z tych samych miesięcy kohort z pełnym oknem.
- **Priorytety:** kolejność ustalona przez człowieka, czyli Safari, potem test przyrostowości z pauzą TikToka, zwroty L4, poranna obsada, `gs_generic_specjalisci`. Pozycja „Meta L4” została włączona do testu i zwrotów zamiast osobnego priorytetu.

## Błędy złapane po drodze (opisane w repozytorium)

- **290 zamówień kont testowych opisanych jako `completed`, a w rzeczywistości `refunded`.** Wyszło przy dodawaniu kont testowych do mostu, bo suma zwrotów się nie zgadzała. Poprawiony opis H1 i H3 (`docs/audit.md`). Wzrost zwrotów przy czacie wynikał prawie w całości z kont testowych.
- **Audyt liczony najpierw z kontami testowymi.** Po decyzji A11 przeliczony od nowa na bazie A8 + A11 (`5c8da2b`).
- **Fałszywe alarmy w teście placebo:** 11–47 wykryć na losowych danych. Powód: szeregi TikToka z zerami przez cały P1. Każdy szereg zaczyna się teraz od pierwszego dnia z danymi, a placebo daje 1/0/0 (`docs/events.md`).
- **Brak czułości metody na zmiany stopniowe.** Spadek powrotu i marży nie przeszedł progu |z| ≥ 5. Wynik opisany wprost zamiast obniżania progu, a spadek przebadany osobno (`docs/mix.md`).
- **`arg_min` pomija NULL.** Kanał i źródło pierwszej sesji pochodziły z różnych sesji, więc „direct” wychodził jako kanał płatny. Zastąpione wyborem jednej sesji (`sql/06_audit_h4.sql`).
- **Niepowtarzalne zaokrąglenia.** Sumy zmiennoprzecinkowe zmieniały wyniki w ostatnim groszu między przebiegami. Kwoty sumowane jako DECIMAL, a dwa przebiegi dają identyczne pliki (`docs/events.md`).
- **Podział „zalogowany na wejściu” okazał się pusty.** Każda sesja z płatnością ma `account_completed`. Zamiast niego użyty podział nowy / znany odwiedzający i rejestracja / logowanie (`docs/funnel_drilldown.md`).
- **Zdarzenie 11.07.2025 w przeglądarkach w aplikacjach** spełniło kryteria wykrycia, ale okazało się powrotem z czerwcowego szczytu, a nie trwałą zmianą (`docs/funnel_drilldown.md`).
- **Nieścisła wiadomość commita `b03bf84`.** Podaje plik, który trafił już do poprzedniego commita. Zostawiona bez zmian, bo historia jest śladem pracy.

## Czego nie zrobiliśmy

- **Testy z listy niewiadomych** (N1–N6): przyrostowość reklamy, czekanie jako przyczyna, przyczyna problemu w Safari, sezon. Tych danych nie ma w zbiorze.
- **Kolumna `rating`.** Odłożona na osobny krok.
- **Przekroje kohort** poza źródłem i grupą L4: specjalizacja, cel wizyty, region, wiek, członkostwo GO.
- **Wpływ czekania na zwroty i oceny wizyt.** Nie wliczony w wartość priorytetu 4.
- **CAC przyrostowy.** Liczony tylko na przypisaniu, a nie na przyroście.
- **Publikacja narzędzia.** Workflow GitHub Pages jest gotowy, ale repozytorium na GitHubie nie zostało jeszcze założone, a w README jest miejsce na link.
