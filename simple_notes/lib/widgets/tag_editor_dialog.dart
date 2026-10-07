import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/tag.dart';
import '../providers/tag_providers.dart';
import '../repositories/tag_repository.dart';
import '../utils/tag_colors.dart';

/// Cria uma Tag (nome + cor da paleta). Se o nome normalizado já existir,
/// devolve a Tag existente. Retorna null se o usuário cancelar.
Future<Tag?> showCreateTagDialog(
  BuildContext context,
  WidgetRef ref,
  String conversationId,
) async {
  final repo = ref.read(tagRepositoryProvider);
  Tag? created;

  final saved = await showDialog<bool>(
    context: context,
    builder: (_) => _TagEditorDialog(
      title: 'Nova tag',
      onSave: (nome, cor) async {
        try {
          created = await repo.createOrGet(
            conversationId: conversationId,
            nome: nome,
            cor: cor,
          );
          return null;
        } on ArgumentError catch (e) {
          return '${e.message}';
        } on StateError catch (e) {
          return e.message;
        }
      },
    ),
  );

  return saved == true ? created : null;
}
/// Edita nome e/ou cor de uma Tag, valendo para TODAS as mensagens que a
/// usam. Retorna true se salvou.
Future<bool> showEditTagDialog(
  BuildContext context,
  WidgetRef ref,
  Tag tag,
) async {
  final repo = ref.read(tagRepositoryProvider);

  final saved = await showDialog<bool>(
    context: context,
    builder: (_) => _TagEditorDialog(
      title: 'Configurar tag',
      initial: tag,
      helper: 'A alteração vale para todas as mensagens desta conversa com esta tag.',
      onSave: (nome, cor) async {
        try {
          await repo.update(tag.id, nome: nome, cor: cor);
          return null;
        } on DuplicateTagNameException catch (e) {
          return e.toString();
        } on ArgumentError catch (e) {
          return '${e.message}';
        } on StateError catch (e) {
          return e.message;
        }
      },
    ),
  );

  return saved == true;
}

class _TagEditorDialog extends StatefulWidget {
  final String title;
  final Tag? initial;
  final String? helper;

  /// Devolve o texto do erro (o diálogo continua aberto) ou null se salvou.
  final Future<String?> Function(String nome, String cor) onSave;

  const _TagEditorDialog({
    required this.title,
    required this.onSave,
    this.initial,
    this.helper,
  });

  @override
  State<_TagEditorDialog> createState() => _TagEditorDialogState();
}

class _TagEditorDialogState extends State<_TagEditorDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial?.nome ?? '');
  late String _cor = widget.initial?.cor ?? kTagPalette.first;
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final nome = TagRepository.normalizeName(_controller.text);
    if (nome.isEmpty) {
      setState(() => _error = 'Informe um nome.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    String? error;
    try {
      error = await widget.onSave(nome, _cor);
    } catch (e) {
      debugPrint('Erro ao salvar tag: $e');
      error = 'Não foi possível salvar a tag.';
    }
    if (!mounted) return;

    if (error != null) {
      setState(() {
        _saving = false;
        _error = error;
      });
      return;
    }
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              enabled: !_saving,
              maxLength: 30,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: 'Nome',
                helperText: widget.helper ?? 'Salvo em maiúsculas',
                helperMaxLines: 2,
                errorText: _error,
                counterText: '',
              ),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 16),
            Text('Cor', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final hex in kTagPalette)
                  _ColorDot(
                    hex: hex,
                    selected: hex == _cor,
                    onTap: _saving ? null : () => setState(() => _cor = hex),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}

class _ColorDot extends StatelessWidget {
  final String hex;
  final bool selected;
  final VoidCallback? onTap;

  const _ColorDot({required this.hex, required this.selected, this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = tagColorFromHex(hex);
    final onColor =
        ThemeData.estimateBrightnessForColor(color) == Brightness.dark
            ? Colors.white
            : Colors.black87;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: selected
              ? Border.all(
                  width: 3,
                  color: Theme.of(context).colorScheme.onSurface,
                )
              : null,
        ),
        child: selected ? Icon(Icons.check, size: 20, color: onColor) : null,
      ),
    );
  }
}