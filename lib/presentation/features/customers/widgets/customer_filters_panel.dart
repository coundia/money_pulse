// Right-drawer filter panel for customers (company, only-active, reset/apply).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_pulse/domain/company/entities/company.dart';
import '../../../../domain/company/repositories/company_repository.dart';
import '../../../app/providers/company_repo_provider.dart';
import '../providers/customer_list_providers.dart';

class CustomerFiltersPanel extends ConsumerStatefulWidget {
  const CustomerFiltersPanel({super.key});

  @override
  ConsumerState<CustomerFiltersPanel> createState() =>
      _CustomerFiltersPanelState();
}

class _CustomerFiltersPanelState extends ConsumerState<CustomerFiltersPanel> {
  String? _companyId;
  bool _onlyActive = true;

  @override
  void initState() {
    super.initState();
    _companyId = ref.read(customerCompanyFilterProvider);
    _onlyActive = ref.read(customerOnlyActiveProvider);
  }

  Future<List<Company>> _loadCompanies() async {
    final repo = ref.read(companyRepoProvider);
    return repo.findAll(const CompanyQuery(limit: 300, offset: 0));
  }

  void _apply() {
    ref.read(customerCompanyFilterProvider.notifier).state =
        (_companyId ?? '').isEmpty ? null : _companyId;
    ref.read(customerOnlyActiveProvider.notifier).state = _onlyActive;
    ref.read(customerPageIndexProvider.notifier).state = 0;
    Navigator.of(context).pop<bool>(true);
  }

  void _reset() {
    setState(() {
      _companyId = null;
      _onlyActive = true;
    });
    ref.read(customerCompanyFilterProvider.notifier).state = null;
    ref.read(customerOnlyActiveProvider.notifier).state = true;
    ref.read(customerSearchProvider.notifier).state = '';
    ref.read(customerPageIndexProvider.notifier).state = 0;
    Navigator.of(context).pop<bool>(true);
  }

  @override
  Widget build(BuildContext context) {
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
                icon: const Icon(Icons.restore),
                label: const Text('Réinitialiser'),
              ),
            ],
          ),
          body: FutureBuilder<List<Company>>(
            future: _loadCompanies(),
            builder: (context, snap) {
              final companies = snap.data ?? const <Company>[];
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  DropdownButtonFormField<String?>(
                    value: (_companyId ?? '').isEmpty ? null : _companyId,
                    isDense: true,
                    decoration: const InputDecoration(
                      labelText: 'Société',
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
                  SwitchListTile.adaptive(
                    value: _onlyActive,
                    onChanged: (v) => setState(() => _onlyActive = v),
                    title: const Text('Actifs uniquement'),
                    secondary: const Icon(Icons.verified_user_outlined),
                    dense: true,
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
                ],
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
