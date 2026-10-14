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
import '../utils/tag_colors.dart';

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
  static const double _previewHeight = 48;
  final _listAreaKey = GlobalKey();
  final Set<_ItemProbeState> _probes = {};

  // Modo mover (A4.2)
  bool _moveActive = false;
  String? _moveId;
  final ValueNotifier<_MoveVisual?> _move = ValueNotifier(null);
  final _scrollOffsetController = ScrollOffsetController();
  Timer? _autoScrollTimer;
  Offset? _lastPointer;
  int? _lastDropIndex;

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
    await ref
        .read(conversationRepositoryProvider)
        .sendDraft(widget.conversationId);

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
    final controller = TextEditingController(
      text: message.arquivoNomeExibicao ?? '',
    );
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
      await ref
          .read(conversationRepositoryProvider)
          .replaceAttachmentFile(
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
      await ref
          .read(conversationRepositoryProvider)
          .sendAttachment(
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

  /// Destaque temporário da mensagem, sem rolar a lista.
  void _flashHighlight(String messageId) {
    _highlightTimer?.cancel();
    setState(() => _highlightedId = messageId);
    _highlightTimer = Timer(const Duration(milliseconds: 1800), () {
      if (mounted) setState(() => _highlightedId = null);
    });
  }

  /// Rola até a mensagem de índice cronológico [index] (de [total]
  /// mensagens) e a destaca por um instante.
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
    _flashHighlight(messageId);
  }

  // ---------------------------------------------------------------------
  // Reordenar: segurar e mover (A4.2)
  // ---------------------------------------------------------------------

  /// Posições na tela (globais) das linhas atualmente montadas, por índice
  /// cronológico.
  Map<int, Rect> _itemRects() {
    final result = <int, Rect>{};
    for (final p in _probes) {
      final r = p.globalRect();
      if (r != null) result[p.index] = r;
    }
    return result;
  }

  /// Onde a mensagem em movimento cairia com o dedo em [globalY]:
  /// índice final e Y (global) da linha de inserção.
  _Drop? _computeDrop(double globalY, List<Message> messages) {
    final movedIdx = messages.indexWhere((m) => m.id == _moveId);
    if (movedIdx < 0) return null;

    // A linha da própria mensagem movida fica de fora: ela pode estar mantida
    // viva fora da tela, com uma posição sem significado.
    final rects = _itemRects()..remove(movedIdx);
    if (rects.isEmpty) return null;

    final minRendered = rects.keys.reduce((a, b) => a < b ? a : b);

    // Mensagens mais antigas que as montadas estão acima da tela.
    var s = minRendered - (movedIdx < minRendered ? 1 : 0);
    for (final e in rects.entries) {
      if (e.value.center.dy < globalY) s++;
    }

    // Posição "t" na lista SEM a mensagem movida -> índice cronológico.
    int toChron(int t) => t < movedIdx ? t : t + 1;

    final others = messages.length - 1;
    double? lineY;
    final above = s - 1;
    if (above >= 0 && rects[toChron(above)] != null) {
      lineY = rects[toChron(above)]!.bottom;
    } else if (s <= others - 1 && rects[toChron(s)] != null) {
      lineY = rects[toChron(s)]!.top;
    }

    return _Drop(index: s, lineY: lineY);
  }

  /// Atualiza o cartão que segue o dedo e a linha de inserção.
  void _updateMove(Offset global, List<Message> messages) {
    final area = _listAreaKey.currentContext?.findRenderObject();
    if (area is! RenderBox || !area.hasSize) return;

    final drop = _computeDrop(global.dy, messages);
    if (drop == null) return;

    // Vibração curta a cada novo ponto de inserção (não na primeira medição).
    if (_lastDropIndex != null && _lastDropIndex != drop.index) {
      HapticFeedback.selectionClick();
    }
    _lastDropIndex = drop.index;

    final local = area.globalToLocal(global);
    final maxTop = area.size.height - _previewHeight;
    final top = (local.dy - _previewHeight / 2)
        .clamp(0.0, maxTop < 0 ? 0.0 : maxTop)
        .toDouble();

    double? lineY;
    if (drop.lineY != null) {
      final ly = area.globalToLocal(Offset(0, drop.lineY!)).dy;
      if (ly >= 0 && ly <= area.size.height) lineY = ly;
    }

    _move.value = _MoveVisual(
      dropIndex: drop.index,
      previewTop: top,
      lineY: lineY,
    );
  }

  void _onMoveUpdate(Message message, LongPressMoveUpdateDetails d) {
    _lastPointer = d.globalPosition;

    if (!_moveActive) {
      if (d.offsetFromOrigin.distance < 12) return; // ainda é só uma segurada
      setState(() {
        _moveActive = true;
        _moveId = message.id;
      });
      _lastDropIndex = null;
      HapticFeedback.selectionClick();
      _startAutoScroll();
    }
    final messages = ref
        .read(messagesStreamProvider(widget.conversationId))
        .valueOrNull;
    if (messages == null) return;
    _updateMove(d.globalPosition, messages);
  }

  /// Soltou o dedo: se estava movendo, grava; senão, abre o menu de ações.
  void _onPressEnd(Message message) {
    if (_moveActive) {
      _finishMove();
    } else {
      _showMessageActions(message);
    }
  }

  void _onPressCancel() {
    if (_moveActive) _resetMove();
  }

  Future<void> _finishMove() async {
    final id = _moveId;
    final target = _move.value?.dropIndex;
    try {
      if (id != null && target != null) {
        final from = await ref
            .read(conversationRepositoryProvider)
            .reorderMessage(id, target);
        if (from != null && mounted) {
          _flashHighlight(id);
          _showUndoSnack(id, from);
        }
      }
    } catch (e) {
      debugPrint('Erro ao mover mensagem: $e');
      _showSnack('Não foi possível mover a mensagem.');
    } finally {
      _resetMove();
    }
  }

  void _resetMove() {
    _stopAutoScroll();
    _lastPointer = null;
    _lastDropIndex = null;
    _move.value = null;
    if (!mounted) return;
    setState(() {
      _moveActive = false;
      _moveId = null;
    });
  }

  // ---------------------------------------------------------------------
  // Rolagem automática e desfazer (A4.3)
  // ---------------------------------------------------------------------

  void _startAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = Timer.periodic(
      const Duration(milliseconds: 40),
      (_) => _autoScrollTick(),
    );
  }

  void _stopAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
  }

  /// Roda a cada 40 ms durante o modo mover. Mesmo com o dedo parado a lista
  /// pode ter rolado sob ele, então recalcula a linha de inserção; depois,
  /// se o dedo está perto de uma borda, rola mais um passo.
  void _autoScrollTick() {
    if (!_moveActive) return;
    final pointer = _lastPointer;
    final area = _listAreaKey.currentContext?.findRenderObject();
    if (pointer == null || area is! RenderBox || !area.hasSize) return;

    final messages = ref
        .read(messagesStreamProvider(widget.conversationId))
        .valueOrNull;
    if (messages == null) return;

    _updateMove(pointer, messages);

    const zone = 72.0;
    const maxStep = 22.0;
    final y = area.globalToLocal(pointer).dy;

    double step = 0;
    if (y < zone) {
      // Perto do topo: a lista é invertida, então avançar o offset mostra
      // mensagens mais ANTIGAS.
      step = maxStep * ((zone - y) / zone).clamp(0.0, 1.0).toDouble();
    } else if (y > area.size.height - zone) {
      final depth = (y - (area.size.height - zone)) / zone;
      step = -maxStep * depth.clamp(0.0, 1.0).toDouble();
    }
    if (step == 0) return;

    try {
      unawaited(
        _scrollOffsetController.animateScroll(
          offset: step,
          duration: const Duration(milliseconds: 40),
          curve: Curves.linear,
        ),
      );
    } catch (e) {
      debugPrint('Falha na rolagem automática: $e');
    }
  }

  /// Aviso "Mensagem movida" com a opção de voltar à posição original.
  void _showUndoSnack(String messageId, int originalIndex) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('Mensagem movida'),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Desfazer',
            onPressed: () async {
              try {
                await ref
                    .read(conversationRepositoryProvider)
                    .reorderMessage(messageId, originalIndex);
                if (mounted) _flashHighlight(messageId);
              } catch (e) {
                debugPrint('Erro ao desfazer: $e');
                _showSnack('Não foi possível desfazer.');
              }
            },
          ),
        ),
      );
  }

  /// Cartão que segue o dedo + linha de inserção, sobre a lista.
  Widget _buildMoveOverlay(List<Message> messages, Map<String, Tag> tagsById) {
    return Positioned.fill(
      child: IgnorePointer(
        child: ValueListenableBuilder<_MoveVisual?>(
          valueListenable: _move,
          builder: (context, visual, _) {
            final id = _moveId;
            if (!_moveActive || visual == null || id == null) {
              return const SizedBox.shrink();
            }
            final moved = messages.where((m) => m.id == id).firstOrNull;
            if (moved == null) return const SizedBox.shrink();

            return Stack(
              children: [
                if (visual.lineY != null)
                  Positioned(
                    left: 8,
                    right: 8,
                    top: visual.lineY! - 1.5,
                    height: 3,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                Positioned(
                  left: 16,
                  right: 16,
                  top: visual.previewTop,
                  height: _previewHeight,
                  child: _MovePreview(
                    message: moved,
                    tag: tagsById[moved.tagId],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
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
    final messages = ref
        .read(messagesStreamProvider(widget.conversationId))
        .valueOrNull;
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
    _autoScrollTimer?.cancel();
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
              PopupMenuItem(
                value: 'debug_first',
                child: Text('[teste] Ir ao início'),
              ),
              PopupMenuItem(
                value: 'debug_last',
                child: Text('[teste] Ir ao fim'),
              ),
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
            ),
            ListTile(
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
    final conversationAsync = ref.watch(
      conversationByIdProvider(widget.conversationId),
    );
    final messagesAsync = ref.watch(
      messagesStreamProvider(widget.conversationId),
    );
    final tagsById = <String, Tag>{
      for (final t
          in ref
              .watch(tagsStreamProvider(widget.conversationId))
              .maybeWhen(data: (tags) => tags, orElse: () => const <Tag>[]))
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
                return Stack(
                  key: _listAreaKey,
                  children: [
                    ScrollablePositionedList.builder(
                      itemScrollController: _itemScrollController,
                      scrollOffsetController: _scrollOffsetController,
                      reverse: true,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 12,
                      ),
                      itemCount: messages.length,
                      itemBuilder: (context, displayIndex) {
                        // Lista invertida: converte para o índice cronológico da mensagem.
                        final index = messages.length - 1 - displayIndex;
                        final message = messages[index];
                        final dimmed = _moveActive && message.id == _moveId;

                        return _ItemProbe(
                          index: index,
                          registry: _probes,
                          keepAlive: _moveActive && message.id == _moveId,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onLongPressStart: (_) =>
                                HapticFeedback.mediumImpact(),
                            onLongPressMoveUpdate: (d) =>
                                _onMoveUpdate(message, d),
                            onLongPressEnd: (_) => _onPressEnd(message),
                            onLongPressCancel: _onPressCancel,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              decoration: BoxDecoration(
                                color: message.id == _highlightedId
                                    ? Theme.of(context).colorScheme.primary
                                          .withValues(alpha: 0.18)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Opacity(
                                opacity: dimmed ? 0.35 : 1.0,
                                child: Dismissible(
                                  key: ValueKey(message.id),
                                  direction: DismissDirection.horizontal,
                                  dismissThresholds: const {
                                    DismissDirection.startToEnd: 0.25,
                                    DismissDirection.endToStart: 0.25,
                                  },
                                  background: const _TagSwipeBackground(),
                                  secondaryBackground:
                                      const _DetailsSwipeBackground(),
                                  confirmDismiss: (direction) async {
                                    HapticFeedback.lightImpact();
                                    // Sem await: a linha volta ao lugar na hora.
                                    if (direction ==
                                        DismissDirection.startToEnd) {
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
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    _buildMoveOverlay(messages, tagsById),
                  ],
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
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
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

class _Drop {
  final int index;
  final double? lineY; // Y global da linha de inserção
  const _Drop({required this.index, this.lineY});
}

/// O que o overlay desenha (já em coordenadas locais da lista).
class _MoveVisual {
  final int dropIndex;
  final double previewTop;
  final double? lineY;
  const _MoveVisual({
    required this.dropIndex,
    required this.previewTop,
    this.lineY,
  });
}

/// Registra a posição na tela de cada linha montada da lista, para o modo
/// mover descobrir onde a mensagem cairia. Com [keepAlive], a linha não é
/// descartada ao sair da tela (a linha segurada precisa sobreviver à
/// rolagem automática, senão o gesto é cancelado).
class _ItemProbe extends StatefulWidget {
  final int index; // índice cronológico
  final Set<_ItemProbeState> registry;
  final bool keepAlive;
  final Widget child;

  const _ItemProbe({
    required this.index,
    required this.registry,
    required this.keepAlive,
    required this.child,
  });

  @override
  State<_ItemProbe> createState() => _ItemProbeState();
}

class _ItemProbeState extends State<_ItemProbe>
    with AutomaticKeepAliveClientMixin {
  int get index => widget.index;

  @override
  bool get wantKeepAlive => widget.keepAlive;

  @override
  void initState() {
    super.initState();
    widget.registry.add(this);
  }

  @override
  void didUpdateWidget(covariant _ItemProbe oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.keepAlive != widget.keepAlive) updateKeepAlive();
  }

  @override
  void dispose() {
    widget.registry.remove(this);
    super.dispose();
  }

  Rect? globalRect() {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // exigido pelo AutomaticKeepAliveClientMixin
    return widget.child;
  }
}

/// Cartão compacto que segue o dedo durante o modo mover.
class _MovePreview extends StatelessWidget {
  final Message message;
  final Tag? tag;
  const _MovePreview({required this.message, required this.tag});

  IconData get _icon {
    switch (message.tipo) {
      case MessageType.texto:
        return Icons.chat_bubble_outline;
      case MessageType.imagem:
        return Icons.image_outlined;
      case MessageType.video:
        return Icons.videocam_outlined;
      case MessageType.audio:
        return Icons.audiotrack_outlined;
      case MessageType.documento:
        return Icons.insert_drive_file_outlined;
    }
  }

  String get _label {
    if (message.tipo == MessageType.texto) {
      final firstLine = (message.conteudoTexto ?? '').trim().split('\n').first;
      return firstLine.isEmpty ? 'Mensagem' : firstLine;
    }
    return message.arquivoNomeExibicao ?? 'Arquivo';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      elevation: 8,
      color: scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 6,
            color: tag != null ? tagColorFromHex(tag!.cor) : scheme.primary,
          ),
          const SizedBox(width: 10),
          Icon(_icon, size: 20, color: scheme.onSurface),
          const SizedBox(width: 8),
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(_label, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
    );
  }
}
