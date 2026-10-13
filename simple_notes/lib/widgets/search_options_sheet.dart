import 'package:flutter/material.dart';

/// Modos de pesquisa dentro de uma Conversa (RF05).
/// As etapas seguintes da Sprint 4 acrescentam os demais.
enum SearchMode { goToDate }

/// Sheet "Pesquisar". Devolve o modo escolhido, ou null se fechado.
Future<SearchMode?> showSearchOptionsSheet(BuildContext context) {
  return showModalBottomSheet<SearchMode>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.event_outlined),
            title: const Text('Ir para uma data'),
            subtitle: const Text('Vai para a primeira mensagem do dia'),
            onTap: () => Navigator.pop(context, SearchMode.goToDate),
          ),
        ],
      ),
    ),
  );
}