import 'package:uuid/uuid.dart';
import 'package:sqflite/sqflite.dart'; // for ConflictAlgorithm (if you need it)
import 'package:money_pulse/infrastructure/db/app_database.dart';
import 'package:money_pulse/domain/accounts/repositories/account_repository.dart';

/// Simple atomic checkout: creates one transaction_entry + many transaction_item,
/// and updates account balance accordingly.
class CheckoutCartUseCase {
  final AppDatabase db;
  final AccountRepository accountRepo;
  CheckoutCartUseCase(this.db, this.accountRepo);

  /// [typeEntry] 'CREDIT' = sale (income), 'DEBIT' = purchase (expense)
  /// [lines] : [{ 'productId': String?, 'label': String, 'quantity': int, 'unitPrice': int }]
  Future<String> execute({
    required String typeEntry,
    String? accountId,
    String? categoryId,
    String? description,
    DateTime? when,
    required List<Map<String, Object?>> lines,
  }) async {
    final t = typeEntry.toUpperCase();
    if (t != 'CREDIT' && t != 'DEBIT') {
      throw ArgumentError.value(
        typeEntry,
        'typeEntry',
        "must be 'CREDIT' or 'DEBIT'",
      );
    }
    if (lines.isEmpty) {
      throw ArgumentError('lines cannot be empty');
    }

    final acc = accountId != null
        ? await accountRepo.findById(accountId)
        : await accountRepo.findDefault();
    if (acc == null) {
      throw StateError('No default account found');
    }

    // Defensive parsing of lines
    int _asInt(Object? v) => (v is int) ? v : int.tryParse('${v ?? 0}') ?? 0;

    final total = lines.fold<int>(0, (p, e) {
      final q = _asInt(e['quantity']);
      final up = _asInt(e['unitPrice']);
      return p + (q < 0 ? 0 : q) * (up < 0 ? 0 : up);
    });

    final now = DateTime.now();
    final date = when ?? now;
    final txId = const Uuid().v4();

    await db.tx((txn) async {
      // 1) Insert transaction_entry
      await txn.insert('transaction_entry', {
        'id': txId,
        'remoteId': null,
        'code': null,
        'description': description,
        'amount': total,
        'typeEntry': t,
        'dateTransaction': date.toIso8601String(),
        'status': null,
        'entityName': null,
        'entityId': null,
        'accountId': acc.id,
        'categoryId': categoryId,
        'createdAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
        'deletedAt': null,
        'syncAt': null,
        'version': 0,
        'isDirty': 1,
      });

      // 2) Insert items
      for (final l in lines) {
        final itemId = const Uuid().v4();
        final qty = _asInt(l['quantity']);
        final up = _asInt(l['unitPrice']);
        final tot = (qty < 0 ? 0 : qty) * (up < 0 ? 0 : up);
        await txn.insert('transaction_item', {
          'id': itemId,
          'transactionId': txId,
          'productId': l['productId'],
          'label': (l['label'] ?? '').toString(),
          'quantity': qty < 0 ? 0 : qty,
          'unitPrice': up < 0 ? 0 : up,
          'total': tot,
          'notes': null,
          'createdAt': now.toIso8601String(),
          'updatedAt': now.toIso8601String(),
          'deletedAt': null,
          'syncAt': null,
          'version': 0,
          'isDirty': 1,
        });
      }

      // 3) Update account balance
      final newBalance = t == 'CREDIT'
          ? acc.balance + total
          : acc.balance - total;
      await txn.update(
        'account',
        {
          'balance': newBalance,
          'updatedAt': now.toIso8601String(),
          'isDirty': 1,
          'version': acc.version + 1,
        },
        where: 'id=?',
        whereArgs: [acc.id],
      );

      // 4) Upsert into change_log (single statement)
      final logId = const Uuid().v4();
      await txn.rawInsert(
        '''
        INSERT INTO change_log(
          id, entityTable, entityId, operation, payload, status, attempts, error, createdAt, updatedAt, processedAt
        )
        VALUES(?,?,?,?,?,?,?,?,?,?,?)
        ON CONFLICT(entityTable, entityId, status) DO UPDATE SET
          operation=excluded.operation,
          payload=excluded.payload,
          updatedAt=excluded.updatedAt
      ''',
        [
          logId,
          'transaction_entry',
          txId,
          'INSERT',
          null,
          'PENDING',
          0,
          null,
          now.toIso8601String(),
          now.toIso8601String(),
          null,
        ],
      );
    });

    return txId;
  }
}
