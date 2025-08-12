import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_pulse/domain/receipts/entities/receipt_models.dart';
import 'package:money_pulse/presentation/app/providers.dart';
import 'package:money_pulse/presentation/shared/formatters.dart';

final receiptDataProvider = FutureProvider.family<ReceiptData, String>((
  ref,
  txnId,
) async {
  final txnRepo = ref.read(transactionRepoProvider);
  final itemRepo = ref.read(transactionItemRepoProvider);
  final catRepo = ref.read(categoryRepoProvider);
  final accRepo = ref.read(accountRepoProvider);

  final entry = await txnRepo.findById(txnId);
  if (entry == null) throw StateError('Transaction introuvable');

  final items = await itemRepo.findByTransaction(txnId);
  final cat = entry.categoryId == null
      ? null
      : await catRepo.findById(entry.categoryId!);
  final acc = entry.accountId == null
      ? null
      : await accRepo.findById(entry.accountId!);

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

  return ReceiptData(
    id: entry.id,
    title: entry.typeEntry == 'CREDIT' ? 'Reçu de vente' : 'Reçu de dépense',
    storeName: null,
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
  );
});

String fmtAmount(int cents) => Formatters.amountFromCents(cents);
String fmtDate(DateTime dt) => Formatters.dateFull(dt);
