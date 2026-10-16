import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Thin wrapper over the single SQLite file shared by micro apps (each owns prefixed tables).
class AppDatabase {
  AppDatabase(this.db);

  final Database db;

  Future<void> close() => db.close();
}

class AppDatabaseFactory {
  AppDatabaseFactory({required this.migrations});

  final Map<int, List<String>> migrations;

  int get version => migrations.isEmpty ? 1 : migrations.keys.reduce((a, b) => a > b ? a : b);

  /// Opens (or upgrades) the database, running every pending migration in order.
  Future<AppDatabase> open({DatabaseFactory? factory, String? path}) async {
    final dbFactory = factory ?? databaseFactory;
    final dbPath = path ?? p.join(await dbFactory.getDatabasesPath(), 'superapp.db');
    final db = await dbFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: version,
        onCreate: (db, v) => _migrate(db, 0, v),
        onUpgrade: _migrate,
      ),
    );
    return AppDatabase(db);
  }

  Future<void> _migrate(Database db, int from, int to) async {
    final batch = db.batch();
    for (var v = from + 1; v <= to; v++) {
      for (final sql in migrations[v] ?? const <String>[]) {
        batch.execute(sql);
      }
    }
    await batch.commit(noResult: true);
  }
}
