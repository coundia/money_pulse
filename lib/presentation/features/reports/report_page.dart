import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:money_pulse/presentation/app/providers.dart';
import 'package:money_pulse/presentation/widgets/money_text.dart';

class ReportPage extends ConsumerStatefulWidget {
  const ReportPage({super.key});

  @override
  ConsumerState<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends ConsumerState<ReportPage> {
  bool isDebit = true;
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month, 1);

  DateTime _firstOfMonth(DateTime d) => DateTime(d.year, d.month, 1);
  DateTime _nextMonth(DateTime d) => DateTime(d.year, d.month + 1, 1);
  DateTime _prevMonth(DateTime d) => DateTime(d.year, d.month - 1, 1);

  Future<List<Map<String, Object?>>> _load() async {
    final acc = await ref.read(accountRepoProvider).findDefault();
    if (acc == null) return <Map<String, Object?>>[];
    return ref
        .read(reportRepoProvider)
        .sumByCategoryForMonth(
          acc.id,
          typeEntry: isDebit ? 'DEBIT' : 'CREDIT',
          month: month,
        );
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

  String _percent(num part, num total) {
    if (total == 0) return '0%';
    final p = (part / total * 100);
    return '${p.toStringAsFixed(0)}%';
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(transactionsProvider);
    final monthLabel = DateFormat.yMMMM().format(month);

    return Scaffold(
      appBar: AppBar(title: const Text('Report')),
      body: FutureBuilder<List<Map<String, Object?>>>(
        future: _load(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final rows = snap.data ?? <Map<String, Object?>>[];
          final total = rows.fold<int>(
            0,
            (p, e) => p + (e['total'] as int? ?? 0),
          );
          final palette = _palette(context);

          final sections = <PieChartSectionData>[];
          for (var i = 0; i < rows.length; i++) {
            final r = rows[i];
            final v = (r['total'] as int? ?? 0).toDouble();
            sections.add(
              PieChartSectionData(
                value: v,
                title: '',
                color: palette[i % palette.length],
                radius: 70,
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => setState(() {}),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            IconButton(
                              tooltip: 'Previous month',
                              icon: const Icon(Icons.chevron_left),
                              onPressed: () =>
                                  setState(() => month = _prevMonth(month)),
                            ),
                            Expanded(
                              child: Center(
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 200),
                                  transitionBuilder: (child, anim) =>
                                      FadeTransition(
                                        opacity: anim,
                                        child: child,
                                      ),
                                  child: Text(
                                    monthLabel,
                                    key: ValueKey(monthLabel),
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Next month',
                              icon: const Icon(Icons.chevron_right),
                              onPressed: () =>
                                  setState(() => month = _nextMonth(month)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        SegmentedButton<bool>(
                          segments: const [
                            ButtonSegment(value: true, label: Text('Expense')),
                            ButtonSegment(value: false, label: Text('Income')),
                          ],
                          selected: {isDebit},
                          onSelectionChanged: (s) =>
                              setState(() => isDebit = s.first),
                        ),
                        const SizedBox(height: 6),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () => setState(
                              () => month = _firstOfMonth(DateTime.now()),
                            ),
                            icon: const Icon(Icons.today),
                            label: const Text('This month'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (rows.isEmpty)
                  const SizedBox(
                    height: 220,
                    child: Center(child: Text('No data for this month')),
                  )
                else
                  SizedBox(
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
                              currency: 'XOF',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            Text(
                              (isDebit ? 'Expense · ' : 'Income · ') +
                                  monthLabel,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
                if (rows.isNotEmpty) ...[
                  Text(
                    'Breakdown',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  ...rows.asMap().entries.map((e) {
                    final i = e.key;
                    final r = e.value;
                    final label =
                        r['categoryCode']?.toString() ?? 'Uncategorized';
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
                        width: 110,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            MoneyText(
                              amountCents: v,
                              currency: 'XOF',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
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
                const SizedBox(height: 8),
                if (rows.isNotEmpty)
                  Text(
                    'Updated ${DateFormat.yMMMd().add_Hm().format(DateTime.now())}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
