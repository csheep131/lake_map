/**
 * Leaflet + protomaps-leaflet CDN Loader für Flutter Web
 *
 * Ersetzt MapLibre GL JS (WebGL-abhängig) durch Leaflet (Canvas2D).
 * protomaps-leaflet rendert PMTiles Vektor-Tiles ohne WebGL.
 */

(function() {
  'use strict';

  // CDN URLs
  var LEAFLET_JS = 'https://unpkg.com/leaflet@1.9.4/dist/leaflet.js';
  var LEAFLET_CSS = 'https://unpkg.com/leaflet@1.9.4/dist/leaflet.css';
  var PMTILES_CDN = 'https://unpkg.com/pmtiles@3.0.6/dist/pmtiles.js';
  var PROTOMAPS_LEAFLET_CDN = 'https://unpkg.com/protomaps-leaflet@4.0.1/dist/protomaps-leaflet.js';

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
    console.log('Map Loader: Starte (Leaflet + protomaps-leaflet)...');

    try {
      // CSS zuerst
      await loadCSS(LEAFLET_CSS);
      console.log('Leaflet CSS geladen');

      // Leaflet laden
      await loadScript(LEAFLET_JS);
      console.log('Leaflet JS geladen');

      // PMTiles + protomaps-leaflet parallel
      await loadScript(PMTILES_CDN);
      console.log('PMTiles JS geladen');

      await loadScript(PROTOMAPS_LEAFLET_CDN);
      console.log('protomaps-leaflet JS geladen');

      console.log('Map Loader: Fertig (kein WebGL benötigt)');
      window._maplibreResolve();

    } catch (e) {
      console.error('Map Loader Fehler:', e);
      window._maplibreReject(e);
    }
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', loadAll);
  } else {
    loadAll();
  }

})();
