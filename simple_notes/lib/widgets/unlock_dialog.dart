import 'package:flutter/material.dart';

/// Sprint 8 — diálogo de senha com contrato **rico** (não só a string).
///
/// Motivo: o usuário pode querer trocar para biometria ou configurá-la
/// sem cancelar o fluxo. Devolver só `String?` obrigaria o chamador a
/// adivinhar. Com o `sealed` abaixo, o `runUnlockFlow` sabe exatamente
/// o que fazer.
///
/// Regras:
/// - "Desbloquear com biometria" aparece se `hasBiometricEnrollment`.
/// - "Configurar biometria nesta conversa" aparece se
///   `biometricAvailable && !hasBiometricEnrollment && allowSetupBiometric`.
/// - Os dois **não** coexistem (uma conversa ou tem ou não tem enrolamento).
sealed class PasswordUnlockResult {
  const PasswordUnlockResult();
}

class PasswordUnlockResultPassword extends PasswordUnlockResult {
  final String password;
  const PasswordUnlockResultPassword(this.password);
}

class PasswordUnlockResultUseBiometric extends PasswordUnlockResult {
  const PasswordUnlockResultUseBiometric();
}

class PasswordUnlockResultSetupBiometric extends PasswordUnlockResult {
  final String password;
  const PasswordUnlockResultSetupBiometric(this.password);
}

Future<PasswordUnlockResult?> showPasswordUnlockDialog(
  BuildContext context, {
  required String conversationTitle,
  bool hasBiometricEnrollment = false,
  bool biometricAvailable = false,
  bool allowSetupBiometric = true,
}) {
  return showDialog<PasswordUnlockResult>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _PasswordUnlockDialog(
      conversationTitle: conversationTitle,
      hasBiometricEnrollment: hasBiometricEnrollment,
      biometricAvailable: biometricAvailable,
      allowSetupBiometric: allowSetupBiometric,
    ),
  );
}

class _PasswordUnlockDialog extends StatefulWidget {
  final String conversationTitle;
  final bool hasBiometricEnrollment;
  final bool biometricAvailable;
  final bool allowSetupBiometric;

  const _PasswordUnlockDialog({
    required this.conversationTitle,
    required this.hasBiometricEnrollment,
    required this.biometricAvailable,
    required this.allowSetupBiometric,
  });

  @override
  State<_PasswordUnlockDialog> createState() => _PasswordUnlockDialogState();
}

class _PasswordUnlockDialogState extends State<_PasswordUnlockDialog> {
  final _controller = TextEditingController();
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text;
    if (value.isEmpty) {
      setState(() => _error = 'Digite a senha.');
      return;
    }
    Navigator.pop(context, PasswordUnlockResultPassword(value));
  }

  void _useBiometric() {
    Navigator.pop(context, const PasswordUnlockResultUseBiometric());
  }

  void _setupBiometric() {
    final value = _controller.text;
    if (value.isEmpty) {
      setState(() => _error = 'Digite a senha para ativar a biometria.');
      return;
    }
    Navigator.pop(context, PasswordUnlockResultSetupBiometric(value));
  }

  bool get _showBiometricLink => widget.hasBiometricEnrollment;
  bool get _showSetupLink =>
      !widget.hasBiometricEnrollment &&
      widget.biometricAvailable &&
      widget.allowSetupBiometric;

  @override
  Widget build(BuildContext context) {
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
          const Text('Esta conversa está protegida por senha.'),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            obscureText: _obscure,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: 'Senha',
              border: const OutlineInputBorder(),
              errorText: _error,
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _obscure = !_obscure),
                tooltip: _obscure ? 'Mostrar senha' : 'Ocultar senha',
              ),
            ),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            onSubmitted: (_) => _submit(),
          ),
          if (_showBiometricLink || _showSetupLink) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 4),
            if (_showBiometricLink)
              TextButton.icon(
                icon: const Icon(Icons.fingerprint),
                label: const Text('Desbloquear com biometria'),
                onPressed: _useBiometric,
              ),
            if (_showSetupLink)
              TextButton.icon(
                icon: const Icon(Icons.fingerprint),
                label: const Text('Configurar biometria nesta conversa'),
                onPressed: _setupBiometric,
              ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Desbloquear'),
        ),
      ],
    );
  }
}