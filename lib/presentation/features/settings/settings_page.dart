// Settings page with improved UI sections and right-drawer confirmations, plus a "Close app" action.
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:money_pulse/presentation/widgets/right_drawer.dart';

import '../products/product_list_page.dart';
import 'widgets/confirm_panel.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});
  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _busy = false;

  Future<bool> _confirm({
    required IconData icon,
    required String title,
    required String message,
    String confirmLabel = 'Confirmer',
    String cancelLabel = 'Annuler',
  }) async {
    final ok = await showRightDrawer<bool>(
      context,
      child: ConfirmPanel(
        icon: icon,
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
      ),
      widthFraction: 0.86,
      heightFraction: 0.5,
    );
    return ok == true;
  }

  Future<void> _resetDb() async {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final ok = await _confirm(
      icon: Icons.delete_forever_rounded,
      title: 'Réinitialiser la base de données ?',
      message:
          'Toutes les données locales seront supprimées puis recréées. Cette action est irréversible.',
      confirmLabel: 'Réinitialiser',
      cancelLabel: 'Annuler',
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      await AppDatabase.I.recreate(version: 1);
    } catch (e) {
      if (mounted) {
        messenger?.showSnackBar(
          SnackBar(content: Text('Échec de la réinitialisation : $e')),
        );
        setState(() => _busy = false);
      }
      return;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    messenger?.showSnackBar(
      const SnackBar(content: Text('Base réinitialisée, redémarrage…')),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      RestartApp.restart(context);
    });
  }

  Future<void> _closeApp() async {
    final ok = await _confirm(
      icon: Icons.power_settings_new_rounded,
      title: 'Fermer l’application ?',
      message: 'Voulez-vous vraiment fermer l’application maintenant ?',
      confirmLabel: 'Fermer',
      cancelLabel: 'Annuler',
    );
    if (!ok) return;

    if (Platform.isIOS) {
      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger?.showSnackBar(
        const SnackBar(content: Text('Fermeture non autorisée sur iOS.')),
      );
      return;
    }
    SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.titleMedium;

    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _SectionCard(
            title: 'Gestion',
            children: [
              _tile(
                icon: Icons.category_outlined,
                title: 'Gérer les catégories',
                subtitle: 'Créer, modifier, supprimer des catégories',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CategoryListPage()),
                ),
              ),
              _divider(),
              _tile(
                icon: Icons.account_balance_wallet_outlined,
                title: 'Gérer les comptes',
                subtitle: 'Ajouter, définir par défaut, modifier, supprimer',
                onTap: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const AccountPage())),
              ),
              _divider(),
              _tile(
                icon: Icons.inventory_2_rounded,
                title: 'Gérer les produits',
                subtitle: 'Créer, modifier, supprimer des produits',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ProductListPage()),
                ),
              ),
              _divider(),
              _tile(
                icon: Icons.group_rounded,
                title: 'Gérer les clients',
                subtitle: 'Créer, modifier, supprimer des clients',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CustomerListPage()),
                ),
              ),
              _divider(),
              _tile(
                icon: Icons.apartment_rounded,
                title: 'Gérer les entreprises',
                subtitle: 'Créer, modifier, supprimer des entreprises',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CompanyListPage()),
                ),
              ),
              _divider(),
              _tile(
                icon: Icons.inventory_rounded,
                title: 'Gérer le stock',
                subtitle: 'Inventaire',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const StockLevelListPage()),
                ),
              ),
              _divider(),
              _tile(
                icon: Icons.swap_horiz_rounded,
                title: 'Mouvements',
                subtitle: 'List',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const StockMovementListPage(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: 'Données',
            children: [
              _tile(
                icon: Icons.storage_rounded,
                title: 'État de synchronisation',
                subtitle: 'Dernière synchro et curseur par entité',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SyncStateListPage()),
                ),
              ),
              _divider(),
              _tile(
                icon: Icons.sync_alt_rounded,
                title: 'Journal des changements',
                subtitle: 'Voir les entrées de synchronisation',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ChangeLogListPage()),
                ),
              ),
              _divider(),
              ListTile(
                leading: const Icon(Icons.delete_forever_rounded),
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
          const SizedBox(height: 12),
          _SectionCard(
            title: 'Application',
            children: [
              ListTile(
                leading: const Icon(Icons.info_outline_rounded),
                title: const Text('Version de l’application'),
                subtitle: Text(Formatters.dateFull(DateTime.now())),
              ),
              _divider(),
              ListTile(
                leading: const Icon(Icons.power_settings_new_rounded),
                title: const Text('Fermer l’application'),
                subtitle: const Text('Quitter proprement l’application'),
                onTap: _closeApp,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _divider() => const Divider(height: 1);

  ListTile _tile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _SectionCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.titleSmall;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: Row(children: [Text(title, style: titleStyle)]),
            ),
            const Divider(height: 1),
            ...children,
          ],
        ),
      ),
    );
  }
}
