import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/conversation_providers.dart';

/// 6.11 (Z1) — re-bloqueio em background.
///
/// Em `AppLifecycleState.paused`, limpa as chaves de sessão do repositório
/// (`lockAll()`), forçando que conversas protegidas peçam senha de novo ao
/// voltar para o primeiro plano. Nenhum dado é apagado; apenas a chave
/// derivada em memória deixa de existir.
///
/// Envolva o `home` do `MaterialApp` (ver `app.dart`). Não confundir com
/// `LostCaptureGate` — os dois coexistem: `LockOnBackground` observa o
/// ciclo de vida; `LostCaptureGate` recupera captura interrompida.
class LockOnBackground extends ConsumerStatefulWidget {
  final Widget child;
  const LockOnBackground({super.key, required this.child});

  @override
  ConsumerState<LockOnBackground> createState() => _LockOnBackgroundState();
}

class _LockOnBackgroundState extends ConsumerState<LockOnBackground>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // `paused` é o estado em que o app fica quando o usuário sai (home,
    // multitarefa, troca de app). `inactive` é transitório (ex.: notificação
    // puxando o painel), então NÃO limpamos nele — evita bloquear a cada
    // pequena interrupção. `detached` é raro; `lockAll` idempotente.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      ref.read(conversationRepositoryProvider).lockAll();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}