// Stub für MapScreenWeb auf Native-Plattformen
// Diese Klasse wird nur importiert, wenn NICHT auf Web

import 'package:flutter/material.dart';

/// Stub-Version von MapScreenWeb für Native-Plattformen
/// Diese sollte nie tatsächlich gerendert werden, da wir auf Native
/// die normale MapScreen verwenden.
class MapScreenWeb extends StatelessWidget {
  const MapScreenWeb({super.key});

  @override
  Widget build(BuildContext context) {
    // Sollte nie angezeigt werden
    return const Scaffold(
      body: Center(
        child: Text('MapScreenWeb nur auf Web verfuegbar'),
      ),
    );
  }
}
