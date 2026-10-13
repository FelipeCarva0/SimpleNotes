/// Intervalo [start, end) dentro de um texto.
class MatchRange {
  final int start;
  final int end;
  const MatchRange(this.start, this.end);
}

const _accents = <String, String>{
  'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'å': 'a',
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
  'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
  'ó': 'o', 'ò': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o',
  'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
  'ç': 'c', 'ñ': 'n', 'ý': 'y', 'ÿ': 'y',
};

/// Minúsculas e sem acentos, **preservando o tamanho da string**. Essa
/// propriedade é essencial: uma posição achada no texto normalizado vale
/// igual no texto original, o que permite destacar a palavra no balão.
///
/// Limite conhecido: letras acentuadas "decompostas" (e + acento combinado,
/// comum em nomes de arquivo vindos do macOS) não são tratadas, pois
/// removê-las mudaria o tamanho. Teclados comuns geram letras compostas.
String normalizeText(String input) {
  final buffer = StringBuffer();
  for (final rune in input.runes) {
    final ch = String.fromCharCode(rune);
    var lower = ch.toLowerCase();
    if (lower.length != ch.length) lower = ch; // mantém o tamanho
    buffer.write(_accents[lower] ?? lower);
  }
  return buffer.toString();
}

/// Todas as ocorrências (sem sobreposição) de [query] em [text], ignorando
/// maiúsculas e acentos. As posições valem para o [text] original.
List<MatchRange> findMatches(String text, String query) {
  final q = normalizeText(query.trim());
  if (q.isEmpty) return const [];

  final t = normalizeText(text);
  final result = <MatchRange>[];
  var from = 0;
  while (true) {
    final i = t.indexOf(q, from);
    if (i < 0) break;
    result.add(MatchRange(i, i + q.length));
    from = i + q.length;
  }
  return result;
}