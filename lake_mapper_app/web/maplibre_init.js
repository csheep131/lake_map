/**
 * Leaflet CDN Loader für Flutter Web
 *
 * Nur Leaflet wird benötigt — keine PMTiles/protomaps-leaflet mehr.
 * Raster-Tiles kommen als vorgerenderte PNGs vom eigenen Server.
 */

(function() {
  'use strict';

  // CDN URLs — nur Leaflet
  var LEAFLET_JS = 'https://unpkg.com/leaflet@1.9.4/dist/leaflet.js';
  var LEAFLET_CSS = 'https://unpkg.com/leaflet@1.9.4/dist/leaflet.css';

  // Promise für fertiges Laden
  window._maplibreLoaded = new Promise(function(resolve, reject) {
    window._maplibreResolve = resolve;
    window._maplibreReject = reject;
  });

  function loadCSS(url) {
    return new Promise(function(resolve, reject) {
      var existing = document.querySelector('link[href="' + url + '"]');
      if (existing) { resolve(); return; }
      var link = document.createElement('link');
      link.rel = 'stylesheet';
      link.href = url;
      link.onload = function() { resolve(); };
      link.onerror = function() { reject(new Error('CSS ' + url)); };
      document.head.appendChild(link);
    });
  }

  function loadScript(url) {
    return new Promise(function(resolve, reject) {
      var existing = document.querySelector('script[src="' + url + '"]');
      if (existing) { resolve(); return; }
      var script = document.createElement('script');
      script.src = url;
      script.async = false;
      script.onload = function() { resolve(); };
      script.onerror = function() { reject(new Error('Script ' + url)); };
      document.head.appendChild(script);
    });
  }

  async function loadAll() {
    console.log('[MAP LOADER] Starte Leaflet-Laden...');

    try {
      await loadCSS(LEAFLET_CSS);
      console.log('[MAP LOADER] Leaflet CSS geladen');

      await loadScript(LEAFLET_JS);
      console.log('[MAP LOADER] Leaflet JS geladen');

      console.log('[MAP LOADER] Fertig (nur Leaflet, keine externen Tile-Quellen)');
      window._maplibreResolve();

    } catch (e) {
      console.error('[MAP LOADER] Fehler:', e);
      window._maplibreReject(e);
    }
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', loadAll);
  } else {
    loadAll();
  }

})();
