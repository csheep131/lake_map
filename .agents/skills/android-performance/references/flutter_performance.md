# Flutter Performance

## Widget-Tree & Rebuilds

- **const-Konstruktoren**: Jede statische Widget-Instanz muss `const` sein. Das verhindert unnötige Rebuilds.
- **Keys**: Verwende `ValueKey` oder `GlobalKey`, wenn sich die Reihenfolge ändernder Listenelemente stabil halten muss. Ohne Keys werden alle Items neu gebaut.
- **Builder statt Funktionen**: Verwende `ListView.builder`, `GridView.builder` – nie `ListView(children: [...])` mit > 20 Items.
- **itemExtent / prototypeItem**: Bei `ListView` immer `itemExtent` oder `prototypeItem` setzen. Das spart Layout-Berechnungen.

## State Management

- **setState-Granularität**: `setState` sollte nur das kleinste Widget treffen, das sich ändert. Nie in einem Parent-Widget `setState` rufen, wenn nur ein Child sich ändert.
- **StatefulBuilder / AnimatedBuilder**: Für isolierte Animationen statt großem `setState`.
- **ValueNotifier / AnimationController**: Für einzelne Werte effizienter als StreamBuilder oder setState.

## Bilder & Assets

- **resizeToAvoidBottomInset**: Bei `Scaffold` deaktivieren, wenn nicht nötig – verhindert Layout-Recalculations.
- **CachedNetworkImage**: Nie `Image.network` direkt. Caching ist Pflicht.
- **Resize & Compression**: Bilder vor dem Bundle auf Zielauflösung skalieren. Ein 4000x3000-Bild auf einem 1080p-Screen ist Verschwendung.
- **Fade-In**: Bilder sollten mit Placeholder oder Fade-In laden, nie abrupt auftauchen.

## Animationen

- **Opacity vs Visibility**: `AnimatedOpacity` ist teuer (erzwingt Repaint). Besser: `AnimatedSwitcher` oder direktes `Visibility`-Toggling ohne Animation.
- **Clip-Operationen**: `ClipRRect`, `ClipPath` sind teuer. Vermeiden in Scroll-Views oder Animationen.
- **ShaderMask / ColorFilter**: Nur wenn nötig. Jeder Pixel muss neu berechnet werden.

## Daten & Async

- **compute()**: Jede Operation > 5 ms auf dem Main-Thread gehört in einen `compute`-Isolate.
- **FutureBuilder**: Nie verschachtelt. Cachen des Futures außerhalb des Builds.
- **Pagination**: Listen > 100 Items müssen paginiert laden. Nie alles auf einmal.

## Startup-Optimierung

- **synchronous work minimieren**: `main()` sollte so wenig wie möglich tun. Services lazy initialisieren.
- **SplashScreen**: Native Splash-Screen anzeigen, während Flutter initialisiert. Keinen leeren weißen Screen.
- **Deferred Components**: Große Assets oder Features als deferred imports laden (Android App Bundle).
