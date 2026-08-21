// providers/page_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'block_providers.dart';
import '../repositories/page_repository.dart';
import '../models/page.dart';

final pageRepositoryProvider = Provider<PageRepository>(
  (ref) => PageRepository(ref.watch(appDatabaseProvider)),
);

/// null = páginas fora de qualquer bloco (nível raiz)
final pagesInBlockProvider =
    StreamProvider.family<List<NotePage>, String?>((ref, blockId) {
  return ref.watch(pageRepositoryProvider).watchPagesInBlock(blockId);
});