import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/tables.dart' show MessageType;
import '../models/tag.dart';
import '../providers/conversation_providers.dart';
import '../providers/tag_providers.dart';
import '../search/message_filter.dart';
import '../search/message_search.dart';
import '../utils/format.dart';
import '../widgets/highlighted_text.dart';
import '../widgets/tag_chip.dart';
import '../widgets/tag_picker_many_sheet.dart';
import '../widgets/search_options_sheet.dart';
import '../models/message.dart';

/// RF05/4.5/4.6 — lista de resultados de busca dentro de uma Conversa.
///
/// Duas responsabilidades:
/// - 4.5: mostrar todos os `SearchHit`s com filtros (texto/tipo/tag/data)
///   combináveis; toque leva ao local da mensagem na conversa (via
///   [Navigator.pop] com o [SearchHit] escolhido).
/// - 4.6: quando o filtro inclui faixa de datas, ativa seleção múltipla e
///   ações em lote (definir/remover tag, editar data, excluir).
///
/// A conversa NUNCA é filtrada — esta tela é separada da `ChatScreen`.
class SearchResultsScreen extends ConsumerStatefulWidget {
  final String conversationId;
  final MessageFilter initialFilter;

  const SearchResultsScreen({
    super.key,
    required this.conversationId,
    required this.initialFilter,
  });

  @override
  ConsumerState<SearchResultsScreen> createState() =>
      _SearchResultsScreenState();
}

class _SearchResultsScreenState extends ConsumerState<SearchResultsScreen> {
  late MessageFilter _filter = widget.initialFilter;

  // Modo seleção (4.6) — só quando o filtro tem faixa de datas.
  bool _selecting = false;
  final Set<String> _selectedIds = {};
  List<SearchHit>? _hits;
  bool _computing = false;
  final Map<MessageFilter, List<SearchHit>> _hitsCache = {};
  bool get _rangeMode => _filter.from != null || _filter.to != null;

  void _exitSelection() {
    setState(() {
      _selecting = false;
      _selectedIds.clear();
    });
  }

  void _toggleSelected(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  Future<void> _openFilters() async {
    final tagsAsync =
        ref.read(tagsStreamProvider(widget.conversationId)).valueOrNull ??
        const <Tag>[];

    final updated = await showSearchFilterSheet(
      context,
      filter: _filter,
      availableTags: tagsAsync,
    );
    if (updated == null || !mounted) return;

    setState(() {
      _filter = updated;
      // Se a faixa de datas saiu do filtro, o modo seleção perde sentido.
      if (!_rangeMode) _exitSelection();
    });
    _recomputeHits();
  }

  void _clearFilters() {
    setState(() {
      _filter = MessageFilter.empty;
      _exitSelection();
    });
    _recomputeHits();
  }

  Future<void> _pickTagForMany() async {
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
      _exitSelection();
    } catch (e) {
      debugPrint('Erro ao aplicar tag em lote: $e');
      _showSnack('Não foi possível aplicar a tag.');
    }
  }

  Future<void> _pickDateForMany() async {
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
      _exitSelection();
    } catch (e) {
      debugPrint('Erro ao alterar data em lote: $e');
      _showSnack('Não foi possível alterar a data.');
    }
  }

  Future<void> _recomputeHits() async {
    if (_hitsCache.containsKey(_filter)) {
      setState(() {
        _hits = _hitsCache[_filter];
        _computing = false;
      });
      return;
    }

    setState(() => _computing = true);

    final messages =
        ref.read(messagesStreamProvider(widget.conversationId)).valueOrNull ??
        const <Message>[];

    // `searchMessages` é O(n) síncrono. Roda em ~5 ms em 10k com cache quente
    // (6.8). Em conversa protegida com cache frio, a lista já vem decifrada
    // pelo `watchAllMessages` antes de chegar aqui.
    final hits = searchMessages(messages, _filter);

    if (!mounted) return;
    _hitsCache[_filter] = hits;
    setState(() {
      _hits = hits;
      _computing = false;
    });
  }

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
      _exitSelection();
    } catch (e) {
      debugPrint('Erro ao excluir em lote: $e');
      _showSnack('Não foi possível excluir.');
    }
  }

  void _showSnack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _recomputeHits();
    });
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(
      messagesStreamProvider(widget.conversationId),
    );
    final tagsAsync = ref.watch(tagsStreamProvider(widget.conversationId));

    final tagsById = <String, Tag>{
      for (final t in tagsAsync.maybeWhen(
        data: (tags) => tags,
        orElse: () => const <Tag>[],
      ))
        t.id: t,
    };
    // 6.9.3 — se o conjunto de mensagens mudou, o cache de hits fica velho.
    // (Barato: `clear` só se a identidade da lista mudou.)
    ref.listen(messagesStreamProvider(widget.conversationId), (_, _) {
      _hitsCache.clear();
      if (mounted) _recomputeHits();
    });
    return PopScope(
      canPop: !_selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _exitSelection();
      },
      child: Scaffold(
        appBar: _selecting ? _buildSelectionAppBar() : _buildNormalAppBar(),
        body: messagesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Erro: $e')),
          data: (messages) {
            final hits = _hits ?? const <SearchHit>[];
            if (_computing) {
              return const Center(child: CircularProgressIndicator());
            }
            if (hits.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.search_off, size: 48),
                      const SizedBox(height: 12),
                      Text(
                        _filter.isEmpty
                            ? 'Nenhuma mensagem nesta conversa.'
                            : 'Nenhuma mensagem corresponde aos filtros.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      FilledButton.tonal(
                        onPressed: _openFilters,
                        child: const Text('Ajustar filtros'),
                      ),
                    ],
                  ),
                ),
              );
            }

            return ListView.separated(
              itemCount: hits.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final hit = hits[index];
                final checked = _selectedIds.contains(hit.message.id);
                return _ResultTile(
                  hit: hit,
                  tag: tagsById[hit.message.tagId],
                  selecting: _selecting,
                  checked: checked,
                  onTap: () {
                    if (_selecting) {
                      _toggleSelected(hit.message.id);
                    } else {
                      Navigator.pop(context, hit);
                    }
                  },
                  onLongPress: _rangeMode && !_selecting
                      ? () {
                          setState(() {
                            _selecting = true;
                            _selectedIds.add(hit.message.id);
                          });
                        }
                      : null,
                );
              },
            );
          },
        ),
      ),
    );
  }

  PreferredSizeWidget _buildNormalAppBar() {
    return AppBar(
      title: const Text('Resultados'),
      actions: [
        if (_rangeMode)
          IconButton(
            icon: const Icon(Icons.checklist),
            tooltip: 'Selecionar',
            onPressed: () => setState(() => _selecting = true),
          ),
        IconButton(
          icon: const Icon(Icons.filter_alt_outlined),
          tooltip: 'Filtros',
          onPressed: _openFilters,
        ),
        if (!_filter.isEmpty)
          IconButton(
            icon: const Icon(Icons.filter_alt_off_outlined),
            tooltip: 'Limpar filtros',
            onPressed: _clearFilters,
          ),
      ],
    );
  }

  PreferredSizeWidget _buildSelectionAppBar() {
    final count = _selectedIds.length;
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.close),
        tooltip: 'Cancelar seleção',
        onPressed: _exitSelection,
      ),
      title: Text('$count selecionada${count == 1 ? '' : 's'}'),
      actions: [
        IconButton(
          icon: const Icon(Icons.label_outline),
          tooltip: 'Definir tag',
          onPressed: count == 0 ? null : _pickTagForMany,
        ),
        IconButton(
          icon: const Icon(Icons.event_outlined),
          tooltip: 'Editar data',
          onPressed: count == 0 ? null : _pickDateForMany,
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline),
          tooltip: 'Excluir',
          onPressed: count == 0 ? null : _deleteMany,
        ),
      ],
    );
  }
}

class _ResultTile extends StatelessWidget {
  final SearchHit hit;
  final Tag? tag;
  final bool selecting;
  final bool checked;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _ResultTile({
    required this.hit,
    required this.tag,
    required this.selecting,
    required this.checked,
    required this.onTap,
    this.onLongPress,
  });

  IconData get _icon {
    switch (hit.message.tipo) {
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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final m = hit.message;
    final previewText = shownText(m);
    final previewStyle = TextStyle(color: scheme.onSurface);

    final highlight = SearchHighlight(
      matches: hit.matches,
      currentMatch: -1,
      originalNameOnly: hit.matches.isEmpty,
    );

    final leading = selecting
        ? Checkbox(value: checked, onChanged: (_) => onTap())
        : Icon(_icon);

    final subtitleParts = <Widget>[
      highlightedText(
        previewText.isEmpty ? '(sem texto)' : previewText,
        previewStyle,
        highlight,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      const SizedBox(height: 4),
      Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            formatDate(m.data),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (tag != null) TagChip(tag: tag!, compact: true, maxWidth: 120),
          if (hit.steps > 1)
            Text(
              '${hit.steps} ocorrências',
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
    ];

    return ListTile(
      leading: leading,
      title: highlightedText(
        previewText.isEmpty ? '(sem texto)' : previewText,
        previewStyle.copyWith(fontWeight: FontWeight.w500),
        highlight,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: subtitleParts,
      ),
      onTap: onTap,
      onLongPress: onLongPress,
      trailing: hit.matches.isEmpty
          ? const Tooltip(
              message: 'Casou pelo nome original do arquivo',
              child: Icon(Icons.info_outline, size: 18),
            )
          : null,
    );
  }
}
