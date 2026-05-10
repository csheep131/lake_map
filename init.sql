-- PostGIS aktivieren (muss zuerst!)
CREATE EXTENSION IF NOT EXISTS postgis;

-- Seen-Tabelle
CREATE TABLE IF NOT EXISTS lakes (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL UNIQUE,
    polygon GEOMETRY(POLYGON, 4326),
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

-- Verify
SELECT name, ST_IsValid(polygon) AS valid FROM lakes WHERE name = 'Wammsee';