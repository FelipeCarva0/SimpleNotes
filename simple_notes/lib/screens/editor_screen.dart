import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/page_providers.dart';
import '../models/line.dart';

class EditorScreen extends ConsumerStatefulWidget {
  final String pageId;
  const EditorScreen({super.key, required this.pageId});

  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen>
    with WidgetsBindingObserver {
  final _draftController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _draftDebounce;
  Future<void> _saveChain = Future.value();

  List<Line> _lines = [];
  bool _loaded = false;

  static const _debounceDuration = Duration(milliseconds: 500);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Garante que sair do app (não só da tela) não perde o rascunho.
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _draftDebounce?.cancel();
      _persistDraft(_draftController.text);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _draftDebounce?.cancel();
    _persistDraft(_draftController.text);
    _draftController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onDraftChanged(String text) {
    _draftDebounce?.cancel();
    _draftDebounce = Timer(_debounceDuration, () => _persistDraft(text));
  }

  void _persistDraft(String text) {
    _saveChain = _saveChain
        .then((_) => ref.read(pageRepositoryProvider).saveDraft(widget.pageId, text))
        .catchError((e) => debugPrint('Erro ao salvar rascunho: $e'));
  }

  Future<void> _sendDraft([String? _]) async {
    _draftDebounce?.cancel();
    final text = _draftController.text;
    if (text.trim().isEmpty) return;

    _draftController.clear();

    _saveChain = _saveChain.then((_) async {
      // Garante que o texto mais recente (mesmo que ainda dentro da janela
      // de debounce) seja persistido antes de confirmar o envio.
      await ref.read(pageRepositoryProvider).saveDraft(widget.pageId, text);
      await ref.read(pageRepositoryProvider).sendDraft(widget.pageId);
      final refreshed = await ref.read(pageRepositoryProvider).getPage(widget.pageId);
      if (mounted && refreshed != null) {
        setState(() => _lines = refreshed.lines);
        _scrollToBottom();
      }
    }).catchError((e) => debugPrint('Erro ao enviar linha: $e'));
  }

  Future<void> _editLine(Line line) async {
    final controller = TextEditingController(text: line.content);
    final newContent = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar linha'),
        content: TextField(controller: controller, autofocus: true, maxLines: null),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );

    if (newContent == null || newContent == line.content) return;

    await ref.read(pageRepositoryProvider).updateLineContent(line.id, newContent);
    setState(() {
      final idx = _lines.indexWhere((l) => l.id == line.id);
      if (idx != -1) _lines[idx] = line.copyWith(content: newContent);
    });
  }

  Future<void> _confirmDeleteLine(Line line) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir linha?'),
        content: Text(line.content.isEmpty ? '(linha vazia)' : line.content),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Excluir')),
        ],
      ),
    );
    if (confirm != true) return;

    await ref.read(pageRepositoryProvider).deleteLine(line.id);
    setState(() => _lines.removeWhere((l) => l.id == line.id));
  }

  Future<void> _editLineDate(Line line) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: line.date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;

    await ref.read(pageRepositoryProvider).setLineDateManually(line.id, picked);
    final dateOnly = DateTime(picked.year, picked.month, picked.day);
    setState(() {
      final idx = _lines.indexWhere((l) => l.id == line.id);
      if (idx != -1) _lines[idx] = line.copyWith(date: dateOnly, isDateManuallyEdited: true);
    });
    if (mounted) Navigator.of(context).pop();
  }

  void _showLineDates() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _LineDatesSheet(lines: _lines, onEditDate: _editLineDate),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final pageAsync = ref.watch(pageByIdProvider(widget.pageId));

    return Scaffold(
      appBar: AppBar(
        title: pageAsync.when(
          data: (page) => Text(page?.title ?? 'Página'),
          loading: () => const Text('Carregando...'),
          error: (_, __) => const Text('Página'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.event_note_outlined),
            tooltip: 'Datas das linhas',
            onPressed: _showLineDates,
          ),
        ],
      ),
      body: pageAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (page) {
          if (page == null) {
            return const Center(child: Text('Página não encontrada.'));
          }
          if (!_loaded) {
            _lines = List.of(page.lines);
            _draftController.text = page.draftContent;
            _loaded = true;
            _scrollToBottom();
          }
          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(12),
                  itemCount: _lines.length,
                  itemBuilder: (context, index) {
                    final line = _lines[index];
                    return GestureDetector(
                      onTap: () => _editLine(line),
                      onLongPress: () => _confirmDeleteLine(line),
                      child: _Bubble(line: line),
                    );
                  },
                ),
              ),
              _ComposeBar(
                controller: _draftController,
                onChanged: _onDraftChanged,
                onSend: _sendDraft,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final Line line;
  const _Bubble({required this.line});

  @override
  Widget build(BuildContext context) {
    final dateLabel =
        '${line.date.day.toString().padLeft(2, '0')}/'
        '${line.date.month.toString().padLeft(2, '0')}/'
        '${line.date.year}';

    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Wrap(
          alignment: WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.end,
          spacing: 8,
          children: [
            Text(
              line.content.isEmpty ? ' ' : line.content,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            Text(
              dateLabel,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ComposeBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSend;

  const _ComposeBar({
    required this.controller,
    required this.onChanged,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 5,
                textInputAction: TextInputAction.send,
                onChanged: onChanged,
                onSubmitted: onSend,
                decoration: const InputDecoration(
                  hintText: 'Escreva algo...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(24)),
                  ),
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              icon: const Icon(Icons.send),
              onPressed: () => onSend(controller.text),
            ),
          ],
        ),
      ),
    );
  }
}

class _LineDatesSheet extends StatelessWidget {
  final List<Line> lines;
  final void Function(Line) onEditDate;

  const _LineDatesSheet({required this.lines, required this.onEditDate});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: lines.length,
        itemBuilder: (context, index) {
          final line = lines[index];
          final dateLabel =
              '${line.date.day.toString().padLeft(2, '0')}/'
              '${line.date.month.toString().padLeft(2, '0')}/'
              '${line.date.year}';
          return ListTile(
            title: Text(
              line.content.isEmpty ? '(linha vazia)' : line.content,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              line.isDateManuallyEdited ? '$dateLabel (editada manualmente)' : dateLabel,
            ),
            trailing: IconButton(
              icon: const Icon(Icons.edit_calendar_outlined),
              onPressed: () => onEditDate(line),
            ),
          );
        },
      ),
    );
  }
}