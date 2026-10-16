import 'package:flutter/material.dart' show Icons;
import 'package:core/core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import 'data/pix_data.dart';
import 'domain/pix.dart';
import 'presentation/pix_cubit.dart';
import 'presentation/pix_page.dart';

class PixMicroApp extends MicroApp {
  static const route = '/pix';

  /// Demo account balance shared with the fake backend.
  static int Function() balance = () => 843217;
  static void Function(int cents, String recipient, String id) onDebit = (_, __, ___) {};

  @override
  String get name => 'pix';

  @override
  MicroAppEntry get entry => const MicroAppEntry(label: 'Pix', icon: Icons.pix, initialRoute: route);

  @override
  Map<int, List<String>> get migrations => PixContactsDataSource.migrations;

  @override
  List<RouteBase> get routes => [
        GoRoute(
          path: route,
          // A fresh cubit (and idempotency key) every time the flow is opened.
          builder: (_, __) => BlocProvider(create: (_) => PixCubit(GetIt.I()), child: const PixPage()),
        ),
      ];

  @override
  void registerDependencies(GetIt di) {
    di
      ..registerLazySingleton(() => PixRemoteDataSource(di<ApiClient>().dio))
      ..registerLazySingleton(() => PixContactsDataSource(di.database.db))
      ..registerLazySingleton<PixRepository>(() => PixRepositoryImpl(di(), di()))
      ..registerFactory(() => SendPix(di(), di()));

    final processed = <String, Map<String, Object>>{};
    di<MockBackendInterceptor>().on('POST', '/v1/pix/transfers', (request) {
      final key = request.headers['Idempotency-Key'] as String;
      // Idempotent fake server: same key → same receipt, no second debit.
      return processed.putIfAbsent(key, () {
        final cents = (request.data as Map)['amountInCents'] as int;
        if (cents > balance()) throw const MockHttpError(422, 'Saldo insuficiente.');
        final id = 'E${DateTime.now().millisecondsSinceEpoch}';
        onDebit(cents, 'Bruno Lima', id);
        return {'endToEndId': id, 'amountInCents': cents, 'recipientName': 'Bruno Lima'};
      });
    });
  }
}
