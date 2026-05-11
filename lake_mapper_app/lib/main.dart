import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'theme/app_theme.dart';
import 'services/auth_service.dart';
import 'widgets/main_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  await authService.loadSavedAuth();
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
