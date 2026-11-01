import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/conversation.dart';
import '../providers/conversation_providers.dart';
import '../utils/text_normalize.dart';
import 'chat_screen.dart';
import '../widgets/password_change_dialog.dart';
import '../widgets/password_setup_dialog.dart';
import '../widgets/unlock_dialog.dart';

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

    final conversation = await ref
        .read(conversationRepositoryProvider)
        .create(titulo: titulo);
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

  // ---------------------------------------------------------------------
  // RF08 — proteção por senha (Sprint 5)
  // ---------------------------------------------------------------------

  /// Abre a conversa; se estiver protegida e ainda não desbloqueada nesta
  /// sessão, pede a senha antes.
  Future<void> _openConversation(Conversation conversation) async {
    final repo = ref.read(conversationRepositoryProvider);

    if (conversation.protegidoPorSenha && !repo.isUnlocked(conversation.id)) {
      final password = await showUnlockDialog(
        context,
        conversationTitle: conversation.titulo,
      );
      if (password == null || !mounted) return;

      final key = await repo.verifyConversationPassword(
        conversation.id,
        password,
      );

      if (!mounted) return;

      if (key == null) {
        _showSnack('Senha incorreta.');
        return;
      }

      // A chave foi guardada no repositório. Invalida o stream de mensagens
      // para que a ChatScreen receba já decifrado quando abrir.
      ref.invalidate(messagesStreamProvider(conversation.id));
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(conversationId: conversation.id),
      ),
    );
  }

  Future<void> _protectConversation(Conversation conversation) async {
    final password = await showPasswordSetupDialog(
      context,
      conversationTitle: conversation.titulo,
    );
    if (password == null || !mounted) return;

    final repo = ref.read(conversationRepositoryProvider);

    try {
      await repo.protectConversation(conversation.id, password);
      if (!mounted) return;
      ref.invalidate(messagesStreamProvider(conversation.id));
      _showSnack('Conversa protegida.');
    } catch (e) {
      debugPrint('Erro ao proteger conversa: $e');
      _showSnack('Não foi possível proteger a conversa.');
    } finally {

    }
  }

  Future<void> _changeConversationPassword(Conversation conversation) async {
    final change = await showPasswordChangeDialog(
      context,
      conversationTitle: conversation.titulo,
    );
    if (change == null || !mounted) return;

    final repo = ref.read(conversationRepositoryProvider);

    try {
      await repo.changeConversationPassword(
        conversation.id,
        change.oldPassword,
        change.newPassword,
      );
      if (!mounted) return;
      ref.invalidate(messagesStreamProvider(conversation.id));
      _showSnack('Senha alterada.');
    } on StateError catch (e) {
      _showSnack(e.message);
    } catch (e) {
      debugPrint('Erro ao trocar senha: $e');
      _showSnack('Não foi possível trocar a senha.');
    } finally {

    }
  }

  Future<void> _unprotectConversation(Conversation conversation) async {
    // Pede a senha atual para confirmar (e para o repositório ter a chave
    // ao decifrar tudo de volta).
    final password = await showUnlockDialog(
      context,
      conversationTitle: conversation.titulo,
    );
    if (password == null || !mounted) return;

    final repo = ref.read(conversationRepositoryProvider);

    try {
      await repo.unprotectConversation(conversation.id, password);
      if (!mounted) return;
      ref.invalidate(messagesStreamProvider(conversation.id));
      _showSnack('Proteção removida.');
    } on StateError catch (e) {
      _showSnack(e.message);
    } catch (e) {
      debugPrint('Erro ao remover proteção: $e');
      _showSnack('Não foi possível remover a proteção.');
    } finally {

    }
  }

  void _showSnack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
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
      canPop: !_searching,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _searching) _closeSearch();
      },
      child: Stack(
        children: [
          Scaffold(
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
                  itemBuilder: (context, index) {
                    final c = conversations[index];
                    return _ConversationTile(
                      conversation: c,
                      onOpen: _openConversation,
                      onRename: _renameConversation,
                      onDelete: _deleteConversation,
                      onProtect: _protectConversation,
                      onChangePassword: _changeConversationPassword,
                      onUnprotect: _unprotectConversation,
                    );
                  },
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

        ],
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final Conversation conversation;
  final Future<void> Function(Conversation) onOpen;
  final void Function(String id, String titulo) onRename;
  final void Function(String id, String titulo) onDelete;
  final Future<void> Function(Conversation) onProtect;
  final Future<void> Function(Conversation) onChangePassword;
  final Future<void> Function(Conversation) onUnprotect;

  const _ConversationTile({
    required this.conversation,
    required this.onOpen,
    required this.onRename,
    required this.onDelete,
    required this.onProtect,
    required this.onChangePassword,
    required this.onUnprotect,
  });

  @override
  Widget build(BuildContext context) {
    final protected = conversation.protegidoPorSenha;

    return ListTile(
      leading: Icon(protected ? Icons.lock_outline : Icons.chat_bubble_outline),
      title: Text(conversation.titulo),
      subtitle: Text(_formatDate(conversation.atualizadoEm)),
      onTap: () => onOpen(conversation),
      trailing: PopupMenuButton<String>(
        onSelected: (value) {
          switch (value) {
            case 'rename':
              onRename(conversation.id, conversation.titulo);
            case 'delete':
              onDelete(conversation.id, conversation.titulo);
            case 'protect':
              onProtect(conversation);
            case 'change':
              onChangePassword(conversation);
            case 'unprotect':
              onUnprotect(conversation);
          }
        },
        itemBuilder: (context) => [
          const PopupMenuItem(value: 'rename', child: Text('Renomear')),
          if (!protected)
            const PopupMenuItem(value: 'protect', child: Text('Definir senha')),
          if (protected) ...[
            const PopupMenuItem(value: 'change', child: Text('Trocar senha')),
            const PopupMenuItem(
              value: 'unprotect',
              child: Text('Remover senha'),
            ),
          ],
          const PopupMenuItem(value: 'delete', child: Text('Excluir')),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)}/${date.year}';
  }
}
