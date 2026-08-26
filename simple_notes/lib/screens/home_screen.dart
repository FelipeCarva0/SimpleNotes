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