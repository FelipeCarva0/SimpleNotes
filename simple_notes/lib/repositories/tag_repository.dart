import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../database/app_database.dart';
import '../models/tag.dart';

/// Lançada ao renomear uma Tag para um nome que já pertence a outra.
class DuplicateTagNameException implements Exception {
  final String nome;
  const DuplicateTagNameException(this.nome);
  @override
  String toString() => 'Já existe uma tag chamada "$nome".';
}

/// RF04 — CRUD de Tag. A unicidade de nome é garantida aqui (não no
/// schema): o nome é normalizado para MAIÚSCULAS, sem espaços nas pontas e
/// com espaços internos colapsados. Símbolos especiais são permitidos.
class TagRepository {
  final AppDatabase db;
  final _uuid = const Uuid();

  TagRepository(this.db);

  /// Regra única de normalização, usada em criar, renomear e (Sprint 4) buscar.
  static String normalizeName(String raw) =>
      raw.trim().replaceAll(RegExp(r'\s+'), ' ').toUpperCase();

  Stream<List<Tag>> watchAll() {
    final query = db.select(db.tags)
      ..orderBy([(t) => OrderingTerm.asc(t.nome)]);
    return query.watch().map((rows) => rows.map(_toModel).toList());
  }

  /// Cria a Tag, ou devolve a já existente se o nome normalizado repetir
  /// (nesse caso a cor existente é mantida).
  Future<Tag> createOrGet({required String nome, required String cor}) async {
    final normalized = normalizeName(nome);
    if (normalized.isEmpty) {
      throw ArgumentError('O nome da tag não pode ser vazio.');
    }

    return db.transaction(() async {
      final existing = await (db.select(db.tags)
            ..where((t) => t.nome.equals(normalized)))
          .getSingleOrNull();
      if (existing != null) return _toModel(existing);

      final id = _uuid.v4();
      await db.into(db.tags).insert(
            TagsCompanion.insert(id: id, nome: normalized, cor: cor),
          );
      return Tag(id: id, nome: normalized, cor: cor);
    });
  }

  /// Atualiza nome e/ou cor (vale para todas as mensagens que usam a Tag).
  /// Lança [DuplicateTagNameException] se o novo nome já for de OUTRA Tag.
  Future<void> update(String id, {String? nome, String? cor}) async {
    String? normalized;
    if (nome != null) {
      normalized = normalizeName(nome);
      if (normalized.isEmpty) {
        throw ArgumentError('O nome da tag não pode ser vazio.');
      }
      final clash = await (db.select(db.tags)
            ..where((t) => t.nome.equals(normalized!) & t.id.equals(id).not()))
          .getSingleOrNull();
      if (clash != null) throw DuplicateTagNameException(normalized);
    }

    await (db.update(db.tags)..where((t) => t.id.equals(id))).write(
      TagsCompanion(
        nome: normalized != null ? Value(normalized) : const Value.absent(),
        cor: cor != null ? Value(cor) : const Value.absent(),
      ),
    );
  }

  /// Exclui só a Tag; as mensagens permanecem e apenas perdem a tag.
  /// Zera `tagId` explicitamente (sem depender só do ON DELETE SET NULL).
  Future<void> delete(String id) async {
    await db.transaction(() async {
      await (db.update(db.messages)..where((m) => m.tagId.equals(id)))
          .write(const MessagesCompanion(tagId: Value(null)));
      await (db.delete(db.tags)..where((t) => t.id.equals(id))).go();
    });
  }

  /// Quantas mensagens usam a Tag (para o aviso de confirmação ao excluir).
  Future<int> countMessages(String tagId) async {
    final count = db.messages.id.count();
    final row = await (db.selectOnly(db.messages)
          ..addColumns([count])
          ..where(db.messages.tagId.equals(tagId)))
        .getSingle();
    return row.read(count) ?? 0;
  }

  Tag _toModel(TagRow row) => Tag(id: row.id, nome: row.nome, cor: row.cor);
}