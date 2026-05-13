/**
 * Leaflet Map Bridge für Flutter Web
 *
 * Verwendet ausschließlich lokal gebündelte Raster-Tiles (web/tiles/{z}/{x}/{y}.png).
 * Kein OSM, kein PMTiles-Client, keine externen Tile-Quellen.
 */

window._maplibreState = window._maplibreState || {
  map: null,
  lastError: null,
  onMapReady: null,
  onMapError: null,
  onMapTap: null,
  onMapMove: null,
};

// 1×1 transparentes GIF – für fehlende Tiles, damit keine roten Fehler-Kacheln erscheinen
var TRANSPARENT_TILE = 'data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7';

console.log('[MAP BRIDGE] Geladen (lokale Raster-Tiles)');

/**
 * Map initialisieren
 * @param {string} containerId  – ID des DOM-Containers
 * @param {string} tileBaseUrl  – Basis-URL für Tiles, z.B. "tiles" (relativ) oder absolute URL
 * @param {object} options      – { center: [lng, lat], zoom: number }
 */
window.initMapLibreMap = function(containerId, tileBaseUrl, options) {
  console.log('[MAP BRIDGE] Warte auf Container', containerId, '…');

  var _attempts = 0;

  function _tryFind() {
    var container = document.getElementById(containerId);
    if (!container) {
      _attempts++;
      if (_attempts < 60) { setTimeout(_tryFind, 250); }
      else { console.error('[MAP BRIDGE] Container nicht gefunden:', containerId); }
      return;
    }
    console.log('[MAP BRIDGE] Container gefunden nach', _attempts * 250, 'ms');
    _waitStableSize(container);
  }

  // Warte bis Container stabile Pixel-Maße hat (Flutter layoutet asynchron)
  var _sw = 0, _sh = 0, _stableCount = 0, _sChecks = 0;

  function _waitStableSize(container) {
    var w = container.offsetWidth;
    var h = container.offsetHeight;

    if (w > 0 && h > 0 && w === _sw && h === _sh) {
      _stableCount++;
      if (_stableCount >= 2) {
        console.log('[MAP BRIDGE] Container stabil', w + 'x' + h, 'nach', _sChecks * 150 + 'ms');
        _initLeaflet(container, w, h);
        return;
      }
    } else {
      _stableCount = 0; _sw = w; _sh = h;
    }
    _sChecks++;
    if (_sChecks < 80) setTimeout(function() { _waitStableSize(container); }, 150);
    else if (w > 0 && h > 0) { console.warn('[MAP BRIDGE] Timeout, init mit', w + 'x' + h); _initLeaflet(container, w, h); }
    else { console.error('[MAP BRIDGE] Container bleibt 0x0'); }
  }

  function _initLeaflet(container, cw, ch) {
    try {
      if (typeof L === 'undefined') {
        console.error('[MAP BRIDGE] Leaflet nicht geladen!');
        return;
      }

      // Explizite Pixel-Maße → Leaflet berechnet Tile-Grid korrekt
      container.style.width  = cw + 'px';
      container.style.height = ch + 'px';
      container.style.position = 'absolute';
      container.style.top  = '0';
      container.style.left = '0';

      // ── Karten-Konfiguration ───────────────────────────────────────────
      var cfg = options || {};
      var centerLng = (cfg.center && cfg.center[0]) || 8.4485;
      var centerLat = (cfg.center && cfg.center[1]) || 49.3394;  // Grenze zwischen beiden Tiles
      var initZoom  = cfg.zoom  || 14;

      // Bounds die beide Tiles umfassen
      var swLat = 49.3230, swLng = 8.4355;
      var neLat = 49.3550, neLng = 8.4620;

      var map = L.map(container, {
        center:             [centerLat, centerLng],
        zoom:               initZoom,
        minZoom:            13,
        maxZoom:            18,
        zoomControl:        false,
        attributionControl: false,
      });

      map.setMaxBounds(
        L.latLngBounds(L.latLng(swLat, swLng), L.latLng(neLat, neLng)).pad(0.15)
      );

      var resolvedBase = _resolveBase(tileBaseUrl);

      // ── Tile 14/8576/5602 (nördlicher Teil des Wammsee) ──────────────
      // lon: 8.4375°E–8.4595°E  |  lat: 49.3394°N–49.3538°N
      L.imageOverlay(
        resolvedBase + '/14/8576/5602.png',
        L.latLngBounds(L.latLng(49.3394, 8.4375), L.latLng(49.3538, 8.4595)),
        { opacity: 1.0, interactive: false }
      ).addTo(map);

      // ── Tile 14/8576/5603 (südlicher Teil des Wammsee) ───────────────
      // lon: 8.4375°E–8.4595°E  |  lat: 49.3250°N–49.3394°N
      L.imageOverlay(
        resolvedBase + '/14/8576/5603.png',
        L.latLngBounds(L.latLng(49.3250, 8.4375), L.latLng(49.3394, 8.4595)),
        { opacity: 1.0, interactive: false }
      ).addTo(map);

      var tileUrl = resolvedBase + '/14/8576/560{2,3}.png'; // für Debug-Panel

      // ── Overlay-Layer: GPS, Tiefenpunkte, Polygon ─────────────────────
      window._mapOverlayLayers = {};
      window._mapOverlayLayers.gpsGroup     = L.layerGroup().addTo(map);
      window._mapOverlayLayers.depthGroup   = L.layerGroup().addTo(map);
      window._mapOverlayLayers.polygonGroup = L.layerGroup().addTo(map);

      // ── Events ────────────────────────────────────────────────────────
      map.on('click', function(e) {
        var tap = { lat: e.latlng.lat, lng: e.latlng.lng, timestamp: Date.now() };
        window._maplibreState.lastTap = tap;
        if (window._maplibreState.onMapTap) window._maplibreState.onMapTap(tap);
      });

      map.on('moveend', function() {
        var c = map.getCenter();
        _updateDebugPanel(map, tileUrl);
        if (window._maplibreState.onMapMove) {
          window._maplibreState.onMapMove({ lat: c.lat, lng: c.lng, zoom: map.getZoom() });
        }
      });

      window._maplibreState.map = map;
      window._maplibreState.lastError = null;

      // Debug-Panel
      _createDebugPanel(map, container, tileUrl);

      // ResizeObserver: wenn Flutter den Container neu layoutet
      var ro = new ResizeObserver(function(entries) {
        for (var entry of entries) {
          var r = entry.contentRect;
          if (r.width > 0 && r.height > 0) {
            container.style.width  = r.width  + 'px';
            container.style.height = r.height + 'px';
            map.invalidateSize({ animate: false });
          }
        }
      });
      ro.observe(container.parentElement || container);

      if (window._maplibreState.onMapReady) window._maplibreState.onMapReady();
      console.log('[MAP BRIDGE] Karte initialisiert ✓');

    } catch(e) {
      console.error('[MAP BRIDGE] Fehler:', e);
      window._maplibreState.lastError = e.message;
      if (window._maplibreState.onMapError) window._maplibreState.onMapError(e.message);
    }
  }

  _tryFind();
};

// ── URL Helper ────────────────────────────────────────────────────────────────
function _resolveBase(base) {
  if (!base) return 'tiles';
  if (base.startsWith('http://') || base.startsWith('https://')) return base;
  // Relativ → absolut auflösen (damit Leaflet keine Probleme bekommt)
  var a = document.createElement('a');
  a.href = base;
  return a.href.replace(/\/$/, '');
}

// ── Debug-Panel ───────────────────────────────────────────────────────────────
function _createDebugPanel(map, container, tileUrl) {
  var panel = document.createElement('div');
  panel.id = 'map-debug-panel';
  panel.style.cssText =
    'position:absolute;bottom:8px;left:8px;z-index:9999;' +
    'background:rgba(10,25,41,0.85);color:#00e5cc;padding:8px 12px;' +
    'border-radius:8px;font-family:monospace;font-size:10px;line-height:1.6;' +
    'border:1px solid rgba(0,229,204,0.2);pointer-events:none;max-width:320px;';
  container.appendChild(panel);
  window._mapDebugPanel = panel;
  window._mapDebugTileUrl = tileUrl;
  _updateDebugPanel(map, tileUrl);
}

function _updateDebugPanel(map, tileUrl) {
  var panel = window._mapDebugPanel;
  if (!panel) return;
  var c = map.getCenter();
  panel.innerHTML =
    '<b>[MAP DEBUG]</b><br>' +
    'Tiles: ' + (window._mapDebugTileUrl || tileUrl || '?') + '<br>' +
    'Zoom: ' + map.getZoom().toFixed(1) + '<br>' +
    'Center: ' + c.lat.toFixed(5) + ', ' + c.lng.toFixed(5) + '<br>' +
    'GPS: ' + (window._mapGpsStatus || 'nicht aktiv');
}

// ── Polygon ───────────────────────────────────────────────────────────────────
window.drawWammseePolygon = function(coords) {
  var map = window._maplibreState.map;
  if (!map || !window._mapOverlayLayers) return;
  var g = window._mapOverlayLayers.polygonGroup;
  g.clearLayers();

  // Glow
  L.polygon(coords, { color: '#00e5ff', weight: 8, opacity: 0.08, fill: false }).addTo(g);
  // Outline
  L.polygon(coords, {
    color: '#00e5ff', weight: 2.5, opacity: 0.75,
    fillColor: '#00e5ff', fillOpacity: 0.05,
  }).addTo(g);
};

// ── Tiefenpunkte ─────────────────────────────────────────────────────────────
window.setDepthPoints = function(points) {
  var map = window._maplibreState.map;
  if (!map || !window._mapOverlayLayers) return;
  var g = window._mapOverlayLayers.depthGroup;
  g.clearLayers();

  for (var i = 0; i < points.length; i++) {
    var p = points[i];
    var color = _depthColor(p.depth);
    var m = L.circleMarker([p.lat, p.lng], {
      radius: 9, fillColor: color, color: '#0a1929', weight: 1.5, fillOpacity: 0.88,
    }).addTo(g);
    m.bindTooltip(
      (p.number ? '#' + p.number + ': ' : '') + p.depth.toFixed(1) + ' m',
      { permanent: false, direction: 'top', className: 'depth-tooltip' }
    );
  }
};

// ── GPS-Position ─────────────────────────────────────────────────────────────
window.setGpsPosition = function(lat, lng, accuracy) {
  var map = window._maplibreState.map;
  if (!map || !window._mapOverlayLayers) return;
  var g = window._mapOverlayLayers.gpsGroup;
  g.clearLayers();

  window._mapGpsStatus = 'aktiv (' + (accuracy ? accuracy.toFixed(0) + ' m' : '?') + ')';
  _updateDebugPanel(map, window._mapDebugTileUrl);

  L.circleMarker([lat, lng], {
    radius: 8, fillColor: '#42a5f5', color: '#fff', weight: 3, fillOpacity: 0.92,
  }).addTo(g);
  L.circleMarker([lat, lng], {
    radius: 18, fillColor: '#42a5f5', color: 'transparent', fillOpacity: 0.18,
  }).addTo(g);
};

// ── Navigation ───────────────────────────────────────────────────────────────
window.flyMapTo = function(lat, lng, zoom) {
  var map = window._maplibreState.map;
  if (!map) return;
  map.flyTo([lat, lng], zoom || map.getZoom());
};

window.setMapCenter = function(lat, lng, zoom) {
  var map = window._maplibreState.map;
  if (!map) return;
  map.setView([lat, lng], zoom || map.getZoom(), { animate: false });
};

window.getMapState = function() {
  return {
    initialized: window._maplibreState.map !== null,
    error: window._maplibreState.lastError,
    lastTap: window._maplibreState.lastTap || null,
  };
};

// ── Tiefenfarbe ──────────────────────────────────────────────────────────────
function _depthColor(d) {
  if (d < 2) return '#00e5ff';
  if (d < 4) return '#26c6da';
  if (d < 6) return '#00bcd4';
  if (d < 8) return '#0097a7';
  return '#ff6d00';
}
