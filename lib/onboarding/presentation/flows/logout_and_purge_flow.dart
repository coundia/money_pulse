// Flow to confirm logout, push sync, clear session, purge local db, then restart.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_pulse/presentation/widgets/right_drawer.dart';
import 'package:money_pulse/presentation/features/settings/widgets/confirm_panel.dart';
import 'package:money_pulse/onboarding/presentation/providers/access_session_provider.dart';
import 'package:money_pulse/infrastructure/db/app_database.dart';
import 'package:money_pulse/presentation/app/restart_app.dart';
import 'package:money_pulse/sync/sync_service_provider.dart';

Future<void> runLogoutAndPurgeFlow(BuildContext context, WidgetRef ref) async {
  final ok = await showRightDrawer<bool>(
    context,
    child: const ConfirmPanel(
      icon: Icons.logout,
      title: 'Se déconnecter ?',
      message:
          'Toutes les modifications seront synchronisées avant la déconnexion. Les données locales seront ensuite effacées.',
      confirmLabel: 'Continuer',
      cancelLabel: 'Annuler',
    ),
    widthFraction: 0.86,
    heightFraction: 0.5,
  );
  if (ok != true) return;

  final messenger = ScaffoldMessenger.maybeOf(context);

  try {
    await syncAllTables(ref);
  } catch (_) {
    messenger?.showSnackBar(
      const SnackBar(
        content: Text('Échec de synchronisation. Déconnexion annulée.'),
      ),
    );
    return;
  }

  await ref.read(accessSessionProvider.notifier).clear();

  try {
    await AppDatabase.I.recreate(version: 1);
  } catch (_) {
    messenger?.showSnackBar(
      const SnackBar(content: Text('Échec de nettoyage local.')),
    );
    return;
  }

  messenger?.showSnackBar(
    const SnackBar(content: Text('Session fermée. Redémarrage…')),
  );
  WidgetsBinding.instance.addPostFrameCallback((_) {
    RestartApp.restart(context);
  });
}
