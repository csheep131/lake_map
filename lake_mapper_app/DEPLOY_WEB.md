# Web Deployment Guide for Wammsee App

To deploy the Flutter Web application to the production server (`arxlabs.dev`), follow these exact steps. This ensures that assets, base paths, and server synchronization work correctly.

## Prerequisites
- Flutter SDK installed at `/home/schaf/flutter_sdk`
- SSH access to `arxlabs.dev` configured

## Deployment Command (One-Liner)
Run this command from the `lake_mapper_app` directory:

```bash
/home/schaf/flutter_sdk/bin/flutter build web --no-tree-shake-icons && \
sed -i 's|<base href="/">|<base href="/web/">|g' build/web/index.html && \
rsync -avz --delete build/web/ arxlabs.dev:/home/schaf/wammsee/public/web/
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
- **Host**: arxlabs.dev
- **Path**: `/home/schaf/wammsee/public/web/`
- **Proxy**: Nginx handles the `/web` path and redirects to the local Node.js server or static files.
