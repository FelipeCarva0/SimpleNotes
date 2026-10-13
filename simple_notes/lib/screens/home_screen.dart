import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/conversation.dart';
import '../providers/conversation_providers.dart';
import '../utils/text_normalize.dart';
import 'chat_screen.dart';

/// RF06 — tela inicial: lista de todas as Conversas, com busca por título
/// (RF06.1) e o CRUD de Conversa (RF01).
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _searchController = TextEditingController();
  bool _searching = false;
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openSearch() => setState(() => _searching = true);

  void _closeSearch() {
    _searchController.clear();
    setState(() {
      _searching = false;
      _query = '';
    });
  }

  void _clearQuery() {
    _searchController.clear();
    setState(() => _query = '');
  }

  /// RF06.1 — filtra por título, ignorando maiúsculas e acentos.
  List<Conversation> _filter(List<Conversation> all) {
    final q = normalizeText(_query.trim());
    if (q.isEmpty) return all;
    return all.where((c) => normalizeText(c.titulo).contains(q)).toList();
  }

  Future<void> _createConversation() async {
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

    if (titulo == null || titulo.isEmpty || !mounted) return;

    final conversation =
        await ref.read(conversationRepositoryProvider).create(titulo: titulo);
    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(conversationId: conversation.id),
      ),
    );
  }

  Future<void> _renameConversation(String id, String currentTitle) async {
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
        !mounted) {
      return;
    }
    await ref.read(conversationRepositoryProvider).updateTitulo(id, newTitle);
  }

  Future<void> _deleteConversation(String id, String titulo) async {
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
    if (confirm != true || !mounted) return;
    await ref.read(conversationRepositoryProvider).delete(id);
  }

  PreferredSizeWidget _buildAppBar() {
    if (!_searching) {
      return AppBar(
        title: const Text('Arquivo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Buscar conversa',
            onPressed: _openSearch,
          ),
        ],
      );
    }

    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        tooltip: 'Fechar busca',
        onPressed: _closeSearch,
      ),
      title: TextField(
        controller: _searchController,
        autofocus: true,
        textInputAction: TextInputAction.search,
        decoration: const InputDecoration(
          hintText: 'Buscar conversa',
          border: InputBorder.none,
        ),
        onChanged: (value) => setState(() => _query = value),
      ),
      actions: [
        if (_query.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Limpar',
            onPressed: _clearQuery,
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final conversationsAsync = ref.watch(conversationsStreamProvider);

    return PopScope(
      // Com a busca aberta, "voltar" fecha a busca em vez de sair da tela.
      canPop: !_searching,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _closeSearch();
      },
      child: Scaffold(
        appBar: _buildAppBar(),
        body: conversationsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Erro: $e')),
          data: (all) {
            if (all.isEmpty) {
              return const Center(child: Text('Nenhuma conversa ainda.'));
            }
            final conversations = _filter(all);
            if (conversations.isEmpty) {
              return const Center(
                child: Text('Nenhuma conversa encontrada.'),
              );
            }
            return ListView.builder(
              itemCount: conversations.length,
              itemBuilder: (context, index) => _ConversationTile(
                conversation: conversations[index],
                onRename: _renameConversation,
                onDelete: _deleteConversation,
              ),
            );
          },
        ),
        floatingActionButton: _searching
            ? null
            : FloatingActionButton(
                onPressed: _createConversation,
                tooltip: 'Nova conversa',
                child: const Icon(Icons.add),
              ),
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