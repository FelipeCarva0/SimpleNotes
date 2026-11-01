import 'package:drift/drift.dart';


enum MessageType { texto, imagem, video, audio, documento }


@DataClassName('TagRow')
class Tags extends Table {
  TextColumn get id => text()();
  TextColumn get conversationId => text().references(Conversations, #id)();
  TextColumn get nome => text()();
  TextColumn get cor => text()(); // hex, ex: '#FF5722'

  @override
  Set<Column> get primaryKey => {id};
}


@DataClassName('ConversationRow')
class Conversations extends Table {
  TextColumn get id => text()();
  TextColumn get titulo => text()();
  DateTimeColumn get criadoEm => dateTime()();
  DateTimeColumn get atualizadoEm => dateTime()();

  /// RF08 — trava apenas o acesso à Conversa inteira (bloqueio/desbloqueio),
  /// sem distinção de cifragem por tipo de conteúdo.
  BoolColumn get protegidoPorSenha =>
      boolean().withDefault(const Constant(false))();
  TextColumn get senhaHash => text().nullable()();
  TextColumn get salt => text().nullable()();

  /// RF02.1 — texto ainda não enviado, sem data associada.
  TextColumn get rascunho => text().withDefault(const Constant(''))();

  @override
  Set<Column> get primaryKey => {id};
}

/// RF02/RF03 — Mensagem (antiga Linha, generalizada para texto ou arquivo).
/// Os campos `arquivo*` só são preenchidos quando `tipo != texto`.
@DataClassName('MessageRow')
class Messages extends Table {
  TextColumn get id => text()();
  TextColumn get conversationId => text().references(Conversations, #id)();

  /// RF04 — no máximo uma Tag por Mensagem (nullable = sem tag).
  TextColumn get tagId =>
      text().nullable().references(Tags, #id, onDelete: KeyAction.setNull)();

  IntColumn get position => integer()();
  IntColumn get tipo =>
      intEnum<MessageType>().withDefault(const Constant(0))();

  TextColumn get conteudoTexto => text().nullable()();

  TextColumn get arquivoPath => text().nullable()();
  TextColumn get arquivoNomeOriginal => text().nullable()();
  TextColumn get arquivoNomeExibicao => text().nullable()();
  TextColumn get arquivoMimeType => text().nullable()();
  IntColumn get arquivoTamanhoBytes => integer().nullable()();

  /// RF03 — apenas o dia, sem hora; atribuída no momento do envio e imutável
  /// por edição de conteúdo (só muda via exclusão+reenvio ou sobrescrita
  /// manual, ver `dataEditadaManualmente`).
  DateTimeColumn get data => dateTime()();
  BoolColumn get dataEditadaManualmente =>
      boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
