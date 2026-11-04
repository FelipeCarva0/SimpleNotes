import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../security/app_lock_shield.dart';

/// Sprint 7 (7.1d) — instância única (por `ProviderScope`) do escudo de
/// auto-bloqueio. Consumida por [LockOnBackground] e [ChatScreen].
///
/// `ref.onDispose` garante que o `WidgetsBindingObserver` interno e o
/// `Timer` de graça não vazem ao fim do escopo.
final appLockShieldProvider = Provider<AppLockShield>((ref) {
  final shield = AppLockShield();
  ref.onDispose(shield.dispose);
  return shield;
});