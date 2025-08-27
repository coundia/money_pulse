/* Standalone right-drawer that shows a French "Page en construction" message, with keyboard shortcuts and responsive layout. */
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'right_drawer.dart';

class UnderConstructionDrawer extends StatelessWidget {
  final String? featureName;
  final VoidCallback? onClose;

  const UnderConstructionDrawer({super.key, this.featureName, this.onClose});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final title = featureName?.trim().isNotEmpty == true
        ? '“$featureName” est en construction'
        : 'Page en construction';

    void _close() => Navigator.of(context).maybePop();

    Widget buildCard(bool isWide) {
      final card = Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cs.surfaceVariant.withOpacity(.35),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.construction, size: isWide ? 88 : 72, color: cs.primary),
            const SizedBox(height: 12),
            Text(
              'Cette page est en cours de création.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Merci de revenir plus tard ou d’explorer une autre section.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
      return card;
    }

    final shortcuts = <LogicalKeySet, Intent>{
      LogicalKeySet(LogicalKeyboardKey.escape): const DismissIntent(),
      LogicalKeySet(LogicalKeyboardKey.enter): const ActivateIntent(),
      LogicalKeySet(LogicalKeyboardKey.numpadEnter): const ActivateIntent(),
    };

    return Shortcuts(
      shortcuts: shortcuts,
      child: Actions(
        actions: {
          DismissIntent: CallbackAction<DismissIntent>(
            onInvoke: (_) {
              _close();
              return null;
            },
          ),
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              _close();
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: LayoutBuilder(
            builder: (context, c) {
              final isWide = c.maxWidth >= 560;

              final header = Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge,
                      textAlign: isWide ? TextAlign.start : TextAlign.center,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Fermer',
                    onPressed: _close,
                    icon: const Icon(Icons.close),
                  ),
                ],
              );

              final actionsRow = Wrap(
                alignment: isWide ? WrapAlignment.start : WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: _close,
                    icon: const Icon(Icons.check),
                    label: const Text('D’accord'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _close,
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Retour'),
                  ),
                ],
              );

              // Corps sans flex par défaut (compatible avec scroll)
              final contentColumn = Column(
                crossAxisAlignment: isWide
                    ? CrossAxisAlignment.start
                    : CrossAxisAlignment.center,
                children: [
                  header,
                  const SizedBox(height: 12),
                  // Zone principale : on enveloppe de flex SEULEMENT en layout non-scrollé
                  if (isWide)
                    Expanded(child: buildCard(isWide))
                  else
                    buildCard(isWide),
                  const SizedBox(height: 16),
                  actionsRow,
                ],
              );

              return Padding(
                padding: const EdgeInsets.all(16),
                // En narrow, on scrolle; en wide, on laisse Flex gérer la hauteur
                child: isWide
                    ? contentColumn
                    : SingleChildScrollView(child: contentColumn),
              );
            },
          ),
        ),
      ),
    );
  }
}

Future<T?> showUnderConstructionDrawer<T>(
  BuildContext context, {
  String? featureName,
  double widthFraction = 0.86,
  double heightFraction = 0.96,
  bool barrierDismissible = true,
}) {
  return showRightDrawer<T>(
    context,
    child: UnderConstructionDrawer(featureName: featureName),
    widthFraction: widthFraction,
    heightFraction: heightFraction,
    barrierDismissible: barrierDismissible,
  );
}
