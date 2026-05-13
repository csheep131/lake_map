/**
 * Leaflet + protomaps-leaflet Bridge für Flutter Web
 * Kein WebGL erforderlich — rendert mit Canvas2D.
 * PMTiles Vektor-Tiles werden über protomaps-leaflet gerendert.
 */

window._maplibreState = window._maplibreState || {
  map: null,
  pmtilesLoaded: false,
  lastError: null,
  onMapReady: null,
  onMapError: null,
  onMapTap: null,
  onMapMove: null,
};

console.log('Map Bridge JS geladen (Leaflet + protomaps-leaflet)');

/**
 * PMTiles URL ermitteln (relativ zum aktuellen Host)
 */
function _resolvePmtilesUrl(pmtilesUrl) {
  if (pmtilesUrl.startsWith('http://') || pmtilesUrl.startsWith('https://')) {
    return pmtilesUrl;
  }
  var base = document.querySelector('base');
  var baseHref = base ? base.getAttribute('href') : '/';
  if (!baseHref.endsWith('/')) baseHref += '/';
  return window.location.origin + baseHref + pmtilesUrl;
}

/**
 * Map initialisieren (Leaflet + protomaps-leaflet)
 */
window.initMapLibreMap = function(containerId, pmtilesUrl, options) {
  console.log('Map: Initializing in container', containerId);

  try {
    var container = document.getElementById(containerId);
    if (!container) {
      console.error('Map: Container nicht gefunden:', containerId);
      window._maplibreState.lastError = 'Container nicht gefunden';
      if (window._maplibreState.onMapError) {
        window._maplibreState.onMapError('Container nicht gefunden');
      }
      return;
    }

    if (typeof L === 'undefined') {
      console.error('Map: Leaflet nicht geladen');
      window._maplibreState.lastError = 'Leaflet nicht geladen';
      if (window._maplibreState.onMapError) {
        window._maplibreState.onMapError('Leaflet nicht geladen');
      }
      return;
    }

    console.log('Map: Leaflet geladen, erstelle Karte...');

    // Container-Größe sicherstellen
    container.style.width = '100%';
    container.style.height = '100%';

    // Leaflet Karte erstellen
    var center = options.center || [8.4495, 49.3425];
    var zoom = options.zoom || 15.5;

    var map = L.map(container, {
      center: [center[1], center[0]], // Leaflet nutzt [lat, lng]
      zoom: zoom,
      minZoom: 13,
      maxZoom: 19,
      zoomControl: false,
      attributionControl: false,
    });

    // Bounds setzen (Wammsee + Umgebung)
    var bounds = L.latLngBounds(
      L.latLng(49.3335, 8.4385), // SW
      L.latLng(49.3515, 8.4595)  // NE
    );
    map.setMaxBounds(bounds.pad(0.5));

    // OSM Basis-Tiles (ohne Attribution)
    var osmLayer = L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png', {
      attribution: '',
      maxZoom: 19
    }).addTo(map);

    // PMTiles Vektor-Layer (protomaps-leaflet)
    var resolvedUrl = _resolvePmtilesUrl(pmtilesUrl);
    console.log('Map: PMTiles URL:', resolvedUrl);

    if (typeof protomapsL !== 'undefined') {
      try {
        var pmtilesLayer = protomapsL.leafletLayer({
          url: resolvedUrl,
          paintRules: _getPaintRules(),
          labelRules: _getLabelRules(),
        });
        pmtilesLayer.addTo(map);
        console.log('Map: protomaps-leaflet PMTiles Layer hinzugefügt');
        window._maplibreState.pmtilesLoaded = true;
      } catch (e) {
        console.warn('Map: protomaps-leaflet Fehler (OSM wird verwendet):', e);
      }
    } else {
      console.warn('Map: protomaps-leaflet nicht geladen, nur OSM');
    }

    // Overlay-Layer (GPS, Tiefenpunkte) vorbereiten
    window._mapOverlayLayers = {};
    _addOverlayLayers(map);

    // Events
    map.on('click', function(e) {
      var tap = {
        lat: e.latlng.lat,
        lng: e.latlng.lng,
        timestamp: Date.now()
      };
      window._maplibreState.lastTap = tap;
      if (window._maplibreState.onMapTap) {
        window._maplibreState.onMapTap(tap);
      }
    });

    map.on('moveend', function() {
      var center = map.getCenter();
      if (window._maplibreState.onMapMove) {
        window._maplibreState.onMapMove({
          lat: center.lat,
          lng: center.lng,
          zoom: map.getZoom()
        });
      }
    });

    window._maplibreState.map = map;
    window._maplibreState.lastError = null;

    if (window._maplibreState.onMapReady) {
      window._maplibreState.onMapReady();
    }

    console.log('Map: Erfolgreich initialisiert (Leaflet, kein WebGL)');

  } catch(e) {
    console.error('Map: Init error:', e);
    window._maplibreState.lastError = e.message;
    if (window._maplibreState.onMapError) {
      window._maplibreState.onMapError(e.message);
    }
  }
};

/**
 * protomaps-leaflet Paint Rules
 * Styling für PMTiles Vektor-Tiles (Protomaps Basemap)
 */
function _getPaintRules() {
  if (typeof protomapsL === 'undefined') return [];

  return [
    {
      dataLayer: 'earth',
      symbolizer: new protomapsL.PolygonSymbolizer({ fill: '#e8e8e0', opacity: 0.4 })
    },
    {
      dataLayer: 'water',
      symbolizer: new protomapsL.PolygonSymbolizer({ fill: '#8ecae6', opacity: 0.7 })
    },
    {
      dataLayer: 'landuse',
      symbolizer: new protomapsL.PolygonSymbolizer({ fill: '#dcedc8', opacity: 0.4 })
    },
    {
      dataLayer: 'natural',
      symbolizer: new protomapsL.PolygonSymbolizer({ fill: '#c8e6c9', opacity: 0.4 })
    },
    {
      dataLayer: 'buildings',
      symbolizer: new protomapsL.PolygonSymbolizer({ fill: '#d5d5d5', opacity: 0.6, stroke: '#bbb', width: 0.5 }),
      minzoom: 14
    },
    {
      dataLayer: 'roads',
      symbolizer: new protomapsL.LineSymbolizer({ color: '#ffffff', width: 3, opacity: 0.6 }),
      filter: function(z, f) { return f.props.kind === 'highway'; }
    },
    {
      dataLayer: 'roads',
      symbolizer: new protomapsL.LineSymbolizer({ color: '#ffa726', width: 2, opacity: 0.7 }),
      filter: function(z, f) { return f.props.kind === 'highway'; }
    },
    {
      dataLayer: 'roads',
      symbolizer: new protomapsL.LineSymbolizer({ color: '#e0e0e0', width: 1.5, opacity: 0.6 }),
      filter: function(z, f) { return f.props.kind !== 'highway'; }
    },
    {
      dataLayer: 'boundaries',
      symbolizer: new protomapsL.LineSymbolizer({ color: '#999', width: 1, opacity: 0.3, dash: [3, 2] })
    },
  ];
}

/**
 * protomaps-leaflet Label Rules
 */
function _getLabelRules() {
  if (typeof protomapsL === 'undefined') return [];

  return [
    {
      dataLayer: 'places',
      symbolizer: new protomapsL.CenteredTextSymbolizer({
        labelProps: ['name:de', 'name'],
        fill: '#444',
        stroke: '#fff',
        width: 2,
        font: '13px sans-serif'
      }),
      minzoom: 10
    },
    {
      dataLayer: 'water',
      symbolizer: new protomapsL.CenteredTextSymbolizer({
        labelProps: ['name:de', 'name'],
        fill: '#2979b0',
        stroke: 'rgba(255,255,255,0.8)',
        width: 1.5,
        font: 'italic 13px sans-serif'
      }),
      filter: function(z, f) { return f.props.name; }
    },
  ];
}

/**
 * Overlay-Layer hinzufügen (GPS, Tiefenpunkte)
 */
function _addOverlayLayers(map) {
  // GPS-Marker Layer
  window._mapOverlayLayers.gpsGroup = L.layerGroup().addTo(map);
  // Tiefenpunkte Layer
  window._mapOverlayLayers.depthGroup = L.layerGroup().addTo(map);
  // Wammsee Polygon Layer
  window._mapOverlayLayers.polygonGroup = L.layerGroup().addTo(map);
}

// =====================================================
// Marker und Overlay API (für Dart JS-Interop)
// =====================================================

/**
 * Wammsee Lake Polygon zeichnen
 */
window.drawWammseePolygon = function(polygonCoords) {
  var map = window._maplibreState.map;
  if (!map || !window._mapOverlayLayers) return;

  var group = window._mapOverlayLayers.polygonGroup;
  group.clearLayers();

  // Outer glow
  L.polygon(polygonCoords, {
    color: '#00e5ff',
    weight: 8,
    opacity: 0.1,
    fill: false,
  }).addTo(group);

  // Main outline
  L.polygon(polygonCoords, {
    color: '#00e5ff',
    weight: 3,
    opacity: 0.7,
    fillColor: '#00e5ff',
    fillOpacity: 0.06,
  }).addTo(group);
};

/**
 * Tiefenpunkte auf der Karte anzeigen
 */
window.setDepthPoints = function(points) {
  var map = window._maplibreState.map;
  if (!map || !window._mapOverlayLayers) return;

  var group = window._mapOverlayLayers.depthGroup;
  group.clearLayers();

  for (var i = 0; i < points.length; i++) {
    var p = points[i];
    var color = _depthColor(p.depth);

    var marker = L.circleMarker([p.lat, p.lng], {
      radius: 10,
      fillColor: color,
      color: '#0a1929',
      weight: 1.5,
      fillOpacity: 0.85,
    }).addTo(group);

    marker.bindTooltip(
      (p.number ? '#' + p.number + ': ' : '') + p.depth.toFixed(1) + 'm',
      { permanent: false, direction: 'top', className: 'depth-tooltip' }
    );
  }
};

/**
 * GPS-Position anzeigen
 */
window.setGpsPosition = function(lat, lng, accuracy) {
  var map = window._maplibreState.map;
  if (!map || !window._mapOverlayLayers) return;

  var group = window._mapOverlayLayers.gpsGroup;
  group.clearLayers();

  // GPS Marker
  L.circleMarker([lat, lng], {
    radius: 8,
    fillColor: '#42a5f5',
    color: '#fff',
    weight: 3,
    fillOpacity: 0.9,
  }).addTo(group);

  // GPS Glow
  L.circleMarker([lat, lng], {
    radius: 16,
    fillColor: '#42a5f5',
    color: 'transparent',
    fillOpacity: 0.2,
  }).addTo(group);
};

/**
 * Karte auf Position zentrieren
 */
window.flyMapTo = function(lat, lng, zoom) {
  var map = window._maplibreState.map;
  if (!map) return;
  map.flyTo([lat, lng], zoom || map.getZoom());
};

// Alias für Dart-Interop Kompatibilität
window.flyTo = window.flyMapTo;
window.setMapCenter = function(lat, lng, zoom) {
  var map = window._maplibreState.map;
  if (!map) return;
  if (zoom) {
    map.setView([lat, lng], zoom);
  } else {
    map.setView([lat, lng]);
  }
};

/**
 * Map Status abfragen
 */
window.getMapState = function() {
  return {
    initialized: window._maplibreState.map !== null,
    pmtilesLoaded: window._maplibreState.pmtilesLoaded,
    error: window._maplibreState.lastError,
    lastTap: window._maplibreState.lastTap || null,
    renderer: 'leaflet-canvas2d',
  };
};

/**
 * Tiefenfarbe berechnen
 */
function _depthColor(depth) {
  if (depth < 2) return '#00e5ff';
  if (depth < 4) return '#26c6da';
  if (depth < 6) return '#00bcd4';
  if (depth < 8) return '#0097a7';
  return '#ff6d00';
}
