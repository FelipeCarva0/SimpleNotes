import 'package:flutter/services.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/message.dart';
import '../providers/conversation_providers.dart';
import '../widgets/message_bubble.dart';
import '../services/attachment_service.dart';
import '../widgets/attachment_picker_sheet.dart';
import '../widgets/audio_recorder_dialog.dart';
import '../database/tables.dart' show MessageType;
import '../widgets/tag_picker_sheet.dart';
import '../models/tag.dart';
import '../providers/tag_providers.dart';
import 'tags_screen.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import '../search/message_search.dart';
import '../utils/format.dart';
import '../widgets/search_options_sheet.dart';
import '../widgets/message_details_sheet.dart';

/// Tela de chat de uma Conversa (RF01, RF02, RF03) — Sprint 1: só mensagens
/// de texto. Anexos de arquivo (RF02.3) entram na Sprint 2 e o gesto de
/// arrastar para tag (RF04) na Sprint 3 — os pontos de extensão ficam
/// marcados nos comentários abaixo.
class ChatScreen extends ConsumerStatefulWidget {
  final String conversationId;

  const ChatScreen({super.key, required this.conversationId});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _controller = TextEditingController();
  final _itemScrollController = ItemScrollController();
  String? _highlightedId;
  Timer? _highlightTimer;
  Timer? _debounce;

  // Só ficamos true depois de carregar o rascunho já salvo no banco; evita
  // que o dispose() sobrescreva um rascunho existente com string vazia caso
  // o usuário saia da tela antes do carregamento inicial terminar.
  bool _draftLoaded = false;
  bool _sendingAttachment = false;
  int _lastMessageCount = 0;

  @override
  void initState() {
    super.initState();
    _loadInitialDraft();
  }

  Future<void> _loadInitialDraft() async {
    final conversation = await ref
        .read(conversationRepositoryProvider)
        .getById(widget.conversationId);
    if (!mounted) return;
    setState(() {
      _controller.text = conversation?.rascunho ?? '';
      _draftLoaded = true;
    });
  }

  /// RF02.1 — autosave com debounce a cada pausa de digitação.
  void _onDraftChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      ref
          .read(conversationRepositoryProvider)
          .saveDraft(widget.conversationId, value);
    });
  }

  /// RF02.2 — confirmação de envio (botão de enviar).
  Future<void> _send() async {
    if (_controller.text.trim().isEmpty) return;

    // Cancela o debounce pendente e garante que o texto mais recente esteja
    // salvo como rascunho antes de confirmar o envio, para não correr risco
    // de enviar uma versão um pouco desatualizada do que foi digitado.
    _debounce?.cancel();
    await ref
        .read(conversationRepositoryProvider)
        .saveDraft(widget.conversationId, _controller.text);
    await ref.read(conversationRepositoryProvider).sendDraft(widget.conversationId);

    _controller.clear();
    _scrollToBottomOnNextFrame();
  }


  /// RF02.3 — abre o sheet, executa a ação escolhida e envia o anexo.
  Future<void> _onAttachPressed() async {
    if (_sendingAttachment) return;

    final action = await showAttachmentPickerSheet(context);
    if (action == null || !mounted) return;

    final service = ref.read(attachmentServiceProvider);
    final isCapture =
        action == AttachmentAction.camera || action == AttachmentAction.video;

    // Se o Android matar o app durante a câmera, este marcador sobra em disco
    // e permite recuperar a captura na próxima abertura.
    if (isCapture) await service.markPendingCapture(widget.conversationId);

    try {
      PickedAttachment? picked;
      switch (action) {
        case AttachmentAction.camera:
          picked = await service.takePhoto();
        case AttachmentAction.gallery:
          picked = await service.pickImageFromGallery();
        case AttachmentAction.video:
          picked = await service.recordVideo();
        case AttachmentAction.videoGallery:
          picked = await service.pickVideoFromGallery();
        case AttachmentAction.audioFile:
          picked = await service.pickAudioFile();
        case AttachmentAction.document:
          picked = await service.pickDocument();
        case AttachmentAction.audioRecord:
          picked = await _recordAudio(service);
      }

      if (picked == null || !mounted) return; // cancelado: sem erro

      await _sendPicked(picked);
    } on AttachmentPermissionException catch (e) {
      _showSnack(e.message);
    } catch (e) {
      _showSnack('Não foi possível anexar o arquivo.');
      debugPrint('Erro ao anexar: $e');
    } finally {
      // Só chega aqui se o app NÃO foi morto; se foi, o marcador permanece.
      if (isCapture) await service.clearPendingCapture();
    }
  }

  Future<PickedAttachment?> _recordAudio(AttachmentService service) async {
    await service.startRecording(); // pode lançar permissão negada
    if (!mounted) {
      await service.cancelRecording();
      return null;
    }
    final send = await showAudioRecorderDialog(context);
    if (send == true) {
      return service.stopRecording();
    }
    await service.cancelRecording();
    return null;
  }

  /// RF02.4: renomeia só o nome de exibição; data intocada.
  Future<void> _renameAttachment(Message message) async {
    final controller =
        TextEditingController(text: message.arquivoNomeExibicao ?? '');
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Renomear arquivo'),
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
    if (newName == null || newName.isEmpty || !mounted) return;
    await ref
        .read(conversationRepositoryProvider)
        .renameAttachment(message.id, newName);
  }

  /// RF02.4: troca o arquivo físico mantendo data, posição e tipo.
  Future<void> _replaceAttachment(Message message) async {
    if (_sendingAttachment) return;
    final service = ref.read(attachmentServiceProvider);

    try {
      final picked = await service.pickForReplace(message.tipo);
      if (picked == null || !mounted) return; // cancelado

      setState(() => _sendingAttachment = true);
      await ref.read(conversationRepositoryProvider).replaceAttachmentFile(
            messageId: message.id,
            newFile: picked.file,
            nomeOriginal: picked.nomeOriginal,
          );
    } on AttachmentPermissionException catch (e) {
      _showSnack(e.message);
    } catch (e) {
      _showSnack('Não foi possível substituir o arquivo.');
      debugPrint('Erro ao substituir: $e');
    } finally {
      if (mounted) setState(() => _sendingAttachment = false);
    }
  }

  Future<void> _sendPicked(PickedAttachment picked) async {
    setState(() => _sendingAttachment = true);
    try {
      await ref.read(conversationRepositoryProvider).sendAttachment(
            conversationId: widget.conversationId,
            tipo: picked.tipo,
            file: picked.file,
            nomeOriginal: picked.nomeOriginal,
          );
      _scrollToBottomOnNextFrame();
    } finally {
      // Apaga o temporário (gravação) já copiado para o storage do app.
      if (picked.isTemporary && await picked.file.exists()) {
        await picked.file.delete();
      }
      if (mounted) setState(() => _sendingAttachment = false);
    }
  }

  void _showSnack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }
  void _scrollToBottomOnNextFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_itemScrollController.isAttached) return;
      // Lista invertida: o índice 0 é a mensagem mais recente.
      _itemScrollController.scrollTo(
        index: 0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }
  /// Rola até a mensagem de índice cronológico [index] (posição na lista
  /// completa da conversa, de [total] mensagens) e a destaca por um instante.
  void _goToMessage({
    required int index,
    required int total,
    required String messageId,
  }) {
    if (!_itemScrollController.isAttached) return;

    // A lista é invertida: converte o índice cronológico no índice do widget.
    _itemScrollController.scrollTo(
      index: total - 1 - index,
      alignment: 0.4,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );

    _highlightTimer?.cancel();
    setState(() => _highlightedId = messageId);
    _highlightTimer = Timer(const Duration(milliseconds: 1800), () {
      if (mounted) setState(() => _highlightedId = null);
    });
  }
  void _onMenuSelected(String value) {
    switch (value) {
      case 'search':
        _openSearchMenu();
      case 'tags':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TagsScreen(conversationId: widget.conversationId),
          ),
        );
    }
  }

  /// RF05 — abre o sheet "Pesquisar" e executa o modo escolhido.
  Future<void> _openSearchMenu() async {
    final mode = await showSearchOptionsSheet(context);
    if (mode == null || !mounted) return;

    switch (mode) {
      case SearchMode.goToDate:
        await _searchByDate();
    }
  }

  /// RF05 — data simples: vai para a primeira mensagem do dia escolhido.
  Future<void> _searchByDate() async {
    final messages =
        ref.read(messagesStreamProvider(widget.conversationId)).valueOrNull;
    if (messages == null || messages.isEmpty) {
      _showSnack('Esta conversa ainda não tem mensagens.');
      return;
    }

    DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

    // Período coberto pela conversa (as datas podem ter sido editadas
    // manualmente, então não dá para assumir que a lista está em ordem).
    var first = dateOnly(messages.first.data);
    var last = first;
    for (final m in messages) {
      final d = dateOnly(m.data);
      if (d.isBefore(first)) first = d;
      if (d.isAfter(last)) last = d;
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: last,
      firstDate: first,
      lastDate: last,
      helpText: 'Ir para o dia',
    );
    if (picked == null || !mounted) return;

    // Relê a lista: pode ter mudado enquanto o calendário estava aberto.
    final current =
        ref.read(messagesStreamProvider(widget.conversationId)).valueOrNull ??
            messages;
    final index = firstIndexOnDate(current, picked);
    if (index == null) {
      _showSnack('Nenhuma mensagem em ${formatDate(picked)}.');
      return;
    }

    _goToMessage(
      index: index,
      total: current.length,
      messageId: current[index].id,
    );
  }
  @override
  void dispose() {
    _debounce?.cancel();
    // RF02.1 — garante que o rascunho não se perde ao sair da tela, mesmo
    // sem o usuário ter confirmado o envio (fechar o app, apertar "voltar").
    if (_draftLoaded) {
      ref
          .read(conversationRepositoryProvider)
          .saveDraft(widget.conversationId, _controller.text);
    }
    _controller.dispose();
    _highlightTimer?.cancel();
    super.dispose();
  }

  /// RF02.4 / RF03 — reescreve o conteúdo sem alterar a data original.
  Future<void> _editMessage(Message message) async {
    final controller = TextEditingController(text: message.conteudoTexto ?? '');
    final newContent = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar mensagem'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: null,
        ),
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
    if (newContent == null || newContent.isEmpty || !mounted) return;
    await ref
        .read(conversationRepositoryProvider)
        .updateMessageContent(message.id, newContent);
  }

  /// RF02.6 / RF03 — sobrescrita manual da data, independente do fluxo
  /// automático.
  Future<void> _editDate(Message message) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: message.data,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null || !mounted) return;
    await ref
        .read(conversationRepositoryProvider)
        .setMessageDateManually(message.id, picked);
  }

  /// RF04 — abre o sheet de tag da mensagem.
  void _openTagPicker(Message message) {
    if (!mounted) return;
    showTagPickerSheet(
      context,
      message: message,
      onManageTags: () {
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TagsScreen(conversationId: widget.conversationId),
          ),
        );
      },
    );
  }
    void _openDetails(Message message, int position, int total, Tag? tag) {
    if (!mounted) return;
    showMessageDetailsSheet(
      context,
      message: message,
      tag: tag,
      position: position,
      total: total,
    );
  }

  /// RF02.5 — exclusão explícita, distinta de qualquer edição de conteúdo.
  Future<void> _deleteMessage(Message message) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir mensagem?'),
        content: const Text('Essa ação não pode ser desfeita.'),
        actions: [
          PopupMenuButton<String>(
            onSelected: _onMenuSelected,
            itemBuilder: (_) => const [
              // TEMPORÁRIOS (Etapa 4.2): somem na 4.3, quando entra "Pesquisar".
              PopupMenuItem(value: 'debug_first', child: Text('[teste] Ir ao início')),
              PopupMenuItem(value: 'debug_last', child: Text('[teste] Ir ao fim')),
              PopupMenuItem(value: 'tags', child: Text('Gerenciar tags')),
            ],
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await ref.read(conversationRepositoryProvider).deleteMessage(message.id);
  }

  void _showMessageActions(Message message) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            // Só para mensagens de texto
            if (message.tipo == MessageType.texto)
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Editar texto'),
                onTap: () {
                  Navigator.pop(context);
                  _editMessage(message);
                },
              ),

            // Só para anexos (imagem, vídeo, áudio, documento)
            if (message.tipo != MessageType.texto) ...[
              ListTile(
                leading: const Icon(Icons.drive_file_rename_outline),
                title: const Text('Renomear arquivo'),
                onTap: () {
                  Navigator.pop(context);
                  _renameAttachment(message);
                },
              ),
              ListTile(
                leading: const Icon(Icons.swap_horiz),
                title: const Text('Substituir arquivo'),
                onTap: () {
                  Navigator.pop(context);
                  _replaceAttachment(message);
                },
              ),
            ],

            ListTile(
              leading: const Icon(Icons.event_outlined),
              title: const Text('Editar data'),
              onTap: () {
                Navigator.pop(context);
                _editDate(message);
              },
            ),ListTile(
              leading: const Icon(Icons.label_outline),
              title: const Text('Definir tag'),
              onTap: () {
                Navigator.pop(context);
                _openTagPicker(message);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Excluir'),
              onTap: () {
                Navigator.pop(context);
                _deleteMessage(message);
              },
            ),
          ],
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final conversationAsync =
        ref.watch(conversationByIdProvider(widget.conversationId));
    final messagesAsync = ref.watch(messagesStreamProvider(widget.conversationId));
    final tagsById = <String, Tag>{
      for (final t in ref.watch(tagsStreamProvider(widget.conversationId)).maybeWhen(
          data: (tags) => tags,
          orElse: () => const <Tag>[],
        ))
      t.id: t,
    };
    // Rola pro fim quando uma mensagem nova chega, sem brigar com o scroll
    // manual do usuário revendo mensagens antigas (só dispara quando a
    // contagem cresce).
    messagesAsync.whenData((messages) {
      if (messages.length > _lastMessageCount) {
        _scrollToBottomOnNextFrame();
      }
      _lastMessageCount = messages.length;
    });

    return Scaffold(
      appBar: AppBar(
        title: conversationAsync.when(
          data: (c) => Text(c?.titulo ?? ''),
          loading: () => const Text(''),
          error: (_, _) => const Text('Erro'),
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: _onMenuSelected,
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'search', child: Text('Pesquisar')),
              PopupMenuItem(value: 'tags', child: Text('Gerenciar tags')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: messagesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Erro: $e')),
              data: (messages) {
                if (messages.isEmpty) {
                  return const Center(
                    child: Text('Nenhuma mensagem ainda. Escreva algo abaixo.'),
                  );
                }
                return ScrollablePositionedList.builder(
                  itemScrollController: _itemScrollController,
                  reverse: true,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                  itemCount: messages.length,
                  itemBuilder: (context, displayIndex) {
  // Lista invertida: converte para o índice cronológico da mensagem.
  final index = messages.length - 1 - displayIndex;
  final message = messages[index];

  return AnimatedContainer(
    duration: const Duration(milliseconds: 300),
    decoration: BoxDecoration(
      color: message.id == _highlightedId
          ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.18)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Dismissible(
  key: ValueKey(message.id),
  direction: DismissDirection.horizontal,
  dismissThresholds: const {
    DismissDirection.startToEnd: 0.25,
    DismissDirection.endToStart: 0.25,
  },
  background: const _TagSwipeBackground(),
  secondaryBackground: const _DetailsSwipeBackground(),
  confirmDismiss: (direction) async {
    HapticFeedback.lightImpact();
    // Sem await: a linha volta ao lugar na hora.
    if (direction == DismissDirection.startToEnd) {
      _openTagPicker(message);
    } else {
      _openDetails(
        message,
        index + 1,
        messages.length,
        tagsById[message.tagId],
      );
    }
    return false;
  },
  child: MessageBubble(
    message: message,
    tag: tagsById[message.tagId],
    onTap: message.tipo == MessageType.texto
        ? () => _editMessage(message)
        : null,
    onLongPress: () => _showMessageActions(message),
  ),
),
  );
},
                );
              },
            ),
          ),
          if (_sendingAttachment) const LinearProgressIndicator(),
          _Composer(
            controller: _controller,
            enabled: _draftLoaded,
            onChanged: _onDraftChanged,
            onSend: _send,
            onAttach: _sendingAttachment ? null : _onAttachPressed,
          ),
        ],
      ),
    );
  }
}

  /// Fundo revelado enquanto o balão é arrastado (RF04).
  class _TagSwipeBackground extends StatelessWidget {
    const _TagSwipeBackground();

    @override
    Widget build(BuildContext context) {
      return Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        child: Icon(
          Icons.label_outline,
          color: Theme.of(context).colorScheme.primary,
        ),
      );
    }
  }

  /// Fundo revelado ao arrastar o balão para a esquerda (detalhes).
  class _DetailsSwipeBackground extends StatelessWidget {
    const _DetailsSwipeBackground();

    @override
    Widget build(BuildContext context) {
      return Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: Icon(
          Icons.info_outline,
          color: Theme.of(context).colorScheme.primary,
        ),
      );
    }
  }
class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  final ValueChanged<String> onChanged;
  final VoidCallback onSend;
  final VoidCallback? onAttach;

  const _Composer({
    required this.controller,
    required this.enabled,
    required this.onChanged,
    required this.onSend,
    required this.onAttach,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            IconButton(
              onPressed: enabled ? onAttach : null,
              icon: const Icon(Icons.attach_file),
              tooltip: 'Anexar',
            ),
            Expanded(
              child: TextField(
                controller: controller,
                enabled: enabled,
                minLines: 1,
                maxLines: 6,
                textInputAction: TextInputAction.newline,
                decoration: const InputDecoration(
                  hintText: 'Escreva algo...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(20)),
                  ),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onChanged: onChanged,
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: enabled ? onSend : null,
              icon: const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }
}
