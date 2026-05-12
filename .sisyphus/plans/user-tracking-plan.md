# Plan: User-Tracking in Datenbank

## Ziel
Speichern welcher User jeden Tiefenmessungs-Eintrag erstellt hat. Ermöglicht in Zukunft:
- Einträge nach User filtern
- Einträge nach User löschen (falls jemand "Mist baut")

## Status Quo

### Bereits vorhanden
- `lake_depths` Tabelle hat `user_id` Spalte
- Auth-System mit Tokens existiert
- Server speichert bereits `user_id` aus Token beim Erstellen
- `/data` Endpoint filtert bereits nach `user_id` für Non-Admin

### Fehlt noch
1. Flutter App sendet keinen `user_id` beim Sync (nicht nötig - Server nimmt aus Token)
2. Admin-Endpoint: Alle Einträge eines Users sehen
3. Admin-Endpoint: Alle Einträge eines Users löschen

---

## Phase 1: Server API Erweiterung

### 1.1 Neuer Endpoint: Admin - Eintraege nach User abrufen
```
GET /admin/users/{userId}/depths
Authorization: Bearer <admin_token>

Response:
{
  "user_id": 1,
  "username": "user1",
  "depth_count": 42,
  "depths": [...]
}
```

### 1.2 Neuer Endpoint: Admin - Alle Eintraege eines Users loeschen
```
DELETE /admin/users/{userId}/depths
Authorization: Bearer <admin_token>

Response:
{ "deleted": 42, "user_id": 1 }
```

### 1.3 Optional: User-Statistik Endpoint
```
GET /admin/users
Authorization: Bearer <admin_token>

Response:
{
  "users": [
    { "id": 1, "username": "user1", "depth_count": 42, "last_activity": "..." },
    { "id": 2, "username": "user2", "depth_count": 15, "last_activity": "..." }
  ]
}
```

---

## Phase 2: Server Implementation

### 2.1 Datei: server/server.js

#### Routing erweitern (~Zeile 175)
```javascript
const API_KEYWORDS = ['health', 'login', 'logout', 'data', 'depths', 'admin'];
```

#### Admin Middleware hinzufuegen (~nach parseToken)
```javascript
if (!isAdmin) {
  res.writeHead(403, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify({ error: 'Admin erforderlich' }));
  return;
}
```

#### Neuer Endpoint: GET /admin/users
```javascript
if (apiCommand === 'admin' && pathParts[1] === 'users' && req.method === 'GET') {
  const users = await query(`
    SELECT u.id, u.username, COUNT(d.id) as depth_count, MAX(d.created_at) as last_activity
    FROM users u
    LEFT JOIN lake_depths d ON u.id = d.user_id
    GROUP BY u.id, u.username
    ORDER BY depth_count DESC
  `);
  res.writeHead(200, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify({ users }));
  return;
}
```

#### Neuer Endpoint: GET /admin/users/{id}/depths
```javascript
if (apiCommand === 'admin' && pathParts[1] === 'users' && pathParts[3] === 'depths' && req.method === 'GET') {
  const targetUserId = parseInt(pathParts[2]);
  const depths = await query(`
    SELECT d.*, l.name as lake_name
    FROM lake_depths d
    JOIN lakes l ON d.lake_id = l.id
    WHERE d.user_id = $1
    ORDER BY d.created_at DESC
  `, [targetUserId]);
  res.writeHead(200, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify({ user_id: targetUserId, depths }));
  return;
}
```

#### Neuer Endpoint: DELETE /admin/users/{id}/depths
```javascript
if (apiCommand === 'admin' && pathParts[1] === 'users' && pathParts[3] === 'depths' && req.method === 'DELETE') {
  const targetUserId = parseInt(pathParts[2]);
  const result = await query('DELETE FROM lake_depths WHERE user_id = $1', [targetUserId]);
  res.writeHead(200, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify({ deleted: result.rowCount, user_id: targetUserId }));
  return;
}
```

---

## Phase 3: Flutter App (optional - nur wenn Admin-UI gewuenscht)

### 3.1 Admin-Screen erstellen
- Datei: `lib/screens/admin_screen.dart`
- Zeigt Liste aller User mit Statistiken
- Button zum Loeschen aller Eintraege eines Users

### 3.2 Admin API Service
```dart
class AdminService {
  Future<List<UserStats>> getUserStats() async { ... }
  Future<int> deleteUserDepths(int userId) async { ... }
  Future<List<DepthPoint>> getUserDepths(int userId) async { ... }
}
```

---

## Risiken und Mitigations

| Risiko | Mitigation |
|--------|------------|
| Admin-Token gestohlen | TOKEN_SECRET schützt Tokens |
| Versehentliches Loeschen | Nur einzelne User löschbar, nicht alle auf einmal |
| Performance bei vielen Usern | Pagination für User-Liste |

---

## Test-Checkliste

- [ ] GET /admin/users gibt alle User mit Statistiken zurück
- [ ] GET /admin/users/{id}/depths gibt nur Einträge dieses Users
- [ ] DELETE /admin/users/{id}/depths löscht nur Einträge dieses Users
- [ ] Non-Admin bekommt 403 bei Admin-Endpoints
- [ ] Sync funktioniert weiterhin ohne Aenderungen

---

## Zeitabschaetzung

| Phase | Aufwand |
|-------|---------|
| Server API Erweiterung | 1-2 Stunden |
| Flutter Admin-Screen | 2-3 Stunden |
| Tests | 1 Stunde |
| **Total** | **4-6 Stunden** |

---

## Naechste Schritte

1. **Sofort umsetzen**: Server API Endpoints (Phase 1-2)
2. **Später**: Flutter Admin-Screen wenn gewünscht
3. **Optional**: User-Management (User sperren, löschen)
