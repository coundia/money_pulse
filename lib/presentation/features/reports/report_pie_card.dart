import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';

import 'report_range.dart';
import 'package:jaayko/domain/accounts/entities/account.dart';
import 'package:jaayko/presentation/app/providers.dart';
import 'package:jaayko/presentation/widgets/money_text.dart';

class ReportPieCard extends ConsumerWidget {
  final Account account;
  final ReportRange range;
  final bool isDebit;

  const ReportPieCard({
    super.key,
    required this.account,
    required this.range,
    required this.isDebit,
  });

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
        if (snap.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 220,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final rows = snap.data ?? const <Map<String, Object?>>[];
        if (rows.isEmpty) {
          return const SizedBox(
            height: 220,
            child: Center(child: Text('Aucune donnée pour cette période')),
          );
        }
        final palette = _palette(context);
        final currency = account.currency ?? 'XOF';
        final total = rows.fold<int>(
          0,
          (p, e) => p + (e['total'] as int? ?? 0),
        );
        final sections = <PieChartSectionData>[
          for (var i = 0; i < rows.length; i++)
            PieChartSectionData(
              value: ((rows[i]['total'] as int? ?? 0)).toDouble(),
              title: '',
              color: palette[i % palette.length],
              radius: 70,
            ),
        ];

        return SizedBox(
          height: 260,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  sections: sections,
                  sectionsSpace: 2,
                  centerSpaceRadius: 60,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  MoneyText(
                    amountCents: total,
                    currency: currency,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(
                    isDebit ? 'Dépenses' : 'Revenus',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
