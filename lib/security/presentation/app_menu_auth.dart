/// App bar actions helper to show profile and implicit logout.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/auth_providers.dart';
import 'widgets/profile_button.dart';

class AppMenuAuth extends ConsumerWidget {
  const AppMenuAuth({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    if (user == null) {
      return TextButton(
        onPressed: () => Navigator.of(context).pushNamed('/login'),
        child: const Text('Se connecter'),
      );
    }
    return const Row(children: [ProfileButton()]);
  }
}
