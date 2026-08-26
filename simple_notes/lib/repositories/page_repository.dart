import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../database/app_database.dart';
import '../models/page.dart';
import '../models/line.dart';

class PageRepository {
  final AppDatabase db;
  final _uuid = const Uuid();

  PageRepository(this.db);

  Stream<List<NotePage>> watchPagesInBlock(String? blockId) {
    final query = db.select(db.pages)
      ..where((p) => blockId == null ? p.blockId.isNull() : p.blockId.equals(blockId));
    return query.watch().asyncMap((rows) async {
      final pages = <NotePage>[];
      for (final row in rows) {
        pages.add(await _toModelWithLines(row));
      }
      return pages;
    });
  }

  Future<NotePage?> getPage(String id) async {
    final row =
        await (db.select(db.pages)..where((p) => p.id.equals(id))).getSingleOrNull();
    if (row == null) return null;
    return _toModelWithLines(row);
  }

  Future<NotePage> create({String? blockId, required String title}) async {
    final id = _uuid.v4();
    final now = DateTime.now();
    await db.into(db.pages).insert(
          PagesCompanion.insert(
            id: id,
            blockId: Value(blockId),
            title: title,
            createdAt: now,
            updatedAt: now,
          ),
        );
    return NotePage(id: id, blockId: blockId, title: title, createdAt: now, updatedAt: now);
  }

  Future<void> delete(String id) async {
    await (db.delete(db.lines)..where((l) => l.pageId.equals(id))).go();
    await (db.delete(db.pages)..where((p) => p.id.equals(id))).go();
  }

  /// Persiste o texto ainda não "enviado" — chamado a cada pausa de digitação
  /// no campo de composição, sem atribuir data ainda.
  Future<void> saveDraft(String pageId, String draft) async {
    await (db.update(db.pages)..where((p) => p.id.equals(pageId)))
        .write(PagesCompanion(draftContent: Value(draft)));
  }

  /// Equivalente a "apertar Enter": confirma o rascunho salvo como uma ou
  /// mais linhas novas (se houver quebras de linha internas), cada uma
  /// carimbada com a data de hoje, e esvazia o rascunho.
  Future<void> sendDraft(String pageId) async {
    final pageRow =
        await (db.select(db.pages)..where((p) => p.id.equals(pageId))).getSingle();

    if (pageRow.draftContent.trim().isEmpty) return;

    final existingCount = (await (db.select(db.lines)
              ..where((l) => l.pageId.equals(pageId)))
            .get())
        .length;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final newContents = pageRow.draftContent.split('\n');

    await db.transaction(() async {
      var position = existingCount;
      for (final content in newContents) {
        await db.into(db.lines).insert(
              LinesCompanion.insert(
                id: _uuid.v4(),
                pageId: pageId,
                position: position,
                content: content,
                date: today,
              ),
            );
        position++;
      }

      await (db.update(db.pages)..where((p) => p.id.equals(pageId))).write(
        PagesCompanion(draftContent: const Value(''), updatedAt: Value(now)),
      );
    });
  }

  /// Edita o conteúdo de uma linha já enviada. Não toca na data — por
  /// construção, satisfaz o RF03 sem precisar de heurística de diff.
  Future<void> updateLineContent(String lineId, String newContent) async {
    await (db.update(db.lines)..where((l) => l.id.equals(lineId)))
        .write(LinesCompanion(content: Value(newContent)));
  }

  Future<void> deleteLine(String lineId) async {
    await (db.delete(db.lines)..where((l) => l.id.equals(lineId))).go();
  }

  /// RF03: sobrescrita manual da data de uma linha específica.
  Future<void> setLineDateManually(String lineId, DateTime date) async {
    final dateOnly = DateTime(date.year, date.month, date.day);
    await (db.update(db.lines)..where((l) => l.id.equals(lineId))).write(
      LinesCompanion(date: Value(dateOnly), isDateManuallyEdited: const Value(true)),
    );
  }

  Future<List<Line>> _fetchLines(String pageId) async {
    final rows = await (db.select(db.lines)
          ..where((l) => l.pageId.equals(pageId))
          ..orderBy([(l) => OrderingTerm(expression: l.position)]))
        .get();

    return rows
        .map((l) => Line(
              id: l.id,
              pageId: l.pageId,
              position: l.position,
              content: l.content,
              date: l.date,
              isDateManuallyEdited: l.isDateManuallyEdited,
            ))
        .toList();
  }

  Future<NotePage> _toModelWithLines(PageRow row) async {
    final lines = await _fetchLines(row.id);
    return NotePage(
      id: row.id,
      blockId: row.blockId,
      title: row.title,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      isEncrypted: row.isEncrypted,
      draftContent: row.draftContent,
      lines: lines,
    );
  }
}