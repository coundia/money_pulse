import 'package:flutter/material.dart';
import 'package:money_pulse/presentation/features/home/home_page.dart';

class AppRoot extends StatelessWidget {
  const AppRoot({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Money Pulse',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF2563EB),
      ),
      home: const HomePage(),
    );
  }
}
