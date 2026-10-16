import 'package:flutter/widgets.dart' show IconData;
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../database/app_database.dart';

/// Contract every micro app implements to plug into the shell.
///
/// A micro app is a self-contained feature (own domain, data and presentation layers)
/// that can be developed, tested and released by an independent team.
abstract class MicroApp {
  /// Unique name, also used as prefix for its database tables.
  String get name;

  /// Entry shown in the shell's bottom navigation, or null for flows opened only by other routes.
  MicroAppEntry? get entry => null;

  /// Routes contributed to the global router.
  List<RouteBase> get routes;

  /// Database migrations owned by this micro app (version → SQL statements).
  Map<int, List<String>> get migrations => const {};

  /// Registers this micro app's dependencies into the shared container.
  void registerDependencies(GetIt di);

  /// Subscribes to events published by other micro apps (decoupled communication).
  void listenEvents(GetIt di) {}
}

class MicroAppEntry {
  const MicroAppEntry({required this.label, required this.icon, required this.initialRoute});

  final String label;

  /// Must be a const icon (e.g. `Icons.pix`) so release builds can tree-shake the icon font.
  final IconData icon;
  final String initialRoute;
}

/// Helper available to micro apps to read the shared database.
extension MicroAppDb on GetIt {
  AppDatabase get database => get<AppDatabase>();
}
