/// Chaves usadas no `flutter_secure_storage` pela biometria.
/// Separado do `BiometricUnlock` para facilitar busca e testes.
class BiometricStorageKeys {
  /// Prefixo do item que guarda a chave da conversa (base64).
  /// Item: `biometric_key__<conversationId>` → base64(chave de 32 bytes).
  static const String keyPrefix = 'biometric_key__';

  /// Metadado booleano que indica que a biometria foi ativada para a
  /// conversa (redundante com a existência da chave, mas explícito e
  /// útil para debug/inspeção no secure storage).
  static const String metaPrefix = 'biometric_meta__';

  static String keyFor(String conversationId) => '$keyPrefix$conversationId';
  static String metaFor(String conversationId) => '$metaPrefix$conversationId';
}