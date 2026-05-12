{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({
  renderer: "canvaskit",
  serviceWorkerSettings: {
    serviceWorkerVersion: {{flutter_service_worker_version}}
  }
});
