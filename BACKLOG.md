# Döner-App Backlog

Single-Source-of-Truth für offene Aufgaben. Sortiert nach Sprint/Phase.

Statuslegende: ☐ offen · 🔄 in Arbeit · ✅ erledigt

Strategie: **V1 = nur Kunden-Features.** Alles rund um Läden-Onboarding, Stempelkarten-Teilnahme und Voucher-System kommt in V2, sobald eine kritische Masse an Nutzern da ist.

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
- ✅ Discover-Tab als Startseite (In deiner Nähe, Gerade im Hype, Neu bewertet, Suche)
- ✅ Food-Type Rotary Picker + Emoji-Confetti beim Check-In
- ✅ Döner Wrapped (Jahresrückblick, Spotify-Wrapped-Style)
- ✅ Friend-System (Display-Name-Suche, Accept/Reject)
- ✅ Feed-Tab mit Activity-Stream
- ✅ Ranking-Tab (Bewertung/Besuche/Zuletzt)
- ✅ Achievements (11 Badges)
- ✅ Dev-Login + Reset-Buttons im Settings

---

## Sprint 3 — Launch-Readiness (V1 Kunden)

### S3.1 Offline-Sync Queue ✅
- ✅ PendingSyncOperation aktiviert (war nur definiert, nie genutzt)
- ✅ SyncQueueService: enqueue bei Fehler, processQueue bei scenePhase .active
- ✅ VisitSyncService + ReviewSyncService: Bool-Return, Codable Bodies

### S3.2 Produktiv-Hosting ☐ (BLOCKER)
- ☐ Backend auf VPS deployen (Coolify auf git.diespaetzles.lol)
- ☐ PostgreSQL + PostGIS hosted
- ☐ Backend-URL dynamisch statt hardcoded LAN-IP
- ☐ Apple Developer Account aktiv → TestFlight Setup
- ☐ CI/CD Pipeline (GitHub Actions → Coolify)

### S3.3 Google Maps Places API ☐ (UX-BLOCKER)
- ☐ Overpass durch Google Maps Places API ersetzen (oder hybrid)
- ☐ Verlässlichere Daten, aktuelle Öffnungszeiten, Fotos
- ☐ API-Key + Kostenabschätzung (Pay-per-Query)
- ☐ Fallback: Overpass behalten als kostenlose Alternative

### S3.4 Freunde-Feed + Live-Status ☐
- ☐ **Freunde-Feed**: Aktivitäten von Freunden als eigener Feed (Backend GET /feed)
- ☐ **Live-Status**: "Robin isst gerade bei Izmir einen großen Teller" — sichtbar für Freunde
  - Status wird beim Check-In automatisch gesetzt
  - Ablauf nach X Stunden oder manuell
  - Im Freunde-Feed + Friends-View sichtbar

### S3.5 Push Notifications ☐
- ☐ APNs Entitlement + Device Token Storage im Backend
- ☐ Triggers: neues Friend Request, Freund checkt bei bekanntem Laden ein
- ☐ iOS Permission-Flow im Onboarding

### S3.6 Freunde per Kontakte ☐
- ☐ Telefonnummer-basiertes Matching (Kontakte abgleichen)
- ☐ Einladungs-Link teilen ("Komm in die Döner-App!")
- ☐ Braucht Telefonnummer im User-Model + Datenschutz-Abwägung

### S3.7 Leaderboards ☐
- ☐ Rangliste unter Freunden (Visits/Unique Places diese Woche)
- ☐ Backend GET /leaderboard
- ☐ iOS LeaderboardView

---

## Sprint 4 — Gamification & Polish

### S4.A Pokemon-Go Sammelmechanik ☐
- ☐ Sammelkarte pro Laden (erst sichtbar nach Check-In)
- ☐ Stadtteil-Badges: "Alle Dönerläden in der Wiehre besucht"
- ☐ "Besuche X verschiedene Läden" Achievements erweitern
- ☐ Verknüpfung mit bestehendem Achievement-System

### S4.B Snapchat-Heatmap ☐
- ☐ Map-Overlay: Dönerdichte als Heatmap-Layer
- ☐ Basiert auf Backend-Places (reviewCount als Gewicht)

### S4.C Döner-Symbole statt Sterne ☐
- ☐ Bewertungen visuell mit kleinen Döner-Icons statt Sternen

### S4.D Community-Summary mit KI ☐
- ☐ Template-basierte Summary durch LLM ersetzen
- ☐ Abwägung: On-Device vs. Backend (Kosten)

### S4.E Feedback-Mechanismus ☐
- ☐ In-App Feedback-Button für Tester
- ☐ Screenshot + Freitext → einfach einsammeln

---

## V2 — Läden-Onboarding (nach kritischer User-Masse)

Diese Themen brauchen Konzept-Entscheidung **vor** dem Code:

- ☐ **Sign-up-Journey** für Kunden ↔ Läden gestalten
- ☐ **Onboarding-Stufen für Läden** definieren
  - Stufe 1: Nur in App sichtbar (passiv)
  - Stufe 2: Teilnahme am Stempelkarten-System
  - Stufe 3: Voucher-Einlösung + Auszahlung
- ☐ **Verifizierung des Laden-Onboardings** (Google Business? Postkarte? Foto?)
- ☐ **Anreize für User**, die einen Laden onboarden (Achievement, Sammelabzeichen)
- ☐ **QR-Sticker-Programm** für Läden ("Find mich in der Döner-App!" + Dankeschön-Paket)
- ☐ **Google Business Anmeldung** für Ladenbesitzer
- ☐ **Döner-Monopoly**: Sammelkarten-System pro Laden (McDonald's Monopoly-Style)
- ☐ NFT/BRC-20 — **Empfehlung: simples digitales Sammelabzeichen** statt Crypto (Wallet killt Conversion)

---

## Erledigt seit Projektstart

- ✅ Sideload-Auth via Dev-Login (Free Provisioning kompatibel)
- ✅ Overpass-Query holt nodes + ways + relations
- ✅ Friend-System mit Dev-Login
- ✅ Favorites mit Heart-Toggle, pink Pins, Map-Filter
- ✅ Achievement-Unlock-Logik für 11 Achievements
- ✅ Feed-Tab mit chronologischem Activity-Stream
- ✅ Ranking-Tab mit sortierbarem persönlichem Döner-Ranking
- ✅ Multi-Dimension-Bewertung (Sauce/Fleisch/Brot + Gesamt)
- ✅ Special-Note pro Laden
- ✅ Community-Summary auf Shop-Detail
- ✅ Map-Overlay Backend → OSM
- ✅ Offline-Sync Queue (PendingSyncOperation)
