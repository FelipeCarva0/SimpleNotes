import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/conversation.dart';
import '../providers/conversation_providers.dart';
import '../providers/security_providers.dart';
import '../security/unlock_flow.dart';
import '../utils/text_normalize.dart';

/// Sprint 7 (7.4) — escolha da Conversa de destino para encaminhar (e,
/// no bloco 7.6, para receber compartilhamento externo).
///
/// Sprint 8: a desbloqueio de destino protegido passa pelo
/// `runUnlockFlow` (biometria primeiro se houver). Sem diálogo próprio
/// de senha.
class DestinationPickerScreen extends ConsumerStatefulWidget {
  /// Conversa que NÃO deve ser escolhida (normalmente a de origem).
  final String? disabledConversationId;

  /// Título da tela. Default: "Encaminhar para".
  final String title;

  /// Texto de apoio abaixo do título. Opcional.
  final String? subtitle;

  const DestinationPickerScreen({
    super.key,
    this.disabledConversationId,
    this.title = 'Encaminhar para',
    this.subtitle,
  });

  @override
  ConsumerState<DestinationPickerScreen> createState() =>
      _DestinationPickerScreenState();
}

class _DestinationPickerScreenState
    extends ConsumerState<DestinationPickerScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  bool _picking = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Conversation> _filter(List<Conversation> all) {
    final q = normalizeText(_query.trim());
    if (q.isEmpty) return all;
    return all.where((c) => normalizeText(c.titulo).contains(q)).toList();
  }

  Future<void> _createAndPick() async {
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

    final conv = await ref
        .read(conversationRepositoryProvider)
        .create(titulo: titulo);
    if (!mounted) return;
    Navigator.pop(context, conv.id);
  }

  Future<void> _pick(Conversation conversation) async {
    if (_picking) return;
    _picking = true;
    try {
      final repo = ref.read(conversationRepositoryProvider);
      final bio = ref.read(biometricUnlockProvider);

      if (conversation.protegidoPorSenha &&
          !repo.isUnlocked(conversation.id)) {
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
          return; // cancelado ou senha errada (já avisado)
        }
        ref.invalidate(messagesStreamProvider(conversation.id));
      }

      if (!mounted) return;
      Navigator.pop(context, conversation.id);
    } finally {
      _picking = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final conversationsAsync = ref.watch(conversationsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Buscar conversa',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                border: const OutlineInputBorder(),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      ),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Nova conversa',
            onPressed: _createAndPick,
          ),
        ],
      ),
      body: Column(
        children: [
          if (widget.subtitle != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  widget.subtitle!,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
          Expanded(
            child: conversationsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Erro: $e')),
              data: (all) {
                final list = _filter(all);
                if (list.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        all.isEmpty
                            ? 'Nenhuma conversa ainda. Crie uma nova.'
                            : 'Nenhuma conversa encontrada.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final c = list[index];
                    final disabled =
                        c.id == widget.disabledConversationId;
                    final protected = c.protegidoPorSenha;
                    return ListTile(
                      enabled: !disabled,
                      leading: Icon(
                        protected
                            ? Icons.lock_outline
                            : Icons.chat_bubble_outline,
                      ),
                      title: Text(c.titulo),
                      subtitle: disabled
                          ? const Text('Conversa de origem')
                          : protected
                              ? const Text('Protegida por senha')
                              : null,
                      onTap: disabled ? null : () => _pick(c),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Sprint 7 (7.4) — opções de encaminhamento.
/// (Mantido sem alteração na Sprint 8.)
class ForwardOptions {
  final bool keepOriginalDate;
  final bool carryTag;

  const ForwardOptions({
    this.keepOriginalDate = false,
    this.carryTag = false,
  });
}

/// Mostra o diálogo de opções. Devolve [ForwardOptions] ou `null` se
/// cancelar. [sourceProtected] + `[!destinationProtected]` dispara o
/// aviso S7-8 (rebaixamento de segurança).
Future<ForwardOptions?> showForwardOptionsDialog(
  BuildContext context, {
  required int messageCount,
  required bool sourceProtected,
  required bool destinationProtected,
}) {
  return showDialog<ForwardOptions>(
    context: context,
    builder: (_) => _ForwardOptionsDialog(
      messageCount: messageCount,
      sourceProtected: sourceProtected,
      destinationProtected: destinationProtected,
    ),
  );
}

class _ForwardOptionsDialog extends StatefulWidget {
  final int messageCount;
  final bool sourceProtected;
  final bool destinationProtected;

  const _ForwardOptionsDialog({
    required this.messageCount,
    required this.sourceProtected,
    required this.destinationProtected,
  });

  @override
  State<_ForwardOptionsDialog> createState() => _ForwardOptionsDialogState();
}

class _ForwardOptionsDialogState extends State<_ForwardOptionsDialog> {
  bool _keepDate = false;
  bool _carryTag = false;

  @override
  Widget build(BuildContext context) {
    final n = widget.messageCount;
    final showWarning =
        widget.sourceProtected && !widget.destinationProtected;

    return AlertDialog(
      title: Text('Encaminhar $n ${n == 1 ? 'mensagem' : 'mensagens'}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CheckboxListTile(
              value: _keepDate,
              onChanged: (v) => setState(() => _keepDate = v ?? false),
              title: const Text('Manter data original'),
              subtitle: const Text(
                'Desligado: as mensagens recebem a data de hoje.',
              ),
              contentPadding: EdgeInsets.zero,
            ),
            CheckboxListTile(
              value: _carryTag,
              onChanged: (v) => setState(() => _carryTag = v ?? false),
              title: const Text('Levar tag'),
              subtitle: const Text(
                'Recria a tag da origem no destino (nome + cor).',
              ),
              contentPadding: EdgeInsets.zero,
            ),
            if (showWarning) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_outlined,
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Os nomes e textos ficarão sem criptografia na '
                        'conversa de destino.',
                        style: TextStyle(
                          color: Theme.of(
                            context,
                          ).colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            ForwardOptions(
              keepOriginalDate: _keepDate,
              carryTag: _carryTag,
            ),
          ),
          child: const Text('Encaminhar'),
        ),
      ],
    );
  }
}