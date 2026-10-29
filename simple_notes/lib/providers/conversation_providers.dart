import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import '../repositories/conversation_repository.dart';
import '../models/conversation.dart';
import '../models/message.dart';
import '../storage/media_storage.dart';
import '../services/attachment_service.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) => AppDatabase());

final mediaStorageProvider = Provider<MediaStorage>((ref) => MediaStorage());

final conversationRepositoryProvider = Provider<ConversationRepository>(
  (ref) => ConversationRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(mediaStorageProvider),
  ),
);

final attachmentServiceProvider = Provider<AttachmentService>((ref) {
  final service = AttachmentService();
  ref.onDispose(service.dispose);
  return service;
});

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

/// Mensagens de uma Conversa (RF02, RF03), ordenadas por `position` — usado
/// pela `ChatScreen` a partir da Sprint 1. `.family` porque cada Conversa
/// tem seu próprio stream; sem `autoDispose` porque o widget que o observa
/// (`ChatScreen`) já está com escopo de vida igual ao da tela.
final messagesStreamProvider =
    StreamProvider.family<List<Message>, String>((ref, conversationId) {
  return ref.watch(conversationRepositoryProvider).watchMessages(conversationId);
});

/// Notifica a UI quando o conjunto de conversas desbloqueadas muda, para que
/// a Home re-renderize o cadeado e o `messagesStreamProvider` seja reexecutado
/// (o repositório decifra na hora de entregar; a UI só precisa saber que
/// mudou).
final conversationUnlockTickProvider = StreamProvider<int>((ref) {
  // Um contador simples que a UI pode observar. Quem chama `lock`/`unlock`
  // no repositório incrementa este estado via `ref.read(...)` — mas para
  // manter o repositório puro (sem Riverpod), a UI usa `ref.invalidate` ou
  // `ref.read` + `setState` local (ver Bloco 3).
  //
  // Este provider fica como ponto de extensão. Por enquanto devolve 0.
  return Stream<int>.value(0);
});

