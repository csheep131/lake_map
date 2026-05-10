# Lake Mapper Roadmap

## ✅ Fertig

### Implementierte Features

- [x] Flutter-Projekt mit flutter_map, geolocator, sqflite
- [x] SQLite-Datenbank (lakes, depth_points)
- [x] GPS-Tracking mit Genauigkeitsanzeige
- [x] GPS-Warnung bei schlechter Genauigkeit (>10m)
- [x] Tiefenmessung speichern mit Notiz
- [x] Automatische Punktnummer
- [x] Letzten Punkt duplizieren
- [x] Karte mit farbcodierten Markern
- [x] Punkt bearbeiten / löschen (MapScreen & HomeScreen)
- [x] Tiefenfarben-Legende
- [x] Export CSV und GeoJSON
- [x] Remote-Sync mit arxlabs.dev/lakedb/{datenbankname}
- [x] Offline/Online-Modus
- [x] Settings für Datenbanknamen
- [x] **Premium Nautical UI** (Glassmorphism, Cyan-Glow)
- [x] **Bathymetrie-/Sonaransicht (Abyss-Modus)**
- [x] **Custom BottomNavigationBar mit aktivem Cyan-Glow**
- [x] **Testdaten-Seeding (2 Punkte beim ersten Start)**
- [x] **Single-Lake: nur Wammsee** (Multi-See entfernt)

### Offline-Nutzung

Die App funktioniert **komplett offline**:
- GPS-Empfang auch ohne Internet
- Lokale SQLite-Datenbank
- Lokale Kartencaches (OSM)
- Export auf Gerät speichern
- Keine Cloud-Sync nötig für lokale Nutzung

### Phase 1: Projekt-Grundlage

- Flutter-App mit flutter_map, geolocator, sqflite
- Projektstruktur: models, database, services, screens, theme

### Phase 2: Datenbank lokal

- SQLite-Tabellen: lakes, depth_points
- Automatische Erstellung beim Start
- Testdaten-Seeding: 2 Punkte bei leerer DB

### Phase 3: GPS + Tiefeneingabe

- Aktuelle GPS-Position anzeigen
- Tiefe eingeben und speichern
- Validierung: Tiefe > 0
- Polygon-Check: nur innerhalb Wammsee speicherbar

### Phase 4: Karte anzeigen

- OpenStreetMap-Karte mit flutter_map
- Marker nach Tiefe eingefärbt
- Marker-Info zeigt Tiefe + Zeit
- Bathymetrie-Ansicht (Abyss-Modus) mit Sonar-Grid

### Phase 5: See-Modus (Wammsee)

- Startzentrum Wammsee (49.346970, 8.446897)
- Wammsee-Polygon als Umriss (Convex Hull, 29 Punkte)
- Nur Wammsee — kein See-Anlegen mehr nötig

### Phase 6: Export

- CSV-Export
- GeoJSON-Export
- Lokal speichern

### Phase 7: Cloud-Sync (ARX Labs)

- Sync mit arxlabs.dev/lakedb/{datenbankname}
- Offline/Online-Modus
- Bidirektionale Synchronisation
- Auth mit Demo-Login (wammsee / angelverein123)

### Phase 8: Premium UI

- Navy-zu-Schwarz-Verlauf im AppBar
- Glassmorphism-IconButtons mit Cyan-Glow
- Glassmorphism-Floating-Action-Panel
- Custom BottomNavigationBar (Cyan-Glow aktiv, Steel-Blue inaktiv)
- Bathymetrische Farbskala

### Geplante Komfortfunktionen

- [x] Punkt löschen / bearbeiten
- [x] Automatische Punktnummer
- [x] GPS-Genauigkeit-Warnung
- [x] Letzten Punkt duplizieren
- [x] Tiefenfarben-Legende
- [x] Bathymetrie-/Sonaransicht
- [ ] Offline-Karten (Tile-Caching)
- [ ] See-Grenzen als echtes GeoJSON
