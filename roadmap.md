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
- [x] Punkt bearbeiten/löschen
- [x] Tiefenfarben-Legende
- [x] Export CSV und GeoJSON
- [x] Remote-Sync mit arxlabs.dev/lakedb/{datenbankname}
- [x] Offline/Online-Modus
- [x] Settings für Datenbanknamen

### Offline-Nutzung

Die App funktioniert **komplett offline**:
- GPS-Empfang auch ohne Internet
- Lokale SQLite-Datenbank
- Lokale Kartencaches (OSM)
- Export auf Gerät speichern
- Keine Cloud-Sync möglich (aber nicht nötig)

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

- [x] Punkt löschen / bearbeiten
- [x] Automatische Punktnummer
- [x] GPS-Genauigkeit-Warnung
- [x] Letzten Punkt duplizieren
- [x] Tiefenfarben-Legende
- [ ] Offline-Karten (Tile-Caching)
- [ ] See-Grenzen als GeoJSON
- [ ] Eigene Seen anlegen


