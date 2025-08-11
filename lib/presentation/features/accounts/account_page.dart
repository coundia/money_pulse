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

  Future<List<Account>> _load() => _repo.findAllActive();

  String? _t(String? s) {
    if (s == null) return null;
    final v = s.trim();
    return v.isEmpty ? null : v;
  }

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
    await _repo.softDelete(acc.id);
    if (mounted) setState(() {});
  }

  bool _isDefault(Account a) {
    final v = a.isDefault;
    if (v is bool) return v;
    if (v is num) return v != 0;
    return false;
  }

  String _fmtDate(DateTime? d) =>
      d == null ? '-' : DateFormat.yMMMd().add_Hm().format(d);

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
              _kv('Balance', '${a.balance / 100}'),
              _kv('Previous balance', '${a.balancePrev / 100}'),
              _kv('Blocked balance', '${a.balanceBlocked / 100}'),
              const SizedBox(height: 8),
              _kv('Default', a.isDefault ? 'Yes' : 'No'),
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

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Account>>(
      future: _load(),
      builder: (context, snap) {
        final items = snap.data ?? const <Account>[];
        return Scaffold(
          appBar: AppBar(title: const Text('Accounts')),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _addOrEdit(),
            icon: const Icon(Icons.add),
            label: const Text('Add account'),
          ),
          body: switch (snap.connectionState) {
            ConnectionState.waiting => const Center(
              child: CircularProgressIndicator(),
            ),
            _ =>
              items.isEmpty
                  ? const Center(child: Text('No accounts'))
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
                      itemBuilder: (_, i) {
                        final a = items[i];
                        final isDefault = _isDefault(a);
                        final code = (a.code ?? '').trim();
                        final two = code.isEmpty
                            ? '?'
                            : (code.length >= 2 ? code.substring(0, 2) : code)
                                  .toUpperCase();
                        return ListTile(
                          leading: CircleAvatar(child: Text(two)),
                          title: Text(a.code ?? 'NA'),
                          subtitle: Text(
                            '${NumberFormat("#").format(a.balance / 100)} ${a.currency ?? ''}',
                          ),
                          trailing: PopupMenuButton<String>(
                            onSelected: (v) {
                              switch (v) {
                                case 'view':
                                  _view(a);
                                  break;
                                case 'default':
                                  _setDefault(a);
                                  break;
                                case 'edit':
                                  _addOrEdit(existing: a);
                                  break;
                                case 'delete':
                                  _delete(a);
                                  break;
                              }
                            },
                            itemBuilder: (_) => [
                              const PopupMenuItem(
                                value: 'view',
                                child: ListTile(
                                  leading: Icon(Icons.info_outline),
                                  title: Text('View'),
                                ),
                              ),
                              if (!isDefault)
                                const PopupMenuItem(
                                  value: 'default',
                                  child: ListTile(
                                    leading: Icon(Icons.star_border),
                                    title: Text('Make default'),
                                  ),
                                ),
                              const PopupMenuItem(
                                value: 'edit',
                                child: ListTile(
                                  leading: Icon(Icons.edit_outlined),
                                  title: Text('Edit'),
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: ListTile(
                                  leading: Icon(Icons.delete_outline),
                                  title: Text('Delete'),
                                ),
                              ),
                            ],
                          ),
                          onTap: () => _view(a),
                          selected: isDefault,
                          selectedTileColor: Theme.of(
                            context,
                          ).colorScheme.primary.withOpacity(0.06),
                          subtitleTextStyle: Theme.of(
                            context,
                          ).textTheme.bodySmall,
                          titleTextStyle: Theme.of(
                            context,
                          ).textTheme.titleMedium,
                        );
                      },
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemCount: items.length,
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
