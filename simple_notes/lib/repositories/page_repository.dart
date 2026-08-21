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

  Future<NotePage> _toModelWithLines(PageRow row) async {
    final lineRows = await (db.select(db.lines)
          ..where((l) => l.pageId.equals(row.id))
          ..orderBy([(l) => OrderingTerm(expression: l.position)]))
        .get();

    final lines = lineRows
        .map((l) => Line(
              id: l.id,
              pageId: l.pageId,
              position: l.position,
              content: l.content,
              date: l.date,
              isDateManuallyEdited: l.isDateManuallyEdited,
            ))
        .toList();

    return NotePage(
      id: row.id,
      blockId: row.blockId,
      title: row.title,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      isEncrypted: row.isEncrypted,
      lines: lines,
    );
  }
}