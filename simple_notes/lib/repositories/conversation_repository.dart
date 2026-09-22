import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../database/app_database.dart';
import '../database/tables.dart' show MessageType;
import '../models/conversation.dart';
import '../models/message.dart';

/// Cobre o CRUD de Conversa (RF01, Sprint 0) e, a partir da Sprint 1, as
/// operações sobre Mensagem de texto (RF02, RF03). Anexos de arquivo
/// (RF02.3) entram na Sprint 2 e a associação com Tag (RF04) na Sprint 3 —
/// ambas reaproveitando esta mesma instância de [AppDatabase].
class ConversationRepository {
  final AppDatabase db;
  final _uuid = const Uuid();

  ConversationRepository(this.db);

  // ---------------------------------------------------------------------
  // Conversa (RF01) — inalterado desde a Sprint 0
  // ---------------------------------------------------------------------

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

  /// Exclui a Conversa e, em cascata, suas Mensagens.
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

  // ---------------------------------------------------------------------
  // Mensagem — texto (RF02, RF03) — Sprint 1
  // ---------------------------------------------------------------------

  /// RF06 (chat) — todas as Mensagens de uma Conversa, na ordem de envio
  /// (`position`). Note que isso NÃO é necessariamente a ordem por `data`:
  /// a data pode ser sobrescrita manualmente (RF02.6) e ficar "fora de
  /// ordem" em relação à posição — isso é esperado, o conteúdo da Conversa
  /// sempre segue `position`, nunca `data` (ver modelo de dados da spec).
  Stream<List<Message>> watchMessages(String conversationId) {
    final query = db.select(db.messages)
      ..where((m) => m.conversationId.equals(conversationId))
      ..orderBy([(m) => OrderingTerm(expression: m.position)]);
    return query.watch().map((rows) => rows.map(_messageToModel).toList());
  }

  /// RF02.1 — salva o texto em composição sem atribuir data. Chamado a cada
  /// pausa de digitação; o debounce fica a cargo da UI (`ChatScreen`), não
  /// deste método.
  Future<void> saveDraft(String conversationId, String draft) async {
    await (db.update(db.conversations)
          ..where((c) => c.id.equals(conversationId)))
        .write(ConversationsCompanion(rascunho: Value(draft)));
  }

  /// RF02.2 — confirma o rascunho como UMA única Mensagem de texto, mesmo
  /// que tenha quebras de linha internas (diferente da v4.0, que gerava uma
  /// Linha por quebra — aqui uma ação de envio = uma Mensagem). A data é
  /// atribuída neste exato momento, nunca durante a digitação.
  ///
  /// Não faz nada se o rascunho estiver vazio (só espaços em branco).
  Future<void> sendDraft(String conversationId) async {
    final conversation = await (db.select(db.conversations)
          ..where((c) => c.id.equals(conversationId)))
        .getSingle();

    final content = conversation.rascunho.trim();
    if (content.isEmpty) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    await db.transaction(() async {
      final position = await _nextPosition(conversationId);

      await db.into(db.messages).insert(
            MessagesCompanion.insert(
              id: _uuid.v4(),
              conversationId: conversationId,
              position: position,
              tipo: Value(MessageType.texto),
              conteudoTexto: Value(content),
              data: today,
            ),
          );

      await (db.update(db.conversations)
            ..where((c) => c.id.equals(conversationId)))
          .write(
        ConversationsCompanion(
          rascunho: const Value(''),
          atualizadoEm: Value(now),
        ),
      );
    });
  }

  /// RF02.4 / RF03 — reescreve o conteúdo de uma Mensagem de texto já
  /// enviada SEM tocar em `data`. A imutabilidade da data é garantida por
  /// este método simplesmente nunca escrever a coluna `data` aqui — não há
  /// heurística de diff/similaridade envolvida (ver nota de RF03 na spec).
  Future<void> updateMessageContent(String messageId, String newContent) async {
    await (db.update(db.messages)..where((m) => m.id.equals(messageId)))
        .write(MessagesCompanion(conteudoTexto: Value(newContent)));
  }

  /// RF02.5 — exclusão explícita e distinta de qualquer edição de conteúdo.
  Future<void> deleteMessage(String messageId) async {
    await (db.delete(db.messages)..where((m) => m.id.equals(messageId))).go();
  }

  /// RF02.6 / RF03 — sobrescrita manual da data de qualquer Mensagem, a
  /// qualquer momento, independente do fluxo automático de envio.
  Future<void> setMessageDateManually(String messageId, DateTime date) async {
    final dateOnly = DateTime(date.year, date.month, date.day);
    await (db.update(db.messages)..where((m) => m.id.equals(messageId))).write(
      MessagesCompanion(
        data: Value(dateOnly),
        dataEditadaManualmente: const Value(true),
      ),
    );
  }

  Future<int> _nextPosition(String conversationId) async {
    final maxRow = await (db.selectOnly(db.messages)
          ..addColumns([db.messages.position.max()])
          ..where(db.messages.conversationId.equals(conversationId)))
        .getSingleOrNull();
    return (maxRow?.read(db.messages.position.max()) ?? -1) + 1;
  }

  Message _messageToModel(MessageRow row) => Message(
        id: row.id,
        conversationId: row.conversationId,
        tagId: row.tagId,
        position: row.position,
        tipo: row.tipo,
        conteudoTexto: row.conteudoTexto,
        arquivoPath: row.arquivoPath,
        arquivoNomeOriginal: row.arquivoNomeOriginal,
        arquivoNomeExibicao: row.arquivoNomeExibicao,
        arquivoMimeType: row.arquivoMimeType,
        arquivoTamanhoBytes: row.arquivoTamanhoBytes,
        data: row.data,
        dataEditadaManualmente: row.dataEditadaManualmente,
      );
}