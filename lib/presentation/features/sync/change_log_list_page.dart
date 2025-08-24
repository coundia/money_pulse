import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:money_pulse/domain/sync/entities/change_log_entry.dart';

import 'package:money_pulse/domain/sync/repositories/change_log_repository.dart';

import '../../app/providers.dart';

enum _Filter { all, pending, failed, ack }

class ChangeLogListPage extends ConsumerStatefulWidget {
  const ChangeLogListPage({super.key});

  @override
  ConsumerState<ChangeLogListPage> createState() => _ChangeLogListPageState();
}

class _ChangeLogListPageState extends ConsumerState<ChangeLogListPage> {
  _Filter filter = _Filter.all;

  String? _statusForFilter(_Filter f) {
    switch (f) {
      case _Filter.pending:
        return 'PENDING';
      case _Filter.failed:
        return 'FAILED';
      case _Filter.ack:
        return 'ACK';
      case _Filter.all:
        return null;
    }
  }

  Future<List<ChangeLogEntry>> _load(ChangeLogRepository repo) async {
    final items = await repo.findAll(
      status: _statusForFilter(filter),
      limit: 500, // optional: control how many rows to fetch
    );
    return items.cast<ChangeLogEntry>();
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(changeLogRepoProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Journal des changements'),
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
                  title: Text('Vider le journal'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: SegmentedButton<_Filter>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: _Filter.all,
                  icon: Icon(Icons.list),
                  label: Text('Tous'),
                ),
                ButtonSegment(
                  value: _Filter.pending,
                  icon: Icon(Icons.schedule),
                  label: Text('En attente'),
                ),
                ButtonSegment(
                  value: _Filter.failed,
                  icon: Icon(Icons.error_outline),
                  label: Text('Échec'),
                ),
                ButtonSegment(
                  value: _Filter.ack,
                  icon: Icon(Icons.task_alt),
                  label: Text('Accusé'),
                ),
              ],
              selected: {filter},
              onSelectionChanged: (s) => setState(() => filter = s.first),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: FutureBuilder<List<ChangeLogEntry>>(
              future: _load(repo),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final items = snap.data ?? const <ChangeLogEntry>[];
                if (items.isEmpty) {
                  return const Center(child: Text('Aucune entrée'));
                }
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) => _tile(context, repo, items[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile(
    BuildContext context,
    ChangeLogRepository repo,
    ChangeLogEntry e,
  ) {
    final when = DateFormat.yMMMd().add_Hm().format(e.createdAt);
    final status = e.status ?? 'PENDING';
    final (icon, color) = _statusVisual(status);
    final title = '${e.entityTable} • ${e.operation ?? '?'}';
    final subtitle = '${e.entityId}\n$when';
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withOpacity(0.12),
        child: Icon(icon, color: color),
      ),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(subtitle),
      isThreeLine: true,
      trailing: PopupMenuButton<String>(
        onSelected: (v) async {
          switch (v) {
            case 'ack':
              await repo.markSync(e.id);
              break;
            case 'retry':
              await repo.markPending(e.id);
              break;
            case 'delete':
              await repo.delete(e.id);
              break;
          }
          if (mounted) setState(() {});
        },
        itemBuilder: (_) => [
          if (status != 'ACK')
            const PopupMenuItem(
              value: 'ack',
              child: ListTile(
                leading: Icon(Icons.task_alt),
                title: Text('Marquer ACCUSÉ'),
              ),
            ),
          if (status != 'PENDING')
            const PopupMenuItem(
              value: 'retry',
              child: ListTile(
                leading: Icon(Icons.refresh),
                title: Text('Remettre en attente'),
              ),
            ),
          const PopupMenuItem(
            value: 'delete',
            child: ListTile(
              leading: Icon(Icons.delete_outline),
              title: Text('Supprimer'),
            ),
          ),
        ],
      ),
    );
  }

  (IconData, Color) _statusVisual(String status) {
    switch (status) {
      case 'PENDING':
        return (Icons.schedule, Colors.amber);
      case 'FAILED':
        return (Icons.error_outline, Colors.red);
      case 'ACK':
        return (Icons.task_alt, Colors.green);
      case 'SENT':
        return (Icons.upload, Colors.blueGrey);
      default:
        return (Icons.help_outline, Colors.grey);
    }
  }
}
