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

<!-- Zuletzt aktualisiert: 2026-04-23 via /save -->

**Sprint / Phase:** Sprint 3 — Launch-Readiness (Beta-Ziel: Freitag 2026-04-25)

**Zuletzt implementiert:**
- Coolify: Postgres-DB + App-Container via API angelegt, alle Env-Vars gesetzt
- Dockerfile-Fix: `libssl3` zur Prod-Image-Runtime hinzugefügt (war Crash-Ursache)
- GitHub Secrets `COOLIFY_APP_UUID` + `COOLIFY_TOKEN` auf neue Coolify-App aktualisiert
- CI/CD-Build läuft (Image-Rebuild mit libssl3-Fix)

**Als nächstes:**
- CI/CD abwarten, dann Deploy triggern: `curl -X POST ... /api/v1/applications/jdna5c4aqx6bf6u10bs5j48n/start`
- iOS App-URL von LAN-IP auf Prod-Backend umstellen (`APIConfig.swift`)
- S3.8 Apple JWKS-Validierung implementieren (SECURITY-BLOCKER)

**Offene Punkte:**
- Coolify App-UUID: `jdna5c4aqx6bf6u10bs5j48n` · DB-UUID: `mzu4msj785xpe5nl6ypntb4d`
- Apple Developer Account Approval ausstehend → Sideload als Beta-Verteilung
- DTO-Duplikation iOS/Shared auf späteren Sprint verschoben

## Kanban

Board-ID: `3da8a65c-4b04-4ce6-b164-784687900065`

Konvention: Bei Session-Start `get-board-info` aufrufen und offene Tasks zeigen. Aktive Tasks nach In Progress ziehen, erledigte nach Done.
