# Performance Review Checklist

Vor jedem Release oder bei jeder Performance-Review diese Punkte abhaken:

## Flutter-Layer

- [ ] Keine roten Balken in Flutter DevTools Performance-Timeline während Scroll
- [ ] `setState` trifft nur das kleinste nötige Widget
- [ ] Alle statischen Widgets nutzen `const`
- [ ] Listen verwenden `ListView.builder` + `itemExtent`
- [ ] Bilder nutzen `CachedNetworkImage` oder `Image.asset` mit korrekter Auflösung
- [ ] Keine synchronen Operationen in `build()` oder `initState()`
- [ ] Startup-Zeit < 1.5 Sekunden (cold start)

## Android-Layer

- [ ] Keine StrictMode-Violations im Debug-Build
- [ ] Keine Memory-Leaks (Profiler: Heap-Dump vor/nach User-Flow)
- [ ] Keine Wakelocks ohne Timeout
- [ ] Background-Work läuft über WorkManager
- [ ] APK-Size minimiert (ProGuard, Resource-Shrinking, AAB)
- [ ] Kein roter Overdraw im GPU-Debug-Overlay

## Messung

- [ ] Durchschnittliche Frame-Time dokumentiert
- [ ] Memory-Peak dokumentiert
- [ ] Startup-Zeit dokumentiert
- [ ] Battery-Impact dokumentiert (Profiler > Energy)
