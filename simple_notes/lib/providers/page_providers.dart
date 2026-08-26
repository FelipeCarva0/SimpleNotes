import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'block_providers.dart';
import '../repositories/page_repository.dart';
import '../models/page.dart';

final pageRepositoryProvider = Provider<PageRepository>(
  (ref) => PageRepository(ref.watch(appDatabaseProvider)),
);

final pagesInBlockProvider =
    StreamProvider.family<List<NotePage>, String?>((ref, blockId) {
  return ref.watch(pageRepositoryProvider).watchPagesInBlock(blockId);
});

/// autoDispose: descarta o cache ao sair da tela, garantindo que reabrir a
/// página sempre busca o estado mais recente do banco.
final pageByIdProvider = FutureProvider.autoDispose.family<NotePage?, String>((ref, id) {
  return ref.watch(pageRepositoryProvider).getPage(id);
});