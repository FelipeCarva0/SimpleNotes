import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'screens/home_screen.dart';
import 'widgets/lost_capture_gate.dart';
import 'widgets/lock_on_background.dart';

class ArquivoApp extends StatelessWidget {
  const ArquivoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Arquivo',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: LockOnBackground(child: LostCaptureGate(child: HomeScreen())),
    );
  }
}
