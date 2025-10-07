// lib/presentation/features/transactions/detail/remote/transaction_sync_service.dart
// Service isolé pour POST/PUT/DELETE + maj du repo local.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'package:money_pulse/domain/transactions/entities/transaction_entry.dart';
import 'package:money_pulse/presentation/app/providers.dart'; // syncHeaderBuilderProvider
import '../../../../../sync/infrastructure/sync_headers_provider.dart';
import '../../providers/transaction_list_providers.dart';
import 'package:money_pulse/presentation/features/transactions/providers/transaction_detail_providers.dart';

class TransactionSyncService {
  static const String _baseUrl = 'http://127.0.0.1:8095';

  static Uri _u(String path, [Map<String, String>? qp]) =>
      Uri.parse('$_baseUrl$path').replace(queryParameters: qp);

  static double _toRemoteAmount(int cents) => cents / 100.0;

  static Map<String, dynamic> _toRemoteBody(TransactionEntry e) {
    return {
      'remoteId': e.remoteId,
      'localId': e.id,
      'code': e.code,
      'description': e.description,
      'amount': _toRemoteAmount(e.amount),
      'typeEntry': e.typeEntry,
      'dateTransaction': e.dateTransaction.toUtc().toIso8601String(),
      'status': e.status,
      'entityName': e.entityName,
      'entityId': e.entityId,
      'accountId': e.accountId,
      'syncAt': DateTime.now().toUtc().toIso8601String(),
      'category': e.categoryId,
      'company': e.companyId,
      'customer': e.customerId,
      'debt': "",
    };
  }

  static Future<void> saveOrUpdateRemote(
    BuildContext context,
    WidgetRef ref,
    TransactionEntry e,
  ) async {
    try {
      final body = jsonEncode(_toRemoteBody(e));
      final headers = ref.read(syncHeaderBuilderProvider)()
        ..putIfAbsent('Content-Type', () => 'application/json')
        ..putIfAbsent('accept', () => 'application/json');

      late http.Response res;
      final remoteId = (e.remoteId ?? '').trim();

      if (remoteId.isEmpty) {
        res = await http.post(
          _u('/api/v1/commands/transaction'),
          headers: headers,
          body: body,
        );
      } else {
        res = await http.put(
          _u('/api/v1/commands/transaction/$remoteId'),
          headers: headers,
          body: body,
        );
      }

      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw Exception('HTTP ${res.statusCode}: ${res.body}');
      }

      String? newRemoteId;
      try {
        final m = jsonDecode(res.body);
        if (m is Map && (m['remoteId'] ?? m['id']) != null) {
          newRemoteId = '${m['remoteId'] ?? m['id']}';
        }
      } catch (_) {}

      final repo = ref.read(transactionRepoProvider);
      await repo.update(
        e.copyWith(
          remoteId: newRemoteId ?? e.remoteId,
          isDirty: false,
          updatedAt: DateTime.now(),
        ),
      );

      await ref.read(transactionsProvider.notifier).load();
      await ref.read(balanceProvider.notifier).load();
      ref.invalidate(transactionListItemsProvider);

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            remoteId.isEmpty
                ? 'Transaction enregistrée sur le serveur'
                : 'Transaction mise à jour sur le serveur',
          ),
        ),
      );
    } catch (err) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur de synchronisation: $err')),
      );
    }
  }

  static Future<void> deleteRemoteThenLocal(
    BuildContext context,
    WidgetRef ref,
    TransactionEntry e,
  ) async {
    try {
      final remoteId = (e.remoteId ?? '').trim();
      if (remoteId.isNotEmpty) {
        final headers = ref.read(syncHeaderBuilderProvider)()
          ..putIfAbsent('Content-Type', () => 'application/json')
          ..putIfAbsent('accept', () => 'application/json');

        final res = await http.delete(
          _u('/api/v1/commands/transaction/$remoteId'),
          headers: headers,
        );
        if (!((res.statusCode >= 200 && res.statusCode < 300) ||
            res.statusCode == 404)) {
          throw Exception('HTTP ${res.statusCode}: ${res.body}');
        }
      }

      await ref.read(transactionRepoProvider).softDelete(e.id);

      await ref.read(transactionsProvider.notifier).load();
      await ref.read(balanceProvider.notifier).load();
      ref.invalidate(transactionListItemsProvider);

      if (!context.mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Transaction supprimée')));
    } catch (err) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Suppression échouée: $err')));
    }
  }
}
