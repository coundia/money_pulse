import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_pulse/presentation/app/restart_app.dart';
import 'package:money_pulse/infrastructure/db/app_database.dart';
import 'package:money_pulse/presentation/features/categories/category_list_page.dart';
import 'package:money_pulse/presentation/features/accounts/account_page.dart';
import 'package:money_pulse/presentation/features/companies/company_list_page.dart';
import 'package:money_pulse/presentation/features/customers/customer_list_page.dart';
import 'package:money_pulse/presentation/features/stock/stock_level_list_page.dart';
import 'package:money_pulse/presentation/features/stock_movement/stock_movement_list_page.dart';
import 'package:money_pulse/presentation/features/sync/change_log_list_page.dart';
import 'package:money_pulse/presentation/features/sync/sync_state_list_page.dart';

import 'package:money_pulse/presentation/shared/formatters.dart';

import '../products/product_list_page.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});
  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _busy = false;

  Future<void> _resetDb() async {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Réinitialiser la base de données ?'),
        content: const Text(
          'Toutes les données locales seront supprimées puis recréées. Cette action est irréversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await AppDatabase.I.recreate(version: 1);
    } catch (e) {
      if (mounted) {
        messenger?.showSnackBar(
          SnackBar(content: Text('Échec de la réinitialisation: $e')),
        );
        setState(() => _busy = false);
      }
      return;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    messenger?.showSnackBar(
      const SnackBar(
        content: Text('Base de données réinitialisée, redémarrage...'),
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      RestartApp.restart(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Paramètres')),
      body: ListView(
        children: [
          const _SectionHeader('Gestion'),
          ListTile(
            leading: const Icon(Icons.category_outlined),
            title: const Text('Gérer les catégories'),
            subtitle: const Text('Créer, modifier, supprimer des catégories'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const CategoryListPage())),
          ),
          ListTile(
            leading: const Icon(Icons.account_balance_wallet_outlined),
            title: const Text('Gérer les comptes'),
            subtitle: const Text(
              'Ajouter, définir par défaut, modifier, supprimer',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const AccountPage())),
          ),
          ListTile(
            leading: const Icon(Icons.list),
            title: const Text('Gérer les produits'),
            subtitle: const Text('Créer, modifier, supprimer des produits'),

            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const ProductListPage())),
          ),

          ListTile(
            leading: const Icon(Icons.list),
            title: const Text('Gérer les clients'),
            subtitle: const Text('Créer, modifier, supprimer des clients'),

            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const CustomerListPage())),
          ),

          ListTile(
            leading: const Icon(Icons.list),
            title: const Text('Gérer les entreprises'),
            subtitle: const Text('Créer, modifier, supprimer des entreprises'),

            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const CompanyListPage())),
          ),

          ListTile(
            leading: const Icon(Icons.list),
            title: const Text('Gérer le stock'),
            subtitle: const Text('Inventaire'),

            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const StockLevelListPage()),
            ),
          ),

          ListTile(
            leading: const Icon(Icons.list),
            title: const Text('Mouvements'),
            subtitle: const Text('List'),

            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const StockMovementListPage()),
            ),
          ),

          const Divider(height: 24),
          const _SectionHeader('Données'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.storage_rounded),
                  title: const Text('État de synchronisation'),
                  subtitle: const Text(
                    'Dernière synchro et curseur par entité',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const SyncStateListPage(),
                    ),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.sync_alt),
                  title: const Text('Journal des changements'),
                  subtitle: const Text('Voir les entrées de synchronisation'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ChangeLogListPage(),
                    ),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.delete_forever),
                  title: const Text('Réinitialiser la base de données'),
                  subtitle: const Text('Supprimer puis recréer la base locale'),
                  trailing: _busy
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : null,
                  enabled: !_busy,
                  onTap: _busy ? null : _resetDb,
                ),
              ],
            ),
          ),
          const Divider(height: 24),
          const _SectionHeader('À propos'),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Version de l’application'),
            subtitle: Text(Formatters.dateFull(DateTime.now())),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.titleSmall;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(text, style: style),
    );
  }
}
