import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import '../repositories/conversation_repository.dart';
import '../models/conversation.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) => AppDatabase());

final conversationRepositoryProvider = Provider<ConversationRepository>(
  (ref) => ConversationRepository(ref.watch(appDatabaseProvider)),
);

/// Lista da tela inicial (RF06), ordenada por atividade mais recente.
final conversationsStreamProvider = StreamProvider<List<Conversation>>(
  (ref) => ref.watch(conversationRepositoryProvider).watchAll(),
);

/// autoDispose: descarta o cache ao sair da tela de chat, garantindo que
/// reabrir a Conversa sempre busca o estado mais recente do banco.
final conversationByIdProvider =
    FutureProvider.autoDispose.family<Conversation?, String>((ref, id) {
  return ref.watch(conversationRepositoryProvider).getById(id);
});
