import '../models/line.dart';

/// Calcula a distância de Levenshtein entre duas strings (número mínimo de
/// inserções/remoções/substituições de caractere pra transformar uma na outra).
int _levenshtein(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;

  var previousRow = List<int>.generate(b.length + 1, (i) => i);
  var currentRow = List<int>.filled(b.length + 1, 0);

  for (var i = 0; i < a.length; i++) {
    currentRow[0] = i + 1;
    for (var j = 0; j < b.length; j++) {
      final cost = a[i] == b[j] ? 0 : 1;
      final deletion = currentRow[j] + 1;
      final insertion = previousRow[j + 1] + 1;
      final substitution = previousRow[j] + cost;
      currentRow[j + 1] = [deletion, insertion, substitution].reduce(
        (x, y) => x < y ? x : y,
      );
    }
    final tmp = previousRow;
    previousRow = currentRow;
    currentRow = tmp;
  }
  return previousRow[b.length];
}

/// Retorna um valor entre 0.0 (totalmente diferentes) e 1.0 (idênticas).
double similarityRatio(String a, String b) {
  if (a == b) return 1.0;
  final maxLen = a.length > b.length ? a.length : b.length;
  if (maxLen == 0) return 1.0;
  return 1 - (_levenshtein(a, b) / maxLen);
}

enum _RawOpType { equal, delete, insert }

class _RawOp {
  final _RawOpType type;
  final int? oldIndex;
  final int? newIndex;
  _RawOp(this.type, {this.oldIndex, this.newIndex});
}

/// Alinha duas listas de linhas via LCS (Longest Common Subsequence) e
/// devolve a sequência de operações (equal/delete/insert) que transforma
/// [oldLines] em [newLines]. Complexidade O(n*m) — ver nota de performance
/// no cabeçalho do arquivo/conversa.
List<_RawOp> _computeLcsOps(List<String> oldLines, List<String> newLines) {
  final n = oldLines.length;
  final m = newLines.length;

  final dp = List.generate(n + 1, (_) => List<int>.filled(m + 1, 0));
  for (var i = n - 1; i >= 0; i--) {
    for (var j = m - 1; j >= 0; j--) {
      dp[i][j] = oldLines[i] == newLines[j]
          ? dp[i + 1][j + 1] + 1
          : (dp[i + 1][j] >= dp[i][j + 1] ? dp[i + 1][j] : dp[i][j + 1]);
    }
  }

  final ops = <_RawOp>[];
  var i = 0, j = 0;
  while (i < n && j < m) {
    if (oldLines[i] == newLines[j]) {
      ops.add(_RawOp(_RawOpType.equal, oldIndex: i, newIndex: j));
      i++;
      j++;
    } else if (dp[i + 1][j] >= dp[i][j + 1]) {
      ops.add(_RawOp(_RawOpType.delete, oldIndex: i));
      i++;
    } else {
      ops.add(_RawOp(_RawOpType.insert, newIndex: j));
      j++;
    }
  }
  while (i < n) {
    ops.add(_RawOp(_RawOpType.delete, oldIndex: i));
    i++;
  }
  while (j < m) {
    ops.add(_RawOp(_RawOpType.insert, newIndex: j));
    j++;
  }
  return ops;
}

/// Núcleo do RF03: recebe o estado anterior de linhas de uma página e o novo
/// texto completo do editor, e devolve a lista de [Line] já pronta pra
/// persistir, aplicando as regras de datação automática:
///
/// - Linha idêntica antes/depois → mantém id e data.
/// - Linha com conteúdo parecido (>= [similarityThreshold]) → considerada a
///   MESMA linha editada, mantém id e data (RF03: edição não muda a data).
/// - Linha nova, ou parecida demais diferente (< threshold) → nova linha,
///   novo id, data de hoje.
/// - Linha que não sobrou no novo texto → removida.
List<Line> computeUpdatedLines({
  required String pageId,
  required List<Line> oldLines,
  required String newText,
  required String Function() generateId,
  DateTime? today,
  double similarityThreshold = 0.6,
}) {
  final now = today ?? DateTime.now();
  final todayDateOnly = DateTime(now.year, now.month, now.day);

  final oldContents = oldLines.map((l) => l.content).toList();
  final newContents = newText.isEmpty ? <String>[] : newText.split('\n');

  final rawOps = _computeLcsOps(oldContents, newContents);

  final result = <Line>[];
  var position = 0;
  var k = 0;

  while (k < rawOps.length) {
    final op = rawOps[k];

    if (op.type == _RawOpType.equal) {
      final oldLine = oldLines[op.oldIndex!];
      result.add(oldLine.copyWith(position: position));
      position++;
      k++;
      continue;
    }

    // Bloco de mudança: agrupa deletes e inserts consecutivos pra parear
    // "linha removida" com "linha nova na mesma vizinhança" por similaridade.
    final deletes = <int>[];
    final inserts = <int>[];
    while (k < rawOps.length && rawOps[k].type == _RawOpType.delete) {
      deletes.add(rawOps[k].oldIndex!);
      k++;
    }
    while (k < rawOps.length && rawOps[k].type == _RawOpType.insert) {
      inserts.add(rawOps[k].newIndex!);
      k++;
    }

    final pairCount = deletes.length < inserts.length
        ? deletes.length
        : inserts.length;

    for (var p = 0; p < pairCount; p++) {
      final oldLine = oldLines[deletes[p]];
      final newContent = newContents[inserts[p]];
      final ratio = similarityRatio(oldLine.content, newContent);

      if (ratio >= similarityThreshold) {
        result.add(oldLine.copyWith(content: newContent, position: position));
      } else {
        result.add(Line(
          id: generateId(),
          pageId: pageId,
          position: position,
          content: newContent,
          date: todayDateOnly,
          isDateManuallyEdited: false,
        ));
      }
      position++;
    }

    // Deletes sem par (sobraram mais deletes que inserts): removidas, ponto.

    // Inserts sem par (sobraram mais inserts que deletes): linhas 100% novas.
    for (var p = pairCount; p < inserts.length; p++) {
      result.add(Line(
        id: generateId(),
        pageId: pageId,
        position: position,
        content: newContents[inserts[p]],
        date: todayDateOnly,
        isDateManuallyEdited: false,
      ));
      position++;
    }
  }

  return result;
}