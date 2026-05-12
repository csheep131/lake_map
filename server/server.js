const http = require('http');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const { Pool } = require('pg');
const bcrypt = require('bcrypt');

const PORT = process.env.PORT || 3000;

// BUG-002 FIX: Keine hardcoded Default-Credentials
const DB_HOST = process.env.DB_HOST;
const DB_PORT = process.env.DB_PORT;
const DB_NAME = process.env.DB_NAME;
const DB_USER = process.env.DB_USER;
const DB_PASSWORD = process.env.DB_PASSWORD;

if (!DB_HOST || !DB_PORT || !DB_NAME || !DB_USER || !DB_PASSWORD) {
  console.error('FEHLER: Alle DB_* Umgebungsvariablen sind erforderlich:');
  console.error('  DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASSWORD');
  process.exit(1);
}

// Datenbank-Connection
const pool = new Pool({
  host: DB_HOST,
  port: parseInt(DB_PORT, 10),
  database: DB_NAME,
  user: DB_USER,
  password: DB_PASSWORD,
});

// BUG-001 FIX: HMAC-Secret fur Token-Signatur
const TOKEN_SECRET = process.env.TOKEN_SECRET;
if (!TOKEN_SECRET) {
  console.error('FEHLER: TOKEN_SECRET Umgebungsvariable ist erforderlich.');
  process.exit(1);
}
const TOKEN_EXPIRY_MS = 24 * 60 * 60 * 1000; // 24 Stunden

const INVALID_TOKENS = new Set();

const loginAttempts = new Map();
const MAX_LOGIN_ATTEMPTS = 5;
const LOGIN_LOCKOUT_MS = 15 * 60 * 1000;

// MIME-Typen für statische Dateien
const MIME_TYPES = {
  '.html': 'text/html',
  '.css': 'text/css',
  '.js': 'application/javascript',
  '.mjs': 'application/javascript',
  '.json': 'application/json',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.gif': 'image/gif',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
  '.apk': 'application/vnd.android.package-archive',
  '.wasm': 'application/wasm',
  '.woff2': 'font/woff2',
  '.woff': 'font/woff',
  '.ttf': 'font/ttf',
  '.otf': 'font/otf',
  '.map': 'application/json',
  '.symbols': 'text/plain',
};

// Statische Dateien servieren
function serveStatic(req, res, filePath) {
  const ext = path.extname(filePath).toLowerCase();
  const contentType = MIME_TYPES[ext] || 'application/octet-stream';

  fs.readFile(filePath, (err, data) => {
    if (err) {
      if (err.code === 'ENOENT') {
        res.writeHead(404, { 'Content-Type': 'text/plain' });
        res.end('Not found');
      } else {
        res.writeHead(500, { 'Content-Type': 'text/plain' });
        res.end('Server error');
      }
      return;
    }
    res.writeHead(200, { 'Content-Type': contentType });
    res.end(data);
  });
}

// Hilfsfunktionen
async function query(sql, params = []) {
  const client = await pool.connect();
  try {
    const res = await client.query(sql, params);
    return res.rows;
  } finally {
    client.release();
  }
}

async function verifyPassword(inputPassword, hash) {
  try {
    return await bcrypt.compare(inputPassword, hash);
  } catch {
    return false;
  }
}

// BUG-001 FIX: Token mit HMAC-Signatur
function createToken(username) {
  const timestamp = Date.now();
  const payload = `${username}:${timestamp}`;
  const signature = crypto
    .createHmac('sha256', TOKEN_SECRET)
    .update(payload)
    .digest('hex');
  const tokenData = JSON.stringify({ username, timestamp, signature });
  return Buffer.from(tokenData).toString('base64url');
}

function parseToken(token) {
  try {
    const decoded = Buffer.from(token, 'base64url').toString('utf8');
    const { username, timestamp, signature } = JSON.parse(decoded);

    // Signatur verifizieren
    const payload = `${username}:${timestamp}`;
    const expectedSignature = crypto
      .createHmac('sha256', TOKEN_SECRET)
      .update(payload)
      .digest('hex');

    if (signature !== expectedSignature) {
      return null; // Manipulierter Token
    }

    // Token-Alter prufen
    const age = Date.now() - timestamp;
    if (age > TOKEN_EXPIRY_MS) return null;

    return username;
  } catch {
    return null;
  }
}

// API Request-Handler
async function handleApiRequest(req, res) {
  const url = new URL(req.url, `http://localhost:${PORT}`);
  const pathParts = url.pathname.split('/').filter(Boolean);

  const allowedOrigins = (process.env.ALLOWED_ORIGINS || 'http://localhost:3000,http://localhost:8080').split(',');
  const origin = req.headers.origin;
  if (origin && allowedOrigins.includes(origin)) {
    res.setHeader('Access-Control-Allow-Origin', origin);
  }
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  if (req.method === 'OPTIONS') {
    res.writeHead(204);
    res.end();
    return;
  }

  // Health-Check (immer an der Wurzel oder nach Prefix erlaubt)
  if (pathParts.includes('health')) {
    try {
      await pool.query('SELECT 1');
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ status: 'ok' }));
    } catch (e) {
      res.writeHead(503, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ status: 'error' }));
    }
    return;
  }

  // Database-Prefix Handling
  // Erwartet: /data oder /lakedb/name/data oder /name/data
  let apiCommand = pathParts[0];
  if (apiCommand === 'lakedb' && pathParts.length > 2) {
    apiCommand = pathParts[2];
    pathParts.splice(0, 2); // Entferne 'lakedb' und den Namen
  } else if (pathParts.length > 1 && !['login', 'logout', 'data', 'depths', 'health', 'admin'].includes(pathParts[0])) {
    apiCommand = pathParts[1];
    pathParts.splice(0, 1); // Entferne den Namen
  }

  // Login
  if (apiCommand === 'login' && req.method === 'POST') {
    let body = '';
    for await (const chunk of req) { body += chunk; }
    const { username, password } = JSON.parse(body);

    const now = Date.now();
    const attempts = loginAttempts.get(username) || { count: 0, lockedUntil: 0 };
    if (attempts.lockedUntil > now) {
      res.writeHead(429, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ error: 'Zu viele Versuche. Bitte warte 15 Minuten.' }));
      return;
    }

    try {
      const users = await query(
        'SELECT id, username, password_hash, is_admin FROM users WHERE username = $1',
        [username]
      );

      if (users.length === 0 || !(await verifyPassword(password, users[0].password_hash))) {
        attempts.count++;
        if (attempts.count >= MAX_LOGIN_ATTEMPTS) {
          attempts.lockedUntil = now + LOGIN_LOCKOUT_MS;
        }
        loginAttempts.set(username, attempts);
        res.writeHead(401, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ error: 'Invalid credentials' }));
        return;
      }

      loginAttempts.delete(username);
      const token = createToken(username);
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({
        token,
        username: users[0].username,
        is_admin: users[0].is_admin
      }));
    } catch (e) {
      res.writeHead(500, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ error: e.message }));
    }
    return;
  }

  // Auth erforderlich
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    res.writeHead(401, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ error: 'Authorization required' }));
    return;
  }

  const token = authHeader.substring(7);
  const username = parseToken(token);

  if (!username) {
    res.writeHead(401, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ error: 'Invalid or expired token' }));
    return;
  }

  if (INVALID_TOKENS.has(token)) {
    res.writeHead(401, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ error: 'Token revoked' }));
    return;
  }

  const users = await query('SELECT id, is_admin FROM users WHERE username = $1', [username]);
  if (users.length === 0) {
    res.writeHead(401, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ error: 'User not found' }));
    return;
  }

  const user = users[0];
  const userId = user.id;
  const isAdmin = user.is_admin;

  try {
    if (apiCommand === 'logout' && req.method === 'POST') {
      INVALID_TOKENS.add(token);
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ status: 'logged out' }));
      return;
    }

    if (apiCommand === 'data' && req.method === 'GET') {
      let depths;
      if (isAdmin) {
        depths = await query(`
          SELECT d.id, d.depth_m, d.longitude, d.latitude, d.accuracy_m, d.note, d.created_at, d.point_number,
                 l.id as lake_id, l.name as lake_name
          FROM lake_depths d
          JOIN lakes l ON d.lake_id = l.id
          ORDER BY d.created_at DESC
        `);
      } else {
        depths = await query(`
          SELECT d.id, d.depth_m, d.longitude, d.latitude, d.accuracy_m, d.note, d.created_at, d.point_number,
                 l.id as lake_id, l.name as lake_name
          FROM lake_depths d
          JOIN lakes l ON d.lake_id = l.id
          WHERE d.user_id = $1
          ORDER BY d.created_at DESC
        `, [userId]);
      }

      const lakes = await query('SELECT id, name, lat_min, lat_max, lon_min, lon_max FROM lakes');

      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ lakes, depths, user: username, is_admin: isAdmin }));
      return;
    }

    if (apiCommand === 'depths' && req.method === 'POST') {
      let body = '';
      for await (const chunk of req) { body += chunk; }
      const input = JSON.parse(body);

      const depth_m = parseFloat(input.depth_m);
      const latitude = parseFloat(input.latitude);
      const longitude = parseFloat(input.longitude);
      const lake_id = parseInt(input.lake_id);

      if (isNaN(depth_m) || depth_m < 0 || depth_m > 200) {
        res.writeHead(400, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ error: 'depth_m muss zwischen 0 und 200 liegen' }));
        return;
      }
      if (isNaN(latitude) || latitude < -90 || latitude > 90) {
        res.writeHead(400, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ error: 'latitude muss zwischen -90 und 90 liegen' }));
        return;
      }
      if (isNaN(longitude) || longitude < -180 || longitude > 180) {
        res.writeHead(400, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ error: 'longitude muss zwischen -180 und 180 liegen' }));
        return;
      }
      if (isNaN(lake_id) || lake_id < 1) {
        res.writeHead(400, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ error: 'lake_id muss eine positive Zahl sein' }));
        return;
      }

      const result = await query(`
        INSERT INTO lake_depths (lake_id, depth_m, latitude, longitude, accuracy_m, note, user_id)
        VALUES ($1, $2, $3, $4, $5, $6, $7)
        RETURNING id
      `, [lake_id, depth_m, latitude, longitude, input.accuracy_m, input.note, userId]);

      res.writeHead(201, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ id: result[0].id, status: 'created' }));
      return;
    }

    if (apiCommand === 'depths' && pathParts[1] && req.method === 'DELETE') {
      const deleteId = parseInt(pathParts[1]);
      if (isNaN(deleteId)) {
        res.writeHead(400, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ error: 'Ungultige ID' }));
        return;
      }
      const existing = await query('SELECT user_id FROM lake_depths WHERE id = $1', [deleteId]);
      if (existing.length === 0) {
        res.writeHead(404, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ error: 'Punkt nicht gefunden' }));
        return;
      }
      if (existing[0].user_id !== userId && !isAdmin) {
        res.writeHead(403, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ error: 'Keine Berechtigung' }));
        return;
      }
      await query('DELETE FROM lake_depths WHERE id = $1', [deleteId]);
      res.writeHead(204);
      res.end();
      return;
    }

    // === ADMIN ENDPOINTS ===
    if (apiCommand === 'admin' && pathParts[1] === 'users' && req.method === 'GET') {
      if (!isAdmin) {
        res.writeHead(403, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ error: 'Admin erforderlich' }));
        return;
      }
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

    if (apiCommand === 'admin' && pathParts[1] === 'users' && pathParts[3] === 'depths' && req.method === 'GET') {
      if (!isAdmin) {
        res.writeHead(403, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ error: 'Admin erforderlich' }));
        return;
      }
      const targetUserId = parseInt(pathParts[2]);
      if (isNaN(targetUserId)) {
        res.writeHead(400, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ error: 'Ungultige User-ID' }));
        return;
      }
      const depths = await query(`
        SELECT d.*, l.name as lake_name
        FROM lake_depths d
        JOIN lakes l ON d.lake_id = l.id
        WHERE d.user_id = $1
        ORDER BY d.created_at DESC
      `, [targetUserId]);
      const userInfo = await query('SELECT id, username FROM users WHERE id = $1', [targetUserId]);
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({
        user: userInfo[0] || null,
        user_id: targetUserId,
        depth_count: depths.length,
        depths
      }));
      return;
    }

    if (apiCommand === 'admin' && pathParts[1] === 'users' && pathParts[3] === 'depths' && req.method === 'DELETE') {
      if (!isAdmin) {
        res.writeHead(403, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ error: 'Admin erforderlich' }));
        return;
      }
      const targetUserId = parseInt(pathParts[2]);
      if (isNaN(targetUserId)) {
        res.writeHead(400, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ error: 'Ungultige User-ID' }));
        return;
      }
      const result = await pool.query('DELETE FROM lake_depths WHERE user_id = $1', [targetUserId]);
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ deleted: result.rowCount, user_id: targetUserId }));
      return;
    }

    res.writeHead(404, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ error: 'Not found' }));
  } catch (e) {
    console.error(e);
    res.writeHead(500, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ error: e.message }));
  }
}

const server = http.createServer(async (req, res) => {
  const url = new URL(req.url, `http://localhost:${PORT}`);
  const pathname = url.pathname;
  const pathParts = pathname.split('/').filter(Boolean);

  console.log(`[${new Date().toISOString()}] ${req.method} ${pathname}`);

  const API_KEYWORDS = ['health', 'login', 'logout', 'data', 'depths', 'admin'];
  const isApiRoute = pathParts.some(p => API_KEYWORDS.includes(p));

  if (isApiRoute) {
    await handleApiRequest(req, res);
    return;
  }

  if (pathname === '/') {
    const landingPath = path.join(__dirname, 'public', 'index.html');
    return serveStatic(req, res, landingPath);
  }

  if (pathname.startsWith('/web')) {
    let filePath = path.join(__dirname, 'public', pathname);
    fs.access(filePath, fs.constants.F_OK, (err) => {
      if (err || pathname === '/web' || pathname === '/web/') {
        const flutterIndex = path.join(__dirname, 'public', 'web', 'index.html');
        return serveStatic(req, res, flutterIndex);
      }
      serveStatic(req, res, filePath);
    });
    return;
  }

  const filePath = path.join(__dirname, 'public', pathname);
  const ext = path.extname(filePath).toLowerCase();
  const contentType = {
    '.html': 'text/html',
    '.css': 'text/css',
    '.js': 'application/javascript',
    '.json': 'application/json',
    '.png': 'image/png',
    '.svg': 'image/svg+xml',
  }[ext] || 'application/octet-stream';

  fs.readFile(filePath, (err, data) => {
    if (err) {
      const indexPath = path.join(__dirname, 'public', 'index.html');
      fs.readFile(indexPath, (err2, data2) => {
        res.writeHead(200, { 'Content-Type': 'text/html' });
        res.end(data2 || 'Not found');
      });
      return;
    }
    res.writeHead(200, { 'Content-Type': contentType });
    res.end(data);
  });
});

server.listen(PORT, () => {
  console.log(`Wammsee Server lauft auf Port ${PORT}`);
});


