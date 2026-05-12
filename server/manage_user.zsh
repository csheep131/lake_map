#!/usr/bin/env zsh
# User Management für Wammsee
# Usage: manage_user.zsh create <user> <pass>
#       manage_user.zsh delete <user>
#       manage_user.zsh passwd <user>

DB_PASSWORD="${DB_PASSWORD:-lake123}"

if [[ -z "$1" ]]; then
    print "Usage:"
    print "  ./manage_user.zsh create <username>"
    print "  ./manage_user.zsh delete <username>"
    print "  ./manage_user.zsh passwd <username>"
    exit 1
fi

CMD="$1"
USERNAME="$2"

# Statischer Hash
HASH='$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewY5GyYqW8z5k8W6'

case "$CMD" in
    create)
        if [[ -z "$USERNAME" ]]; then
            print "Usage: create <username>"
            exit 1
        fi
        PGPASSWORD="$DB_PASSWORD" psql -h localhost -U lakeuser -d lakemap -c "
        INSERT INTO users (username, password_hash, is_admin)
        VALUES ('$USERNAME', '$HASH', FALSE)
        ON CONFLICT (username) DO NOTHING;"
        print "User '$USERNAME' erstellt"
        ;;
        
    delete)
        if [[ -z "$USERNAME" ]]; then
            print "Usage: delete <username>"
            exit 1
        fi
        PGPASSWORD="$DB_PASSWORD" psql -h localhost -U lakeuser -d lakemap -c "
        DELETE FROM users WHERE username = '$USERNAME';"
        print "User '$USERNAME' geloescht"
        ;;
        
    passwd)
        if [[ -z "$USERNAME" ]]; then
            print "Usage: passwd <username>"
            exit 1
        fi
        PGPASSWORD="$DB_PASSWORD" psql -h localhost -U lakeuser -d lakemap -c "
        UPDATE users SET password_hash = '$HASH' WHERE username = '$USERNAME';"
        print "Passwort fuer '$USERNAME' geaendert"
        ;;
        
    *)
        print "Unknown command: $CMD"
        exit 1
        ;;
esac