import 'package:core/core.dart';
import 'package:equatable/equatable.dart';

// ── Domain layer: entities, repository contract and use cases. No Flutter, Dio or SQLite here.

class Account extends Equatable {
  const Account({required this.holder, required this.balanceInCents});

  final String holder;
  final int balanceInCents;

  @override
  List<Object?> get props => [holder, balanceInCents];
}

class Transaction extends Equatable {
  const Transaction({required this.id, required this.title, required this.amountInCents, required this.date});

  final String id;
  final String title;
  final int amountInCents;
  final DateTime date;

  bool get isCredit => amountInCents > 0;

  @override
  List<Object?> get props => [id, title, amountInCents, date];
}

class Statement extends Equatable {
  const Statement({required this.account, required this.transactions, required this.isStale});

  final Account account;
  final List<Transaction> transactions;

  /// True when served from the local database because the network failed.
  final bool isStale;

  @override
  List<Object?> get props => [account, transactions, isStale];
}

abstract interface class StatementRepository {
  Future<Result<Statement>> getStatement({bool forceRefresh = false});
}

class GetStatement {
  const GetStatement(this._repository);

  final StatementRepository _repository;

  Future<Result<Statement>> call({bool forceRefresh = false}) async {
    final result = await _repository.getStatement(forceRefresh: forceRefresh);
    // Business rule kept in the domain: newest first.
    return result.fold(
      Error.new,
      (s) => Success(
        Statement(
          account: s.account,
          transactions: [...s.transactions]..sort((a, b) => b.date.compareTo(a.date)),
          isStale: s.isStale,
        ),
      ),
    );
  }
}
