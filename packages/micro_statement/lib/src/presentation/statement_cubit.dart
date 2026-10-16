import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/statement.dart';

sealed class StatementState extends Equatable {
  const StatementState();

  @override
  List<Object?> get props => const [];
}

final class StatementLoading extends StatementState {
  const StatementLoading();
}

final class StatementLoaded extends StatementState {
  const StatementLoaded(this.statement, {this.refreshing = false});

  final Statement statement;
  final bool refreshing;

  /// Transactions grouped by calendar day, keeping the newest-first order.
  Map<DateTime, List<Transaction>> get byDay {
    final map = <DateTime, List<Transaction>>{};
    for (final t in statement.transactions) {
      map.putIfAbsent(DateTime(t.date.year, t.date.month, t.date.day), () => []).add(t);
    }
    return map;
  }

  @override
  List<Object?> get props => [statement, refreshing];
}

final class StatementFailure extends StatementState {
  const StatementFailure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

class StatementCubit extends Cubit<StatementState> {
  StatementCubit(this._getStatement) : super(const StatementLoading());

  final GetStatement _getStatement;

  Future<void> load({bool forceRefresh = false}) async {
    final current = state;
    // Keep showing data while refreshing instead of flashing a spinner.
    emit(current is StatementLoaded ? StatementLoaded(current.statement, refreshing: true) : const StatementLoading());
    final result = await _getStatement(forceRefresh: forceRefresh);
    if (isClosed) return;
    emit(result.fold((f) => StatementFailure(f.message), StatementLoaded.new));
  }
}
