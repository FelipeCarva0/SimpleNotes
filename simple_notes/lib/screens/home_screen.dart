import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/conversation.dart';
import '../providers/conversation_providers.dart';
import '../providers/security_providers.dart';
import '../security/unlock_flow.dart';
import '../utils/text_normalize.dart';
import 'chat_screen.dart';
import '../widgets/password_change_dialog.dart';
import '../widgets/password_setup_dialog.dart';
import '../widgets/unlock_dialog.dart';

/// RF06 — tela inicial: lista de todas as Conversas, com busca por título
/// (RF06.1) e o CRUD de Conversa (RF01).
///
/// Sprint 8: abertura de conversa protegida passa pelo `runUnlockFlow`,
/// que decide entre biometria e senha automaticamente (biometria primeiro
/// se houver enrolamento). Menu ⋮ ganhou "Biometria" (ativar/desativar).
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _searchController = TextEditingController();
  bool _searching = false;
  String _query = '';

  /// Anti-reentrância do handler "Biometria" (não deixa abrir dois
  /// diálogos do menu em sequência antes do primeiro fechar).
  bool _biometricBusy = false;

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

  /// Abertura de conversa. Sprint 8: usa `runUnlockFlow` (biometria
  /// primeiro se houver enrolamento; senha como fallback).
  Future<void> _openConversation(Conversation conversation) async {
    final repo = ref.read(conversationRepositoryProvider);

    if (conversation.protegidoPorSenha && !repo.isUnlocked(conversation.id)) {
      final bio = ref.read(biometricUnlockProvider);
      final outcome = await runUnlockFlow(
        context: context,
        conversationId: conversation.id,
        conversationTitle: conversation.titulo,
        repo: repo,
        bio: bio,
      );
      if (!mounted) return;
      if (outcome != UnlockOutcome.unlockedByBiometric &&
          outcome != UnlockOutcome.unlockedByPassword) {
        return; // cancelado (já avisado quando necessário)
      }
      // Chave já está na sessão; invalida o stream para a ChatScreen
      // receber decifrado.
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
    }
  }

  Future<void> _unprotectConversation(Conversation conversation) async {
    // Pede a senha atual para confirmar (e para o repositório ter a chave
    // ao decifrar tudo de volta).
    final result = await showPasswordUnlockDialog(
      context,
      conversationTitle: conversation.titulo,
      hasBiometricEnrollment: false,
      biometricAvailable: false,
      allowSetupBiometric: false,
    );
    if (!mounted) return;
    if (result is! PasswordUnlockResultPassword) return;
    final password = result.password;

    final repo = ref.read(conversationRepositoryProvider);

    try {
      await repo.unprotectConversation(conversation.id, password);
      if (!mounted) return;
      // Ao remover a proteção, o enrolamento biométrico perde sentido
      // (a chave não tem mais como ser usada). Limpamos.
      await ref.read(biometricUnlockProvider).disable(conversation.id);
      if (!mounted) return;
      ref.invalidate(messagesStreamProvider(conversation.id));
      _showSnack('Proteção removida.');
    } on StateError catch (e) {
      _showSnack(e.message);
    } catch (e) {
      debugPrint('Erro ao remover proteção: $e');
      _showSnack('Não foi possível remover a proteção.');
    }
  }

  /// Sprint 8 — ativar/desativar biometria a partir do menu ⋮.
  /// Se a chave ainda não está na sessão, abre o fluxo de desbloqueio
  /// (com `manageBiometrics`: permite biometria se já existe, esconde o
  /// link "Configurar biometria" no rodapé).
  Future<void> _onBiometricPressed(Conversation conversation) async {
    if (_biometricBusy) return;
    _biometricBusy = true;
    try {
      final repo = ref.read(conversationRepositoryProvider);
      final bio = ref.read(biometricUnlockProvider);

      if (!await bio.isAvailable()) {
        if (!mounted) return;
        _showSnack('Biometria não disponível neste aparelho.');
        return;
      }

      // Garante que a chave está na sessão (senão o enable não pode ser
      // feito, e o isUnlocked dos outros fluxos fica inconsistente).
      var key = repo.unlockedKeyOrNull(conversation.id);
      if (key == null) {
        if (!mounted) return;
        final outcome = await runUnlockFlow(
          context: context,
          conversationId: conversation.id,
          conversationTitle: conversation.titulo,
          repo: repo,
          bio: bio,
          purpose: UnlockPurpose.manageBiometrics,
        );
        if (!mounted) return;
        if (outcome != UnlockOutcome.unlockedByBiometric &&
            outcome != UnlockOutcome.unlockedByPassword) {
          return;
        }
        key = repo.unlockedKeyOrNull(conversation.id);
        if (key == null) return; // defensivo
      }

      final enrolled = await bio.hasEnrollment(conversation.id);
      if (!mounted) return;

      if (enrolled) {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Desativar biometria?'),
            content: const Text(
              'A senha continuará funcionando para abrir esta conversa.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Desativar'),
              ),
            ],
          ),
        );
        if (confirm != true || !mounted) return;
        await bio.disable(conversation.id);
        if (!mounted) return;
        _showSnack('Biometria desativada.');
        return;
      }

      // Ativar.
      final ok = await bio.enable(
        conversationId: conversation.id,
        key: key,
      );
      if (!mounted) return;
      _showSnack(
        ok
            ? 'Biometria ativada. Você pode desbloquear esta conversa com a digital.'
            : 'Biometria não ativada.',
      );
    } finally {
      _biometricBusy = false;
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
                      onBiometric: _onBiometricPressed,
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
  final Future<void> Function(Conversation) onBiometric;

  const _ConversationTile({
    required this.conversation,
    required this.onOpen,
    required this.onRename,
    required this.onDelete,
    required this.onProtect,
    required this.onChangePassword,
    required this.onUnprotect,
    required this.onBiometric,
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
              // BUGFIX Sprint 8: este case estava vazio e caía no
              // 'biometric' por fall-through implícito. Cada case agora
              // tem seu próprio bloco.
              onChangePassword(conversation);
            case 'biometric':
              onBiometric(conversation);
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
            const PopupMenuItem(value: 'biometric', child: Text('Biometria')),
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