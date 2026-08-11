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

<!-- Zuletzt aktualisiert: 2026-08-11 via /save -->

**Sprint / Phase:** Sprint 3 — Launch-Readiness / Beta-Feedback-Runde

**Zuletzt implementiert:**
- Feedback-Formular für Tester (Text + Screenshot) inkl. Backend-Endpoint `POST /feedback`
- Discover-Empty-State bekommt CTA-Button zur Karte (schließt Bruch nach Onboarding)
- Google Places Migration: OSM/Overpass raus, Backend-Proxy zu Google Places API (New), Place-IDs von OSM-Int64 auf Google-String umgestellt (Backend, iOS, Shared-DTOs)

**Als nächstes:**
- Google Cloud Setup (Places API (New), Billing, Budget-Alert, API-Key) — extern, durch Robin
- `GOOGLE_PLACES_API_KEY` in Coolify hinterlegen, dann Backend deployen (Migration leert `doener_places` automatisch)
- iOS Build-Nummer in `project.yml` vor nächstem TestFlight-Upload hochziehen

**Offene Punkte:**
- Google-Places-Migration ist im Code fertig, aber noch nicht live (wartet auf GCP-Setup)
- DTO-Duplikation iOS/Shared weiterhin bewusst verschoben (auch in dieser Migration nicht angefasst)

## Kanban

Board-ID: `3da8a65c-4b04-4ce6-b164-784687900065`

Konvention: Bei Session-Start `get-board-info` aufrufen und offene Tasks zeigen. Aktive Tasks nach In Progress ziehen, erledigte nach Done.
