# MazeDash Versioning

Diese Struktur trennt klar zwischen:

- `1.0` = aktueller Release-Stand
- `1.1` = neue laufende Features / nächste Version

## Regeln

1. `App Store / veröffentlichte Version`
   - aktuell: `1.0`

2. `laufende Entwicklung`
   - aktuell: `1.1`

3. Vor jedem größeren Stand:
   - Snapshot mit dem Script in `Tools/save_version_snapshot.sh` erstellen

4. Für jede Version gibt es:
   - eine kurze Beschreibung
   - Status
   - wichtige Ziele / Änderungen

## Ordner

- `Versions/current.json`
  - maschinenlesbarer aktueller Stand
- `Versions/1.0/`
  - Release-Notizen für 1.0
- `Versions/1.1/`
  - Plan und Änderungen für 1.1
- `Versions/_snapshots/`
  - gespeicherte Projekt-Snapshots als `.tar.gz`

## Empfohlene Nutzung

- Wenn `1.0` live ist, bleibt `1.0` die Release-Version.
- Alle neuen Features, Fixes und Umbauten laufen unter `1.1`.
- Wenn du einen sicheren Zwischenstand willst:
  - Snapshot erstellen
  - optional zusätzlich in Git committen/taggen

## Wichtiger Hinweis

Diese Struktur ändert nicht automatisch die App-Store-Version in Xcode.
Sie hilft dir zuerst dabei, deine Projektstände sauber zu organisieren.
