import 'package:core/core.dart';
import 'package:dio/dio.dart';
import 'package:sqflite/sqflite.dart';

import '../domain/pix.dart';

class PixRemoteDataSource {
  const PixRemoteDataSource(this._dio);

  final Dio _dio;

  Future<PixReceipt> send(PixKey key, int amountInCents, String idempotencyKey) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/v1/pix/transfers',
      data: {'key': key.value, 'keyType': key.label, 'amountInCents': amountInCents},
      options: Options(headers: {'Idempotency-Key': idempotencyKey}),
    );
    final json = response.data!;
    return PixReceipt(
      endToEndId: json['endToEndId'] as String,
      amountInCents: json['amountInCents'] as int,
      recipientName: json['recipientName'] as String,
    );
  }
}

/// Recent recipients stored locally for one-tap repeat transfers.
class PixContactsDataSource {
  const PixContactsDataSource(this._db);

  final Database _db;

  static const migrations = {
    1: ['CREATE TABLE pix_recent_contacts (key TEXT PRIMARY KEY, name TEXT NOT NULL, last_used TEXT NOT NULL)'],
  };

  Future<void> remember(String key, String name, DateTime when) => _db.insert(
        'pix_recent_contacts',
        {'key': key, 'name': name, 'last_used': when.toIso8601String()},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  Future<List<({String key, String name})>> recent({int limit = 5}) async {
    final rows = await _db.query('pix_recent_contacts', orderBy: 'last_used DESC', limit: limit);
    return [for (final r in rows) (key: r['key']! as String, name: r['name']! as String)];
  }
}

class PixRepositoryImpl implements PixRepository {
  PixRepositoryImpl(this._remote, this._contacts);

  final PixRemoteDataSource _remote;
  final PixContactsDataSource _contacts;

  @override
  Future<Result<PixReceipt>> send(
      {required PixKey key, required int amountInCents, required String idempotencyKey}) async {
    try {
      final receipt = await _remote.send(key, amountInCents, idempotencyKey);
      await _contacts.remember(key.value, receipt.recipientName, DateTime.now());
      return Success(receipt);
    } catch (e) {
      return Error(ApiClient.mapError(e));
    }
  }
}
