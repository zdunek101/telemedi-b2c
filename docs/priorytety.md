# Priorytety (szkic)

> **Szkic do decyzji.** Kolejność ustala Bartosz. Tu pozycje są w kolejności szacowanej wartości.
> Wartości liczone w `sql/18_priorities.sql` na danych z P2, w zł miesięcznie. To szacunki, nie prognozy.
> Czas wdrożenia to moja ocena, bez danych o zespole i systemach. Do weryfikacji.

| # | co zrobić | z czego wynika | wartość (szacunek) | po czym poznamy, że zadziałało | czas wdrożenia (ocena) |
|---|---|---|---|---|---|
| A | **Naprawić rejestrację w Safari na iPhonie** | Od 17.03.2026 krok termin → konto w Safari na iPhonie spada z 75% do 59%, tylko u nowych osób (rejestracje −28%). Realny spadek, widoczny w zamówieniach (`docs/funnel_drilldown.md`) | 749 utraconych zamówień w 198 dni, czyli **ok. 115 zamówień i 9,9 tys. zł przychodu netto miesięcznie** (ok. 4,4 tys. zł marży przy 38,36 zł marży na zamówienie). Bez późniejszych powrotów tych pacjentów | F3 w Safari na iPhonie wraca do ok. 74–75% (dziś ok. 60%); zamówienia na sesję z terminem do ok. 60% (dziś ok. 48%); tygodniowo w `tool`, zakładka Lejek | diagnoza 1–3 dni (formularz rejestracji w mobilnym Safari, wdrożenia z okolic 17.03), poprawka 1–2 tygodnie |
| B | **Ograniczyć zwroty przy L4** | `refunded` przy L4 u internisty: 5,6% w P1, 12,6% w VII–IX 2026. Najwyższe w kodach `L4SZYBKO20` / `TIKTOK25` (11–15%). Lekarz dostaje wynagrodzenie także przy zwrocie (`docs/audit.md`, H3) | Nadwyżka zwrotów ponad poziom z P1: **ok. 5,5 tys. zł miesięcznie** (130 zwrotów, 9,7 tys. zł zwrotów miesięcznie, z czego nadwyżka ok. 5,5 tys.). To górna granica: lepsze kwalifikowanie wniosków może też obniżyć sprzedaż L4 | odsetek `refunded` przy L4 wraca do ok. 6%, a liczba opłaconych L4 nie spada o więcej niż różnicę w zwrotach; miesięcznie | 2–4 tygodnie: przekaz w kampaniach L4 (czego lekarz nie wystawi), pytanie kwalifikujące przed płatnością |
| C | **Poranna obsada internistów (6–12)** | Od XI 2025 90. percentyl czekania u internistów rano rośnie z ok. 12 do ok. 56 min, a wieczorem przy podobnym ruchu czekania nie ma. Kto czeka ≥ 15 min, wraca rzadziej (`docs/capacity.md`, `docs/return_drivers.md`) | Górna granica: ok. 32 utraconych powrotów miesięcznie × 54,96 zł marży z kolejnych zamówień w 90 dni = **ok. 1,8 tys. zł miesięcznie w samym oknie 90 dni**. Związek, nie dowód przyczyny. Do tego niżej opisany koszt czekania dla zwrotów i ocen, którego nie liczyłem | p90 czekania u internistów rano < 15 min, odsetek ≥ 15 min poniżej 10% (dziś ok. 50%); powrót 90 dni kohort porannych; tygodniowo | 2–4 tygodnie: przesunięcie grafików z wieczoru na rano |
| D | **Wyłączyć albo przerobić `tt_prosp_l4_15min` (TikTok L4)** | Marża minus CAC na pacjenta: −8,07 zł (180 dni), −11,82 zł (90 dni), w każdym wariancie przypisania ujemna; powrót 3% (`docs/cac.md`) | Według przypisania lnd: **ok. −1,3 tys. zł miesięcznie** (110 pacjentów miesięcznie × −11,82 zł) przy wydatkach 12,3 tys. zł miesięcznie (VII–IX 2026). Ile pacjentów przyszłoby i tak, nie wiemy (N2) | po pauzie lub zmianie: nowi pacjenci ogółem i z L4 nie spadają o więcej niż przypisanie TikToka; najlepiej w teście z grupą kontrolną (E) | dni (pauza), 2–4 tygodnie (test) |
| E | **Test przyrostowości kampanii płatnych (N2)** | Bez kanałów płatnych wzrost nowych to +17,7% (lnd), w zakresie +12,7–25,4%. Nie wiadomo, ile reklama dokłada naprawdę (`docs/nierozstrzygniete.md`) | Wartość informacji. Decyzja dotyczy **ok. 60,5 tys. zł wydatków za klik miesięcznie** (VII–IX 2026) | test geo-holdout albo conversion lift: różnica nowych pacjentów między regionami z kampanią i bez, z przedziałem ufności | 4–6 tygodni testu i 1 tydzień przygotowania |
| F | **`gs_generic_specjalisci`: zmienić ofertę albo stawki** | Marża minus CAC na pacjenta: −26,85 zł (180 dni), −35,36 zł (90 dni). Marża pierwszej wizyty u specjalisty jest niska: cena 109–119 zł minus 100 zł lekarza (`docs/cac.md`) | **ok. −1,9 do −2,3 tys. zł miesięcznie** (64–69 pacjentów miesięcznie) przy wydatkach 4,4 tys. zł miesięcznie | marża minus CAC tej kampanii ≥ 0 w oknie 180 dni; CAC < marża pierwszej wizyty | 1–2 tygodnie (stawki, słowa kluczowe), dłużej przy zmianie cennika |
| G | **Meta L4 (`meta_prosp_l4_szybko`): utrzymać tylko po poprawie B** | Marża minus CAC na pacjenta ok. 0 zł (od −0,28 przy 90 dniach do +1,82 przy 180), powrót 5% (`docs/cac.md`) | **ok. 0 zł miesięcznie** (od −0,1 do +0,5 tys.) przy wydatkach 17,0 tys. zł miesięcznie. Kampania przyprowadza ok. 270–320 pacjentów miesięcznie, ale na nich nie zarabia | po B: marża 180 dni na pacjenta z tej kampanii rośnie powyżej CAC; w teście E: przyrostowy CAC | razem z B i E |

## Zależności między pozycjami

- **D, G i E dotyczą tych samych pieniędzy.** Najpierw warto zrobić E (test), żeby decyzje D i G opierać na przyroście, a nie na przypisaniu.
- **B poprawia wynik G** (te same kampanie L4) i zmniejsza poranne obciążenie z C. Wzrost czekania od XI 2025 zbiega się w czasie ze startem kampanii L4, ale nie sprawdzałem, czy L4 skupia się rano.
- **A nie zależy od żadnej innej pozycji**: to błąd albo regresja w jednym kroku lejka.

## Czego nie wliczyłem

- **Późniejsze powroty pacjentów**, których tracimy w A. Wartość A jest przez to dolną granicą.
- **Wpływ czekania (C) na zwroty i oceny wizyt.**
- **Koszt wdrożeń.** Czas jest szacunkiem bez wiedzy o zespole.
