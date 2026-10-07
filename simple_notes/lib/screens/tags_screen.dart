import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/tag.dart';
import '../providers/tag_providers.dart';
import '../widgets/tag_chip.dart';
import '../widgets/tag_editor_dialog.dart';

/// RF04 — gerenciamento global de Tags: criar, renomear, trocar cor e
/// excluir. Excluir só remove a Tag; as mensagens permanecem.
class TagsScreen extends ConsumerWidget {
  const TagsScreen({super.key});

  Future<void> _delete(BuildContext context, WidgetRef ref, Tag tag) async {
    final repo = ref.read(tagRepositoryProvider);
    final count = await repo.countMessages(tag.id);
    if (!context.mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir tag?'),
        content: Text(
          count == 0
              ? 'A tag "${tag.nome}" não está em nenhuma mensagem.'
              : 'A tag "${tag.nome}" será removida de $count '
                  '${count == 1 ? 'mensagem' : 'mensagens'}. '
                  'As mensagens permanecem, apenas perdem a tag.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await repo.delete(tag.id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tagsAsync = ref.watch(tagsStreamProvider);
    final counts = ref.watch(tagUsageCountsProvider).maybeWhen(
          data: (m) => m,
          orElse: () => const <String, int>{},
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Tags')),
      body: tagsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (tags) {
          if (tags.isEmpty) {
            return const Center(child: Text('Nenhuma tag ainda.'));
          }
          return ListView.separated(
            itemCount: tags.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final tag = tags[index];
              final used = counts[tag.id] ?? 0;
              return ListTile(
                title: Align(
                  alignment: Alignment.centerLeft,
                  child: TagChip(tag: tag, maxWidth: 220),
                ),
                subtitle: Text(
                  used == 0
                      ? 'Sem mensagens'
                      : '$used ${used == 1 ? 'mensagem' : 'mensagens'}',
                ),
                onTap: () => showEditTagDialog(context, ref, tag),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      tooltip: 'Editar',
                      onPressed: () => showEditTagDialog(context, ref, tag),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: 'Excluir',
                      onPressed: () => _delete(context, ref, tag),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showCreateTagDialog(context, ref),
        tooltip: 'Nova tag',
        child: const Icon(Icons.add),
      ),
    );
  }
}