// TransactionDetailView: shows a transaction details with items, category, company and customer when present, plus share/receipt actions.
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:money_pulse/domain/transactions/entities/transaction_entry.dart';
import 'package:money_pulse/presentation/app/providers.dart';
import 'package:money_pulse/presentation/features/transactions/providers/transaction_list_providers.dart';
import 'package:money_pulse/presentation/features/transactions/providers/transaction_detail_providers.dart';
import 'package:money_pulse/presentation/features/transactions/transaction_form_sheet.dart';
import 'package:money_pulse/presentation/shared/formatters.dart';
import 'package:money_pulse/presentation/widgets/right_drawer.dart';

import '../../companies/providers/company_detail_providers.dart';
import '../../customers/providers/customer_detail_providers.dart';
import '../receipt/receipt_preview_page.dart';
import '../receipt/receipt_controller.dart';
import 'package:money_pulse/infrastructure/receipts/receipt_pdf_renderer.dart';

class TransactionDetailView extends ConsumerWidget {
  final TransactionEntry entry;

  const TransactionDetailView({super.key, required this.entry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDebit = entry.typeEntry == 'DEBIT';
    final sign = isDebit ? '-' : '+';
    final amount = Formatters.amountFromCents(entry.amount);
    final dateLabel = Formatters.dateFull(entry.dateTransaction);

    final catAsync = ref.watch(categoryByIdProvider(entry.categoryId));
    final itemsAsync = ref.watch(transactionItemsProvider(entry.id));

    final companyAsync = entry.companyId == null
        ? const AsyncValue.data(null)
        : ref.watch(companyByIdProvider(entry.companyId!));
    final customerAsync = entry.customerId == null
        ? const AsyncValue.data(null)
        : ref.watch(customerByIdProvider(entry.customerId!));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Détails de la transaction'),
        actions: [
          IconButton(
            tooltip: 'Partager le reçu',
            icon: const Icon(Icons.ios_share),
            onPressed: () async {
              final d = await ref.read(receiptDataProvider(entry.id).future);
              final formatAmount = (int cents) =>
                  Formatters.amountFromCents(cents);
              final formatDate = (DateTime dt) => Formatters.dateFull(dt);
              final bytes = await ReceiptPdfRenderer(
                amount: formatAmount,
                date: formatDate,
              ).render(d);
              final dir = await getTemporaryDirectory();
              final path = '${dir.path}/recu_${entry.id}.pdf';
              final f = File(path);
              await f.writeAsBytes(bytes, flush: true);
              await Share.shareXFiles([XFile(path)], text: 'Reçu');
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _InfoTile(title: 'Montant', value: '$sign$amount'),
          _InfoTile(title: 'Type', value: isDebit ? 'Dépense' : 'Revenu'),
          _InfoTile(title: 'Date et heure', value: dateLabel),
          _InfoTile(title: 'Description', value: entry.description ?? '—'),
          _InfoTile(title: 'Code', value: entry.code ?? '—'),
          _InfoTile(title: 'Identifiant', value: entry.id),

          catAsync.when(
            data: (cat) => cat == null
                ? const SizedBox.shrink()
                : _InfoTile(
                    title: 'Catégorie',
                    value: _categoryLabel(cat.code, cat.description),
                  ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),

          companyAsync.when(
            data: (co) => co == null
                ? const SizedBox.shrink()
                : _InfoTile(
                    title: 'Société',
                    value: _companyLabel(co.name, co.code),
                  ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),

          customerAsync.when(
            data: (cu) => cu == null
                ? const SizedBox.shrink()
                : _InfoTile(
                    title: 'Client',
                    value: _customerLabel(cu.fullName, cu.email, cu.phone),
                  ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),

          itemsAsync.when(
            data: (items) => items.isEmpty
                ? const SizedBox.shrink()
                : _ItemsSection(
                    title: 'Articles',
                    items: items
                        .map(
                          (it) => _ItemRowData(
                            label: it.label ?? '—',
                            quantity: it.quantity,
                            unitPrice: it.unitPrice,
                            total: it.total,
                          ),
                        )
                        .toList(),
                    accent: isDebit ? Colors.red : Colors.green,
                  ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final ok = await showRightDrawer<bool>(
                      context,
                      child: TransactionFormSheet(entry: entry),
                      widthFraction: 0.86,
                      heightFraction: 0.96,
                    );
                    if (ok == true) {
                      await ref.read(transactionsProvider.notifier).load();
                      await ref.read(balanceProvider.notifier).load();
                      ref.invalidate(transactionListItemsProvider);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Transaction mise à jour'),
                          ),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Modifier'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            ReceiptPreviewPage(transactionId: entry.id),
                      ),
                    );
                  },
                  icon: const Icon(Icons.receipt_long),
                  label: const Text('Reçu'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (dCtx) => AlertDialog(
                        title: const Text('Confirmer la suppression'),
                        content: const Text('Supprimer cette transaction ?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(dCtx, false),
                            child: const Text('Annuler'),
                          ),
                          FilledButton.tonal(
                            onPressed: () => Navigator.pop(dCtx, true),
                            child: const Text('Supprimer'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await ref
                          .read(transactionRepoProvider)
                          .softDelete(entry.id);
                      await ref.read(transactionsProvider.notifier).load();
                      await ref.read(balanceProvider.notifier).load();
                      ref.invalidate(transactionListItemsProvider);
                      if (context.mounted) {
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Transaction supprimée'),
                          ),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Supprimer'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _categoryLabel(String? code, String? description) {
    final c = (code ?? '').trim();
    final d = (description ?? '').trim();
    if (c.isNotEmpty && d.isNotEmpty) return '$d ($c)';
    if (d.isNotEmpty) return d;
    if (c.isNotEmpty) return c;
    return '—';
  }

  static String _companyLabel(String? name, String? code) {
    final n = (name ?? '').trim();
    final c = (code ?? '').trim();
    if (n.isNotEmpty && c.isNotEmpty) return '$n ($c)';
    if (n.isNotEmpty) return n;
    if (c.isNotEmpty) return c;
    return '—';
  }

  static String _customerLabel(String fullName, String? email, String? phone) {
    final e = (email ?? '').trim();
    final p = (phone ?? '').trim();
    if (e.isNotEmpty && p.isNotEmpty) return '$fullName • $e • $p';
    if (e.isNotEmpty) return '$fullName • $e';
    if (p.isNotEmpty) return '$fullName • $p';
    return fullName.isEmpty ? '—' : fullName;
  }
}

class _InfoTile extends StatelessWidget {
  final String title;
  final String value;

  const _InfoTile({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      title: Text(title),
      subtitle: Text(value),
      contentPadding: EdgeInsets.zero,
    );
  }
}

class _ItemRowData {
  final String label;
  final int quantity;
  final int unitPrice;
  final int total;

  _ItemRowData({
    required this.label,
    required this.quantity,
    required this.unitPrice,
    required this.total,
  });
}

class _ItemsSection extends StatelessWidget {
  final String title;
  final List<_ItemRowData> items;
  final Color accent;

  const _ItemsSection({
    required this.title,
    required this.items,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          children: [
            ListTile(title: Text(title), trailing: Text('${items.length}')),
            const Divider(height: 1),
            ...items.map(
              (it) => ListTile(
                dense: true,
                title: Text(
                  it.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${it.quantity} × ${Formatters.amountFromCents(it.unitPrice)}',
                ),
                trailing: Text(
                  Formatters.amountFromCents(it.total),
                  style: TextStyle(color: accent, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
