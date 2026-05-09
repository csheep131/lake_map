# Lake Mapper Server

Backend für die lake_mapper_app zur Synchronisation von Tiefenmessdaten.

## API Endpoints

Alle Requests an `https://arxlabs.dev/lakedb/{datenbankname}`

### Health Check

```
GET /health
```

Response:
```json
{"status": "ok"}
```

### Alle Daten abrufen

```
GET /all
```

Response:
```json
{
  "lakes": [
    {"id": 1, "name": "Wammsee", "created_at": "2026-01-01T00:00:00.000Z"}
  ],
  "depth_points": [
    {
      "id": 1,
      "lake_id": 1,
      "latitude": 49.3300,
      "longitude": 8.4550,
      "depth_m": 3.5,
      "note": "Kante",
      "created_at": "2026-05-09T14:55:00.000Z",
      "point_number": 1
    }
  ]
}
```

### See anlegen

```
POST /lakes
Content-Type: application/json

{"name": "Wammsee", "created_at": "2026-05-09T14:00:00.000Z"}
```

### Messpunkt anlegen

```
POST /depth_points
Content-Type: application/json

{
  "lake_id": 1,
  "latitude": 49.3300,
  "longitude": 8.4550,
  "depth_m": 3.5,
  "note": "Kante",
  "created_at": "2026-05-09T14:55:00.000Z",
  "point_number": 1
}
```

### Messpunkt aktualisieren

```
PUT /depth_points/{id}
Content-Type: application/json

{
  "latitude": 49.3300,
  "longitude": 8.4550,
  "depth_m": 4.0,
  "note": "Updated note"
}
```

### Messpunkt löschen

```
DELETE /depth_points/{id}
```

## Datenbank-Schema

### lakes

| Spalte | Typ | Beschreibung |
|-------|-----|-------------|
| id | INTEGER | Primärschlüssel |
| name | TEXT | Name des Sees |
| created_at | TEXT | ISO 8601 Timestamp |

### depth_points

| Spalte | Typ | Beschreibung |
|-------|-----|-------------|
| id | INTEGER | Primärschlüssel |
| lake_id | INTEGER | Fremdschlüssel zu lakes |
| latitude | REAL | Breitengrad |
| longitude | REAL | Längengrad |
| depth_m | REAL | Tiefe in Metern |
| note | TEXT | Optionale Notiz |
| created_at | TEXT | ISO 8601 Timestamp |
| point_number | INTEGER | Fortlaufende Nummer |

## Sync-Logik

1. Client sendet alle lokalen Punkte zum Server
2. Server vergleicht Timestamps
3. Bei neuen Punkten: Server speichert
4. Bei älteren Punkten auf Server: Client aktualisiert
5. Last-Sync-Zeit wird aktualisiert

## Installation (Docker)

```dockerfile
FROM node:20-alpine

WORKDIR /app
COPY package*.json ./
RUN npm install

COPY . .
EXPOSE 3000

CMD ["node", "server.js"]
```

## Umgebungsvariablen

| Variable | Standard | Beschreibung |
|----------|----------|--------------|
| PORT | 3000 | Server-Port |
| DB_PATH | ./data | SQLite-Datenbankverzeichnis |

## Sicherheit

- Keine Authentifizierung (offenes Projekt)
- CORS für alle Origins erlaubt
- Keine sensiblen Daten gespeichert

## Offene TODOs

- [ ] SQLite statt JSON-Files
- [ ] CORS einschränken
- [ ] Basis-Auth optional
- [ ] Web-UI zur Datenanzeige
- [ ] Export-Funktionen im Web