import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_pulse/presentation/features/categories/category_list_page.dart';
import 'package:money_pulse/presentation/features/accounts/account_page.dart';
import 'package:money_pulse/presentation/shared/formatters.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
