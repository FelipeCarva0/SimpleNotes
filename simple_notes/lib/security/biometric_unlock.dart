import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

import 'biometric_storage_keys.dart';
/// Sprint 8 — porta biométrica para conversas protegidas por senha.
///
/// Modelo (Estratégia A):
/// - A chave derivada por senha (32 bytes) **já existe** em memória quando
///   o usuário ativa a biometria. Guardamos essa chave embrulhada no
///   secure storage do sistema (Keystore/Keychain), protegida pela
///   biometria.
/// - Desbloquear = autenticar biometria + ler a chave + devolver para o
///   repositório colocar em `_unlockedKeys` (via `unlockWithKey`).
/// - A **senha continua funcionando**. A biometria é uma segunda porta.
/// - Nenhuma mudança em schema, `senhaHash`, `salt`, `protegidoPorSenha`
///   ou no fluxo de cifragem (`_encodeForStorage`).
///
/// Cancelamento/falha de biometria **não** é exceção: devolve `null`/`false`
/// para o chamador cair no diálogo de senha.
class BiometricUnlock {
  final LocalAuthentication _auth;
  final FlutterSecureStorage _storage;

  BiometricUnlock({LocalAuthentication? auth, FlutterSecureStorage? storage})
      : _auth = auth ?? LocalAuthentication(),
        _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  // -------------------------------------------------------------------
  // Disponibilidade
  // -------------------------------------------------------------------

  /// True se o aparelho suporta biometria e o usuário tem alguma
  /// cadastrada. **Não** autentica.
  Future<bool> isAvailable() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final deviceSupported = await _auth.isDeviceSupported();
      if (!canCheck || !deviceSupported) return false;
      final enrolled = await _auth.getAvailableBiometrics();
      return enrolled.isNotEmpty;
    } catch (e) {
      debugPrint('BiometricUnlock.isAvailable: $e');
      return false;
    }
  }

  /// True se há chave guardada para esta conversa. Leitura direta ao
  /// secure storage (não exige biometria para checar existência).
  Future<bool> hasEnrollment(String conversationId) async {
    try {
      final value =
          await _storage.read(key: BiometricStorageKeys.keyFor(conversationId));
      return value != null && value.isNotEmpty;
    } catch (e) {
      debugPrint('BiometricUnlock.hasEnrollment: $e');
      return false;
    }
  }

  // -------------------------------------------------------------------
  // Ativar / desativar
  // -------------------------------------------------------------------

  /// Ativa a biometria para a conversa. Exige autenticação biométrica
  /// **agora** (o usuário precisa provar que é ele antes de guardar a
  /// chave). [key] é a chave derivada da senha já desbloqueada.
  ///
  /// Devolve `true` se guardou, `false` se o usuário cancelou/falhou.
  Future<bool> enable({
    required String conversationId,
    required List<int> key,
  }) async {
    final ok = await _authenticate(
      reason: 'Ativar desbloqueio por biometria',
    );
    if (!ok) return false;

    try {
      await _storage.write(
        key: BiometricStorageKeys.keyFor(conversationId),
        value: base64Encode(Uint8List.fromList(key)),
      );
      await _storage.write(
        key: BiometricStorageKeys.metaFor(conversationId),
        value: '1',
      );
      return true;
    } catch (e) {
      debugPrint('BiometricUnlock.enable: $e');
      return false;
    }
  }

  /// Desativa a biometria da conversa. Só apaga o cofre paralelo; não
  /// toca em `senhaHash`/`salt`/`protegidoPorSenha` nem recifra nada.
  Future<void> disable(String conversationId) async {
    try {
      await _storage.delete(key: BiometricStorageKeys.keyFor(conversationId));
      await _storage.delete(key: BiometricStorageKeys.metaFor(conversationId));
    } catch (e) {
      debugPrint('BiometricUnlock.disable: $e');
    }
  }

  /// Apaga **todos** os enrolamentos. Útil em logout/desinstalação lógica.
  /// (O app não tem logout hoje; método preparado para o futuro.)
  Future<void> disableAll() async {
    try {
      final all = await _storage.readAll();
      for (final k in all.keys.toList()) {
        if (k.startsWith(BiometricStorageKeys.keyPrefix) ||
            k.startsWith(BiometricStorageKeys.metaPrefix)) {
          await _storage.delete(key: k);
        }
      }
    } catch (e) {
      debugPrint('BiometricUnlock.disableAll: $e');
    }
  }

  // -------------------------------------------------------------------
  // Desbloquear
  // -------------------------------------------------------------------

  /// Autentica a biometria e devolve a chave guardada (ou null).
  /// Null também cobre "sem enrolamento" e "biometria indisponível".
  Future<List<int>?> unlock({required String conversationId}) async {
    if (!await hasEnrollment(conversationId)) return null;

    final ok = await _authenticate(
      reason: 'Desbloquear conversa',
    );
    if (!ok) return null;

    try {
      final value = await _storage.read(
        key: BiometricStorageKeys.keyFor(conversationId),
      );
      if (value == null || value.isEmpty) return null;
      return base64Decode(value);
    } catch (e) {
      debugPrint('BiometricUnlock.unlock: $e');
      return null;
    }
  }

  // -------------------------------------------------------------------
  // Interno
  // -------------------------------------------------------------------

  Future<bool> _authenticate({required String reason}) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
    } on PlatformException catch (e) {
      // Códigos comuns: notEnrolled, notAvailable, lockedOut, permanentlyLockedOut.
      debugPrint(
        'BiometricUnlock._authenticate PlatformException '
        '(${e.code}): ${e.message}',
      );
      return false;
    } catch (e) {
      debugPrint('BiometricUnlock._authenticate: $e');
      return false;
    }
  }
}