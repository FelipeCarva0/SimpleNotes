import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'tables.dart';
import 'package:uuid/uuid.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [Conversations, Messages, Tags])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
        },
        onUpgrade: (m, from, to) async {
          if (from < 3) {
            
            await m.database.customStatement('DROP TABLE IF EXISTS blocks');
            await m.database.customStatement('DROP TABLE IF EXISTS lines');
            await m.database.customStatement('DROP TABLE IF EXISTS pages');
            await m.createTable(conversations);
            await m.createTable(messages);
            await m.createTable(tags);
          }

          // v3 -> v4: tags passam a pertencer a uma Conversa (RF04).
          // `from >= 3` evita rodar em quem veio da v2, cujas tabelas acabaram de
          // ser criadas já no formato novo pelo bloco acima.
          if (from >= 3 && from < 4) {
            await m.database.customStatement(
              'ALTER TABLE tags ADD COLUMN conversation_id TEXT '
              'REFERENCES conversations (id)',
            );

            // Cada par (tag, conversa) em uso vira uma tag própria da conversa.
            final pairs = await m.database.customSelect(
              'SELECT DISTINCT tag_id, conversation_id FROM messages '
              'WHERE tag_id IS NOT NULL',
            ).get();

            const uuid = Uuid();
            for (final r in pairs) {
              final oldTagId = r.read<String>('tag_id');
              final convId = r.read<String>('conversation_id');
              final newId = uuid.v4();

              await m.database.customStatement(
                'INSERT INTO tags (id, nome, cor, conversation_id) '
                'SELECT ?, nome, cor, ? FROM tags WHERE id = ?',
                [newId, convId, oldTagId],
              );
              await m.database.customStatement(
                'UPDATE messages SET tag_id = ? WHERE tag_id = ? AND conversation_id = ?',
                [newId, oldTagId, convId],
              );
            }

            // Sobraram só as tags antigas (sem conversa): nenhuma mensagem aponta mais para elas.
            await m.database.customStatement(
              'DELETE FROM tags WHERE conversation_id IS NULL',
            );
          }

        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    // Nome de arquivo também rebatizado (era 'secure_notes.sqlite'); como a
    // migração acima já é destrutiva, não há motivo para manter o nome
    // antigo do bloco de notas.
    final file = File(p.join(dbFolder.path, 'arquivo.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
