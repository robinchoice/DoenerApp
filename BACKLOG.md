# Döner-App Backlog

Single-Source-of-Truth für offene Aufgaben. Sortiert nach Sprint/Phase.

Statuslegende: ☐ offen · 🔄 in Arbeit · ✅ erledigt

---

## Sprint 1 — Polish + Tester-Readiness ✅

- ✅ Stempel-Tiers (6 Stufen), Döner-Symbole statt Sterne, App-Icon
- ✅ Settings-Screen (DisplayName, Backend-URL, 4 Reset-Buttons)
- ✅ Map-Coverage (Overpass erweitert, User-Report), Map-Performance
- ✅ "Was ist Einchecken?" Onboarding (später entfernt — unnötig)

---

## Sprint 2 — Backend-Foundation + Bewertungs-Refactor ✅

- ✅ Reviews + Visits ans Backend syncen (fire-and-forget)
- ✅ Multi-Dimension-Bewertung (Sauce/Fleisch/Brot, Gesamt = Durchschnitt mit Override)
- ✅ Kurzbeschreibung pro Laden (`specialNote` auf DoenerPlace)
- ✅ Map-Overlay: Backend-Places mit avgRating/reviewCount/specialNote
- ✅ Community-Review-Summary (template-basiert, GET /places/by_osm/:id/summary)
- ☐ Shop-Entity mit source-Strategie (osm | user_reported | owner_claimed) — verschoben
- ☐ Tracking: Welche Shops aufgerufen, wo Stempel gesetzt — verschoben

---

## Sprint 3 — Discover, Suche & Gamification

### S3.A Suchfunktion + Discover-Startseite (Prio 1)
- ☐ **Neuer 1. Tab "Entdecken"** als Startseite (Lieferando-style)
  - Suchleiste oben (Places durchsuchen nach Name/Stadt)
  - "In deiner Nähe" — nächste Dönerläden mit Rating
  - "Gerade im Hype" — meiste Check-ins/Reviews letzte 7 Tage
  - "Neu bewertet" — frische Reviews von Freunden
- ☐ Karte wird 2. Tab (statt 1.)

### S3.B Google Maps Places API (Prio 1)
- ☐ Overpass durch Google Maps Places API ersetzen (oder hybrid)
  - Verlässlichere Daten, aktuelle Öffnungszeiten, Fotos
  - Braucht API-Key + Kostenabschätzung (Pay-per-Query)
  - Fallback: Overpass behalten als kostenlose Alternative

### S3.C Wählscheiben-Status-Picker (Prio 2)
- ☐ Kreisförmiger Picker: Symbole (Döner, Pommes, Lahmacun, Teller, Yufka, etc.) auf Wählscheibe
  - Oberstes Symbol = ausgewählt + größer, Rest kleiner
  - Drehbewegung verschiebt Symbole auf dem Kreis
  - Auslöse-Button in der Mitte → Emoji explodiert + Konfetti-Regen
  - Status: "Robin isst gerade einen großen Teller bei Izmir"
  - Sichtbar für Freunde im Feed

### S3.D Yufka/Döner-Counter + Jahresrückblick (Prio 2)
- ☐ Visits um Typ erweitern (Döner, Yufka, Lahmacun, Teller, Pommes, Falafel)
  - Wählscheibe aus S3.C als Typ-Auswahl beim Check-in
- ☐ Stats-View im Profil: "Dieses Jahr: 47 Döner, 12 Yufkas, 3 Falafel"
- ☐ Jahresrückblick-Screen (Spotify-Wrapped-Style)

### S3.E Pokemon-Go Sammelmechanik (Prio 2)
- ☐ "Besuche X verschiedene Läden" Achievements
- ☐ Sammelkarte pro Laden (erst sichtbar nach Check-in)
- ☐ Stadtteil-Badges: "Alle Dönerläden in der Wiehre besucht"
- ☐ Verknüpfung mit bestehendem Achievement-System

### S3.F Snapchat-Heatmap (Prio 3)
- ☐ Map-Overlay: Dönerdichte als Heatmap-Layer
- ☐ Basiert auf Backend-Places (reviewCount als Gewicht)

---

## Sprint 4 — Döner-Monopoly & Social

### S4.A Döner-Monopoly
- ☐ Konzept: Sammelkarten-System pro Dönerladen (wie McDonald's Monopoly)
  - Dezentral: jeder Laden kann eigene "Karten" / Belohnungen definieren
  - User sammeln durch Check-ins, Reviews, Freunde einladen
  - Seltene Karten durch besondere Aktionen (erster Review, 10. Besuch, etc.)
- ☐ Braucht Laden-Onboarding (Phase 2) als Grundlage

### S4.B Freunde via Kontakte
- ☐ Telefonnummer-basiertes Matching (Kontakte abgleichen)
- ☐ Einladungs-Link teilen ("Komm in die Döner-App!")

---

## Phase 2 (Voucher-Stempelkarte) — Strategische Vorarbeit

Diese Themen brauchen Konzept-Entscheidung **vor** dem Code:

- ☐ **Sign-up-Journey** für Kunden ↔ Läden gestalten
- ☐ **Onboarding-Stufen für Läden** definieren
  - Stufe 1: Nur in App sichtbar (passiv)
  - Stufe 2: Teilnahme am Stempelkarten-System
  - Stufe 3: Voucher-Einlösung + Auszahlung
- ☐ **Verifizierung des Laden-Onboardings** (OSM-Telefon? Postkarte? Foto?)
- ☐ **Anreize für User**, die einen Laden onboarden (Achievement, Sammelabzeichen)
- ☐ **QR-Sticker-Programm** für Läden ("Find mich in der Döner-App!" + Dankeschön-Paket)
- ☐ NFT/BRC-20 — **Empfehlung: simples digitales Sammelabzeichen** statt Crypto (Wallet killt Conversion)

---

## Erledigt seit Projektstart

- ✅ Sideload-Auth via Dev-Login (Free Provisioning kompatibel)
- ✅ Overpass-Query holt nodes + ways + relations
- ✅ Friend-System mit Dev-Login
- ✅ Favorites mit Heart-Toggle, pink Pins, Map-Filter
- ✅ Achievement-Unlock-Logik für 10 von 11 Achievements
- ✅ Feed-Tab mit chronologischem Activity-Stream
- ✅ Ranking-Tab mit sortierbarem persönlichem Döner-Ranking
- ✅ Multi-Dimension-Bewertung (Sauce/Fleisch/Brot + Gesamt)
- ✅ Special-Note pro Laden
- ✅ Community-Summary auf Shop-Detail
- ✅ Map-Overlay Backend → OSM
