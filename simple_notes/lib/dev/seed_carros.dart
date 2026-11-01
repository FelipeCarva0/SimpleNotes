import 'dart:math';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:uuid/uuid.dart';
import '../database/app_database.dart';
import '../database/tables.dart' show MessageType;
import '../repositories/conversation_repository.dart';

/// DEV-ONLY — 5.000 mensagens aleatórias (vocabulário "Carros").
/// Idempotente: apaga e recria a conversa a cada execução.
/// Sem UI, sem SnackBar. Falha só loga.
Future<String?> seedCarros({
  required ConversationRepository repo,
  required AppDatabase db,
  String tituloAlvo = 'Carros (seed 5k)',
  int total = 5000,
  int seed = 42,
}) async {
  try {
    final uuid = const Uuid();
    final rnd = Random(seed);

    final existing = await (db.select(db.conversations)
          ..where((c) => c.titulo.equals(tituloAlvo)))
        .getSingleOrNull();
    if (existing != null) await repo.delete(existing.id);

    final conversation = await repo.create(titulo: tituloAlvo);
    final convId = conversation.id;

    const sujeitos = <String>[
      'Relâmpago McQueen', 'Mate', 'Doc Hudson', 'Sally', 'Luigi',
      'Guido', 'Ramone', 'Flo', 'Sargento', 'Filmore', 'Sheriff',
      'Chick Hicks', 'The King', 'Tex Dinoco', 'Mack', 'Kori',
      'Brent', 'Darrell', 'Van', 'Minny', 'Stanley', 'Red',
    ];
    const verbos = <String>[
      'disse', 'gritou', 'perguntou', 'respondeu', 'comentou',
      'lembrou', 'avisou', 'prometeu', 'duvidou', 'confirmou',
      'riu', 'suspirou', 'correu', 'parou', 'acelerou', 'virou',
    ];
    const complementos = <String>[
      'na pista poeirenta', 'no posto abandonado', 'na Route 66',
      'no estádio lotado', 'na garagem antiga', 'no deserto',
      'sob o sol forte', 'na curva fechada', 'na reta final',
      'durante a corrida', 'com o pneu cantando',
      'na bandeira quadriculada', 'em Radiator Springs',
      'na Califórnia', 'no pit stop', 'com a equipe inteira',
      'no pôr do sol', 'na chuva fina',
    ];
    const extras = <String>[
      'velocidade', 'amizade', 'respeito', 'ferrari', 'guincho',
      'pintura nova', 'combustível premium', 'ordem e disciplina',
      'paz e amor', 'campeão', 'lenda', 'contrato', 'transmissão',
      'corrida', 'pneu', 'motor', 'volta', 'pole position',
    ];

    String frase() {
      final n = 4 + rnd.nextInt(7);
      final parts = <String>[
        sujeitos[rnd.nextInt(sujeitos.length)],
        verbos[rnd.nextInt(verbos.length)],
        complementos[rnd.nextInt(complementos.length)],
        extras[rnd.nextInt(extras.length)],
      ];
      while (parts.length < n) {
        parts.add(extras[rnd.nextInt(extras.length)]);
      }
      final s = parts.join(' ');
      return '${s[0].toUpperCase()}${s.substring(1)}.';
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    await db.batch((batch) {
      for (var i = 0; i < total; i++) {
        batch.insert(
          db.messages,
          MessagesCompanion.insert(
            id: uuid.v4(),
            conversationId: convId,
            position: (i + 1) * 1000,
            tipo: const Value(MessageType.texto),
            conteudoTexto: Value(frase()),
            data: today.subtract(Duration(days: total - i)),
          ),
        );
      }
    });

    debugPrint('seedCarros: OK ($convId)');
    return convId;
  } catch (e, st) {
    debugPrint('seedCarros: falhou — $e\n$st');
    return null;
  }
}