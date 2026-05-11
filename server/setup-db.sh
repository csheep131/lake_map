#!/bin/bash
# DB Setup für Wammsee Server
# Ausführen: 
#   sudo -i -u postgres bash /home/schaf/wammsee/setup-db.sh
# ODER mit Passwort:
#   PGPASSWORD=xxx psql -h localhost -U postgres -f /home/schaf/wammsee/setup-db.sh

psql -h localhost -U postgres <<'EOF'

-- User erstellen
CREATE USER lakeuser WITH PASSWORD 'lake123';
CREATE DATABASE lakemap OWNER lakeuser;
GRANT ALL PRIVILEGES ON DATABASE lakemap TO lakeuser;

\c lakemap

-- PostGIS
CREATE EXTENSION IF NOT EXISTS postgis;

-- Seen
CREATE TABLE IF NOT EXISTS lakes (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL UNIQUE,
    polygon GEOMETRY(POLYGON, 4326),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- User
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(100) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    is_admin BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Tiefen
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

GRANT ALL ON ALL TABLES TO lakeuser;
GRANT ALL ON ALL SEQUENCES TO lakeuser;

-- Wammsee
INSERT INTO lakes (name, polygon)
SELECT 'Wammsee', ST_GeomFromText(
'POLYGON((8.4458 49.3416,8.4456 49.3412,8.4495 49.3476,8.4518 49.3473,
8.4519 49.3470,8.4471 49.3453,8.4469 49.3458,8.4456 49.3411,
8.4501 49.3396,8.4501 49.3476,8.4485 49.3474,8.4459 49.3417,
8.4507 49.3428,8.4514 49.3474,8.4511 49.3456,8.4464 49.3428,
8.4488 49.3384,8.4503 49.3413,8.4504 49.3411,8.4508 49.3444,
8.4458 49.3416))', 4326)
WHERE NOT EXISTS (SELECT 1 FROM lakes WHERE name = 'Wammsee');

-- Testuser
INSERT INTO users (username, password_hash, is_admin)
SELECT 'test', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewY5GyYqW8z5k8W6', FALSE
WHERE NOT EXISTS (SELECT 1 FROM users WHERE username = 'test');

-- Admin
INSERT INTO users (username, password_hash, is_admin)
SELECT 'admin', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewY5GyYqW8z5k8W6', TRUE
WHERE NOT EXISTS (SELECT 1 FROM users WHERE username = 'admin');

-- 3 Testpunkte
INSERT INTO lake_depths (lake_id, depth_m, location, note, user_id)
SELECT (SELECT id FROM lakes WHERE name = 'Wammsee'), d.depth, ST_MakePoint(d.lon, d.lat)::geography, d.note, 1
FROM (VALUES (3.5, 49.3469, 8.4468, 'Testpunkt 1'),
 (5.2, 49.3472, 8.4475, 'Testpunkt 2'),
 (7.8, 49.3465, 8.4482, 'Testpunkt 3')
) AS d(depth, lat, lon, note);

SELECT 'Fertig!' AS status;
SELECT username, is_admin FROM users;
SELECT depth_m, note FROM lake_depths;

EOF