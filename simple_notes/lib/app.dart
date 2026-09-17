// app.dart
import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

class ArquivoApp extends StatelessWidget {
  const ArquivoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Arquivo',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
      home: const HomeScreen(),
    );
  }
}
