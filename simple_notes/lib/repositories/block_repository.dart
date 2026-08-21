import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../database/app_database.dart';
import '../models/block.dart';

class BlockRepository {
  final AppDatabase db;
  final _uuid = const Uuid();

  BlockRepository(this.db);

  Future<List<Block>> getAll() async {
    final rows = await db.select(db.blocks).get();
    return rows.map(_toModel).toList();
  }

  Stream<List<Block>> watchAll() {
    return db.select(db.blocks).watch().map(
          (rows) => rows.map(_toModel).toList(),
        );
  }

  Future<Block> create(String name) async {
    final id = _uuid.v4();
    final now = DateTime.now();
    await db.into(db.blocks).insert(
          BlocksCompanion.insert(
            id: id,
            name: name,
            createdAt: now,
          ),
        );
    return Block(id: id, name: name, createdAt: now);
  }

  Future<void> rename(String id, String newName) async {
    await (db.update(db.blocks)..where((b) => b.id.equals(id)))
        .write(BlocksCompanion(name: Value(newName)));
  }

  Future<void> delete(String id) async {
    await (db.delete(db.blocks)..where((b) => b.id.equals(id))).go();
  }

  Block _toModel(BlockRow row) => Block(
        id: row.id,
        name: row.name,
        createdAt: row.createdAt,
        isEncrypted: row.isEncrypted,
    );
}