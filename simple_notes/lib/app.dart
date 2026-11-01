import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dev/seed_carros.dart';
import 'providers/conversation_providers.dart';
import 'screens/home_screen.dart';
import 'widgets/lock_on_background.dart';
import 'widgets/lost_capture_gate.dart';

class ArquivoApp extends StatelessWidget {
  const ArquivoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Arquivo',
      // ... seu theme, locale, etc. (mantenha como está)
      home: const _DevSeedOnStart(
        child: LockOnBackground(
          child: LostCaptureGate(child: HomeScreen()),
        ),
      ),
    );
  }
}

/// DEV-ONLY — dispara `seedCarros()` uma única vez, após o primeiro frame.
/// Não mostra UI. Remova este widget (e o import de `seed_carros.dart`)
/// quando terminar os testes.
class _DevSeedOnStart extends ConsumerStatefulWidget {
  final Widget child;
  const _DevSeedOnStart({required this.child});

  @override
  ConsumerState<_DevSeedOnStart> createState() => _DevSeedOnStartState();
}

class _DevSeedOnStartState extends ConsumerState<_DevSeedOnStart> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final repo = ref.read(conversationRepositoryProvider);
      final db = ref.read(appDatabaseProvider);
      final sw = Stopwatch()..start();
      await seedCarros(repo: repo, db: db);
      sw.stop();
      debugPrint('seedCarros: disparado em ${sw.elapsedMilliseconds} ms');
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}