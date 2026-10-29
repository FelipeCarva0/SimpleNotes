import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/tag.dart';
import '../providers/tag_providers.dart';
import 'tag_chip.dart';
import 'tag_editor_dialog.dart';

/// Resultado do sheet de tag em lote.
///
/// [tagId] == null + [clear] == false  -> usuário fechou sem escolher.
/// [tagId] == null + [clear] == true   -> usuário escolheu "Sem tag".
/// [tagId] != null                     -> usuário escolheu uma tag.
class TagChoice {
  final String? tagId;
  final bool clear;
  const TagChoice._(this.tagId, this.clear);

  const TagChoice.none() : this._(null, false);
  const TagChoice.clear() : this._(null, true);
  const TagChoice.set(String id) : this._(id, false);
}

/// RF04/4.6 — define (ou remove) a Tag de várias Mensagens de uma vez.
/// Devolve um [TagChoice] ou null se fechado.
Future<TagChoice?> showTagPickerManySheet(
  BuildContext context, {
  required String conversationId,
  required int count,
}) {
  return showModalBottomSheet<TagChoice>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _TagPickerManySheet(
      conversationId: conversationId,
      count: count,
    ),
  );
}

class _TagPickerManySheet extends ConsumerWidget {
  final String conversationId;
  final int count;

  const _TagPickerManySheet({
    required this.conversationId,
    required this.count,
  });

  Future<void> _newTag(
    BuildContext context,
    WidgetRef ref,
    List<Tag> existing,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    final created = await showCreateTagDialog(context, ref, conversationId);
    if (created == null || !context.mounted) return;

    if (existing.any((t) => t.id == created.id)) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text('Já existia a tag "${created.nome}"; ela foi reutilizada.'),
        ));
    }
    nav.pop<TagChoice>(TagChoice.set(created.id));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tagsAsync = ref.watch(tagsStreamProvider(conversationId));
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
            'Tag para $count ${count == 1 ? 'mensagem' : 'mensagens'}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        const Divider(height: 1),
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
                        onTap: () => Navigator.pop<TagChoice>(
                          context,
                          TagChoice.set(tag.id),
                        ),
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
        ListTile(
          leading: const Icon(Icons.label_off_outlined),
          title: const Text('Sem tag'),
          onTap: () => Navigator.pop<TagChoice>(
            context,
            const TagChoice.clear(),
          ),
        ),
      ],
    );
  }
}