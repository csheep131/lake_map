import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const LakeMapperApp());
}

class LakeMapperApp extends StatelessWidget {
  const LakeMapperApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lake Mapper',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}