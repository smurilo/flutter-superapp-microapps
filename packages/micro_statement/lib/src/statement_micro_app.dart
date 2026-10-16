import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import 'data/statement_data.dart';
import 'domain/statement.dart';
import 'presentation/statement_cubit.dart';
import 'presentation/statement_page.dart';

/// Composition root of the statement micro app: the only file the shell knows about.
class StatementMicroApp extends MicroApp {
  static const route = '/extrato';

  @override
  String get name => 'statement';

  @override
  MicroAppEntry get entry => const MicroAppEntry(label: 'Extrato', icon: Icons.receipt_long, initialRoute: route);

  @override
  Map<int, List<String>> get migrations => StatementLocalDataSource.migrations;

  @override
  List<RouteBase> get routes => [
        GoRoute(
          path: route,
          builder: (_, __) => BlocProvider.value(value: GetIt.I<StatementCubit>(), child: const StatementPage()),
        ),
      ];

  @override
  void registerDependencies(GetIt di) {
    di
      ..registerLazySingleton(() => StatementRemoteDataSource(di<ApiClient>().dio))
      ..registerLazySingleton(() => StatementLocalDataSource(di.database.db))
      ..registerLazySingleton<StatementRepository>(() => StatementRepositoryImpl(di(), di()))
      ..registerLazySingleton(() => GetStatement(di()))
      ..registerLazySingleton(() => StatementCubit(di())..load());

    registerFakeEndpoints(di<MockBackendInterceptor>());
  }

  /// Reacts to Pix sent by another micro app without importing it.
  @override
  void listenEvents(GetIt di) {
    di<EventBus>().on<PixSentEvent>().listen((_) => di<StatementCubit>().load(forceRefresh: true));
  }

  static void registerFakeEndpoints(MockBackendInterceptor mock) {
    final now = DateTime.now();
    String at(int daysAgo, int hour) => DateTime(now.year, now.month, now.day - daysAgo, hour).toIso8601String();
    mock
      ..on('GET', '/v1/account', (_) => {'holder': 'Ana Souza', 'balanceInCents': FakeLedger.balance})
      ..on(
        'GET',
        '/v1/transactions',
        (_) => [
          ...FakeLedger.extra,
          {'id': 't1', 'description': 'Salário', 'amountInCents': 750000, 'dateTime': at(0, 8)},
          {'id': 't2', 'description': 'Supermercado Bom Preço', 'amountInCents': -28743, 'dateTime': at(1, 19)},
          {'id': 't3', 'description': 'Conta de energia', 'amountInCents': -19820, 'dateTime': at(1, 9)},
          {'id': 't4', 'description': 'PIX recebido — Bruno', 'amountInCents': 15000, 'dateTime': at(3, 12)},
        ],
      );
  }
}

/// Shared in-memory "server state" for the demo backend (Pix debits appear in the statement).
abstract final class FakeLedger {
  static int balance = 843217;
  static final List<Map<String, Object>> extra = [];

  @visibleForTesting
  static void reset() {
    balance = 843217;
    extra.clear();
  }
}
