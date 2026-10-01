# Döner-App 🥙

Eine App zum Finden, Bewerten und Sammeln von Dönerläden – für iOS, Android und Web aus einer Codebase. Offline-First, Community-getrieben, mit Gamification-Mechaniken, die an Pokémon Go und Spotify Wrapped erinnern.

---

## Überblick

Die Döner-App verbindet eine persönliche Stempelkarte mit einem sozialen Layer: Nutzer checken bei Läden ein, bewerten nach Soße/Fleisch/Brot, verfolgen ihre eigene Döner-Geschichte und sehen, was Freunde gerade essen.

**Stack:**
- App: Flutter (iOS, Android, Web), Google Maps (google_maps_flutter), sembast als lokaler Store
- Server: Dart (shelf), PostgreSQL – liefert auch die Web-App aus
- Geteilt: `packages/doener_models` – DTOs, Validierung und Gamification-Regeln für App und Server
- Läden: Google Places API (New), serverseitig abgefragt und gecacht
- Login: E-Mail-Code bzw. Magic-Link, kein Passwort; Pflicht, samt eigenem Anzeigenamen statt „Döner-Fan-1234“

---

## Features

### Karte

Die Karte lädt Dönerläden für den sichtbaren Ausschnitt (nur bis 0,5° Span). Der Server fragt Google pro Kachel (0,03°) höchstens alle 25 Tage ab, auch leere Kacheln werden gemerkt. Das hält die Google-Kosten klein. Erkannt werden Läden über den Namen (Döner, Kebap, Dürüm, Yufka …) oder den Google-Typ (z. B. türkisches Restaurant).

Google erlaubt, Laden-Details höchstens 30 Tage zu speichern (nur die Place ID unbegrenzt) und Places-Daten nur auf Google-Karten zu zeigen. Deshalb: Karte von Google Maps, ein täglicher Job auf dem Server frischt Läden mit Besuchen oder Bewertungen auf und löscht ungenutzte nach 30 Tagen, die App verwirft ihren lokalen Cache ebenso. Listen ohne Karte tragen den Hinweis „Ortsdaten: Google Maps“.

- Pins: orange, besuchte Läden grün, Favoriten pink; fremde Geschäfts-POIs sind ausgeblendet
- Favoriten-Filter per Herz oben rechts
- „Laden fehlt?“ oben links schickt eine Meldung samt Kartenposition an den Server

### Check-In

Ein Drehrad mit 6 Essenstypen (Döner, Yufka, Lahmacun, Teller, Pommes, Falafel) – das oberste Symbol ist ausgewählt. Danach regnet es Emojis des gewählten Essens.

- Check-ins werden sofort lokal gespeichert und über eine Sync-Queue an den Server geschickt
- Die ID erzeugt der Client, deshalb entstehen bei Wiederholungen keine doppelten Besuche
- Ein Check-in setzt für 2 Stunden den Live-Status („isst gerade bei …“), aber nur wenn er wirklich gerade passiert

### Bewertungen

Ein Gesamtrating (1–5) plus drei optionale Dimensionen: Soße, Fleisch, Brot. Das Gesamtrating ist automatisch der Durchschnitt der Dimensionen und kann manuell überschrieben werden.

- Eine Bewertung pro Nutzer und Laden – eine neue ersetzt die alte
- „Was macht den Laden besonders?“ gehört zur eigenen Bewertung; der Laden zeigt die jüngste solche Notiz
- Durchschnitt und Anzahl berechnet der Server beim Lesen, nichts wird doppelt gespeichert
- In der Laden-Ansicht: eigene Bewertung, Community-Zusammenfassung und Bewertungen anderer

### Profil & Stempelkarte

Das Profil ist der persönliche Döner-Pass: Besuche, Bewertungen, Läden, Döner-Konsum nach Essenstyp und „Seit [Monat Jahr]“ ab dem ersten Check-in.

| Stufe | Ab Besuchen | Farbe |
|---|---|---|
| Dönerneuling | 0 | Grau |
| Dönerfreund | 5 | Braun |
| Dönerfan | 15 | Orange |
| Dönerprofi | 30 | Rot |
| Dönermeister | 60 | Lila |
| Dönerlegende | 100 | Gold |

### Erfolge

| Erfolg | Bedingung |
|---|---|
| First Bite | Erster Check-in |
| Kritiker | Erste Bewertung |
| Stammgast | 5× derselbe Laden |
| Entdecker | 10 verschiedene Läden |
| Kenner | 50 verschiedene Läden |
| Berlin Döner Tour | 5 Läden in Berlin |
| Hamburg Döner Tour | 5 Läden in Hamburg |
| Silber-Sammler | Stufe „Dönerfan“ erreicht |
| Gold-Sammler | Stufe „Dönermeister“ erreicht |
| Nachtschwärmer | Check-in nach 22 Uhr |
| Schmetterling | 5 Freunde |

Die Regeln liegen in `packages/doener_models` und sind dort getestet.

### Döner Wrapped

Jahresrückblick auf 5 Seiten mit wechselnden Farbverläufen: Besuche im Jahr, Lieblingsessen, Stammladen, entdeckte Läden, Zusammenfassung mit aktivstem Monat.

### Freunde & Feed

- Persönlicher Einladungslink samt QR-Code (Profil, Freunde-Liste, letzter Onboarding-Schritt): Wer ihn öffnet und sich anmeldet, ist sofort befreundet, eine offene Anfrage gilt damit als angenommen. Der Link lässt sich zurücksetzen.
- Ohne App führt der Link auf eine Einladungsseite (`/i/<code>`) mit Chat-Vorschau, von dort in die Web-App. Neue Accounts merken sich, über wessen Link sie kamen.
- Freunde per Namenssuche finden (ab 2 Zeichen); wer eine offene Anfrage zurückschickt, nimmt sie damit an
- Freunde-Feed mit Check-ins und Bewertungen, dazu Live-Status der Freunde
- „Meine“-Feed zeigt die eigene Aktivität, noch nicht übertragene Einträge sind markiert

### Ranking & Entdecken

- Ranking: alle Läden, bei denen man war oder die man bewertet hat – sortiert nach Bewertung, Besuchen oder zuletzt besucht
- Entdecken: bestbewertete Läden in der Nähe, „Gerade im Hype“ (Aktivität der letzten 7 Tage), eigene neue Bewertungen, Suche in allen bekannten Läden

---

## Architektur

```
app/                          Flutter-App (iOS, Android, Web)
├── lib/src/core/             ApiClient, Session, AppData (lokaler Store + Sync-Queue), Standort
├── lib/src/features/         auth, map, place, feed, ranking, discover, profile, social, settings, onboarding
└── lib/src/ui/               Theme und gemeinsame Widgets
server/                       Dart-API + Auslieferung der Web-App
├── lib/src/auth.dart         Magic-Link-Login, Sitzungen, Account
├── lib/src/places.dart       Läden, Bewertungen, Besuche
├── lib/src/social.dart       Feed, Live-Status, Freunde, Feedback, Ladenmeldungen
├── lib/src/google_places.dart
├── lib/src/db.dart           SQL-Migrationen (nur anhängen, nie ändern)
└── tool/seed_dev.dart        Test-Läden in Freiburg für Entwicklung ohne Google-Key
packages/doener_models/       Geteilte DTOs, Validierung, Stempel/Erfolge/Essenstypen
```

**Prinzipien:**
- Offline-First: Die App zeigt alles aus dem lokalen Store. Eigene Besuche und Bewertungen warten in einer Queue, bis der Server sie bestätigt.
- Bei einem Netzwerkfehler versucht die App es später erneut, auch eine abgelaufene Sitzung verwirft keine Einträge. Nur was der Server endgültig ablehnt (z. B. ungültige Daten), wird verworfen.
- Der Server ist die Quelle der Wahrheit für den Account. Ein neues Gerät oder die Web-App holt sich Besuche und Bewertungen über `/me/*`.
- Favoriten und Notizen bleiben lokal auf dem Gerät.

### API (`/api/v1`)

| Methode | Pfad | Beschreibung |
|---|---|---|
| POST | `/auth/login` | Login-Code + Magic-Link per Mail schicken |
| POST | `/auth/verify` | Code oder Link-Token einlösen → Sitzung |
| POST | `/auth/logout` | Sitzung beenden |
| GET | `/auth/me` | Aktueller User |
| PATCH | `/users/me` | Anzeigename ändern |
| DELETE | `/users/me` | Account löschen |
| GET | `/places?minLat&minLon&maxLat&maxLon` | Läden im Kartenausschnitt |
| GET | `/places/top?lat&lon` | Bestbewertete in der Nähe |
| GET | `/places/trending` | Meiste Aktivität der letzten Tage |
| GET | `/places/:placeId` | Laden (Google Place ID) |
| GET | `/places/:placeId/reviews` | Bewertungen des Ladens |
| GET | `/places/:placeId/summary` | Community-Zusammenfassung |
| PUT | `/places/:placeId/review` | Eigene Bewertung speichern |
| POST | `/places/:placeId/visits` | Check-in (idempotent über Client-ID) |
| GET | `/me/visits`, `/me/reviews`, `/me/places` | Eigene Daten |
| DELETE | `/me/live-status` | Live-Status beenden |
| GET | `/feed?cursor` | Freunde-Feed (Keyset-Pagination) |
| GET | `/feed/live` | Live-Status der Freunde |
| GET | `/users/search?q` | Nutzer suchen |
| GET | `/friends` | Freundschaften |
| POST | `/friends/requests` | Anfrage senden |
| POST | `/friends/:id/accept` | Anfrage annehmen |
| DELETE | `/friends/:id` | Freundschaft entfernen |
| GET | `/me/invite` | Eigener Einladungslink |
| POST | `/me/invite/reset` | Neuer Einladungslink, der alte verfällt |
| GET | `/invites/:code` | Wer einlädt (ohne Login) |
| POST | `/invites/:code/accept` | Einladung annehmen → sofort befreundet |
| POST | `/feedback` | Feedback mit optionalem Screenshot |
| POST | `/shop-reports` | Fehlenden Laden melden |

Außerhalb von `/api/v1` liefert der Server unter `/i/:code` die Einladungsseite aus.

---

## Entwicklung

Voraussetzung: [Flutter-SDK](https://docs.flutter.dev/get-started/install) (bringt Dart mit) und Docker. iOS-Builds brauchen macOS – das übernimmt die CI, entwickelt werden kann komplett unter Linux.

### Alles in einem

```bash
docker compose up --build        # App + API auf http://localhost:8080, Postgres auf :5434
```

Ohne `SMTP_HOST` landen die Login-Codes im Log (`docker compose logs app`).

### Einzeln (schneller beim Entwickeln)

```bash
docker compose up -d db

# Server
cd server
DB_PORT=5434 dart run tool/seed_dev.dart                    # Test-Läden, falls kein Google-Key
DB_PORT=5434 CORS_ORIGIN=http://localhost:5000 dart run bin/server.dart

# App im Browser
cd app
flutter run -d chrome --web-port 5000 --dart-define=API_BASE=http://localhost:8080/api/v1 \
  --dart-define=GOOGLE_MAPS_WEB_KEY=<Browser-Key>

# App im Android-Emulator
GOOGLE_MAPS_ANDROID_KEY=<Android-Key> flutter run -d emulator-5554 --dart-define=API_BASE=http://10.0.2.2:8080/api/v1
```

Für iOS den Key in `app/ios/Flutter/Secrets.xcconfig` eintragen (`GOOGLE_MAPS_IOS_KEY=…`, nicht eingecheckt).

In der App lässt sich die Backend-URL auch unter Einstellungen → Backend-URL umstellen.

### Tests

```bash
cd packages/doener_models && dart test
cd server && TEST_DB_PORT=5434 TEST_DB_USER=doener TEST_DB_PASSWORD=doener dart test   # legt DB doener_test neu an
cd app && flutter test
```

### Konfiguration

**Server (Umgebungsvariablen):**

| Variable | Standard | Zweck |
|---|---|---|
| `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_PASSWORD` | `localhost`, `5432`, `doener`, `doener`, `doener` | Postgres |
| `DB_TLS` | – | `require` für TLS zur Datenbank |
| `PORT` | `8080` | HTTP-Port |
| `PUBLIC_URL` | – | Basis für Magic-Links (`/login?token=…`) und Einladungslinks (`/i/…`); ohne steht nur der Code in der Mail |
| `GOOGLE_PLACES_API_KEY` | – | Ohne Key nur bereits bekannte Läden |
| `SMTP_HOST`, `SMTP_PORT`, `SMTP_USER`, `SMTP_PASSWORD`, `SMTP_SSL` | –, `587` | Mailversand; ohne Host stehen Codes im Log |
| `MAIL_FROM` | `Döner App <noreply@localhost>` | Absender |
| `WEB_DIR` | `web` | Web-Build, der unter `/` ausgeliefert wird |
| `CORS_ORIGIN` | – | Nur für lokale Web-Entwicklung |
| `APP_DOWNLOAD_URL` | – | Ziel von „App holen“ auf der Einladungsseite (z. B. öffentlicher TestFlight-Link); ohne nur Web-App |

**App (`--dart-define`):**

| Variable | Standard | Zweck |
|---|---|---|
| `API_BASE` | Web: gleiche Domain; Mobil: Produktion | API-Adresse |
| `GOOGLE_MAPS_WEB_KEY` | – | Maps-JavaScript-Key für die Web-Version (ohne: keine Karte) |

**Google-Maps-Keys** (Google Cloud Console, je ein Key pro Plattform): „Maps SDK for iOS“ (eingeschränkt auf Bundle-ID `com.robinchoice.doener`), „Maps SDK for Android“ (Paketname + SHA-1 des Signaturzertifikats), „Maps JavaScript API“ (HTTP-Referrer der Web-Domain). Der Server braucht zusätzlich einen Key für „Places API (New)“.

---

## Deployment

| Workflow | Auslöser | Macht |
|---|---|---|
| `ci.yml` | PRs, Push auf `main` | Analyse + Tests für Models, Server (mit Postgres) und App |
| `deploy.yml` | Push auf `main` (`server/`, `app/`, `packages/`) | arm64-Image `ghcr.io/robinchoice/doener-api:<sha>` bauen, auf Coolify deployen |
| `mobile.yml` | Push auf `main` (`app/`, `packages/`), manuell | iOS → TestFlight, Android → signiertes App Bundle als Artefakt |

Das Image enthält Server und Web-App: Die API liegt unter `/api/v1`, alles andere ist die Web-App.

**Secrets:**
- Coolify: `COOLIFY_APP_UUID`, `COOLIFY_TOKEN`
- Google Maps: `GOOGLE_MAPS_IOS_KEY`, `GOOGLE_MAPS_ANDROID_KEY`, `GOOGLE_MAPS_WEB_KEY`
- iOS: `ASC_KEY_P8` (Base64), `ASC_KEY_ID`, `ASC_ISSUER_ID`
- Android: `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD` – ohne sie wird mit Debug-Keys signiert

Die Build-Nummer steigt pro Lauf automatisch (TestFlight lehnt doppelte ab).

---

## Design-Prinzipien

- **Orange als Akzentfarbe:** konsistent für alle interaktiven Elemente, Material 3, Hell- und Dunkelmodus
- **Offline-First:** Jede Aktion wird lokal gespeichert, bevor sie das Netzwerk berührt
- **Emoji als UI:** Essenstypen, Konfetti und Wrapped nutzen Emojis statt eigener Grafiken
- **FOSS, wo es geht:** Flutter, Dart, Postgres, Web-Ressourcen selbst gehostet statt vom CDN. Karte und Laden-Daten kommen von Google, weil OpenStreetMap deutlich weniger Döner-Läden und Öffnungszeiten kennt.

---

## Offene Punkte

- Universal Links / App Links, damit der Magic-Link direkt die App öffnet (bis dahin: Code eintippen)
- Upload ins Play Store (bisher nur das App Bundle als Artefakt)
