import 'package:flutter/material.dart';

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
    Navigator.pop<SearchRequest>(
      context,
      (mode: _mode, query: query.isEmpty ? null : query),
    );
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
                onTap: () => Navigator.pop<SearchRequest>(
                  context,
                  (mode: SearchMode.goToDate, query: null),
                ),
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
                onTap: () => Navigator.pop<SearchRequest>(
                  context,
                  (mode: SearchMode.dateRange, query: null),
                ),
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