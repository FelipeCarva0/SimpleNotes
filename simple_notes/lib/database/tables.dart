import 'package:drift/drift.dart';

@DataClassName('BlockRow')
class Blocks extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  DateTimeColumn get createdAt => dateTime()();
  BoolColumn get isEncrypted => boolean().withDefault(const Constant(false))();
  TextColumn get passwordHash => text().nullable()();
  TextColumn get salt => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('PageRow')
class Pages extends Table {
  TextColumn get id => text()();
  TextColumn get blockId => text().nullable().references(Blocks, #id)();
  TextColumn get title => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get isEncrypted => boolean().withDefault(const Constant(false))();
  TextColumn get passwordHash => text().nullable()();
  TextColumn get salt => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('LineRow')
class Lines extends Table {
  TextColumn get id => text()();
  TextColumn get pageId => text().references(Pages, #id)();
  IntColumn get position => integer()();
  TextColumn get content => text()();
  DateTimeColumn get date => dateTime()();
  BoolColumn get isDateManuallyEdited =>
      boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}