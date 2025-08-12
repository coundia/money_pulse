import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:money_pulse/presentation/shared/formatters.dart';
import 'package:money_pulse/domain/sync/entities/sync_state.dart';
import 'package:money_pulse/presentation/features/sync/sync_state_repo_provider.dart';
import 'package:money_pulse/domain/sync/repositories/sync_state_repository.dart';

class SyncStateListPage extends ConsumerStatefulWidget {
  const SyncStateListPage({super.key});

  @override
  ConsumerState<SyncStateListPage> createState() => _SyncStateListPageState();
}

class _SyncStateListPageState extends ConsumerState<SyncStateListPage> {
  Future<List<SyncState>> _load(SyncStateRepository repo) => repo.findAll();

  String _fmt(DateTime? d) => d == null ? '—' : Formatters.dateFull(d);

  Future<void> _addOrEditDialog({SyncState? existing}) async {
    final repo = ref.read(syncStateRepoProvider);
    final form = _SyncFormData(
      table: existing?.entityTable ?? '',
      cursor: existing?.lastCursor ?? '',
      date: existing?.lastSyncAt,
      lockedTable: existing != null,
    );
    final res = await showDialog<_SyncFormData>(
      context: context,
      builder: (_) => _SyncStateEditDialog(data: form),
    );
    if (res == null) return;
    await repo.upsert(
      entityTable: res.table.trim(),
      lastSyncAt: res.date,
      lastCursor: res.cursor.trim().isEmpty ? null : res.cursor.trim(),
    );
    if (mounted) setState(() {});
  }

  Future<void> _editCursor(String table, String? current) async {
    final repo = ref.read(syncStateRepoProvider);
    final ctrl = TextEditingController(text: current ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Modifier le curseur'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: 'Curseur',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Enregistrer')),
        ],
      ),
    );
    if (ok == true) {
      await repo.updateCursor(table, ctrl.text.trim().isEmpty ? null : ctrl.text.trim());
      if (mounted) setState(() {});
    }
  }

  Future<void> _reset(String table) async {
    final repo = ref.read(syncStateRepoProvider);
    await repo.reset(table);
    if (mounted) setState(() {});
  }

  Future<void> _delete(String table) async {
    final repo = ref.read(syncStateRepoProvider);
    await repo.delete(table);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(syncStateRepoProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('État de synchronisation'),
        actions: [
          IconButton(
            tooltip: 'Rafraîchir',
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
          ),
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'clear') {
                await repo.clearAll();
                if (mounted) setState(() {});
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'clear',
                child: ListTile(
                  leading: Icon(Icons.delete_sweep_outlined),
                  title: Text('Vider la table'),
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addOrEditDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Ajouter'),
      ),
      body: FutureBuilder<List<SyncState>>(
        future: _load(repo),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snap.data ?? const <SyncState>[];
          if (items.isEmpty) {
            return const Center(child: Text('Aucune ligne'));
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final e = items[i];
              final subtitle =
                  'Dernière synchro: ${_fmt(e.lastSyncAt)}\n'
                  'Curseur: ${e.lastCursor?.isEmpty == true ? '—' : e.lastCursor}\n'
                  'MAJ: ${_fmt(e.updatedAt)}';
              return ListTile(
                leading: const Icon(Icons.storage),
                title: Text(e.entityTable),
                subtitle: Text(subtitle),
                isThreeLine: true,
                onTap: () => _addOrEditDialog(existing: e),
                trailing: PopupMenuButton<String>(
                  onSelected: (v) {
                    switch (v) {
                      case 'cursor':
                        _editCursor(e.entityTable, e.lastCursor);
                        break;
                      case 'reset':
                        _reset(e.entityTable);
                        break;
                      case 'delete':
                        _delete(e.entityTable);
                        break;
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'cursor',
                      child: ListTile(
                        leading: Icon(Icons.edit_note),
                        title: Text('Modifier le curseur'),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'reset',
                      child: ListTile(
                        leading: Icon(Icons.restart_alt),
                        title: Text('Réinitialiser'),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        leading: Icon(Icons.delete_outline),
                        title: Text('Supprimer'),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/* -------------------------- Small edit/add dialog -------------------------- */

class _SyncFormData {
  String table;
  String cursor;
  DateTime? date;
  final bool lockedTable;
  _SyncFormData({
    required this.table,
    required this.cursor,
    required this.date,
    this.lockedTable = false,
  });
}

class _SyncStateEditDialog extends StatefulWidget {
  final _SyncFormData data;
  const _SyncStateEditDialog({required this.data});

  @override
  State<_SyncStateEditDialog> createState() => _SyncStateEditDialogState();
}

class _SyncStateEditDialogState extends State<_SyncStateEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _table;
  late TextEditingController _cursor;

  @override
  void initState() {
    super.initState();
    _table = TextEditingController(text: widget.data.table);
    _cursor = TextEditingController(text: widget.data.cursor);
  }

  @override
  void dispose() {
    _table.dispose();
    _cursor.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = widget.data.date == null
        ? '—'
        : DateFormat.yMMMd().add_Hm().format(widget.data.date!);

    return AlertDialog(
      title: Text(widget.data.lockedTable ? 'Modifier' : 'Ajouter'),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _table,
                enabled: !widget.data.lockedTable,
                decoration: const InputDecoration(
                  labelText: 'Nom de table (ex: account)',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Requis'
                    : null,
                autofocus: !widget.data.lockedTable,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _cursor,
                decoration: const InputDecoration(
                  labelText: 'Curseur',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Dernière synchro'),
                subtitle: Text(dateLabel),
                trailing: const Icon(Icons.calendar_today_outlined),
                onTap: () async {
                  final now = DateTime.now();
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: widget.data.date ?? now,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                    helpText: 'Sélectionnez une date',
                  );
                  if (picked != null) {
                    setState(() => widget.data.date = picked);
                  }
                },
                onLongPress: () =>
                    setState(() => widget.data.date = null), // effacer
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.pop(
              context,
              _SyncFormData(
                table: _table.text.trim(),
                cursor: _cursor.text.trim(),
                date: widget.data.date,
                lockedTable: widget.data.lockedTable,
              ),
            );
          },
          child: const Text('Enregistrer'),
        ),
      ],
    );
  }
}
