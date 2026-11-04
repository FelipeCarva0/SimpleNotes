import 'dart:async';
import 'package:flutter/widgets.dart';

/// Sprint 7 (7.1d) — escudo de auto-bloqueio com janela de graça.
///
/// Problema: os plugins de picker/câmera/galeria/gravador e a share sheet
/// colocam o app em `AppLifecycleState.paused`. O `LockOnBackground` (Z1)
/// re-bloqueia a conversa imediatamente, **no meio da ação** — o usuário
/// perde o desbloqueio enquanto escolhe a foto. O `AppLockShield` arma um
/// contador que diz ao `LockOnBackground`/`ChatScreen`: "estou no meio de
/// uma ação legítima; ignore o `paused` até eu terminar".
///
/// Comportamento:
/// - [run] incrementa [armed] antes e decrementa no `finally` (reentrante,
///   suporta chamadas aninhadas).
/// - Enquanto [armed] > 0, `LockOnBackground` e `ChatScreen` **não** devem
///   limpar as chaves/conteúdo ao irem para `paused`.
/// - **Desarme no `resumed`**: alguns plugins (ex.: `share_plus`) retornam
///   do `Future` **antes** do `paused` chegar. Se desarmássemos só no
///   `finally`, o `paused` que chega depois encontraria o escudo já em 0.
///   Por isso, quando [armed] vai a 0, o escudo espera o próximo
///   `resumed` e só aí considera a ação encerrada.
/// - **Janela de graça (2 min)**: se o app ficar em `paused` com o escudo
///   armado por mais de 2 minutos (usuário abriu outro app e ficou lá),
///   [onGraceExpired] é chamado para forçar `lockAll()` — não deixa uma
///   conversa protegida desbloqueada indefinidamente em segundo plano.
///
/// O escudo **não** faz locking sozinho; ele apenas informa. Quem chama
/// `repo.lockAll()` continua sendo o `LockOnBackground` (e o próprio
/// `ChatScreen` ao voltar do background).
class AppLockShield with WidgetsBindingObserver {
  /// Duração máxima em `paused` com o escudo armado antes de forçar bloqueio.
  static const Duration graceWindow = Duration(minutes: 2);

  int _armedCount = 0;

  /// True se há pelo menos uma ação legítima em andamento (picker, share,
  /// câmera, gravador). Consumidores devem checar isto antes de bloquear
  /// no `paused`.
  bool get armed => _armedCount > 0;

  /// Contador bruto, para debug e testes.
  int get armedCount => _armedCount;

  /// Chamado quando a janela de graça expira (app em `paused` com o
  /// escudo armado por mais de [graceWindow]). O consumidor deve registrar
  /// um callback que chame `repo.lockAll()`.
  VoidCallback? onGraceExpired;

  Timer? _graceTimer;
  bool _waitingForResume = false;
  bool _observing = false;

  /// Executa [action] com o escudo armado. O escudo cai (contador chega a
  /// 0) no `finally`, mas a "ação encerrada" só é confirmada no próximo
  /// [didChangeAppLifecycleState] com `resumed` — cobrindo plugins cujo
  /// `Future` retorna antes do `paused`.
  ///
  /// Reentrante: chamadas aninhadas incrementam/decrementam o contador.
  Future<T> run<T>(Future<T> Function() action) async {
    _ensureObserving();
    _armedCount++;
    try {
      return await action();
    } finally {
      _armedCount--;
      if (_armedCount <= 0) {
        _armedCount = 0;
        // Ação principal terminou. O `resumed` virá em seguida (picker,
        // share, câmera). Marcamos para desarmar de vez quando ele chegar.
        _waitingForResume = true;
      }
    }
  }

  void _ensureObserving() {
    if (_observing) return;
    _observing = true;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        // App foi para segundo plano com ação em andamento. Arma o timer
        // de graça. Se a ação terminar (resumed) antes, o timer é
        // cancelado abaixo.
        if (armed) {
          _graceTimer?.cancel();
          _graceTimer = Timer(graceWindow, () {
            if (!armed) return; // corrida: resumed já cancelou
            _graceTimer = null;
            _waitingForResume = false;
            _armedCount = 0;
            onGraceExpired?.call();
          });
        }
      case AppLifecycleState.resumed:
        // Chegou o `resumed`: se estávamos esperando, a ação terminou.
        _graceTimer?.cancel();
        _graceTimer = null;
        _waitingForResume = false;
        // Se ainda há contadores pendentes (run() em execução), respeita.
        // Se não, o escudo está de fato desarmado.
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        // `inactive` é transitório (notificação puxando painel) — não
        // mexe no escudo. `detached` é raro; o `LockOnBackground` já trata.
        break;
    }
  }

  /// True se o escudo está armado OU se já terminou e está aguardando o
  /// próximo `resumed` para desarmar de vez. Consumidores como o
  /// `LockOnBackground` devem usar isto: só bloqueiam se
  /// `!shield.isProtecting`.
  ///
  /// Na prática, equivale a `armed || _waitingForResume`.
  bool get isProtecting => armed || _waitingForResume;

  void dispose() {
    _graceTimer?.cancel();
    _graceTimer = null;
    if (_observing) {
      WidgetsBinding.instance.removeObserver(this);
      _observing = false;
    }
  }
}