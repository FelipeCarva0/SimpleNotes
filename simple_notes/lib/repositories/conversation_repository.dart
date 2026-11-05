import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../database/app_database.dart';
import '../database/tables.dart' show MessageType;
import '../models/conversation.dart';
import '../models/message.dart';
import 'dart:io';
import '../storage/media_storage.dart';
import '../security/password_crypto.dart';
import 'new_message.dart';
import 'tag_repository.dart'; // ← ADICIONAR

class _DecryptedFields {
  final String? conteudoTexto;
  final String? arquivoNomeOriginal;
  final String? arquivoNomeExibicao;
  final String? arquivoMimeType;
  const _DecryptedFields({
    this.conteudoTexto,
    this.arquivoNomeOriginal,
    this.arquivoNomeExibicao,
    this.arquivoMimeType,
  });
}

class ConversationRepository {
  final AppDatabase db;
  final MediaStorage storage;
  final _uuid = const Uuid();

  /// Cache em memória das chaves derivadas, por `conversationId`. Nunca vai
  /// para disco. É o que permite `watchMessages` entregar os campos já
  /// decifrados sem que a `ChatScreen` saiba de criptografia.
  final Map<String, List<int>> _unlockedKeys = {};
  final Map<String, _DecryptedFields> _plaintextCache = {};

  /// True se a conversa está protegida e a chave está na sessão (ou seja,
  /// o usuário já desbloqueou nesta execução do app).
  bool isUnlocked(String conversationId) =>
      _unlockedKeys.containsKey(conversationId);

  /// Remove a chave da sessão (usado pelo "Bloquear" e ao fechar o app).
  void lockConversation(String conversationId) {
    _unlockedKeys.remove(conversationId);
    _plaintextCache.removeWhere((_, _) => true);
  }

  void lockAll() {
    _unlockedKeys.clear();
    _plaintextCache.clear();
  }

  ConversationRepository(this.db, this.storage);

  Stream<List<Conversation>> watchAll() {
    final query = db.select(db.conversations)
      ..orderBy([(c) => OrderingTerm.desc(c.atualizadoEm)]);
    return query.watch().map((rows) => rows.map(_toModel).toList());
  }

  Future<Conversation?> getById(String id) async {
    final row = await (db.select(
      db.conversations,
    )..where((c) => c.id.equals(id))).getSingleOrNull();
    return row == null ? null : _toModel(row);
  }

  Future<Conversation> create({required String titulo}) async {
    final id = _uuid.v4();
    final now = DateTime.now();
    await db
        .into(db.conversations)
        .insert(
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

  
  Future<List<Message>?> searchMessagesByText(
    String conversationId,
    String query,
  ) async {
    final protected = await _isProtected(conversationId);
    if (protected) return null;

    final like = '%${query.replaceAll('%', r'\%').replaceAll('_', r'\_')}%';
    final query_ = db.select(db.messages)
      ..where(
        (m) =>
            m.conversationId.equals(conversationId) &
            (m.conteudoTexto.like(like) |
                m.arquivoNomeOriginal.like(like) |
                m.arquivoNomeExibicao.like(like)),
      )
      ..orderBy([(m) => OrderingTerm(expression: m.position)]);
    final rows = await query_.get();
    return rows.map(_messageToModel).toList();
  }

  /// Exclui a Conversa, suas Mensagens e a pasta de mídia no filesystem.
  Future<void> delete(String id) async {
    _plaintextCache.clear();
    await db.transaction(() async {
      await (db.delete(
        db.messages,
      )..where((m) => m.conversationId.equals(id))).go();
      await (db.delete(
        db.tags,
      )..where((t) => t.conversationId.equals(id))).go();
      await (db.delete(db.conversations)..where((c) => c.id.equals(id))).go();
    });
    await storage.deleteConversationFolder(id);
  }

  Conversation _toModel(ConversationRow row) => Conversation(
    id: row.id,
    titulo: row.titulo,
    criadoEm: row.criadoEm,
    atualizadoEm: row.atualizadoEm,
    protegidoPorSenha: row.protegidoPorSenha,
    rascunho: row.rascunho,
  );

  
  /// RF06 (chat) — todas as Mensagens de uma Conversa, na ordem de envio
  /// (`position`). Note que isso NÃO é necessariamente a ordem por `data`:
  /// a data pode ser sobrescrita manualmente (RF02.6) e ficar "fora de
  /// ordem" em relação à posição — isso é esperado, o conteúdo da Conversa
  /// sempre segue `position`, nunca `data` (ver modelo de dados da spec).
  /// RF06 (chat) — todas as Mensagens de uma Conversa, na ordem de envio
  /// (`position`). Sprint 6: delega a decifragem para `_decryptRows`, que
  /// usa `Future.wait` (decifra em paralelo).

  Stream<List<Message>> watchMessages(String conversationId) {
    final query = db.select(db.messages)
      ..where((m) => m.conversationId.equals(conversationId))
      ..orderBy([(m) => OrderingTerm(expression: m.position)]);

    return query.watch().asyncMap((rows) async {
      final isProtected = await _isProtected(conversationId);
      if (!isProtected) {
        return rows.map(_messageToModel).toList();
      }
      final key = _unlockedKeys[conversationId];
      return _decryptRows(rows, true, key);
    });
  }

  /// Página "de chat": devolve as [limit] mensagens MAIS RECENTES
  /// (maior `position`) começando a [offset] mensagens do fim. A ordem
  /// devolvida é **crescente** (mais antigas primeiro) — igual ao
  /// `watchMessages`.
  ///
  /// - `offset: 0` → as `limit` mais recentes.
  /// - `offset: 100` → as `limit` anteriores a essas.
  ///
  /// Usada pela `ChatScreen`. A `SearchResultsScreen` usa
  /// `watchAllMessages` (sem limite).
  Stream<List<Message>> watchMessagesPaginated(
    String conversationId, {
    int limit = 100,
    int offset = 0,
  }) {
    final query = db.select(db.messages)
      ..where((m) => m.conversationId.equals(conversationId))
      ..orderBy([(m) => OrderingTerm.desc(m.position)])
      ..limit(limit, offset: offset);

    return query.watch().asyncMap((rows) async {
      final isProtected = await _isProtected(conversationId);
      if (!isProtected) {
        // Caminho rápido: sem decifrar, sem Future.wait, sem cache.
        return rows.map(_messageToModel).toList();
      }
      final key = _unlockedKeys[conversationId];
      return _decryptRows(rows, true, key);
    });
  }

  /// Igual a [watchMessages], sem paginação. Usado pela `SearchResultsScreen`
  /// para varrer a conversa inteira (a paginação da `ChatScreen` não pode
  /// afetar a busca).
  Stream<List<Message>> watchAllMessages(String conversationId) =>
      watchMessages(conversationId);

  /// Quantas mensagens a conversa tem. Usado pela `ChatScreen` para saber
  /// quando parar de paginar.
  Future<int> countMessages(String conversationId) async {
    final count = db.messages.id.count();
    final row =
        await (db.selectOnly(db.messages)
              ..addColumns([count])
              ..where(db.messages.conversationId.equals(conversationId)))
            .getSingle();
    return row.read(count) ?? 0;
  }

  /// Contagem de mensagens da conversa, ao vivo. Reage a qualquer
  /// inserção ou exclusão, venha de onde vier.
  Stream<int> watchMessageCount(String conversationId) {
    final count = db.messages.id.count();
    final query = db.selectOnly(db.messages)
      ..addColumns([count])
      ..where(db.messages.conversationId.equals(conversationId));
    return query.watchSingle().map((row) => row.read(count) ?? 0);
  }

  /// Consulta `protegidoPorSenha` da conversa. Barato (índice implícito em
  /// `conversations.id`).
  Future<bool> _isProtected(String conversationId) async {
    final row = await (db.select(
      db.conversations,
    )..where((c) => c.id.equals(conversationId))).getSingleOrNull();
    return row?.protegidoPorSenha ?? false;
  }

  
  Future<List<Message>> _decryptRows(
    List<MessageRow> rows,
    bool isProtected,
    List<int>? key,
  ) async {
    if (!isProtected) {
      return rows.map(_messageToModel).toList();
    }
    if (key == null) {
      return rows.map(_withPlaceholders).toList();
    }
    return Future.wait(
      rows.map((row) async {
        // 6.8: cache quente → re-render instantâneo.
        final cached = _plaintextCache[row.id];
        if (cached != null) {
          return _messageToModel(
            row,
            overrides: (
              conteudoTexto: cached.conteudoTexto,
              arquivoNomeOriginal: cached.arquivoNomeOriginal,
              arquivoNomeExibicao: cached.arquivoNomeExibicao,
              arquivoMimeType: cached.arquivoMimeType,
            ),
          );
        }

        _DecryptedFields fields;
        if (row.tipo == MessageType.texto) {
          final raw = row.conteudoTexto;
          fields = _DecryptedFields(
            conteudoTexto: raw == null
                ? null
                : await PasswordCrypto.decryptField(raw, key),
            arquivoNomeOriginal: row.arquivoNomeOriginal,
            arquivoNomeExibicao: row.arquivoNomeExibicao,
            arquivoMimeType: row.arquivoMimeType,
          );
        } else {
          final rawOriginal = row.arquivoNomeOriginal;
          final rawExibicao = row.arquivoNomeExibicao;
          final rawMime = row.arquivoMimeType;
          fields = _DecryptedFields(
            conteudoTexto: row.conteudoTexto,
            arquivoNomeOriginal: rawOriginal == null
                ? null
                : await PasswordCrypto.decryptField(rawOriginal, key),
            arquivoNomeExibicao: rawExibicao == null
                ? null
                : await PasswordCrypto.decryptField(rawExibicao, key),
            arquivoMimeType: rawMime == null
                ? null
                : await PasswordCrypto.decryptField(rawMime, key),
          );
        }

        _plaintextCache[row.id] = fields;
        return _messageToModel(
          row,
          overrides: (
            conteudoTexto: fields.conteudoTexto,
            arquivoNomeOriginal: fields.arquivoNomeOriginal,
            arquivoNomeExibicao: fields.arquivoNomeExibicao,
            arquivoMimeType: fields.arquivoMimeType,
          ),
        );
      }),
    );
  }


  Message _withPlaceholders(MessageRow row) => _messageToModel(
    row,
    overrides: (
      conteudoTexto: row.conteudoTexto == null ? null : '••••••',
      arquivoNomeOriginal: row.arquivoNomeOriginal == null ? null : '••••',
      arquivoNomeExibicao: row.arquivoNomeExibicao == null ? null : '••••',
      arquivoMimeType: row.arquivoMimeType == null ? null : '••••',
    ),
  );

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
    _plaintextCache
        .clear(); // a nova Mensagem vai invalidar o cache de todas as anteriores
    final conversation = await (db.select(
      db.conversations,
    )..where((c) => c.id.equals(conversationId))).getSingle();

    final content = conversation.rascunho.trim();
    if (content.isEmpty) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Se a conversa está protegida, cifra o conteúdo antes de gravar.
    // Se não está, `_encodeForStorage` devolve o texto como está.
    final storedContent = await _encodeForStorage(conversationId, content);

    await db.transaction(() async {
      final position = await _nextPosition(conversationId);

      await db
          .into(db.messages)
          .insert(
            MessagesCompanion.insert(
              id: _uuid.v4(),
              conversationId: conversationId,
              position: position,
              tipo: Value(MessageType.texto),
              conteudoTexto: Value(storedContent),
              data: today,
            ),
          );

      await (db.update(
        db.conversations,
      )..where((c) => c.id.equals(conversationId))).write(
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
    // Descobre a conversa da mensagem para saber se precisa cifrar.
    _plaintextCache.remove(messageId);
    final row = await (db.select(
      db.messages,
    )..where((m) => m.id.equals(messageId))).getSingleOrNull();
    if (row == null) return;

    final stored = await _encodeForStorage(row.conversationId, newContent);

    await (db.update(db.messages)..where((m) => m.id.equals(messageId))).write(
      MessagesCompanion(conteudoTexto: Value(stored)),
    );
  }

  /// RF02.5 — exclusão explícita e distinta de qualquer edição de conteúdo.
  Future<void> deleteMessage(String messageId) async {
    _plaintextCache.remove(messageId);
    final row = await (db.select(
      db.messages,
    )..where((m) => m.id.equals(messageId))).getSingleOrNull();
    if (row == null) return;

    await (db.delete(db.messages)..where((m) => m.id.equals(messageId))).go();

    final path = row.arquivoPath;
    if (path != null) await storage.delete(path);
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

  /// Sprint 6: `position` passa a usar **gaps de 1000** para permitir
  /// inserções no meio sem renumerar em massa. Conversas antigas têm
  /// `position` 0..N-1, que continua sendo uma sequência válida (o gap
  /// só é criado ao inserir novas).
  static const int _positionGap = 1000;
  static const int _sqlChunkSize = 500;

  Future<int> _nextPosition(String conversationId) async {
    final maxRow =
        await (db.selectOnly(db.messages)
              ..addColumns([db.messages.position.max()])
              ..where(db.messages.conversationId.equals(conversationId)))
            .getSingleOrNull();
    final last = maxRow?.read(db.messages.position.max());
    return last == null ? _positionGap : last + _positionGap;
  }

  Message _messageToModel(
    MessageRow row, {
    ({
      String? conteudoTexto,
      String? arquivoNomeOriginal,
      String? arquivoNomeExibicao,
      String? arquivoMimeType,
    })?
    overrides,
  }) => Message(
    id: row.id,
    conversationId: row.conversationId,
    tagId: row.tagId,
    position: row.position,
    tipo: row.tipo,
    conteudoTexto: overrides?.conteudoTexto ?? row.conteudoTexto,
    arquivoPath: row.arquivoPath,
    arquivoNomeOriginal:
        overrides?.arquivoNomeOriginal ?? row.arquivoNomeOriginal,
    arquivoNomeExibicao:
        overrides?.arquivoNomeExibicao ?? row.arquivoNomeExibicao,
    arquivoMimeType: overrides?.arquivoMimeType ?? row.arquivoMimeType,
    arquivoTamanhoBytes: row.arquivoTamanhoBytes,
    data: row.data,
    dataEditadaManualmente: row.dataEditadaManualmente,
  );

  /// RF02.3 — copia o arquivo para o storage e cria uma Mensagem de anexo
  /// com a data de hoje. Se o banco falhar, remove o arquivo copiado para
  /// não deixar órfão.
  Future<void> sendAttachment({
    required String conversationId,
    required MessageType tipo,
    required File file,
    required String nomeOriginal,
  }) async {
    _plaintextCache.clear();
    assert(tipo != MessageType.texto, 'Use sendDraft para texto');

    final stored = await storage.saveFile(file, conversationId);

    // Cifra os metadados ANTES de abrir a transação (encryptField é async
    // e não precisa estar dentro da tx; a tx só precisa ser atômica sobre
    // as escritas no BD).
    final storedNomeOriginal = await _encodeForStorage(
      conversationId,
      nomeOriginal,
    );
    final storedNomeExibicao = await _encodeForStorage(
      conversationId,
      nomeOriginal,
    );
    final storedMime = await _encodeForStorage(conversationId, stored.mimeType);

    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      await db.transaction(() async {
        final position = await _nextPosition(conversationId);

        await db
            .into(db.messages)
            .insert(
              MessagesCompanion.insert(
                id: _uuid.v4(),
                conversationId: conversationId,
                position: position,
                tipo: Value(tipo),
                arquivoPath: Value(stored.relativePath),
                arquivoNomeOriginal: Value(storedNomeOriginal),
                arquivoNomeExibicao: Value(storedNomeExibicao),
                arquivoMimeType: Value(storedMime),
                arquivoTamanhoBytes: Value(stored.sizeBytes),
                data: today,
              ),
            );

        await (db.update(db.conversations)
              ..where((c) => c.id.equals(conversationId)))
            .write(ConversationsCompanion(atualizadoEm: Value(now)));
      });
    } catch (_) {
      await storage.delete(stored.relativePath);
      rethrow;
    }
  }

  
  /// Sprint 7 (7.1a) — insere N mensagens de uma vez, em **duas fases**:
  ///
  /// **Fase 1 (fora da transação):** copia arquivos para o storage e cifra
  /// metadados (paralelo, via `Future.wait`). Se [isCancelled] retornar
  /// `true` entre arquivos, aborta a fase 1, apaga o que já foi copiado e
  /// devolve lista vazia (sem tocar no banco).
  ///
  /// **Fase 2 (uma transação):** calcula `_nextPosition` uma vez, atribui
  /// `base + i * _positionGap` para cada item, insere todas as linhas e
  /// atualiza `Conversations.atualizadoEm` — tudo ou nada.
  ///
  /// Se qualquer passo falhar, apaga **todos** os arquivos copiados nesta
  /// chamada (invariante 18 do `SPRINT_7_PLAN.md`) e relança o erro.
  ///
  /// Devolve a lista de `id`s criados, na mesma ordem de [items].
  /// Lista vazia → no-op (devolve `[]`).
  ///
  /// Notas:
  /// - **Não** valida tag contra a conversa aqui — o chamador (encaminhar)
  ///   já resolveu via `TagRepository.createOrGet`. O `tagId` chega
  ///   pertencendo ao destino. Se quiser defesa em profundidade, o chamador
  ///   deve validar antes; aqui confiamos no contrato (S7-2: primitiva única).
  /// - **Não** faz commit por lote de 10 — a divisão em lotes é decisão do
  ///   chamador (S7-11), para que cada `appendMessages` seja atômico por si
  ///   só. Ver bloco 7.3.
  Future<List<String>> appendMessages(
    String conversationId,
    List<NewMessage> items, {
    bool Function()? isCancelled,
  }) async {
    if (items.isEmpty) return const [];

    // Validação barata e imediata (antes de copiar arquivo nenhum).
    for (var i = 0; i < items.length; i++) {
      final err = items[i].validate();
      if (err != null) {
        throw ArgumentError('appendMessages[$i]: $err');
      }
    }

    // Lê a conversa uma vez: precisamos do estado de proteção para cifrar
    // e (no fim) atualizar `atualizadoEm`.
    final conversation = await (db.select(
      db.conversations,
    )..where((c) => c.id.equals(conversationId))).getSingleOrNull();
    if (conversation == null) {
      throw StateError('A conversa não existe mais.');
    }
    final isProtected = conversation.protegidoPorSenha;
    final key = _unlockedKeys[conversationId];
    if (isProtected && key == null) {
      throw StateError(
        'Conversa protegida, mas a sessão não está desbloqueada. '
        'Desbloqueie antes de gravar.',
      );
    }

    // ------------------------------------------------------------------
    // Fase 1 — cópia de arquivos + cifra de metadados (fora da transação)
    // ------------------------------------------------------------------

    // Estrutura intermediária: para cada item, o que vai para o banco.
    // `arquivoPath` já é o relativo (ou null em texto).
    final prepared = <_PreparedAppend>[];
    final copiedPaths = <String>[]; // para rollback da fase 1

    try {
      for (var i = 0; i < items.length; i++) {
        if (isCancelled != null && isCancelled()) {
          // Cancelado: limpa o que já copiou e devolve vazio (sem tocar no BD).
          for (final p in copiedPaths) {
            await storage.delete(p);
          }
          return const [];
        }

        final item = items[i];

        if (item.tipo == MessageType.texto) {
          final storedContent = isProtected
              ? await PasswordCrypto.encryptField(item.texto!, key!)
              : item.texto!;
          prepared.add(
            _PreparedAppend(
              tipo: item.tipo,
              conteudoTexto: storedContent,
              arquivoPath: null,
              nomeOriginal: null,
              nomeExibicao: null,
              mimeType: null,
              tamanhoBytes: null,
              data: _dateOnly(item.data ?? DateTime.now()),
              dataEditadaManualmente: item.dataEditadaManualmente,
              tagId: item.tagId,
            ),
          );
          continue;
        }

        // Não-texto: copia arquivo + cifra metadados.
        final stored = await storage.saveFile(item.arquivo!, conversationId);
        copiedPaths.add(stored.relativePath);

        final nomeExibicao = item.nomeExibicao ?? item.nomeOriginal!;
        final storedOriginal = isProtected
            ? await PasswordCrypto.encryptField(item.nomeOriginal!, key!)
            : item.nomeOriginal!;
        final storedExibicao = isProtected
            ? await PasswordCrypto.encryptField(nomeExibicao, key!)
            : nomeExibicao;
        final storedMime = stored.mimeType == null
            ? null
            : (isProtected
                  ? await PasswordCrypto.encryptField(stored.mimeType!, key!)
                  : stored.mimeType!);

        prepared.add(
          _PreparedAppend(
            tipo: item.tipo,
            conteudoTexto: null,
            arquivoPath: stored.relativePath,
            nomeOriginal: storedOriginal,
            nomeExibicao: storedExibicao,
            mimeType: storedMime,
            tamanhoBytes: stored.sizeBytes,
            data: _dateOnly(item.data ?? DateTime.now()),
            dataEditadaManualmente: item.dataEditadaManualmente,
            tagId: item.tagId,
          ),
        );
      }
    } catch (_) {
      // Rollback da fase 1: apaga tudo o que copiou.
      for (final p in copiedPaths) {
        await storage.delete(p);
      }
      rethrow;
    }

    // ------------------------------------------------------------------
    // Fase 2 — uma transação, todas as linhas
    // ------------------------------------------------------------------

    final createdIds = <String>[];
    try {
      await db.transaction(() async {
        // Uma única consulta de `_nextPosition` para todos os itens.
        final base = await _nextPosition(conversationId);
        final now = DateTime.now();

        for (var i = 0; i < prepared.length; i++) {
          final p = prepared[i];
          final id = _uuid.v4();
          createdIds.add(id);
          await db
              .into(db.messages)
              .insert(
                MessagesCompanion.insert(
                  id: id,
                  conversationId: conversationId,
                  position: base + i * _positionGap,
                  tipo: Value(p.tipo),
                  conteudoTexto: p.conteudoTexto == null
                      ? const Value.absent()
                      : Value(p.conteudoTexto),
                  arquivoPath: p.arquivoPath == null
                      ? const Value.absent()
                      : Value(p.arquivoPath),
                  arquivoNomeOriginal: p.nomeOriginal == null
                      ? const Value.absent()
                      : Value(p.nomeOriginal),
                  arquivoNomeExibicao: p.nomeExibicao == null
                      ? const Value.absent()
                      : Value(p.nomeExibicao),
                  arquivoMimeType: p.mimeType == null
                      ? const Value.absent()
                      : Value(p.mimeType),
                  arquivoTamanhoBytes: p.tamanhoBytes == null
                      ? const Value.absent()
                      : Value(p.tamanhoBytes),
                  data: p.data,
                  dataEditadaManualmente: Value(p.dataEditadaManualmente),
                  tagId: p.tagId == null
                      ? const Value.absent()
                      : Value(p.tagId),
                ),
              );
        }

        // Uma única atualização de `atualizadoEm`.
        await (db.update(db.conversations)
              ..where((c) => c.id.equals(conversationId)))
            .write(ConversationsCompanion(atualizadoEm: Value(now)));
      });
    } catch (_) {
      // Rollback da fase 1 (a transação já desfez o BD).
      for (final p in copiedPaths) {
        await storage.delete(p);
      }
      rethrow;
    }

    // Cache de plaintext: as linhas novas ainda não têm cache; nada a
    // invalidar (o `_decryptRows` vai preencher na próxima leitura). Mas,
    // por consistência com os outros métodos de escrita (invariante 15 do
    // mapa), limpamos — é barato e evita surpresa se o `_nextPosition`
    // tiver mexido em algo fora do comum.
    // (O `sendDraft` faz `_plaintextCache.clear()` no início; aqui fazemos
    // no fim, o que é equivalente em efeito.)
    // Não limpamos por messageId porque não há ids antigos envolvidos.
    _plaintextCache.removeWhere((k, _) => false); // no-op; mantido por clareza

    return createdIds;
  }



  /// Encaminha as mensagens de [messageIds] (todas da mesma origem) para
  /// [destinationConversationId]. Cada mensagem gera um **novo** `id` e um
  /// **novo** arquivo físico no destino (S7-1: cópia física por mensagem),
  /// então excluir a origem **não** afeta o destino.
  ///
  /// Origem e destino podem ser protegidos por senha, mas o destino precisa
  /// estar desbloqueado para que os metadados sejam cifrados.
  ///
  /// Opções:
  /// - [keepOriginalDate] → `true` preserva `data`/`dataEditadaManualmente`
  ///   de cada mensagem; `false` (default) usa a data de hoje.
  /// - [carryTag] → `true` recria a tag da origem no destino
  ///   (`TagRepository.createOrGet` por nome normalizado + cor) e a aplica
  ///   na mensagem encaminhada; `false` (default) não leva tag.
  ///
  /// Arquivo físico ausente (órfão) → a mensagem é **pulada** e contada em
  /// [ForwardResult.skippedCount]. Demais mensagens são encaminhadas
  /// normalmente. Não há falha total por causa de um arquivo faltante.
  ///
  /// Processa em **lotes de 10** via `appendMessages`, com
  /// [isCancelled] consultado entre lotes. Lotes já enviados permanecem
  /// mesmo em caso de cancelamento/falha.
  ///
  /// Devolve [ForwardResult] com ids criados, total e ignoradas.
  Future<ForwardResult> forwardMessages({
    required String destinationConversationId,
    required Iterable<String> messageIds,
    bool keepOriginalDate = false,
    bool carryTag = false,
    bool Function()? isCancelled,
  }) async {
    final ids = messageIds.toSet().toList();
    if (ids.isEmpty) {
      return const ForwardResult(createdIds: [], skippedCount: 0, total: 0);
    }

    // Lê origem + destino para saber o estado de proteção.
    final source = await getMessagesByIds(ids);
    if (source.isEmpty) {
      return const ForwardResult(createdIds: [], skippedCount: 0, total: 0);
    }

    final destRow = await (db.select(
      db.conversations,
    )..where((c) => c.id.equals(destinationConversationId))).getSingleOrNull();
    if (destRow == null) {
      throw StateError('A conversa de destino não existe mais.');
    }
    final destProtected = destRow.protegidoPorSenha;
    if (destProtected && _unlockedKeys[destinationConversationId] == null) {
      throw StateError(
        'A conversa de destino está protegida, mas a sessão não está '
        'desbloqueada. Desbloqueie antes de encaminhar.',
      );
    }

    // Resolve tags no destino, se `carryTag`.
    final tagRepo = TagRepository(db);
    final tagMap = <String, String?>{}; // origem -> destino (null = falhou)
    if (carryTag) {
      final originTagIds = source
          .map((m) => m.tagId)
          .whereType<String>()
          .toSet();
      for (final originTagId in originTagIds) {
        final tag = await (db.select(
          db.tags,
        )..where((t) => t.id.equals(originTagId))).getSingleOrNull();
        if (tag == null) {
          tagMap[originTagId] = null;
          continue;
        }
        final created = await tagRepo.createOrGet(
          conversationId: destinationConversationId,
          nome: tag.nome,
          cor: tag.cor,
        );
        tagMap[originTagId] = created.id;
      }
    }

    // Monta os NewMessage. Fase 1 do appendMessages fará a cópia física.
    // Arquivo ausente => pula a mensagem.
    final items = <NewMessage>[];
    var skipped = 0;
    for (final m in source) {
      if (isCancelled != null && isCancelled()) break;

      if (m.tipo == MessageType.texto) {
        items.add(
          NewMessage.texto(
            m.conteudoTexto ?? '',
            data: keepOriginalDate ? m.data : null,
            dataEditadaManualmente: keepOriginalDate
                ? m.dataEditadaManualmente
                : false,
            tagId: carryTag && m.tagId != null ? tagMap[m.tagId] : null,
          ),
        );
        continue;
      }

      final relPath = m.arquivoPath;
      if (relPath == null) {
        skipped++;
        continue;
      }
      final physical = await storage.resolve(relPath);
      if (!await physical.exists()) {
        skipped++;
        continue;
      }

      items.add(
        NewMessage.arquivo(
          tipo: m.tipo,
          arquivo: physical,
          nomeOriginal: m.arquivoNomeOriginal ?? 'arquivo',
          nomeExibicao: m.arquivoNomeExibicao,
          data: keepOriginalDate ? m.data : null,
          dataEditadaManualmente: keepOriginalDate
              ? m.dataEditadaManualmente
              : false,
          tagId: carryTag && m.tagId != null ? tagMap[m.tagId] : null,
        ),
      );
    }

    if (items.isEmpty) {
      return ForwardResult(
        createdIds: const [],
        skippedCount: skipped,
        total: source.length,
      );
    }

    // Envio em lotes de 10.
    const batchSize = 10;
    final createdIds = <String>[];
    for (var start = 0; start < items.length; start += batchSize) {
      if (isCancelled != null && isCancelled()) break;
      final end = (start + batchSize) > items.length
          ? items.length
          : start + batchSize;
      final chunk = items.sublist(start, end);
      final created = await appendMessages(
        destinationConversationId,
        chunk,
        isCancelled: isCancelled,
      );
      createdIds.addAll(created);
    }

    return ForwardResult(
      createdIds: createdIds,
      skippedCount: skipped,
      total: source.length,
    );
  }


  /// Sprint 7 (7.1b) — devolve as [Message] dos [ids] informados, **já
  /// decifradas**, ordenadas por `position` (não pela ordem de [ids]).
  ///
  /// Consulta em **blocos de 500** ids para respeitar o limite de variáveis
  /// do SQLite (invariante 20 do `SPRINT_7_PLAN.md`). Reusa `_decryptRows`
  /// e o cache de plaintext — em conversa não protegida, caminho rápido.
  ///
  /// Ids inexistentes são **ignorados** (não é erro). Lista vazia devolve
  /// lista vazia. Duplicatas em [ids] não duplicam o resultado.
  ///
  /// Usado pela seleção (7.2), encaminhar (7.4) e compartilhar (7.5).
  Future<List<Message>> getMessagesByIds(Iterable<String> ids) async {
    final unique = ids.toSet().toList();
    if (unique.isEmpty) return const [];

    const chunkSize = 500;
    final rows = <MessageRow>[];
    for (var start = 0; start < unique.length; start += chunkSize) {
      final end = (start + chunkSize) > unique.length
          ? unique.length
          : start + chunkSize;
      final chunk = unique.sublist(start, end);
      final part = await (db.select(
        db.messages,
      )..where((m) => m.id.isIn(chunk))).get();
      rows.addAll(part);
    }
    if (rows.isEmpty) return const [];

    // Uma consulta de `protegidoPorSenha` por conversa representada.
    // Como todas as mensagens em [ids] vêm do mesmo contexto de uso
    // (seleção/encaminhamento de UMA conversa), normalmente é 1 só.
    final convIds = rows.map((r) => r.conversationId).toSet();
    final protectedByConv = <String, bool>{};
    for (final convId in convIds) {
      protectedByConv[convId] = await _isProtected(convId);
    }

    // _decryptRows assume uma única conversa; por segurança, agrupa.
    // (Na prática, ids vêm sempre de uma conversa; o agrupamento evita
    // ambiguidade se o chamador misturar.)
    final result = <Message>[];
    final byConv = <String, List<MessageRow>>{};
    for (final r in rows) {
      (byConv[r.conversationId] ??= []).add(r);
    }
    for (final entry in byConv.entries) {
      final isProtected = protectedByConv[entry.key] ?? false;
      final key = _unlockedKeys[entry.key];
      final decrypted = await _decryptRows(entry.value, isProtected, key);
      result.addAll(decrypted);
    }

    result.sort((a, b) => a.position.compareTo(b.position));
    return result;
  }

  /// Sprint 7 (7.1b) — todos os ids de mensagens da conversa, ordenados por
  /// `position`. Não decifra nada (devolve só `id`s), então é barato mesmo
  /// em conversa protegida e em conversa grande.
  ///
  /// Usado por "Selecionar tudo" no modo seleção (7.2), sem carregar conteúdo.
  Future<List<String>> getMessageIds(String conversationId) async {
    final query = db.selectOnly(db.messages)
      ..addColumns([db.messages.id])
      ..where(db.messages.conversationId.equals(conversationId))
      ..orderBy([OrderingTerm(expression: db.messages.position)]);
    final rows = await query.get();
    return rows.map((r) => r.read(db.messages.id)!).toList();
  }

  /// Helper interno do [appendMessages] — o "shape" que vai para o banco,
  /// já cifrado e com arquivo copiado.
  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// RF02.4 — altera só o nome de exibição; `data` intocada.
  Future<void> renameAttachment(String messageId, String novoNome) async {
    _plaintextCache.remove(messageId);
    final row = await (db.select(
      db.messages,
    )..where((m) => m.id.equals(messageId))).getSingleOrNull();
    if (row == null) return;

    final stored = await _encodeForStorage(row.conversationId, novoNome);

    await (db.update(db.messages)..where((m) => m.id.equals(messageId))).write(
      MessagesCompanion(arquivoNomeExibicao: Value(stored)),
    );
  }

  /// RF02.4 — troca o arquivo físico mantendo id, posição, tag, tipo, nome de
  /// exibição e `data`. O arquivo antigo só é apagado depois que o banco
  /// aceitou a atualização.
  Future<void> replaceAttachmentFile({
    required String messageId,
    required File newFile,
    required String nomeOriginal,
  }) async {
    _plaintextCache.remove(messageId);
    final row = await (db.select(
      db.messages,
    )..where((m) => m.id.equals(messageId))).getSingle();

    final stored = await storage.saveFile(newFile, row.conversationId);

    // Cifra os metadados novos, conforme o estado da conversa.
    final storedNomeOriginal = await _encodeForStorage(
      row.conversationId,
      nomeOriginal,
    );
    final storedMime = await _encodeForStorage(
      row.conversationId,
      stored.mimeType,
    );

    try {
      await (db.update(
        db.messages,
      )..where((m) => m.id.equals(messageId))).write(
        MessagesCompanion(
          arquivoPath: Value(stored.relativePath),
          arquivoNomeOriginal: Value(storedNomeOriginal),
          arquivoMimeType: Value(storedMime),
          arquivoTamanhoBytes: Value(stored.sizeBytes),
        ),
      );
    } catch (_) {
      await storage.delete(stored.relativePath);
      rethrow;
    }

    final oldPath = row.arquivoPath;
    if (oldPath != null) await storage.delete(oldPath);
  }

  /// RF04 — define, substitui ou remove (tagId == null) a Tag de uma
  /// Mensagem. Cada Mensagem tem no máximo uma Tag.
  ///
  /// Escreve APENAS `tag_id`: `data`, `dataEditadaManualmente` e o
  /// `atualizadoEm` da Conversa permanecem intactos.
  Future<void> setMessageTag(String messageId, String? tagId) async {
    if (tagId != null) {
      final message = await (db.select(
        db.messages,
      )..where((m) => m.id.equals(messageId))).getSingleOrNull();
      if (message == null) return;

      final tag = await (db.select(
        db.tags,
      )..where((t) => t.id.equals(tagId))).getSingleOrNull();
      if (tag == null) {
        throw StateError('A tag selecionada não existe mais.');
      }
      if (tag.conversationId != message.conversationId) {
        throw StateError('Esta tag pertence a outra conversa.');
      }
    }

    await (db.update(db.messages)..where((m) => m.id.equals(messageId))).write(
      MessagesCompanion(tagId: Value(tagId)),
    );
  }


  /// Sprint 6: reordenar em conversa grande passa a ser **O(1)** no caso
  /// comum. A `position` vira uma chave esparsa (gaps de 1000); mover
  /// calcula a nova posição como a **média entre os vizinhos**. Só quando o
  /// gap esgota (colisão) é que renumeramos toda a conversa — o que é raro.
  ///
  /// Continua devolvendo o índice ANTERIOR (para o "Desfazer") ou null.
  Future<int?> reorderMessage(String messageId, int newIndex) {
    return db.transaction<int?>(() async {
      final row = await (db.select(
        db.messages,
      )..where((m) => m.id.equals(messageId))).getSingleOrNull();
      if (row == null) return null;

      final rows =
          await (db.select(db.messages)
                ..where((m) => m.conversationId.equals(row.conversationId))
                ..orderBy([(m) => OrderingTerm(expression: m.position)]))
              .get();
      final oldIndex = rows.indexWhere((m) => m.id == messageId);
      if (oldIndex < 0) return null;

      // Lista SEM a mensagem movida, na ordem atual.
      final others = [...rows]..removeAt(oldIndex);
      final last = others.length;
      final target = newIndex < 0 ? 0 : (newIndex > last ? last : newIndex);

      // Se o índice final é o mesmo, nada a fazer.
      final currentIndexInOthers = oldIndex > target ? oldIndex - 1 : oldIndex;
      if (target == currentIndexInOthers) return null;

      // Calcula a nova `position` entre os vizinhos.
      int newPosition;
      if (others.isEmpty) {
        newPosition = _positionGap;
      } else if (target == 0) {
        // Antes do primeiro: metade, ou -gap se não houver espaço.
        final first = others.first.position;
        newPosition = first ~/ 2;
        if (newPosition == first) newPosition = first - _positionGap;
      } else if (target == last) {
        // Depois do último.
        newPosition = others.last.position + _positionGap;
      } else {
        final prev = others[target - 1].position;
        final next = others[target].position;
        newPosition = (prev + next) ~/ 2;
        if (newPosition == prev || newPosition == next) {
          // Gap esgotado: renumera a conversa inteira em passos de 1000,
          // reposiciona a movida e retorna.
          final reordered = [...others]..insert(target, row);
          final updates = <(String, int)>[];
          for (var i = 0; i < reordered.length; i++) {
            updates.add((reordered[i].id, (i + 1) * _positionGap));
          }
          await db.batch((batch) {
            for (final u in updates) {
              batch.update(
                db.messages,
                MessagesCompanion(position: Value(u.$2)),
                where: (x) => x.id.equals(u.$1),
              );
            }
          });
          return oldIndex;
        }
      }

      await (db.update(db.messages)..where((m) => m.id.equals(messageId)))
          .write(MessagesCompanion(position: Value(newPosition)));
      return oldIndex;
    });
  }

  /// Define (ou remove, com [tagId] == null) a Tag de várias Mensagens de
  /// uma vez. Valida que a Tag existe e pertence à mesma conversa da
  /// primeira mensagem antes de aplicar. Escreve **apenas `tag_id`**;
  /// `data`, `dataEditadaManualmente`, `position` e `atualizadoEm` da
  /// Conversa ficam intactos. Operação idempotente (ids inexistentes são
  /// ignorados).
  Future<void> setMessageTagMany(
    Iterable<String> messageIds,
    String? tagId,
  ) async {
    final ids = messageIds.toSet().toList();
    if (ids.isEmpty) return;

    if (tagId != null) {
      // Descobre a conversa a partir da primeira mensagem existente e valida
      // que a Tag pertence a ela. (Mesma lógica de antes; usa o primeiro
      // bloco para não estourar com ids demais.)
      final head = ids.length <= _sqlChunkSize
          ? ids
          : ids.sublist(0, _sqlChunkSize);
      final first =
          await (db.select(db.messages)
                ..where((m) => m.id.isIn(head))
                ..limit(1))
              .getSingleOrNull();
      if (first == null) return;

      final tag = await (db.select(
        db.tags,
      )..where((t) => t.id.equals(tagId))).getSingleOrNull();
      if (tag == null) {
        throw StateError('A tag selecionada não existe mais.');
      }
      if (tag.conversationId != first.conversationId) {
        throw StateError('Esta tag pertence a outra conversa.');
      }
    }

    await db.transaction(() async {
      for (var start = 0; start < ids.length; start += _sqlChunkSize) {
        final end = (start + _sqlChunkSize) > ids.length
            ? ids.length
            : start + _sqlChunkSize;
        final chunk = ids.sublist(start, end);
        await (db.update(db.messages)..where((m) => m.id.isIn(chunk))).write(
          MessagesCompanion(tagId: Value(tagId)),
        );
      }
    });
  }

  /// Sobrescreve manualmente a `data` de várias Mensagens de uma vez
  /// (RF02.6/RF03). Marca `dataEditadaManualmente = true` em todas. Escreve
  /// **apenas `data` e `dataEditadaManualmente`**; `tagId`, `position` e
  /// `atualizadoEm` da Conversa ficam intactos.
  Future<void> setMessageDateMany(
    Iterable<String> messageIds,
    DateTime date,
  ) async {
    final ids = messageIds.toSet().toList();
    if (ids.isEmpty) return;
    final dateOnly = DateTime(date.year, date.month, date.day);

    await db.transaction(() async {
      for (var start = 0; start < ids.length; start += _sqlChunkSize) {
        final end = (start + _sqlChunkSize) > ids.length
            ? ids.length
            : start + _sqlChunkSize;
        final chunk = ids.sublist(start, end);
        await (db.update(db.messages)..where((m) => m.id.isIn(chunk))).write(
          MessagesCompanion(
            data: Value(dateOnly),
            dataEditadaManualmente: const Value(true),
          ),
        );
      }
    });
  }

  /// Exclui várias Mensagens de uma vez. Apaga os registros em transação e,
  /// depois, os arquivos físicos correspondentes do storage (se houver).
  /// Não altera `atualizadoEm` da Conversa (a exclusão em si já é uma
  /// operação de conteúdo; o padrão vigente é o mesmo de `deleteMessage`).
  Future<void> deleteMessagesMany(Iterable<String> messageIds) async {
    _plaintextCache.clear();
    final ids = messageIds.toSet().toList();
    if (ids.isEmpty) return;

    // Coleta os caminhos de arquivo ANTES do delete (depois não existem
    // mais nas rows).
    final pathsToDelete = <String>[];
    for (var start = 0; start < ids.length; start += _sqlChunkSize) {
      final end = (start + _sqlChunkSize) > ids.length
          ? ids.length
          : start + _sqlChunkSize;
      final chunk = ids.sublist(start, end);
      final rows = await (db.select(
        db.messages,
      )..where((m) => m.id.isIn(chunk))).get();
      for (final r in rows) {
        final p = r.arquivoPath;
        if (p != null) pathsToDelete.add(p);
      }
    }

    await db.transaction(() async {
      for (var start = 0; start < ids.length; start += _sqlChunkSize) {
        final end = (start + _sqlChunkSize) > ids.length
            ? ids.length
            : start + _sqlChunkSize;
        final chunk = ids.sublist(start, end);
        await (db.delete(db.messages)..where((m) => m.id.isIn(chunk))).go();
      }
    });

    for (final p in pathsToDelete) {
      await storage.delete(p);
    }
  }


  /// Ativa a proteção por senha: gera salt, deriva a chave, **cifra** os
  /// campos sensíveis de todas as mensagens da conversa e grava
  /// `senhaHash`/`salt`/`protegidoPorSenha = true` — tudo em transação.
  ///
  /// Se a conversa já estiver protegida, lança [StateError]. Use
  /// [changeConversationPassword] nesse caso.
  Future<void> protectConversation(String id, String password) async {
    _plaintextCache.clear();
    final row = await (db.select(
      db.conversations,
    )..where((c) => c.id.equals(id))).getSingleOrNull();
    if (row == null) {
      throw StateError('A conversa não existe mais.');
    }
    if (row.protegidoPorSenha) {
      throw StateError('Esta conversa já está protegida por senha.');
    }

    final salt = PasswordCrypto.newSaltBase64();
    final key = await PasswordCrypto.deriveKeyInIsolate(
      password: password,
      saltBase64: salt,
    );
    final hash = await PasswordCrypto.hashKey(key);

    await db.transaction(() async {
      // Cifra as mensagens existentes.
      final messages = await (db.select(
        db.messages,
      )..where((m) => m.conversationId.equals(id))).get();

      // Fase 1: cifra todos os campos em paralelo.
      final encoded = await Future.wait(
        messages.map(
          (m) async => (
            id: m.id,
            conteudoTexto: m.conteudoTexto == null
                ? null
                : await PasswordCrypto.encryptField(m.conteudoTexto!, key),
            arquivoNomeOriginal: m.arquivoNomeOriginal == null
                ? null
                : await PasswordCrypto.encryptField(
                    m.arquivoNomeOriginal!,
                    key,
                  ),
            arquivoNomeExibicao: m.arquivoNomeExibicao == null
                ? null
                : await PasswordCrypto.encryptField(
                    m.arquivoNomeExibicao!,
                    key,
                  ),
            arquivoMimeType: m.arquivoMimeType == null
                ? null
                : await PasswordCrypto.encryptField(m.arquivoMimeType!, key),
          ),
        ),
      );

      // Fase 2: um único batch de UPDATEs.
      await db.batch((batch) {
        for (final e in encoded) {
          batch.update(
            db.messages,
            MessagesCompanion(
              conteudoTexto: e.conteudoTexto != null
                  ? Value(e.conteudoTexto!)
                  : const Value.absent(),
              arquivoNomeOriginal: e.arquivoNomeOriginal != null
                  ? Value(e.arquivoNomeOriginal!)
                  : const Value.absent(),
              arquivoNomeExibicao: e.arquivoNomeExibicao != null
                  ? Value(e.arquivoNomeExibicao!)
                  : const Value.absent(),
              arquivoMimeType: e.arquivoMimeType != null
                  ? Value(e.arquivoMimeType!)
                  : const Value.absent(),
            ),
            where: (x) => x.id.equals(e.id),
          );
        }
      });

      // Grava os metadados de senha na conversa.
      await (db.update(db.conversations)..where((c) => c.id.equals(id))).write(
        ConversationsCompanion(
          protegidoPorSenha: const Value(true),
          senhaHash: Value(hash),
          salt: Value(salt),
        ),
      );
    });

    // Deixa a conversa desbloqueada na sessão (usuário acabou de provar a
    // senha ao ativar).
    _unlockedKeys[id] = key;
  }

  /// Desativa a proteção: verifica a senha, **decifra** todas as mensagens
  /// e limpa `senhaHash`/`salt`/`protegidoPorSenha = false` — tudo em
  /// transação.
  ///
  /// Lança [StateError] se a senha estiver errada ou a conversa não estiver
  /// protegida.
  Future<void> unprotectConversation(String id, String password) async {
    _plaintextCache.clear();
    final row = await (db.select(
      db.conversations,
    )..where((c) => c.id.equals(id))).getSingleOrNull();
    if (row == null) throw StateError('A conversa não existe mais.');
    if (!row.protegidoPorSenha) {
      throw StateError('Esta conversa não está protegida por senha.');
    }

    final salt = row.salt;
    final expectedHash = row.senhaHash;
    if (salt == null || expectedHash == null) {
      throw StateError('Metadados de senha inconsistentes.');
    }

    final key = await PasswordCrypto.deriveKeyInIsolate(
      password: password,
      saltBase64: salt,
    );
    final actualHash = await PasswordCrypto.hashKey(key);
    if (!PasswordCrypto.constantTimeEquals(actualHash, expectedHash)) {
      throw StateError('Senha incorreta.');
    }

    await db.transaction(() async {
      final messages = await (db.select(
        db.messages,
      )..where((m) => m.conversationId.equals(id))).get();

      final decoded = await Future.wait(
        messages.map(
          (m) async => (
            id: m.id,
            conteudoTexto: m.conteudoTexto == null
                ? null
                : await PasswordCrypto.decryptField(m.conteudoTexto!, key),
            arquivoNomeOriginal: m.arquivoNomeOriginal == null
                ? null
                : await PasswordCrypto.decryptField(
                    m.arquivoNomeOriginal!,
                    key,
                  ),
            arquivoNomeExibicao: m.arquivoNomeExibicao == null
                ? null
                : await PasswordCrypto.decryptField(
                    m.arquivoNomeExibicao!,
                    key,
                  ),
            arquivoMimeType: m.arquivoMimeType == null
                ? null
                : await PasswordCrypto.decryptField(m.arquivoMimeType!, key),
          ),
        ),
      );

      await db.batch((batch) {
        for (final d in decoded) {
          batch.update(
            db.messages,
            MessagesCompanion(
              conteudoTexto: d.conteudoTexto != null
                  ? Value(d.conteudoTexto!)
                  : const Value.absent(),
              arquivoNomeOriginal: d.arquivoNomeOriginal != null
                  ? Value(d.arquivoNomeOriginal!)
                  : const Value.absent(),
              arquivoNomeExibicao: d.arquivoNomeExibicao != null
                  ? Value(d.arquivoNomeExibicao!)
                  : const Value.absent(),
              arquivoMimeType: d.arquivoMimeType != null
                  ? Value(d.arquivoMimeType!)
                  : const Value.absent(),
            ),
            where: (x) => x.id.equals(d.id),
          );
        }
      });

      await (db.update(db.conversations)..where((c) => c.id.equals(id))).write(
        const ConversationsCompanion(
          protegidoPorSenha: Value(false),
          senhaHash: Value(null),
          salt: Value(null),
        ),
      );
    });

    _unlockedKeys.remove(id);
  }

  /// Troca a senha mantendo a conversa protegida. Verifica a senha atual,
  /// deriva uma nova chave (novo salt), **re-cifra tudo** (decifra com a
  /// antiga, cifra com a nova) e atualiza `senhaHash`/`salt` — em transação.
  ///
  /// Lança [StateError] se a senha atual estiver errada.
  Future<void> changeConversationPassword(
    String id,
    String oldPassword,
    String newPassword,
  ) async {
    _plaintextCache.clear();
    final row = await (db.select(
      db.conversations,
    )..where((c) => c.id.equals(id))).getSingleOrNull();
    if (row == null) throw StateError('A conversa não existe mais.');
    if (!row.protegidoPorSenha) {
      throw StateError('Esta conversa não está protegida por senha.');
    }

    final oldSalt = row.salt;
    final expectedHash = row.senhaHash;
    if (oldSalt == null || expectedHash == null) {
      throw StateError('Metadados de senha inconsistentes.');
    }

    final oldKey = await PasswordCrypto.deriveKeyInIsolate(
      password: oldPassword,
      saltBase64: oldSalt,
    );
    final actualHash = await PasswordCrypto.hashKey(oldKey);
    if (!PasswordCrypto.constantTimeEquals(actualHash, expectedHash)) {
      throw StateError('Senha atual incorreta.');
    }

    final newSalt = PasswordCrypto.newSaltBase64();
    final newKey = await PasswordCrypto.deriveKeyInIsolate(
      password: newPassword,
      saltBase64: newSalt,
    );
    final newHash = await PasswordCrypto.hashKey(newKey);

    await db.transaction(() async {
      final messages = await (db.select(
        db.messages,
      )..where((m) => m.conversationId.equals(id))).get();

      final reencoded = await Future.wait(
        messages.map(
          (m) async => (
            id: m.id,
            conteudoTexto: m.conteudoTexto == null
                ? null
                : await PasswordCrypto.encryptField(
                    await PasswordCrypto.decryptField(m.conteudoTexto!, oldKey),
                    newKey,
                  ),
            arquivoNomeOriginal: m.arquivoNomeOriginal == null
                ? null
                : await PasswordCrypto.encryptField(
                    await PasswordCrypto.decryptField(
                      m.arquivoNomeOriginal!,
                      oldKey,
                    ),
                    newKey,
                  ),
            arquivoNomeExibicao: m.arquivoNomeExibicao == null
                ? null
                : await PasswordCrypto.encryptField(
                    await PasswordCrypto.decryptField(
                      m.arquivoNomeExibicao!,
                      oldKey,
                    ),
                    newKey,
                  ),
            arquivoMimeType: m.arquivoMimeType == null
                ? null
                : await PasswordCrypto.encryptField(
                    await PasswordCrypto.decryptField(
                      m.arquivoMimeType!,
                      oldKey,
                    ),
                    newKey,
                  ),
          ),
        ),
      );

      await db.batch((batch) {
        for (final e in reencoded) {
          batch.update(
            db.messages,
            MessagesCompanion(
              conteudoTexto: e.conteudoTexto != null
                  ? Value(e.conteudoTexto!)
                  : const Value.absent(),
              arquivoNomeOriginal: e.arquivoNomeOriginal != null
                  ? Value(e.arquivoNomeOriginal!)
                  : const Value.absent(),
              arquivoNomeExibicao: e.arquivoNomeExibicao != null
                  ? Value(e.arquivoNomeExibicao!)
                  : const Value.absent(),
              arquivoMimeType: e.arquivoMimeType != null
                  ? Value(e.arquivoMimeType!)
                  : const Value.absent(),
            ),
            where: (x) => x.id.equals(e.id),
          );
        }
      });

      await (db.update(db.conversations)..where((c) => c.id.equals(id))).write(
        ConversationsCompanion(senhaHash: Value(newHash), salt: Value(newSalt)),
      );
    });

    // Mantém a sessão desbloqueada com a nova chave.
    _unlockedKeys[id] = newKey;
  }

  /// Verifica a senha de uma conversa protegida. Se correta, guarda a chave
  /// em cache na sessão e devolve a própria chave. Se errada (ou conversa
  /// não protegida), devolve `null` e **não** mexe na sessão.
  Future<List<int>?> verifyConversationPassword(
    String id,
    String password,
  ) async {
    final row = await (db.select(
      db.conversations,
    )..where((c) => c.id.equals(id))).getSingleOrNull();
    if (row == null || !row.protegidoPorSenha) return null;

    final salt = row.salt;
    final expectedHash = row.senhaHash;
    if (salt == null || expectedHash == null) return null;

    final key = await PasswordCrypto.deriveKeyInIsolate(
      password: password,
      saltBase64: salt,
    );
    final actualHash = await PasswordCrypto.hashKey(key);
    if (!PasswordCrypto.constantTimeEquals(actualHash, expectedHash)) {
      return null;
    }

    _unlockedKeys[id] = key;
    return key;
  }


  /// Devolve o valor a ser gravado em [field], conforme o estado da conversa:
  /// - Conversa **não protegida** → devolve [plaintext] como está.
  /// - Conversa **protegida + chave na sessão** → devolve o ciphertext
  ///   (`base64(nonce||ciphertext||tag)`).
  /// - Conversa **protegida + SEM chave na sessão** → lança [StateError]
  ///   (não deveria acontecer: o gate da Home impede o envio sem chave;
  ///   falhar aqui é melhor do que gravar texto puro numa conversa cifrada).
  ///
  /// [plaintext] nulo devolve nulo (preserva a semântica de campos opcionais).
  Future<String?> _encodeForStorage(
    String conversationId,
    String? plaintext,
  ) async {
    if (plaintext == null) return null;

    final conv = await (db.select(
      db.conversations,
    )..where((c) => c.id.equals(conversationId))).getSingleOrNull();
    if (conv == null || !conv.protegidoPorSenha) {
      return plaintext;
    }

    final key = _unlockedKeys[conversationId];
    if (key == null) {
      throw StateError(
        'Conversa protegida, mas a sessão não está desbloqueada. '
        'Desbloqueie antes de gravar.',
      );
    }

    return PasswordCrypto.encryptField(plaintext, key);
  }
}

/// Sprint 7 (7.1a) — saída da "fase 1" de [appendMessages]: já cifrado,
/// já com arquivo copiado, só falta atribuir `id`/`position` e inserir.
class _PreparedAppend {
  final MessageType tipo;
  final String? conteudoTexto;
  final String? arquivoPath;
  final String? nomeOriginal;
  final String? nomeExibicao;
  final String? mimeType;
  final int? tamanhoBytes;
  final DateTime data;
  final bool dataEditadaManualmente;
  final String? tagId;

  const _PreparedAppend({
    required this.tipo,
    required this.conteudoTexto,
    required this.arquivoPath,
    required this.nomeOriginal,
    required this.nomeExibicao,
    required this.mimeType,
    required this.tamanhoBytes,
    required this.data,
    required this.dataEditadaManualmente,
    required this.tagId,
  });
}

/// Sprint 7 (7.4) — resultado de [ConversationRepository.forwardMessages].
class ForwardResult {
  /// Ids criados no destino, na ordem em que foram gravados.
  final List<String> createdIds;

  /// Quantas mensagens da origem foram ignoradas (arquivo físico ausente).
  final int skippedCount;

  /// Quantas mensagens foram consideradas no total.
  final int total;

  const ForwardResult({
    required this.createdIds,
    required this.skippedCount,
    required this.total,
  });

  int get forwardedCount => createdIds.length;
}
