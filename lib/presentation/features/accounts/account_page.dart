import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:money_pulse/presentation/app/providers.dart';
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
        description: result.description?.trim().isEmpty == true
            ? null
            : result.description!.trim(),
        status: null,
        currency: result.currency?.trim().isEmpty == true
            ? null
            : result.currency!.trim(),
        isDefault: true,
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
        description: result.description?.trim().isEmpty == true
            ? null
            : result.description!.trim(),
        currency: result.currency?.trim().isEmpty == true
            ? null
            : result.currency!.trim(),
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
                        return ListTile(
                          leading: CircleAvatar(child: Text(a.code ?? '?')),
                          title: Text(a.code ?? 'NA'),
                          subtitle: Text(a.description ?? a.currency ?? ''),
                          trailing: PopupMenuButton<String>(
                            onSelected: (v) {
                              switch (v) {
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
                          onTap: () => _addOrEdit(existing: a),
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
