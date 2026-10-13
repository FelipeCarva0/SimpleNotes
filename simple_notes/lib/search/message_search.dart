import '../database/tables.dart' show MessageType;
import '../models/message.dart';
import '../utils/text_normalize.dart';
import 'message_filter.dart';

/// Uma mensagem que casa com o filtro.
class SearchHit {
  /// Posição na lista COMPLETA da conversa (usada para navegar até ela).
  final int index;
  final Message message;

  /// Ocorrências da palavra no texto EXIBIDO no balão (conteúdo da mensagem
  /// de texto, ou nome de exibição do anexo). Pode ser vazia quando a
  /// mensagem casou apenas pelo nome original do arquivo.
  final List<MatchRange> matches;

  const SearchHit({
    required this.index,
    required this.message,
    required this.matches,
  });

  /// Quantos "saltos" esta mensagem ocupa na navegação por ocorrência.
  int get steps => matches.isEmpty ? 1 : matches.length;
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Texto que o balão realmente mostra para a mensagem.
String shownText(Message m) => m.tipo == MessageType.texto
    ? (m.conteudoTexto ?? '')
    : (m.arquivoNomeExibicao ?? '');

/// RF05 — aplica [filter] sobre a lista completa de mensagens da conversa,
/// mantendo a ordem original (`position`).
///
/// Com filtro vazio devolve todas as mensagens; quem chama decide se isso
/// deve ser tratado como "sem busca".
List<SearchHit> searchMessages(List<Message> messages, MessageFilter filter) {
  var from = filter.from == null ? null : _dateOnly(filter.from!);
  var to = filter.to == null ? null : _dateOnly(filter.to!);
  if (from != null && to != null && from.isAfter(to)) {
    final tmp = from;
    from = to;
    to = tmp;
  }

  final hits = <SearchHit>[];
  for (var i = 0; i < messages.length; i++) {
    final m = messages[i];

    if (filter.types.isNotEmpty && !filter.types.contains(m.tipo)) continue;

    if (filter.tagIds.isNotEmpty &&
        (m.tagId == null || !filter.tagIds.contains(m.tagId))) {
      continue;
    }

    final d = _dateOnly(m.data);
    if (from != null && d.isBefore(from)) continue;
    if (to != null && d.isAfter(to)) continue;

    var matches = const <MatchRange>[];
    if (filter.hasText) {
      matches = findMatches(shownText(m), filter.text);
      if (matches.isEmpty) {
        // RF05: o nome ORIGINAL do arquivo também conta.
        if (m.tipo == MessageType.texto) continue;
        if (findMatches(m.arquivoNomeOriginal ?? '', filter.text).isEmpty) {
          continue;
        }
      }
    }

    hits.add(SearchHit(index: i, message: m, matches: matches));
  }
  return hits;
}

/// Data simples: índice da primeira mensagem (na ordem da conversa) cuja
/// data é [date], ou null se não houver nenhuma.
int? firstIndexOnDate(List<Message> messages, DateTime date) {
  final target = _dateOnly(date);
  for (var i = 0; i < messages.length; i++) {
    if (_dateOnly(messages[i].data) == target) return i;
  }
  return null;
}