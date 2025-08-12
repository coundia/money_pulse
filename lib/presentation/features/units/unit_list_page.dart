import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:money_pulse/domain/units/entities/unit.dart';
import 'package:money_pulse/presentation/features/units/unit_repo_provider.dart';

import 'package:money_pulse/presentation/widgets/right_drawer.dart';
import 'package:money_pulse/presentation/shared/formatters.dart';

import '../../../domain/units/repositories/unit_repository.dart';
import 'widgets/unit_tile.dart';
import 'widgets/unit_form_panel.dart';
import 'widgets/unit_delete_panel.dart';
import 'widgets/unit_view_panel.dart';
import 'widgets/unit_context_menu.dart';

class UnitListPage extends ConsumerStatefulWidget {
  const UnitListPage({super.key});

  @override
  ConsumerState<UnitListPage> createState() => _UnitListPageState();
}

class _UnitListPageState extends ConsumerState<UnitListPage> {
  late final UnitRepository _repo = ref.read(unitRepoProvider);
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      if (!mounted) return;
      setState(() => _query = _searchCtrl.text.trim());
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<List<Unit>> _load() async {
    if (_query.isEmpty) return _repo.findAllActive();
    return _repo.searchActive(_query, limit: 300);
  }

  Future<void> _share(Unit u) async {
    final text = [
      'Unité: ${u.name ?? u.code}',
      'Code: ${u.code}',
      if ((u.description ?? '').isNotEmpty) 'Description: ${u.description}',
      'MAJ: ${Formatters.dateFull(u.updatedAt)}',
      'ID: ${u.id}',
    ].join('\n');
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Détails copiés')));
  }

  Future<void> _addOrEdit({Unit? existing}) async {
    if (!mounted) return;
    final res = await showRightDrawer<UnitFormResult?>(
      context,
      child: UnitFormPanel(existing: existing),
      widthFraction: 0.92,
      heightFraction: 0.96,
    );
    if (res == null) return;

    if (existing == null) {
      final now = DateTime.now();
      final u = Unit(
        id: res.id,
        remoteId: null,
        code: res.code,
        name: res.name?.isEmpty == true ? null : res.name!.trim(),
        description: res.description?.isEmpty == true
            ? null
            : res.description!.trim(),
        createdAt: now,
        updatedAt: now,
        deletedAt: null,
        syncAt: null,
        version: 0,
        isDirty: 1,
      );
      await _repo.create(u);
    } else {
      final updated = existing.copyWith(
        code: res.code,
        name: res.name?.isEmpty == true ? null : res.name!.trim(),
        description: res.description?.isEmpty == true
            ? null
            : res.description!.trim(),
      );
      await _repo.update(updated);
    }
    if (mounted) setState(() {});
  }

  Future<void> _confirmDelete(Unit u) async {
    if (!mounted) return;
    final ok = await showRightDrawer<bool>(
      context,
      child: UnitDeletePanel(unit: u),
      widthFraction: 0.86,
      heightFraction: 0.6,
    );
    if (ok == true) {
      await _repo.softDelete(u.id);
      if (!mounted) return;
      setState(() {});
    }
  }

  Future<void> _view(Unit u) async {
    if (!mounted) return;
    await showRightDrawer<void>(
      context,
      child: UnitViewPanel(
        unit: u,
        onEdit: () async {
          Navigator.of(context).pop(); // close viewer
          await _addOrEdit(existing: u);
        },
        onDelete: () async {
          Navigator.of(context).pop(); // close viewer
          await _confirmDelete(u);
        },
        onShare: () => _share(u),
      ),
      widthFraction: 0.92,
      heightFraction: 0.96,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Unit>>(
      future: _load(),
      builder: (context, snap) {
        final items = snap.data ?? const <Unit>[];

        final body = switch (snap.connectionState) {
          ConnectionState.waiting => const Center(
            child: CircularProgressIndicator(),
          ),
          _ =>
            items.isEmpty
                ? _empty()
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
                    itemCount: items.length + 1,
                    separatorBuilder: (_, i) => i == 0
                        ? const SizedBox.shrink()
                        : const Divider(height: 1),
                    itemBuilder: (_, i) {
                      if (i == 0) return _header(items.length);
                      final u = items[i - 1];
                      final subtitle = (u.description ?? '').isNotEmpty
                          ? u.description
                          : null;

                      return UnitTile(
                        code: u.code,
                        name: u.name,
                        subtitle: subtitle,
                        onTap: () => _view(u), // open viewer
                        onMenuAction: (action) async {
                          await Future.delayed(
                            Duration.zero,
                          ); // close menu first
                          if (!mounted) return;
                          switch (action) {
                            case UnitContextMenu.view:
                              await _view(u);
                              break;
                            case UnitContextMenu.edit:
                              await _addOrEdit(existing: u);
                              break;
                            case UnitContextMenu.delete:
                              await _confirmDelete(u);
                              break;
                            case UnitContextMenu.share:
                              await _share(u);
                              break;
                          }
                        },
                      );
                    },
                  ),
        };

        return Scaffold(
          appBar: AppBar(
            title: const Text('Unités'),
            actions: [
              IconButton(
                tooltip: 'Ajouter',
                onPressed: () => _addOrEdit(),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _addOrEdit(),
            icon: const Icon(Icons.add),
            label: const Text('Nouvelle unité'),
          ),
          body: body,
        );
      },
    );
  }

  Widget _header(int count) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text('Unités', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            Chip(
              avatar: const Icon(Icons.straighten, size: 18),
              label: Text('Total: $count'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _searchCtrl,
          decoration: InputDecoration(
            hintText: 'Rechercher par code, nom ou description',
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
            const Icon(Icons.straighten, size: 72),
            const SizedBox(height: 12),
            const Text(
              'Aucune unité',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            const Text('Ajoutez votre première unité (ex: kg, L, pièce…)'),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => _addOrEdit(),
              icon: const Icon(Icons.add),
              label: const Text('Nouvelle unité'),
            ),
          ],
        ),
      ),
    );
  }
}
