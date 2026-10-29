import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_notes/security/password_crypto.dart';

void main() {
  group('PasswordCrypto.deriveKey', () {
    test('é determinística para a mesma senha e salt', () async {
      final salt = PasswordCrypto.newSaltBase64();
      final k1 = await PasswordCrypto.deriveKey(password: 'senha', saltBase64: salt);
      final k2 = await PasswordCrypto.deriveKey(password: 'senha', saltBase64: salt);
      expect(k1, equals(k2));
      expect(k1.length, 32);
    });

    test('muda com salt diferente', () async {
      final s1 = PasswordCrypto.newSaltBase64();
      final s2 = PasswordCrypto.newSaltBase64();
      final k1 = await PasswordCrypto.deriveKey(password: 'senha', saltBase64: s1);
      final k2 = await PasswordCrypto.deriveKey(password: 'senha', saltBase64: s2);
      expect(k1, isNot(equals(k2)));
    });

    test('muda com senha diferente', () async {
      final salt = PasswordCrypto.newSaltBase64();
      final k1 = await PasswordCrypto.deriveKey(password: 'a', saltBase64: salt);
      final k2 = await PasswordCrypto.deriveKey(password: 'b', saltBase64: salt);
      expect(k1, isNot(equals(k2)));
    });
  });

  group('PasswordCrypto.hashKey', () {
    test('é estável', () async {
      final h1 = await PasswordCrypto.hashKey(List.filled(32, 7));
      final h2 = await PasswordCrypto.hashKey(List.filled(32, 7));
      expect(h1, h2);
      expect(h1.length, 64); // sha256 em hex
    });
  });

  group('PasswordCrypto.constantTimeEquals', () {
    test('true quando iguais; false caso contrário', () {
      expect(PasswordCrypto.constantTimeEquals('abc', 'abc'), isTrue);
      expect(PasswordCrypto.constantTimeEquals('abc', 'abd'), isFalse);
      expect(PasswordCrypto.constantTimeEquals('abc', 'ab'), isFalse);
    });
  });

  group('AES-GCM por campo', () {
    test('ida-e-volta com a chave correta', () async {
      final key = List<int>.generate(32, (i) => i);
      final payload = await PasswordCrypto.encryptField('olá, mundo ção', key);
      expect(PasswordCrypto.looksEncrypted(payload), isTrue);

      final back = await PasswordCrypto.decryptField(payload, key);
      expect(back, 'olá, mundo ção');
    });

    test('nonces diferentes geram payloads diferentes', () async {
      final key = List<int>.generate(32, (i) => i);
      final a = await PasswordCrypto.encryptField('x', key);
      final b = await PasswordCrypto.encryptField('x', key);
      expect(a, isNot(equals(b)));
    });

    test('chave errada falha', () async {
      final k1 = List<int>.generate(32, (i) => i);
      final k2 = List<int>.generate(32, (i) => i + 1);
      final payload = await PasswordCrypto.encryptField('segredo', k1);
      expect(
        () => PasswordCrypto.decryptField(payload, k2),
        throwsA(anything),
      );
    });

    test('payload corrompido falha', () async {
      final key = List<int>.generate(32, (i) => i);
      expect(
        () => PasswordCrypto.decryptField(base64Encode([1, 2, 3]), key),
        throwsA(isA<FormatException>()),
      );
    });
  });
}