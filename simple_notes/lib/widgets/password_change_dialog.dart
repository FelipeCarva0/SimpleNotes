import 'package:flutter/material.dart';

/// RF08 — troca a senha de uma conversa protegida.
/// Devolve `(oldPassword, newPassword)` se confirmar, ou null se cancelar.
/// O chamador é quem chama `changeConversationPassword` no repositório.
Future<({String oldPassword, String newPassword})?> showPasswordChangeDialog(
  BuildContext context, {
  required String conversationTitle,
}) {
  return showDialog<({String oldPassword, String newPassword})>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _PasswordChangeDialog(conversationTitle: conversationTitle),
  );
}

class _PasswordChangeDialog extends StatefulWidget {
  final String conversationTitle;
  const _PasswordChangeDialog({required this.conversationTitle});

  @override
  State<_PasswordChangeDialog> createState() => _PasswordChangeDialogState();
}

class _PasswordChangeDialogState extends State<_PasswordChangeDialog> {
  final _oldPwd = TextEditingController();
  final _newPwd = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;
  String? _error;

  static const _minLength = 4;

  @override
  void dispose() {
    _oldPwd.dispose();
    _newPwd.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _submit() {
    final oldP = _oldPwd.text;
    final newP = _newPwd.text;
    final conf = _confirm.text;

    if (oldP.isEmpty) {
      setState(() => _error = 'Informe a senha atual.');
      return;
    }
    if (newP.length < _minLength) {
      setState(() => _error = 'Nova senha: pelo menos $_minLength caracteres.');
      return;
    }
    if (newP != conf) {
      setState(() => _error = 'As senhas novas não coincidem.');
      return;
    }

    Navigator.pop(
      context,
      (oldPassword: oldP, newPassword: newP),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Trocar senha'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Conversa: "${widget.conversationTitle}"'),
            const SizedBox(height: 12),
            TextField(
              controller: _oldPwd,
              autofocus: true,
              obscureText: _obscure,
              decoration: const InputDecoration(
                labelText: 'Senha atual',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _newPwd,
              obscureText: _obscure,
              decoration: const InputDecoration(
                labelText: 'Nova senha',
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.lock_outline),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirm,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: 'Confirmar nova senha',
                border: const OutlineInputBorder(),
                errorText: _error,
                suffixIcon: IconButton(
                  icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _obscure = !_obscure),
                  tooltip: _obscure ? 'Mostrar senhas' : 'Ocultar senhas',
                ),
              ),
              onSubmitted: (_) => _submit(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Trocar'),
        ),
      ],
    );
  }
}