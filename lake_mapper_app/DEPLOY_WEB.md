# Web Deployment Guide for Wammsee App

To deploy the Flutter Web application to the production server (`arxlabs.dev`), follow these exact steps. This ensures that assets, base paths, and server synchronization work correctly.

## Prerequisites
- Flutter SDK installed at `/home/schaf/develop/flutter`
- SSH access to `arxlabs.dev` configured

## Deployment Command (One-Liner)
Run this command from the `lake_mapper_app` directory:

```bash
/home/schaf/develop/flutter/bin/flutter build web --no-tree-shake-icons && \
sed -i 's|<base href="/">|<base href="/web/">|g' build/web/index.html && \
rsync -avz --delete build/web/ arxlabs.dev:/home/schaf/wammsee/public/web/
```

## Full Deployment (inkl. Server)
To deploy both the web app and the backend:

```bash
# 1. Server.js deployen
scp server/server.js arxlabs.dev:/home/schaf/wammsee/server.js

# 2. Web Build + Deploy
cd lake_mapper_app
/home/schaf/develop/flutter/bin/flutter build web --no-tree-shake-icons
sed -i 's|<base href="/">|<base href="/web/">|g' build/web/index.html
rsync -avz --delete build/web/ arxlabs.dev:/home/schaf/wammsee/public/web/

# 3. Server neustarten
ssh arxlabs.dev "pkill -f 'node server.js'; sleep 1; cd /home/schaf/wammsee && PORT=3333 DB_HOST=localhost DB_PORT=5432 DB_NAME=lakemap DB_USER=lakeuser DB_PASSWORD=lake123 TOKEN_SECRET=b10c5c35395aebb8bb02bddd3ad519b609f3cb3f0dccc71fd90e44008e85230c ALLOWED_ORIGINS=https://wammsee.arxlabs.dev nohup node server.js > server.log 2>&1 &"
```

## APK Deployment
```bash
scp andro_app/wammsee-v1.0.3.apk arxlabs.dev:/home/schaf/wammsee/public/downloads/wammsee-lake-mapper.apk
```

## Explanation of Steps
1. **Build**: `flutter build web --no-tree-shake-icons`
   - Compiles the app for the web.
   - `--no-tree-shake-icons` is required for some icon fonts to display correctly.
2. **Base Path Fix**: `sed -i 's|<base href="/">|<base href="/web/">|g' build/web/index.html`
   - Since the app is hosted under the `/web/` subdirectory on the server, the base href in `index.html` must be updated.
3. **Sync**: `rsync -avz --delete build/web/ arxlabs.dev:/home/schaf/wammsee/public/web/`
   - Transfers the compiled files to the server.
   - The `--delete` flag ensures that old, unused files are removed from the server.

## Server Environment
- **Host**: arxlabs.dev (wammsee.arxlabs.dev)
- **Path**: `/home/schaf/wammsee/public/web/`
- **Node.js Server**: Port 3333, proxied via Nginx HTTPS
- **Required ENV**: PORT, DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASSWORD, TOKEN_SECRET, ALLOWED_ORIGINS
- **Range Requests**: Server supports HTTP 206 Partial Content for PMTiles

## URLs
- **Landing Page**: https://wammsee.arxlabs.dev/
- **Web App**: https://wammsee.arxlabs.dev/web/
- **API Health**: https://wammsee.arxlabs.dev/health
- **APK Download**: https://wammsee.arxlabs.dev/downloads/wammsee-lake-mapper.apk
