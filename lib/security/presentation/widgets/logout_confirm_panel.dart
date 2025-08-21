/// Right-drawer confirmation panel for logout.
import 'package:flutter/material.dart';

class LogoutConfirmPanel extends StatelessWidget {
  final VoidCallback onConfirm;

  const LogoutConfirmPanel({super.key, required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Confirmer la déconnexion')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 16),
            const Text('Voulez-vous vraiment vous déconnecter ?'),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Annuler'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      onConfirm();
                    },
                    child: const Text('Se déconnecter'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
