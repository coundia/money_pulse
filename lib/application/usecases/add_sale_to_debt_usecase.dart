// lib/application/use_cases/add_sale_to_debt_use_case.dart
//
// Use case to append a sale to a customer's OPEN debt.
// - UTC timestamps
// - Safe math (qty/unitPrice >= 0)
// - Creates transaction_entry (type=DEBT) + transaction_item rows
// - Creates OUT stock_movement per line
// - Updates stock_level (clamped >= 0) per product/company
// - Updates debt balance via repository + customer.balanceDebt
// - Logs all mutations with upsertChangeLogPending (no custom logger)

import 'package:uuid/uuid.dart';
import 'package:sqflite/sqflite.dart';

import 'package:money_pulse/infrastructure/db/app_database.dart';
import 'package:money_pulse/domain/debts/entities/debt.dart';
import 'package:money_pulse/domain/debts/repositories/debt_repository.dart';
import 'package:money_pulse/sync/infrastructure/change_log_helper.dart';

class AddSaleToDebtUseCase {
  final AppDatabase db;
  final DebtRepository debtRepo;
  AddSaleToDebtUseCase(this.db, this.debtRepo);

  String _nowUtcIso() => DateTime.now().toUtc().toIso8601String();
  int _asInt(Object? v) =>
      v is int ? v : (v is num ? v.toInt() : int.tryParse('${v ?? 0}') ?? 0);
  int _nzPos(int v) => v < 0 ? 0 : v;

  Future<String> execute({
    required String customerId,
    String? companyId,
    String? categoryId,
    String? description,
    required DateTime when,
    required List<Map<String, Object?>> lines,
  }) async {
    if (lines.isEmpty) {
      throw ArgumentError('lines cannot be empty');
    }

    final txId = const Uuid().v4();
    final whenIso = (when.isUtc ? when : when.toUtc()).toIso8601String();
    final nowIso = _nowUtcIso();

    int totalCents(List<Map<String, Object?>> ls) {
      var sum = 0;
      for (final e in ls) {
        final q = _nzPos(_asInt(e['quantity']));
        final u = _nzPos(_asInt(e['unitPrice']));
        sum += q * u;
      }
      return sum;
    }

    final total = totalCents(lines);

    await db.tx((txn) async {
      // Ensure OPEN debt for customer
      final Debt open = await debtRepo.upsertOpenForCustomerTx(txn, customerId);

      // ---- transaction_entry (DEBT) ----
      await txn.insert('transaction_entry', {
        'id': txId,
        'remoteId': null,
        'code': null,
        'description': description,
        'amount': total,
        'typeEntry': 'DEBT',
        'dateTransaction': whenIso,
        'status': 'DEBT',
        'entityName': 'CUSTOMER',
        'entityId': customerId,
        'accountId': null,
        'categoryId': categoryId,
        'companyId': companyId,
        'customerId': customerId,
        'debtId': open.id,
        'createdAt': nowIso,
        'updatedAt': nowIso,
        'deletedAt': null,
        'syncAt': null,
        'version': 0,
        'isDirty': 1,
      }, conflictAlgorithm: ConflictAlgorithm.abort);

      await upsertChangeLogPending(
        txn,
        entityTable: 'transaction_entry',
        entityId: txId,
        operation: 'INSERT',
      );

      // ---- transaction_item rows + stock_movement (OUT) per line ----
      for (final e in lines) {
        final itemId = const Uuid().v4();
        final qty = _nzPos(_asInt(e['quantity']));
        final unit = _nzPos(_asInt(e['unitPrice']));
        final tot = qty * unit;
        final productId = e['productId']?.toString();
        final label = e['label']?.toString();
        final unitId = e['unitId']?.toString();

        // Insert item
        await txn.insert('transaction_item', {
          'id': itemId,
          'transactionId': txId,
          'productId': productId,
          'label': label,
          'quantity': qty,
          'unitId': unitId,
          'unitPrice': unit,
          'total': tot,
          'notes': null,
          'createdAt': nowIso,
          'updatedAt': nowIso,
          'deletedAt': null,
          'syncAt': null,
          'version': 0,
          'isDirty': 1,
        }, conflictAlgorithm: ConflictAlgorithm.abort);

        await upsertChangeLogPending(
          txn,
          entityTable: 'transaction_item',
          entityId: itemId,
          operation: 'INSERT',
        );

        // Stock movement (OUT) for sell on debt → affects stock
        if ((companyId ?? '').isNotEmpty &&
            (productId ?? '').isNotEmpty &&
            qty > 0) {
          final mvtId = const Uuid().v4();
          await txn.insert('stock_movement', {
            'id': mvtId,
            'type_stock_movement': 'OUT',
            'quantity': qty,
            'companyId': companyId,
            'productVariantId': productId,
            'orderLineId': itemId,
            'discriminator': 'TXN',
            'createdAt': nowIso,
            'updatedAt': nowIso,
            'syncAt': null,
            'version': 0,
            'isDirty': 1,
            'remoteId': null,
            'localId': null,
          }, conflictAlgorithm: ConflictAlgorithm.abort);

          await upsertChangeLogPending(
            txn,
            entityTable: 'stock_movement',
            entityId: mvtId,
            operation: 'INSERT',
          );
        }
      }

      // ---- Aggregate & apply stock level adjustments (OUT) ----
      await _applyStockAdjustments(
        txn: txn,
        lines: lines,
        companyId: companyId,
        nowIso: nowIso,
      );

      // ---- Update debt balance (repository already logs change_log) ----
      final newBalance = open.balance + total;
      await debtRepo.updateBalanceTx(txn, open.id, newBalance);

      // ---- Update customer.balanceDebt and log ----
      await txn.rawUpdate(
        'UPDATE customer '
        'SET balanceDebt = CASE '
        '  WHEN COALESCE(balanceDebt,0) + ? < 0 THEN 0 '
        '  ELSE COALESCE(balanceDebt,0) + ? '
        'END, '
        'updatedAt=?, isDirty=1, version=COALESCE(version,0)+1 '
        'WHERE id=?',
        [total, total, nowIso, customerId],
      );

      await upsertChangeLogPending(
        txn,
        entityTable: 'customer',
        entityId: customerId,
        operation: 'UPDATE',
      );
    });

    return txId;
  }

  // Ensure a stock_level row exists for (productVariantId, companyId) and return its id + current onHand
  Future<(String id, int onHand)> _ensureLevelRow(
    Transaction txn, {
    required String productVariantId,
    required String companyId,
    required String nowIso,
  }) async {
    final r = await txn.rawQuery(
      'SELECT id, stockOnHand FROM stock_level WHERE productVariantId=? AND companyId=? LIMIT 1',
      [productVariantId, companyId],
    );
    if (r.isNotEmpty) {
      final id = (r.first['id'] as String?) ?? '';
      final on = (r.first['stockOnHand'] as int?) ?? 0;
      return (id, on);
    }

    final id = const Uuid().v4();
    await txn.insert('stock_level', {
      'id': id,
      'productVariantId': productVariantId,
      'companyId': companyId,
      'stockOnHand': 0,
      'stockAllocated': 0,
      'createdAt': nowIso,
      'updatedAt': nowIso,
      'version': 0,
      'isDirty': 1,
    }, conflictAlgorithm: ConflictAlgorithm.abort);

    await upsertChangeLogPending(
      txn,
      entityTable: 'stock_level',
      entityId: id,
      operation: 'INSERT',
    );

    return (id, 0);
  }

  Future<void> _applyStockAdjustments({
    required Transaction txn,
    required List<Map<String, Object?>> lines,
    required String? companyId,
    required String nowIso,
  }) async {
    final company = companyId ?? '';
    if (company.isEmpty) return;

    // Sum OUT quantities per product
    final Map<String, int> totalsByVariant = {};
    for (final e in lines) {
      final pid = e['productId']?.toString() ?? '';
      final qty = _nzPos(_asInt(e['quantity']));
      if (pid.isEmpty || qty <= 0) continue;
      totalsByVariant[pid] = (totalsByVariant[pid] ?? 0) + qty;
    }
    if (totalsByVariant.isEmpty) return;

    for (final entry in totalsByVariant.entries) {
      final pvId = entry.key;
      final dec = entry.value; // OUT => decrease

      final (idStock, onHand) = await _ensureLevelRow(
        txn,
        productVariantId: pvId,
        companyId: company,
        nowIso: nowIso,
      );

      final next = onHand - dec;
      final clamped = next < 0 ? 0 : next;

      await txn.rawUpdate(
        'UPDATE stock_level SET stockOnHand=?, updatedAt=?, isDirty=1, version=COALESCE(version,0)+1 WHERE id=?',
        [clamped, nowIso, idStock],
      );

      await upsertChangeLogPending(
        txn,
        entityTable: 'stock_level',
        entityId: idStock,
        operation: 'UPDATE',
      );
    }
  }
}
