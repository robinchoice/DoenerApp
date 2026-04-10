# Döner-App Backlog

Single-Source-of-Truth für offene Aufgaben. Sortiert nach Sprint/Phase. Strategie-Roadmap liegt unter `~/.claude/plans/vivid-spinning-cook.md`.

Statuslegende: ☐ offen · 🔄 in Arbeit · ✅ erledigt

---

## Sprint 1 — Polish + Tester-Readiness

### Quick Wins
- ✅ **S1.1** Stempel-Tiers auf 6 Stufen umbauen (Dönerneuling → Dönerlegende), lokalisiert
- ✅ **S1.2** Sterne durch Döner-Symbole ersetzen (`DoenerRatingView` als Shared Component)
- ✅ **S1.3** App-Icon austauschen (OG-Dönermann-Bild)
- ✅ **S1.4** "Was ist Einchecken?" UX-Klarstellung (Onboarding + Info-Button im Detail)

### Settings & Dev-Modus
- ✅ **S1.5** Settings-Screen anlegen (Account, Backend-URL, Dev-Reset, Über)
  - ✅ DisplayName editierbar (PATCH /users/me)
  - ☐ ~~Sprache umschalten~~ (System-Default reicht für Sprint 1)
  - ✅ Backend-URL editierbar (UserDefaults, kein Recompile bei WiFi-Wechsel)
  - ✅ 4 konfigurierbare Reset-Buttons: Logout / Daten löschen / Cache leeren / Komplett zurücksetzen
  - ✅ Version + Build + "Made with Knoblauchsoße"

### Map
- ✅ **S1.6** Map-Coverage-Lücke schließen
  - ✅ Stufe 1: Overpass-Query erweitert (turkish/arab/lebanese/syrian/falafel/shawarma + Name-Patterns dürüm/lahmacun/imbiss)
  - ✅ Stufe 3: User-Report "Laden hinzufügen" (Plus-Button auf Map, lokal in `MissingShopReport`, Liste in Settings)
  - Stufe 2 (eigenes Shop-Backend) → Sprint 2 / Phase 0
- ✅ **S1.7** Map-Performance: Skip bei großem Span, Cancel-Old-Task pattern

### Tooling
- ✅ **S1.8** `BACKLOG.md` im Repo angelegt

---

## Sprint 2 — Backend-Foundation + Bewertungs-Refactor

- ✅ Reviews + Visits + Stamps ans Backend syncen
- ☐ `Shop`-Entity im Backend mit Overlay-Strategie (`source: osm | user_reported | owner_claimed`)
- ✅ Map-Layer mergt OSM + Backend-Shops (Backend-Places overlayed mit avgRating/reviewCount/specialNote)
- ✅ Multi-Dimension-Bewertungs-Assessment (Sauce / Fleisch / Brot, Gesamt = Durchschnitt mit Override)
- ✅ Kurzbeschreibung pro Laden ("Special" auf DoenerPlace, editierbar via ReviewSheet)
- ✅ Community-Review-Summary auf Shop-Detail (template-basiert, kein LLM)
- ☐ Tracking: Welche Shops werden aufgerufen, wo werden Stempel gesetzt

---

## Sprint 3 — Discover & Gamification

- ☐ 5. Tab "In deiner Nähe / im Hype" (Lieferando-style Discover)
- ☐ Yufka/Döner-Counter + Jahresrückblick-Stats ("Wieviel Yufkas dieses Jahr?")
- ☐ Beer-with-me Wählscheiben-Status-Picker ("Robin isst gerade einen großen Teller bei Izmir")
  - Symbole auf Kreis, Drehung selektiert, Auslöser regnet Konfetti-Emoji
- ☐ Snapchat-Heatmap der Dönerdichte
- ☐ Pokemon-Go-Anreize: "Sammel deinen Lieblingsdönermann" — User abklappern Läden
- ☐ Freunde via Telefonnummer / Kontakte hinzufügen
- ☐ Mehr Gamification-Tiefe (TBD)

---

## Phase 2 (Voucher-Stempelkarte) — Strategische Vorarbeit

Diese Themen brauchen Konzept-Entscheidung **vor** dem Code:

- ☐ **Sign-up-Journey** für Kunden ↔ Läden gestalten (wie unterscheiden, wo trennen)
- ☐ **Onboarding-Stufen für Läden** definieren
  - Stufe 1: Nur in App sichtbar (passive)
  - Stufe 2: Teilnahme am Stempelkarten-System
  - Stufe 3: Voucher-Einlösung + Auszahlung
- ☐ **Verifizierung des Laden-Onboardings** (OSM-Telefon? Postkarte? Foto?)
- ☐ **Anreize für User**, die einen Laden onboarden (Achievement, Sammelabzeichen, Status)
- ☐ **QR-Sticker-Programm** für Läden ("Find mich in der Döner-App!" + Dankeschön-Paket)
- ☐ NFT/BRC-20-Belohnung — **Empfehlung: nicht umsetzen**, simples digitales Sammelabzeichen reicht (Crypto-Wallet killt Conversion)

---

## Erledigt seit Projektstart

- ✅ Sideload-Auth via Dev-Login (Free Provisioning kompatibel)
- ✅ Overpass-Query holt nodes + ways + relations (Erbil/Rieselfeld & Co. tauchen auf)
- ✅ Friend-System mit Apple Sign-In (jetzt Dev-Login)
- ✅ Favorites mit Heart-Toggle, pink Pins, Map-Filter
- ✅ Achievement-Unlock-Logik für 10 von 11 Achievements
- ✅ Feed-Tab mit chronologischem Activity-Stream
- ✅ Ranking-Tab mit sortierbarem persönlichem Döner-Ranking
