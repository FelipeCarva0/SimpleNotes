import 'package:flutter/material.dart';

/// RF08 — pede a senha de uma conversa protegida. Devolve a senha digitada
/// (String) se o usuário confirmar, ou null se cancelar.
///
/// A verificação em si é feita pelo chamador (Home), que tem acesso ao
/// repositório. Este diálogo é puramente UI.
Future<String?> showUnlockDialog(
  BuildContext context, {
  required String conversationTitle,
}) {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _UnlockDialog(conversationTitle: conversationTitle),
  );
}

class _UnlockDialog extends StatefulWidget {
  final String conversationTitle;
  const _UnlockDialog({required this.conversationTitle});

  @override
  State<_UnlockDialog> createState() => _UnlockDialogState();
}

class _UnlockDialogState extends State<_UnlockDialog> {
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
    Navigator.pop(context, value);
  }

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
        crossAxisAlignment: CrossAxisAlignment.start,
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