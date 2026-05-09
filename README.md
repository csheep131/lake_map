# 🗺️ Lake Mapper

![Wammsee Bathymetrie-Karte](images/logo.png)

**Flutter-App für Bathymetrie-Kartierung mit Cloud-Sync**

---

## Was das ist

Mobile App zum Aufnehmen von Tiefenmessungen mit GPS-Koordinaten. Daten werden lokal gespeichert und können mit einem Server synchronisiert werden.

---

## Features

| Feature | Status |
|---------|--------|
| GPS-Tracking mit Genauigkeitsanzeige | ✅ |
| Tiefeneingabe mit Notiz | ✅ |
| Lokale SQLite-Datenbank | ✅ |
| Live-Karte (flutter_map) | ✅ |
| Farbcodierung nach Tiefe | ✅ |
| Punktnummer (automatisch) | ✅ |
| Letzten Punkt duplizieren | ✅ |
| GPS-Warnung bei Ungenauigkeit | ✅ |
| Punkt bearbeiten/löschen | ✅ |
| CSV/GeoJSON Export | ✅ |
| Cloud-Sync (arxlabs.dev) | ✅ |
| Offline/Online-Modus | ✅ |
| Legende auf Karte | ✅ |

---

## Installation

```bash
# Flutter-App
cd lake_mapper_app
flutter pub get
flutter run

# Server (optional)
cd server
npm start
```

---

## Tech-Stack

- **App**: Flutter + flutter_map + geolocator + sqflite
- **Server**: Node.js (JSON-Files)
- **Sync**: REST API an arxlabs.dev/lakedb/{datenbankname}

---

## Server installieren

```bash
cd server
PORT=3000 node server.js
```

Datenbank-Verzeichnis: `./data/{name}.json`

---

## API

| Methode | Endpoint | Beschreibung |
|---------|----------|-------------|
| GET | /health | Health-Check |
| GET | /{db}/all | Alle Daten |
| POST | /{db}/lakes | See anlegen |
| POST | /{db}/depth_points | Messpunkt anlegen |
| PUT | /{db}/depth_points/{id} | Aktualisieren |
| DELETE | /{db}/depth_points/{id} | Löschen |

---

## Projektstruktur

```
lake_map/
├── lake_mapper_app/      # Flutter-App
│   └── lib/
│       ├── main.dart
│       ├── database/     # SQLite
│       ├── models/      # Datenmodelle
│       ├── services/    # Location, Sync, Export
│       └── screens/    # UI
├── server/            # Node.js Server
│   ├── server.js
│   ├── package.json
│   └── README.md
├── roadmap.md
└── README.md
```

---

## Lizenz

MIT