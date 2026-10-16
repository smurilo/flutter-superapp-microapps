import 'dart:math';

import 'package:design_system/design_system.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/pix.dart';

class PixState extends Equatable {
  const PixState({
    this.keyInput = '',
    this.amountInput = '',
    this.key,
    this.keyError,
    this.amountError,
    this.sending = false,
    this.receipt,
    this.error,
  });

  final String keyInput;
  final String amountInput;
  final PixKey? key;
  final String? keyError;
  final String? amountError;
  final bool sending;
  final PixReceipt? receipt;
  final String? error;

  int? get amountInCents => Money.parse(amountInput);

  bool get canSubmit => key != null && amountInCents != null && amountError == null && !sending;

  PixState copyWith({
    String? keyInput,
    String? amountInput,
    PixKey? Function()? key,
    String? Function()? keyError,
    String? Function()? amountError,
    bool? sending,
    PixReceipt? Function()? receipt,
    String? Function()? error,
  }) =>
      PixState(
        keyInput: keyInput ?? this.keyInput,
        amountInput: amountInput ?? this.amountInput,
        key: key != null ? key() : this.key,
        keyError: keyError != null ? keyError() : this.keyError,
        amountError: amountError != null ? amountError() : this.amountError,
        sending: sending ?? this.sending,
        receipt: receipt != null ? receipt() : this.receipt,
        error: error != null ? error() : this.error,
      );

  @override
  List<Object?> get props => [keyInput, amountInput, key, keyError, amountError, sending, receipt, error];
}

class PixCubit extends Cubit<PixState> {
  PixCubit(this._sendPix, {String Function()? idGenerator})
      : _newId = idGenerator ?? _uuid,
        super(const PixState()) {
    _idempotencyKey = _newId();
  }

  final SendPix _sendPix;
  final String Function() _newId;

  /// Reused on retry: a timeout followed by "try again" never sends the money twice.
  late String _idempotencyKey;

  void keyChanged(String input) {
    final key = PixKey.parse(input);
    emit(
      state.copyWith(
        keyInput: input,
        key: () => key,
        keyError: () => input.isNotEmpty && key == null ? 'Chave Pix inválida' : null,
      ),
    );
  }

  void amountChanged(String input) {
    final cents = Money.parse(input);
    emit(
      state.copyWith(
        amountInput: input,
        amountError: () => input.isNotEmpty && (cents == null || cents <= 0) ? 'Valor inválido' : null,
      ),
    );
  }

  Future<void> submit() async {
    if (!state.canSubmit) return;
    emit(state.copyWith(sending: true, error: () => null));
    final result =
        await _sendPix(key: state.key!, amountInCents: state.amountInCents!, idempotencyKey: _idempotencyKey);
    result.fold(
      (failure) => emit(state.copyWith(sending: false, error: () => failure.message)),
      (receipt) {
        _idempotencyKey = _newId();
        emit(state.copyWith(sending: false, receipt: () => receipt));
      },
    );
  }

  void reset() => emit(const PixState());

  static String _uuid() {
    final r = Random.secure();
    return List.generate(16, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  }
}
