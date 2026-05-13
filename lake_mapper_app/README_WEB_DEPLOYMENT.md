# Web Deployment - Wammsee App mit MapLibre GL JS

## Übersicht

Die Web-Version der Wammsee App verwendet MapLibre GL JS mit PMTiles für die Kartendarstellung. Die PMTiles-Datei (wammsee.pmtiles) enthält die georeferenzierte Seekarte.

## Server-Anforderungen

### 1. HTTP Range Requests (CRITICAL)

PMTiles verwendet HTTP Range Requests um einzelne Tiles aus der Datei zu laden. Der Server **muss** Range Requests unterstützen.

**Was passiert:**
- Browser fordert Tile an: `GET /assets/maps/wammsee.pmtiles`
- Server antwortet mit `206 Partial Content` und den angeforderten Bytes
- Ohne Range Support wird die gesamte Datei geladen (langsam) oder schlägt fehl

**Im Browser-Netzwerk-Tab prüfen:**
```
Status: 206 Partial Content
Content-Range: bytes 0-65535/1234567
```

### 2. CORS Header (falls nötig)

Falls die App von einer anderen Domain geladen wird:

```
Access-Control-Allow-Origin: *
Access-Control-Allow-Headers: Range
```

## Nginx Konfiguration

```nginx
server {
    listen 80;
    server_name wammsee.example.com;

    root /var/www/wammsee_app;
    index index.html;

    # Gzip für bessere Performance
    gzip on;
    gzip_types application/javascript text/css;

    # PMTiles mit Range Support
    location /web/assets/maps/ {
        # Range Requests aktivieren (Standard bei Nginx)
        add_header Accept-Ranges bytes;
        add_header Access-Control-Allow-Origin *;

        # CORS Preflight
        if ($request_method = 'OPTIONS') {
            add_header Access-Control-Allow-Origin *;
            add_header Access-Control-Allow-Methods 'GET, OPTIONS';
            add_header Access-Control-Max-Age 1728000;
            add_header Content-Type 'text/plain charset=UTF-8';
            add_header Content-Length 0;
            return 204;
        }
    }

    # Flutter Web Build
    location / {
        try_files $uri $uri/ /index.html;
    }
}
```

## Apache Konfiguration

```apache
<VirtualHost *:80>
    ServerName wammsee.example.com
    DocumentRoot /var/www/wammsee_app

    # Range Requests sind bei Apache standardmäßig aktiviert
    # Optional: explizit aktivieren
    <IfModule mod_headers.c>
        Header set Accept-Ranges "bytes"
    </IfModule>
</VirtualHost>
```

## Cloudflare / CDN

Bei Verwendung von Cloudflare:

1. **Cache Rules:** PMTiles-Dateien vom Caching ausschließen
2. **Chunked Content:** Aktivieren für Range Requests
3. **Page Rules:** Für `.pmtiles` Dateien:
   - Cache Level: Bypass
   - Disable Apps

## Fehlerbehebung

### "Wammsee-Karte konnte nicht geladen werden"

**Mögliche Ursachen:**

1. **Server unterstützt keine Range Requests**
   - Prüfe: `curl -I -H "Range: bytes=0-1" https://example.com/assets/maps/wammsee.pmtiles`
   - Erwartet: `HTTP/1.1 206 Partial Content`

2. **PMTiles-Datei nicht gefunden**
   - Prüfe: Existiert die Datei im Build-Output?
   - Prüfe: Ist der Pfad korrekt?

3. **CORS-Blockierung**
   - Prüfe Browser Console auf CORS-Fehler
   - Server muss `Access-Control-Allow-Origin` Header senden

4. **Falsches PMTiles-Format**
   - Die Datei muss eine gültige PMTiles-Datei sein (magic bytes: "PMTl")
   - Prüfe mit: `head -c 16 wammsee.pmtiles | xxd`

## Build & Deployment

```bash
# Web Build erstellen
cd lake_mapper_app
flutter build web

# Build-Output prüfen
ls -la build/web/

# Ins Server-Verzeichnis kopieren
scp -r build/web/* user@server:/var/www/wammsee_app/
```

## Entwicklung

### Lokaler Server

```bash
cd lake_mapper_app
flutter run -d chrome

# Oder mit eigenem Server:
cd build/web
python3 -m http.server 8080
# -> http://localhost:8080
```

### Debugging im Browser

1. **Netzwerk-Tab:** Prüfe ob PMTiles mit 206 geladen wird
2. **Console:** Prüfe auf MapLibre-Fehler
3. **Quellcode:** maplibre_init.js und maplibre_bridge.js prüfen

### Debug-Panel

Im MapLibreWidget (oben links) werden angezeigt:
- PMTiles geladen: OK/FAIL
- Aktueller Zoom
- Kartenmitte
- Letzter Fehler

## Dateien

| Datei | Beschreibung |
|-------|--------------|
| `web/maplibre_init.js` | CDN-Lader für MapLibre GL JS |
| `web/maplibre_bridge.js` | MapLibre-API Bridge |
| `lib/services/maplibre_bridge.dart` | Dart-JS Interop Wrapper |
| `lib/widgets/maplibre_widget.dart` | Flutter Widget |
| `lib/screens/map_screen_web.dart` | Web-spezifischer Map-Screen |
| `assets/maps/wammsee.pmtiles` | Die PMTiles-Datei |

## Technische Details

### MapLibre GL JS Version
- Version: 4.7.1
- CDN: unpkg.com/maplibre-gl

### PMTiles.js Version
- Version: 3.0.6
- CDN: unpkg.com/pmtiles

### Koordinaten-System
- GeoJSON Standard: [longitude, latitude]
- Flutter MapLibre: lat/lng separat
- Wammsee Mitte: 49.3425°N, 8.4495°E
