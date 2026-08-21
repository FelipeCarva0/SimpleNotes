import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/block_providers.dart';
import '../providers/page_providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

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
                        // TODO Sprint 1: navegar para editor_screen.dart
                      },
                    ),
                ],
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: dialog simples para criar Block ou Page
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}