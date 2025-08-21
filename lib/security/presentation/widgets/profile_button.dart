/// Profile button that opens a right-drawer with logout action.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_providers.dart';
import 'logout_confirm_panel.dart';
import 'package:money_pulse/presentation/widgets/right_drawer.dart';

class ProfileButton extends ConsumerWidget {
  const ProfileButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final user = auth.user;

    return PopupMenuButton<String>(
      tooltip: 'Profil',
      icon: CircleAvatar(
        child: Text((user?.name?.substring(0, 1).toUpperCase() ?? 'U')),
      ),
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          value: 'profile',
          child: Text(user?.name ?? 'Mon profil'),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'logout',
          child: Text('Se déconnecter'),
        ),
      ],
      onSelected: (v) async {
        if (v == 'logout') {
          await showRightDrawer<void>(
            context,
            child: LogoutConfirmPanel(
              onConfirm: () =>
                  ref.read(authControllerProvider.notifier).logout(),
            ),
            widthFraction: 0.86,
          );
        }
      },
    );
  }
}
