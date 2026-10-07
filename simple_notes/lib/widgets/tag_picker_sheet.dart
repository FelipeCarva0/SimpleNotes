import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/message.dart';
import '../models/tag.dart';
import '../providers/conversation_providers.dart';
import '../providers/tag_providers.dart';
import 'tag_chip.dart';
import 'tag_editor_dialog.dart';

/// RF04 — sheet de tag de uma Mensagem: trocar para uma tag existente,
/// criar uma nova, remover a tag, ou configurar a tag atual (global).
///
/// [onManageTags] abre a tela "Gerenciar tags" (Etapa 3.5); se null, o link
/// fica oculto.
Future<void> showTagPickerSheet(
  BuildContext context, {
  required Message message,
  VoidCallback? onManageTags,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _TagPickerSheet(
      message: message,
      onManageTags: onManageTags,
    ),
  );
}

class _TagPickerSheet extends ConsumerWidget {
  final Message message;
  final VoidCallback? onManageTags;

  const _TagPickerSheet({required this.message, this.onManageTags});

  /// Define (ou remove, com null) a tag da mensagem e fecha o sheet.
  Future<void> _assign(BuildContext context, WidgetRef ref, String? tagId) async {
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    try {
      await ref
          .read(conversationRepositoryProvider)
          .setMessageTag(message.id, tagId);
      nav.pop();
    } on StateError catch (e) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _newTag(
    BuildContext context,
    WidgetRef ref,
    List<Tag> existing,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final created = await showCreateTagDialog(context, ref, message.conversationId);
    if (created == null || !context.mounted) return;

    if (existing.any((t) => t.id == created.id)) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text('Já existia a tag "${created.nome}"; ela foi reutilizada.'),
        ));
    }
    await _assign(context, ref, created.id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tagsAsync = ref.watch(tagsStreamProvider(message.conversationId));
    final maxHeight = MediaQuery.of(context).size.height * 0.75;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: tagsAsync.when(
          loading: () => const SizedBox(
            height: 120,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Erro: $e'),
          ),
          data: (tags) => _content(context, ref, tags),
        ),
      ),
    );
  }

  Widget _content(BuildContext context, WidgetRef ref, List<Tag> tags) {
    final current = tags.where((t) => t.id == message.tagId).firstOrNull;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
            'Tag da mensagem',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),

        // Tag atual + configuração global.
        if (current != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
            child: Row(
              children: [
                Flexible(child: TagChip(tag: current, maxWidth: 180)),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => showEditTagDialog(context, ref, current),
                  icon: const Icon(Icons.tune, size: 18),
                  label: const Text('Configurar tag'),
                ),
              ],
            ),
          ),

        const Divider(height: 1),

        // Tags existentes.
        Flexible(
          child: tags.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Nenhuma tag ainda. Crie a primeira abaixo.'),
                )
              : ListView(
                  shrinkWrap: true,
                  children: [
                    for (final tag in tags)
                      ListTile(
                        title: Align(
                          alignment: Alignment.centerLeft,
                          child: TagChip(tag: tag, maxWidth: 220),
                        ),
                        trailing:
                            tag.id == message.tagId ? const Icon(Icons.check) : null,
                        onTap: tag.id == message.tagId
                            ? () => Navigator.pop(context)
                            : () => _assign(context, ref, tag.id),
                      ),
                  ],
                ),
        ),

        const Divider(height: 1),

        ListTile(
          leading: const Icon(Icons.add),
          title: const Text('Nova tag'),
          onTap: () => _newTag(context, ref, tags),
        ),
        if (current != null)
          ListTile(
            leading: const Icon(Icons.label_off_outlined),
            title: const Text('Sem tag'),
            onTap: () => _assign(context, ref, null),
          ),
        if (onManageTags != null)
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: const Text('Gerenciar tags'),
            onTap: () {
              Navigator.pop(context);
              onManageTags!();
            },
          ),
      ],
    );
  }
}