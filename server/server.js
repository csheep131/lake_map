const http = require('http');
const fs = require('fs');
const path = require('path');
const { promisify } = require('util');

const PORT = process.env.PORT || 3000;
const DB_PATH = process.env.DB_PATH || './data';

const readFile = promisify(fs.readFile);
const writeFile = promisify(fs.writeFile);
const readdir = promisify(fs.readdir);
const mkdir = promisify(fs.mkdir);
const stat = promisify(fs.stat);

const INITIAL_DATA = {
  lakes: [
    { id: 1, name: 'Wammsee', created_at: new Date().toISOString() }
  ],
  depth_points: []
};

function getDbPath(name) {
  return path.join(DB_PATH, `${name}.json`);
}

async function loadDb(name) {
  const dbPath = getDbPath(name);
  try {
    await stat(dbPath);
    const data = await readFile(dbPath, 'utf8');
    return JSON.parse(data);
  } catch (e) {
    return INITIAL_DATA;
  }
}

async function saveDb(name, data) {
  const dbPath = getDbPath(name);
  try {
    await stat(DB_PATH);
  } catch (e) {
    await mkdir(DB_PATH, { recursive: true });
  }
  await writeFile(dbPath, JSON.stringify(data, null, 2));
}

async function handleRequest(req, res) {
  const url = new URL(req.url, `http://localhost:${PORT}`);
  const pathParts = url.pathname.split('/').filter(Boolean);
  
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  
  if (req.method === 'OPTIONS') {
    res.writeHead(204);
    res.end();
    return;
  }
  
  if (pathParts[0] === 'health') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ status: 'ok' }));
    return;
  }
  
  if (pathParts.length < 1) {
    res.writeHead(404);
    res.end('Not found');
    return;
  }
  
  const dbName = pathParts[0];
  const endpoint = pathParts[1];
  const id = pathParts[2];
  
  try {
    const data = await loadDb(dbName);
    
    if (req.method === 'GET' && !endpoint) {
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify(data));
      return;
    }
    
    if (req.method === 'GET' && endpoint === 'all') {
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify(data));
      return;
    }
    
    let body = '';
    for await (const chunk of req) {
      body += chunk;
    }
    
    if (req.method === 'POST' && endpoint === 'lakes') {
      const input = JSON.parse(body);
      const newId = (Math.max(...data.lakes.map(l => l.id), 0)) + 1;
      const lake = {
        id: newId,
        name: input.name,
        created_at: input.created_at || new Date().toISOString()
      };
      data.lakes.push(lake);
      await saveDb(dbName, data);
      res.writeHead(201, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify(lake));
      return;
    }
    
    if (req.method === 'POST' && endpoint === 'depth_points') {
      const input = JSON.parse(body);
      const newId = (Math.max(...data.depth_points.map(p => p.id), 0)) + 1;
      const point = {
        id: newId,
        ...input,
        created_at: input.created_at || new Date().toISOString()
      };
      data.depth_points.push(point);
      await saveDb(dbName, data);
      res.writeHead(201, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify(point));
      return;
    }
    
    if (req.method === 'PUT' && endpoint === 'depth_points' && id) {
      const input = JSON.parse(body);
      const idx = data.depth_points.findIndex(p => p.id == id);
      if (idx >= 0) {
        data.depth_points[idx] = { ...data.depth_points[idx], ...input };
        await saveDb(dbName, data);
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify(data.depth_points[idx]));
      } else {
        res.writeHead(404);
        res.end(JSON.stringify({ error: 'Not found' }));
      }
      return;
    }
    
    if (req.method === 'DELETE' && endpoint === 'depth_points' && id) {
      const idx = data.depth_points.findIndex(p => p.id == id);
      if (idx >= 0) {
        data.depth_points.splice(idx, 1);
        await saveDb(dbName, data);
        res.writeHead(204);
        res.end();
      } else {
        res.writeHead(404);
        res.end(JSON.stringify({ error: 'Not found' }));
      }
      return;
    }
    
    res.writeHead(404);
    res.end(JSON.stringify({ error: 'Not found' }));
  } catch (e) {
    console.error(e);
    res.writeHead(500, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ error: e.message }));
  }
}

const server = http.createServer(handleRequest);

server.listen(PORT, () => {
  console.log(`Lake Mapper Server running on port ${PORT}`);
});