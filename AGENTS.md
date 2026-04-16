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

<!-- Zuletzt aktualisiert: 2026-04-16 via /save -->

**Sprint / Phase:** Sprint 3 — Launch-Readiness

**Zuletzt implementiert:**
- Security-Fixes aus externem Audit: Friendship-Richtung (DTO + Backend + iOS), specialNote-Clearing, Compose-Defaults gehärtet
- S3.8 "Apple JWT Signaturprüfung" als SECURITY-BLOCKER ins Kanban (To Do)

**Als nächstes:**
- S3.8 JWKS-Validierung implementieren (BLOCKER vor öffentlichem Hosting)
- S3.2 Coolify-Container debuggen (`COOLIFY_SPAETZLES_TOKEN` aus `~/.secrets`)
- S3.3 Google Maps Places API angehen

**Offene Punkte:**
- Apple Developer Account Approval ausstehend → TestFlight blockiert
- Container auf VPS startet nicht trotz erfolgreichem CI/CD
- DTO-Duplikation iOS/Shared noch nicht aufgelöst (auf späteren Sprint verschoben)

## Kanban

Board-ID: `3da8a65c-4b04-4ce6-b164-784687900065`

Konvention: Bei Session-Start `get-board-info` aufrufen und offene Tasks zeigen. Aktive Tasks nach In Progress ziehen, erledigte nach Done.
