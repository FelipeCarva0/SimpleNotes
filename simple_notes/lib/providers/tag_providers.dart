import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/tag.dart';
import '../repositories/tag_repository.dart';
import 'conversation_providers.dart' show appDatabaseProvider;
import 'package:drift/drift.dart';

final tagRepositoryProvider = Provider<TagRepository>(
  (ref) => TagRepository(ref.watch(appDatabaseProvider)),
);

/// Todas as Tags, em ordem alfabética, atualizando ao vivo. A UI monta um
/// `Map<String, Tag>` a partir dela para resolver a tag de cada mensagem.
final tagsStreamProvider = StreamProvider.family<List<Tag>, String>(
  (ref, conversationId) =>
      ref.watch(tagRepositoryProvider).watchByConversation(conversationId),
);

/// Quantas mensagens usam cada Tag (tagId -> contagem), ao vivo.
/// Tags sem nenhuma mensagem não aparecem no mapa (leia como 0).
final tagUsageCountsProvider = StreamProvider<Map<String, int>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final count = db.messages.id.count();

  final query = db.selectOnly(db.messages)
    ..addColumns([db.messages.tagId, count])
    ..where(db.messages.tagId.isNotNull())
    ..groupBy([db.messages.tagId]);

  return query.watch().map((rows) => {
        for (final r in rows) r.read(db.messages.tagId)!: r.read(count) ?? 0,
      });
});