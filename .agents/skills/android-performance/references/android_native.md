# Android Native Performance

## Main Thread (UI Thread)

- **StrictMode**: Im Debug-Build aktivieren. Flaggt disk- und network-I/O auf dem Main-Thread.
- **AsyncTask ist tot**: Verwende Kotlin Coroutines (`Dispatchers.IO`) oder `java.util.concurrent`.
- **SharedPreferences**: `apply()` statt `commit()` – asynchron. Nie blockierend lesen.

## Memory

- **Bitmap-Pool**: Wiederverwende `Bitmap`-Objekte. Jede Dekodierung allokiert Heap-Memory.
- **LargeHeap**: Nur als letzter Ausweg. Besser: Weniger Allokationen.
- **WeakReferences**: Für Caches verwenden. Memory darf jederzeit freigegeben werden.
- **Memory Leaks**: Activities/Fragments nie in statischen Referenzen halten.

## Battery & Background

- **WorkManager**: Alle Hintergrundarbeiten über WorkManager. Nie direkte Services.
- **Doze Mode**: App muss korrekt im Doze-Mode funktionieren. Keine unnötigen Netzwerk-Requests im Hintergrund.
- **Location-Updates**: Nie `PRIORITY_HIGH_ACCURACY` im Hintergrund. Balanced Power Mode nutzen.
- **Wakelocks**: Explizit vermeiden. Wenn nötig: `WakeLock` mit Timeout und `acquire/release` in `finally`.

## Rendering

- **Hardware-Layer**: Für komplexe, statische Views `setLayerType(View.LAYER_TYPE_HARDWARE, null)` – aber nie für animierte Views.
- **Overdraw**: In Developer Options „Debug GPU Overdraw“ aktivieren. Kein roter Bereich auf dem Screen.
- **ViewStub**: Für selten sichtbare Layouts (Error-States, Empty-States) `ViewStub` nutzen.

## APK & Build

- **ProGuard / R8**: Code-Shrinking und Obfuscation aktivieren. Entfernt ungenutzten Code.
- **Android App Bundle**: Nutze AAB statt APK. Google liefert nur die nötigen Ressourcen.
- **Resource Shrinking**: `shrinkResources true` in `build.gradle`.
