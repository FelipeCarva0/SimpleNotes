// providers/block_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import '../repositories/block_repository.dart';
import '../models/block.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) => AppDatabase());

final blockRepositoryProvider = Provider<BlockRepository>(
  (ref) => BlockRepository(ref.watch(appDatabaseProvider)),
);

final blocksStreamProvider = StreamProvider<List<Block>>(
  (ref) => ref.watch(blockRepositoryProvider).watchAll(),
);