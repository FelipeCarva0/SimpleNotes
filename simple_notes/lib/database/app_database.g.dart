// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $ConversationsTable extends Conversations
    with TableInfo<$ConversationsTable, ConversationRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ConversationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tituloMeta = const VerificationMeta('titulo');
  @override
  late final GeneratedColumn<String> titulo = GeneratedColumn<String>(
    'titulo',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _criadoEmMeta = const VerificationMeta(
    'criadoEm',
  );
  @override
  late final GeneratedColumn<DateTime> criadoEm = GeneratedColumn<DateTime>(
    'criado_em',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _atualizadoEmMeta = const VerificationMeta(
    'atualizadoEm',
  );
  @override
  late final GeneratedColumn<DateTime> atualizadoEm = GeneratedColumn<DateTime>(
    'atualizado_em',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _protegidoPorSenhaMeta = const VerificationMeta(
    'protegidoPorSenha',
  );
  @override
  late final GeneratedColumn<bool> protegidoPorSenha = GeneratedColumn<bool>(
    'protegido_por_senha',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("protegido_por_senha" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _senhaHashMeta = const VerificationMeta(
    'senhaHash',
  );
  @override
  late final GeneratedColumn<String> senhaHash = GeneratedColumn<String>(
    'senha_hash',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _saltMeta = const VerificationMeta('salt');
  @override
  late final GeneratedColumn<String> salt = GeneratedColumn<String>(
    'salt',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _rascunhoMeta = const VerificationMeta(
    'rascunho',
  );
  @override
  late final GeneratedColumn<String> rascunho = GeneratedColumn<String>(
    'rascunho',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    titulo,
    criadoEm,
    atualizadoEm,
    protegidoPorSenha,
    senhaHash,
    salt,
    rascunho,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'conversations';
  @override
  VerificationContext validateIntegrity(
    Insertable<ConversationRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('titulo')) {
      context.handle(
        _tituloMeta,
        titulo.isAcceptableOrUnknown(data['titulo']!, _tituloMeta),
      );
    } else if (isInserting) {
      context.missing(_tituloMeta);
    }
    if (data.containsKey('criado_em')) {
      context.handle(
        _criadoEmMeta,
        criadoEm.isAcceptableOrUnknown(data['criado_em']!, _criadoEmMeta),
      );
    } else if (isInserting) {
      context.missing(_criadoEmMeta);
    }
    if (data.containsKey('atualizado_em')) {
      context.handle(
        _atualizadoEmMeta,
        atualizadoEm.isAcceptableOrUnknown(
          data['atualizado_em']!,
          _atualizadoEmMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_atualizadoEmMeta);
    }
    if (data.containsKey('protegido_por_senha')) {
      context.handle(
        _protegidoPorSenhaMeta,
        protegidoPorSenha.isAcceptableOrUnknown(
          data['protegido_por_senha']!,
          _protegidoPorSenhaMeta,
        ),
      );
    }
    if (data.containsKey('senha_hash')) {
      context.handle(
        _senhaHashMeta,
        senhaHash.isAcceptableOrUnknown(data['senha_hash']!, _senhaHashMeta),
      );
    }
    if (data.containsKey('salt')) {
      context.handle(
        _saltMeta,
        salt.isAcceptableOrUnknown(data['salt']!, _saltMeta),
      );
    }
    if (data.containsKey('rascunho')) {
      context.handle(
        _rascunhoMeta,
        rascunho.isAcceptableOrUnknown(data['rascunho']!, _rascunhoMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ConversationRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ConversationRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      titulo: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}titulo'],
      )!,
      criadoEm: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}criado_em'],
      )!,
      atualizadoEm: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}atualizado_em'],
      )!,
      protegidoPorSenha: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}protegido_por_senha'],
      )!,
      senhaHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}senha_hash'],
      ),
      salt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}salt'],
      ),
      rascunho: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rascunho'],
      )!,
    );
  }

  @override
  $ConversationsTable createAlias(String alias) {
    return $ConversationsTable(attachedDatabase, alias);
  }
}

class ConversationRow extends DataClass implements Insertable<ConversationRow> {
  final String id;
  final String titulo;
  final DateTime criadoEm;
  final DateTime atualizadoEm;

  /// RF08 — trava apenas o acesso à Conversa inteira (bloqueio/desbloqueio),
  /// sem distinção de cifragem por tipo de conteúdo.
  final bool protegidoPorSenha;
  final String? senhaHash;
  final String? salt;

  /// RF02.1 — texto ainda não enviado, sem data associada.
  final String rascunho;
  const ConversationRow({
    required this.id,
    required this.titulo,
    required this.criadoEm,
    required this.atualizadoEm,
    required this.protegidoPorSenha,
    this.senhaHash,
    this.salt,
    required this.rascunho,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['titulo'] = Variable<String>(titulo);
    map['criado_em'] = Variable<DateTime>(criadoEm);
    map['atualizado_em'] = Variable<DateTime>(atualizadoEm);
    map['protegido_por_senha'] = Variable<bool>(protegidoPorSenha);
    if (!nullToAbsent || senhaHash != null) {
      map['senha_hash'] = Variable<String>(senhaHash);
    }
    if (!nullToAbsent || salt != null) {
      map['salt'] = Variable<String>(salt);
    }
    map['rascunho'] = Variable<String>(rascunho);
    return map;
  }

  ConversationsCompanion toCompanion(bool nullToAbsent) {
    return ConversationsCompanion(
      id: Value(id),
      titulo: Value(titulo),
      criadoEm: Value(criadoEm),
      atualizadoEm: Value(atualizadoEm),
      protegidoPorSenha: Value(protegidoPorSenha),
      senhaHash: senhaHash == null && nullToAbsent
          ? const Value.absent()
          : Value(senhaHash),
      salt: salt == null && nullToAbsent ? const Value.absent() : Value(salt),
      rascunho: Value(rascunho),
    );
  }

  factory ConversationRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ConversationRow(
      id: serializer.fromJson<String>(json['id']),
      titulo: serializer.fromJson<String>(json['titulo']),
      criadoEm: serializer.fromJson<DateTime>(json['criadoEm']),
      atualizadoEm: serializer.fromJson<DateTime>(json['atualizadoEm']),
      protegidoPorSenha: serializer.fromJson<bool>(json['protegidoPorSenha']),
      senhaHash: serializer.fromJson<String?>(json['senhaHash']),
      salt: serializer.fromJson<String?>(json['salt']),
      rascunho: serializer.fromJson<String>(json['rascunho']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'titulo': serializer.toJson<String>(titulo),
      'criadoEm': serializer.toJson<DateTime>(criadoEm),
      'atualizadoEm': serializer.toJson<DateTime>(atualizadoEm),
      'protegidoPorSenha': serializer.toJson<bool>(protegidoPorSenha),
      'senhaHash': serializer.toJson<String?>(senhaHash),
      'salt': serializer.toJson<String?>(salt),
      'rascunho': serializer.toJson<String>(rascunho),
    };
  }

  ConversationRow copyWith({
    String? id,
    String? titulo,
    DateTime? criadoEm,
    DateTime? atualizadoEm,
    bool? protegidoPorSenha,
    Value<String?> senhaHash = const Value.absent(),
    Value<String?> salt = const Value.absent(),
    String? rascunho,
  }) => ConversationRow(
    id: id ?? this.id,
    titulo: titulo ?? this.titulo,
    criadoEm: criadoEm ?? this.criadoEm,
    atualizadoEm: atualizadoEm ?? this.atualizadoEm,
    protegidoPorSenha: protegidoPorSenha ?? this.protegidoPorSenha,
    senhaHash: senhaHash.present ? senhaHash.value : this.senhaHash,
    salt: salt.present ? salt.value : this.salt,
    rascunho: rascunho ?? this.rascunho,
  );
  ConversationRow copyWithCompanion(ConversationsCompanion data) {
    return ConversationRow(
      id: data.id.present ? data.id.value : this.id,
      titulo: data.titulo.present ? data.titulo.value : this.titulo,
      criadoEm: data.criadoEm.present ? data.criadoEm.value : this.criadoEm,
      atualizadoEm: data.atualizadoEm.present
          ? data.atualizadoEm.value
          : this.atualizadoEm,
      protegidoPorSenha: data.protegidoPorSenha.present
          ? data.protegidoPorSenha.value
          : this.protegidoPorSenha,
      senhaHash: data.senhaHash.present ? data.senhaHash.value : this.senhaHash,
      salt: data.salt.present ? data.salt.value : this.salt,
      rascunho: data.rascunho.present ? data.rascunho.value : this.rascunho,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ConversationRow(')
          ..write('id: $id, ')
          ..write('titulo: $titulo, ')
          ..write('criadoEm: $criadoEm, ')
          ..write('atualizadoEm: $atualizadoEm, ')
          ..write('protegidoPorSenha: $protegidoPorSenha, ')
          ..write('senhaHash: $senhaHash, ')
          ..write('salt: $salt, ')
          ..write('rascunho: $rascunho')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    titulo,
    criadoEm,
    atualizadoEm,
    protegidoPorSenha,
    senhaHash,
    salt,
    rascunho,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ConversationRow &&
          other.id == this.id &&
          other.titulo == this.titulo &&
          other.criadoEm == this.criadoEm &&
          other.atualizadoEm == this.atualizadoEm &&
          other.protegidoPorSenha == this.protegidoPorSenha &&
          other.senhaHash == this.senhaHash &&
          other.salt == this.salt &&
          other.rascunho == this.rascunho);
}

class ConversationsCompanion extends UpdateCompanion<ConversationRow> {
  final Value<String> id;
  final Value<String> titulo;
  final Value<DateTime> criadoEm;
  final Value<DateTime> atualizadoEm;
  final Value<bool> protegidoPorSenha;
  final Value<String?> senhaHash;
  final Value<String?> salt;
  final Value<String> rascunho;
  final Value<int> rowid;
  const ConversationsCompanion({
    this.id = const Value.absent(),
    this.titulo = const Value.absent(),
    this.criadoEm = const Value.absent(),
    this.atualizadoEm = const Value.absent(),
    this.protegidoPorSenha = const Value.absent(),
    this.senhaHash = const Value.absent(),
    this.salt = const Value.absent(),
    this.rascunho = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ConversationsCompanion.insert({
    required String id,
    required String titulo,
    required DateTime criadoEm,
    required DateTime atualizadoEm,
    this.protegidoPorSenha = const Value.absent(),
    this.senhaHash = const Value.absent(),
    this.salt = const Value.absent(),
    this.rascunho = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       titulo = Value(titulo),
       criadoEm = Value(criadoEm),
       atualizadoEm = Value(atualizadoEm);
  static Insertable<ConversationRow> custom({
    Expression<String>? id,
    Expression<String>? titulo,
    Expression<DateTime>? criadoEm,
    Expression<DateTime>? atualizadoEm,
    Expression<bool>? protegidoPorSenha,
    Expression<String>? senhaHash,
    Expression<String>? salt,
    Expression<String>? rascunho,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (titulo != null) 'titulo': titulo,
      if (criadoEm != null) 'criado_em': criadoEm,
      if (atualizadoEm != null) 'atualizado_em': atualizadoEm,
      if (protegidoPorSenha != null) 'protegido_por_senha': protegidoPorSenha,
      if (senhaHash != null) 'senha_hash': senhaHash,
      if (salt != null) 'salt': salt,
      if (rascunho != null) 'rascunho': rascunho,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ConversationsCompanion copyWith({
    Value<String>? id,
    Value<String>? titulo,
    Value<DateTime>? criadoEm,
    Value<DateTime>? atualizadoEm,
    Value<bool>? protegidoPorSenha,
    Value<String?>? senhaHash,
    Value<String?>? salt,
    Value<String>? rascunho,
    Value<int>? rowid,
  }) {
    return ConversationsCompanion(
      id: id ?? this.id,
      titulo: titulo ?? this.titulo,
      criadoEm: criadoEm ?? this.criadoEm,
      atualizadoEm: atualizadoEm ?? this.atualizadoEm,
      protegidoPorSenha: protegidoPorSenha ?? this.protegidoPorSenha,
      senhaHash: senhaHash ?? this.senhaHash,
      salt: salt ?? this.salt,
      rascunho: rascunho ?? this.rascunho,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (titulo.present) {
      map['titulo'] = Variable<String>(titulo.value);
    }
    if (criadoEm.present) {
      map['criado_em'] = Variable<DateTime>(criadoEm.value);
    }
    if (atualizadoEm.present) {
      map['atualizado_em'] = Variable<DateTime>(atualizadoEm.value);
    }
    if (protegidoPorSenha.present) {
      map['protegido_por_senha'] = Variable<bool>(protegidoPorSenha.value);
    }
    if (senhaHash.present) {
      map['senha_hash'] = Variable<String>(senhaHash.value);
    }
    if (salt.present) {
      map['salt'] = Variable<String>(salt.value);
    }
    if (rascunho.present) {
      map['rascunho'] = Variable<String>(rascunho.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ConversationsCompanion(')
          ..write('id: $id, ')
          ..write('titulo: $titulo, ')
          ..write('criadoEm: $criadoEm, ')
          ..write('atualizadoEm: $atualizadoEm, ')
          ..write('protegidoPorSenha: $protegidoPorSenha, ')
          ..write('senhaHash: $senhaHash, ')
          ..write('salt: $salt, ')
          ..write('rascunho: $rascunho, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TagsTable extends Tags with TableInfo<$TagsTable, TagRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TagsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _conversationIdMeta = const VerificationMeta(
    'conversationId',
  );
  @override
  late final GeneratedColumn<String> conversationId = GeneratedColumn<String>(
    'conversation_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES conversations (id)',
    ),
  );
  static const VerificationMeta _nomeMeta = const VerificationMeta('nome');
  @override
  late final GeneratedColumn<String> nome = GeneratedColumn<String>(
    'nome',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _corMeta = const VerificationMeta('cor');
  @override
  late final GeneratedColumn<String> cor = GeneratedColumn<String>(
    'cor',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, conversationId, nome, cor];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tags';
  @override
  VerificationContext validateIntegrity(
    Insertable<TagRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('conversation_id')) {
      context.handle(
        _conversationIdMeta,
        conversationId.isAcceptableOrUnknown(
          data['conversation_id']!,
          _conversationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_conversationIdMeta);
    }
    if (data.containsKey('nome')) {
      context.handle(
        _nomeMeta,
        nome.isAcceptableOrUnknown(data['nome']!, _nomeMeta),
      );
    } else if (isInserting) {
      context.missing(_nomeMeta);
    }
    if (data.containsKey('cor')) {
      context.handle(
        _corMeta,
        cor.isAcceptableOrUnknown(data['cor']!, _corMeta),
      );
    } else if (isInserting) {
      context.missing(_corMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TagRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TagRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      conversationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}conversation_id'],
      )!,
      nome: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}nome'],
      )!,
      cor: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cor'],
      )!,
    );
  }

  @override
  $TagsTable createAlias(String alias) {
    return $TagsTable(attachedDatabase, alias);
  }
}

class TagRow extends DataClass implements Insertable<TagRow> {
  final String id;
  final String conversationId;
  final String nome;
  final String cor;
  const TagRow({
    required this.id,
    required this.conversationId,
    required this.nome,
    required this.cor,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['conversation_id'] = Variable<String>(conversationId);
    map['nome'] = Variable<String>(nome);
    map['cor'] = Variable<String>(cor);
    return map;
  }

  TagsCompanion toCompanion(bool nullToAbsent) {
    return TagsCompanion(
      id: Value(id),
      conversationId: Value(conversationId),
      nome: Value(nome),
      cor: Value(cor),
    );
  }

  factory TagRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TagRow(
      id: serializer.fromJson<String>(json['id']),
      conversationId: serializer.fromJson<String>(json['conversationId']),
      nome: serializer.fromJson<String>(json['nome']),
      cor: serializer.fromJson<String>(json['cor']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'conversationId': serializer.toJson<String>(conversationId),
      'nome': serializer.toJson<String>(nome),
      'cor': serializer.toJson<String>(cor),
    };
  }

  TagRow copyWith({
    String? id,
    String? conversationId,
    String? nome,
    String? cor,
  }) => TagRow(
    id: id ?? this.id,
    conversationId: conversationId ?? this.conversationId,
    nome: nome ?? this.nome,
    cor: cor ?? this.cor,
  );
  TagRow copyWithCompanion(TagsCompanion data) {
    return TagRow(
      id: data.id.present ? data.id.value : this.id,
      conversationId: data.conversationId.present
          ? data.conversationId.value
          : this.conversationId,
      nome: data.nome.present ? data.nome.value : this.nome,
      cor: data.cor.present ? data.cor.value : this.cor,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TagRow(')
          ..write('id: $id, ')
          ..write('conversationId: $conversationId, ')
          ..write('nome: $nome, ')
          ..write('cor: $cor')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, conversationId, nome, cor);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TagRow &&
          other.id == this.id &&
          other.conversationId == this.conversationId &&
          other.nome == this.nome &&
          other.cor == this.cor);
}

class TagsCompanion extends UpdateCompanion<TagRow> {
  final Value<String> id;
  final Value<String> conversationId;
  final Value<String> nome;
  final Value<String> cor;
  final Value<int> rowid;
  const TagsCompanion({
    this.id = const Value.absent(),
    this.conversationId = const Value.absent(),
    this.nome = const Value.absent(),
    this.cor = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TagsCompanion.insert({
    required String id,
    required String conversationId,
    required String nome,
    required String cor,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       conversationId = Value(conversationId),
       nome = Value(nome),
       cor = Value(cor);
  static Insertable<TagRow> custom({
    Expression<String>? id,
    Expression<String>? conversationId,
    Expression<String>? nome,
    Expression<String>? cor,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (conversationId != null) 'conversation_id': conversationId,
      if (nome != null) 'nome': nome,
      if (cor != null) 'cor': cor,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TagsCompanion copyWith({
    Value<String>? id,
    Value<String>? conversationId,
    Value<String>? nome,
    Value<String>? cor,
    Value<int>? rowid,
  }) {
    return TagsCompanion(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      nome: nome ?? this.nome,
      cor: cor ?? this.cor,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (conversationId.present) {
      map['conversation_id'] = Variable<String>(conversationId.value);
    }
    if (nome.present) {
      map['nome'] = Variable<String>(nome.value);
    }
    if (cor.present) {
      map['cor'] = Variable<String>(cor.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TagsCompanion(')
          ..write('id: $id, ')
          ..write('conversationId: $conversationId, ')
          ..write('nome: $nome, ')
          ..write('cor: $cor, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MessagesTable extends Messages
    with TableInfo<$MessagesTable, MessageRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MessagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _conversationIdMeta = const VerificationMeta(
    'conversationId',
  );
  @override
  late final GeneratedColumn<String> conversationId = GeneratedColumn<String>(
    'conversation_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES conversations (id)',
    ),
  );
  static const VerificationMeta _tagIdMeta = const VerificationMeta('tagId');
  @override
  late final GeneratedColumn<String> tagId = GeneratedColumn<String>(
    'tag_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES tags (id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<MessageType, int> tipo =
      GeneratedColumn<int>(
        'tipo',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
        defaultValue: const Constant(0),
      ).withConverter<MessageType>($MessagesTable.$convertertipo);
  static const VerificationMeta _conteudoTextoMeta = const VerificationMeta(
    'conteudoTexto',
  );
  @override
  late final GeneratedColumn<String> conteudoTexto = GeneratedColumn<String>(
    'conteudo_texto',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _arquivoPathMeta = const VerificationMeta(
    'arquivoPath',
  );
  @override
  late final GeneratedColumn<String> arquivoPath = GeneratedColumn<String>(
    'arquivo_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _arquivoNomeOriginalMeta =
      const VerificationMeta('arquivoNomeOriginal');
  @override
  late final GeneratedColumn<String> arquivoNomeOriginal =
      GeneratedColumn<String>(
        'arquivo_nome_original',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _arquivoNomeExibicaoMeta =
      const VerificationMeta('arquivoNomeExibicao');
  @override
  late final GeneratedColumn<String> arquivoNomeExibicao =
      GeneratedColumn<String>(
        'arquivo_nome_exibicao',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _arquivoMimeTypeMeta = const VerificationMeta(
    'arquivoMimeType',
  );
  @override
  late final GeneratedColumn<String> arquivoMimeType = GeneratedColumn<String>(
    'arquivo_mime_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _arquivoTamanhoBytesMeta =
      const VerificationMeta('arquivoTamanhoBytes');
  @override
  late final GeneratedColumn<int> arquivoTamanhoBytes = GeneratedColumn<int>(
    'arquivo_tamanho_bytes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dataMeta = const VerificationMeta('data');
  @override
  late final GeneratedColumn<DateTime> data = GeneratedColumn<DateTime>(
    'data',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dataEditadaManualmenteMeta =
      const VerificationMeta('dataEditadaManualmente');
  @override
  late final GeneratedColumn<bool> dataEditadaManualmente =
      GeneratedColumn<bool>(
        'data_editada_manualmente',
        aliasedName,
        false,
        type: DriftSqlType.bool,
        requiredDuringInsert: false,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("data_editada_manualmente" IN (0, 1))',
        ),
        defaultValue: const Constant(false),
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    conversationId,
    tagId,
    position,
    tipo,
    conteudoTexto,
    arquivoPath,
    arquivoNomeOriginal,
    arquivoNomeExibicao,
    arquivoMimeType,
    arquivoTamanhoBytes,
    data,
    dataEditadaManualmente,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'messages';
  @override
  VerificationContext validateIntegrity(
    Insertable<MessageRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('conversation_id')) {
      context.handle(
        _conversationIdMeta,
        conversationId.isAcceptableOrUnknown(
          data['conversation_id']!,
          _conversationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_conversationIdMeta);
    }
    if (data.containsKey('tag_id')) {
      context.handle(
        _tagIdMeta,
        tagId.isAcceptableOrUnknown(data['tag_id']!, _tagIdMeta),
      );
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    if (data.containsKey('conteudo_texto')) {
      context.handle(
        _conteudoTextoMeta,
        conteudoTexto.isAcceptableOrUnknown(
          data['conteudo_texto']!,
          _conteudoTextoMeta,
        ),
      );
    }
    if (data.containsKey('arquivo_path')) {
      context.handle(
        _arquivoPathMeta,
        arquivoPath.isAcceptableOrUnknown(
          data['arquivo_path']!,
          _arquivoPathMeta,
        ),
      );
    }
    if (data.containsKey('arquivo_nome_original')) {
      context.handle(
        _arquivoNomeOriginalMeta,
        arquivoNomeOriginal.isAcceptableOrUnknown(
          data['arquivo_nome_original']!,
          _arquivoNomeOriginalMeta,
        ),
      );
    }
    if (data.containsKey('arquivo_nome_exibicao')) {
      context.handle(
        _arquivoNomeExibicaoMeta,
        arquivoNomeExibicao.isAcceptableOrUnknown(
          data['arquivo_nome_exibicao']!,
          _arquivoNomeExibicaoMeta,
        ),
      );
    }
    if (data.containsKey('arquivo_mime_type')) {
      context.handle(
        _arquivoMimeTypeMeta,
        arquivoMimeType.isAcceptableOrUnknown(
          data['arquivo_mime_type']!,
          _arquivoMimeTypeMeta,
        ),
      );
    }
    if (data.containsKey('arquivo_tamanho_bytes')) {
      context.handle(
        _arquivoTamanhoBytesMeta,
        arquivoTamanhoBytes.isAcceptableOrUnknown(
          data['arquivo_tamanho_bytes']!,
          _arquivoTamanhoBytesMeta,
        ),
      );
    }
    if (data.containsKey('data')) {
      context.handle(
        _dataMeta,
        this.data.isAcceptableOrUnknown(data['data']!, _dataMeta),
      );
    } else if (isInserting) {
      context.missing(_dataMeta);
    }
    if (data.containsKey('data_editada_manualmente')) {
      context.handle(
        _dataEditadaManualmenteMeta,
        dataEditadaManualmente.isAcceptableOrUnknown(
          data['data_editada_manualmente']!,
          _dataEditadaManualmenteMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MessageRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MessageRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      conversationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}conversation_id'],
      )!,
      tagId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tag_id'],
      ),
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      tipo: $MessagesTable.$convertertipo.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}tipo'],
        )!,
      ),
      conteudoTexto: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}conteudo_texto'],
      ),
      arquivoPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}arquivo_path'],
      ),
      arquivoNomeOriginal: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}arquivo_nome_original'],
      ),
      arquivoNomeExibicao: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}arquivo_nome_exibicao'],
      ),
      arquivoMimeType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}arquivo_mime_type'],
      ),
      arquivoTamanhoBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}arquivo_tamanho_bytes'],
      ),
      data: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}data'],
      )!,
      dataEditadaManualmente: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}data_editada_manualmente'],
      )!,
    );
  }

  @override
  $MessagesTable createAlias(String alias) {
    return $MessagesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<MessageType, int, int> $convertertipo =
      const EnumIndexConverter<MessageType>(MessageType.values);
}

class MessageRow extends DataClass implements Insertable<MessageRow> {
  final String id;
  final String conversationId;

  /// RF04 — no máximo uma Tag por Mensagem (nullable = sem tag).
  final String? tagId;
  final int position;
  final MessageType tipo;
  final String? conteudoTexto;
  final String? arquivoPath;
  final String? arquivoNomeOriginal;
  final String? arquivoNomeExibicao;
  final String? arquivoMimeType;
  final int? arquivoTamanhoBytes;

  /// RF03 — apenas o dia, sem hora; atribuída no momento do envio e imutável
  /// por edição de conteúdo (só muda via exclusão+reenvio ou sobrescrita
  /// manual, ver `dataEditadaManualmente`).
  final DateTime data;
  final bool dataEditadaManualmente;
  const MessageRow({
    required this.id,
    required this.conversationId,
    this.tagId,
    required this.position,
    required this.tipo,
    this.conteudoTexto,
    this.arquivoPath,
    this.arquivoNomeOriginal,
    this.arquivoNomeExibicao,
    this.arquivoMimeType,
    this.arquivoTamanhoBytes,
    required this.data,
    required this.dataEditadaManualmente,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['conversation_id'] = Variable<String>(conversationId);
    if (!nullToAbsent || tagId != null) {
      map['tag_id'] = Variable<String>(tagId);
    }
    map['position'] = Variable<int>(position);
    {
      map['tipo'] = Variable<int>($MessagesTable.$convertertipo.toSql(tipo));
    }
    if (!nullToAbsent || conteudoTexto != null) {
      map['conteudo_texto'] = Variable<String>(conteudoTexto);
    }
    if (!nullToAbsent || arquivoPath != null) {
      map['arquivo_path'] = Variable<String>(arquivoPath);
    }
    if (!nullToAbsent || arquivoNomeOriginal != null) {
      map['arquivo_nome_original'] = Variable<String>(arquivoNomeOriginal);
    }
    if (!nullToAbsent || arquivoNomeExibicao != null) {
      map['arquivo_nome_exibicao'] = Variable<String>(arquivoNomeExibicao);
    }
    if (!nullToAbsent || arquivoMimeType != null) {
      map['arquivo_mime_type'] = Variable<String>(arquivoMimeType);
    }
    if (!nullToAbsent || arquivoTamanhoBytes != null) {
      map['arquivo_tamanho_bytes'] = Variable<int>(arquivoTamanhoBytes);
    }
    map['data'] = Variable<DateTime>(data);
    map['data_editada_manualmente'] = Variable<bool>(dataEditadaManualmente);
    return map;
  }

  MessagesCompanion toCompanion(bool nullToAbsent) {
    return MessagesCompanion(
      id: Value(id),
      conversationId: Value(conversationId),
      tagId: tagId == null && nullToAbsent
          ? const Value.absent()
          : Value(tagId),
      position: Value(position),
      tipo: Value(tipo),
      conteudoTexto: conteudoTexto == null && nullToAbsent
          ? const Value.absent()
          : Value(conteudoTexto),
      arquivoPath: arquivoPath == null && nullToAbsent
          ? const Value.absent()
          : Value(arquivoPath),
      arquivoNomeOriginal: arquivoNomeOriginal == null && nullToAbsent
          ? const Value.absent()
          : Value(arquivoNomeOriginal),
      arquivoNomeExibicao: arquivoNomeExibicao == null && nullToAbsent
          ? const Value.absent()
          : Value(arquivoNomeExibicao),
      arquivoMimeType: arquivoMimeType == null && nullToAbsent
          ? const Value.absent()
          : Value(arquivoMimeType),
      arquivoTamanhoBytes: arquivoTamanhoBytes == null && nullToAbsent
          ? const Value.absent()
          : Value(arquivoTamanhoBytes),
      data: Value(data),
      dataEditadaManualmente: Value(dataEditadaManualmente),
    );
  }

  factory MessageRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MessageRow(
      id: serializer.fromJson<String>(json['id']),
      conversationId: serializer.fromJson<String>(json['conversationId']),
      tagId: serializer.fromJson<String?>(json['tagId']),
      position: serializer.fromJson<int>(json['position']),
      tipo: $MessagesTable.$convertertipo.fromJson(
        serializer.fromJson<int>(json['tipo']),
      ),
      conteudoTexto: serializer.fromJson<String?>(json['conteudoTexto']),
      arquivoPath: serializer.fromJson<String?>(json['arquivoPath']),
      arquivoNomeOriginal: serializer.fromJson<String?>(
        json['arquivoNomeOriginal'],
      ),
      arquivoNomeExibicao: serializer.fromJson<String?>(
        json['arquivoNomeExibicao'],
      ),
      arquivoMimeType: serializer.fromJson<String?>(json['arquivoMimeType']),
      arquivoTamanhoBytes: serializer.fromJson<int?>(
        json['arquivoTamanhoBytes'],
      ),
      data: serializer.fromJson<DateTime>(json['data']),
      dataEditadaManualmente: serializer.fromJson<bool>(
        json['dataEditadaManualmente'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'conversationId': serializer.toJson<String>(conversationId),
      'tagId': serializer.toJson<String?>(tagId),
      'position': serializer.toJson<int>(position),
      'tipo': serializer.toJson<int>(
        $MessagesTable.$convertertipo.toJson(tipo),
      ),
      'conteudoTexto': serializer.toJson<String?>(conteudoTexto),
      'arquivoPath': serializer.toJson<String?>(arquivoPath),
      'arquivoNomeOriginal': serializer.toJson<String?>(arquivoNomeOriginal),
      'arquivoNomeExibicao': serializer.toJson<String?>(arquivoNomeExibicao),
      'arquivoMimeType': serializer.toJson<String?>(arquivoMimeType),
      'arquivoTamanhoBytes': serializer.toJson<int?>(arquivoTamanhoBytes),
      'data': serializer.toJson<DateTime>(data),
      'dataEditadaManualmente': serializer.toJson<bool>(dataEditadaManualmente),
    };
  }

  MessageRow copyWith({
    String? id,
    String? conversationId,
    Value<String?> tagId = const Value.absent(),
    int? position,
    MessageType? tipo,
    Value<String?> conteudoTexto = const Value.absent(),
    Value<String?> arquivoPath = const Value.absent(),
    Value<String?> arquivoNomeOriginal = const Value.absent(),
    Value<String?> arquivoNomeExibicao = const Value.absent(),
    Value<String?> arquivoMimeType = const Value.absent(),
    Value<int?> arquivoTamanhoBytes = const Value.absent(),
    DateTime? data,
    bool? dataEditadaManualmente,
  }) => MessageRow(
    id: id ?? this.id,
    conversationId: conversationId ?? this.conversationId,
    tagId: tagId.present ? tagId.value : this.tagId,
    position: position ?? this.position,
    tipo: tipo ?? this.tipo,
    conteudoTexto: conteudoTexto.present
        ? conteudoTexto.value
        : this.conteudoTexto,
    arquivoPath: arquivoPath.present ? arquivoPath.value : this.arquivoPath,
    arquivoNomeOriginal: arquivoNomeOriginal.present
        ? arquivoNomeOriginal.value
        : this.arquivoNomeOriginal,
    arquivoNomeExibicao: arquivoNomeExibicao.present
        ? arquivoNomeExibicao.value
        : this.arquivoNomeExibicao,
    arquivoMimeType: arquivoMimeType.present
        ? arquivoMimeType.value
        : this.arquivoMimeType,
    arquivoTamanhoBytes: arquivoTamanhoBytes.present
        ? arquivoTamanhoBytes.value
        : this.arquivoTamanhoBytes,
    data: data ?? this.data,
    dataEditadaManualmente:
        dataEditadaManualmente ?? this.dataEditadaManualmente,
  );
  MessageRow copyWithCompanion(MessagesCompanion data) {
    return MessageRow(
      id: data.id.present ? data.id.value : this.id,
      conversationId: data.conversationId.present
          ? data.conversationId.value
          : this.conversationId,
      tagId: data.tagId.present ? data.tagId.value : this.tagId,
      position: data.position.present ? data.position.value : this.position,
      tipo: data.tipo.present ? data.tipo.value : this.tipo,
      conteudoTexto: data.conteudoTexto.present
          ? data.conteudoTexto.value
          : this.conteudoTexto,
      arquivoPath: data.arquivoPath.present
          ? data.arquivoPath.value
          : this.arquivoPath,
      arquivoNomeOriginal: data.arquivoNomeOriginal.present
          ? data.arquivoNomeOriginal.value
          : this.arquivoNomeOriginal,
      arquivoNomeExibicao: data.arquivoNomeExibicao.present
          ? data.arquivoNomeExibicao.value
          : this.arquivoNomeExibicao,
      arquivoMimeType: data.arquivoMimeType.present
          ? data.arquivoMimeType.value
          : this.arquivoMimeType,
      arquivoTamanhoBytes: data.arquivoTamanhoBytes.present
          ? data.arquivoTamanhoBytes.value
          : this.arquivoTamanhoBytes,
      data: data.data.present ? data.data.value : this.data,
      dataEditadaManualmente: data.dataEditadaManualmente.present
          ? data.dataEditadaManualmente.value
          : this.dataEditadaManualmente,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MessageRow(')
          ..write('id: $id, ')
          ..write('conversationId: $conversationId, ')
          ..write('tagId: $tagId, ')
          ..write('position: $position, ')
          ..write('tipo: $tipo, ')
          ..write('conteudoTexto: $conteudoTexto, ')
          ..write('arquivoPath: $arquivoPath, ')
          ..write('arquivoNomeOriginal: $arquivoNomeOriginal, ')
          ..write('arquivoNomeExibicao: $arquivoNomeExibicao, ')
          ..write('arquivoMimeType: $arquivoMimeType, ')
          ..write('arquivoTamanhoBytes: $arquivoTamanhoBytes, ')
          ..write('data: $data, ')
          ..write('dataEditadaManualmente: $dataEditadaManualmente')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    conversationId,
    tagId,
    position,
    tipo,
    conteudoTexto,
    arquivoPath,
    arquivoNomeOriginal,
    arquivoNomeExibicao,
    arquivoMimeType,
    arquivoTamanhoBytes,
    data,
    dataEditadaManualmente,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MessageRow &&
          other.id == this.id &&
          other.conversationId == this.conversationId &&
          other.tagId == this.tagId &&
          other.position == this.position &&
          other.tipo == this.tipo &&
          other.conteudoTexto == this.conteudoTexto &&
          other.arquivoPath == this.arquivoPath &&
          other.arquivoNomeOriginal == this.arquivoNomeOriginal &&
          other.arquivoNomeExibicao == this.arquivoNomeExibicao &&
          other.arquivoMimeType == this.arquivoMimeType &&
          other.arquivoTamanhoBytes == this.arquivoTamanhoBytes &&
          other.data == this.data &&
          other.dataEditadaManualmente == this.dataEditadaManualmente);
}

class MessagesCompanion extends UpdateCompanion<MessageRow> {
  final Value<String> id;
  final Value<String> conversationId;
  final Value<String?> tagId;
  final Value<int> position;
  final Value<MessageType> tipo;
  final Value<String?> conteudoTexto;
  final Value<String?> arquivoPath;
  final Value<String?> arquivoNomeOriginal;
  final Value<String?> arquivoNomeExibicao;
  final Value<String?> arquivoMimeType;
  final Value<int?> arquivoTamanhoBytes;
  final Value<DateTime> data;
  final Value<bool> dataEditadaManualmente;
  final Value<int> rowid;
  const MessagesCompanion({
    this.id = const Value.absent(),
    this.conversationId = const Value.absent(),
    this.tagId = const Value.absent(),
    this.position = const Value.absent(),
    this.tipo = const Value.absent(),
    this.conteudoTexto = const Value.absent(),
    this.arquivoPath = const Value.absent(),
    this.arquivoNomeOriginal = const Value.absent(),
    this.arquivoNomeExibicao = const Value.absent(),
    this.arquivoMimeType = const Value.absent(),
    this.arquivoTamanhoBytes = const Value.absent(),
    this.data = const Value.absent(),
    this.dataEditadaManualmente = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MessagesCompanion.insert({
    required String id,
    required String conversationId,
    this.tagId = const Value.absent(),
    required int position,
    this.tipo = const Value.absent(),
    this.conteudoTexto = const Value.absent(),
    this.arquivoPath = const Value.absent(),
    this.arquivoNomeOriginal = const Value.absent(),
    this.arquivoNomeExibicao = const Value.absent(),
    this.arquivoMimeType = const Value.absent(),
    this.arquivoTamanhoBytes = const Value.absent(),
    required DateTime data,
    this.dataEditadaManualmente = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       conversationId = Value(conversationId),
       position = Value(position),
       data = Value(data);
  static Insertable<MessageRow> custom({
    Expression<String>? id,
    Expression<String>? conversationId,
    Expression<String>? tagId,
    Expression<int>? position,
    Expression<int>? tipo,
    Expression<String>? conteudoTexto,
    Expression<String>? arquivoPath,
    Expression<String>? arquivoNomeOriginal,
    Expression<String>? arquivoNomeExibicao,
    Expression<String>? arquivoMimeType,
    Expression<int>? arquivoTamanhoBytes,
    Expression<DateTime>? data,
    Expression<bool>? dataEditadaManualmente,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (conversationId != null) 'conversation_id': conversationId,
      if (tagId != null) 'tag_id': tagId,
      if (position != null) 'position': position,
      if (tipo != null) 'tipo': tipo,
      if (conteudoTexto != null) 'conteudo_texto': conteudoTexto,
      if (arquivoPath != null) 'arquivo_path': arquivoPath,
      if (arquivoNomeOriginal != null)
        'arquivo_nome_original': arquivoNomeOriginal,
      if (arquivoNomeExibicao != null)
        'arquivo_nome_exibicao': arquivoNomeExibicao,
      if (arquivoMimeType != null) 'arquivo_mime_type': arquivoMimeType,
      if (arquivoTamanhoBytes != null)
        'arquivo_tamanho_bytes': arquivoTamanhoBytes,
      if (data != null) 'data': data,
      if (dataEditadaManualmente != null)
        'data_editada_manualmente': dataEditadaManualmente,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MessagesCompanion copyWith({
    Value<String>? id,
    Value<String>? conversationId,
    Value<String?>? tagId,
    Value<int>? position,
    Value<MessageType>? tipo,
    Value<String?>? conteudoTexto,
    Value<String?>? arquivoPath,
    Value<String?>? arquivoNomeOriginal,
    Value<String?>? arquivoNomeExibicao,
    Value<String?>? arquivoMimeType,
    Value<int?>? arquivoTamanhoBytes,
    Value<DateTime>? data,
    Value<bool>? dataEditadaManualmente,
    Value<int>? rowid,
  }) {
    return MessagesCompanion(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      tagId: tagId ?? this.tagId,
      position: position ?? this.position,
      tipo: tipo ?? this.tipo,
      conteudoTexto: conteudoTexto ?? this.conteudoTexto,
      arquivoPath: arquivoPath ?? this.arquivoPath,
      arquivoNomeOriginal: arquivoNomeOriginal ?? this.arquivoNomeOriginal,
      arquivoNomeExibicao: arquivoNomeExibicao ?? this.arquivoNomeExibicao,
      arquivoMimeType: arquivoMimeType ?? this.arquivoMimeType,
      arquivoTamanhoBytes: arquivoTamanhoBytes ?? this.arquivoTamanhoBytes,
      data: data ?? this.data,
      dataEditadaManualmente:
          dataEditadaManualmente ?? this.dataEditadaManualmente,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (conversationId.present) {
      map['conversation_id'] = Variable<String>(conversationId.value);
    }
    if (tagId.present) {
      map['tag_id'] = Variable<String>(tagId.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (tipo.present) {
      map['tipo'] = Variable<int>(
        $MessagesTable.$convertertipo.toSql(tipo.value),
      );
    }
    if (conteudoTexto.present) {
      map['conteudo_texto'] = Variable<String>(conteudoTexto.value);
    }
    if (arquivoPath.present) {
      map['arquivo_path'] = Variable<String>(arquivoPath.value);
    }
    if (arquivoNomeOriginal.present) {
      map['arquivo_nome_original'] = Variable<String>(
        arquivoNomeOriginal.value,
      );
    }
    if (arquivoNomeExibicao.present) {
      map['arquivo_nome_exibicao'] = Variable<String>(
        arquivoNomeExibicao.value,
      );
    }
    if (arquivoMimeType.present) {
      map['arquivo_mime_type'] = Variable<String>(arquivoMimeType.value);
    }
    if (arquivoTamanhoBytes.present) {
      map['arquivo_tamanho_bytes'] = Variable<int>(arquivoTamanhoBytes.value);
    }
    if (data.present) {
      map['data'] = Variable<DateTime>(data.value);
    }
    if (dataEditadaManualmente.present) {
      map['data_editada_manualmente'] = Variable<bool>(
        dataEditadaManualmente.value,
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MessagesCompanion(')
          ..write('id: $id, ')
          ..write('conversationId: $conversationId, ')
          ..write('tagId: $tagId, ')
          ..write('position: $position, ')
          ..write('tipo: $tipo, ')
          ..write('conteudoTexto: $conteudoTexto, ')
          ..write('arquivoPath: $arquivoPath, ')
          ..write('arquivoNomeOriginal: $arquivoNomeOriginal, ')
          ..write('arquivoNomeExibicao: $arquivoNomeExibicao, ')
          ..write('arquivoMimeType: $arquivoMimeType, ')
          ..write('arquivoTamanhoBytes: $arquivoTamanhoBytes, ')
          ..write('data: $data, ')
          ..write('dataEditadaManualmente: $dataEditadaManualmente, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ConversationsTable conversations = $ConversationsTable(this);
  late final $TagsTable tags = $TagsTable(this);
  late final $MessagesTable messages = $MessagesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    conversations,
    tags,
    messages,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'tags',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('messages', kind: UpdateKind.update)],
    ),
  ]);
}

typedef $$ConversationsTableCreateCompanionBuilder =
    ConversationsCompanion Function({
      required String id,
      required String titulo,
      required DateTime criadoEm,
      required DateTime atualizadoEm,
      Value<bool> protegidoPorSenha,
      Value<String?> senhaHash,
      Value<String?> salt,
      Value<String> rascunho,
      Value<int> rowid,
    });
typedef $$ConversationsTableUpdateCompanionBuilder =
    ConversationsCompanion Function({
      Value<String> id,
      Value<String> titulo,
      Value<DateTime> criadoEm,
      Value<DateTime> atualizadoEm,
      Value<bool> protegidoPorSenha,
      Value<String?> senhaHash,
      Value<String?> salt,
      Value<String> rascunho,
      Value<int> rowid,
    });

final class $$ConversationsTableReferences
    extends
        BaseReferences<_$AppDatabase, $ConversationsTable, ConversationRow> {
  $$ConversationsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$TagsTable, List<TagRow>> _tagsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.tags,
    aliasName: 'conversations__id__tags__conversation_id',
  );

  $$TagsTableProcessedTableManager get tagsRefs {
    final manager = $$TagsTableTableManager(
      $_db,
      $_db.tags,
    ).filter((f) => f.conversationId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_tagsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$MessagesTable, List<MessageRow>>
  _messagesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.messages,
    aliasName: 'conversations__id__messages__conversation_id',
  );

  $$MessagesTableProcessedTableManager get messagesRefs {
    final manager = $$MessagesTableTableManager(
      $_db,
      $_db.messages,
    ).filter((f) => f.conversationId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_messagesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ConversationsTableFilterComposer
    extends Composer<_$AppDatabase, $ConversationsTable> {
  $$ConversationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get titulo => $composableBuilder(
    column: $table.titulo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get criadoEm => $composableBuilder(
    column: $table.criadoEm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get atualizadoEm => $composableBuilder(
    column: $table.atualizadoEm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get protegidoPorSenha => $composableBuilder(
    column: $table.protegidoPorSenha,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get senhaHash => $composableBuilder(
    column: $table.senhaHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get salt => $composableBuilder(
    column: $table.salt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rascunho => $composableBuilder(
    column: $table.rascunho,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> tagsRefs(
    Expression<bool> Function($$TagsTableFilterComposer f) f,
  ) {
    final $$TagsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.tags,
      getReferencedColumn: (t) => t.conversationId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TagsTableFilterComposer(
            $db: $db,
            $table: $db.tags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> messagesRefs(
    Expression<bool> Function($$MessagesTableFilterComposer f) f,
  ) {
    final $$MessagesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.messages,
      getReferencedColumn: (t) => t.conversationId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MessagesTableFilterComposer(
            $db: $db,
            $table: $db.messages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ConversationsTableOrderingComposer
    extends Composer<_$AppDatabase, $ConversationsTable> {
  $$ConversationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get titulo => $composableBuilder(
    column: $table.titulo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get criadoEm => $composableBuilder(
    column: $table.criadoEm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get atualizadoEm => $composableBuilder(
    column: $table.atualizadoEm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get protegidoPorSenha => $composableBuilder(
    column: $table.protegidoPorSenha,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get senhaHash => $composableBuilder(
    column: $table.senhaHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get salt => $composableBuilder(
    column: $table.salt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rascunho => $composableBuilder(
    column: $table.rascunho,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ConversationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ConversationsTable> {
  $$ConversationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get titulo =>
      $composableBuilder(column: $table.titulo, builder: (column) => column);

  GeneratedColumn<DateTime> get criadoEm =>
      $composableBuilder(column: $table.criadoEm, builder: (column) => column);

  GeneratedColumn<DateTime> get atualizadoEm => $composableBuilder(
    column: $table.atualizadoEm,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get protegidoPorSenha => $composableBuilder(
    column: $table.protegidoPorSenha,
    builder: (column) => column,
  );

  GeneratedColumn<String> get senhaHash =>
      $composableBuilder(column: $table.senhaHash, builder: (column) => column);

  GeneratedColumn<String> get salt =>
      $composableBuilder(column: $table.salt, builder: (column) => column);

  GeneratedColumn<String> get rascunho =>
      $composableBuilder(column: $table.rascunho, builder: (column) => column);

  Expression<T> tagsRefs<T extends Object>(
    Expression<T> Function($$TagsTableAnnotationComposer a) f,
  ) {
    final $$TagsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.tags,
      getReferencedColumn: (t) => t.conversationId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TagsTableAnnotationComposer(
            $db: $db,
            $table: $db.tags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> messagesRefs<T extends Object>(
    Expression<T> Function($$MessagesTableAnnotationComposer a) f,
  ) {
    final $$MessagesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.messages,
      getReferencedColumn: (t) => t.conversationId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MessagesTableAnnotationComposer(
            $db: $db,
            $table: $db.messages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ConversationsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ConversationsTable,
          ConversationRow,
          $$ConversationsTableFilterComposer,
          $$ConversationsTableOrderingComposer,
          $$ConversationsTableAnnotationComposer,
          $$ConversationsTableCreateCompanionBuilder,
          $$ConversationsTableUpdateCompanionBuilder,
          (ConversationRow, $$ConversationsTableReferences),
          ConversationRow,
          PrefetchHooks Function({bool tagsRefs, bool messagesRefs})
        > {
  $$ConversationsTableTableManager(_$AppDatabase db, $ConversationsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ConversationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ConversationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ConversationsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> titulo = const Value.absent(),
                Value<DateTime> criadoEm = const Value.absent(),
                Value<DateTime> atualizadoEm = const Value.absent(),
                Value<bool> protegidoPorSenha = const Value.absent(),
                Value<String?> senhaHash = const Value.absent(),
                Value<String?> salt = const Value.absent(),
                Value<String> rascunho = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ConversationsCompanion(
                id: id,
                titulo: titulo,
                criadoEm: criadoEm,
                atualizadoEm: atualizadoEm,
                protegidoPorSenha: protegidoPorSenha,
                senhaHash: senhaHash,
                salt: salt,
                rascunho: rascunho,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String titulo,
                required DateTime criadoEm,
                required DateTime atualizadoEm,
                Value<bool> protegidoPorSenha = const Value.absent(),
                Value<String?> senhaHash = const Value.absent(),
                Value<String?> salt = const Value.absent(),
                Value<String> rascunho = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ConversationsCompanion.insert(
                id: id,
                titulo: titulo,
                criadoEm: criadoEm,
                atualizadoEm: atualizadoEm,
                protegidoPorSenha: protegidoPorSenha,
                senhaHash: senhaHash,
                salt: salt,
                rascunho: rascunho,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ConversationsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({tagsRefs = false, messagesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (tagsRefs) db.tags,
                if (messagesRefs) db.messages,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (tagsRefs)
                    await $_getPrefetchedData<
                      ConversationRow,
                      $ConversationsTable,
                      TagRow
                    >(
                      currentTable: table,
                      referencedTable: $$ConversationsTableReferences
                          ._tagsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$ConversationsTableReferences(
                            db,
                            table,
                            p0,
                          ).tagsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where(
                            (e) => e.conversationId == item.id,
                          ),
                      typedResults: items,
                    ),
                  if (messagesRefs)
                    await $_getPrefetchedData<
                      ConversationRow,
                      $ConversationsTable,
                      MessageRow
                    >(
                      currentTable: table,
                      referencedTable: $$ConversationsTableReferences
                          ._messagesRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$ConversationsTableReferences(
                            db,
                            table,
                            p0,
                          ).messagesRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where(
                            (e) => e.conversationId == item.id,
                          ),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$ConversationsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ConversationsTable,
      ConversationRow,
      $$ConversationsTableFilterComposer,
      $$ConversationsTableOrderingComposer,
      $$ConversationsTableAnnotationComposer,
      $$ConversationsTableCreateCompanionBuilder,
      $$ConversationsTableUpdateCompanionBuilder,
      (ConversationRow, $$ConversationsTableReferences),
      ConversationRow,
      PrefetchHooks Function({bool tagsRefs, bool messagesRefs})
    >;
typedef $$TagsTableCreateCompanionBuilder =
    TagsCompanion Function({
      required String id,
      required String conversationId,
      required String nome,
      required String cor,
      Value<int> rowid,
    });
typedef $$TagsTableUpdateCompanionBuilder =
    TagsCompanion Function({
      Value<String> id,
      Value<String> conversationId,
      Value<String> nome,
      Value<String> cor,
      Value<int> rowid,
    });

final class $$TagsTableReferences
    extends BaseReferences<_$AppDatabase, $TagsTable, TagRow> {
  $$TagsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ConversationsTable _conversationIdTable(_$AppDatabase db) =>
      db.conversations.createAlias('tags__conversation_id__conversations__id');

  $$ConversationsTableProcessedTableManager get conversationId {
    final $_column = $_itemColumn<String>('conversation_id')!;

    final manager = $$ConversationsTableTableManager(
      $_db,
      $_db.conversations,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_conversationIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$MessagesTable, List<MessageRow>>
  _messagesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.messages,
    aliasName: 'tags__id__messages__tag_id',
  );

  $$MessagesTableProcessedTableManager get messagesRefs {
    final manager = $$MessagesTableTableManager(
      $_db,
      $_db.messages,
    ).filter((f) => f.tagId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_messagesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$TagsTableFilterComposer extends Composer<_$AppDatabase, $TagsTable> {
  $$TagsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nome => $composableBuilder(
    column: $table.nome,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cor => $composableBuilder(
    column: $table.cor,
    builder: (column) => ColumnFilters(column),
  );

  $$ConversationsTableFilterComposer get conversationId {
    final $$ConversationsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.conversationId,
      referencedTable: $db.conversations,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ConversationsTableFilterComposer(
            $db: $db,
            $table: $db.conversations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> messagesRefs(
    Expression<bool> Function($$MessagesTableFilterComposer f) f,
  ) {
    final $$MessagesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.messages,
      getReferencedColumn: (t) => t.tagId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MessagesTableFilterComposer(
            $db: $db,
            $table: $db.messages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TagsTableOrderingComposer extends Composer<_$AppDatabase, $TagsTable> {
  $$TagsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nome => $composableBuilder(
    column: $table.nome,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cor => $composableBuilder(
    column: $table.cor,
    builder: (column) => ColumnOrderings(column),
  );

  $$ConversationsTableOrderingComposer get conversationId {
    final $$ConversationsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.conversationId,
      referencedTable: $db.conversations,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ConversationsTableOrderingComposer(
            $db: $db,
            $table: $db.conversations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TagsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TagsTable> {
  $$TagsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get nome =>
      $composableBuilder(column: $table.nome, builder: (column) => column);

  GeneratedColumn<String> get cor =>
      $composableBuilder(column: $table.cor, builder: (column) => column);

  $$ConversationsTableAnnotationComposer get conversationId {
    final $$ConversationsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.conversationId,
      referencedTable: $db.conversations,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ConversationsTableAnnotationComposer(
            $db: $db,
            $table: $db.conversations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> messagesRefs<T extends Object>(
    Expression<T> Function($$MessagesTableAnnotationComposer a) f,
  ) {
    final $$MessagesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.messages,
      getReferencedColumn: (t) => t.tagId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MessagesTableAnnotationComposer(
            $db: $db,
            $table: $db.messages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TagsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TagsTable,
          TagRow,
          $$TagsTableFilterComposer,
          $$TagsTableOrderingComposer,
          $$TagsTableAnnotationComposer,
          $$TagsTableCreateCompanionBuilder,
          $$TagsTableUpdateCompanionBuilder,
          (TagRow, $$TagsTableReferences),
          TagRow,
          PrefetchHooks Function({bool conversationId, bool messagesRefs})
        > {
  $$TagsTableTableManager(_$AppDatabase db, $TagsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TagsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TagsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TagsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> conversationId = const Value.absent(),
                Value<String> nome = const Value.absent(),
                Value<String> cor = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TagsCompanion(
                id: id,
                conversationId: conversationId,
                nome: nome,
                cor: cor,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String conversationId,
                required String nome,
                required String cor,
                Value<int> rowid = const Value.absent(),
              }) => TagsCompanion.insert(
                id: id,
                conversationId: conversationId,
                nome: nome,
                cor: cor,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$TagsTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback:
              ({conversationId = false, messagesRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [if (messagesRefs) db.messages],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (conversationId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.conversationId,
                                    referencedTable: $$TagsTableReferences
                                        ._conversationIdTable(db),
                                    referencedColumn: $$TagsTableReferences
                                        ._conversationIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (messagesRefs)
                        await $_getPrefetchedData<
                          TagRow,
                          $TagsTable,
                          MessageRow
                        >(
                          currentTable: table,
                          referencedTable: $$TagsTableReferences
                              ._messagesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TagsTableReferences(db, table, p0).messagesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.tagId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$TagsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TagsTable,
      TagRow,
      $$TagsTableFilterComposer,
      $$TagsTableOrderingComposer,
      $$TagsTableAnnotationComposer,
      $$TagsTableCreateCompanionBuilder,
      $$TagsTableUpdateCompanionBuilder,
      (TagRow, $$TagsTableReferences),
      TagRow,
      PrefetchHooks Function({bool conversationId, bool messagesRefs})
    >;
typedef $$MessagesTableCreateCompanionBuilder =
    MessagesCompanion Function({
      required String id,
      required String conversationId,
      Value<String?> tagId,
      required int position,
      Value<MessageType> tipo,
      Value<String?> conteudoTexto,
      Value<String?> arquivoPath,
      Value<String?> arquivoNomeOriginal,
      Value<String?> arquivoNomeExibicao,
      Value<String?> arquivoMimeType,
      Value<int?> arquivoTamanhoBytes,
      required DateTime data,
      Value<bool> dataEditadaManualmente,
      Value<int> rowid,
    });
typedef $$MessagesTableUpdateCompanionBuilder =
    MessagesCompanion Function({
      Value<String> id,
      Value<String> conversationId,
      Value<String?> tagId,
      Value<int> position,
      Value<MessageType> tipo,
      Value<String?> conteudoTexto,
      Value<String?> arquivoPath,
      Value<String?> arquivoNomeOriginal,
      Value<String?> arquivoNomeExibicao,
      Value<String?> arquivoMimeType,
      Value<int?> arquivoTamanhoBytes,
      Value<DateTime> data,
      Value<bool> dataEditadaManualmente,
      Value<int> rowid,
    });

final class $$MessagesTableReferences
    extends BaseReferences<_$AppDatabase, $MessagesTable, MessageRow> {
  $$MessagesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ConversationsTable _conversationIdTable(_$AppDatabase db) => db
      .conversations
      .createAlias('messages__conversation_id__conversations__id');

  $$ConversationsTableProcessedTableManager get conversationId {
    final $_column = $_itemColumn<String>('conversation_id')!;

    final manager = $$ConversationsTableTableManager(
      $_db,
      $_db.conversations,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_conversationIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $TagsTable _tagIdTable(_$AppDatabase db) =>
      db.tags.createAlias('messages__tag_id__tags__id');

  $$TagsTableProcessedTableManager? get tagId {
    final $_column = $_itemColumn<String>('tag_id');
    if ($_column == null) return null;
    final manager = $$TagsTableTableManager(
      $_db,
      $_db.tags,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_tagIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$MessagesTableFilterComposer
    extends Composer<_$AppDatabase, $MessagesTable> {
  $$MessagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<MessageType, MessageType, int> get tipo =>
      $composableBuilder(
        column: $table.tipo,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get conteudoTexto => $composableBuilder(
    column: $table.conteudoTexto,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get arquivoPath => $composableBuilder(
    column: $table.arquivoPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get arquivoNomeOriginal => $composableBuilder(
    column: $table.arquivoNomeOriginal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get arquivoNomeExibicao => $composableBuilder(
    column: $table.arquivoNomeExibicao,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get arquivoMimeType => $composableBuilder(
    column: $table.arquivoMimeType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get arquivoTamanhoBytes => $composableBuilder(
    column: $table.arquivoTamanhoBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get dataEditadaManualmente => $composableBuilder(
    column: $table.dataEditadaManualmente,
    builder: (column) => ColumnFilters(column),
  );

  $$ConversationsTableFilterComposer get conversationId {
    final $$ConversationsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.conversationId,
      referencedTable: $db.conversations,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ConversationsTableFilterComposer(
            $db: $db,
            $table: $db.conversations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TagsTableFilterComposer get tagId {
    final $$TagsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tagId,
      referencedTable: $db.tags,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TagsTableFilterComposer(
            $db: $db,
            $table: $db.tags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MessagesTableOrderingComposer
    extends Composer<_$AppDatabase, $MessagesTable> {
  $$MessagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get tipo => $composableBuilder(
    column: $table.tipo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get conteudoTexto => $composableBuilder(
    column: $table.conteudoTexto,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get arquivoPath => $composableBuilder(
    column: $table.arquivoPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get arquivoNomeOriginal => $composableBuilder(
    column: $table.arquivoNomeOriginal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get arquivoNomeExibicao => $composableBuilder(
    column: $table.arquivoNomeExibicao,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get arquivoMimeType => $composableBuilder(
    column: $table.arquivoMimeType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get arquivoTamanhoBytes => $composableBuilder(
    column: $table.arquivoTamanhoBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get dataEditadaManualmente => $composableBuilder(
    column: $table.dataEditadaManualmente,
    builder: (column) => ColumnOrderings(column),
  );

  $$ConversationsTableOrderingComposer get conversationId {
    final $$ConversationsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.conversationId,
      referencedTable: $db.conversations,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ConversationsTableOrderingComposer(
            $db: $db,
            $table: $db.conversations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TagsTableOrderingComposer get tagId {
    final $$TagsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tagId,
      referencedTable: $db.tags,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TagsTableOrderingComposer(
            $db: $db,
            $table: $db.tags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MessagesTableAnnotationComposer
    extends Composer<_$AppDatabase, $MessagesTable> {
  $$MessagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumnWithTypeConverter<MessageType, int> get tipo =>
      $composableBuilder(column: $table.tipo, builder: (column) => column);

  GeneratedColumn<String> get conteudoTexto => $composableBuilder(
    column: $table.conteudoTexto,
    builder: (column) => column,
  );

  GeneratedColumn<String> get arquivoPath => $composableBuilder(
    column: $table.arquivoPath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get arquivoNomeOriginal => $composableBuilder(
    column: $table.arquivoNomeOriginal,
    builder: (column) => column,
  );

  GeneratedColumn<String> get arquivoNomeExibicao => $composableBuilder(
    column: $table.arquivoNomeExibicao,
    builder: (column) => column,
  );

  GeneratedColumn<String> get arquivoMimeType => $composableBuilder(
    column: $table.arquivoMimeType,
    builder: (column) => column,
  );

  GeneratedColumn<int> get arquivoTamanhoBytes => $composableBuilder(
    column: $table.arquivoTamanhoBytes,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get data =>
      $composableBuilder(column: $table.data, builder: (column) => column);

  GeneratedColumn<bool> get dataEditadaManualmente => $composableBuilder(
    column: $table.dataEditadaManualmente,
    builder: (column) => column,
  );

  $$ConversationsTableAnnotationComposer get conversationId {
    final $$ConversationsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.conversationId,
      referencedTable: $db.conversations,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ConversationsTableAnnotationComposer(
            $db: $db,
            $table: $db.conversations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TagsTableAnnotationComposer get tagId {
    final $$TagsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tagId,
      referencedTable: $db.tags,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TagsTableAnnotationComposer(
            $db: $db,
            $table: $db.tags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MessagesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MessagesTable,
          MessageRow,
          $$MessagesTableFilterComposer,
          $$MessagesTableOrderingComposer,
          $$MessagesTableAnnotationComposer,
          $$MessagesTableCreateCompanionBuilder,
          $$MessagesTableUpdateCompanionBuilder,
          (MessageRow, $$MessagesTableReferences),
          MessageRow,
          PrefetchHooks Function({bool conversationId, bool tagId})
        > {
  $$MessagesTableTableManager(_$AppDatabase db, $MessagesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MessagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MessagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MessagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> conversationId = const Value.absent(),
                Value<String?> tagId = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<MessageType> tipo = const Value.absent(),
                Value<String?> conteudoTexto = const Value.absent(),
                Value<String?> arquivoPath = const Value.absent(),
                Value<String?> arquivoNomeOriginal = const Value.absent(),
                Value<String?> arquivoNomeExibicao = const Value.absent(),
                Value<String?> arquivoMimeType = const Value.absent(),
                Value<int?> arquivoTamanhoBytes = const Value.absent(),
                Value<DateTime> data = const Value.absent(),
                Value<bool> dataEditadaManualmente = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MessagesCompanion(
                id: id,
                conversationId: conversationId,
                tagId: tagId,
                position: position,
                tipo: tipo,
                conteudoTexto: conteudoTexto,
                arquivoPath: arquivoPath,
                arquivoNomeOriginal: arquivoNomeOriginal,
                arquivoNomeExibicao: arquivoNomeExibicao,
                arquivoMimeType: arquivoMimeType,
                arquivoTamanhoBytes: arquivoTamanhoBytes,
                data: data,
                dataEditadaManualmente: dataEditadaManualmente,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String conversationId,
                Value<String?> tagId = const Value.absent(),
                required int position,
                Value<MessageType> tipo = const Value.absent(),
                Value<String?> conteudoTexto = const Value.absent(),
                Value<String?> arquivoPath = const Value.absent(),
                Value<String?> arquivoNomeOriginal = const Value.absent(),
                Value<String?> arquivoNomeExibicao = const Value.absent(),
                Value<String?> arquivoMimeType = const Value.absent(),
                Value<int?> arquivoTamanhoBytes = const Value.absent(),
                required DateTime data,
                Value<bool> dataEditadaManualmente = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MessagesCompanion.insert(
                id: id,
                conversationId: conversationId,
                tagId: tagId,
                position: position,
                tipo: tipo,
                conteudoTexto: conteudoTexto,
                arquivoPath: arquivoPath,
                arquivoNomeOriginal: arquivoNomeOriginal,
                arquivoNomeExibicao: arquivoNomeExibicao,
                arquivoMimeType: arquivoMimeType,
                arquivoTamanhoBytes: arquivoTamanhoBytes,
                data: data,
                dataEditadaManualmente: dataEditadaManualmente,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$MessagesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({conversationId = false, tagId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (conversationId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.conversationId,
                                referencedTable: $$MessagesTableReferences
                                    ._conversationIdTable(db),
                                referencedColumn: $$MessagesTableReferences
                                    ._conversationIdTable(db)
                                    .id,
                              )
                              as T;
                    }
                    if (tagId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.tagId,
                                referencedTable: $$MessagesTableReferences
                                    ._tagIdTable(db),
                                referencedColumn: $$MessagesTableReferences
                                    ._tagIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$MessagesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MessagesTable,
      MessageRow,
      $$MessagesTableFilterComposer,
      $$MessagesTableOrderingComposer,
      $$MessagesTableAnnotationComposer,
      $$MessagesTableCreateCompanionBuilder,
      $$MessagesTableUpdateCompanionBuilder,
      (MessageRow, $$MessagesTableReferences),
      MessageRow,
      PrefetchHooks Function({bool conversationId, bool tagId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ConversationsTableTableManager get conversations =>
      $$ConversationsTableTableManager(_db, _db.conversations);
  $$TagsTableTableManager get tags => $$TagsTableTableManager(_db, _db.tags);
  $$MessagesTableTableManager get messages =>
      $$MessagesTableTableManager(_db, _db.messages);
}
