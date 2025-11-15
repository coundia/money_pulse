import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:jaayko/presentation/app/providers.dart';
import 'package:jaayko/presentation/widgets/money_text.dart';
import 'package:jaayko/domain/accounts/entities/account.dart';

import 'report_range.dart';

class ReportBreakdownList extends ConsumerWidget {
  final Account account;
  final ReportRange range;
  final bool isDebit;
  const ReportBreakdownList({
    super.key,
    required this.account,
    required this.range,
    required this.isDebit,
  });

  String _percent(num part, num total) {
    if (total == 0) return '0%';
    final p = (part / total * 100);
    return '${p.toStringAsFixed(0)}%';
  }

  List<Color> _palette(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return [
      cs.primary,
      cs.secondary,
      cs.tertiary,
      cs.error,
      cs.primaryContainer,
      cs.secondaryContainer,
      cs.tertiaryContainer,
    ].map((c) => c.withOpacity(0.85)).toList();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(reportRepoProvider);
    final future = repo.sumByCategory(
      account.id,
      typeEntry: isDebit ? 'DEBIT' : 'CREDIT',
      from: range.from,
      to: range.to,
    );

    return FutureBuilder<List<Map<String, Object?>>>(
      future: future,
      builder: (context, snap) {
        final rows = snap.data ?? const <Map<String, Object?>>[];
        if (rows.isEmpty) return const SizedBox.shrink();

        final total = rows.fold<int>(
          0,
          (p, e) => p + (e['total'] as int? ?? 0),
        );
        final palette = _palette(context);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Répartition', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...rows.asMap().entries.map((e) {
              final i = e.key;
              final r = e.value;
              final label = r['categoryCode']?.toString() ?? 'Non catégorisé';
              final v = (r['total'] as int? ?? 0);
              final percent = _percent(v, total == 0 ? 1 : total);
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: palette[i % palette.length],
                  radius: 10,
                ),
                title: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: SizedBox(
                  width: 120,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      MoneyText(
                        amountCents: v,
                        currency: account.currency ?? 'XOF',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        percent,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                subtitle: LinearProgressIndicator(
                  value: total == 0 ? 0 : v / total,
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}
