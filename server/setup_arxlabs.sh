#!/bin/bash

# Setup-Script für Wammsee Server auf arxlabs.dev
# systemd Service + PostgreSQL

set -e

SERVER_DIR="/opt/wammsee-server"
SERVER_USER="www-data"
SERVER_PORT="${PORT:-3000}"

echo "=== Wammsee Server Setup (systemd) ==="

# 1. Server-Dateien kopieren
echo "[1/4] Kopiere Server-Dateien nach $SERVER_DIR..."
sudo mkdir -p $SERVER_DIR
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
sudo cp $SCRIPT_DIR/server/server.js $SERVER_DIR/
sudo cp $SCRIPT_DIR/server/package.json $SERVER_DIR/
sudo cp $SCRIPT_DIR/init.sql $SERVER_DIR/

# 2. Node.js + npm packages
echo "[2/4] Installiere Node.js und Dependencies..."
if ! command -v node &> /dev/null; then
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
    sudo apt-get install -y nodejs
fi
cd $SERVER_DIR
sudo npm install --production

# 3. systemd Service installieren
echo "[3/4] Installiere systemd Service..."
sudo cp $SCRIPT_DIR/server/wammsee.service /etc/systemd/system/
sudo systemctl daemon-reload

# 4. Server starten
echo "[4/4] Starte Server..."
sudo systemctl enable wammsee
sudo systemctl restart wammsee
sudo systemctl status wammsee --no-pager

echo ""
echo "=== Fertig! ==="
echo "Server: http://arxlabs.dev:$SERVER_PORT"
echo ""
echo "Befehle:"
echo "  Status:   sudo systemctl status wammsee"
echo "  Neustart: sudo systemctl restart wammsee"
echo "  Logs:     sudo journalctl -u wammsee -f"
echo ""
echo "Test-Login (nur Testdaten):"
echo "  user: test / pass: test123"
echo ""
echo "Admin-Login (alle Daten):"
echo "  user: admin / pass: wammsee2024"