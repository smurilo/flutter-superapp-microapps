import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../database/app_database.dart';
import 'micro_app.dart';

/// Composes micro apps: merges routes and migrations, wires DI and event listeners.
class MicroAppRegistry {
  MicroAppRegistry(this.microApps) {
    final names = microApps.map((m) => m.name).toList();
    if (names.toSet().length != names.length) {
      throw StateError('Micro apps com nomes duplicados: $names');
    }
  }

  final List<MicroApp> microApps;

  List<RouteBase> get routes => [for (final m in microApps) ...m.routes];

  List<MicroAppEntry> get entries => [
        for (final m in microApps)
          if (m.entry != null) m.entry!
      ];

  /// Migrations of all micro apps, grouped by version, applied in a single schema version.
  Map<int, List<String>> get migrations {
    final merged = <int, List<String>>{};
    for (final m in microApps) {
      m.migrations.forEach((version, statements) => merged.putIfAbsent(version, () => []).addAll(statements));
    }
    return merged;
  }

  void register(GetIt di) {
    for (final m in microApps) {
      m.registerDependencies(di);
    }
    for (final m in microApps) {
      m.listenEvents(di);
    }
  }

  /// Migrations must touch only tables prefixed with the micro app name, so teams never collide.
  static void assertOwnedTables(MicroApp app) {
    final pattern =
        RegExp(r'(?:create table|alter table|create index \w+ on)\s+(?:if not exists\s+)?(\w+)', caseSensitive: false);
    for (final sql in app.migrations.values.expand((s) => s)) {
      for (final match in pattern.allMatches(sql)) {
        final table = match.group(1)!;
        if (!table.startsWith('${app.name}_')) {
          throw StateError('Micro app "${app.name}" tentou criar/alterar a tabela "$table"');
        }
      }
    }
  }

  AppDatabaseFactory get databaseFactory => AppDatabaseFactory(migrations: migrations);
}
