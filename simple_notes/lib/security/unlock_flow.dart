import 'package:flutter/material.dart';

import '../repositories/conversation_repository.dart';
import '../widgets/biometric_unlock_dialog.dart';
import '../widgets/unlock_dialog.dart';
import 'biometric_unlock.dart';

/// Sprint 8 — orquestra o fluxo de desbloqueio de uma conversa protegida,
/// unindo senha e biometria num único caminho determinístico.
///
/// Regras de UX (aprovadas):
/// - Se a conversa TEM biometria ativada, o diálogo de biometria é o
///   **primeiro** (e dispara o sensor nativo automaticamente).
/// - O diálogo de biometria oferece "Usar senha" para cair no de senha.
/// - O diálogo de senha, se a conversa TEM biometria ativada, mostra
///   "Desbloquear com biometria" no rodapé → volta para o de biometria.
/// - O diálogo de senha, se a conversa NÃO TEM biometria ativada e o
///   aparelho suporta, mostra "Configurar biometria nesta conversa" →
///   verifica a senha + ativa biometria + segue desbloqueado.
/// - Erro de senha reabre o diálogo de senha com SnackBar "Senha incorreta".
/// - **Nunca** dois diálogos empilhados: um é fechado antes do outro abrir.
///
/// Uso:
/// ```dart
/// final outcome = await runUnlockFlow(
///   context: context,
///   conversationId: c.id,
///   conversationTitle: c.titulo,
///   repo: repo, bio: bio,
/// );
/// if (outcome == UnlockOutcome.cancelled) return;
/// if (outcome == UnlockOutcome.wrongPassword) return; // já avisado
/// // abrir ChatScreen...
/// ```
enum UnlockPurpose {
  /// Abertura normal da conversa. Habilita "Configurar biometria" no
  /// rodapé do diálogo de senha (quando a conversa ainda não tem).
  openConversation,

  /// Gerenciamento de biometria a partir do menu ⋮ da Home. Desabilita
  /// "Configurar biometria" no rodapé (evita recursão) mas mantém "Usar
  /// biometria" quando já existe.
  manageBiometrics,
}

enum UnlockOutcome {
  unlockedByBiometric,
  unlockedByPassword,
  cancelled,
  wrongPassword, // já avisado por SnackBar interno; o chamador só descarta
}

enum _Step { biometric, password }

Future<UnlockOutcome> runUnlockFlow({
  required BuildContext context,
  required String conversationId,
  required String conversationTitle,
  required ConversationRepository repo,
  required BiometricUnlock bio,
  UnlockPurpose purpose = UnlockPurpose.openConversation,
}) async {
  final hasBio = await bio.hasEnrollment(conversationId);
  final bioAvailable = await bio.isAvailable();

  var step = hasBio ? _Step.biometric : _Step.password;

  while (true) {
    if (!context.mounted) return UnlockOutcome.cancelled;

    switch (step) {
      case _Step.biometric:
        final result = await showBiometricUnlockDialog(
          context,
          conversationTitle: conversationTitle,
          onTryBiometric: () async {
            final key = await bio.unlock(conversationId: conversationId);
            if (key == null) return false;
            repo.unlockWithKey(conversationId, key);
            return true;
          },
        );
        if (!context.mounted) return UnlockOutcome.cancelled;

        switch (result) {
          case BiometricDialogResult.success:
            return UnlockOutcome.unlockedByBiometric;
          case BiometricDialogResult.usePassword:
            step = _Step.password;
            continue;
          case BiometricDialogResult.cancelled:
          case null:
            return UnlockOutcome.cancelled;
        }

      case _Step.password:
        final result = await showPasswordUnlockDialog(
          context,
          conversationTitle: conversationTitle,
          hasBiometricEnrollment: hasBio,
          biometricAvailable: bioAvailable,
          allowSetupBiometric: purpose == UnlockPurpose.openConversation,
        );
        if (!context.mounted) return UnlockOutcome.cancelled;
        if (result == null) return UnlockOutcome.cancelled;

        if (result is PasswordUnlockResultUseBiometric) {
          step = _Step.biometric;
          continue;
        }

        if (result is PasswordUnlockResultSetupBiometric) {
          final key = await repo.verifyConversationPassword(
            conversationId,
            result.password,
          );
          if (!context.mounted) return UnlockOutcome.cancelled;
          if (key == null) {
            _snack(context, 'Senha incorreta.');
            // Permanece no passo de senha (diálogo reabre vazio).
            continue;
          }
          // Senha OK: tenta ativar biometria. Se o usuário cancelar a
          // digital nativa, seguimos desbloqueados pela senha (já provou).
          final enabled = await bio.enable(
            conversationId: conversationId,
            key: key,
          );
          if (!context.mounted) {
            return UnlockOutcome.unlockedByPassword;
          }
          _snack(
            context,
            enabled
                ? 'Biometria ativada nesta conversa.'
                : 'Biometria não ativada. A senha continua valendo.',
          );
          return UnlockOutcome.unlockedByPassword;
        }

        if (result is PasswordUnlockResultPassword) {
          final key = await repo.verifyConversationPassword(
            conversationId,
            result.password,
          );
          if (!context.mounted) return UnlockOutcome.cancelled;
          if (key == null) {
            _snack(context, 'Senha incorreta.');
            continue; // reabre o diálogo de senha
          }
          return UnlockOutcome.unlockedByPassword;
        }
    }
  }
}

void _snack(BuildContext context, String text) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}