# Döner-App

iOS-App in Swift 6 + SwiftUI + MapKit.

## Decisions

`docs/decisions/` — Architecture Decision Records für nicht-offensichtliche Entscheidungen.
Template: `~/.claude/templates/adr.md`
Anlegen wenn: Alternative verworfen, Constraint akzeptiert, Richtungsentscheidung getroffen.

## Specs

`specs/` — ein File pro Sprint oder Feature, bevor Code geschrieben wird.
Template: `~/.claude/templates/spec.md`

Konvention:
- Neues Sprint/Feature → erst `specs/sprint-N.md` oder `specs/feature-name.md` anlegen
- Kanban-Task verlinkt auf die Spec-Datei
- Aktive Spec steht im `## Aktueller Stand`

## Aktueller Stand

<!-- Zuletzt aktualisiert: 2026-04-13 via /save -->

**Sprint / Phase:** Sprint 3 — Launch-Readiness

**Zuletzt implementiert:**
- Kanban-Board vollständig aus BACKLOG.md migriert (Single Source of Truth)
- S3.2 In Progress: CI/CD läuft (GitHub Actions → ghcr.io → Coolify-Webhook)
- `APIConfig.swift` bereits auf Prod-URL (`doener-api.diespaetzles.lol`) + UserDefaults Override

**Als nächstes:**
- Coolify-Deployment debuggen: Container startet nicht (Env-Vars / docker-compose.prod.yml in Coolify prüfen)
- `COOLIFY_SPAETZLES_TOKEN` aus `~/.secrets` nutzen für direkte API-Diagnose

**Offene Punkte:**
- Apple Developer Account Approval ausstehend → TestFlight blockiert

## Kanban

Board-ID: `3da8a65c-4b04-4ce6-b164-784687900065`

Konvention: Bei Session-Start `get-board-info` aufrufen und offene Tasks zeigen. Aktive Tasks nach In Progress ziehen, erledigte nach Done.
