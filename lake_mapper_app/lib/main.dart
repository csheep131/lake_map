import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme/app_theme.dart';
import 'services/auth_service.dart';
import 'services/sync_service.dart';
import 'widgets/main_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Gespeicherte Auth-Daten laden – beide Services müssen den Token kennen
  await authService.loadSavedAuth();
  await SyncService.instance.loadDatabaseName();
  runApp(
    const ProviderScope(
      child: LakeMapperApp(),
    ),
  );
}

class LakeMapperApp extends StatelessWidget {
  const LakeMapperApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wammsee App',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const MainShell(),
    );
  }
}
