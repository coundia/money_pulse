// Accounts page with cleaner header/search and Enter-to-submit form in right drawer.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:money_pulse/presentation/app/providers.dart';
import 'package:money_pulse/presentation/app/account_selection.dart';
import 'package:money_pulse/domain/accounts/entities/account.dart';
import 'package:money_pulse/domain/accounts/repositories/account_repository.dart';
import 'package:money_pulse/presentation/widgets/right_drawer.dart';
import 'package:money_pulse/presentation/shared/formatters.dart';
import 'widgets/account_details_panel.dart';
import 'widgets/account_tile.dart';
import 'widgets/account_context_menu.dart';
import 'widgets/account_adjust_balance_panel.dart'; // <— NEW

class AccountPage extends ConsumerStatefulWidget {
  const AccountPage({super.key});
  @override
  ConsumerState<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends ConsumerState<AccountPage> {
  late final AccountRepository _repo = ref.read(accountRepoProvider);
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(
      () => setState(() => _query = _searchCtrl.text.trim().toLowerCase()),
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<List<Account>> _load() => _repo.findAllActive();

  String? _t(String? s) {
    if (s == null) return null;
    final v = s.trim();
    return v.isEmpty ? null : v;
  }

  String _fmtMoney(int cents, String? code) {
    final a = Formatters.amountFromCents(cents);
    return code == null ? a : '$a $code';
  }

  String _fmtDate(DateTime? d) => d == null ? '—' : Formatters.dateFull(d);

  Future<void> _addOrEdit({Account? existing}) async {
    final result = await showRightDrawer<_AccountFormResult>(
      context,
      child: _AccountFormPanel(existing: existing),
      widthFraction: 0.86,
      heightFraction: 0.96,
    );
    if (result == null) return;
    if (existing == null) {
      final now = DateTime.now();
      final acc = Account(
        id: const Uuid().v4(),
        remoteId: null,
        balance: 0,
        balancePrev: 0,
        balanceBlocked: 0,
        code: result.code,
        description: _t(result.description),
        status: null,
        currency: _t(result.currency),
        isDefault: false,
        createdAt: now,
        updatedAt: now,
        deletedAt: null,
        syncAt: null,
        version: 0,
        isDirty: true,
      );
      await _repo.create(acc);
    } else {
      final updated = existing.copyWith(
        code: result.code,
        description: _t(result.description),
        currency: _t(result.currency),
        updatedAt: DateTime.now(),
      );
      await _repo.update(updated);
    }
    if (mounted) setState(() {});
  }

  Future<void> _adjustBalance(Account acc) async {
    // <— NEW
    final result = await showRightDrawer<AccountAdjustBalanceResult>(
      context,
      child: AccountAdjustBalancePanel(account: acc),
      widthFraction: 0.64,
      heightFraction: 0.96,
    );
    if (result == null) return;
    final updated = acc.copyWith(
      balancePrev: acc.balance,
      balance: result.newBalanceCents,
      updatedAt: DateTime.now(),
      isDirty: true,
    );
    await _repo.update(updated);
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Solde ajusté à ${_fmtMoney(updated.balance, updated.currency)}',
        ),
      ),
    );
  }

  Future<void> _setDefault(Account acc) async {
    try {
      await _repo.setDefault(acc.id);
    } catch (_) {
      await _repo.update(acc.copyWith(isDefault: true));
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kLastAccountIdKey, acc.id);
    ref.read(selectedAccountIdProvider.notifier).state = acc.id;
    if (mounted) setState(() {});
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('« ${acc.code} » est désormais le compte par défaut'),
      ),
    );
  }

  Future<void> _delete(Account acc) async {
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer le compte ?'),
        content: Text(
          '« ${acc.code ?? 'Compte'} » sera déplacé dans la corbeille.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _repo.softDelete(acc.id);
    if (mounted) setState(() {});
  }

  Future<void> _share(Account a) async {
    if (!mounted) return;
    final text =
        'Compte: ${a.code ?? '—'}\nSolde: ${_fmtMoney(a.balance, a.currency)}\nDevise: ${a.currency ?? '—'}\nMis à jour: ${_fmtDate(a.updatedAt)}';
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Détails copiés dans le presse-papiers')),
    );
  }

  bool _isDefault(Account a) {
    final v = a.isDefault;
    if (v is bool) return v;
    if (v is num) return v != 0;
    return false;
  }

  List<Account> _filterAndSort(List<Account> items) {
    final base = List<Account>.of(items);
    final q = _query;
    final filtered = q.isEmpty
        ? base
        : base.where((a) {
            final s = [
              a.code ?? '',
              a.description ?? '',
              a.currency ?? '',
              a.status ?? '',
            ].join(' ').toLowerCase();
            return s.contains(q);
          }).toList();
    filtered.sort((a, b) {
      final da = _isDefault(a) ? 0 : 1;
      final db = _isDefault(b) ? 0 : 1;
      if (da != db) return da.compareTo(db);
      return (a.code ?? '').toLowerCase().compareTo(
        (b.code ?? '').toLowerCase(),
      );
    });
    return filtered;
  }

  Widget _header(List<Account> items) {
    final currencyGroups = <String, int>{};
    for (final a in items) {
      final code = (a.currency ?? 'XOF').toUpperCase();
      currencyGroups[code] = (currencyGroups[code] ?? 0) + a.balance;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: currencyGroups.entries
              .map(
                (e) => Chip(
                  label: Text(
                    'Total: ${Formatters.amountFromCents(e.value)} ${e.key}',
                  ),
                  avatar: const Icon(
                    Icons.account_balance_wallet_outlined,
                    size: 18,
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _searchCtrl,
          decoration: InputDecoration(
            hintText: 'Rechercher par code, devise, description',
            prefixIcon: const Icon(Icons.search),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            isDense: true,
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Future<void> _view(Account a) async {
    if (!mounted) return;
    await showRightDrawer<void>(
      context,
      child: AccountDetailsPanel(
        account: a,
        onEdit: () => _addOrEdit(existing: a),
        onMakeDefault: () => _setDefault(a),
        onDelete: () => _delete(a),
        onShare: () => _share(a),
      ),
      widthFraction: 0.86,
      heightFraction: 0.96,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Account>>(
      future: _load(),
      builder: (context, snap) {
        final items = snap.data ?? const <Account>[];
        final filtered = _filterAndSort(items);

        final body = snap.connectionState == ConnectionState.waiting
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: () async => setState(() {}),
                child: items.isEmpty
                    ? _empty()
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 120),
                        itemBuilder: (_, i) {
                          if (i == 0) return _header(items);
                          final a = filtered[i - 1];
                          return GestureDetector(
                            onLongPressStart: (d) {
                              showAccountContextMenu(
                                context,
                                d.globalPosition,
                                canMakeDefault: !_isDefault(a),
                                onView: () => _view(a),
                                onMakeDefault: () => _setDefault(a),
                                onEdit: () => _addOrEdit(existing: a),
                                onDelete: () => _delete(a),
                                onShare: () => _share(a),
                                onAdjustBalance: () =>
                                    _adjustBalance(a), // <— NEW
                                accountLabel: a.code,
                                balanceCents: a.balance,
                                currency: a.currency,
                                updatedAt: a.updatedAt,
                              );
                            },
                            onSecondaryTapDown: (d) {
                              showAccountContextMenu(
                                context,
                                d.globalPosition,
                                canMakeDefault: !_isDefault(a),
                                onView: () => _view(a),
                                onMakeDefault: () => _setDefault(a),
                                onEdit: () => _addOrEdit(existing: a),
                                onDelete: () => _delete(a),
                                onShare: () => _share(a),
                                onAdjustBalance: () =>
                                    _adjustBalance(a), // <— NEW
                                accountLabel: a.code,
                                balanceCents: a.balance,
                                currency: a.currency,
                                updatedAt: a.updatedAt,
                              );
                            },
                            child: AccountTile(
                              account: a,
                              isDefault: _isDefault(a),
                              balanceText: _fmtMoney(a.balance, a.currency),
                              updatedAtText:
                                  'Mis à jour ${_fmtDate(a.updatedAt)}',
                              onView: () => _view(a),
                              onMakeDefault: null,
                              onEdit: () => _addOrEdit(existing: a),
                              onDelete: () => _delete(a),
                            ),
                          );
                        },
                        separatorBuilder: (_, i) => i == 0
                            ? const SizedBox.shrink()
                            : const Divider(height: 1),
                        itemCount: filtered.isEmpty ? 1 : filtered.length + 1,
                      ),
              );

        return Scaffold(
          appBar: AppBar(
            title: const Text('Comptes'),
            actions: [
              IconButton(
                onPressed: () => _addOrEdit(),
                icon: const Icon(Icons.add),
                tooltip: 'Ajouter un compte',
              ),
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'refresh') setState(() {});
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'refresh',
                    child: ListTile(
                      leading: Icon(Icons.refresh),
                      title: Text('Rafraîchir'),
                    ),
                  ),
                ],
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _addOrEdit(),
            icon: const Icon(Icons.add),
            label: const Text('Ajouter un compte'),
          ),
          body: body,
        );
      },
    );
  }

  Widget _empty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.account_balance_outlined, size: 72),
            const SizedBox(height: 12),
            const Text(
              'Aucun compte',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            const Text('Créez votre premier compte pour suivre vos soldes.'),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => _addOrEdit(),
              icon: const Icon(Icons.add),
              label: const Text('Ajouter un compte'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountFormResult {
  final String code;
  final String? description;
  final String? currency;
  const _AccountFormResult({
    required this.code,
    this.description,
    this.currency,
  });
}

class _AccountFormPanel extends StatefulWidget {
  final Account? existing;
  const _AccountFormPanel({this.existing});
  @override
  State<_AccountFormPanel> createState() => _AccountFormPanelState();
}

class _AccountFormPanelState extends State<_AccountFormPanel> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _code = TextEditingController(
    text: widget.existing?.code ?? '',
  );
  late final TextEditingController _desc = TextEditingController(
    text: widget.existing?.description ?? '',
  );
  late final TextEditingController _curr = TextEditingController(
    text: widget.existing?.currency ?? 'XOF',
  );

  @override
  void dispose() {
    _code.dispose();
    _desc.dispose();
    _curr.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      _AccountFormResult(
        code: _code.text.trim(),
        description: _desc.text.trim().isEmpty ? null : _desc.text.trim(),
        currency: _curr.text.trim().isEmpty ? null : _curr.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(isEdit ? 'Modifier le compte' : 'Ajouter un compte'),
        actions: [
          TextButton(
            onPressed: _save,
            child: Text(isEdit ? 'Enregistrer' : 'Ajouter'),
          ),
        ],
      ),
      body: Shortcuts(
        shortcuts: {
          LogicalKeySet(LogicalKeyboardKey.enter): const ActivateIntent(),
          LogicalKeySet(LogicalKeyboardKey.numpadEnter): const ActivateIntent(),
        },
        child: Actions(
          actions: {
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                _save();
                return null;
              },
            ),
          },
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextFormField(
                  controller: _code,
                  decoration: const InputDecoration(
                    labelText: 'Code',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Obligatoire' : null,
                  autofocus: true,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _desc,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _curr,
                  decoration: const InputDecoration(
                    labelText: 'Devise (ex. XOF)',
                    border: OutlineInputBorder(),
                  ),
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _save(),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save),
                  label: const Text('Enregistrer'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
