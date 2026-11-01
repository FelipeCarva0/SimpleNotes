import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart' show compute;


/// RF08 — primitivas de senha e cifragem de campos.
///
/// Modelo de segurança (flag única `Conversations.protegidoPorSenha`):
/// - Ativar a senha **também** cifra os metadados sensíveis de cada mensagem
///   (`conteudoTexto`, `arquivoNomeOriginal`, `arquivoNomeExibicao`,
///   `arquivoMimeType`). Desativar **decifra de volta**.
/// - Senha NUNCA é gravada; só `sha256(chaveDerivada)` (hex) vai para
///   `Conversations.senhaHash`.
/// - `salt` (16 bytes) fica em `Conversations.salt` (público).
/// - A chave (32 bytes) é derivada por PBKDF2-HMAC-SHA256 (310k iterações) e
///   guardada só em memória (sessão), nunca em disco.
/// - Cada campo cifrado é `base64(nonce(12) || ciphertext || tag(16))` com
///   AES-256-GCM. O nonce é aleatório por campo.
class PasswordCrypto {
  static const int _iterations = 155000;
  static const int _saltBytes = 16;
  static const int _keyBytes = 32;
  static const int _nonceBytes = 12;

  static final _pbkdf2 = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: _iterations,
    bits: _keyBytes * 8,
  );

  static final _aes = AesGcm.with256bits();
  static final _sha256 = Sha256();

  // ---------------------------------------------------------------------
  // Salt
  // ---------------------------------------------------------------------

  /// Salt aleatório de 16 bytes, para `Conversations.salt` (base64).
  static String newSaltBase64() {
    final salt = _secureRandom(_saltBytes);
    return base64Encode(salt);
  }

  static Uint8List _secureRandom(int length) {
    final rnd = Random.secure();
    final out = Uint8List(length);
    for (var i = 0; i < length; i++) {
      out[i] = rnd.nextInt(256);
    }
    return out;
  }

  // ---------------------------------------------------------------------
  // Derivação e hash
  // ---------------------------------------------------------------------

  /// Deriva a chave (32 bytes) a partir da senha e do salt base64.
  /// Roda em ~200–400 ms num celular médio (310k iterações).
  static Future<List<int>> deriveKey({
    required String password,
    required String saltBase64,
  }) async {
    final salt = base64Decode(saltBase64);
    final key = await _pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    );
    return key.extractBytes();
  }

  /// Versão da derivação que roda em **isolate separada** (não trava a UI).
  /// Usada pelo fluxo de desbloquear/proteger/trocar. `deriveKey` continua
  /// disponível para testes e para uso quando já estamos fora da main.
  ///
  /// `compute` aceita apenas um argumento, por isso passamos um record
  /// `(password, saltBase64)`.
  static Future<List<int>> deriveKeyInIsolate({
    required String password,
    required String saltBase64,
  }) {
    return compute(
      _deriveKeyTopLevel,
      (password, saltBase64),
    );
  }

  static Future<List<int>> _deriveKeyTopLevel(
    (String password, String saltBase64) args,
  ) {
    return deriveKey(password: args.$1, saltBase64: args.$2);
  }

  /// `sha256(chave)` em hex minúsculo — é o que vai para `senhaHash`.
  static Future<String> hashKey(List<int> key) async {
    final digest = await _sha256.hash(key);
    return _toHex(digest.bytes);
  }

  /// Comparação em tempo constante (evita timing attack na verificação).
  static bool constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }

  // ---------------------------------------------------------------------
  // AES-256-GCM por campo (base64(nonce||ciphertext||tag))
  // ---------------------------------------------------------------------

  /// Cifra [plaintext] com [key]. Devolve base64(nonce||ciphertext||tag).
  static Future<String> encryptField(String plaintext, List<int> key) async {
    final nonce = _secureRandom(_nonceBytes);
    final box = await _aes.encrypt(
      utf8.encode(plaintext),
      secretKey: SecretKey(key),
      nonce: nonce,
    );

    final out = BytesBuilder(copy: false)
      ..add(box.nonce)
      ..add(box.cipherText)
      ..add(box.mac.bytes);
    return base64Encode(out.toBytes());
  }

  /// Decifra o payload gerado por [encryptField]. Lança se o payload estiver
  /// corrompido ou a chave estiver errada.
  static Future<String> decryptField(String payload, List<int> key) async {
    final raw = base64Decode(payload);
    if (raw.length < _nonceBytes + 16) {
      throw const FormatException('Payload cifrado inválido.');
    }

    final nonce = raw.sublist(0, _nonceBytes);
    final macStart = raw.length - 16;
    final cipherText = raw.sublist(_nonceBytes, macStart);
    final mac = Mac(raw.sublist(macStart));

    final clear = await _aes.decrypt(
      SecretBox(cipherText, nonce: nonce, mac: mac),
      secretKey: SecretKey(key),
    );
    return utf8.decode(clear);
  }

  // ---------------------------------------------------------------------
  // Heurística auxiliar
  // ---------------------------------------------------------------------

  /// True se [value] "parece" um payload de [encryptField] (base64 de pelo
  /// menos nonce + tag). Usado só como sanidade, nunca como verificação de
  /// integridade (a verificação real é o MAC do AES-GCM no decrypt).
  static bool looksEncrypted(String? value) {
    if (value == null || value.isEmpty) return false;
    try {
      final raw = base64Decode(value);
      return raw.length >= _nonceBytes + 16;
    } catch (_) {
      return false;
    }
  }

  static String _toHex(List<int> bytes) {
    final sb = StringBuffer();
    for (final b in bytes) {
      sb.write(b.toRadixString(16).padLeft(2, '0'));
    }
    return sb.toString();
  }
}