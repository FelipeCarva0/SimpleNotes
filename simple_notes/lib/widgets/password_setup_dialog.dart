import 'package:flutter/material.dart';

/// RF08 — define uma senha nova para uma conversa (ativar a proteção).
/// Devolve a senha digitada (String) se confirmar, ou null se cancelar.
///
/// Regra mínima: 4 caracteres. O chamador é quem efetivamente chama o
/// repositório (`protectConversation`).
Future<String?> showPasswordSetupDialog(
  BuildContext context, {
  required String conversationTitle,
}) {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _PasswordSetupDialog(conversationTitle: conversationTitle),
  );
}

class _PasswordSetupDialog extends StatefulWidget {
  final String conversationTitle;
  const _PasswordSetupDialog({required this.conversationTitle});

  @override
  State<_PasswordSetupDialog> createState() => _PasswordSetupDialogState();
}

class _PasswordSetupDialogState extends State<_PasswordSetupDialog> {
  final _pwd = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;
  String? _error;
  bool _saving = false;

  static const _minLength = 4;

  @override
  void dispose() {
    _pwd.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _submit() {
    final a = _pwd.text;
    final b = _confirm.text;

    if (a.length < _minLength) {
      setState(() => _error = 'Use pelo menos $_minLength caracteres.');
      return;
    }
    if (a != b) {
      setState(() => _error = 'As senhas não coincidem.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    Navigator.pop(context, a);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Definir senha'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'A conversa "${widget.conversationTitle}" será protegida e '
              'seus metadados serão cifrados. Guarde a senha: não há '
              'recuperação.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _pwd,
              autofocus: true,
              obscureText: _obscure,
              enabled: !_saving,
              decoration: InputDecoration(
                labelText: 'Senha',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _obscure = !_obscure),
                  tooltip: _obscure ? 'Mostrar senha' : 'Ocultar senha',
                ),
              ),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirm,
              obscureText: _obscure,
              enabled: !_saving,
              decoration: InputDecoration(
                labelText: 'Confirmar senha',
                border: const OutlineInputBorder(),
                errorText: _error,
              ),
              onSubmitted: (_) => _submit(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: const Text('Definir'),
        ),
      ],
    );
  }
}