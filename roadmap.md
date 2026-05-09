# Lake Mapper Roadmap

## Status: In Entwicklung

### Implementierte Features

- [x] Flutter-Projekt mit flutter_map, geolocator, sqflite
- [x] SQLite-Datenbank (lakes, depth_points)
- [x] GPS-Tracking mit Genauigkeitsanzeige
- [x] Tiefenmessung speichern mit Notiz
- [x] Karte mit Markern (farbcodiert nach Tiefe)
- [x] Export CSV und GeoJSON
- [x] Remote-Sync mit arxlabs.dev/lakedb/{datenbankname}
- [x] Offline/Online-Modus mit Sync-Status
- [x] Settings für Datenbanknamen

### Phase 1: Projekt-Grundlage

- Flutter-App mit flutter_map, geolocator, sqflite
- Projektstruktur: models, database, services, screens

### Phase 2: Datenbank lokal

- SQLite-Tabellen: lakes, depth_points
- Automatische Erstellung beim Start

### Phase 3: GPS + Tiefeneingabe

- Aktuelle GPS-Position anzeigen
- Tiefe eingeben und speichern
- Validierung: Tiefe > 0

### Phase 4: Karte anzeigen

- OpenStreetMap-Karte mit flutter_map
- Marker nach Tiefe eingefärbt
- Marker-Info zeigt Tiefe + Zeit

### Phase 5: See-Modus (Wammsee)

- Startzentrum Wammsee (49.3300, 8.4550)
- Später: eigene Seen anlegen
- Später: GeoJSON-Uferlinie

### Phase 6: Export

- CSV-Export
- GeoJSON-Export
- Lokal speichern

### Phase 7: Cloud-Sync (ARX Labs)

- Sync mit arxlabs.dev/lakedb/{datenbankname}
- Offline/Online-Modus
- Bidirektionale Synchronisation

### Geplante Komfortfunktionen

- [ ] Punkt löschen / bearbeiten
- [ ] Automatische Punktnummer
- [ ] GPS-Genauigkeit-Warnung
- [ ] Letzten Punkt duplizieren
- [ ] Tiefenfarben-Legende
- [ ] Offline-Karten (Tile-Caching)
- [ ] See-Grenzen als GeoJSON
- [ ] Eigene Seen anlegen