// App root that returns the first page (HomePage) and wires basic logs for visibility.

import 'package:flutter/material.dart';
import 'package:jaayko/presentation/app/log.dart';
import 'package:jaayko/presentation/features/home/home_page.dart';

class AppRoot extends StatelessWidget {
  const AppRoot({super.key});

  @override
  Widget build(BuildContext context) {
    Log.d('AppRoot.build', tag: 'AppRoot');
    return const HomePage();
  }
}
