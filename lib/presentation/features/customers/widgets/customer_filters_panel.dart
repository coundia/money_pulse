// Right-drawer filter panel for customers with richer controls.
// Adds: company, active-only, debt (all/with/without), sort (recent/A–Z), reset/apply.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jaayko/domain/company/entities/company.dart';
import '../../../../domain/company/repositories/company_repository.dart';
import '../../../app/providers/company_repo_provider.dart';
import '../providers/customer_filters_providers.dart'
    hide customerCompanyFilterProvider, customerSearchProvider;
import '../providers/customer_list_providers.dart'
    hide customerPageIndexProvider;

class CustomerFiltersPanel extends ConsumerStatefulWidget {
  const CustomerFiltersPanel({super.key});

  @override
  ConsumerState<CustomerFiltersPanel> createState() =>
      _CustomerFiltersPanelState();
}

class _CustomerFiltersPanelState extends ConsumerState<CustomerFiltersPanel> {
  String? _companyId;
  bool _onlyActive = true;

  // New fields
  bool? _hasDebt; // null = Tous, true = Avec dette, false = Sans dette
  late CustomerSortMode _sort;

  @override
  void initState() {
    super.initState();
    _companyId = ref.read(customerCompanyFilterProvider);
    _onlyActive = ref.read(customerOnlyActiveProvider);

    _hasDebt = ref.read(customerHasDebtFilterProvider);
    _sort = ref.read(customerSortModeProvider);
  }

  Future<List<Company>> _loadCompanies() async {
    final repo = ref.read(companyRepoProvider);
    return repo.findAll(const CompanyQuery(limit: 300, offset: 0));
  }

  void _apply() {
    ref.read(customerCompanyFilterProvider.notifier).state =
        (_companyId ?? '').isEmpty ? null : _companyId;
    ref.read(customerOnlyActiveProvider.notifier).state = _onlyActive;

    ref.read(customerHasDebtFilterProvider.notifier).state = _hasDebt;
    ref.read(customerSortModeProvider.notifier).state = _sort;

    ref.read(customerPageIndexProvider.notifier).state = 0;
    Navigator.of(context).pop<bool>(true);
  }

  void _reset() {
    setState(() {
      _companyId = null;
      _onlyActive = true;
      _hasDebt = null;
      _sort = CustomerSortMode.recent;
    });

    ref.read(customerCompanyFilterProvider.notifier).state = null;
    ref.read(customerOnlyActiveProvider.notifier).state = true;
    ref.read(customerHasDebtFilterProvider.notifier).state = null;
    ref.read(customerSortModeProvider.notifier).state = CustomerSortMode.recent;
    ref.read(customerSearchProvider.notifier).state = '';
    ref.read(customerPageIndexProvider.notifier).state = 0;
    Navigator.of(context).pop<bool>(true);
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 640;

    Widget _sectionTitle(String t) => Padding(
      padding: const EdgeInsets.only(bottom: 6, top: 10),
      child: Text(t, style: Theme.of(context).textTheme.titleSmall),
    );

    return Shortcuts(
      shortcuts: {
        LogicalKeySet(LogicalKeyboardKey.enter): const _SubmitIntent(),
        LogicalKeySet(LogicalKeyboardKey.numpadEnter): const _SubmitIntent(),
      },
      child: Actions(
        actions: {
          _SubmitIntent: CallbackAction<_SubmitIntent>(
            onInvoke: (_) {
              _apply();
              return null;
            },
          ),
        },
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Filtres'),
            leading: IconButton(
              tooltip: 'Fermer',
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            actions: [
              TextButton.icon(
                onPressed: _reset,
                icon: const Icon(Icons.filter_alt_off_outlined),
                label: const Text('Réinitialiser'),
              ),
              const SizedBox(width: 4),
              FilledButton.icon(
                onPressed: _apply,
                icon: const Icon(Icons.check),
                label: const Text('Appliquer'),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: FutureBuilder<List<Company>>(
            future: _loadCompanies(),
            builder: (context, snap) {
              final companies = snap.data ?? const <Company>[];
              final content = [
                // SOCIÉTÉ
                _sectionTitle('Société'),
                DropdownButtonFormField<String?>(
                  value: (_companyId ?? '').isEmpty ? null : _companyId,
                  isDense: true,
                  decoration: const InputDecoration(
                    hintText: '— Toutes —',
                    prefixIcon: Icon(Icons.business),
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('— Toutes —'),
                    ),
                    ...companies.map(
                      (c) => DropdownMenuItem<String?>(
                        value: c.id,
                        child: Text('${c.name} (${c.code})'),
                      ),
                    ),
                  ],
                  onChanged: (v) => setState(() => _companyId = v),
                ),
                const SizedBox(height: 16),

                // ACTIVITÉ
                SwitchListTile.adaptive(
                  value: _onlyActive,
                  onChanged: (v) => setState(() => _onlyActive = v),
                  title: const Text('Actifs uniquement'),
                  secondary: const Icon(Icons.verified_user_outlined),
                  dense: true,
                ),
                const SizedBox(height: 8),

                // TRI
                _sectionTitle('Tri'),
                Wrap(
                  spacing: 8,
                  children: [
                    FilterChip(
                      label: const Text('Récent'),
                      selected: _sort == CustomerSortMode.recent,
                      onSelected: (_) =>
                          setState(() => _sort = CustomerSortMode.recent),
                    ),
                    FilterChip(
                      label: const Text('A–Z'),
                      selected: _sort == CustomerSortMode.nameAZ,
                      onSelected: (_) =>
                          setState(() => _sort = CustomerSortMode.nameAZ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),
                SafeArea(
                  top: false,
                  child: FilledButton.icon(
                    onPressed: _apply,
                    icon: const Icon(Icons.filter_alt),
                    label: const Text('Appliquer'),
                  ),
                ),
              ];

              return ListView(
                padding: const EdgeInsets.all(16),
                children: isWide
                    ? [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: content.take(6).toList(),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: content.skip(6).toList(),
                              ),
                            ),
                          ],
                        ),
                      ]
                    : content,
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SubmitIntent extends Intent {
  const _SubmitIntent();
}
