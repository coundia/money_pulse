/// Orchestration page for listing, searching and managing savings goals with right-drawers.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_pulse/presentation/features/goals/providers/saving_goal_list_providers.dart';
import 'package:money_pulse/presentation/features/goals/providers/saving_goal_repo_provider.dart';
import 'package:money_pulse/presentation/features/goals/widgets/saving_goal_tile.dart';
import 'package:money_pulse/presentation/features/goals/widgets/saving_goal_context_menu.dart';
import 'package:money_pulse/presentation/features/goals/saving_goal_view_panel.dart';
import 'package:money_pulse/presentation/features/goals/saving_goal_form_panel.dart';
import 'package:money_pulse/presentation/features/goals/saving_goal_delete_panel.dart';
import 'package:money_pulse/presentation/widgets/right_drawer.dart';
import 'package:money_pulse/domain/goals/entities/saving_goal.dart';
import 'package:money_pulse/domain/goals/repositories/saving_goal_repository.dart';

import '../../shared/formatters.dart';
import '../transactions/widgets/amount_field_quickpad.dart';

class SavingGoalListPage extends ConsumerStatefulWidget {
  const SavingGoalListPage({super.key});

  @override
  ConsumerState<SavingGoalListPage> createState() => _SavingGoalListPageState();
}

class _SavingGoalListPageState extends ConsumerState<SavingGoalListPage> {
  late final TextEditingController _searchCtrl;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController(
      text: ref.read(savingGoalSearchProvider),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _refresh() {
    ref.invalidate(savingGoalListProvider);
    ref.invalidate(savingGoalCountProvider);
  }

  Future<void> _openCreate() async {
    final res = await showRightDrawer<SavingGoalFormResult?>(
      context,
      child: const SavingGoalFormPanel(),
      widthFraction: 0.9,
      heightFraction: 1,
    );
    if (res != null) _refresh();
  }

  Future<void> _openEdit(SavingGoal e) async {
    final res = await showRightDrawer<SavingGoalFormResult?>(
      context,
      child: SavingGoalFormPanel(existing: e),
      widthFraction: 0.9,
      heightFraction: 1,
    );
    if (res != null) _refresh();
  }

  Future<void> _openView(SavingGoal e) async {
    await showRightDrawer<void>(
      context,
      child: SavingGoalViewPanel(
        goal: e,
        onEdit: () {
          Navigator.of(context).pop();
          _openEdit(e);
        },
        onAdjust: () async {
          Navigator.of(context).pop();
          await _openAdjust(e);
        },
        onArchiveToggle: () async {
          final repo = ref.read(savingGoalRepoProvider);
          await repo.updatePartial(e.id, {
            'isArchived': e.isArchived == 1 ? 0 : 1,
            'updatedAt': DateTime.now().toIso8601String(),
            'isDirty': 1,
          });
          _refresh();
        },
        onDelete: () async {
          Navigator.of(context).pop();
          await _confirmDelete(e);
        },
        onShare: () {},
      ),
      widthFraction: 0.86,
      heightFraction: 1,
    );
  }

  Future<void> _openAdjust(SavingGoal e) async {
    final ctrl = TextEditingController();
    final res = await showRightDrawer<int?>(
      context,
      child: _AdjustSavedPanel(controller: ctrl, current: e.savedCents),
      widthFraction: 0.86,
    );
    if (res != null) {
      final repo = ref.read(savingGoalRepoProvider);
      await repo.addToSaved(e.id, res);
      await repo.updatePartial(e.id, {
        'updatedAt': DateTime.now().toIso8601String(),
        'isDirty': 1,
      });
      _refresh();
    }
  }

  Future<void> _confirmDelete(SavingGoal e) async {
    final ok = await showRightDrawer<bool?>(
      context,
      child: SavingGoalDeletePanel(name: e.name),
      widthFraction: 0.6,
    );
    if (ok == true) {
      final repo = ref.read(savingGoalRepoProvider);
      await repo.softDelete(e.id);
      _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(savingGoalListProvider);
    final count = ref
        .watch(savingGoalCountProvider)
        .maybeWhen(orElse: () => 0, data: (v) => v);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Objectifs d’épargne'),
        actions: [
          IconButton(
            onPressed: _openCreate,
            icon: const Icon(Icons.add),
            tooltip: 'Créer',
          ),
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualiser',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Rechercher un objectif…',
                    ),
                    onChanged: (v) {
                      _debounce?.cancel();
                      _debounce = Timer(const Duration(milliseconds: 280), () {
                        ref.read(savingGoalSearchProvider.notifier).state = v;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Actifs'),
                  selected: ref.watch(savingGoalOnlyActiveProvider),
                  onSelected: (v) =>
                      ref.read(savingGoalOnlyActiveProvider.notifier).state = v,
                ),
                const SizedBox(width: 6),
                PopupMenuButton<bool?>(
                  tooltip: 'Statut',
                  onSelected: (v) =>
                      ref.read(savingGoalOnlyCompletedProvider.notifier).state =
                          v,
                  itemBuilder: (ctx) => const [
                    PopupMenuItem(value: null, child: Text('Tous')),
                    PopupMenuItem(value: true, child: Text('Terminés')),
                    PopupMenuItem(value: false, child: Text('En cours')),
                  ],
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8.0),
                    child: Chip(label: Text('Filtrer')),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('$count élément(s)'),
            ),
          ),
          Expanded(
            child: async.when(
              data: (items) {
                if (items.isEmpty) {
                  return const Center(
                    child: Text(
                      'Aucun objectif. Créez votre premier objectif.',
                    ),
                  );
                }
                return ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final e = items[i];
                    return SavingGoalTile(
                      goal: e,
                      onTap: () => _openView(e),
                      onMenu: (a) async {
                        switch (a) {
                          case SavingGoalMenuAction.view:
                            _openView(e);
                            break;
                          case SavingGoalMenuAction.edit:
                            _openEdit(e);
                            break;
                          case SavingGoalMenuAction.adjust:
                            _openAdjust(e);
                            break;
                          case SavingGoalMenuAction.archive:
                            await ref
                                .read(savingGoalRepoProvider)
                                .updatePartial(e.id, {
                                  'isArchived': 1,
                                  'updatedAt': DateTime.now().toIso8601String(),
                                  'isDirty': 1,
                                });
                            _refresh();
                            break;
                          case SavingGoalMenuAction.unarchive:
                            await ref
                                .read(savingGoalRepoProvider)
                                .updatePartial(e.id, {
                                  'isArchived': 0,
                                  'updatedAt': DateTime.now().toIso8601String(),
                                  'isDirty': 1,
                                });
                            _refresh();
                            break;
                          case SavingGoalMenuAction.delete:
                            _confirmDelete(e);
                            break;
                          case SavingGoalMenuAction.share:
                            break;
                        }
                      },
                    );
                  },
                );
              },
              error: (e, s) => Center(child: Text('Erreur: $e')),
              loading: () => const Center(child: CircularProgressIndicator()),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreate,
        icon: const Icon(Icons.add),
        label: const Text('Créer'),
      ),
    );
  }
}

class _AdjustSavedPanel extends StatefulWidget {
  final TextEditingController controller;
  final int current;
  const _AdjustSavedPanel({required this.controller, required this.current});

  @override
  State<_AdjustSavedPanel> createState() => _AdjustSavedPanelState();
}

class _AdjustSavedPanelState extends State<_AdjustSavedPanel> {
  int _delta = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.text = '0';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ajuster l’épargne')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'Épargne actuelle: ${Formatters.amountFromCents(widget.current)}',
            ),
            const SizedBox(height: 8),
            AmountFieldQuickPad(
              controller: widget.controller,
              quickUnits: const [
                0,
                2000,
                5000,
                10000,
                20000,
                50000,
                100000,
                200000,
                300000,
                400000,
                500000,
                1000000,
              ],
              lockToItems: false,
              onToggleLock: null,
              onChanged: () {
                final raw = widget.controller.text.replaceAll(
                  RegExp(r'[^0-9]'),
                  '',
                );
                setState(() => _delta = raw.isEmpty ? 0 : int.parse(raw));
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => Navigator.of(context).pop(_delta),
                    icon: const Icon(Icons.add),
                    label: const Text('Ajouter'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).pop(-_delta),
                    icon: const Icon(Icons.remove),
                    label: const Text('Retirer'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
