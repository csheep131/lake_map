#!/bin/bash

# Setup-Script für Wammsee App Backend auf arxlabs.dev
# Führt den Server als Service aus

set -e

SERVER_DIR="/opt/wammsee-server"
SERVER_PORT="${PORT:-3000}"
SYSTEMD_SERVICE="wammsee.service"

echo "=== Wammsee App Server Setup ==="

# Verzeichnis erstellen
echo "[1/5] Erstelle Verzeichnis $SERVER_DIR..."
sudo mkdir -p $SERVER_DIR
sudo mkdir -p $SERVER_DIR/data

# Server-Datei kopieren
echo "[2/5] Kopiere Server-Datei..."
# Falls dieses Script im lake_mapper_repo liegt
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -f "$SCRIPT_DIR/server/server.js" ]; then
    sudo cp -r $SCRIPT_DIR/server/* $SERVER_DIR/
else
    echo "FEHLER: server.js nicht gefunden"
    exit 1
fi

# Node.js installieren falls nicht vorhanden
echo "[3/5] Prüfe Node.js..."
if ! command -v node &> /dev/null; then
    echo "Installiere Node.js..."
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
    sudo apt-get install -y nodejs
fi

# pm2 installieren für Process Management
echo "[4/5] Installiere pm2..."
sudo npm install -g pm2

# Service starten
echo "[5/5] Starte Server mit pm2..."
cd $SERVER_DIR
sudo pm2 stop wammsee 2>/dev/null || true
sudo pm2 start server.js --name wammsee --env "PORT=$SERVER_PORT"

# Autostart einrichten
sudo pm2 startup
sudo pm2 save

echo ""
echo "=== Fertig! ==="
echo "Server läuft auf Port $SERVER_PORT"
echo ""
echo "Befehle:"
echo "  Status:   pm2 status wammsee"
echo "  Logs:    pm2 logs wammsee"
echo "  Neustart: pm2 restart wammsee"
echo "  Stoppen:  pm2 stop wammsee"