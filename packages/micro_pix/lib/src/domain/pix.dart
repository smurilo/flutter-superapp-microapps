import 'package:core/core.dart';
import 'package:equatable/equatable.dart';

/// PIX key value object: validated on construction, so an invalid key can't exist in the domain.
sealed class PixKey extends Equatable {
  const PixKey(this.value);

  final String value;

  String get label;

  @override
  List<Object?> get props => [runtimeType, value];

  static PixKey? parse(String raw) {
    final input = raw.trim();
    final digits = input.replaceAll(RegExp(r'\D'), '');
    if (RegExp(r'^[\w.+-]+@[\w-]+(\.[\w-]+)+$').hasMatch(input)) return EmailKey(input.toLowerCase());
    if (RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$').hasMatch(input.toLowerCase())) {
      return RandomKey(input.toLowerCase());
    }
    if (input.startsWith('+') && RegExp(r'^55\d{10,11}$').hasMatch(digits)) return PhoneKey('+$digits');
    if (digits.length == 11 && _validCpf(digits)) return CpfKey(digits);
    if (digits.length == 14 && _validCnpj(digits)) return CnpjKey(digits);
    return null;
  }

  static bool _validCpf(String cpf) {
    final n = cpf.split('').map(int.parse).toList();
    if (n.toSet().length == 1) return false;
    int dv(int len) {
      var sum = 0;
      for (var i = 0; i < len; i++) {
        sum += n[i] * (len + 1 - i);
      }
      final r = (sum * 10) % 11;
      return r == 10 ? 0 : r;
    }

    return dv(9) == n[9] && dv(10) == n[10];
  }

  static bool _validCnpj(String cnpj) {
    final n = cnpj.split('').map(int.parse).toList();
    if (n.toSet().length == 1) return false;
    int dv(List<int> w) {
      var sum = 0;
      for (var i = 0; i < w.length; i++) {
        sum += n[i] * w[i];
      }
      final r = sum % 11;
      return r < 2 ? 0 : 11 - r;
    }

    return dv([5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2]) == n[12] && dv([6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2]) == n[13];
  }
}

final class CpfKey extends PixKey {
  const CpfKey(super.value);
  @override
  String get label => 'CPF';
}

final class CnpjKey extends PixKey {
  const CnpjKey(super.value);
  @override
  String get label => 'CNPJ';
}

final class EmailKey extends PixKey {
  const EmailKey(super.value);
  @override
  String get label => 'E-mail';
}

final class PhoneKey extends PixKey {
  const PhoneKey(super.value);
  @override
  String get label => 'Celular';
}

final class RandomKey extends PixKey {
  const RandomKey(super.value);
  @override
  String get label => 'Chave aleatória';
}

class PixReceipt extends Equatable {
  const PixReceipt({required this.endToEndId, required this.amountInCents, required this.recipientName});

  final String endToEndId;
  final int amountInCents;
  final String recipientName;

  @override
  List<Object?> get props => [endToEndId, amountInCents, recipientName];
}

abstract interface class PixRepository {
  Future<Result<PixReceipt>> send({required PixKey key, required int amountInCents, required String idempotencyKey});
}

/// Use case: validates limits, sends the Pix and notifies other micro apps.
class SendPix {
  SendPix(this._repository, this._bus, {this.nightLimitInCents = 100000, DateTime Function()? now})
      : _now = now ?? DateTime.now;

  final PixRepository _repository;
  final EventBus _bus;
  final int nightLimitInCents;
  final DateTime Function() _now;

  Future<Result<PixReceipt>> call(
      {required PixKey key, required int amountInCents, required String idempotencyKey}) async {
    if (amountInCents <= 0) return const Error(ValidationFailure('Informe um valor maior que zero.'));
    final hour = _now().hour;
    // Central Bank rule: reduced limit between 20h and 6h.
    if ((hour >= 20 || hour < 6) && amountInCents > nightLimitInCents) {
      return const Error(ValidationFailure('Acima do limite noturno de R\$ 1.000,00.'));
    }
    final result = await _repository.send(key: key, amountInCents: amountInCents, idempotencyKey: idempotencyKey);
    if (result case Success(:final value)) {
      _bus.publish(PixSentEvent(
          endToEndId: value.endToEndId, amountInCents: value.amountInCents, recipientName: value.recipientName));
    }
    return result;
  }
}
