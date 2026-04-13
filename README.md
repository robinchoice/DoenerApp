# Döner-App 🥙

Eine iOS-App zum Finden, Bewerten und Sammeln von Dönerläden. Offline-First, Community-getrieben, mit Gamification-Mechaniken die an Pokémon Go und Spotify Wrapped erinnern.

---

## Überblick

Die Döner-App verbindet eine persönliche Stempelkarte mit einem sozialen Layer: Nutzer checken bei Läden ein, bewerten nach Sauce/Fleisch/Brot, verfolgen ihre eigene Döner-Geschichte und sehen was Freunde gerade essen.

**Stack:**
- iOS: Swift 6, SwiftUI, MapKit, SwiftData
- Backend: Vapor (Swift), PostgreSQL + PostGIS, Docker
- Daten: OpenStreetMap via Overpass API

---

## Features

### Karte

Die Karte ist der Einstiegspunkt. Sie lädt Dönerläden dynamisch per Overpass API basierend auf dem sichtbaren Kartenausschnitt — aber nur wenn der Span klein genug ist (< 0.5°), um Timeouts zu vermeiden. Ein Caching-Layer in SwiftData verhindert unnötige Netzwerkaufrufe: Regionen werden erst nach 24h neu geladen.

**UI-Details:**
- Kein Standard-Apple-Maps-Look: POI-Layer deaktiviert, 3D-Elevation aktiv, Fokus liegt auf Döner-Pins
- Custom Pin-Views zeigen Ladenname + lokalen Besuchszähler direkt auf der Karte
- Favoriten-Filter per Heart-Button oben rechts: zeigt nur gemerkte Läden, Pins werden pink
- Backend-Overlay ist non-blocking: OSM-Daten erscheinen sofort, Community-Ratings werden still nachgeladen

### Check-In

Der Check-In ist bewusst schnell gehalten. Ein Rotary Picker dreht sich durch 6 Food-Types (Döner Classic, Hähnchen, Lamm, Falafel, Salat, Sonstiges) — oberstes Symbol = ausgewählt.

**UI-Details:**
- Bestätigung: großer oranger Kreis mit Checkmark — klar, unübersehbar
- Confetti-Animation: Emoji-Partikel des gewählten Food-Types fallen herunter (nicht generisches Konfetti)
- Check-In speichert lokal in SwiftData zuerst, Backend-Sync läuft danach asynchron

### Bewertungen

Reviews haben ein 5-Sterne-Gesamtrating plus drei optionale Dimensions-Ratings: Sauce, Fleisch, Brot. Das Gesamtrating berechnet sich automatisch als Durchschnitt der Dimensionen, kann aber manuell überschrieben werden.

**UI-Details:**
- Dimensions-Ratings sind optional — wer nur eine Zahl will, kann das
- Beim Review kann eine Community-Notiz vorgeschlagen werden: kurze Freitext-Beschreibung die für alle Nutzer des Ladens sichtbar ist (z.B. "Besonders gute Knoblauchsoße")
- One-Per-User-Per-Place: zweiter Review überschreibt den ersten, Aggregate werden neu berechnet

### Profil & Stempelkarte

Das Profil ist der persönliche Döner-Pass.

**Stempel-Tiers (6 Stufen):**
| Tier | Ab | Farbe |
|---|---|---|
| Dönerneuling | 0 | Grau |
| Dönerfreund | 5 | Braun |
| Dönerfan | 15 | Orange |
| Dönerprofi | 30 | Rot |
| Dönermeister | 60 | Lila |
| Dönerlegende | 100 | Gold |

**UI-Details:**
- 10×10 Stempel-Grid, pro Tier gefüllt dargestellt
- Progress-Bar zum nächsten Tier mit Text ("noch 8 bis Dönerprofi")
- Food-Konsum-Stats als Bar-Chart mit prozentualer Verteilung
- "Seit [Monat/Jahr]"-Badge basiert auf dem ersten Check-In als Join-Date

### Achievements

11 unlockbare Badges in einem 4×4-Grid. Locked/Unlocked visuell klar unterschieden.

| Badge | Bedingung |
|---|---|
| First Bite | Erster Check-In |
| Critic | Erste Bewertung |
| Regular | 5× gleicher Laden |
| Explorer | 10 verschiedene Läden |
| Connoisseur | 50 verschiedene Läden |
| Berlin Tour | 5 Läden in Berlin |
| Hamburg Tour | 5 Läden in Hamburg |
| Stamp Collector Silver | Tier "Dönerfan" erreicht |
| Stamp Collector Gold | Tier "Dönermeister" erreicht |
| Night Owl | Check-In nach 22:00 Uhr |
| Social Butterfly | 5+ Freunde |

### Döner Wrapped

Full-Screen-Experience mit 5 animierten Seiten im Spotify-Wrapped-Stil:
1. Total Besuche des Jahres
2. Lieblings-Food-Type + Anzahl
3. Top-Läden mit Besuchszahl
4. Unique Läden entdeckt
5. Summary

**UI-Details:**
- Spring-Physics-Übergänge zwischen Seiten
- Wechselnde Gradient-Backgrounds pro Seite
- Zentrierte große Typografie, Emoji-basierte Visuals

### Friends & Social

Bidirektionale Freundschaften (Requester/Addressee-Modell). Nutzer finden sich per Display-Name-Suche.

- Eingehende Anfragen erscheinen oben in der Friends-View
- Slide-to-Delete für bestehende Freundschaften
- Friend Request verhindert Duplikate und Selbst-Anfragen

### Ranking

Persönliches Ranking aller Läden wo der Nutzer interagiert hat. Drei Sortieroptionen per Segmented Picker:
- **Bewertung** — nach Durchschnitts-Rating
- **Besuche** — nach Visit-Count
- **Zuletzt besucht** — chronologisch

Top-3 bekommen Trophy-Badges statt Zahlen.

---

## Architektur

### iOS

```
iOS/DoenerApp/
├── App/                    # Entry Point, ModelContainer, ScenePhase
├── Core/
│   ├── Network/            # APIClient, VisitSyncService, ReviewSyncService, SyncQueueService
│   ├── Persistence/        # SwiftData Models
│   └── Auth/               # AuthStore, KeychainStore
├── Features/
│   ├── Map/                # MapView, MapViewModel, OverpassService
│   ├── CheckIn/            # CheckInSheet, ConfettiView
│   ├── PlaceDetail/        # PlaceDetailView, ReviewSheet
│   ├── Discover/           # DiscoverView, DiscoverViewModel
│   ├── Feed/               # FeedView
│   ├── Profile/            # ProfileView, AchievementsView, WrappedView
│   ├── Friends/            # FriendsView, FriendSearchView
│   ├── Ranking/            # RankingView
│   └── Settings/           # SettingsView
└── Shared/                 # Wiederverwendbare Views, Extensions
```

**Prinzipien:**
- MVVM mit `@Observable` ViewModels + `@MainActor`
- Offline-First: SwiftData als lokale Quelle, Backend-Sync asynchron
- Dependency Injection via SwiftUI Environment
- Sync-Queue: Gescheiterte Backend-Syncs werden als `PendingSyncOperation` persistiert und beim nächsten App-Vordergrund verarbeitet

### Backend

```
Backend/Sources/App/
├── Controllers/
│   ├── AuthController.swift
│   ├── PlaceController.swift
│   ├── ReviewController.swift
│   ├── VisitController.swift
│   └── FriendController.swift
├── Models/
│   ├── User.swift
│   ├── DoenerPlace.swift
│   ├── Review.swift
│   ├── Visit.swift
│   └── Friendship.swift
└── Migrations/
```

**API-Routen:**

| Methode | Pfad | Beschreibung |
|---|---|---|
| POST | `/auth/apple` | Apple Sign-In |
| GET | `/auth/me` | Aktueller User |
| PATCH | `/users/me` | Display-Name ändern |
| GET | `/places` | Läden in Radius |
| GET | `/places/top_nearby` | Top-bewertete in Radius |
| GET | `/places/trending` | Trending (letzte N Tage) |
| POST | `/places/by_osm/:id/visits` | Visit erstellen (Place wird auto-angelegt) |
| POST | `/places/by_osm/:id/reviews` | Review upserten |
| GET | `/places/by_osm/:id/summary` | Community-Summary |
| GET | `/users/search` | Nutzer per Display-Name suchen |
| GET | `/friends` | Freundschaften abrufen |
| POST | `/friends/requests` | Freundschaftsanfrage senden |
| POST | `/friends/requests/:id/accept` | Anfrage annehmen |
| DELETE | `/friends/:id` | Freundschaft entfernen |

**Besonderheiten:**
- Lazy Place Creation: Visits und Reviews legen den `DoenerPlace`-Eintrag bei Bedarf automatisch an
- Aggregate werden nach jedem Review neu berechnet (avgRating, reviewCount)
- Auth: Apple Identity Token wird dekodiert (HMAC-SHA256 Session-Token statt vapor/jwt — Kompatibilitätsproblem mit Swift-Toolchain)

---

## Setup

### Backend lokal starten

Voraussetzung: OrbStack oder Docker Desktop, Swift-Toolchain.

```bash
cd Backend

# Postgres starten (Port 5434, da 5432 ggf. belegt)
docker compose up -d db

# Backend starten
DB_PORT=5434 swift run App serve --hostname 0.0.0.0 --port 8080
```

Das Backend ist dann unter `http://<Mac-LAN-IP>:8080` erreichbar.

### iOS-App

1. Xcode öffnen: `open iOS/DoenerApp.xcodeproj`
2. Backend-URL anpassen falls nötig: `iOS/DoenerApp/Core/Network/APIConfig.swift`
   - Oder direkt in der App unter Settings → Backend-URL
3. Signing-Team setzen (Free Provisioning reicht für Entwicklung)
4. Auf echtem Gerät deployen (Simulator hat kein Sign-in with Apple)

**Netzwerk-Hinweis:** iPhone und Mac müssen im gleichen WiFi sein. Die App erlaubt LAN-HTTP via `NSAllowsLocalNetworking` in der `Info.plist`.

### Dev-Login (ohne Apple Account)

Falls kein Sign-in with Apple verfügbar:

```bash
# Backend starten mit Dev-Login aktiviert
ALLOW_DEV_LOGIN=true DB_PORT=5434 swift run App serve --hostname 0.0.0.0 --port 8080
```

In der App unter Settings → Dev-Login erscheint dann ein zusätzlicher Login-Button.

### Test-Daten

```bash
# 5 Freundschaften für letzten User anlegen (entsperrt Social Butterfly Achievement)
./scripts/seed_friendships.sh
```

---

## Design-Prinzipien

- **Glassmorphism:** `.ultraThinMaterial` durchgehend für Sheets und Overlays
- **Orange als Akzentfarbe:** konsistent für alle interaktiven Elemente
- **Spring-Physics:** Animationen basieren auf Spring-Kurven, nicht linearen Timings
- **Offline-First:** Jede Aktion wird lokal gespeichert bevor sie das Netzwerk berührt
- **Emoji als UI:** Statt Icon-Sets werden Emojis für Food-Types, Achievements und Confetti verwendet — spart Assets, wirkt lebendiger

---

## Roadmap

Siehe [BACKLOG.md](BACKLOG.md) für den detaillierten Aufgabenstand.

**Nächste Schritte (Sprint 3):**
- Freunde-Feed: gemeinsamer Activity Stream
- Push Notifications: Friend Requests, Freund bei bekanntem Laden
- Leaderboards unter Freunden
- TestFlight-Distribution (sobald Apple Developer Account aktiv)
