// lib/presentation/features/transactions/receipt/receipt_controller.dart
// Receipt controller: builds ReceiptData for a transaction including company and customer info.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_pulse/domain/receipts/entities/receipt_models.dart';
import 'package:money_pulse/presentation/app/providers.dart';
import 'package:money_pulse/presentation/shared/formatters.dart';
import 'package:money_pulse/presentation/app/providers/company_repo_provider.dart';
import 'package:money_pulse/presentation/app/providers/customer_repo_provider.dart';

String _titleForType(String type) {
  final t = type.toUpperCase().trim();
  if (t == 'CREDIT') return 'Reçu de vente';
  if (t == 'DEBIT') return 'Reçu de dépense';
  if (t.contains('DETTE')) return 'Reçu de dette';
  if (t.startsWith('REMBOUR')) return 'Reçu de remboursement';
  if (t.startsWith('TRANSF')) return 'Reçu de transfert';
  if (t == 'AVOIR') return 'Reçu d’avoir';
  if (t == 'VERSEMENT') return 'Reçu de versement';
  return 'Reçu';
}

final receiptDataProvider = FutureProvider.family<ReceiptData, String>((
  ref,
  txnId,
) async {
  final txnRepo = ref.read(transactionRepoProvider);
  final itemRepo = ref.read(transactionItemRepoProvider);
  final catRepo = ref.read(categoryRepoProvider);
  final accRepo = ref.read(accountRepoProvider);
  final coRepo = ref.read(companyRepoProvider);
  final cuRepo = ref.read(customerRepoProvider);

  final entry = await txnRepo.findById(txnId);
  if (entry == null) {
    throw StateError('Transaction introuvable');
  }

  final items = await itemRepo.findByTransaction(txnId);
  final cat = entry.categoryId == null
      ? null
      : await catRepo.findById(entry.categoryId!);
  final acc = entry.accountId == null
      ? null
      : await accRepo.findById(entry.accountId!);
  final co = entry.companyId == null
      ? null
      : await coRepo.findById(entry.companyId!);
  final cu = entry.customerId == null
      ? null
      : await cuRepo.findById(entry.customerId!);

  String joinParts(Iterable<String?> parts) => parts
      .where((e) => (e ?? '').trim().isNotEmpty)
      .map((e) => e!.trim())
      .join(', ');

  final lines = items
      .map(
        (e) => ReceiptLine(
          label: e.label ?? '—',
          quantity: e.quantity,
          unitPrice: e.unitPrice,
          total: e.total,
        ),
      )
      .toList();

  final subtotal = lines.fold<int>(0, (p, e) => p + e.total);
  final total = entry.amount;

  final companyAddress = co == null
      ? null
      : joinParts([
          co.addressLine1,
          co.addressLine2,
          joinParts([co.postalCode, co.city]),
          joinParts([co.region, co.country]),
        ]);

  return ReceiptData(
    id: entry.id,
    title: _titleForType(entry.typeEntry), // 👈 titre adapté au type
    storeName: co?.name,
    accountLabel: (acc?.description ?? acc?.code) ?? 'Compte',
    categoryLabel: cat == null
        ? null
        : ((cat.description ?? cat.code) ?? 'Catégorie'),
    typeEntry: entry.typeEntry,
    currency: acc?.currency ?? 'FCFA',
    date: entry.dateTransaction,
    lines: lines,
    subtotal: subtotal,
    total: total,
    footerNote: 'À bientôt',
    companyName: co?.name,
    companyCode: co?.code,
    companyPhone: co?.phone,
    companyEmail: co?.email,
    companyTaxId: co?.taxId,
    companyAddress: companyAddress,
    customerName: cu?.fullName,
    customerPhone: cu?.phone,
    customerEmail: cu?.email,
  );
});

String fmtAmount(int cents) => Formatters.amountFromCents(cents);
String fmtDate(DateTime dt) => Formatters.dateFull(dt);
