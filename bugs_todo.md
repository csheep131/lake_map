# Bug Tracker: Lake Mapper Server & App

Generated: 2026-05-12

---

## KRITISCHE BUGS

### BUG-001: Server Token ohne kryptografische Signatur
**Datei**: `server/server.js`
**Zeile**: 39-67
**Beschreibung**: Token ist trivially fälschbar (keine HMAC-Signatur).
**Fix**: Token wird jetzt mit HMAC-SHA256 signiert und bei jeder Anfrage verifiziert.
```javascript
function createToken(username) {
  const timestamp = Date.now();
  const payload = `${username}:${timestamp}`;
  const signature = crypto.createHmac('sha256', TOKEN_SECRET)
    .update(payload).digest('hex');
  const tokenData = JSON.stringify({ username, timestamp, signature });
  return Buffer.from(tokenData).toString('base64url');
}
```
**Risiko**: Vollständige Authentifizierungsumgehung. Jeder kann sich als beliebiger User ausgeben.
**Status**: Fixed (2026-05-12)

---

### BUG-002: Hardcoded Default-DB-Credentials
**Datei**: `server/server.js`
**Zeile**: 7-29
**Beschreibung**: Default-Passwort im Code.
**Fix**: Alle DB-Umgebungsvariablen sind jetzt obligatorisch (Server startet nicht ohne sie).
```javascript
const DB_HOST = process.env.DB_HOST;
const DB_PORT = process.env.DB_PORT;
// ...
if (!DB_HOST || !DB_PORT || !DB_NAME || !DB_USER || !DB_PASSWORD) {
  console.error('FEHLER: Alle DB_* Umgebungsvariablen sind erforderlich:');
  process.exit(1);
}
```
**Risiko**: Passwort-Hashing schützt nur gegen direkte DB-Zugriffe, nicht gegen triviale Token-Manipulation (BUG-001).
**Status**: Fixed (2026-05-12)

---

### BUG-003: Race Condition beim Punkt-Duplizieren
**Datei**: `lake_mapper_app/lib/screens/home_screen.dart`
**Zeile**: 269-279
**Beschreibung**: `_lastPointNumber` kann null sein (keine Punkte vorhanden), dann wirft `firstWhere` eine Exception.
**Fix**: Sichere Iteration mit null-Prüfung und Fehlermeldung.
```dart
Future<void> _duplicateLastPoint() async {
  if (_lastPointNumber == null || _currentLat == null || _currentLon == null) return;
  DepthPoint? lastPoint;
  for (final p in _recentPoints) {
    if (p.pointNumber == _lastPointNumber) { lastPoint = p; break; }
  }
  if (lastPoint == null) { _showError('Letzter Punkt nicht gefunden'); return; }
```
**Risiko**: App-Absturz bei leeren Recent Points.
**Status**: Fixed (2026-05-12)

---

### BUG-004: pointNumber ohne Transaction-Schutz
**Datei**: `lake_mapper_app/lib/database/app_database.dart`
**Zeile**: 146-172
**Beschreibung**: `getNextPointNumber()` und `insert()` sind nicht in einer Transaction.
**Fix**: Operationen werden jetzt in einer DB-Transaction ausgeführt.
```dart
Future<int> insertDepthPoint(DepthPoint point) async {
  return await customTransaction((tx) async {
    final pointNumber = point.pointNumber ?? await getNextPointNumberInTx(tx, point.lakeId);
    return await tx.into(depthPointsTable).insert(...);
  });
}
```
**Risiko**: Bei gleichzeitigen Saves konnen doppelte `pointNumber` entstehen.
**Status**: Fixed (2026-05-12)

---

## HOHE PRIORITAT

### BUG-005: Keine Input-Validierung bei `depths` POST
**Datei**: `server/server.js`
**Zeile**: 284-320
**Beschreibung**: Keine Validierung von Koordinatenbereichen, negativen Tiefen.
**Fix**: Validierung von depth_m (0-200), latitude (-90 bis 90), longitude (-180 bis 180), lake_id.
**Risiko**: Ungultige Daten in der Datenbank.
**Status**: Fixed (2026-05-12)

---

### BUG-006: CORS erlaubt alle Origins
**Datei**: `server/server.js`
**Zeile**: 148-153
**Beschreibung**: Jede Website kann API-Anfragen im Browser des Users senden.
**Fix**: Origins werden via `ALLOWED_ORIGINS` ENV-Variable konfiguriert.
```javascript
const allowedOrigins = (process.env.ALLOWED_ORIGINS || 'http://localhost:3000').split(',');
```
**Risiko**: CSRF-Angriffe moglich.
**Status**: Fixed (2026-05-12)

---

### BUG-007: `fromServerMap` ignoriert Server-Timestamp
**Datei**: `lake_mapper_app/lib/models/depth_point.dart`
**Zeile**: 56-68
**Beschreibung**: Server liefert `measured_at`, aber `fromServerMap` gibt `DateTime.now()` zuruck wenn das Feld fehlt.
**Fix**: Unterstutzt jetzt beide Felder (`measured_at` und `created_at`) und mapped `point_number`.
**Risiko**: Originaler Messzeitpunkt geht verloren.
**Status**: Fixed (2026-05-12)

---

### BUG-008: Keine Offline-Queue fur Sync
**Datei**: `lake_mapper_app/lib/services/sync_service.dart`
**Zeile**: 97-165
**Beschreibung**: Wenn Sync fehlschlagt, gehen lokale Punkte verloren. Keine Retry-Queue.
**Fix**: Pending-Punkte werden in SharedPreferences gespeichert und bei jedem Sync automatisch retryt.
```dart
Future<void> _addPendingPoint(DepthPoint point) async { ... }
Future<void> _removePendingPoint(int pointId) async { ... }
```
**Risiko**: Datenverlust bei Netzwerkfehlern wahrend Sync.
**Status**: Fixed (2026-05-12)

---

### BUG-009: DELETE ohne explizite Ownership-Prufung
**Datei**: `server/server.js`
**Zeile**: 322-343
**Beschreibung**: Non-Admin kann eigene Punkte loschen ohne explizite Berechtigungsprufung.
**Fix**: Prueft ob der User der Owner des Punktes ist, bevor geloescht wird.
```javascript
if (existing[0].user_id !== userId && !isAdmin) {
  res.writeHead(403, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify({ error: 'Keine Berechtigung' }));
  return;
}
```
**Risiko**: Falsche Benutzer konnen Punkte loschen.
**Status**: Fixed (2026-05-12)

---

## MEDIUM PRIORITAT

### BUG-010: `_wammseeCenter` doppelt definiert
**Datei**: `lake_mapper_app/lib/screens/map_screen.dart` vs `lake_mapper_app/lib/config/map_config.dart`
**Zeile**: 50 vs 19
**Beschreibung**: Inkonsistente Koordinaten.
**Fix**: Unbenutzte `_wammseeCenter` Variable entfernt, MapConfig.initialCenter wird verwendet.
**Risiko**: UI-Flicker beim Screen-Wechsel.
**Status**: Fixed (2026-05-12)

---

### BUG-011: Doppelter Request-Handler im Server
**Datei**: `server/server.js`
**Zeile**: 363-449
**Beschreibung**: Zwei verschiedene `handleRequest` Implementierungen.
**Fix**: Handler konsolidiert, redundanter Code entfernt.
**Risiko**: Widerspruchliches Routing, potenzielle Fehler.
**Status**: Fixed (2026-05-12)

---

### BUG-012: `_duplicateLastPoint` nutzt falsches Lookup
**Datei**: `lake_mapper_app/lib/screens/home_screen.dart`
**Zeile**: 269-285
**Beschreibung**: Sucht nach `pointNumber` statt direktem Zugriff.
**Fix**: Neue Methode `getLastDepthPoint()` in DB, direkte Abfrage statt limitierter Liste.
```dart
Future<DepthPoint?> getLastDepthPoint(int lakeId) async { ... }
```
**Risiko**: Falscher Punkt wird dupliziert oder Exception.
**Status**: Fixed (2026-05-12)

---

### BUG-013: Zwei verschiedene Landing Pages
**Datei**: `server/public/index_landing.html` vs `server/public/index_new.html`
**Beschreibung**: Unklar welche ausgeliefert wird.
**Fix**: Landing Pages konsolidiert - nur noch index.html existiert.
**Risiko**: Inkonsistentes Verhalten.
**Status**: Fixed (2026-05-12)

---

### BUG-014: Inkompatibles API-Response-Mapping
**Datei**: Server (`server.js:260-285`) vs Flutter (`depth_point.dart:56-68`)
**Beschreibung**: Server liefert `measured_at`, Client `fromMap` liest `created_at`.
**Fix**: Server liefert jetzt `created_at`, `point_number`, `lake_id`. Client liest `created_at` primar.
**Risiko**: Inkonsistente Daten между Server und Client.
**Status**: Fixed (2026-05-12)

---

## NIEDERIGE PRIORITAT

### BUG-015: Kein Rate-Limiting
**Datei**: `server/server.js`
**Zeile**: 18-20, 191-222
**Beschreibung**: Brute-Force Login moglich ohne Captcha oder IP-Limit.
**Fix**: Rate-Limiting mit 5 Versuchen und 15 Minuten Lockout.
```javascript
const loginAttempts = new Map();
const MAX_LOGIN_ATTEMPTS = 5;
const LOGIN_LOCKOUT_MS = 15 * 60 * 1000;
```
**Risiko**: Login-Brute-Force-Angriffe.
**Status**: Fixed (2026-05-12)

---

### BUG-016: `isPointInPolygon` Division by Zero
**Datei**: `lake_mapper_app/lib/screens/map_screen.dart`
**Zeile**: 155-166
**Beschreibung**: Bei identischen y-Koordinaten (`yj == yi`) Division durch Null.
**Fix**: Horizontale Kanten werden ubersprungen.
```dart
if (yi == yj) continue;
```
**Risiko**: Unerwartetes Verhalten bei bestimmten Polygon-Konfigurationen.
**Status**: Fixed (2026-05-12)

---

### BUG-017: Memory Leak — Listener nicht entfernt
**Datei**: `lake_mapper_app/lib/screens/map_screen.dart`
**Zeile**: 1428-1432
**Beschreibung**: `_onRefresh` Listener werden potentiell nicht aufgeraumt.
**Fix**: dispose() Methode hinzugefugt mit Timer und WebGPS Cleanup.
```dart
@override
void dispose() {
  _gpsLockTimer?.cancel();
  _webGpsService?.stop();
  super.dispose();
}
```
**Risiko**: Memory Leak bei langen App-Sessions.
**Status**: Fixed (2026-05-12)

---

## ZUSAMMENFASSUNG

| Prioritat | Anzahl | Fixed |
|-----------|--------|-------|
| Kritisch | 4 | 4 |
| Hoch | 5 | 5 |
| Mittel | 5 | 5 |
| Niedrig | 3 | 3 |
| **Total** | **17** | **17** | |

---

## CHANGELOG

### 2026-05-12
- **BUG-001**: Token jetzt mit HMAC-SHA256 signiert (TOKEN_SECRET erforderlich)
- **BUG-002**: DB-Umgebungsvariablen sind jetzt obligatorisch
- **BUG-003**: Punkt-Duplizieren mit sicherem Fallback
- **BUG-004**: insertDepthPoint in Transaction gewrappt
- **BUG-005**: Input-Validierung fur depth_m, latitude, longitude, lake_id
- **BUG-006**: CORS via ALLOWED_ORIGINS ENV-Variable konfigurierbar
- **BUG-007**: fromServerMap unterstutzt beide Timestamp-Felder
- **BUG-008**: Offline-Queue speichert fehlgeschlagene Syncs in SharedPreferences
- **BUG-009**: DELETE pruft Ownership bevor geloescht wird
- **BUG-010**: Doppelte _wammseeCenter Variable entfernt
- **BUG-011**: Doppelter Request-Handler im Server konsolidiert
- **BUG-012**: _duplicateLastPoint nutzt jetzt direkte DB-Abfrage
- **BUG-013**: Landing Pages konsolidiert (nur index.html)
- **BUG-014**: Server-API gibt jetzt konsistente Felder zuruck
- **BUG-015**: Rate-Limiting mit 5 Versuchen und 15 Minuten Lockout
- **BUG-016**: Division by Zero in isPointInPolygon behoben
- **BUG-017**: dispose() in MapScreen mit Timer/GPS Cleanup
