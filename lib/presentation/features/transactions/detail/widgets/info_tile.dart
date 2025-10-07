// lib/presentation/features/transactions/detail/widgets/info_tile.dart

import 'package:flutter/material.dart';

class InfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Widget? trailing;

  const InfoTile({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(value),
      trailing: trailing,
    );
  }
}
