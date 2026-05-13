# Kartenproblem - Flutter Web mit PMTiles — GELÖST

## Status: ✅ GELÖST (2026-05-12)

## Ursprüngliches Problem

Die Flutter Web App zeigte beim Öffnen der Karte eine weiße Seite. Das MapLibre GL JS + PMTiles Rendering funktionierte nicht.

## Ursachenanalyse (korrigiert)

### 1. PMTiles-Datei Format — KORREKTUR
- **Datei**: `assets/maps/wammsee.pmtiles` (2.9 MB)
- **Format**: **MVT (Vektor-Tiles!)** — NICHT Raster wie ursprünglich vermutet
- **PMTiles Header**:
  ```
  Magic: PMTiles (v3)
  Tile Type: MVT (1) — Vektor!
  Komprimierung: gzip
  Min/Max Zoom: 0-14
  Bounds: [8.42, 49.325] → [8.475, 49.36]
  39 Tiles, Protomaps Basemap
  ```
- **Layer**: water, earth, landuse, roads, buildings, places, pois, boundaries, natural

### 2. Server fehlte Range Request Support
- `serveStatic()` nutzte `fs.readFile()` (liest alles auf einmal)
- PMTiles.js braucht `206 Partial Content` mit `fs.createReadStream()`
- **Fix**: `serveStatic()` unterstützt jetzt HTTP Range Requests

### 3. Kein HTML-Container im DOM (Race Condition)
- `_buildMapContainer()` erstellte nur ein Flutter-Widget, kein HTML-Element
- MapLibre GL JS braucht ein echtes DOM-Element
- **Fix**: `HtmlElementView` + `platformViewRegistry` erstellt echtes `<div>` Element

### 4. PMTiles Protocol nicht registriert
- `pmtiles.js` wurde geladen, aber die Source nutzte nur OSM-Tiles
- **Fix**: PMTiles als `vector`-Source mit `pmtiles://` Protocol registriert

## Lösung

### server.js
- `serveStatic()` mit Range Request Support (`fs.stat` + `fs.createReadStream`)
- CORS-Header inkl. `Access-Control-Expose-Headers: Content-Range, Accept-Ranges`
- `.pmtiles` MIME-Type hinzugefügt

### maplibre_bridge.js
- PMTiles URL wird relativ zum base-href aufgelöst
- PMTiles als `vector`-Source mit `pmtiles://` Protocol
- Alle Vektor-Layer (water, earth, landuse, roads, etc.) gestyled
- OSM Raster als Basiskarte, PMTiles-Vektor darüber

### map_screen_web.dart
- `HtmlElementView` mit `platformViewRegistry` für echtes DOM-Element
- `dart:html` + `dart:ui_web` importiert

### maplibre_web.dart (Service)
- Container-Polling (bis 10s) gegen Race Condition
- Wartet bis DOM-Element existiert bevor MapLibre initialisiert wird

## Dateien (aktualisiert)

```
lake_mapper_app/
├── web/
│   ├── maplibre_init.js      # CDN Loader (MapLibre + PMTiles Protocol)
│   └── maplibre_bridge.js   # MapLibre API mit PMTiles Vektor-Source
├── lib/
│   ├── services/
│   │   └── maplibre_web.dart  # Dart JS-Interop mit Container-Polling
│   └── screens/
│       └── map_screen_web.dart # HtmlElementView für MapLibre
└── assets/maps/
    └── wammsee.pmtiles      # MVT Vektor-Tiles (Protomaps Basemap)
```

## Remote Deployment

Siehe `DEPLOY_WEB.md` für das vollständige Deployment-Verfahren.

```bash
# Quick Deploy
/home/schaf/develop/flutter/bin/flutter build web --no-tree-shake-icons && \
sed -i 's|<base href="/">|<base href="/web/">|g' build/web/index.html && \
rsync -avz --delete build/web/ arxlabs.dev:/home/schaf/wammsee/public/web/
```
