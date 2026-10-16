import 'package:core/core.dart';
import 'package:dio/dio.dart';
import 'package:sqflite/sqflite.dart' hide Transaction;

import '../domain/statement.dart';

// ── Data layer: DTO mapping, remote (REST) and local (SQLite) data sources, repository implementation.

class TransactionModel {
  const TransactionModel({required this.id, required this.title, required this.amountInCents, required this.dateIso});

  factory TransactionModel.fromJson(Map<String, dynamic> json) => TransactionModel(
        id: json['id'] as String,
        title: json['description'] as String,
        amountInCents: json['amountInCents'] as int,
        dateIso: json['dateTime'] as String,
      );

  factory TransactionModel.fromRow(Map<String, Object?> row) => TransactionModel(
        id: row['id']! as String,
        title: row['title']! as String,
        amountInCents: row['amount_cents']! as int,
        dateIso: row['date']! as String,
      );

  final String id;
  final String title;
  final int amountInCents;
  final String dateIso;

  Map<String, Object?> toRow() => {'id': id, 'title': title, 'amount_cents': amountInCents, 'date': dateIso};

  Transaction toEntity() =>
      Transaction(id: id, title: title, amountInCents: amountInCents, date: DateTime.parse(dateIso));
}

class StatementRemoteDataSource {
  const StatementRemoteDataSource(this._dio);

  final Dio _dio;

  Future<(Account, List<TransactionModel>)> fetch() async {
    final (account, transactions) = await (
      _dio.get<Map<String, dynamic>>('/v1/account'),
      _dio.get<List<dynamic>>('/v1/transactions'),
    ).wait; // both requests in parallel
    final a = account.data!;
    return (
      Account(holder: a['holder'] as String, balanceInCents: a['balanceInCents'] as int),
      transactions.data!.cast<Map<String, dynamic>>().map(TransactionModel.fromJson).toList(),
    );
  }
}

class StatementLocalDataSource {
  const StatementLocalDataSource(this._db);

  final Database _db;

  static const migrations = {
    1: [
      'CREATE TABLE statement_transactions (id TEXT PRIMARY KEY, title TEXT NOT NULL, amount_cents INTEGER NOT NULL, date TEXT NOT NULL)',
      'CREATE INDEX statement_tx_date ON statement_transactions (date DESC)',
      'CREATE TABLE statement_account (id INTEGER PRIMARY KEY CHECK (id = 1), holder TEXT NOT NULL, balance_cents INTEGER NOT NULL)',
    ],
  };

  Future<void> save(Account account, List<TransactionModel> transactions) => _db.transaction((txn) async {
        await txn.insert(
          'statement_account',
          {'id': 1, 'holder': account.holder, 'balance_cents': account.balanceInCents},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        final batch = txn.batch();
        for (final t in transactions) {
          batch.insert('statement_transactions', t.toRow(), conflictAlgorithm: ConflictAlgorithm.replace);
        }
        await batch.commit(noResult: true);
      });

  Future<(Account, List<TransactionModel>)?> read() async {
    final rows = await _db.query('statement_account');
    if (rows.isEmpty) return null;
    final txs = await _db.query('statement_transactions', orderBy: 'date DESC', limit: 200);
    return (
      Account(holder: rows.first['holder']! as String, balanceInCents: rows.first['balance_cents']! as int),
      txs.map(TransactionModel.fromRow).toList(),
    );
  }
}

/// Offline-first: network result is persisted; on failure the cached statement is returned as stale.
class StatementRepositoryImpl implements StatementRepository {
  StatementRepositoryImpl(this._remote, this._local);

  final StatementRemoteDataSource _remote;
  final StatementLocalDataSource _local;

  @override
  Future<Result<Statement>> getStatement({bool forceRefresh = false}) async {
    try {
      final (account, models) = await _remote.fetch();
      await _local.save(account, models);
      return Success(
          Statement(account: account, transactions: models.map((m) => m.toEntity()).toList(), isStale: false));
    } catch (error) {
      final failure = ApiClient.mapError(error);
      final cached = await _local.read();
      if (cached == null || failure is UnauthorizedFailure) return Error(failure);
      final (account, models) = cached;
      return Success(
          Statement(account: account, transactions: models.map((m) => m.toEntity()).toList(), isStale: true));
    }
  }
}
