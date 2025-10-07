// lib/presentation/features/transactions/detail/widgets/section_card.dart

import 'package:flutter/material.dart';

class SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const SectionCard({super.key, required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const Divider(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }
}
