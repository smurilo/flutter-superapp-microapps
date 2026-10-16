import 'package:bloc_test/bloc_test.dart';
import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:micro_pix/src/domain/pix.dart';
import 'package:micro_pix/src/presentation/pix_cubit.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepository extends Mock implements PixRepository {}

void main() {
  setUpAll(() => registerFallbackValue(const EmailKey('x@y.z')));

  test('detects and validates every PIX key type', () {
    expect(PixKey.parse('529.982.247-25'), const CpfKey('52998224725'));
    expect(PixKey.parse('11.222.333/0001-81'), const CnpjKey('11222333000181'));
    expect(PixKey.parse(' Ana@Banco.com '), const EmailKey('ana@banco.com'));
    expect(PixKey.parse('+55 (82) 99999-0000'), const PhoneKey('+5582999990000'));
    expect(PixKey.parse('123e4567-e89b-12d3-a456-426614174000'), isA<RandomKey>());
    expect(PixKey.parse('111.111.111-11'), isNull);
    expect(PixKey.parse('529.982.247-24'), isNull);
  });

  group('SendPix use case', () {
    late _MockRepository repo;
    late EventBus bus;
    const receipt = PixReceipt(endToEndId: 'E1', amountInCents: 5000, recipientName: 'Bruno');

    setUp(() {
      repo = _MockRepository();
      bus = EventBus();
      when(() => repo.send(
          key: any(named: 'key'),
          amountInCents: any(named: 'amountInCents'),
          idempotencyKey: any(named: 'idempotencyKey'))).thenAnswer((_) async => const Success(receipt));
    });

    test('publishes PixSentEvent so other micro apps can react', () async {
      final events = bus.on<PixSentEvent>().first;
      await SendPix(repo, bus, now: () => DateTime(2026, 3, 2, 10))(
          key: const EmailKey('b@x.com'), amountInCents: 5000, idempotencyKey: 'k');
      expect(await events, const PixSentEvent(endToEndId: 'E1', amountInCents: 5000, recipientName: 'Bruno'));
    });

    test('enforces the night limit without calling the server', () async {
      final result = await SendPix(repo, bus, now: () => DateTime(2026, 3, 2, 22))(
        key: const EmailKey('b@x.com'),
        amountInCents: 150000,
        idempotencyKey: 'k',
      );
      expect(result.fold((f) => f, (_) => null), isA<ValidationFailure>());
      verifyNever(() => repo.send(
          key: any(named: 'key'),
          amountInCents: any(named: 'amountInCents'),
          idempotencyKey: any(named: 'idempotencyKey')));
    });
  });

  group('PixCubit', () {
    final repo = _MockRepository();
    final keys = <String>[];

    blocTest<PixCubit, PixState>(
      'retry after failure reuses the same idempotency key',
      setUp: () {
        var calls = 0;
        when(() => repo.send(
            key: any(named: 'key'),
            amountInCents: any(named: 'amountInCents'),
            idempotencyKey: any(named: 'idempotencyKey'))).thenAnswer((inv) async {
          keys.add(inv.namedArguments[#idempotencyKey] as String);
          return ++calls == 1
              ? const Error(NetworkFailure())
              : const Success(PixReceipt(endToEndId: 'E1', amountInCents: 5000, recipientName: 'Bruno'));
        });
      },
      build: () {
        var n = 0;
        return PixCubit(SendPix(repo, EventBus(), now: () => DateTime(2026, 3, 2, 10)), idGenerator: () => 'id-${n++}');
      },
      act: (cubit) async {
        cubit
          ..keyChanged('529.982.247-25')
          ..amountChanged('50,00');
        await cubit.submit();
        await cubit.submit();
      },
      verify: (cubit) {
        expect(keys, ['id-0', 'id-0']);
        expect(cubit.state.receipt?.amountInCents, 5000);
      },
    );

    blocTest<PixCubit, PixState>(
      'shows inline validation errors',
      build: () => PixCubit(SendPix(repo, EventBus())),
      act: (cubit) => cubit
        ..keyChanged('ana@')
        ..amountChanged('abc'),
      verify: (cubit) {
        expect(cubit.state.keyError, 'Chave Pix inválida');
        expect(cubit.state.amountError, 'Valor inválido');
        expect(cubit.state.canSubmit, isFalse);
      },
    );
  });
}
