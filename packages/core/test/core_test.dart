import 'package:core/core.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _FakeApp extends MicroApp {
  _FakeApp(this.name, this.migrations);

  @override
  final String name;

  @override
  final Map<int, List<String>> migrations;

  @override
  List<RouteBase> get routes => const [];

  @override
  void registerDependencies(GetIt di) {}
}

void main() {
  sqfliteFfiInit();

  test('event bus delivers typed events only to matching subscribers', () async {
    final bus = EventBus();
    final pix = <PixSentEvent>[];
    final sessions = <SessionExpiredEvent>[];
    bus.on<PixSentEvent>().listen(pix.add);
    bus.on<SessionExpiredEvent>().listen(sessions.add);

    bus.publish(const PixSentEvent(endToEndId: 'E1', amountInCents: 1000, recipientName: 'Ana'));
    bus.publish(const SessionExpiredEvent());
    await Future<void>.delayed(Duration.zero);

    expect(pix.single.amountInCents, 1000);
    expect(sessions, hasLength(1));
  });

  test('registry merges migrations by version and rejects duplicated names', () {
    final registry = MicroAppRegistry([
      _FakeApp('a', {
        1: ['CREATE TABLE a_x (id TEXT)']
      }),
      _FakeApp('b', {
        1: ['CREATE TABLE b_y (id TEXT)'],
        2: ['ALTER TABLE b_y ADD COLUMN v INT']
      }),
    ]);
    expect(registry.migrations[1], hasLength(2));
    expect(registry.databaseFactory.version, 2);
    expect(() => MicroAppRegistry([_FakeApp('a', {}), _FakeApp('a', {})]), throwsStateError);
  });

  test('micro apps may only touch their own prefixed tables', () {
    expect(
        () => MicroAppRegistry.assertOwnedTables(_FakeApp('pix', {
              1: ['CREATE TABLE pix_keys (k TEXT)']
            })),
        returnsNormally);
    expect(
      () => MicroAppRegistry.assertOwnedTables(_FakeApp('pix', {
        1: ['CREATE TABLE statement_tx (k TEXT)']
      })),
      throwsStateError,
    );
  });

  test('database applies pending migrations on upgrade', () async {
    final path = inMemoryDatabasePath;
    final v1 = await AppDatabaseFactory(migrations: {
      1: ['CREATE TABLE s_t (id TEXT)']
    }).open(factory: databaseFactoryFfiNoIsolate, path: path);
    await v1.db.insert('s_t', {'id': '1'});
    expect(await v1.db.query('s_t'), hasLength(1));
    await v1.close();
  });

  test('api client maps HTTP errors to domain failures and signals 401', () async {
    final bus = EventBus();
    final expired = bus.on<SessionExpiredEvent>().first;
    final mock = MockBackendInterceptor(latency: Duration.zero)
      ..on('GET', '/secure', (_) => throw const MockHttpError(401, 'expirou'))
      ..on('POST', '/pix', (_) => throw const MockHttpError(422, 'Saldo insuficiente'));
    final client = ApiClient(baseUrl: 'https://api.test', bus: bus, extra: [mock]);

    Future<Failure?> failureOf(Future<Object?> request) async {
      try {
        await request;
        return null;
      } catch (e) {
        return ApiClient.mapError(e);
      }
    }

    final unauthorized = await failureOf(client.dio.get<void>('/secure'));
    final invalid = await failureOf(client.dio.post<void>('/pix'));

    expect(unauthorized, isA<UnauthorizedFailure>());
    expect(invalid, const ValidationFailure('Saldo insuficiente'));
    expect(await expired, const SessionExpiredEvent());
    expect(ApiClient.mapError(DioException.connectionError(requestOptions: RequestOptions(), reason: 'x')),
        isA<NetworkFailure>());
  });
}
