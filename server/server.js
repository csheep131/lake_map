const http = require('http');
const { Pool } = require('pg');
const bcrypt = require('bcrypt');

const PORT = process.env.PORT || 3000;

// Datenbank-Connection
const pool = new Pool({
  host: process.env.DB_HOST || 'localhost',
  port: process.env.DB_PORT || 5432,
  database: process.env.DB_NAME || 'lakemap',
  user: process.env.DB_USER || 'lakeuser',
  password: process.env.DB_PASSWORD || 'lake123',
});

const INVALID_TOKENS = new Set();

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

function createToken(username) {
  const payload = `${username}:${Date.now()}`;
  return Buffer.from(payload).toString('base64');
}

function parseToken(token) {
  try {
    const decoded = Buffer.from(token, 'base64').toString('utf8');
    const [username, timestamp] = decoded.split(':');
    const age = Date.now() - parseInt(timestamp);
    if (age > 24 * 60 * 60 * 1000) return null;
    return username;
  } catch {
    return null;
  }
}

// Request-Handler
async function handleRequest(req, res) {
  const url = new URL(req.url, `http://localhost:${PORT}`);
  const pathParts = url.pathname.split('/').filter(Boolean);

  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  if (req.method === 'OPTIONS') {
    res.writeHead(204);
    res.end();
    return;
  }

  // Health-Check
  if (pathParts[0] === 'health') {
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

  // Login
  if (pathParts[0] === 'login' && req.method === 'POST') {
    let body = '';
    for await (const chunk of req) { body += chunk; }
    const { username, password } = JSON.parse(body);

    try {
      const users = await query(
        'SELECT id, username, password_hash, is_admin FROM users WHERE username = $1',
        [username]
      );

      if (users.length === 0 || !(await verifyPassword(password, users[0].password_hash))) {
        res.writeHead(401, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ error: 'Invalid credentials' }));
        return;
      }

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
    // LOGOUT
    if (pathParts[0] === 'logout' && req.method === 'POST') {
      INVALID_TOKENS.add(token);
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ status: 'logged out' }));
      return;
    }

    // DATEN
    if (pathParts[0] === 'data' && req.method === 'GET') {
      let depths;
      if (isAdmin) {
        depths = await query(`
          SELECT d.id, d.depth_m, d.longitude, d.latitude, d.accuracy_m, d.note, d.measured_at,
                 l.name as lake_name
          FROM lake_depths d
          JOIN lakes l ON d.lake_id = l.id
          ORDER BY d.measured_at DESC
        `);
      } else {
        depths = await query(`
          SELECT d.id, d.depth_m, d.longitude, d.latitude, d.accuracy_m, d.note, d.measured_at,
                 l.name as lake_name
          FROM lake_depths d
          JOIN lakes l ON d.lake_id = l.id
          WHERE d.user_id = 1
          ORDER BY d.measured_at DESC
        `);
      }

      const lakes = await query('SELECT id, name, lat_min, lat_max, lon_min, lon_max FROM lakes');

      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ lakes, depths, user: username, is_admin: isAdmin }));
      return;
    }

    // NEU
    if (pathParts[0] === 'depths' && req.method === 'POST') {
      if (isAdmin) {
        let body = '';
        for await (const chunk of req) { body += chunk; }
        const input = JSON.parse(body);

        const result = await query(`
          INSERT INTO lake_depths (lake_id, depth_m, latitude, longitude, accuracy_m, note, user_id)
          VALUES ($1, $2, $3, $4, $5, $6, $7)
          RETURNING id
        `, [input.lake_id, input.depth_m, input.latitude, input.longitude, input.accuracy_m, input.note, userId]);

        res.writeHead(201, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ id: result[0].id, status: 'created' }));
      } else {
        res.writeHead(403, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ error: 'Nur Admin darf Daten hinzufügen' }));
      }
      return;
    }

    // LÖSCHEN
    if (pathParts[0] === 'depths' && pathParts[1] && req.method === 'DELETE') {
      if (isAdmin) {
        const deleteId = parseInt(pathParts[1]);
        await query('DELETE FROM lake_depths WHERE id = $1', [deleteId]);
        res.writeHead(204);
        res.end();
      } else {
        res.writeHead(403, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ error: 'Nur Admin darf löschen' }));
      }
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

const server = http.createServer(handleRequest);

server.listen(PORT, () => {
  console.log(`Wammsee Server on port ${PORT}`);
});