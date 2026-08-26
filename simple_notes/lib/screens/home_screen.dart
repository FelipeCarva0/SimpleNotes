import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/block_providers.dart';
import '../providers/page_providers.dart';
import 'editor_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _createPage(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final title = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nova página'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Título'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Criar'),
          ),
        ],
      ),
    );

    if (title == null || title.isEmpty || !context.mounted) return;

    final page = await ref.read(pageRepositoryProvider).create(title: title);
    if (!context.mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EditorScreen(pageId: page.id)),
    );
  }

  Future<void> _renamePage(BuildContext context, WidgetRef ref, String pageId, String currentTitle) async {
    final controller = TextEditingController(text: currentTitle);
    final newTitle = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Renomear página'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );

    if (newTitle == null || newTitle.isEmpty || newTitle == currentTitle || !context.mounted) return;
    await ref.read(pageRepositoryProvider).updateTitle(pageId, newTitle);
  }

  Future<void> _deletePage(BuildContext context, WidgetRef ref, String pageId, String title) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir página?'),
        content: Text('Isso vai apagar "$title" e todo o seu conteúdo permanentemente.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Excluir')),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;
    await ref.read(pageRepositoryProvider).delete(pageId);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blocksAsync = ref.watch(blocksStreamProvider);
    final rootPagesAsync = ref.watch(pagesInBlockProvider(null));

    return Scaffold(
      appBar: AppBar(title: const Text('Secure Notes')),
      body: blocksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (blocks) {
          return rootPagesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (rootPages) {
              if (blocks.isEmpty && rootPages.isEmpty) {
                return const Center(child: Text('Nothing here yet.'));
              }
              return ListView(
                children: [
                  for (final block in blocks)
                    ListTile(
                      leading: const Icon(Icons.folder_outlined),
                      title: Text(block.name),
                      onTap: () {
                        // TODO Sprint 2+: navegar para dentro do bloco
                      },
                    ),
                  for (final page in rootPages)
                    ListTile(
                      leading: const Icon(Icons.description_outlined),
                      title: Text(page.title),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => EditorScreen(pageId: page.id),
                          ),
                        );
                      },
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'rename') {
                            _renamePage(context, ref, page.id, page.title);
                          } else if (value == 'delete') {
                            _deletePage(context, ref, page.id, page.title);
                          }
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(value: 'rename', child: Text('Renomear')),
                          PopupMenuItem(value: 'delete', child: Text('Excluir')),
                        ],
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _createPage(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }
}

  