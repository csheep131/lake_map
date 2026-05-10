Phase 1 — Kartenbasis sauber machen

Ziel: Weg von Screenshots, hin zu echter GPS-Karte.

Cursor-Prompt:

Baue die bestehende Flutter-App so um, dass sie eine echte Kartenansicht für den Wammsee verwendet.

Technik:
- flutter_map
- latlong2
- OpenStreetMap TileLayer
- SQLite bleibt für Messpunkte
- Keine Google-Maps-Screenshots als Kartenbasis verwenden

Startkoordinate:
LatLng(49.346970, 8.446897)

Aufgaben:
1. Erstelle oder überarbeite lib/screens/lake_map_screen.dart.
2. Zeige FlutterMap mit initialCenter LatLng(49.346970, 8.446897).
3. Setze initialZoom auf 16 oder 17.
4. Nutze vorerst OSM-Tiles:
   https://tile.openstreetmap.org/{z}/{x}/{y}.png
5. Setze userAgentPackageName sauber auf z. B.:
   de.tom.wammsee_mapper
6. Ergänze unten rechts oder in einer Infoleiste die Attribution:
   © OpenStreetMap contributors
7. Die Karte muss zoombar und verschiebbar sein.
8. Beim Tippen auf die Karte muss die echte LatLng-Koordinate verfügbar sein.
Phase 2 — Datenmodell für See und Messpunkte

Ziel: Wammsee, Messpunkte und Tiefen strukturiert speichern.

Überarbeite die lokale SQLite-Struktur.

Tabellen:

lakes:
- id INTEGER PRIMARY KEY AUTOINCREMENT
- name TEXT NOT NULL
- center_lat REAL NOT NULL
- center_lon REAL NOT NULL
- created_at TEXT NOT NULL

depth_points:
- id INTEGER PRIMARY KEY AUTOINCREMENT
- lake_id INTEGER NOT NULL
- point_no INTEGER
- latitude REAL NOT NULL
- longitude REAL NOT NULL
- depth_m REAL NOT NULL
- accuracy_m REAL
- note TEXT
- created_at TEXT NOT NULL

Beim ersten Start:
- Lege automatisch einen See "Wammsee" an.
- center_lat = 49.346970
- center_lon = 8.446897

Erstelle passende Models:
- Lake
- DepthPoint

Erstelle DatabaseHelper-Methoden:
- initDatabase()
- getOrCreateWammsee()
- insertDepthPoint()
- getDepthPointsForLake()
- deleteDepthPoint()
- updateDepthPoint()
- getNextPointNumber()
Phase 3 — Tippen auf Karte = GPS + Tiefe speichern

Ziel: Du tippst auf Karte, gibst Tiefe ein, Punkt erscheint.

Implementiere im LakeMapScreen:

1. onTap der FlutterMap nutzen.
2. Beim Tap öffnet sich ein Dialog "Messpunkt speichern".
3. Im Dialog anzeigen:
   - Latitude mit 6 Nachkommastellen
   - Longitude mit 6 Nachkommastellen
   - Eingabefeld "Tiefe in m"
   - optionales Notizfeld
4. Komma und Punkt als Dezimaltrenner akzeptieren.
5. Nur Tiefe > 0 erlauben.
6. Nach Speichern:
   - point_no automatisch vergeben
   - Datensatz in SQLite speichern
   - Marker sofort auf Karte anzeigen
7. Marker zeigt die Punktnummer.
8. Beim Antippen eines Markers:
   - Punktnummer
   - Tiefe
   - GPS
   - Datum/Uhrzeit
   - Notiz anzeigen
Phase 4 — Aktuelle Handyposition nutzen

Ziel: Beim Rudern nicht auf Karte tippen müssen, sondern aktuellen Standort speichern.

Integriere geolocator.

Funktionen:
1. Standortberechtigung beim Start prüfen.
2. Aktuelle GPS-Position holen.
3. Oben eine Statusleiste anzeigen:
   - aktuelle Latitude
   - aktuelle Longitude
   - GPS-Genauigkeit in Metern
4. Button einbauen:
   "Aktuelle Position speichern"
5. Beim Klick:
   - aktuelle GPS-Position holen
   - Tiefendialog öffnen
   - Tiefe speichern
   - Marker an aktueller Position setzen
6. Wenn GPS-Genauigkeit schlechter als 10 m:
   - Warnung anzeigen, aber Speichern erlauben
7. Marker für aktuelle Position separat anzeigen.
Phase 5 — Wammsee-Umriss als Polygon

Ziel: Der rote Umriss aus Google Maps wird als eigener Layer nachgebaut.

Wichtig: Nicht aus Google kopieren. Besser:

- aus OpenStreetMap/Overpass extrahieren
- oder manuell in der App entlang des Ufers Punkte setzen
- oder später QGIS/GeoJSON nutzen

Cursor-Prompt:

Erstelle eine Datei:

lib/data/wammsee_polygon.dart

Darin:
- const List<LatLng> wammseePolygon = [...]

Ergänze im LakeMapScreen einen PolygonLayer:
- rote oder blaue Uferlinie
- leicht transparente blaue Füllung
- borderStrokeWidth 2 oder 3

Wenn noch keine echten Polygonpunkte vorhanden sind:
- Erstelle eine grobe Platzhalterform um den Wammsee anhand der Startkoordinate.
- Markiere die Datei klar mit TODO:
  "Diese Polygonpunkte müssen später durch echte GeoJSON-Koordinaten ersetzt werden."

Später machen wir daraus ein echtes GeoJSON:

assets/geo/wammsee.geojson
Phase 6 — Messpunktübersicht und Export

Ziel: Deine gesammelten Daten rausbekommen.

Erstelle ExportService:

lib/services/export_service.dart

Funktionen:
1. exportDepthPointsToCsv()
2. exportDepthPointsToGeoJson()

CSV-Spalten:
- point_no
- latitude
- longitude
- depth_m
- accuracy_m
- note
- created_at

GeoJSON:
- FeatureCollection
- Jeder Messpunkt als Point
- Properties:
  - point_no
  - depth_m
  - accuracy_m
  - note
  - created_at

UI:
- Button "Export CSV"
- Button "Export GeoJSON"
- Exportdatei im App-Dokumentordner speichern
Phase 7 — Offline-Modus für Wammsee

Ziel: Am See auch ohne Netz funktionieren.

Für privat/testweise kannst du erst online arbeiten. Für echten Einsatz am See würde ich später Offline-Kacheln für nur diesen Bereich vorbereiten.

Cursor-Prompt:

Bereite die App auf Offline-Karten vor.

Variante A:
- Verwende flutter_map_tile_caching.
- Erstelle einen Cache-Bereich für den Wammsee.
- Lade Zoomlevel 14 bis 18 für den Wammsee vor.
- Baue einen Screen "Offline-Karten":
  - Button "Wammsee-Karte herunterladen"
  - Fortschrittsanzeige
  - Speichergröße anzeigen
  - Button "Cache löschen"

Variante B:
- Wenn flutter_map_tile_caching zu komplex ist:
  - Erstelle zunächst nur eine saubere TileProvider-Abstraktion.
  - OnlineTileProvider und später OfflineTileProvider vorbereiten.

Offline-Caching ist bei flutter_map ein normaler Anwendungsfall; FMTC bietet dafür dynamisches Caching und Bulk-Download von Regionen.

Phase 8 — Tiefenfarben auf der Karte

Ziel: Man sieht schnell, wo es flach/tief ist.

Erweitere Marker-Farbe nach Tiefe:

0 - 1 m: hellblau
1 - 2 m: türkis
2 - 4 m: blau
4 - 6 m: dunkelblau
> 6 m: violett/dunkel

Marker:
- Punktnummer im Kreis
- Farbe abhängig von depth_m

Ergänze Legende:
- Farbbalken Tiefe
- Anzahl Messpunkte
- tiefster Punkt
- durchschnittliche Tiefe
Großer Cursor-Gesamtprompt

Den kannst du direkt verwenden:

Du arbeitest an einer bestehenden Flutter-App namens Wammsee Mapper.

Ziel:
Die App soll kostenlos/praktisch kostenlos für den Wammsee in Speyer funktionieren. Sie soll keine Google-Maps-Screenshots als Kartenbasis verwenden, sondern eine echte GPS-fähige Karte mit flutter_map. Der Nutzer rudert auf dem See, das Handy liefert GPS, der Nutzer gibt die gemessene Tiefe ein und speichert den Punkt. Jeder Punkt erscheint sofort auf der Karte. Beim Antippen eines Punkts werden Tiefe, GPS-Koordinaten und Zeitpunkt angezeigt.

Wichtige Startdaten:
- See: Wammsee, 67346 Speyer
- Startzentrum: LatLng(49.346970, 8.446897)
- Kartenbibliothek: flutter_map
- Koordinaten: latlong2
- Datenbank: sqflite
- GPS: geolocator
- Speicherung: lokal, keine Cloud, kein Login

Architektur:
lib/
  main.dart
  models/
    lake.dart
    depth_point.dart
  database/
    app_database.dart
  screens/
    lake_map_screen.dart
    point_list_screen.dart
    settings_screen.dart
  services/
    location_service.dart
    export_service.dart
  data/
    wammsee_polygon.dart

Aufgaben:

1. Kartenansicht:
- Erstelle/überarbeite lake_map_screen.dart.
- Nutze FlutterMap.
- initialCenter = LatLng(49.346970, 8.446897)
- initialZoom = 16 oder 17.
- Verwende vorerst OpenStreetMap TileLayer.
- Setze userAgentPackageName = "de.tom.wammsee_mapper".
- Zeige Attribution "© OpenStreetMap contributors".

2. SQLite:
- Erstelle app_database.dart.
- Lege Tabellen lakes und depth_points an.
- Beim ersten Start automatisch Lake "Wammsee" anlegen.
- Methoden:
  - getOrCreateWammsee()
  - insertDepthPoint()
  - getDepthPointsForLake()
  - updateDepthPoint()
  - deleteDepthPoint()
  - getNextPointNumber()

3. Models:
- Lake:
  - id
  - name
  - centerLat
  - centerLon
  - createdAt
- DepthPoint:
  - id
  - lakeId
  - pointNo
  - latitude
  - longitude
  - depthM
  - accuracyM
  - note
  - createdAt

4. Karte antippen:
- Implementiere onTap.
- Beim Tippen Dialog öffnen:
  - GPS-Koordinaten anzeigen
  - Tiefe in Meter eingeben
  - optional Notiz
- Komma und Punkt als Dezimaltrenner erlauben.
- Nur Tiefe > 0 speichern.
- Nach Speichern Punkt in SQLite schreiben und Marker sofort aktualisieren.

5. Aktuelle Position:
- Integriere geolocator.
- Standortberechtigung sauber abfragen.
- Aktuelle Position anzeigen.
- Button "Aktuelle Position speichern".
- Beim Klick aktuelle GPS-Koordinate holen und Tiefendialog öffnen.
- accuracy_m speichern.
- Warnung anzeigen, wenn accuracy_m > 10.

6. Marker:
- Alle gespeicherten Punkte beim Öffnen laden.
- Marker mit Punktnummer anzeigen.
- Markerfarbe abhängig von Tiefe:
  - 0-1 m hellblau
  - 1-2 m türkis
  - 2-4 m blau
  - 4-6 m dunkelblau
  - >6 m violett
- Marker antippen öffnet Detaildialog:
  - Punktnummer
  - Tiefe
  - GPS
  - Genauigkeit
  - Datum/Zeit
  - Notiz
  - Button Löschen
  - Button Bearbeiten

7. Wammsee-Umriss:
- Erstelle lib/data/wammsee_polygon.dart.
- Ergänze PolygonLayer mit Wammsee-Umriss.
- Falls keine echten Koordinaten vorhanden sind, verwende grobe Platzhalter und markiere TODO.
- Später soll assets/geo/wammsee.geojson unterstützt werden.

8. Export:
- Erstelle export_service.dart.
- Exportiere alle Messpunkte als CSV.
- Exportiere alle Messpunkte als GeoJSON FeatureCollection.
- UI-Buttons:
  - "CSV exportieren"
  - "GeoJSON exportieren"

9. Offline-Vorbereitung:
- Baue die TileLayer-Konfiguration so, dass später leicht ein OfflineTileProvider eingebaut werden kann.
- Optional Screen "Offline-Karten" vorbereiten, aber noch nicht zwingend vollständig implementieren.

10. UI:
- Oben eine kompakte Infoleiste:
  - Messpunkte: Anzahl
  - letzte Tiefe
  - aktuelle GPS-Genauigkeit
- Unten Floating Buttons:
  - aktuelle Position speichern
  - Karte auf GPS zentrieren
  - Export
- Design passend zum Logo:
  - Navy
  - Türkis
  - Hellblau
  - Grün als Akzent

Wichtig:
- Kein Google-Maps-Screenshot als Kartenbasis.
- Keine Cloud.
- Kein Login.
- Erst lokal robust und einfach.
- Code sauber modularisieren.
- Bestehende App nicht zerstören, sondern minimal-invasiv umbauen.
- Nach jedem Schritt sicherstellen, dass flutter analyze möglichst fehlerfrei ist.
