// Utilities for quick add transaction.

import 'package:jaayko/domain/categories/entities/category.dart';

import '../widgets/type_selector.dart';

TxKind? mapTypeEntryToKind(String? t) {
  switch ((t ?? '').toUpperCase()) {
    case 'DEBIT':
      return TxKind.debit;
    case 'CREDIT':
      return TxKind.credit;
    case 'DEBT':
      return TxKind.debt;
    case 'REMBOURSEMENT':
      return TxKind.remboursement;
    case 'PRET':
      return TxKind.pret;
    default:
      return null;
  }
}

int parseAmountToCents(String v) {
  final s = v.replaceAll(RegExp(r'\s'), '').replaceAll(',', '.');
  final d = double.tryParse(s) ?? 0;
  return (d * 100).round();
}

List<Category> filterCategoriesByKind(
  List<Category> all,
  TxKind kind,
  String query,
) {
  String? wanted;
  if (kind == TxKind.debit) wanted = 'DEBIT';
  if (kind == TxKind.credit || kind == TxKind.debt) wanted = 'CREDIT';
  if (wanted == null) return const [];
  final base = all.where((c) => c.typeEntry == wanted);
  if (query.trim().isEmpty) return base.toList();
  final q = query.toLowerCase().trim();
  return base
      .where(
        (c) =>
            c.code.toLowerCase().contains(q) ||
            (c.description ?? '').toLowerCase().contains(q),
      )
      .toList();
}

Category? findDefaultCategoryForProducts(List<Category> all, TxKind kind) {
  String? desiredType;
  if (kind == TxKind.debit) desiredType = 'DEBIT';
  if (kind == TxKind.credit || kind == TxKind.debt) desiredType = 'CREDIT';
  if (desiredType == null) return null;

  final preferCodes = kind == TxKind.debit
      ? <String>['ACHAT', 'ACHATS', 'PURCHASE', 'PURCHASES']
      : <String>['VENTE', 'VENTES', 'SALE', 'SALES'];

  final list = all.where((c) => c.typeEntry == desiredType).toList();

  for (final pref in preferCodes) {
    final hit = list.where((c) => c.code.toUpperCase() == pref);
    if (hit.isNotEmpty) return hit.first;
  }

  final containsAny = kind == TxKind.debit
      ? <String>['ACHAT', 'PURCHASE', 'ACHATS']
      : <String>['VENTE', 'SALE', 'VENTES', 'SALES'];

  for (final c in list) {
    final codeU = c.code.toUpperCase();
    final descU = (c.description ?? '').toUpperCase();
    final ok = containsAny.any((k) => codeU.contains(k) || descU.contains(k));
    if (ok) return c;
  }
  return list.isNotEmpty ? list.first : null;
}
