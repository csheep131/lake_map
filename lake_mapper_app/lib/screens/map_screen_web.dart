import 'dart:async';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'dart:js' as js;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// MapScreen für Flutter Web — bettet Leaflet-Karte direkt als DOM-Element ein.
class MapScreenWeb extends StatefulWidget {
  const MapScreenWeb({super.key});

  @override
  State<MapScreenWeb> createState() => _MapScreenWebState();
}

class _MapScreenWebState extends State<MapScreenWeb> {
  static const _viewType = 'wammsee-map-div';
  static bool _registered = false;
  bool _mapReady = false;

  @override
  void initState() {
    super.initState();
    _registerViewFactory();
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) setState(() => _mapReady = true);
    });
  }

  void _registerViewFactory() {
    if (_registered) return;
    _registered = true;

    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final divId = 'wammsee-map-$viewId';
      final div = html.DivElement()
        ..id = divId
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.position = 'relative';

      // Map nach kurzer Verzögerung initialisieren (wenn div im DOM ist)
      Future.delayed(const Duration(milliseconds: 300), () {
        if (js.context.hasProperty('initWammseeMap')) {
          js.context.callMethod('initWammseeMap', [div]);
        } else {
          print('Error: initWammseeMap not found on window');
        }
      });

      return div;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text(
          'Wammsee',
          style: TextStyle(
            fontFamily: 'RobotoMono',
            fontWeight: FontWeight.w700,
            fontSize: 18,
            letterSpacing: 2,
          ),
        ),
        backgroundColor: AppColors.navyDark,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: Stack(
        children: [
          const HtmlElementView(viewType: _viewType),

          if (!_mapReady)
            Container(
              color: AppColors.surface,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: AppColors.cyan),
                    SizedBox(height: 16),
                    Text(
                      'Karte wird geladen...',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontFamily: 'RobotoMono',
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
