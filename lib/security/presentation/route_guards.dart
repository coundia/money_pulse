/// Helpers to protect routes without external router dependencies.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/auth_providers.dart';

Route<dynamic> protectedRoute(
  WidgetRef ref, {
  required RouteSettings settings,
  required WidgetBuilder builder,
}) {
  final user = ref.read(authControllerProvider).user;
  if (user == null) {
    return MaterialPageRoute(
      builder: (_) => const _Empty(),
      settings: settings,
    );
  }
  return MaterialPageRoute(builder: builder, settings: settings);
}

class _Empty extends StatelessWidget {
  const _Empty({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(body: SizedBox.shrink());
}
