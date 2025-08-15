// Right-drawer panel to configure HomePage UI preferences (bottom navigation visibility).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'home_ui_prefs_provider.dart';

class HomeUiPrefsPanel extends ConsumerWidget {
  const HomeUiPrefsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(homeUiPrefsProvider);
    final ctrl = ref.read(homeUiPrefsProvider.notifier);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Text('Interface', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            SwitchListTile.adaptive(
              title: const Text('Afficher la barre de navigation en bas'),
              value: prefs.showBottomNav,
              onChanged: (v) => ctrl.setShowBottomNav(v),
            ),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: () => ctrl.reset(),
              child: const Text('Réinitialiser'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: const Text('Fermer'),
            ),
          ],
        ),
      ),
    );
  }
}
