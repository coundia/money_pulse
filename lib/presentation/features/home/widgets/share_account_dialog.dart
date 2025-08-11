import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:money_pulse/domain/accounts/entities/account.dart';

/// Affiche une boite de dialogue permettant de partager/copier les infos d’un compte.
Future<void> showShareAccountDialog({
  required BuildContext context,
  required Account acc,
}) async {
  final text = 'Account ${acc.code ?? ''} (${acc.id})';

  await showDialog<void>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Share account'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Code: ${acc.code ?? '-'}'),
          const SizedBox(height: 6),
          const Text('ID:', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          SelectableText(acc.id),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: text));
            if (context.mounted) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Copied to clipboard')),
              );
            }
          },
          child: const Text('Copy'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}
