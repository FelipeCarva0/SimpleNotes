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
import '../widgets/highlighted_text.dart';
import '../search/message_filter.dart';
import '../models/conversation.dart';
import 'search_results_screen.dart';
import '../providers/security_providers.dart';
import '../widgets/tag_picker_many_sheet.dart';
import '../repositories/new_message.dart';
import 'destination_picker_screen.dart';
import '../repositories/conversation_repository.dart';
import '../services/share_service.dart';
import 'package:share_plus/share_plus.dart' show ShareResult, ShareResultStatus;

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

class _ChatScreenState extends ConsumerState<ChatScreen>
    with WidgetsBindingObserver {
  final _controller = TextEditingController();
  final _itemScrollController = ItemScrollController();
  String? _highlightedId;
  Timer? _highlightTimer;
  Timer? _debounce;
  static const double _previewHeight = 48;
  final _listAreaKey = GlobalKey();
  final Set<_ItemProbeState> _probes = {};
  bool _moveActive = false;
  String? _moveId;
  final ValueNotifier<_MoveVisual?> _move = ValueNotifier(null);
  final _scrollOffsetController = ScrollOffsetController();
  Timer? _autoScrollTimer;
  Offset? _lastPointer;
  int? _lastDropIndex;
  bool _searchActive = false;
  String _searchQuery = '';
  List<SearchHit> _hits = const [];
  int _currentHit = 0; // índice em _hits
  int _currentOccurrence = 0; // índice em _hits[_currentHit].matches
  bool _selecting = false;
  final Set<String> _selectedIds = {};
  String? _anchorId;
    bool _draftLoaded = false;
  bool _sendingAttachment = false;
  int _batchTotal = 0;
  int _batchSent = 0;
  bool _batchCancelled = false;
  static const int _pageSize = 100;
  final List<Message> _ordered = [];
  final Set<String> _ids = {};
  int _limit = _pageSize;
  int _totalCount = 0;
  bool _preloading = false;
  bool _disposed = false;
  bool _paginationReady = false;
  Completer<void>? _pageSignal;
  StreamSubscription<List<Message>>? _pageSub;
  StreamSubscription<int>? _countSub;
  bool _protected = false; 
  bool _locked = false;
  final _positionsListener = ItemPositionsListener.create();

  void _enterSelection(Message message) {
    if (_selecting) return;
    setState(() {
      _selecting = true;
      _selectedIds.add(message.id);
      _anchorId = message.id;
      _searchActive = false;
      _searchQuery = '';
      _hits = const [];
      _currentHit = 0;
      _currentOccurrence = 0;
    });
    HapticFeedback.selectionClick();
  }

  void _exitSelection() {
    if (!_selecting) return;
    setState(() {
      _selecting = false;
      _selectedIds.clear();
      _anchorId = null;
    });
  }

  void _toggleSelected(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
      if (_selectedIds.isEmpty) {
        _selecting = false;
        _anchorId = null;
      }
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadInitialDraft();
    _initPagination();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_protected) return;

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      final shield = ref.read(appLockShieldProvider);
      if (shield.isProtecting) return;

      _discardDecryptedContent();
    } else if (state == AppLifecycleState.resumed) {
      // Sprint 7 (7.1e): mesmo que `_locked` tenha ficado false (o escudo
      // "protegeu" o `paused`), se o repositório não tem mais a chave
      // (ex.: `onGraceExpired` chamou `lockAll()`), descarta e volta.
      if (_locked ||
          !ref
              .read(conversationRepositoryProvider)
              .isUnlocked(widget.conversationId)) {
        _discardDecryptedContent();
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }

  /// Sprint 7 (7.1e) — extraído para reuso entre `paused` e `resumed`.
  void _discardDecryptedContent() {
    _pageSub?.cancel();
    _countSub?.cancel();
    ref.invalidate(messagesStreamProvider(widget.conversationId));
    if (!mounted) return;
    setState(() {
      _locked = true;
      _ordered.clear();
      _ids.clear();
      _hits = const [];
      _searchActive = false;
      _searchQuery = '';
      // Sprint 7 (7.2a) — invariante 17: seleção morre quando a conversa
      // bloqueia.
      _selecting = false;
      _selectedIds.clear();
      _anchorId = null;
    });
  }

  Future<void> _loadInitialDraft() async {
    final conversation = await ref
        .read(conversationRepositoryProvider)
        .getById(widget.conversationId);
    if (!mounted) return;
    setState(() {
      _controller.text = conversation?.rascunho ?? '';
      _protected = conversation?.protegidoPorSenha ?? false;
      _draftLoaded = true;
    });
  }

  Future<void> _initPagination() async {
    if (!mounted || _disposed) return;
    _countSub?.cancel();
    _countSub = ref
        .read(conversationRepositoryProvider)
        .watchMessageCount(widget.conversationId)
        .listen((n) {
          if (_disposed || !mounted) return;
          _totalCount = n; // sem setState: só alimenta as travas da paginação
        });
    _subscribe();
    _positionsListener.itemPositions.addListener(_onPositionsChanged);
  }

  /// (Re)assina a janela das [_limit] mensagens mais recentes. O stream do
  /// drift continua observando o banco, então toda mudança nessa janela
  /// chega em [_onPage].
  void _subscribe() {
    _pageSub?.cancel();
    _pageSub = ref
        .read(conversationRepositoryProvider)
        .watchMessagesPaginated(widget.conversationId, limit: _limit, offset: 0)
        .listen(
          _onPage,
          onError: (Object e) {
            debugPrint('Erro no stream de mensagens: $e');
            _preloading = false;
            _pageSignal?.complete();
            _pageSignal = null;
          },
        );
  }

  /// Cada emissão é a verdade atual da janela: substitui a lista inteira.
  void _onPage(List<Message> page) {
    if (_disposed || !mounted || _locked) return;

    final sorted = [...page]..sort((a, b) => a.position.compareTo(b.position));

    // Mensagem realmente nova no fim (envio/anexo) => rola para o fim.
    final newestId = sorted.isEmpty ? null : sorted.last.id;
    final hasNewAtEnd =
        _paginationReady && newestId != null && !_ids.contains(newestId);

    setState(() {
      _ordered
        ..clear()
        ..addAll(sorted);
      _ids
        ..clear()
        ..addAll(sorted.map((m) => m.id));
      _preloading = false;
      _paginationReady =
          true; // só depois da 1ª emissão (evita o "vazio" falso)
    });

    _pageSignal?.complete();
    _pageSignal = null;

    if (hasNewAtEnd) _scrollToBottomOnNextFrame();
  }

  /// Amplia a janela em mais uma página.
  void _loadMore() {
    if (_preloading || _limit >= _totalCount) return;
    _preloading = true;
    _limit += _pageSize;
    _subscribe();
  }

  int get _loadedCount => _ordered.length;

  void _onPositionsChanged() {
    final positions = _positionsListener.itemPositions.value;
    if (positions.isEmpty) return;

    // Lista invertida: índice 0 = mais nova; o MAIOR índice visível é a
    // mensagem mais antiga na tela. Quando ela chega perto do fim da janela
    // carregada, amplia a janela em mais uma página.
    final maxVisible = positions
        .map((p) => p.index)
        .reduce((a, b) => a > b ? a : b);

    if (maxVisible >= _loadedCount - 20) {
      _loadMore();
    }
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

    _debounce?.cancel();
    try {
      final repo = ref.read(conversationRepositoryProvider);
      await repo.saveDraft(widget.conversationId, _controller.text);
      await repo.sendDraft(widget.conversationId);
    } on StateError catch (e) {
      _showSnack(e.message);
      return; // mantém o texto no campo
    }
    _controller.clear();
    _scrollToBottomOnNextFrame();
  }

  Future<void> _onAttachPressed() async {
    if (_sendingAttachment) return;

    final action = await showAttachmentPickerSheet(context);
    if (action == null || !mounted) return;

    final service = ref.read(attachmentServiceProvider);
    final shield = ref.read(appLockShieldProvider);

    final isCapture =
        action == AttachmentAction.camera || action == AttachmentAction.video;

    if (isCapture) await service.markPendingCapture(widget.conversationId);

    try {
      // Sprint 7 (7.3): todos os pickers rodam dentro do escudo (Z1 não
      // re-bloqueia durante a escolha).
      if (action == AttachmentAction.camera) {
        final picked = await shield.run(service.takePhoto);
        if (picked == null || !mounted) return;
        await _sendPicked(picked);
      } else if (action == AttachmentAction.video) {
        final picked = await shield.run(service.recordVideo);
        if (picked == null || !mounted) return;
        await _sendPicked(picked);
      } else if (action == AttachmentAction.gallery) {
        final picked = await shield.run(service.pickMultipleMedia);
        if (picked.isEmpty || !mounted) return;
        await _sendPickedMany(picked);
      } else if (action == AttachmentAction.audioRecord) {
        final picked = await _recordAudio(service);
        if (picked == null || !mounted) return;
        await _sendPicked(picked);
      } else if (action == AttachmentAction.audioFile) {
        final picked = await shield.run(service.pickMultipleAudioFiles);
        if (picked.isEmpty || !mounted) return;
        await _sendPickedMany(picked);
      } else if (action == AttachmentAction.document) {
        final picked = await shield.run(service.pickMultipleDocuments);
        if (picked.isEmpty || !mounted) return;
        await _sendPickedMany(picked);
      }
    } on AttachmentPermissionException catch (e) {
      _showSnack(e.message);
    } catch (e) {
      _showSnack('Não foi possível anexar.');
      debugPrint('Erro ao anexar: $e');
    } finally {
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
      _totalCount = await ref
          .read(conversationRepositoryProvider)
          .countMessages(widget.conversationId);
      _scrollToBottomOnNextFrame();
    } finally {
      // Apaga o temporário (gravação) já copiado para o storage do app.
      if (picked.isTemporary && await picked.file.exists()) {
        await picked.file.delete();
      }
      if (mounted) setState(() => _sendingAttachment = false);
    }
  }

  /// Envia N anexos escolhidos de uma vez, em **lotes de 10** via
  /// [ConversationRepository.appendMessages] (7.1a). Cada lote é atômico;
  /// falha em um lote não desfaz os anteriores.
  ///
  /// Comportamento:
  /// - Progresso "N de M" no [LinearProgressIndicator] com botão
  ///   **Cancelar**.
  /// - `isCancelled` consultado entre lotes; se o usuário cancelar,
  ///   os lotes já enviados **permanecem** e o resto é descartado.
  /// - Se o envio de um lote lançar, os anteriores **permanecem**, o
  ///   lote que falhou **não** entra (atomicidade interna do
  ///   `appendMessages`), e o resto **não** é tentado.
  /// - Temporários (`isTemporary`) apagados no `finally`.
  ///
  /// Ordem final = ordem de seleção; todas com a data de hoje (regra
  /// do plano: "todas com a data do momento da inclusão, na ordem de
  /// seleção").
  Future<void> _sendPickedMany(List<PickedAttachment> picked) async {
    if (picked.isEmpty) return;
    if (_sendingAttachment) return;

    final repo = ref.read(conversationRepositoryProvider);
    const batchSize = 10;

    final total = picked.length;
    var sent = 0;
    var failed = false;

    setState(() {
      _sendingAttachment = true;
      _batchCancelled = false;
      _batchTotal = total;
      _batchSent = 0;
    });

    try {
      for (var start = 0; start < total; start += batchSize) {
        if (_batchCancelled) break;
        final end = (start + batchSize) > total ? total : start + batchSize;
        final chunk = picked.sublist(start, end);

        try {
          final items = chunk
              .map(
                (p) => NewMessage.arquivo(
                  tipo: p.tipo,
                  arquivo: p.file,
                  nomeOriginal: p.nomeOriginal,
                ),
              )
              .toList();

          await repo.appendMessages(
            widget.conversationId,
            items,
            isCancelled: () => _batchCancelled,
          );
          sent += chunk.length;
          if (mounted) {
            setState(() => _batchSent = sent);
          }
        } catch (e) {
          debugPrint('Erro ao enviar lote: $e');
          failed = true;
          break;
        }
      }
    } finally {
      for (final p in picked) {
        if (p.isTemporary && await p.file.exists()) {
          try {
            await p.file.delete();
          } catch (_) {
            /* ignora */
          }
        }
      }
      if (mounted) {
        setState(() {
          _sendingAttachment = false;
          _batchTotal = 0;
          _batchSent = 0;
          // não zera `_batchCancelled` aqui: o feedback final ainda lê o
          // valor; zera no próximo envio (setState acima).
        });
      }
    }

    if (!mounted) return;

    if (sent == total) {
      _scrollToBottomOnNextFrame();
    } else if (_batchCancelled) {
      _showSnack('Cancelado. $sent de $total enviados.');
    } else if (failed) {
      _showSnack('Falha no envio. $sent de $total enviados.');
    }
  }

  void _showSnack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  /// Todas as mensagens da conversa, esperando o carregamento terminar.
  /// Usado só pelas buscas (que precisam da conversa inteira, fora da janela
  /// paginada). Nunca devolve "vazio por ainda estar carregando".
  Future<List<Message>> _loadAllMessages() {
    return ref.read(messagesStreamProvider(widget.conversationId).future);
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

  /// Sprint 6: se a mensagem alvo ainda não está carregada (página muito
  /// distante), pagina até incluí-la, então rola.
  Future<void> _goToMessage({
    required int index,
    required int total,
    required String messageId,
  }) async {
    if (_disposed || !mounted) return;

    // Alvo fora da janela: amplia a janela até cobrir a conversa e espera
    // a emissão + o frame em que a lista é reconstruída.
    if (!_ids.contains(messageId)) {
      final signal = Completer<void>();
      _pageSignal = signal;
      _limit = _totalCount;
      _preloading = true;
      _subscribe();
      await signal.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () {},
      );
      if (_disposed || !mounted) return;
      await WidgetsBinding.instance.endOfFrame;
      if (_disposed || !mounted) return;
    }

    final idx = _ordered.indexWhere((m) => m.id == messageId);
    if (idx < 0) return;
    if (!_itemScrollController.isAttached) return;

    _itemScrollController.scrollTo(
      index: _ordered.length - 1 - idx,
      alignment: 0.4,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
    _flashHighlight(messageId);
  }

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
    if (_ordered.isEmpty) return;
    _updateMove(d.globalPosition, _ordered);
  }

  /// Soltou o dedo: se estava movendo, grava; senão, abre o menu de ações.
  void _onPressEnd(Message message) {
    if (_moveActive) {
      _finishMove();
    } else {
      _enterSelection(message);
    }
  }

  void _onPressCancel() {
    if (_moveActive) _resetMove();
  }

  Future<void> _finishMove() async {
    final id = _moveId;
    final windowTarget = _move.value?.dropIndex;
    try {
      if (id != null && windowTarget != null) {
        // Índice da janela -> índice global da conversa.
        final total = _totalCount < _ordered.length
            ? _ordered.length
            : _totalCount;
        final hiddenOlder = total - _ordered.length;
        final target = windowTarget + hiddenOlder;

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

    if (_ordered.isEmpty) return;

    _updateMove(pointer, _ordered);

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

  /// Sprint 7 (7.2a-fix) — itens do `⋮` durante a seleção.
  /// Regras:
  /// - Ações em lote (Copiar/Compartilhar/Encaminhar/Excluir/Tag/Data)
  ///   só fazem sentido com pelo menos 1 mensagem selecionada.
  /// - Ações individuais (Editar texto/Renomear/Substituir) só com
  ///   exatamente 1 selecionada, e conforme o tipo dela.
  List<PopupMenuEntry<String>> _buildSelectionMenuItems() {
    final n = _selectedIds.length;
    final onlyOne = n == 1 ? _selectedSingleMessage() : null;

    return [
      // Sprint 7 (7.2b) — seleção ampla. Ambos habilitados só quando há
      // âncora (para "até aqui") ou mensagens na conversa (para "tudo").
      PopupMenuItem(
        value: 'select_to_anchor',
        enabled: _anchorId != null,
        child: const ListTile(
          leading: Icon(Icons.unfold_more),
          title: Text('Selecionar até aqui'),
          contentPadding: EdgeInsets.zero,
        ),
      ),
      PopupMenuItem(
        value: 'select_all',
        enabled: _ordered.isNotEmpty || _totalCount > 0,
        child: const ListTile(
          leading: Icon(Icons.select_all),
          title: Text('Selecionar tudo'),
          contentPadding: EdgeInsets.zero,
        ),
      ),
      const PopupMenuDivider(),
      PopupMenuItem(
        value: 'copy',
        enabled: n > 0,
        child: const ListTile(
          leading: Icon(Icons.copy_outlined),
          title: Text('Copiar'),
          contentPadding: EdgeInsets.zero,
        ),
      ),
      PopupMenuItem(
        value: 'share',
        enabled: n > 0,
        child: const ListTile(
          leading: Icon(Icons.share_outlined),
          title: Text('Compartilhar'),
          contentPadding: EdgeInsets.zero,
        ),
      ),
      PopupMenuItem(
        value: 'forward',
        enabled: n > 0,
        child: const ListTile(
          leading: Icon(Icons.forward_outlined),
          title: Text('Encaminhar'),
          contentPadding: EdgeInsets.zero,
        ),
      ),
      PopupMenuItem(
        value: 'tag',
        enabled: n > 0,
        child: const ListTile(
          leading: Icon(Icons.label_outline),
          title: Text('Definir tag'),
          contentPadding: EdgeInsets.zero,
        ),
      ),
      PopupMenuItem(
        value: 'date',
        enabled: n > 0,
        child: const ListTile(
          leading: Icon(Icons.event_outlined),
          title: Text('Editar data'),
          contentPadding: EdgeInsets.zero,
        ),
      ),
      // Ações individuais: só com 1 selecionada.
      if (onlyOne != null && onlyOne.tipo == MessageType.texto)
        const PopupMenuItem(
          value: 'edit_text',
          child: ListTile(
            leading: Icon(Icons.edit_outlined),
            title: Text('Editar texto'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      if (onlyOne != null && onlyOne.tipo != MessageType.texto) ...[
        const PopupMenuItem(
          value: 'rename_file',
          child: ListTile(
            leading: Icon(Icons.drive_file_rename_outline),
            title: Text('Renomear arquivo'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const PopupMenuItem(
          value: 'replace_file',
          child: ListTile(
            leading: Icon(Icons.swap_horiz),
            title: Text('Substituir arquivo'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
      const PopupMenuDivider(),
      PopupMenuItem(
        value: 'delete',
        enabled: n > 0,
        child: const ListTile(
          leading: Icon(Icons.delete_outline),
          title: Text('Excluir'),
          contentPadding: EdgeInsets.zero,
        ),
      ),
    ];
  }

  /// Mensagem única da seleção (se houver exatamente 1).
  Message? _selectedSingleMessage() {
    if (_selectedIds.length != 1) return null;
    final id = _selectedIds.first;
    for (final m in _ordered) {
      if (m.id == id) return m;
    }
    return null;
  }

  Future<void> _onSelectionMenuSelected(String value) async {
    switch (value) {
      // Sprint 7 (7.2b) — seleção ampla. NÃO saem da seleção: o usuário
      // acabou de ampliá-la; faz sentido continuar no modo.
      case 'select_to_anchor':
        _selectRangeToAnchor();
        return;
      case 'select_all':
        await _selectAll();
        return;

      case 'edit_text':
        final m = _selectedSingleMessage();
        if (m != null) await _editMessage(m);
      case 'rename_file':
        final m = _selectedSingleMessage();
        if (m != null) await _renameAttachment(m);
      case 'replace_file':
        final m = _selectedSingleMessage();
        if (m != null) await _replaceAttachment(m);
      case 'date':
        await _editDateMany();
      case 'tag':
        await _tagMany();
      case 'delete':
        await _deleteMany();
      case 'copy':
        await _copySelected();
      case 'forward':
        await _forwardSelected();
      case 'share':
         await _shareSelected();
    }
    // Após qualquer ação **destrutiva/de conteúdo** via `⋮` em seleção,
    // sair da seleção (comportamento consolidado). As ações de "seleção
    // ampla" acima já deram `return` antes, mantendo o modo.
    if (mounted) _exitSelection();
  }


  /// Copia o **texto** das mensagens de texto selecionadas, em ordem de
  /// `position`, separadas por linha em branco. Mídia é ignorada com
  /// aviso (S7-6: copiar binário não é confiável no Flutter).
  ///
  /// Usa `getMessagesByIds` (7.1b) — sobrevive a seleções fora da janela
  /// paginada, porque busca por id no banco.
  Future<void> _copySelected() async {
    if (_selectedIds.isEmpty) return;
    final repo = ref.read(conversationRepositoryProvider);

    List<Message> messages;
    try {
      messages = await repo.getMessagesByIds(_selectedIds);
    } catch (e) {
      debugPrint('Erro ao buscar mensagens para copiar: $e');
      _showSnack('Não foi possível copiar.');
      return;
    }
    if (!mounted) return;

    final texts = <String>[];
    var mediaCount = 0;
    for (final m in messages) {
      if (m.tipo == MessageType.texto) {
        final t = m.conteudoTexto;
        if (t != null && t.trim().isNotEmpty) texts.add(t);
      } else {
        mediaCount++;
      }
    }

    if (texts.isEmpty) {
      _showSnack(
        mediaCount > 0
            ? 'Nenhum texto para copiar (só mídia selecionada).'
            : 'Nada para copiar.',
      );
      return;
    }

    await Clipboard.setData(ClipboardData(text: texts.join('\n\n')));
    if (!mounted) return;

    final n = texts.length;
    final base =
        '$n ${n == 1 ? 'mensagem de texto copiada' : 'mensagens de texto copiadas'}';
    _showSnack(
      mediaCount > 0
          ? '$base. $mediaCount ${mediaCount == 1 ? 'arquivo não copiado' : 'arquivos não copiados'}.'
          : '$base.',
    );
  }

  /// Marca, na janela carregada, todas as mensagens entre `_anchorId` e a
  /// **última selecionada** (inclusive). Se `_anchorId` não estiver na
  /// janela (mensagem muito antiga, ainda não paginada), avisa.
  ///
  /// Não busca no banco: opera só sobre `_ordered` (a janela). Para
  /// alcançar fora da janela, use "Selecionar tudo".
  void _selectRangeToAnchor() {
    final anchor = _anchorId;
    if (anchor == null) {
      _showSnack('Sem âncora: selecione uma mensagem primeiro.');
      return;
    }

    final anchorIdx = _ordered.indexWhere((m) => m.id == anchor);
    if (anchorIdx < 0) {
      _showSnack(
        'A âncora não está na janela atual. Role a lista ou use '
        '"Selecionar tudo".',
      );
      return;
    }

    // Fim do intervalo: a última selecionada por ordem de `position`
    // (garante que "até aqui" se estenda até o ponto mais recente que o
    // usuário tocou, não importa a ordem de cliques).
    int? endIdx;
    if (_selectedIds.isNotEmpty) {
      final selectedInWindow = _ordered
          .asMap()
          .entries
          .where((e) => _selectedIds.contains(e.value.id))
          .map((e) => e.key)
          .toList();
      if (selectedInWindow.isNotEmpty) {
        endIdx = selectedInWindow.reduce((a, b) => a > b ? a : b);
      }
    }
    endIdx ??= anchorIdx;

    final lo = anchorIdx < endIdx ? anchorIdx : endIdx;
    final hi = anchorIdx < endIdx ? endIdx : anchorIdx;

    setState(() {
      for (var i = lo; i <= hi; i++) {
        _selectedIds.add(_ordered[i].id);
      }
    });
    HapticFeedback.selectionClick();
  }

  void _cancelBatch() {
    // Setar um flag que o loop de `_sendPickedMany` consulta.
    _batchCancelled = true;
  }
    /// Sprint 7 (7.5) — compartilha as mensagens selecionadas via share
  /// sheet do sistema. Aviso S7-8 quando a origem é protegida (os
  /// metadados vão para fora em claro). Roda dentro do `AppLockShield`
  /// para o Z1 não fechar a conversa no meio do share.
  Future<void> _shareSelected() async {
    if (_selectedIds.isEmpty) return;

    final repo = ref.read(conversationRepositoryProvider);

    // Busca as mensagens (decifradas, em ordem de position).
    List<Message> messages;
    try {
      messages = await repo.getMessagesByIds(_selectedIds);
    } catch (e) {
      debugPrint('Erro ao buscar mensagens para compartilhar: $e');
      _showSnack('Não foi possível compartilhar.');
      return;
    }
    if (messages.isEmpty || !mounted) return;

    // Aviso S7-8 se a origem é protegida.
    final sourceConv = await repo.getById(widget.conversationId);
    if (!mounted) return;
    if (sourceConv?.protegidoPorSenha == true) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Compartilhar de conversa protegida?'),
          content: const Text(
            'Os textos e nomes dos arquivos serão enviados para outro '
            'aplicativo, fora da criptografia desta conversa.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Compartilhar'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    // Executa dentro do escudo (picker/share põe o app em paused).
    final shareService = ref.read(shareServiceProvider);
    final shield = ref.read(appLockShieldProvider);

    ShareResult? result;
    try {
      result = await shield.run(() => shareService.shareMessages(messages));
    } catch (e) {
      debugPrint('Erro ao compartilhar: $e');
      if (mounted) _showSnack('Não foi possível compartilhar.');
      return;
    }
    if (!mounted) return;

    _exitSelection();

    // Feedback opcional: só informa em caso de erro do plugin.
    if (result != null && result.status == ShareResultStatus.unavailable) {
      _showSnack('Nenhum aplicativo disponível para receber o conteúdo.');
    }
  }

    /// Sprint 7 (7.4) — encaminha as mensagens selecionadas para outra
  /// conversa. Passos:
  /// 1. `DestinationPickerScreen` (com a origem desabilitada).
  /// 2. `showForwardOptionsDialog` (data/tag + aviso S7-8).
  /// 3. `forwardMessages` no destino (repositório).
  /// 4. Snack com resumo + "Abrir conversa".
  Future<void> _forwardSelected() async {
    if (_selectedIds.isEmpty) return;

    // 1) Escolher destino.
    final destinationId = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => DestinationPickerScreen(
          disabledConversationId: widget.conversationId,
          subtitle:
              '${_selectedIds.length} ${_selectedIds.length == 1 ? "mensagem selecionada" : "mensagens selecionadas"}',
        ),
      ),
    );
    if (destinationId == null || !mounted) return;

    // 2) Opções + aviso de segurança.
    final destConv = await ref
        .read(conversationRepositoryProvider)
        .getById(destinationId);
    if (destConv == null || !mounted) {
      _showSnack('Conversa de destino indisponível.');
      return;
    }
    final sourceConv = await ref
        .read(conversationRepositoryProvider)
        .getById(widget.conversationId);
    if (sourceConv == null || !mounted) return;

    final options = await showForwardOptionsDialog(
      context,
      messageCount: _selectedIds.length,
      sourceProtected: sourceConv.protegidoPorSenha,
      destinationProtected: destConv.protegidoPorSenha,
    );
    if (options == null || !mounted) return;

    // 3) Executa.
    final repo = ref.read(conversationRepositoryProvider);
    ForwardResult result;
    try {
      result = await repo.forwardMessages(
        destinationConversationId: destinationId,
        messageIds: _selectedIds,
        keepOriginalDate: options.keepOriginalDate,
        carryTag: options.carryTag,
      );
    } catch (e) {
      debugPrint('Erro ao encaminhar: $e');
      _showSnack('Não foi possível encaminhar.');
      return;
    }
    if (!mounted) return;

    // 4) Feedback.
    _exitSelection();

    final forwarded = result.forwardedCount;
    final skipped = result.skippedCount;
    final base =
        '$forwarded ${forwarded == 1 ? "mensagem encaminhada" : "mensagens encaminhadas"}';
    final skipMsg = skipped > 0
        ? ' ($skipped ${skipped == 1 ? "ignorada" : "ignoradas"}: arquivo indisponível)'
        : '';

    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('$base$skipMsg em "${destConv.titulo}".'),
          action: SnackBarAction(
            label: 'Abrir',
            onPressed: () {
              if (!mounted) return;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatScreen(conversationId: destinationId),
                ),
              );
            },
          ),
          duration: const Duration(seconds: 6),
        ),
      );
  }

  /// Marca todas as mensagens reais da conversa, inclusive as fora da
  /// janela. Usa `getMessageIds` (7.1b) — só ids, sem conteúdo.
  ///
  /// Em conversa protegida, também funciona: `getMessageIds` não decifra
  /// nada, só lê `id`s ordenados por `position`.
  Future<void> _selectAll() async {
    final repo = ref.read(conversationRepositoryProvider);
    try {
      final ids = await repo.getMessageIds(widget.conversationId);
      if (!mounted) return;
      if (ids.isEmpty) {
        _showSnack('Nenhuma mensagem nesta conversa.');
        return;
      }
      setState(() {
        _selectedIds
          ..clear()
          ..addAll(ids);
        // Em "selecionar tudo" a âncora perde sentido: qualquer "até
        // aqui" posterior seria a mensagem inteira de novo.
        _anchorId = null;
      });
      _showSnack(
        '${ids.length} ${ids.length == 1 ? 'mensagem selecionada' : 'mensagens selecionadas'}.',
      );
    } catch (e) {
      debugPrint('Erro ao selecionar tudo: $e');
      _showSnack('Não foi possível selecionar tudo.');
    }
  }

  Future<void> _tagMany() async {
    if (_selectedIds.isEmpty) return;
    final choice = await showTagPickerManySheet(
      context,
      conversationId: widget.conversationId,
      count: _selectedIds.length,
    );
    if (choice == null || !mounted) return;
    if (choice.tagId == null && !choice.clear) return; // cancelado

    try {
      await ref
          .read(conversationRepositoryProvider)
          .setMessageTagMany(_selectedIds, choice.clear ? null : choice.tagId);
      if (!mounted) return;
      _showSnack(
        choice.clear
            ? 'Tag removida de ${_selectedIds.length} mensagens.'
            : 'Tag aplicada a ${_selectedIds.length} mensagens.',
      );
    } catch (e) {
      debugPrint('Erro ao aplicar tag em lote: $e');
      _showSnack('Não foi possível aplicar a tag.');
    }
  }

  /// Edita a data de várias mensagens de uma vez (`setMessageDateMany`).
  Future<void> _editDateMany() async {
    if (_selectedIds.isEmpty) return;
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'Nova data para as mensagens',
    );
    if (picked == null || !mounted) return;

    try {
      await ref
          .read(conversationRepositoryProvider)
          .setMessageDateMany(_selectedIds, picked);
      if (!mounted) return;
      _showSnack('Data alterada em ${_selectedIds.length} mensagens.');
    } catch (e) {
      debugPrint('Erro ao alterar data em lote: $e');
      _showSnack('Não foi possível alterar a data.');
    }
  }

  /// Exclui várias mensagens (`deleteMessagesMany`, com blocagem de 500
  /// ids internamente — 7.1c). Confirmação conta mensagens.
  Future<void> _deleteMany() async {
    if (_selectedIds.isEmpty) return;
    final count = _selectedIds.length;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Excluir $count ${count == 1 ? 'mensagem' : 'mensagens'}?'),
        content: const Text('Essa ação não pode ser desfeita.'),
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

    try {
      await ref
          .read(conversationRepositoryProvider)
          .deleteMessagesMany(_selectedIds);
      if (!mounted) return;
      _showSnack(
        '$count ${count == 1 ? 'mensagem excluída' : 'mensagens excluídas'}.',
      );
    } catch (e) {
      debugPrint('Erro ao excluir em lote: $e');
      _showSnack('Não foi possível excluir.');
    }
  }

  /// RF05 — abre o sheet "Pesquisar" e executa o modo escolhido.
  /// RF05 — abre o sheet "Pesquisar" e executa o modo escolhido.
  Future<void> _openSearchMenu() async {
    final request = await showSearchOptionsSheet(context);
    if (request == null || !mounted) return;

    switch (request.mode) {
      case SearchMode.goToDate:
        await _searchByDate();
      case SearchMode.wordInConversation:
        await _startWordSearch(request.query ?? '');
      case SearchMode.resultsList:
        await _openResultsList(MessageFilter(text: request.query ?? ''));
      case SearchMode.dateRange:
        await _openDateRangeResults();
    }
  }

  /// RF05 — data simples: vai para a primeira mensagem do dia escolhido.
  Future<void> _searchByDate() async {
    final messages = await _loadAllMessages();
    if (!mounted) return;
    if (messages.isEmpty) {
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


  Future<void> _startWordSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    final messages = await _loadAllMessages();
    if (!mounted) return;
    if (messages.isEmpty) {
      _showSnack('Esta conversa ainda não tem mensagens.');
      return;
    }

    final filter = MessageFilter(text: trimmed);
    final hits = searchMessages(messages, filter);
    if (hits.isEmpty) {
      _showSnack('Nenhuma mensagem com "$trimmed".');
      return;
    }

    setState(() {
      _searchActive = true;
      _searchQuery = trimmed;
      _hits = hits;
      _currentHit = 0;
      _currentOccurrence = 0;
    });

    _goToCurrentOccurrence();
  }

  void _closeWordSearch() {
    if (!_searchActive) return;
    setState(() {
      _searchActive = false;
      _searchQuery = '';
      _hits = const [];
      _currentHit = 0;
      _currentOccurrence = 0;
    });
  }

  /// Quantas ocorrências existem no total (soma de `steps` de cada hit).
  int get _totalOccurrences {
    var n = 0;
    for (final h in _hits) {
      n += h.steps;
    }
    return n;
  }

  /// Posição plana (1-based) da ocorrência atual dentro do total.
  int get _currentOccurrenceFlat {
    var n = 0;
    for (var i = 0; i < _currentHit && i < _hits.length; i++) {
      n += _hits[i].steps;
    }
    n += _currentOccurrence + 1;
    return n;
  }

  void _goToCurrentOccurrence() {
    if (_hits.isEmpty) return;
    final hit = _hits[_currentHit];
    final total =
        ref
            .read(messagesStreamProvider(widget.conversationId))
            .valueOrNull
            ?.length ??
        _hits.length;
    _goToMessage(index: hit.index, total: total, messageId: hit.message.id);
  }

  void _nextOccurrence() {
    if (_hits.isEmpty) return;
    final hit = _hits[_currentHit];
    if (_currentOccurrence + 1 < hit.steps) {
      setState(() => _currentOccurrence++);
    } else if (_currentHit + 1 < _hits.length) {
      setState(() {
        _currentHit++;
        _currentOccurrence = 0;
      });
    } else {
      setState(() {
        _currentHit = 0;
        _currentOccurrence = 0;
      });
    }
    _goToCurrentOccurrence();
  }

  void _previousOccurrence() {
    if (_hits.isEmpty) return;
    if (_currentOccurrence > 0) {
      setState(() => _currentOccurrence--);
    } else if (_currentHit > 0) {
      final prev = _hits[_currentHit - 1];
      setState(() {
        _currentHit--;
        _currentOccurrence = prev.steps - 1;
      });
    } else {
      final last = _hits.length - 1;
      setState(() {
        _currentHit = last;
        _currentOccurrence = _hits[last].steps - 1;
      });
    }
    _goToCurrentOccurrence();
  }

  /// Monta o [SearchHighlight] para uma mensagem. `null` se ela não casou.
  SearchHighlight? _highlightFor(Message message) {
    if (!_searchActive || _hits.isEmpty) return null;
    final hitIdx = _hits.indexWhere((h) => h.message.id == message.id);
    if (hitIdx < 0) return null;
    final hit = _hits[hitIdx];
    return SearchHighlight(
      matches: hit.matches,
      currentMatch: hitIdx == _currentHit ? _currentOccurrence : -1,
      originalNameOnly: hit.matches.isEmpty,
    );
  }


  Future<void> _openResultsList(MessageFilter filter) async {
    final messages = await _loadAllMessages();
    if (!mounted) return;
    if (messages.isEmpty) {
      _showSnack('Esta conversa ainda não tem mensagens.');
      return;
    }

    // Feedback rápido quando o texto não casa com nada (evita abrir uma
    // tela vazia sem explicação).
    if (filter.hasText) {
      final preview = searchMessages(messages, filter);
      if (preview.isEmpty) {
        _showSnack('Nenhuma mensagem com "${filter.text}".');
        return;
      }
    }

    final hit = await Navigator.push<SearchHit>(
      context,
      MaterialPageRoute(
        builder: (_) => SearchResultsScreen(
          conversationId: widget.conversationId,
          initialFilter: filter,
        ),
      ),
    );
    if (hit == null || !mounted) return;

    // `hit.index` é cronológico; `_goToMessage` converte para o índice
    // invertido da lista. Usamos a contagem atual do stream.
    final current =
        ref.read(messagesStreamProvider(widget.conversationId)).valueOrNull ??
        messages;
    _goToMessage(
      index: hit.index,
      total: current.length,
      messageId: hit.message.id,
    );
  }

  Future<void> _openDateRangeResults() async {
    final messages = await _loadAllMessages();
    if (!mounted) return;
    if (messages.isEmpty) {
      _showSnack('Esta conversa ainda não tem mensagens.');
      return;
    }

    // Período coberto pela conversa, calculado sem assumir ordem por data
    // (a data pode ter sido editada manualmente e ficar fora de sequência).
    DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
    var first = dateOnly(messages.first.data);
    var last = first;
    for (final m in messages) {
      final d = dateOnly(m.data);
      if (d.isBefore(first)) first = d;
      if (d.isAfter(last)) last = d;
    }

    final picked = await showDateRangePicker(
      context: context,
      firstDate: first,
      lastDate: last,
      initialDateRange: DateTimeRange(start: first, end: last),
      helpText: 'Faixa de datas',
      saveText: 'Aplicar',
    );
    if (picked == null || !mounted) return;

    final hit = await Navigator.push<SearchHit>(
      context,
      MaterialPageRoute(
        builder: (_) => SearchResultsScreen(
          conversationId: widget.conversationId,
          initialFilter: MessageFilter(from: picked.start, to: picked.end),
        ),
      ),
    );
    if (hit == null || !mounted) return;

    final current =
        ref.read(messagesStreamProvider(widget.conversationId)).valueOrNull ??
        messages;
    _goToMessage(
      index: hit.index,
      total: current.length,
      messageId: hit.message.id,
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
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    _highlightTimer?.cancel();
    _autoScrollTimer?.cancel();
    _disposed = true;
    _countSub?.cancel();
    _pageSub?.cancel();
    _positionsListener.itemPositions.removeListener(_onPositionsChanged);
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

  void _openDetails(Message message, int windowIndex, Tag? tag) {
    if (!mounted) return;

    // Total real; nunca menor que o que já está carregado (o contador
    // pode chegar um instante depois da página).
    final total = _totalCount < _ordered.length ? _ordered.length : _totalCount;
    final hiddenOlder = total - _ordered.length; // mensagens fora da janela
    final position = hiddenOlder + windowIndex + 1;

    showMessageDetailsSheet(
      context,
      message: message,
      tag: tag,
      position: position,
      total: total,
    );
  }

  PreferredSizeWidget _buildNormalAppBar(
    AsyncValue<Conversation?> conversationAsync,
  ) {
    return AppBar(
      title: conversationAsync.when(
        data: (c) => Text(c?.titulo ?? ''),
        loading: () => const Text(''),
        error: (_, _) => const Text('Erro'),
      ),
      actions: [
        // Sprint 7 (7.2a-fix) — `⋮` com sobrecarga: em seleção, mostra
        // ações em lote; fora, mostra o menu normal.
        _AnimatedMoreMenu(
          selecting: _selecting,
          selectedCount: _selectedIds.length,
          // Menu normal
          normalItems: const [
            PopupMenuItem(value: 'search', child: Text('Pesquisar')),
            PopupMenuItem(value: 'tags', child: Text('Gerenciar tags')),
          ],
          onNormalSelected: _onMenuSelected,
          // Menu de seleção
          selectionItems: _buildSelectionMenuItems(),
          onSelectionSelected: _onSelectionMenuSelected,
        ),
      ],
    );
  }

  PreferredSizeWidget _buildSearchAppBar() {
    final total = _totalOccurrences;
    final current = _currentOccurrenceFlat;
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        tooltip: 'Fechar busca',
        onPressed: _closeWordSearch,
      ),
      title: Text('"$_searchQuery"', overflow: TextOverflow.ellipsis),
      actions: [
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              total == 0 ? '0' : '$current de $total',
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.keyboard_arrow_up),
          tooltip: 'Ocorrência anterior',
          onPressed: total == 0 ? null : _previousOccurrence,
        ),
        IconButton(
          icon: const Icon(Icons.keyboard_arrow_down),
          tooltip: 'Próxima ocorrência',
          onPressed: total == 0 ? null : _nextOccurrence,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final conversationAsync = ref.watch(
      conversationByIdProvider(widget.conversationId),
    );

    final tagsById = <String, Tag>{
      for (final tag
          in ref
              .watch(tagsStreamProvider(widget.conversationId))
              .maybeWhen(data: (tags) => tags, orElse: () => const <Tag>[]))
        tag.id: tag,
    };

    return PopScope(
      canPop: !_searchActive && !_selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_selecting) {
          _exitSelection();
        } else if (_searchActive) {
          _closeWordSearch();
        }
      },
      child: Scaffold(
        appBar: _searchActive
            ? _buildSearchAppBar()
            : _buildNormalAppBar(conversationAsync),
        body: Column(
          children: [
            Expanded(
              child: !_paginationReady
                  ? const Center(child: CircularProgressIndicator())
                  : _ordered.isEmpty
                  ? const Center(
                      child: Text(
                        'Nenhuma mensagem ainda. Escreva algo abaixo.',
                      ),
                    )
                  : Stack(
                      key: _listAreaKey,
                      children: [
                        ScrollablePositionedList.builder(
                          itemScrollController: _itemScrollController,
                          scrollOffsetController: _scrollOffsetController,
                          itemPositionsListener: _positionsListener,
                          reverse: true,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 12,
                          ),
                          itemCount: _ordered.length,
                          itemBuilder: (context, displayIndex) {
                            final index = _ordered.length - 1 - displayIndex;
                            final message = _ordered[index];
                            final dimmed = _moveActive && message.id == _moveId;
                            final isSelected = _selectedIds.contains(
                              message.id,
                            );
                            return _ItemProbe(
                              index: index,
                              registry: _probes,
                              keepAlive: _moveActive && message.id == _moveId,
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                // Sprint 7 (7.2a): em modo seleção, o long-press não inicia
                                // reordenar; o toque alterna a seleção.
                                onTap: _selecting
                                    ? () => _toggleSelected(message.id)
                                    : null,
                                onLongPressStart: _selecting
                                    ? null
                                    : (_) => HapticFeedback.mediumImpact(),
                                onLongPressMoveUpdate: _selecting
                                    ? null
                                    : (d) => _onMoveUpdate(message, d),
                                onLongPressEnd: _selecting
                                    ? null
                                    : (_) => _onPressEnd(message),
                                onLongPressCancel: _selecting
                                    ? null
                                    : _onPressCancel,
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Theme.of(context).colorScheme.primary
                                              .withValues(alpha: 0.18)
                                        : (message.id == _highlightedId
                                              ? Theme.of(context)
                                                    .colorScheme
                                                    .primary
                                                    .withValues(alpha: 0.18)
                                              : Colors.transparent),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Opacity(
                                    opacity: dimmed ? 0.35 : 1.0,
                                    child: Dismissible(
                                      key: ValueKey(message.id),
                                      // Sprint 7 (7.2a): swipe desligado durante a seleção.
                                      direction: _selecting
                                          ? DismissDirection.none
                                          : DismissDirection.horizontal,
                                      dismissThresholds: const {
                                        DismissDirection.startToEnd: 0.25,
                                        DismissDirection.endToStart: 0.25,
                                      },
                                      background: const _TagSwipeBackground(),
                                      secondaryBackground:
                                          const _DetailsSwipeBackground(),
                                      confirmDismiss: (direction) async {
                                        HapticFeedback.lightImpact();
                                        if (direction ==
                                            DismissDirection.startToEnd) {
                                          _openTagPicker(message);
                                        } else {
                                          _openDetails(
                                            message,
                                            index,
                                            tagsById[message.tagId],
                                          );
                                        }
                                        return false;
                                      },
                                      child: MessageBubble(
                                        message: message,
                                        tag: tagsById[message.tagId],
                                        highlight: _highlightFor(message),
                                        // Sprint 7 (7.2a): em modo seleção, `onTap` do balão
                                        // não deve abrir editor de texto; o toque é tratado pelo
                                        // GestureDetector externo.
                                        onTap: _selecting
                                            ? null
                                            : (message.tipo == MessageType.texto
                                                  ? () => _editMessage(message)
                                                  : null),
                                        selectionMode: _selecting,
                                        selected: isSelected,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        _buildMoveOverlay(_ordered, tagsById),
                      ],
                    ),
            ),
            if (_sendingAttachment)
              _BatchProgressBar(
                sent: _batchSent,
                total: _batchTotal,
                onCancel: _batchTotal > 0 ? _cancelBatch : null,
              ),
            _Composer(
              controller: _controller,
              enabled: _draftLoaded,
              onChanged: _onDraftChanged,
              onSend: _send,
              onAttach: _sendingAttachment ? null : _onAttachPressed,
            ),
          ],
        ),
      ),
    );
  }
}

/// Sprint 7 (7.3) — barra de progresso determinada "N de M" com Cancelar.
class _BatchProgressBar extends StatelessWidget {
  final int sent;
  final int total;
  final VoidCallback? onCancel;

  const _BatchProgressBar({
    required this.sent,
    required this.total,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    // Determinado quando há total > 0; senão, indeterminado (envio único
    // legado via _sendPicked, que não passa por aqui — defensivo).
    final hasProgress = total > 0;
    final value = hasProgress ? (sent / total).clamp(0.0, 1.0) : null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        LinearProgressIndicator(value: value),
        if (hasProgress)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '$sent de $total',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                if (onCancel != null)
                  TextButton(
                    onPressed: onCancel,
                    child: const Text('Cancelar'),
                  ),
              ],
            ),
          ),
      ],
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

/// Sprint 7 (7.2a-fix) — `⋮` do AppBar com **sobrecarga** durante a seleção.
///
/// Fora da seleção: menu normal (Pesquisar / Gerenciar tags).
/// Em seleção: menu em lote, e o ícone pulsa/realça para sinalizar a
/// sobrecarga de função.
class _AnimatedMoreMenu extends StatefulWidget {
  final bool selecting;
  final int selectedCount;
  final List<PopupMenuEntry<String>> normalItems;
  final void Function(String) onNormalSelected;
  final List<PopupMenuEntry<String>> selectionItems;
  final void Function(String) onSelectionSelected;

  const _AnimatedMoreMenu({
    required this.selecting,
    required this.selectedCount,
    required this.normalItems,
    required this.onNormalSelected,
    required this.selectionItems,
    required this.onSelectionSelected,
  });

  @override
  State<_AnimatedMoreMenu> createState() => _AnimatedMoreMenuState();
}

class _AnimatedMoreMenuState extends State<_AnimatedMoreMenu>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );

  @override
  void didUpdateWidget(covariant _AnimatedMoreMenu old) {
    super.didUpdateWidget(old);
    // Pulsa só na transição "não selecionando" → "selecionando".
    if (!old.selecting && widget.selecting) {
      _pulse.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isSelection = widget.selecting;
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        // Curva: 0 → 1 → 0 (pulso único).
        final t = _pulse.value;
        final pulse = t <= 0.5 ? t * 2 : (1 - t) * 2;
        final scale = 1.0 + 0.25 * pulse;
        return Transform.scale(scale: scale, child: child);
      },
      child: PopupMenuButton<String>(
        icon: Icon(
          isSelection ? Icons.checklist : Icons.more_vert,
          color: isSelection ? scheme.primary : null,
        ),
        tooltip: isSelection ? 'Ações (${widget.selectedCount})' : 'Mais',
        onSelected: isSelection
            ? widget.onSelectionSelected
            : widget.onNormalSelected,
        itemBuilder: (_) =>
            isSelection ? widget.selectionItems : widget.normalItems,
      ),
    );
  }
}
