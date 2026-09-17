import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../database/app_database.dart';
import '../models/conversation.dart';

/// Cobre o CRUD de Conversa (RF01) — escopo da Sprint 0.
///
/// Operações sobre Mensagem (RF02/RF03: rascunho, envio, edição, anexos) e
/// sobre Tag (RF04) entram aqui a partir da Sprint 1 e Sprint 3
/// respectivamente, reaproveitando esta mesma instância de [AppDatabase] —
/// por isso o `delete` já limpa as Mensagens da conversa, mesmo a Sprint 0
/// ainda não criando nenhuma.
class ConversationRepository {
  final AppDatabase db;
  final _uuid = const Uuid();

  ConversationRepository(this.db);

  Stream<List<Conversation>> watchAll() {
    final query = db.select(db.conversations)
      ..orderBy([(c) => OrderingTerm.desc(c.atualizadoEm)]);
    return query.watch().map((rows) => rows.map(_toModel).toList());
  }

  Future<Conversation?> getById(String id) async {
    final row = await (db.select(db.conversations)
          ..where((c) => c.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _toModel(row);
  }

  Future<Conversation> create({required String titulo}) async {
    final id = _uuid.v4();
    final now = DateTime.now();
    await db.into(db.conversations).insert(
          ConversationsCompanion.insert(
            id: id,
            titulo: titulo,
            criadoEm: now,
            atualizadoEm: now,
          ),
        );
    return Conversation(
      id: id,
      titulo: titulo,
      criadoEm: now,
      atualizadoEm: now,
    );
  }

  Future<void> updateTitulo(String id, String novoTitulo) async {
    await (db.update(db.conversations)..where((c) => c.id.equals(id))).write(
      ConversationsCompanion(
        titulo: Value(novoTitulo),
        atualizadoEm: Value(DateTime.now()),
      ),
    );
  }

  /// Exclui a Conversa e, em cascata, suas Mensagens. O vínculo de Tag em
  /// cada Mensagem (`Messages.tagId`) usa `onDelete: setNull` na definição
  /// da tabela, então excluir uma Tag nunca impede excluir uma Conversa (ou
  /// vice-versa).
  Future<void> delete(String id) async {
    await (db.delete(db.messages)..where((m) => m.conversationId.equals(id)))
        .go();
    await (db.delete(db.conversations)..where((c) => c.id.equals(id))).go();
  }

  Conversation _toModel(ConversationRow row) => Conversation(
        id: row.id,
        titulo: row.titulo,
        criadoEm: row.criadoEm,
        atualizadoEm: row.atualizadoEm,
        protegidoPorSenha: row.protegidoPorSenha,
        rascunho: row.rascunho,
      );
}
