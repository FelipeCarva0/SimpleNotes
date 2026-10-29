import 'package:flutter/material.dart';
import '../utils/text_normalize.dart';

/// Resultado de busca aplicado a UM balão.
class SearchHighlight {
  final List<MatchRange> matches;

  /// Índice, em [matches], da ocorrência atual (-1 = nenhuma neste balão).
  final int currentMatch;

  /// Casou só pelo nome ORIGINAL do arquivo (nada a destacar no balão).
  final bool originalNameOnly;

  const SearchHighlight({
    required this.matches,
    this.currentMatch = -1,
    this.originalNameOnly = false,
  });
}

/// Texto com as ocorrências destacadas; a atual em laranja, as demais em amarelo.
Widget highlightedText(
  String text,
  TextStyle style,
  SearchHighlight? h, {
  int? maxLines,
  TextOverflow? overflow,
}) {
  if (h == null || h.matches.isEmpty) {
    return Text(text, style: style, maxLines: maxLines, overflow: overflow);
  }

  final spans = <InlineSpan>[];
  var pos = 0;
  for (var i = 0; i < h.matches.length; i++) {
    final m = h.matches[i];
    if (m.start < pos || m.end > text.length) continue;
    if (m.start > pos) spans.add(TextSpan(text: text.substring(pos, m.start)));
    final isCurrent = i == h.currentMatch;
    spans.add(TextSpan(
      text: text.substring(m.start, m.end),
      style: TextStyle(
        backgroundColor:
            isCurrent ? const Color(0xFFFF9800) : const Color(0x66FFEB3B),
        color: Colors.black,
        fontWeight: isCurrent ? FontWeight.w700 : null,
      ),
    ));
    pos = m.end;
  }
  if (pos < text.length) spans.add(TextSpan(text: text.substring(pos)));

  return Text.rich(
    TextSpan(style: style, children: spans),
    maxLines: maxLines,
    overflow: overflow,
  );
}