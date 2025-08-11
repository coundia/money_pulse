import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:money_pulse/presentation/app/providers.dart';
import 'package:money_pulse/presentation/app/account_selection.dart';
import 'package:money_pulse/domain/accounts/entities/account.dart';
import 'package:money_pulse/domain/accounts/repositories/account_repository.dart';
import 'package:money_pulse/presentation/widgets/right_drawer.dart';

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
    _searchCtrl.addListener(() {
      setState(() {
        _query = _searchCtrl.text.trim().toLowerCase();
      });
    });
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

  int _decimalDigits(String? code) {
    final c = code?.toUpperCase() ?? '';
    const zeros = {'XOF', 'XAF', 'JPY', 'KRW'};
    return zeros.contains(c) ? 0 : 2;
  }

  String _fmtMoney(int cents, String? code) {
    final amount = cents / 100;
    final digits = _decimalDigits(code);
    final fmt = NumberFormat.currency(
      name: code ?? 'XOF',
      decimalDigits: digits,
    );
    return fmt.format(amount);
  }

  String _fmtDate(DateTime? d) =>
      d == null ? '-' : DateFormat.yMMMd().add_Hm().format(d);

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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('“${acc.code}” is now default')));
  }

  Future<void> _delete(Account acc) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete account?'),
        content: Text('This will move “${acc.code ?? 'Account'}” to trash.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _repo.softDelete(acc.id);
    if (mounted) setState(() {});
  }

  bool _isDefault(Account a) {
    final v = a.isDefault;
    if (v is bool) return v;
    if (v is num) return v != 0;
    return false;
  }

  List<Account> _filterAndSort(List<Account> items) {
    final q = _query;
    final filtered = q.isEmpty
        ? items
        : items.where((a) {
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
        Text('Accounts', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: currencyGroups.entries
              .map(
                (e) => Chip(
                  label: Text(_fmtMoney(e.value, e.key)),
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
            hintText: 'Search by code, currency, description',
            prefixIcon: const Icon(Icons.search),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            isDense: true,
          ),
        ),
        const SizedBox(height: 12),
      ],
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
              'No accounts',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            const Text('Create your first account to start tracking balances.'),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => _addOrEdit(),
              icon: const Icon(Icons.add),
              label: const Text('Add account'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(k, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 6),
          Expanded(child: Text(v)),
        ],
      ),
    );
  }

  Future<void> _view(Account a) async {
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Account details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _kv('Code', a.code ?? '-'),
              _kv('Description', a.description ?? '-'),
              _kv('Currency', a.currency ?? '-'),
              const SizedBox(height: 8),
              _kv('Balance', _fmtMoney(a.balance, a.currency)),
              _kv('Previous balance', _fmtMoney(a.balancePrev, a.currency)),
              _kv('Blocked balance', _fmtMoney(a.balanceBlocked, a.currency)),
              const SizedBox(height: 8),
              _kv('Default', _isDefault(a) ? 'Yes' : 'No'),
              _kv('Status', a.status ?? '-'),
              _kv('Remote ID', a.remoteId ?? '-'),
              const SizedBox(height: 8),
              _kv('Created at', _fmtDate(a.createdAt)),
              _kv('Updated at', _fmtDate(a.updatedAt)),
              _kv('Deleted at', _fmtDate(a.deletedAt)),
              _kv('Sync at', _fmtDate(a.syncAt)),
              _kv('Version', '${a.version}'),
              const SizedBox(height: 8),
              const Text('ID', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              SelectableText(a.id),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _tile(Account a) {
    final isDefault = _isDefault(a);
    final code = (a.code ?? '').trim();
    final two = code.isEmpty
        ? '?'
        : (code.length >= 2 ? code.substring(0, 2) : code).toUpperCase();
    final bal = _fmtMoney(a.balance, a.currency);
    final sub = a.description?.trim().isNotEmpty == true
        ? a.description!.trim()
        : (a.currency ?? '-');
    return InkWell(
      onLongPress: () => _setDefault(a),
      child: ListTile(
        leading: CircleAvatar(child: Text(two)),
        title: Row(
          children: [
            Expanded(child: Text(a.code ?? 'NA')),
            if (isDefault)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.star, size: 14),
                        SizedBox(width: 4),
                        Text(
                          'Default',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
        subtitle: Text(sub),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(bal, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(
              'Updated ${_fmtDate(a.updatedAt)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        onTap: () => _view(a),
        selected: isDefault,
        selectedTileColor: Theme.of(
          context,
        ).colorScheme.primary.withOpacity(0.06),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Account>>(
      future: _load(),
      builder: (context, snap) {
        final items = snap.data ?? const <Account>[];
        final filtered = _filterAndSort(items);
        return Scaffold(
          appBar: AppBar(
            title: const Text('Accounts'),
            actions: [
              IconButton(
                onPressed: () => _addOrEdit(),
                icon: const Icon(Icons.add),
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
                      title: Text('Refresh'),
                    ),
                  ),
                ],
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _addOrEdit(),
            icon: const Icon(Icons.add),
            label: const Text('Add account'),
          ),
          body: switch (snap.connectionState) {
            ConnectionState.waiting => const Center(
              child: CircularProgressIndicator(),
            ),
            _ => RefreshIndicator(
              onRefresh: () async {
                setState(() {});
              },
              child: items.isEmpty
                  ? _empty()
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 120),
                      itemBuilder: (_, i) {
                        if (i == 0) return _header(items);
                        final a = filtered[i - 1];
                        return Dismissible(
                          key: ValueKey(a.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            color: Colors.red,
                            child: const Icon(
                              Icons.delete,
                              color: Colors.white,
                            ),
                          ),
                          confirmDismiss: (_) async {
                            await _delete(a);
                            return false;
                          },
                          child: _tile(a),
                        );
                      },
                      separatorBuilder: (_, i) => i == 0
                          ? const SizedBox.shrink()
                          : const Divider(height: 1),
                      itemCount: filtered.isEmpty ? 1 : filtered.length + 1,
                    ),
            ),
          },
        );
      },
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
        title: Text(isEdit ? 'Edit account' : 'Add account'),
        actions: [
          TextButton(onPressed: _save, child: Text(isEdit ? 'Save' : 'Add')),
        ],
      ),
      body: Form(
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
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
              autofocus: true,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _desc,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _curr,
              decoration: const InputDecoration(
                labelText: 'Currency (e.g. XOF)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
