import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/conversation.dart';
import '../providers/conversation_providers.dart';
import 'chat_screen.dart';
import 'tags_screen.dart';

/// RF06 — tela inicial: lista de todas as Conversas. A busca por título
/// (RF06.1) entra na Sprint 4; esta versão (Sprint 0) cobre listagem e o
/// CRUD de Conversa (RF01).
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _createConversation(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final titulo = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nova conversa'),
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

    if (titulo == null || titulo.isEmpty || !context.mounted) return;

    final conversation =
        await ref.read(conversationRepositoryProvider).create(titulo: titulo);
    if (!context.mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(conversationId: conversation.id),
      ),
    );
  }

  Future<void> _renameConversation(
    BuildContext context,
    WidgetRef ref,
    String conversationId,
    String currentTitle,
  ) async {
    final controller = TextEditingController(text: currentTitle);
    final newTitle = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Renomear conversa'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );

    if (newTitle == null ||
        newTitle.isEmpty ||
        newTitle == currentTitle ||
        !context.mounted) {
      return;
    }
    await ref
        .read(conversationRepositoryProvider)
        .updateTitulo(conversationId, newTitle);
  }

  Future<void> _deleteConversation(
    BuildContext context,
    WidgetRef ref,
    String conversationId,
    String titulo,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir conversa?'),
        content: Text(
          'Isso vai apagar "$titulo" e todo o seu conteúdo permanentemente.',
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
    if (confirm != true || !context.mounted) return;
    await ref.read(conversationRepositoryProvider).delete(conversationId);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversationsAsync = ref.watch(conversationsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Arquivo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.label_outline),
            tooltip: 'Gerenciar tags',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TagsScreen()),
            ),
          ),
        ],
      ),
      body: conversationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (conversations) {
          if (conversations.isEmpty) {
            return const Center(child: Text('Nenhuma conversa ainda.'));
          }
          return ListView.builder(
            itemCount: conversations.length,
            itemBuilder: (context, index) =>
                _ConversationTile(
              conversation: conversations[index],
              onRename: (id, titulo) =>
                  _renameConversation(context, ref, id, titulo),
              onDelete: (id, titulo) =>
                  _deleteConversation(context, ref, id, titulo),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _createConversation(context, ref),
        tooltip: 'Nova conversa',
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final Conversation conversation;
  final void Function(String id, String titulo) onRename;
  final void Function(String id, String titulo) onDelete;

  const _ConversationTile({
    required this.conversation,
    required this.onRename,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        conversation.protegidoPorSenha
            ? Icons.lock_outline
            : Icons.chat_bubble_outline,
      ),
      title: Text(conversation.titulo),
      subtitle: Text(_formatDate(conversation.atualizadoEm)),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(conversationId: conversation.id),
        ),
      ),
      trailing: PopupMenuButton<String>(
        onSelected: (value) {
          if (value == 'rename') {
            onRename(conversation.id, conversation.titulo);
          } else if (value == 'delete') {
            onDelete(conversation.id, conversation.titulo);
          }
        },
        itemBuilder: (context) => const [
          PopupMenuItem(value: 'rename', child: Text('Renomear')),
          PopupMenuItem(value: 'delete', child: Text('Excluir')),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)}/${date.year}';
  }
}
