// TransactionDetailView: shows a transaction details with items, category, company and
// customer when present, plus share/receipt actions.
// Uses dynamic sync headers (syncHeaderBuilderProvider) for POST/PUT/DELETE.

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
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
import '../../customers/customer_marketplace_repo.dart';
import '../../customers/providers/customer_detail_providers.dart';
import '../receipt/receipt_preview_page.dart';
import '../receipt/receipt_controller.dart';
import 'package:money_pulse/infrastructure/receipts/receipt_pdf_renderer.dart';

// ⬇️ Import your sync headers provider (update the path if needed)

class TransactionDetailView extends ConsumerWidget {
  final TransactionEntry entry;

  // Change this if you target a different base URL
  static const String _baseUrl = 'http://127.0.0.1:8095';

  const TransactionDetailView({super.key, required this.entry});

  // ----------------------- Remote helpers -----------------------

  Uri _u(String path, [Map<String, String>? qp]) =>
      Uri.parse('$_baseUrl$path').replace(queryParameters: qp);

  double _toRemoteAmount(int cents) => cents / 100.0;

  Map<String, dynamic> _toRemoteBody(TransactionEntry e) {
    // Map local fields to your remote API contract
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

  Future<void> _saveOrUpdateRemote(
    BuildContext context,
    WidgetRef ref,
    TransactionEntry e,
  ) async {
    try {
      final body = jsonEncode(_toRemoteBody(e));
      // 🔐 Build dynamic headers (Authorization, API Key, Tenant, etc.)

      final headers = ref.read(syncHeaderBuilderProvider)()
        ..putIfAbsent('Content-Type', () => 'application/json')
        ..putIfAbsent('accept', () => 'application/json');

      late http.Response res;
      final remoteId = (e.remoteId ?? '').trim();

      if (remoteId.isEmpty) {
        // POST create
        res = await http.post(
          _u('/api/v1/commands/transaction'),
          headers: headers,
          body: body,
        );
      } else {
        // PUT update
        res = await http.put(
          _u('/api/v1/commands/transaction/$remoteId'),
          headers: headers,
          body: body,
        );
      }

      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw Exception('HTTP ${res.statusCode}: ${res.body}');
      }

      // Try read remoteId from response to persist locally (optional)
      String? newRemoteId;
      try {
        final m = jsonDecode(res.body);
        if (m is Map && (m['remoteId'] ?? m['id']) != null) {
          newRemoteId = '${m['remoteId'] ?? m['id']}';
        }
      } catch (_) {}

      // Mark local as clean if your repo supports it
      final repo = ref.read(transactionRepoProvider);
      await repo.update(
        e.copyWith(
          remoteId: newRemoteId ?? e.remoteId,
          isDirty: false,
          updatedAt: DateTime.now(),
        ),
      );

      // Refresh lists/balances
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
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur de synchronisation: $e')));
    }
  }

  Future<void> _deleteRemoteThenLocal(
    BuildContext context,
    WidgetRef ref,
    TransactionEntry e,
  ) async {
    try {
      final remoteId = (e.remoteId ?? '').trim();
      if (remoteId.isNotEmpty) {
        // 🔐 Dynamic headers again
        final headers = ref.read(syncHeaderBuilderProvider)()
          ..putIfAbsent('Content-Type', () => 'application/json')
          ..putIfAbsent('accept', () => 'application/json');

        final res = await http.delete(
          _u('/api/v1/commands/transaction/$remoteId'),
          headers: headers,
        );
        // Accept 2xx and 404 as "ok" (idempotent)
        if (!((res.statusCode >= 200 && res.statusCode < 300) ||
            res.statusCode == 404)) {
          throw Exception('HTTP ${res.statusCode}: ${res.body}');
        }
      }

      // Local soft delete
      await ref.read(transactionRepoProvider).softDelete(e.id);

      // Refresh lists/balances
      await ref.read(transactionsProvider.notifier).load();
      await ref.read(balanceProvider.notifier).load();
      ref.invalidate(transactionListItemsProvider);

      if (!context.mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Transaction supprimée')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Suppression échouée: $e')));
    }
  }

  // ----------------------- UI -----------------------

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tone = _toneForType(context, entry.typeEntry);
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Détails de la transaction'),
        actions: [
          // Save/Update to server
          IconButton(
            tooltip: (entry.remoteId ?? '').isEmpty
                ? 'Enregistrer sur le serveur'
                : 'Mettre à jour sur le serveur',
            icon: const Icon(Icons.cloud_upload_outlined),
            onPressed: () => _saveOrUpdateRemote(context, ref, entry),
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
          _HeaderCard(
            tone: tone,
            amountText: '$sign$amount',
            dateText: dateLabel,
            status: entry.status,
            accountless: (entry.accountId ?? '').isEmpty,
          ),
          const SizedBox(height: 12),

          // Informations principales
          _SectionCard(
            title: 'Informations',
            children: [
              _InfoTile(
                icon: Icons.notes_outlined,
                title: 'Description',
                value: (entry.description ?? '').trim().isNotEmpty
                    ? entry.description!
                    : '—',
              ),
              _InfoTile(
                icon: Icons.tag_outlined,
                title: 'Code',
                value: (entry.code ?? '').trim().isNotEmpty ? entry.code! : '—',
              ),
              _InfoTile(
                icon: Icons.account_balance_wallet_outlined,
                title: 'Compte',
                value: entry.accountId ?? '—',
              ),
              _InfoTile(
                icon: Icons.fingerprint,
                title: 'Identifiant',
                value: entry.id,
                trailing: IconButton(
                  tooltip: 'Copier',
                  icon: const Icon(Icons.copy),
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: entry.id));
                    if (context.mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(const SnackBar(content: Text('ID copié')));
                    }
                  },
                ),
              ),
            ],
          ),

          // Catégorie
          catAsync.when(
            data: (cat) => cat == null
                ? const SizedBox.shrink()
                : _SectionCard(
                    title: 'Catégorie',
                    children: [
                      _InfoTile(
                        icon: Icons.category_outlined,
                        title: 'Catégorie',
                        value: _categoryLabel(cat.code, cat.description),
                      ),
                    ],
                  ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),

          // Société / Client
          _PartiesSection(
            companyAsync: companyAsync,
            customerAsync: customerAsync,
          ),

          // Articles
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
              // Edit
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

              // Receipt preview
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

              // Delete (remote then local)
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
                      await _deleteRemoteThenLocal(context, ref, entry);
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

/// ———————————————————————— UI WIDGETS ————————————————————————

class _HeaderCard extends StatelessWidget {
  final _Tone tone;
  final String amountText;
  final String dateText;
  final String? status;
  final bool accountless;

  const _HeaderCard({
    required this.tone,
    required this.amountText,
    required this.dateText,
    required this.status,
    required this.accountless,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hsl = HSLColor.fromColor(tone.color);
    final c1 = hsl
        .withLightness((hsl.lightness + (isDark ? 0.12 : 0.20)).clamp(0, 1))
        .toColor();
    final c2 = hsl
        .withLightness((hsl.lightness - (isDark ? 0.10 : 0.06)).clamp(0, 1))
        .toColor();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [c1.withOpacity(0.18), c2.withOpacity(0.12)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: tone.color.withOpacity(0.28), width: 1),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: tone.color.withOpacity(0.15),
            child: Icon(tone.icon, color: tone.color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _TypePill(label: tone.label, color: tone.color),
                    _StatusPill(status: status, tone: tone),
                    if (accountless)
                      _TypePillSmall(label: 'Hors compte', color: tone.color),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  amountText,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: tone.color,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.event, size: 16),
                    const SizedBox(width: 6),
                    Text(dateText),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SectionCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const Divider(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Widget? trailing;

  const _InfoTile({
    required this.icon,
    required this.title,
    required this.value,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(value),
      trailing: trailing,
    );
  }
}

class _PartiesSection extends StatelessWidget {
  final AsyncValue companyAsync;
  final AsyncValue customerAsync;

  const _PartiesSection({
    required this.companyAsync,
    required this.customerAsync,
  });

  @override
  Widget build(BuildContext context) {
    final company = companyAsync.maybeWhen(data: (v) => v, orElse: () => null);
    final customer = customerAsync.maybeWhen(
      data: (v) => v,
      orElse: () => null,
    );
    if (company == null && customer == null) return const SizedBox.shrink();

    String companyLabel(String? name, String? code) {
      final n = (name ?? '').trim();
      final c = (code ?? '').trim();
      if (n.isNotEmpty && c.isNotEmpty) return '$n ($c)';
      if (n.isNotEmpty) return n;
      if (c.isNotEmpty) return c;
      return '—';
    }

    String customerLabel(String fullName, String? email, String? phone) {
      final e = (email ?? '').trim();
      final p = (phone ?? '').trim();
      if (e.isNotEmpty && p.isNotEmpty) return '$fullName • $e • $p';
      if (e.isNotEmpty) return '$fullName • $e';
      if (p.isNotEmpty) return '$fullName • $p';
      return fullName.isEmpty ? '—' : fullName;
    }

    return _SectionCard(
      title: 'Tiers',
      children: [
        if (company != null)
          _InfoTile(
            icon: Icons.apartment_outlined,
            title: 'Société',
            value: companyLabel(company.name, company.code),
          ),
        if (customer != null)
          _InfoTile(
            icon: Icons.person_outline,
            title: 'Client',
            value: customerLabel(
              customer.fullName,
              customer.email,
              customer.phone,
            ),
          ),
      ],
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
            ListTile(
              title: Text(title),
              trailing: _TypePillSmall(
                label: '${items.length} article(s)',
                color: accent,
              ),
            ),
            const Divider(height: 1),
            ...items.map(
              (it) => ListTile(
                dense: true,
                leading: const Icon(Icons.shopping_bag_outlined),
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

/// ———————————————————————— Tones & Pills ————————————————————————

class _Tone {
  final Color color;
  final IconData icon;
  final String label;
  const _Tone({required this.color, required this.icon, required this.label});
}

_Tone _toneForType(BuildContext context, String type) {
  final scheme = Theme.of(context).colorScheme;
  switch (type.toUpperCase()) {
    case 'DEBIT':
      return _Tone(color: scheme.error, icon: Icons.south, label: 'Dépense');
    case 'CREDIT':
      return _Tone(color: scheme.tertiary, icon: Icons.north, label: 'Revenu');
    case 'REMBOURSEMENT':
      return _Tone(
        color: Colors.teal,
        icon: Icons.undo_rounded,
        label: 'Remboursement',
      );
    case 'PRET':
      return _Tone(
        color: Colors.purple,
        icon: Icons.account_balance_outlined,
        label: 'Prêt',
      );
    case 'DEBT':
      return _Tone(
        color: Colors.amber.shade800,
        icon: Icons.receipt_long,
        label: 'Dette',
      );
    default:
      return _Tone(
        color: scheme.primary,
        icon: Icons.receipt_long,
        label: type.toUpperCase(),
      );
  }
}

class _TypePill extends StatelessWidget {
  final String label;
  final Color color;
  const _TypePill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    final bg = color.withOpacity(0.12);
    final fg = color.withOpacity(0.95);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: fg.withOpacity(0.35), width: 0.8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.w800,
          fontSize: 12,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _TypePillSmall extends StatelessWidget {
  final String label;
  final Color color;
  const _TypePillSmall({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    final bg = color.withOpacity(0.10);
    final fg = color.withOpacity(0.90);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: fg.withOpacity(0.28), width: 0.7),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.w700,
          fontSize: 11,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String? status;
  final _Tone tone;

  const _StatusPill({required this.status, required this.tone});

  @override
  Widget build(BuildContext context) {
    final s = (status ?? '').trim();
    if (s.isEmpty) return const SizedBox.shrink();

    // Map status -> label+color
    String label;
    Color color;
    switch (s.toUpperCase()) {
      case 'DEBT':
        label = 'Dette';
        color = Colors.amber.shade800;
        break;
      case 'REPAYMENT':
        label = 'Remboursement';
        color = Colors.teal;
        break;
      case 'LOAN':
        label = 'Prêt';
        color = Colors.purple;
        break;
      default:
        label = s;
        color = tone.color;
    }
    return _TypePillSmall(label: label, color: color);
  }
}
