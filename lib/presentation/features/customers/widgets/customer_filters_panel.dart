// Right-drawer panel to edit customer list filters with local state and apply/reset actions.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/customer_filters_providers.dart';
import '../providers/customer_filters_data_providers.dart';

class SubmitFormIntent extends Intent {
  const SubmitFormIntent();
}

class CustomerFiltersPanel extends ConsumerStatefulWidget {
  const CustomerFiltersPanel({super.key});

  @override
  ConsumerState<CustomerFiltersPanel> createState() =>
      _CustomerFiltersPanelState();
}

class _CustomerFiltersPanelState extends ConsumerState<CustomerFiltersPanel> {
  late final TextEditingController _searchCtrl;
  String? _companyId;
  bool? _hasDebt;
  late CustomerSortMode _sortMode;

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController(text: ref.read(customerSearchProvider));
    _companyId = ref.read(customerCompanyFilterProvider);
    _hasDebt = ref.read(customerHasDebtFilterProvider);
    _sortMode = ref.read(customerSortModeProvider);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _resetLocal() {
    _searchCtrl.text = '';
    _companyId = null;
    _hasDebt = null;
    _sortMode = CustomerSortMode.recent;
    setState(() {});
  }

  void _applyAndClose() {
    ref.read(customerSearchProvider.notifier).state = _searchCtrl.text;
    ref.read(customerCompanyFilterProvider.notifier).state = _companyId;
    ref.read(customerHasDebtFilterProvider.notifier).state = _hasDebt;
    ref.read(customerSortModeProvider.notifier).state = _sortMode;
    ref.read(customerPageIndexProvider.notifier).state = 0;
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final companiesAsync = ref.watch(companyFilterOptionsProvider);
    final insets = MediaQuery.of(context).viewInsets.bottom;

    return Shortcuts(
      shortcuts: {
        LogicalKeySet(LogicalKeyboardKey.enter): const SubmitFormIntent(),
        LogicalKeySet(LogicalKeyboardKey.numpadEnter): const SubmitFormIntent(),
      },
      child: Actions(
        actions: {
          SubmitFormIntent: CallbackAction<SubmitFormIntent>(
            onInvoke: (_) {
              _applyAndClose();
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
              IconButton(
                tooltip: 'Appliquer',
                icon: const Icon(Icons.check),
                onPressed: _applyAndClose,
              ),
            ],
          ),
          body: Padding(
            padding: EdgeInsets.only(bottom: insets),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextField(
                  controller: _searchCtrl,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _applyAndClose(),
                  decoration: InputDecoration(
                    labelText: 'Rechercher',
                    hintText: 'Nom, téléphone, email',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      tooltip: 'Effacer',
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() {});
                      },
                      icon: const Icon(Icons.clear),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                companiesAsync.when(
                  data: (companies) {
                    final items = <DropdownMenuItem<String?>>[
                      const DropdownMenuItem(
                        value: null,
                        child: Text('Toutes sociétés'),
                      ),
                      ...companies.map((c) {
                        final label = (c.name ?? '').isNotEmpty
                            ? c.name!
                            : (c.code ?? 'Société');
                        return DropdownMenuItem(
                          value: c.id,
                          child: Text(label),
                        );
                      }),
                    ];
                    return InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Société',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String?>(
                          value: _companyId,
                          items: items,
                          onChanged: (v) => setState(() => _companyId = v),
                          isExpanded: true,
                        ),
                      ),
                    );
                  },
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text('Erreur: $e'),
                ),
                const SizedBox(height: 12),
                Text(
                  'État de dette',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    FilterChip(
                      label: const Text('Tous'),
                      selected: _hasDebt == null,
                      onSelected: (_) => setState(() => _hasDebt = null),
                    ),
                    FilterChip(
                      label: const Text('Avec dette'),
                      selected: _hasDebt == true,
                      onSelected: (_) => setState(() => _hasDebt = true),
                    ),
                    FilterChip(
                      label: const Text('Sans dette'),
                      selected: _hasDebt == false,
                      onSelected: (_) => setState(() => _hasDebt = false),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text('Tri', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Récents'),
                      selected: _sortMode == CustomerSortMode.recent,
                      onSelected: (_) =>
                          setState(() => _sortMode = CustomerSortMode.recent),
                    ),
                    ChoiceChip(
                      label: const Text('A–Z'),
                      selected: _sortMode == CustomerSortMode.az,
                      onSelected: (_) =>
                          setState(() => _sortMode = CustomerSortMode.az),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _resetLocal,
                        icon: const Icon(Icons.filter_alt_off_outlined),
                        label: const Text('Réinitialiser'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _applyAndClose,
                        icon: const Icon(Icons.check),
                        label: const Text('Appliquer'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
