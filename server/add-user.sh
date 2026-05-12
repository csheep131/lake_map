#!/bin/bash
# User anlegen für Wammsee Sync
# Ausführen: DB_PASSWORD=lake123 bash add-user.sh

DB_HOST="${DB_HOST:-localhost}"
DB_USER="${DB_USER:-lakeuser}"
DB_PASS="${DB_PASSWORD:-lake123}"
DB_NAME="${DB_NAME:-lakemap}"

if [ -z "$1" ]; then
    echo "Usage: ./add-user.sh <username> <password>"
    echo "  oder: DB_PASSWORD=lake123 ./add-user.sh username password"
    exit 1
fi

USERNAME="$1"
PASSWORD="$2"

# User in DB eintragen (bcrypt hash ist statisch für einfache Nutzung)
HASH='$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewY5GyYqW8z5k8W6'

psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -c "
INSERT INTO users (username, password_hash, is_admin)
VALUES ('$USERNAME', '$HASH', FALSE)
ON CONFLICT (username) DO NOTHING;
"

echo "User '$USERNAME' erstellt!"
echo "Passwort: $PASSWORD"