// Page de liste des sociétés : recherche, rafraîchissement local, synchronisation avec le serveur distant.
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'package:money_pulse/domain/company/entities/company.dart';
import 'package:money_pulse/presentation/features/companies/company_form_panel.dart';
import 'package:money_pulse/presentation/features/companies/providers/company_list_providers.dart';
import 'package:money_pulse/presentation/features/companies/widgets/company_tile.dart';
import 'package:money_pulse/presentation/widgets/right_drawer.dart';

import '../../../sync/infrastructure/sync_headers_provider.dart';
import '../../app/providers/company_repo_provider.dart';

class CompanyListPage extends ConsumerStatefulWidget {
  const CompanyListPage({super.key});

  @override
  ConsumerState<CompanyListPage> createState() => _CompanyListPageState();
}

class _CompanyListPageState extends ConsumerState<CompanyListPage> {
  late final TextEditingController _searchCtrl;

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController(text: ref.read(companySearchProvider));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _refresh() {
    ref.invalidate(companyListProvider);
    ref.invalidate(companyCountProvider);
  }

  Future<void> _openCreate() async {
    final ok = await showRightDrawer<bool>(
      context,
      child: const CompanyFormPanel(),
      widthFraction: 0.86,
      heightFraction: 0.96,
    );
    if (ok == true && mounted) _refresh();
  }

  Future<void> _syncWithServer() async {
    final repo = ref.read(companyRepoProvider);
    final headerBuilder = ref.read(syncHeaderBuilderProvider);
    final uri = Uri.parse(
      'http://127.0.0.1:8095/api/v1/queries/companies?page=0&limit=500',
    );

    try {
      final res = await http.get(uri, headers: headerBuilder());
      if (res.statusCode != 200) {
        throw Exception('Erreur ${res.statusCode}: ${res.body}');
      }

      final decoded = jsonDecode(res.body) as Map<String, dynamic>;
      final rows = (decoded['items'] ?? decoded['content'] ?? []) as List;

      for (final raw in rows) {
        final remoteId = raw['id']?.toString();
        final code = raw['code']?.toString();
        if (remoteId == null || code == null) continue;

        // Trouver la société locale via code
        final existing = await repo.findByCode(code);
        if (existing != null) {
          final updated = existing.copyWith(
            remoteId: remoteId,
            status: raw['status']?.toString(),
            isPublic: raw['isPublic'] == true,
            isActive: raw['isActive'] == true,
            syncAt: DateTime.tryParse(raw['syncAt'] ?? ''),
            updatedAt: DateTime.now(),
            isDirty: false,
          );
          await repo.update(updated);
        }
      }

      if (mounted) {
        _refresh();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Synchronisation terminée')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur de sync: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final listAsync = ref.watch(companyListProvider);
    final count = ref
        .watch(companyCountProvider)
        .maybeWhen(data: (c) => c, orElse: () => null);

    final header = Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) {
                ref.read(companySearchProvider.notifier).state = v;
                ref.read(companyPageIndexProvider.notifier).state = 0;
              },
              onSubmitted: (v) {
                ref.read(companySearchProvider.notifier).state = v;
                ref.read(companyPageIndexProvider.notifier).state = 0;
              },
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                hintText: 'Rechercher par code, nom, téléphone, email',
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_searchCtrl.text.isNotEmpty)
                      IconButton(
                        tooltip: 'Effacer',
                        onPressed: () {
                          _searchCtrl.clear();
                          ref.read(companySearchProvider.notifier).state = '';
                          ref.read(companyPageIndexProvider.notifier).state = 0;
                        },
                        icon: const Icon(Icons.clear),
                      ),
                    IconButton(
                      tooltip: 'Rafraîchir',
                      onPressed: _refresh,
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (count != null)
            Chip(
              label: Text('$count élément(s)'),
              avatar: const Icon(Icons.filter_alt, size: 18),
            ),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sociétés'),
        actions: [
          IconButton(
            tooltip: 'Ajouter',
            onPressed: _openCreate,
            icon: const Icon(Icons.add),
          ),
          IconButton(
            tooltip: 'Rafraîchir',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Synchroniser',
            onPressed: _syncWithServer,
            icon: const Icon(Icons.cloud_sync_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          header,
          const Divider(height: 1),
          Expanded(
            child: listAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Erreur: $e')),
              data: (rows) {
                if (rows.isEmpty) {
                  return _EmptyState(onAdd: _openCreate);
                }
                return RefreshIndicator(
                  onRefresh: () async => _refresh(),
                  child: ListView.separated(
                    padding: const EdgeInsets.only(bottom: 88),
                    itemCount: rows.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final c = rows[i];

                      final tile = CompanyTile(
                        key: ValueKey('company_${c.id}'),
                        company: c,
                        onActionDone: _refresh,
                      );

                      if (c.isDefault == true) {
                        return ClipRect(
                          child: Banner(
                            message: 'Défaut',
                            location: BannerLocation.topStart,
                            color: Theme.of(context).colorScheme.primary,
                            textStyle: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onPrimary.withOpacity(0.95),
                              fontWeight: FontWeight.w600,
                            ),
                            child: tile,
                          ),
                        );
                      }
                      return tile;
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreate,
        icon: const Icon(Icons.add),
        label: const Text('Ajouter'),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.business_outlined, size: 72),
            const SizedBox(height: 12),
            const Text(
              'Aucune société',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            const Text('Créez votre première société pour commencer.'),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Ajouter'),
            ),
          ],
        ),
      ),
    );
  }
}
