{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({
  config: {
    canvasKitVariant: "auto",
  },
  // Service Worker deaktiviert: Der Node.js Proxy gibt bei ?v=... Query-Strings
  // HTML zurück statt JS → SecurityError (MIME type 'text/html')
});
