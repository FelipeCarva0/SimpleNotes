import 'package:flutter/material.dart';
import '../database/tables.dart' show MessageType;
import '../models/tag.dart';
import '../search/message_filter.dart';
import '../utils/format.dart';

/// Modos de pesquisa dentro de uma Conversa (RF05).
///
/// - [goToDate]:          vai para a primeira mensagem do dia escolhido (4.3).
/// - [wordInConversation]: destaca as ocorrências e permite saltar entre elas (4.4).
/// - [resultsList]:       lista única de resultados com filtros de texto/tipo/tag (4.5).
/// - [dateRange]:         faixa de datas com seleção e ações em lote (4.6).
enum SearchMode { goToDate, wordInConversation, resultsList, dateRange }

/// Requisição devolvida pelo sheet. [query] só é preenchida em
/// [SearchMode.wordInConversation] e [SearchMode.resultsList].
typedef SearchRequest = ({SearchMode mode, String? query});

/// Sheet "Pesquisar". Devolve a requisição escolhida, ou null se fechado.
Future<SearchRequest?> showSearchOptionsSheet(BuildContext context) {
  return showModalBottomSheet<SearchRequest>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _SearchOptionsSheet(),
  );
}

class _SearchOptionsSheet extends StatefulWidget {
  const _SearchOptionsSheet();

  @override
  State<_SearchOptionsSheet> createState() => _SearchOptionsSheetState();
}

class _SearchOptionsSheetState extends State<_SearchOptionsSheet> {
  final _controller = TextEditingController();
  SearchMode _mode = SearchMode.wordInConversation;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final query = _controller.text.trim();
    Navigator.pop<SearchRequest>(context, (
      mode: _mode,
      query: query.isEmpty ? null : query,
    ));
  }

  bool get _needsText =>
      _mode == SearchMode.wordInConversation || _mode == SearchMode.resultsList;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(0, 0, 0, bottomInset),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.event_outlined),
                title: const Text('Ir para uma data'),
                subtitle: const Text('Vai para a primeira mensagem do dia'),
                onTap: () => Navigator.pop<SearchRequest>(context, (
                  mode: SearchMode.goToDate,
                  query: null,
                )),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.search),
                title: const Text('Palavra na conversa'),
                subtitle: const Text(
                  'Destaca e permite saltar entre as ocorrências',
                ),
                selected: _mode == SearchMode.wordInConversation,
                onTap: () =>
                    setState(() => _mode = SearchMode.wordInConversation),
              ),
              ListTile(
                leading: const Icon(Icons.list_alt_outlined),
                title: const Text('Lista de resultados'),
                subtitle: const Text(
                  'Filtros de texto, tipo e tag; abre cada ocorrência',
                ),
                selected: _mode == SearchMode.resultsList,
                onTap: () => setState(() => _mode = SearchMode.resultsList),
              ),
              ListTile(
                leading: const Icon(Icons.date_range_outlined),
                title: const Text('Faixa de datas'),
                subtitle: const Text(
                  'Lista as mensagens do período com seleção e ações em lote',
                ),
                onTap: () => Navigator.pop<SearchRequest>(context, (
                  mode: SearchMode.dateRange,
                  query: null,
                )),
              ),
              if (_needsText) ...[
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: TextField(
                    controller: _controller,
                    autofocus: true,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      labelText: 'Palavra ou frase',
                      hintText: 'Ex.: josé, relatório 2024',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.arrow_forward),
                        tooltip: 'Buscar',
                        onPressed: _submit,
                      ),
                    ),
                    onSubmitted: (_) => _submit(),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Ignora maiúsculas e acentos.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      FilledButton(
                        onPressed: _submit,
                        child: const Text('Buscar'),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Sheet de edição de filtros (4.5 completo)
// ---------------------------------------------------------------------

/// Abre o sheet para editar [filter] (texto, tipos, tags e faixa de datas).
/// Devolve o [MessageFilter] atualizado, ou null se fechado sem salvar.
Future<MessageFilter?> showSearchFilterSheet(
  BuildContext context, {
  required MessageFilter filter,
  required List<Tag> availableTags,
}) {
  return showModalBottomSheet<MessageFilter>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) =>
        _SearchFilterSheet(initial: filter, availableTags: availableTags),
  );
}

class _SearchFilterSheet extends StatefulWidget {
  final MessageFilter initial;
  final List<Tag> availableTags;
  const _SearchFilterSheet({
    required this.initial,
    required this.availableTags,
  });

  @override
  State<_SearchFilterSheet> createState() => _SearchFilterSheetState();
}

class _SearchFilterSheetState extends State<_SearchFilterSheet> {
  late final TextEditingController _textController = TextEditingController(
    text: widget.initial.text,
  );
  late final Set<MessageType> _types = {...widget.initial.types};
  late final Set<String> _tagIds = {...widget.initial.tagIds};
  late DateTime? _from = widget.initial.from;
  late DateTime? _to = widget.initial.to;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  static const _typeLabels = <MessageType, String>{
    MessageType.texto: 'Texto',
    MessageType.imagem: 'Imagem',
    MessageType.video: 'Vídeo',
    MessageType.audio: 'Áudio',
    MessageType.documento: 'Documento',
  };

  Future<void> _pickDate({required bool isFrom}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: (isFrom ? _from : _to) ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: isFrom ? 'Data inicial' : 'Data final',
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isFrom) {
        _from = picked;
        if (_to != null && _to!.isBefore(picked)) _to = picked;
      } else {
        _to = picked;
        if (_from != null && _from!.isAfter(picked)) _from = picked;
      }
    });
  }

  void _clearDates() => setState(() {
    _from = null;
    _to = null;
  });

  void _apply() {
    Navigator.pop<MessageFilter>(
      context,
      MessageFilter(
        text: _textController.text.trim(),
        from: _from,
        to: _to,
        types: _types,
        tagIds: _tagIds,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottomInset),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Filtros', style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),
              TextField(
                controller: _textController,
                textInputAction: TextInputAction.search,
                decoration: const InputDecoration(
                  labelText: 'Palavra ou frase',
                  hintText: 'Ignora maiúsculas e acentos',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _apply(),
              ),
              const SizedBox(height: 16),
              Text('Tipo', style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final entry in _typeLabels.entries)
                    FilterChip(
                      label: Text(entry.value),
                      selected: _types.contains(entry.key),
                      onSelected: (on) => setState(() {
                        if (on) {
                          _types.add(entry.key);
                        } else {
                          _types.remove(entry.key);
                        }
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text('Tag', style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              if (widget.availableTags.isEmpty)
                Text(
                  'Nenhuma tag nesta conversa.',
                  style: theme.textTheme.bodySmall,
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final tag in widget.availableTags)
                      FilterChip(
                        label: Text(tag.nome),
                        selected: _tagIds.contains(tag.id),
                        onSelected: (on) => setState(() {
                          if (on) {
                            _tagIds.add(tag.id);
                          } else {
                            _tagIds.remove(tag.id);
                          }
                        }),
                      ),
                  ],
                ),
              const SizedBox(height: 16),
              Text('Datas', style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.event_outlined),
                      label: Text(
                        _from == null ? 'Data inicial' : formatDate(_from!),
                      ),
                      onPressed: () => _pickDate(isFrom: true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.event_available_outlined),
                      label: Text(
                        _to == null ? 'Data final' : formatDate(_to!),
                      ),
                      onPressed: () => _pickDate(isFrom: false),
                    ),
                  ),
                ],
              ),
              if (_from != null || _to != null) ...[
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    icon: const Icon(Icons.clear),
                    label: const Text('Limpar datas'),
                    onPressed: _clearDates,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: _apply,
                      child: const Text('Aplicar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
