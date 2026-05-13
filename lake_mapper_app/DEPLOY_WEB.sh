#!/bin/bash
# DEPLOY_WEB.sh — Wammsee Web-App vollständig deployen
# Führt Flutter-Build aus und kopiert ALLE benötigten Dateien auf den Server.
# Flutter kopiert web/*.js NICHT automatisch in build/web/ — daher manuell!

set -e
cd "$(dirname "$0")"

echo "=== Flutter Web Build ==="
flutter/bin/flutter build web --no-tree-shake-icons --base-href "/web/"

echo "=== Sync Flutter Build ==="
rsync -avz --delete build/web/ arxlabs.dev:/home/schaf/wammsee/public/web/

echo "=== Sync Web-Assets (maplibre JS, tiles) ==="
# Flutter kopiert web/*.js NICHT in build/web/ → manuell deployen
rsync -avz \
  web/maplibre_init.js \
  web/maplibre_bridge.js \
  arxlabs.dev:/home/schaf/wammsee/public/web/

# Tiles ebenfalls deployen (werden durch --delete oben gelöscht)
rsync -avz web/tiles/ arxlabs.dev:/home/schaf/wammsee/public/web/tiles/

echo "=== Verify ==="
ssh arxlabs.dev 'ls /home/schaf/wammsee/public/web/maplibre*.js && \
  find /home/schaf/wammsee/public/web/tiles -name "*.png" | wc -l | xargs echo "Tiles:"'

echo "=== DEPLOYMENT DONE ==="
