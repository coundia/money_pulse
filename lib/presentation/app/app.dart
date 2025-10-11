import 'package:flutter/material.dart';
import 'package:money_pulse/presentation/features/home/home_page.dart';

/// AppRoot ne doit PAS créer un second MaterialApp.
/// On renvoie juste la page racine de l'app.
/// Le seul MaterialApp se trouve dans le Bootstrap (main.dart).
class AppRoot extends StatelessWidget {
  const AppRoot({super.key});

  @override
  Widget build(BuildContext context) {
    return const HomePage();
  }
}
