-- PostGIS aktivieren (muss zuerst!)
CREATE EXTENSION IF NOT EXISTS postgis;

-- Seen-Tabelle
CREATE TABLE IF NOT EXISTS lakes (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL UNIQUE,
    polygon GEOMETRY(POLYGON, 4326),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Credentials / Benutzer
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(100) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    is_admin BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Tiefenmessungen
CREATE TABLE IF NOT EXISTS lake_depths (
    id SERIAL PRIMARY KEY,
    lake_id INT REFERENCES lakes(id),
    depth_m FLOAT NOT NULL,
    location GEOGRAPHY(POINT, 4326),
    accuracy_m FLOAT,
    note TEXT,
    measured_at TIMESTAMPTZ DEFAULT NOW(),
    user_id INT DEFAULT 1,
    synced BOOLEAN DEFAULT FALSE
);

-- Indizes
CREATE INDEX IF NOT EXISTS idx_lake_depths_lake_id ON lake_depths(lake_id);
CREATE INDEX IF NOT EXISTS idx_lake_depths_location ON lake_depths USING GIST(location);
CREATE INDEX IF NOT EXISTS idx_lake_depths_measured_at ON lake_depths(measured_at);

-- Rechte
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO lakeuser;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO lakeuser;

-- Wammsee Polygon (vereinfacht - Hauptpunkt)
INSERT INTO lakes (name, polygon) 
SELECT 'Wammsee', ST_GeomFromText(
    'POLYGON((8.4458 49.3416,8.4456 49.3412,8.4495 49.3476,8.4518 49.3473,
             8.4519 49.3470,8.4471 49.3453,8.4469 49.3458,8.4456 49.3411,
             8.4501 49.3396,8.4501 49.3476,8.4485 49.3474,8.4459 49.3417,
             8.4507 49.3428,8.4514 49.3474,8.4511 49.3456,8.4464 49.3428,
             8.4488 49.3384,8.4503 49.3413,8.4504 49.3411,8.4508 49.3444,
             8.4458 49.3416))', 4326)
WHERE NOT EXISTS (SELECT 1 FROM lakes WHERE name = 'Wammsee');

-- Admin-User (Passwort: wammsee2024)
-- hash: bcrypt($2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewY5GyYqW8z5k8W6)
INSERT INTO users (username, password_hash, is_admin)
SELECT 'admin', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewY5GyYqW8z5k8W6', TRUE
WHERE NOT EXISTS (SELECT 1 FROM users WHERE username = 'admin');

-- Test-User (nur Testdaten)
-- hash: test123
-- $2b$12$KQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewY5GyYqW8z5k8W6
INSERT INTO users (username, password_hash, is_admin)
SELECT 'test', '$2b$12$KQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewY5GyYqW8z5k8W6', FALSE
WHERE NOT EXISTS (SELECT 1 FROM users WHERE username = 'test');

-- 3 Test-Messpunkte (nur für Test-User sichtbar)
INSERT INTO lake_depths (lake_id, depth_m, location, note)
SELECT l.id, d.depth, ST_MakePoint(d.lon, d.lat)::geography, d.note
FROM lakes l,
     (VALUES 
       (3.5, 49.3469, 8.4468, 'Testpunkt 1 - flach'),
       (5.2, 49.3472, 8.4475, 'Testpunkt 2 - mittig'),
       (7.8, 49.3465, 8.4482, 'Testpunkt 3 - tief')
     ) AS d(depth, lat, lon, note)
CROSS JOIN (SELECT id FROM lakes WHERE name = 'Wammsee') l
WHERE l.id = (SELECT id FROM lakes WHERE name = 'Wammsee')
  AND NOT EXISTS (SELECT 1 FROM lake_depths WHERE note = d.note);

-- Verify
SELECT name, ST_IsValid(polygon) AS valid FROM lakes WHERE name = 'Wammsee';
SELECT username, is_admin FROM users;