// lib/presentation/features/transactions/detail/transaction_detail_view.dart
// TransactionDetailView: shows a transaction with items, parties, share/receipt actions.
// Dépend sur TransactionSyncService pour la sync distante (POST/PUT/DELETE).

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:money_pulse/domain/transactions/entities/transaction_entry.dart';
import 'package:money_pulse/presentation/shared/formatters.dart';
import 'package:money_pulse/presentation/widgets/right_drawer.dart';

import 'package:money_pulse/infrastructure/receipts/receipt_pdf_renderer.dart';

import '../../../app/providers.dart';
import '../detail/remote/transaction_sync_service.dart';
import '../detail/widgets/header_card.dart';
import '../detail/widgets/info_tile.dart';
import '../detail/widgets/items_section.dart';
import '../detail/widgets/parties_section.dart';
import '../detail/widgets/pills.dart';
import '../detail/widgets/section_card.dart';
import '../providers/transaction_list_providers.dart';
import '../providers/transaction_detail_providers.dart';
import '../../companies/providers/company_detail_providers.dart';
import '../../customers/providers/customer_detail_providers.dart';
import '../../transactions/transaction_form_sheet.dart';
import '../receipt/receipt_controller.dart';
import '../receipt/receipt_preview_page.dart';
import 'items_section.dart' hide ItemsSection;

class TransactionDetailView extends ConsumerWidget {
  final TransactionEntry entry;
  const TransactionDetailView({super.key, required this.entry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tone = toneForType(context, entry.typeEntry);
    final isDebit = entry.typeEntry.toUpperCase() == 'DEBIT';
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

    final hasRemote = (entry.remoteId ?? '').trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Détails de la transaction'),
        actions: [
          IconButton(
            tooltip: (entry.remoteId ?? '').isEmpty
                ? 'Enregistrer sur le serveur'
                : 'Mettre à jour sur le serveur',
            icon: const Icon(Icons.cloud_upload_outlined),
            onPressed: () =>
                TransactionSyncService.saveOrUpdateRemote(context, ref, entry),
          ),
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
          HeaderCard(
            tone: tone,
            amountText: '$sign$amount',
            dateText: dateLabel,
            status: entry.status,
            accountless: (entry.accountId ?? '').isEmpty,
          ),
          const SizedBox(height: 12),

          SectionCard(
            title: 'Informations',
            children: [
              InfoTile(
                icon: Icons.notes_outlined,
                title: 'Description',
                value: (entry.description ?? '').trim().isNotEmpty
                    ? entry.description!
                    : '—',
              ),
              InfoTile(
                icon: Icons.tag_outlined,
                title: 'Code',
                value: (entry.code ?? '').trim().isNotEmpty ? entry.code! : '—',
              ),
              InfoTile(
                icon: Icons.account_balance_wallet_outlined,
                title: 'Compte',
                value: entry.accountId ?? '—',
              ),
              InfoTile(
                icon: Icons.fingerprint,
                title: 'Identifiant',
                value: entry.id,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Tooltip(
                      message: hasRemote
                          ? 'Synchronisé (remoteId présent)'
                          : 'Non synchronisé (pas de remoteId)',
                      child: Icon(
                        hasRemote
                            ? Icons.cloud_done_outlined
                            : Icons.cloud_off_outlined,
                        color: hasRemote
                            ? Theme.of(context).colorScheme.tertiary
                            : Theme.of(context).colorScheme.outline,
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      tooltip: 'Copier',
                      icon: const Icon(Icons.copy),
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: entry.id));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('ID copié')),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),

          catAsync.when(
            data: (cat) => cat == null
                ? const SizedBox.shrink()
                : SectionCard(
                    title: 'Catégorie',
                    children: [
                      InfoTile(
                        icon: Icons.category_outlined,
                        title: 'Catégorie',
                        value: _categoryLabel(cat.code, cat.description),
                      ),
                    ],
                  ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),

          PartiesSection(
            companyAsync: companyAsync,
            customerAsync: customerAsync,
          ),

          itemsAsync.when(
            data: (items) => items.isEmpty
                ? const SizedBox.shrink()
                : ItemsSection(
                    title: 'Articles',
                    items: items
                        .map(
                          (it) => ItemRowData(
                            label: it.label ?? '—',
                            quantity: it.quantity,
                            unitPrice: it.unitPrice,
                            total: it.total,
                          ),
                        )
                        .toList(),
                    accent: tone.color,
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
                      await TransactionSyncService.deleteRemoteThenLocal(
                        context,
                        ref,
                        entry,
                      );
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
}
