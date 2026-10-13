import '../database/tables.dart' show MessageType;

/// RF05 — critérios de busca dentro de uma Conversa.
///
/// Dentro de uma categoria vale "ou" ([types], [tagIds]); entre categorias
/// vale "e". Categoria vazia = sem restrição.
class MessageFilter {
  /// Palavra ou frase (ignora maiúsculas e acentos).
  final String text;

  /// Intervalo de datas, inclusivo nas duas pontas. Mesmo dia nas duas
  /// pontas equivale à data exata.
  final DateTime? from;
  final DateTime? to;

  final Set<MessageType> types;
  final Set<String> tagIds;

  const MessageFilter({
    this.text = '',
    this.from,
    this.to,
    this.types = const {},
    this.tagIds = const {},
  });

  static const empty = MessageFilter();

  bool get hasText => text.trim().isNotEmpty;
  bool get hasDates => from != null || to != null;

  bool get isEmpty =>
      !hasText && !hasDates && types.isEmpty && tagIds.isEmpty;

  MessageFilter copyWith({
    String? text,
    DateTime? from,
    DateTime? to,
    bool clearDates = false,
    Set<MessageType>? types,
    Set<String>? tagIds,
  }) {
    return MessageFilter(
      text: text ?? this.text,
      from: clearDates ? null : (from ?? this.from),
      to: clearDates ? null : (to ?? this.to),
      types: types ?? this.types,
      tagIds: tagIds ?? this.tagIds,
    );
  }
}