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
  final _scrollController = ScrollController();
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
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
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
    _scrollController.dispose();
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

  /// RF02.5 — exclusão explícita, distinta de qualquer edição de conteúdo.
  Future<void> _deleteMessage(Message message) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir mensagem?'),
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
            // Ponto de extensão da Sprint 3 (RF04): "Definir tag" entra
            // aqui como mais um ListTile, além do gesto de arrastar.
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

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final conversationAsync =
        ref.watch(conversationByIdProvider(widget.conversationId));
    final messagesAsync = ref.watch(messagesStreamProvider(widget.conversationId));

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
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final previous = index > 0 ? messages[index - 1] : null;
                    final showDateSeparator =
                        previous == null || !_isSameDay(previous.data, message.data);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (showDateSeparator) _DateSeparator(date: message.data),
                        MessageBubble(
                          message: message,
                          onTap: message.tipo == MessageType.texto
                              ? () => _editMessage(message)
                              : null,
                          onLongPress: () => _showMessageActions(message),
                        ),
                      ],
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

class _DateSeparator extends StatelessWidget {
  final DateTime date;
  const _DateSeparator({required this.date});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            _formatDate(date),
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)}/${date.year}';
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
