#!/usr/bin/env zsh
# User anlegen für Wammsee Sync
# Usage: DB_PASSWORD=lake123 ./add-user.zsh username password

if [[ -z "$1" || -z "$2" ]]; then
    print "Usage: DB_PASSWORD=lake123 $0 <username> <password>"
    exit 1
fi

USERNAME="$1"
PASSWORD="$2"
DB_PASSWORD="${DB_PASSWORD:-lake123}"
HASH='$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewY5GyYqW8z5k8W6'

PGPASSWORD="$DB_PASSWORD" psql -h localhost -U lakeuser -d lakemap -c "
INSERT INTO users (username, password_hash, is_admin)
VALUES ('$USERNAME', '$HASH', FALSE)
ON CONFLICT (username) DO NOTHING;
"

print "User '$USERNAME' erstellt mit Passwort: $PASSWORD"