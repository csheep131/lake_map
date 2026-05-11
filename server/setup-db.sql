-- DB Setup für Wammsee OHNE PostGIS (da nicht installiert)
-- Ausführen: PGPASSWORD=xxx psql -h localhost -U postgres -f /home/schaf/wammsee/setup-db.sql

-- User
CREATE USER lakeuser WITH PASSWORD 'lake123';
CREATE DATABASE lakemap OWNER lakeuser;

\c lakemap postgres

-- Seen (einfache Koordinaten statt PostGIS)
CREATE TABLE IF NOT EXISTS lakes (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL UNIQUE,
    lat_min FLOAT, lat_max FLOAT,
    lon_min FLOAT, lon_max FLOAT,
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

-- Tiefen (einfache Koordinaten)
CREATE TABLE IF NOT EXISTS lake_depths (
    id SERIAL PRIMARY KEY,
    lake_id INT REFERENCES lakes(id),
    depth_m FLOAT NOT NULL,
    latitude FLOAT,
    longitude FLOAT,
    accuracy_m FLOAT,
    note TEXT,
    measured_at TIMESTAMPTZ DEFAULT NOW(),
    user_id INT DEFAULT 1,
    synced BOOLEAN DEFAULT FALSE
);

-- GRANTS
GRANT ALL ON ALL TABLES IN SCHEMA public TO lakeuser;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO lakeuser;

-- Wammsee
INSERT INTO lakes (name, lat_min, lat_max, lon_min, lon_max)
SELECT 'Wammsee', 49.338, 49.348, 8.445, 8.452
WHERE NOT EXISTS (SELECT 1 FROM lakes WHERE name = 'Wammsee');

-- Testuser (pass: test123)
INSERT INTO users (username, password_hash, is_admin)
SELECT 'test', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewY5GyYqW8z5k8W6', FALSE
WHERE NOT EXISTS (SELECT 1 FROM users WHERE username = 'test');

-- Admin (pass: wammsee2024)
INSERT INTO users (username, password_hash, is_admin)
SELECT 'admin', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewY5GyYqW8z5k8W6', TRUE
WHERE NOT EXISTS (SELECT 1 FROM users WHERE username = 'admin');

-- 3 Testpunkte
INSERT INTO lake_depths (lake_id, depth_m, latitude, longitude, note, user_id)
SELECT (SELECT id FROM lakes WHERE name = 'Wammsee'), d.depth, d.lat, d.lon, d.note, 1
FROM (VALUES 
 (3.5, 49.3469, 8.4468, 'Testpunkt 1'),
 (5.2, 49.3472, 8.4475, 'Testpunkt 2'),
 (7.8, 49.3465, 8.4482, 'Testpunkt 3')
) AS d(depth, lat, lon, note);

-- Verify
SELECT 'Fertig!' AS msg;
SELECT username FROM users;
SELECT depth_m, note FROM lake_depths;