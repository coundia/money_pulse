import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';

import 'report_range.dart';
import 'package:jaayko/presentation/app/providers.dart';
import 'package:jaayko/presentation/shared/formatters.dart';
import 'package:jaayko/domain/accounts/entities/account.dart';

class ReportDualLineCard extends ConsumerWidget {
  final Account account;
  final ReportRange range;

  const ReportDualLineCard({
    super.key,
    required this.account,
    required this.range,
  });

  static DateTime _strip(DateTime d) => DateTime(d.year, d.month, d.day);

  DateTime _parseDay(Map<String, Object?> row) {
    final v = row['date'] ?? row['day'] ?? row['d'];
    if (v is DateTime) return _strip(v);
    if (v is String) {
      try {
        return _strip(DateTime.parse(v));
      } catch (_) {}
    }
    if (v is int) {
      try {
        return _strip(DateTime.fromMillisecondsSinceEpoch(v));
      } catch (_) {}
    }
    return _strip(DateTime.now());
  }

  int _parseTotal(Map<String, Object?> row) {
    final v = row['total'];
    if (v is int) return v;
    if (v is num) return v.toInt();
    return 0;
  }

  Future<
    ({List<Map<String, Object?>> credit, List<Map<String, Object?>> debit})
  >
  _loadDailySeriesBoth(WidgetRef ref) async {
    final repo = ref.read(reportRepoProvider);
    final int days =
        (range.to.difference(range.from).inDays).clamp(1, 365) as int;

    final debit = await repo.dailyTotals(
      account.id,
      typeEntry: 'DEBIT',
      days: days,
    );
    final credit = await repo.dailyTotals(
      account.id,
      typeEntry: 'CREDIT',
      days: days,
    );
    return (credit: credit, debit: debit);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final debitColor = cs.error;
    final creditColor = cs.primary;
    final currency = account.currency ?? 'XOF';

    return FutureBuilder<
      ({List<Map<String, Object?>> credit, List<Map<String, Object?>> debit})
    >(
      future: _loadDailySeriesBoth(ref),
      builder: (context, seriesSnap) {
        if (seriesSnap.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 220,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final debitRows =
            seriesSnap.data?.debit ?? const <Map<String, Object?>>[];
        final creditRows =
            seriesSnap.data?.credit ?? const <Map<String, Object?>>[];

        if (debitRows.isEmpty && creditRows.isEmpty) {
          return const SizedBox(
            height: 120,
            child: Center(
              child: Text('Aucune courbe disponible sur cette période'),
            ),
          );
        }

        // X = chaque jour de [from, to)
        final start = _strip(range.from);
        final end = _strip(range.to);
        final int dayCount =
            (end.difference(start).inDays).clamp(1, 365) as int;
        final labels = List<DateTime>.generate(
          dayCount,
          (i) => start.add(Duration(days: i)),
        );

        final debitMap = <DateTime, int>{};
        for (final r in debitRows) {
          final d = _parseDay(r);
          debitMap[d] = (debitMap[d] ?? 0) + _parseTotal(r);
        }
        final creditMap = <DateTime, int>{};
        for (final r in creditRows) {
          final d = _parseDay(r);
          creditMap[d] = (creditMap[d] ?? 0) + _parseTotal(r);
        }

        final debitSpots = <FlSpot>[];
        final creditSpots = <FlSpot>[];
        for (var i = 0; i < labels.length; i++) {
          final d = labels[i];
          final dv = (debitMap[d] ?? 0) / 100.0;
          final cv = (creditMap[d] ?? 0) / 100.0;
          debitSpots.add(FlSpot(i.toDouble(), dv));
          creditSpots.add(FlSpot(i.toDouble(), cv));
        }

        final maxY = [
          ...debitSpots.map((e) => e.y),
          ...creditSpots.map((e) => e.y),
          0.0,
        ].reduce((a, b) => a > b ? a : b);
        final rawInterval = maxY == 0 ? 1.0 : maxY / 4.0;
        final double gridInterval = rawInterval < 0.25 ? 0.25 : rawInterval;

        Widget legendDot(Color c, String t) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: c, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(t),
          ],
        );

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Courbe quotidienne',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Spacer(),
                    Wrap(
                      spacing: 16,
                      children: [
                        legendDot(debitColor, 'Dépenses'),
                        legendDot(creditColor, 'Revenus'),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                SizedBox(
                  height: 220,
                  child: LineChart(
                    LineChartData(
                      minX: 0,
                      maxX: (labels.length - 1).toDouble(),
                      minY: 0,
                      maxY: (maxY == 0) ? 1 : maxY * 1.2,
                      lineTouchData: LineTouchData(
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipItems: (touched) => touched.map((e) {
                            final idx = e.x.toInt().clamp(0, labels.length - 1);
                            final day = labels[idx];
                            final cents = (e.y * 100).round();
                            final seriesName = (e.barIndex == 0)
                                ? 'Dépenses'
                                : 'Revenus';
                            return LineTooltipItem(
                              '${Formatters.dateFull(day)}\n$seriesName: ${Formatters.amountFromCents(cents)} $currency',
                              const TextStyle(fontWeight: FontWeight.w600),
                            );
                          }).toList(),
                        ),
                      ),
                      gridData: FlGridData(
                        show: true,
                        horizontalInterval: gridInterval,
                      ),
                      titlesData: FlTitlesData(
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 44,
                            getTitlesWidget: (v, meta) {
                              final cents = (v * 100).round();
                              return Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: Text(
                                  Formatters.amountFromCents(cents),
                                  style: Theme.of(context).textTheme.bodySmall,
                                  textAlign: TextAlign.right,
                                ),
                              );
                            },
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval:
                                (labels.length <= 7
                                        ? 1
                                        : (labels.length / 7).ceil())
                                    .toDouble(),
                            getTitlesWidget: (v, meta) {
                              final i = v.toInt();
                              if (i < 0 || i >= labels.length)
                                return const SizedBox.shrink();
                              final d = labels[i];
                              final short =
                                  '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  short,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        // 0 -> Dépenses
                        LineChartBarData(
                          spots: debitSpots,
                          isCurved: true,
                          barWidth: 3,
                          color: debitColor,
                          dotData: const FlDotData(show: false),
                        ),
                        // 1 -> Revenus
                        LineChartBarData(
                          spots: creditSpots,
                          isCurved: true,
                          barWidth: 3,
                          color: creditColor,
                          dotData: const FlDotData(show: false),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
