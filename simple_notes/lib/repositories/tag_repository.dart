import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../database/app_database.dart';
import '../models/tag.dart';

/// Lançada ao renomear uma Tag para um nome que já pertence a outra
/// Tag da mesma Conversa.
class DuplicateTagNameException implements Exception {
  final String nome;
  const DuplicateTagNameException(this.nome);
  @override
  String toString() => 'Já existe uma tag chamada "$nome" nesta conversa.';
}

/// RF04 — CRUD de Tag, sempre no escopo de uma Conversa. A unicidade de nome
/// vale dentro da Conversa (não no schema): nome em MAIÚSCULAS, sem espaços
/// nas pontas e com espaços internos colapsados. Símbolos são permitidos.
class TagRepository {
  final AppDatabase db;
  final _uuid = const Uuid();

  TagRepository(this.db);

  /// Regra única de normalização, usada em criar, renomear e (Sprint 4) buscar.
  static String normalizeName(String raw) =>
      raw.trim().replaceAll(RegExp(r'\s+'), ' ').toUpperCase();

  /// Tags de UMA Conversa, em ordem alfabética, ao vivo.
  Stream<List<Tag>> watchByConversation(String conversationId) {
    final query = db.select(db.tags)
      ..where((t) => t.conversationId.equals(conversationId))
      ..orderBy([(t) => OrderingTerm.asc(t.nome)]);
    return query.watch().map((rows) => rows.map(_toModel).toList());
  }

  /// Cria a Tag na Conversa, ou devolve a já existente se o nome normalizado
  /// repetir (nesse caso a cor existente é mantida).
  Future<Tag> createOrGet({
    required String conversationId,
    required String nome,
    required String cor,
  }) async {
    final normalized = normalizeName(nome);
    if (normalized.isEmpty) {
      throw ArgumentError('O nome da tag não pode ser vazio.');
    }

    return db.transaction(() async {
      final existing = await (db.select(db.tags)
            ..where((t) =>
                t.conversationId.equals(conversationId) &
                t.nome.equals(normalized)))
          .getSingleOrNull();
      if (existing != null) return _toModel(existing);

      final id = _uuid.v4();
      await db.into(db.tags).insert(
            TagsCompanion.insert(
              id: id,
              conversationId: conversationId,
              nome: normalized,
              cor: cor,
            ),
          );
      return Tag(
        id: id,
        conversationId: conversationId,
        nome: normalized,
        cor: cor,
      );
    });
  }

  /// Atualiza nome e/ou cor (vale para as mensagens da Conversa que usam a Tag).
  /// Lança [DuplicateTagNameException] se o novo nome já for de OUTRA Tag
  /// da mesma Conversa.
  Future<void> update(String id, {String? nome, String? cor}) async {
    String? normalized;
    if (nome != null) {
      normalized = normalizeName(nome);
      if (normalized.isEmpty) {
        throw ArgumentError('O nome da tag não pode ser vazio.');
      }

      final row = await (db.select(db.tags)..where((t) => t.id.equals(id)))
          .getSingleOrNull();
      if (row == null) throw StateError('A tag não existe mais.');

      final clash = await (db.select(db.tags)
            ..where((t) =>
                t.conversationId.equals(row.conversationId) &
                t.nome.equals(normalized!) &
                t.id.equals(id).not()))
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

  Tag _toModel(TagRow row) => Tag(
        id: row.id,
        conversationId: row.conversationId,
        nome: row.nome,
        cor: row.cor,
      );
}