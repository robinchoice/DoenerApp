# Döner-App

iOS-App in Swift 6 + SwiftUI + MapKit.

## Decisions

`docs/decisions/` — Architecture Decision Records für nicht-offensichtliche Entscheidungen.
Template: `docs/templates/adr.md`
Anlegen wenn: Alternative verworfen, Constraint akzeptiert, Richtungsentscheidung getroffen.

## Specs

`specs/` — ein File pro Sprint oder Feature, bevor Code geschrieben wird.
Template: `docs/templates/spec.md`

Konvention:
- Neues Sprint/Feature → erst `specs/sprint-N.md` oder `specs/feature-name.md` anlegen
- Kanban-Task verlinkt auf die Spec-Datei
- Aktive Spec steht im `## Aktueller Stand`

## Aktueller Stand

<!-- Zuletzt aktualisiert: 2026-04-13 via /save -->

**Sprint / Phase:** Sprint 3 — Launch-Readiness

**Zuletzt implementiert:**
- S3.1 Offline-Sync Queue (SyncQueueService, VisitSyncService, ReviewSyncService refactored)
- S3.4 Freunde-Feed + Live-Status komplett (Backend FeedController + iOS FeedStore/FeedView)
- Kanban migriert, BACKLOG.md ist nur noch historisch

**Als nächstes:**
- S3.2 Coolify-Container debuggen (`COOLIFY_SPAETZLES_TOKEN` aus `~/.secrets`)
- S3.4 end-to-end testen (zwei Dev-Logins, Freundschaft, Feed prüfen)
- S3.3 Google Maps Places API angehen

**Offene Punkte:**
- Apple Developer Account Approval ausstehend → TestFlight blockiert
- Container auf VPS startet nicht trotz erfolgreichem CI/CD

## Kanban

Board-ID: `3da8a65c-4b04-4ce6-b164-784687900065`

Konvention: Bei Session-Start `get-board-info` aufrufen und offene Tasks zeigen. Aktive Tasks nach In Progress ziehen, erledigte nach Done.
