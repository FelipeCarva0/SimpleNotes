import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'widgets/lost_capture_gate.dart';

class ArquivoApp extends StatelessWidget {
  const ArquivoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Arquivo',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
      home: const LostCaptureGate(child: HomeScreen()),
    );
  }
}