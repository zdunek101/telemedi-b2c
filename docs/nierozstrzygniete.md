# Czego nie da się rozstrzygnąć

Rzeczy, które z tych danych nie wynikają, oraz jaki test albo jakie informacje są potrzebne, żeby je domknąć.

| # | Pytanie | Dlaczego dane tego nie rozstrzygają | Co by to domknęło |
|---|---|---|---|
| N1 | Czy część „nowych pacjentów” to powracający pacjenci na nowych kontach (np. dla kodu na pierwsze zamówienie)? | Jedynym łącznikiem osób jest `visitor_id` (cookie). Każdy `visitor_id` łączy się z dokładnie jednym kontem (57 495 `visitor_id`, 0 z dwoma kontami). Osoba z nowym kontem na nowym urządzeniu albo po wyczyszczeniu cookies ma nowy `visitor_id`, więc metoda tego nie widzi. Innego identyfikatora osoby nie ma (`docs/audit.md`, H7). | Zahashowany e-mail, telefon albo PESEL konta, do porównania między kontami. Albo test: przy rejestracji z kodem na pierwsze zamówienie sprawdzać e-mail/telefon i mierzyć, ile kont odpada. |
