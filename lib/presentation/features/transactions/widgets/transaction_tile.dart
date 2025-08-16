import 'package:flutter/material.dart';
import 'package:money_pulse/domain/transactions/entities/transaction_entry.dart';
import 'package:money_pulse/presentation/features/transactions/transaction_form_sheet.dart';
import 'package:money_pulse/presentation/shared/formatters.dart';
import 'package:money_pulse/presentation/widgets/right_drawer.dart';
import 'transaction_detail_view.dart';

class TransactionTile extends StatelessWidget {
  final TransactionEntry entry;
  final Future<void> Function() onDeleted;
  final Future<void> Function() onUpdated;
  final Future<void> Function(TransactionEntry entry)? onSync;

  const TransactionTile({
    super.key,
    required this.entry,
    required this.onDeleted,
    required this.onUpdated,
    this.onSync,
  });

  @override
  Widget build(BuildContext context) {
    final tone = _toneForType(context, entry.typeEntry);
    final amount = Formatters.amountFromCents(entry.amount);
    final time = Formatters.timeHm(entry.dateTransaction);

    return Dismissible(
      key: ValueKey('txn-${entry.id}'),
      direction: DismissDirection.endToStart,
      background: _buildSwipeBg(context, alignStart: true),
      secondaryBackground: _buildSwipeBg(context, alignStart: false),
      confirmDismiss: (direction) async {
        final ok = await _confirmDelete(context);
        if (!ok) return false;
        await onDeleted();
        // Empêche Dismissible de retirer l’item (la liste sera rechargée côté appelant)
        return false;
      },
      child: Semantics(
        button: true,
        label:
            '${tone.semanticLabel} de ${amount.replaceAll('\u00A0', ' ')} à $time',
        onTapHint: 'Ouvrir le détail de la transaction',
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 4,
          ),
          leading: _LeadingToneAvatar(icon: tone.icon, base: tone.color),
          title: Text(
            entry.description ?? entry.code ?? 'Transaction',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Row(
            children: [
              const Icon(Icons.schedule, size: 14),
              const SizedBox(width: 4),
              Text(time, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(width: 8),
              _TypePill(label: tone.label, color: tone.color),
              if ((entry.companyId ?? '').isNotEmpty) ...[
                const SizedBox(width: 8),
                _MetaDot(),
                const SizedBox(width: 8),
                Text('Société', style: Theme.of(context).textTheme.bodySmall),
              ],
              if ((entry.customerId ?? '').isNotEmpty) ...[
                const SizedBox(width: 8),
                _MetaDot(),
                const SizedBox(width: 8),
                Text('Client', style: Theme.of(context).textTheme.bodySmall),
              ],
            ],
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${tone.signPrefix}$amount',
                style: TextStyle(
                  color: tone.textColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              if (tone.trailingHint != null)
                Text(
                  tone.trailingHint!,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: tone.color.withOpacity(0.9),
                  ),
                ),
            ],
          ),
          onTap: () async {
            final ok = await showRightDrawer<bool>(
              context,
              child: TransactionDetailView(entry: entry),
              widthFraction: 0.86,
              heightFraction: 0.96,
            );
            if (ok == true) await onUpdated();
          },
          onLongPress: () => _openContextMenu(context),
        ),
      ),
    );
  }

  // ————————————————— UI helpers —————————————————

  static Widget _buildSwipeBg(
    BuildContext context, {
    required bool alignStart,
  }) {
    final danger = Theme.of(context).colorScheme.error;
    final child = Row(
      mainAxisAlignment: alignStart
          ? MainAxisAlignment.start
          : MainAxisAlignment.end,
      children: [
        if (alignStart) const SizedBox(width: 16),
        const Icon(Icons.delete_outline, color: Colors.white),
        const SizedBox(width: 8),
        const Text('Supprimer', style: TextStyle(color: Colors.white)),
        if (!alignStart) const SizedBox(width: 16),
      ],
    );
    return Container(
      color: danger,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: child,
    );
  }

  static Future<bool> _confirmDelete(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (dCtx) => AlertDialog(
            title: const Text('Confirmer la suppression'),
            content: const Text('Supprimer cette transaction ?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dCtx, false),
                child: const Text('Annuler'),
              ),
              FilledButton.tonal(
                onPressed: () => Navigator.pop(dCtx, true),
                child: const Text('Supprimer'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _openContextMenu(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.visibility_outlined),
                title: const Text('Voir'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await showRightDrawer<void>(
                    context,
                    child: TransactionDetailView(entry: entry),
                    widthFraction: 0.86,
                    heightFraction: 0.96,
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Modifier'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final ok = await showRightDrawer<bool>(
                    context,
                    child: TransactionFormSheet(entry: entry),
                    widthFraction: 0.86,
                    heightFraction: 0.96,
                  );
                  if (ok == true) await onUpdated();
                },
              ),
              ListTile(
                leading: const Icon(Icons.sync_outlined),
                title: const Text('Synchroniser'),
                onTap: () async {
                  Navigator.pop(ctx);
                  if (onSync != null) {
                    await onSync!(entry);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Synchronisation indisponible'),
                      ),
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Supprimer'),
                textColor: Colors.red,
                onTap: () async {
                  Navigator.pop(ctx);
                  final ok = await _confirmDelete(context);
                  if (ok) await onDeleted();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}

// ————————————————— Styles & petits widgets —————————————————

class _TypePill extends StatelessWidget {
  final String label;
  final Color color;
  const _TypePill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    final bg = color.withOpacity(0.12);
    final fg = color.withOpacity(0.95);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: fg.withOpacity(0.35), width: 0.8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.w700,
          fontSize: 11,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _MetaDot extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme.outline.withOpacity(0.45);
    return Container(
      width: 4,
      height: 4,
      decoration: BoxDecoration(color: c, shape: BoxShape.circle),
    );
  }
}

class _LeadingToneAvatar extends StatelessWidget {
  final IconData icon;
  final Color base;
  const _LeadingToneAvatar({required this.icon, required this.base});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hsl = HSLColor.fromColor(base);
    final c1 = hsl
        .withLightness((hsl.lightness + (isDark ? 0.12 : 0.22)).clamp(0, 1))
        .toColor();
    final c2 = hsl
        .withLightness((hsl.lightness - (isDark ? 0.10 : 0.06)).clamp(0, 1))
        .toColor();

    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [c1.withOpacity(0.35), c2.withOpacity(0.55)],
        ),
      ),
      child: Icon(icon, color: base.withOpacity(isDark ? 0.95 : 0.85)),
    );
  }
}

// ————————————————— Tone logic —————————————————

class _Tone {
  final Color color;
  final IconData icon;
  final String label;
  final String signPrefix; // "+", "-", ou "" (DEBT)
  final String semanticLabel; // pour l’accessibilité
  final String? trailingHint; // ex: "Dette", "Remb."
  final Color textColor;

  _Tone({
    required this.color,
    required this.icon,
    required this.label,
    required this.signPrefix,
    required this.semanticLabel,
    required this.textColor,
    this.trailingHint,
  });
}

_Tone _toneForType(BuildContext context, String type) {
  final scheme = Theme.of(context).colorScheme;
  final upper = type.toUpperCase();

  switch (upper) {
    case 'DEBIT':
      return _Tone(
        color: scheme.error,
        icon: Icons.south,
        label: 'Dépense',
        signPrefix: '−',
        semanticLabel: 'Dépense',
        textColor: scheme.error,
      );
    case 'CREDIT':
      return _Tone(
        color: scheme.tertiary, // souvent “green-like” dans les thèmes MD3
        icon: Icons.north,
        label: 'Revenu',
        signPrefix: '+',
        semanticLabel: 'Revenu',
        textColor: scheme.tertiary,
      );
    case 'REMBOURSEMENT':
      return _Tone(
        color: Colors.teal,
        icon: Icons.undo_rounded,
        label: 'Remboursement',
        signPrefix: '+',
        semanticLabel: 'Remboursement',
        textColor: Colors.teal.shade700,
        trailingHint: 'Remb.',
      );
    case 'PRET':
      return _Tone(
        color: Colors.purple,
        icon: Icons.account_balance_outlined,
        label: 'Prêt',
        signPrefix: '−',
        semanticLabel: 'Prêt',
        textColor: Colors.purple.shade700,
        trailingHint: 'Prêt',
      );
    case 'DEBT':
      return _Tone(
        color: Colors.amber.shade800,
        icon: Icons.receipt_long,
        label: 'Dette',
        signPrefix: '', // compte souvent nul → pas de signe visuel
        semanticLabel: 'Dette',
        textColor: Colors.amber.shade800,
        trailingHint: 'Dette',
      );
    default:
      return _Tone(
        color: scheme.primary,
        icon: Icons.receipt_long,
        label: upper,
        signPrefix: '',
        semanticLabel: 'Transaction',
        textColor: scheme.primary,
      );
  }
}
