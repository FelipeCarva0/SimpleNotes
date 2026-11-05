import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'widgets/lock_on_background.dart';
import 'widgets/lost_capture_gate.dart';
import 'widgets/share_receiver_gate.dart';

class ArquivoApp extends StatelessWidget {
  const ArquivoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Arquivo',
      // ... seu theme, locale, etc. (mantenha como está)
      home: const LockOnBackground(
        child: LostCaptureGate(child: ShareReceiverGate(child: HomeScreen())),
      ),
    );
  }
}