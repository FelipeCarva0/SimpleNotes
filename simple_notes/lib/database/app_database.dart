import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [Conversations, Messages, Tags])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
        },
        onUpgrade: (m, from, to) async {
          if (from < 3) {
            // v2 -> v3: pivot de "Bloco de Notas" para "Arquivo" (spec 5.1).
            //
            // A entidade Bloco já tinha sido removida do escopo funcional na
            // v4.0 da especificação, mas o schema físico (`blocks` e
            // `pages.block_id`) nunca chegou a ser limpo — essa migração
            // fecha essa dívida técnica junto com o pivot.
            //
            // Decisão: como o app ainda não foi publicado (sem usuários
            // reais dependendo de Páginas/Linhas em produção), tratamos esta
            // troca de schema como destrutiva por simplicidade, em vez de
            // escrever uma migração coluna a coluna. Se este código for
            // aplicado depois de o app já ter dados reais em campo,
            // substituir o bloco abaixo por uma migração que preserva
            // conteúdo (renomear tabelas/colunas existentes e popular os
            // novos campos via UPDATE) em vez de derrubar as tabelas.
            await m.database.customStatement('DROP TABLE IF EXISTS blocks');
            await m.database.customStatement('DROP TABLE IF EXISTS lines');
            await m.database.customStatement('DROP TABLE IF EXISTS pages');
            await m.createTable(conversations);
            await m.createTable(messages);
            await m.createTable(tags);
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
