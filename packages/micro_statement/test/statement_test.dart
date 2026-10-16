import 'package:bloc_test/bloc_test.dart';
import 'package:core/core.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:micro_statement/src/data/statement_data.dart';
import 'package:micro_statement/src/domain/statement.dart';
import 'package:micro_statement/src/presentation/statement_cubit.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' hide Transaction;

class _MockRemote extends Mock implements StatementRemoteDataSource {}

class _MockRepository extends Mock implements StatementRepository {}

void main() {
  sqfliteFfiInit();

  const account = Account(holder: 'Ana', balanceInCents: 1000);
  final models = [
    TransactionModel(id: 'a', title: 'Antiga', amountInCents: -100, dateIso: DateTime(2026, 3, 1, 9).toIso8601String()),
    TransactionModel(id: 'b', title: 'Nova', amountInCents: 500, dateIso: DateTime(2026, 3, 2, 10).toIso8601String()),
  ];

  late AppDatabase db;
  late StatementLocalDataSource local;
  late _MockRemote remote;

  setUp(() async {
    db = await AppDatabaseFactory(migrations: StatementLocalDataSource.migrations)
        .open(factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
    local = StatementLocalDataSource(db.db);
    remote = _MockRemote();
  });

  tearDown(() => db.close()); // closing destroys the in-memory database: each test starts clean

  group('offline-first repository', () {
    test('persists fresh data from the network', () async {
      when(() => remote.fetch()).thenAnswer((_) async => (account, models));

      final result = await StatementRepositoryImpl(remote, local).getStatement();

      expect(result.fold((_) => null, (s) => s.isStale), isFalse);
      expect((await local.read())!.$2, hasLength(2));
    });

    test('falls back to cached statement when offline', () async {
      await local.save(account, models);
      when(() => remote.fetch())
          .thenThrow(DioException.connectionError(requestOptions: RequestOptions(), reason: 'offline'));

      final result = await StatementRepositoryImpl(remote, local).getStatement();

      final statement = result.fold((_) => null, (s) => s)!;
      expect(statement.isStale, isTrue);
      expect(statement.account, account);
    });

    test('returns failure when offline and nothing cached', () async {
      when(() => remote.fetch())
          .thenThrow(DioException.connectionError(requestOptions: RequestOptions(), reason: 'offline'));
      final result = await StatementRepositoryImpl(remote, local).getStatement();
      expect(result.fold((f) => f, (_) => null), isA<NetworkFailure>());
    });
  });

  test('use case sorts newest first', () async {
    final repo = _MockRepository();
    when(() => repo.getStatement(forceRefresh: any(named: 'forceRefresh'))).thenAnswer(
      (_) async => Success(
        Statement(
          account: account,
          transactions: models.map((m) => m.toEntity()).toList(),
          isStale: false,
        ),
      ),
    );
    final result = await GetStatement(repo)();
    expect(result.fold((_) => null, (s) => s.transactions.map((t) => t.id).toList()), ['b', 'a']);
  });

  group('cubit', () {
    final repo = _MockRepository();
    final statement =
        Statement(account: account, transactions: models.map((m) => m.toEntity()).toList(), isStale: false);

    blocTest<StatementCubit, StatementState>(
      'loads then refreshes without dropping the visible data',
      setUp: () => when(() => repo.getStatement(forceRefresh: any(named: 'forceRefresh')))
          .thenAnswer((_) async => Success(statement)),
      build: () => StatementCubit(GetStatement(repo)),
      act: (cubit) async {
        await cubit.load();
        await cubit.load(forceRefresh: true);
      },
      expect: () => [
        const StatementLoading(),
        isA<StatementLoaded>().having((s) => s.byDay.length, 'days', 2),
        isA<StatementLoaded>().having((s) => s.refreshing, 'refreshing', true),
        isA<StatementLoaded>().having((s) => s.refreshing, 'refreshing', false),
      ],
    );

    blocTest<StatementCubit, StatementState>(
      'shows failure message',
      setUp: () => when(() => repo.getStatement(forceRefresh: any(named: 'forceRefresh')))
          .thenAnswer((_) async => const Error(ServerFailure())),
      build: () => StatementCubit(GetStatement(repo)),
      act: (cubit) => cubit.load(),
      expect: () => [const StatementLoading(), const StatementFailure('Serviço indisponível. Tente novamente.')],
    );
  });
}
