import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'report_range.dart';
import 'models/report_totals.dart';

import 'package:money_pulse/domain/accounts/entities/account.dart';
import 'package:money_pulse/presentation/app/providers.dart';
import 'package:money_pulse/presentation/shared/formatters.dart';

class ReportTotalsCard extends ConsumerStatefulWidget {
  final Account account;
  final ReportRange range;

  /// Mode contrôlé (optionnel) :
  /// - true  => Dépenses actives
  /// - false => Revenus actifs
  final bool? activeIsDebit;

  /// Callback optionnel : si fourni, on est en mode contrôlé
  /// - onToggleDebitCredit(true)  => Dépenses
  /// - onToggleDebitCredit(false) => Revenus
  final ValueChanged<bool>? onToggleDebitCredit;

  const ReportTotalsCard({
    super.key,
    required this.account,
    required this.range,
    this.activeIsDebit,
    this.onToggleDebitCredit,
  });

  @override
  ConsumerState<ReportTotalsCard> createState() => _ReportTotalsCardState();
}

class _ReportTotalsCardState extends ConsumerState<ReportTotalsCard> {
  // État interne pour le mode non-contrôlé (fallback)
  late bool _localIsDebit;

  @override
  void initState() {
    super.initState();
    _localIsDebit = widget.activeIsDebit ?? true; // par défaut : Dépenses
  }

  @override
  void didUpdateWidget(covariant ReportTotalsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Si le parent contrôle et change la valeur, on la reflète
    if (widget.activeIsDebit != null &&
        widget.activeIsDebit != oldWidget.activeIsDebit &&
        widget.activeIsDebit != _localIsDebit) {
      _localIsDebit = widget.activeIsDebit!;
    }
  }

  bool get _isControlled =>
      widget.onToggleDebitCredit != null && widget.activeIsDebit != null;
  bool get _isDebit =>
      _isControlled ? (widget.activeIsDebit ?? true) : _localIsDebit;

  Future<ReportTotals> _loadTotals(WidgetRef ref) async {
    final repo = ref.read(reportRepoProvider);
    final debitRows = await repo.sumByCategory(
      widget.account.id,
      typeEntry: 'DEBIT',
      from: widget.range.from,
      to: widget.range.to,
    );
    final creditRows = await repo.sumByCategory(
      widget.account.id,
      typeEntry: 'CREDIT',
      from: widget.range.from,
      to: widget.range.to,
    );
    final debit = debitRows.fold<int>(
      0,
      (p, e) => p + (e['total'] as int? ?? 0),
    );
    final credit = creditRows.fold<int>(
      0,
      (p, e) => p + (e['total'] as int? ?? 0),
    );
    return ReportTotals(debitCents: debit, creditCents: credit);
  }

  void _toggleTo(bool isDebit) {
    HapticFeedback.selectionClick();
    if (_isControlled) {
      widget.onToggleDebitCredit?.call(isDebit);
    } else {
      setState(() => _localIsDebit = isDebit);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = "";

    return FutureBuilder<ReportTotals>(
      future: _loadTotals(ref),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Card(
            elevation: 0,
            child: SizedBox(
              height: 72,
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }
        final totals =
            snap.data ?? const ReportTotals(debitCents: 0, creditCents: 0);
        final netColor = Colors.blue;

        Widget pill({
          required String label,
          required int cents,
          required Color color,
          required IconData icon,
          required bool selected,
          VoidCallback? onTap,
          String? tooltip,
        }) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final bg = selected
              ? color.withOpacity(0.18)
              : color.withOpacity(0.10);
          final border = selected
              ? color.withOpacity(0.55)
              : color.withOpacity(0.25);
          final textColor = isDark ? Colors.white : Colors.black87;

          final child = Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: border, width: selected ? 1.4 : 1.0),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: textColor.withOpacity(0.9),
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${Formatters.amountFromCents(cents)}',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: color),
                    ),
                  ],
                ),
                // Icône check quand sélectionné
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 160),
                  transitionBuilder: (child, anim) =>
                      ScaleTransition(scale: anim, child: child),
                  child: selected
                      ? Icon(
                          Icons.check_circle,
                          key: const ValueKey('sel'),
                          size: 18,
                          color: color,
                        )
                      : const SizedBox(
                          key: ValueKey('nosel'),
                          width: 1,
                          height: 1,
                        ),
                ),
              ],
            ),
          );

          final tappable = onTap == null
              ? child
              : InkWell(
                  borderRadius: BorderRadius.circular(22),
                  onTap: onTap,
                  child: child,
                );

          return tooltip == null
              ? tappable
              : Tooltip(message: tooltip, child: tappable);
        }

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // Dépenses (cliquable) — check si actif
                  pill(
                    label: 'Dépenses',
                    cents: totals.debitCents,
                    color: Colors.red,
                    icon: Icons.south_east,
                    selected: _isDebit == true,
                    onTap: () => _toggleTo(true),
                    tooltip: 'Afficher les dépenses dans les graphes',
                  ),
                  const SizedBox(width: 10),

                  // Revenus (cliquable) — check si actif
                  pill(
                    label: 'Revenus',
                    cents: totals.creditCents,
                    color: Colors.green,
                    icon: Icons.north_east,
                    selected: _isDebit == false,
                    onTap: () => _toggleTo(false),
                    tooltip: 'Afficher les revenus dans les graphes',
                  ),
                  const SizedBox(width: 10),

                  // Net (non cliquable)
                  pill(
                    label: 'Net',
                    cents: totals.netCents,
                    color: netColor,
                    icon: totals.netCents >= 0
                        ? Icons.trending_up
                        : Icons.trending_down,
                    selected: false,
                    onTap: null,
                    tooltip: 'Revenus – Dépenses',
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
