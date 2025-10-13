/// File: lib/presentation/features/settings/settings_page.dart
/// Settings page including schema upgrade, and login/logout using right-drawer flow.
/// Adds an "À propos" page with your information.

import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_pulse/presentation/app/restart_app.dart';
import 'package:money_pulse/infrastructure/db/app_database.dart';
import 'package:money_pulse/presentation/features/categories/category_list_page.dart';
import 'package:money_pulse/presentation/features/accounts/account_page.dart';
import 'package:money_pulse/presentation/features/companies/company_list_page.dart';
import 'package:money_pulse/presentation/features/customers/customer_list_page.dart';
import 'package:money_pulse/presentation/features/settings/app_settings_page.dart'
    show AppSettingsPage;
import 'package:money_pulse/presentation/features/stock/stock_level_list_page.dart';
import 'package:money_pulse/presentation/features/stock_movement/stock_movement_list_page.dart';
import 'package:money_pulse/presentation/features/sync/change_log_list_page.dart';
import 'package:money_pulse/presentation/features/sync/sync_state_list_page.dart';
import 'package:money_pulse/presentation/shared/formatters.dart';
import 'package:money_pulse/presentation/widgets/right_drawer.dart';
import 'package:money_pulse/onboarding/presentation/providers/access_session_provider.dart';
import 'package:money_pulse/onboarding/presentation/flows/logout_and_purge_flow.dart';
import '../../../sync/infrastructure/pull_providers.dart';
import '../../app/app_exit/app_exit.dart';
import '../products/product_list_page.dart';
import 'widgets/confirm_panel.dart';
import 'about_page.dart'; // <-- NEW

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

  Future<void> _login() async {
    if (!mounted || _busy) return;
    final ok = await requireAccess(context, ref);
    if (!mounted) return;
    if (ok) {
      try {
        final sum = await pullAllTables(ref);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Import terminé • Comptes: ${sum.accounts}, '
              'Catégories: ${sum.categories}, Clients: ${sum.customers}',
            ),
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Échec import: $e')));
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Connecté avec succès.')));
      setState(() {});
    }
  }

  Future<void> _logout() async {
    if (!mounted || _busy) return;
    setState(() => _busy = true);
    await runLogoutAndPurgeFlow(context, ref);
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _upgradeDbSchema() async {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final ok = await _confirm(
      icon: Icons.system_update_alt_rounded,
      title: 'Mettre à niveau le schéma ?',
      message:
          'Créer les tables et index manquants sans supprimer les données.',
      confirmLabel: 'Mettre à niveau',
      cancelLabel: 'Annuler',
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      await AppDatabase.I.upgradeSchemas();
      messenger?.showSnackBar(
        const SnackBar(content: Text('Schéma mis à niveau avec succès.')),
      );
    } catch (e) {
      messenger?.showSnackBar(
        SnackBar(content: Text('Échec de la mise à niveau : $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resetDb() async {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final ok = await _confirm(
      icon: Icons.delete_forever_rounded,
      title: 'Effacer les données ?',
      message: 'Toutes les données  seront supprimées.',
      confirmLabel: 'Réinitialiser',
      cancelLabel: 'Annuler',
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      await AppDatabase.I.recreate(version: 1);
    } catch (e) {
      messenger?.showSnackBar(
        SnackBar(content: Text('Échec de la réinitialisation : $e')),
      );
      setState(() => _busy = false);
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
    final res = await AppExit.requestClose(context);
    if (!mounted) return;
    if (res.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            res.message.isEmpty ? 'Fermeture en cours…' : res.message,
          ),
        ),
      );
    } else if (res.needsUserAction) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            res.message.isEmpty
                ? 'Veuillez fermer l’application/onglet manuellement.'
                : res.message,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            res.message.isEmpty ? 'Échec de la fermeture.' : res.message,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(accessSessionProvider);
    final isLoggedIn = session != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _SectionCard(
            title: 'Compte',
            children: [
              _tile(
                icon: isLoggedIn ? Icons.logout : Icons.login,
                title: isLoggedIn ? 'Se déconnecter' : 'Se connecter',
                subtitle: isLoggedIn
                    ? session.email
                    : 'Activer la synchronisation et le partage sécurisé etc...',
                onTap: _busy ? null : (isLoggedIn ? _logout : _login),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: 'Gestion',
            children: [
              _divider(),
              _tile(
                icon: Icons.swap_horiz_rounded,
                title: 'Mouvements',
                subtitle: 'Historique des entrée et sortie ',
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
                title: const Text('Effacer les données'),
                subtitle: const Text('Supprimer  toutes les données .'),
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
                leading: const Icon(Icons.tune_rounded),
                title: const Text('Paramètres de l’application'),
                subtitle: const Text(
                  'Activer/désactiver le rafraîchissement auto',
                ),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AppSettingsPage()),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.info_outline_rounded),
                title: const Text('Version de l’application'),
                subtitle: Text(Formatters.dateFull(DateTime.now())),
              ),
              _divider(),
              ListTile(
                leading: const Icon(Icons.menu_book_rounded),
                title: const Text('À propos'),
                subtitle: const Text('Informations & contacts'),
                onTap: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const AboutPage())),
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
    required VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: _busy
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.chevron_right),
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
