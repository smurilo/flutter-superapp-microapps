import 'package:core/core.dart';
import 'package:get_it/get_it.dart';
import 'package:micro_pix/micro_pix.dart';
import 'package:micro_statement/micro_statement.dart';
import 'package:sqflite/sqflite.dart';

/// Composition root: the only place that knows which micro apps exist.
/// Adding a feature = adding one line to [microApps].
List<MicroApp> microApps() => [StatementMicroApp(), PixMicroApp()];

Future<MicroAppRegistry> bootstrap(
    {GetIt? container, DatabaseFactory? dbFactory, String? dbPath, Duration? latency}) async {
  final di = container ?? GetIt.I;
  final registry = MicroAppRegistry(microApps());
  registry.microApps.forEach(MicroAppRegistry.assertOwnedTables);

  final bus = EventBus();
  final mock = MockBackendInterceptor(latency: latency ?? const Duration(milliseconds: 600));
  di
    ..registerSingleton(bus)
    ..registerSingleton(mock)
    ..registerSingleton(ApiClient(baseUrl: 'https://api.superapp-exemplo.com.br', bus: bus, extra: [mock]))
    ..registerSingleton(await registry.databaseFactory.open(factory: dbFactory, path: dbPath));

  _wireDemoLedger();
  registry.register(di);
  return registry;
}

/// Demo-only: lets the fake Pix endpoint debit the fake statement backend.
void _wireDemoLedger() {
  PixMicroApp.balance = () => FakeLedger.balance;
  PixMicroApp.onDebit = (cents, recipient, id) {
    FakeLedger.balance -= cents;
    FakeLedger.extra.insert(0, {
      'id': id,
      'description': 'PIX enviado — $recipient',
      'amountInCents': -cents,
      'dateTime': DateTime.now().toIso8601String(),
    });
  };
}
