import 'package:flutter/material.dart';

/// Sprint 8 — diálogo de desbloqueio por biometria. Dispara o sensor
/// nativo **automaticamente** ao abrir (via `initState` + postFrame) e
/// mantém "Tentar novamente" e "Usar senha" disponíveis.
///
/// **Não** verifica a senha nem toca no repositório. Quem faz isso é o
/// `runUnlockFlow`; aqui só apresentamos estados e devolvemos a escolha.
enum BiometricDialogResult { success, usePassword, cancelled }

Future<BiometricDialogResult?> showBiometricUnlockDialog(
  BuildContext context, {
  required String conversationTitle,
  required Future<bool> Function() onTryBiometric,
}) {
  return showDialog<BiometricDialogResult>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _BiometricUnlockDialog(
      conversationTitle: conversationTitle,
      onTryBiometric: onTryBiometric,
    ),
  );
}

class _BiometricUnlockDialog extends StatefulWidget {
  final String conversationTitle;
  final Future<bool> Function() onTryBiometric;

  const _BiometricUnlockDialog({
    required this.conversationTitle,
    required this.onTryBiometric,
  });

  @override
  State<_BiometricUnlockDialog> createState() => _BiometricUnlockDialogState();
}

class _BiometricUnlockDialogState extends State<_BiometricUnlockDialog> {
  bool _busy = false;
  bool _attempted = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Dispara o sensor nativo no primeiro frame. `local_auth` abre uma
    // activity por cima do Flutter; não depende do `context` estar pronto
    // para `showDialog`, só de estarmos montados.
    WidgetsBinding.instance.addPostFrameCallback((_) => _try());
  }

  Future<void> _try() async {
    if (!mounted || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await widget.onTryBiometric();
    if (!mounted) return;
    if (ok) {
      // Fecha devolvendo sucesso. O chamador (`runUnlockFlow`) já viu a
      // chave na sessão porque `onTryBiometric` chamou `unlockWithKey`
      // antes de retornar `true`.
      Navigator.pop(context, BiometricDialogResult.success);
      return;
    }
    setState(() {
      _busy = false;
      _attempted = true;
      _error = 'Não reconhecido. Tente novamente ou use a senha.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.lock_outline),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.conversationTitle,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 4),
          Icon(
            Icons.fingerprint,
            size: 64,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 8),
          Text(
            _busy
                ? 'Aguardando a digital…'
                : 'Toque no sensor de digital para desbloquear.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy
              ? null
              : () =>
                  Navigator.pop(context, BiometricDialogResult.cancelled),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: _busy
              ? null
              : () =>
                  Navigator.pop(context, BiometricDialogResult.usePassword),
          child: const Text('Usar senha'),
        ),
        FilledButton(
          // Antes da primeira tentativa, o botão "Tentar" fica escondido
          // (o sensor nativo já vai abrir sozinho). Depois de uma falha,
          // fica disponível.
          onPressed: (!_attempted || _busy) ? null : _try,
          child: const Text('Tentar novamente'),
        ),
      ],
    );
  }
}