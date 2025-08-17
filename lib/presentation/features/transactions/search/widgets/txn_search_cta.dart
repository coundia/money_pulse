// Compact CTA card to open transaction search quickly; French label and neutral hint color.

import 'package:flutter/material.dart';

class TxnSearchCta extends StatelessWidget {
  final VoidCallback onTap;
  final String text;

  const TxnSearchCta({
    super.key,
    required this.onTap,
    this.text = 'Rechercher des transactions',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hintColor = theme.colorScheme.onSurfaceVariant;

    return SafeArea(
      top: false,
      child: Card(
        elevation: 0,
        margin: const EdgeInsets.fromLTRB(0, 0, 0, 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: SizedBox(
              width: double.infinity,
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.search, color: hintColor),
                    const SizedBox(width: 10),
                    Text(
                      text,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: hintColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
