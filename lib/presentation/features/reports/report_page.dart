import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:money_pulse/presentation/app/providers.dart';
import 'package:money_pulse/presentation/shared/formatters.dart';
import 'package:money_pulse/presentation/widgets/money_text.dart';
import 'report_range.dart';

class ReportPage extends ConsumerStatefulWidget {
  const ReportPage({super.key});

  @override
  ConsumerState<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends ConsumerState<ReportPage> {
  /// true = Dépenses, false = Revenus (pour le camembert uniquement)
  bool isDebit = true;
  ReportRange range = ReportRange.thisMonth();

  // ----- Catégories (camembert) -----
  Future<List<Map<String, Object?>>> _loadCategories() async {
    final acc = await ref.read(accountRepoProvider).findDefault();
    if (acc == null) return <Map<String, Object?>>[];
    return ref
        .read(reportRepoProvider)
        .sumByCategory(
          acc.id,
          typeEntry: isDebit ? 'DEBIT' : 'CREDIT',
          from: range.from,
          to: range.to,
        );
  }

  // ----- Série journalière (2 séries: DEBIT & CREDIT) -----
  Future<
    ({List<Map<String, Object?>> credit, List<Map<String, Object?>> debit})
  >
  _loadDailySeriesBoth() async {
    final acc = await ref.read(accountRepoProvider).findDefault();
    if (acc == null) {
      return (
        credit: <Map<String, Object?>>[],
        debit: <Map<String, Object?>>[],
      );
    }

    // clamp renvoie num -> cast en int
    final int days =
        (range.to.difference(range.from).inDays).clamp(1, 365) as int;

    final List<Map<String, Object?>> debit = await ref
        .read(reportRepoProvider)
        .dailyTotals(acc.id, typeEntry: 'DEBIT', days: days);

    final List<Map<String, Object?>> credit = await ref
        .read(reportRepoProvider)
        .dailyTotals(acc.id, typeEntry: 'CREDIT', days: days);

    // IMPORTANT: l’ordre doit correspondre au type du record
    return (credit: credit, debit: debit);
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

  Future<void> _pickCustomRange() async {
    final initial = DateTimeRange(
      start: range.from,
      end: range.to.subtract(const Duration(milliseconds: 1)),
    );
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: initial,
    );
    if (picked != null) {
      setState(() => range = ReportRange.custom(picked.start, picked.end));
    }
  }

  String _rangeLabel(ReportRange r) {
    switch (r.kind) {
      case ReportRangeKind.today:
        return 'Aujourd’hui';
      case ReportRangeKind.thisWeek:
        return 'Cette semaine';
      case ReportRangeKind.thisMonth:
        final d = DateTime(r.from.year, r.from.month, 1);
        // Affiche « mois année » (ex: septembre 2025)
        return Formatters.dateFull(d).split(' ').sublist(1).join(' ');
      case ReportRangeKind.thisYear:
        return 'Cette année';
      case ReportRangeKind.custom:
        final left = Formatters.dateFull(r.from);
        final right = Formatters.dateFull(
          r.to.subtract(const Duration(milliseconds: 1)),
        );
        return '$left – $right';
    }
  }

  // ---- Helpers parse série ----
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

  @override
  Widget build(BuildContext context) {
    // pour rafraîchir après changements
    ref.watch(transactionsProvider);

    final titleLabel = isDebit ? 'Dépenses' : 'Revenus';
    final rangeLabel = _rangeLabel(range);

    return Scaffold(
      appBar: AppBar(title: const Text('Rapport')),
      body: FutureBuilder<List<Map<String, Object?>>>(
        future: _loadCategories(),
        builder: (context, catSnap) {
          final rows = catSnap.data ?? <Map<String, Object?>>[];
          final total = rows.fold<int>(
            0,
            (p, e) => p + (e['total'] as int? ?? 0),
          );
          final palette = _palette(context);

          final sections = <PieChartSectionData>[
            for (var i = 0; i < rows.length; i++)
              PieChartSectionData(
                value: ((rows[i]['total'] as int? ?? 0)).toDouble(),
                title: '',
                color: palette[i % palette.length],
                radius: 70,
              ),
          ];

          return RefreshIndicator(
            onRefresh: () async => setState(() {}),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ====== Sélecteurs (période + type) ======
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
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            FilterChip(
                              avatar: const Icon(Icons.today, size: 18),
                              label: const Text('Aujourd’hui'),
                              selected: range.kind == ReportRangeKind.today,
                              onSelected: (_) =>
                                  setState(() => range = ReportRange.today()),
                            ),
                            FilterChip(
                              avatar: const Icon(Icons.view_week, size: 18),
                              label: const Text('Cette semaine'),
                              selected: range.kind == ReportRangeKind.thisWeek,
                              onSelected: (_) => setState(
                                () => range = ReportRange.thisWeek(),
                              ),
                            ),
                            FilterChip(
                              avatar: const Icon(
                                Icons.calendar_view_month,
                                size: 18,
                              ),
                              label: const Text('Ce mois-ci'),
                              selected: range.kind == ReportRangeKind.thisMonth,
                              onSelected: (_) => setState(
                                () => range = ReportRange.thisMonth(),
                              ),
                            ),
                            FilterChip(
                              avatar: const Icon(
                                Icons.calendar_month,
                                size: 18,
                              ),
                              label: const Text('Cette année'),
                              selected: range.kind == ReportRangeKind.thisYear,
                              onSelected: (_) => setState(
                                () => range = ReportRange.thisYear(),
                              ),
                            ),
                            ActionChip(
                              avatar: const Icon(Icons.date_range, size: 18),
                              label: const Text('Plage personnalisée'),
                              onPressed: _pickCustomRange,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () =>
                                setState(() => range = ReportRange.today()),
                            icon: const Icon(Icons.restart_alt),
                            label: const Text('Revenir à aujourd’hui'),
                          ),
                        ),
                        const SizedBox(height: 6),
                        // Ce toggle ne concerne que le camembert
                        SegmentedButton<bool>(
                          segments: const [
                            ButtonSegment(value: true, label: Text('Dépenses')),
                            ButtonSegment(value: false, label: Text('Revenus')),
                          ],
                          selected: {isDebit},
                          onSelectionChanged: (s) =>
                              setState(() => isDebit = s.first),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // ====== Camembert ======
                if (catSnap.connectionState == ConnectionState.waiting)
                  const SizedBox(
                    height: 220,
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (rows.isEmpty)
                  const SizedBox(
                    height: 220,
                    child: Center(
                      child: Text('Aucune donnée pour cette période'),
                    ),
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
                              '$titleLabel · $rangeLabel',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 16),

                // ====== Courbe (Débit + Crédit) ======
                FutureBuilder<
                  ({
                    List<Map<String, Object?>> credit,
                    List<Map<String, Object?>> debit,
                  })
                >(
                  future: _loadDailySeriesBoth(),
                  builder: (context, seriesSnap) {
                    final List<Map<String, Object?>> debitRows =
                        seriesSnap.data?.debit ??
                        const <Map<String, Object?>>[];
                    final List<Map<String, Object?>> creditRows =
                        seriesSnap.data?.credit ??
                        const <Map<String, Object?>>[];

                    if (seriesSnap.connectionState == ConnectionState.waiting) {
                      return const SizedBox(
                        height: 220,
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (debitRows.isEmpty && creditRows.isEmpty) {
                      return const SizedBox(
                        height: 120,
                        child: Center(
                          child: Text(
                            'Aucune courbe disponible sur cette période',
                          ),
                        ),
                      );
                    }

                    // Échelle X : chaque jour de [from, to)
                    final start = _strip(range.from);
                    final end = _strip(range.to);
                    final int dayCount =
                        (end.difference(start).inDays).clamp(1, 365) as int;
                    final labels = List<DateTime>.generate(
                      dayCount,
                      (i) => start.add(Duration(days: i)),
                    );

                    // Indexation par jour
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

                    // Spots
                    final debitSpots = <FlSpot>[];
                    final creditSpots = <FlSpot>[];
                    for (var i = 0; i < labels.length; i++) {
                      final d = labels[i];
                      final dv = (debitMap[d] ?? 0) / 100.0;
                      final cv = (creditMap[d] ?? 0) / 100.0;
                      debitSpots.add(FlSpot(i.toDouble(), dv));
                      creditSpots.add(FlSpot(i.toDouble(), cv));
                    }

                    // Couleurs
                    final cs = Theme.of(context).colorScheme;
                    final debitColor = cs.error; // rouge
                    final creditColor = cs.primary;

                    final maxY = [
                      ...debitSpots.map((e) => e.y),
                      ...creditSpots.map((e) => e.y),
                      0.0,
                    ].reduce((a, b) => a > b ? a : b);

                    final rawInterval = maxY == 0 ? 1.0 : maxY / 4.0;
                    final double gridInterval = rawInterval < 0.25
                        ? 0.25
                        : rawInterval;

                    // Légende
                    Widget legendDot(Color c, String t) => Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                          ),
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
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
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
                                      getTooltipItems: (touched) => touched.map((
                                        e,
                                      ) {
                                        final idx = e.x.toInt().clamp(
                                          0,
                                          labels.length - 1,
                                        );
                                        final day = labels[idx];
                                        final cents = (e.y * 100).round();
                                        final seriesName = (e.barIndex == 0)
                                            ? 'Dépenses'
                                            : 'Revenus';
                                        return LineTooltipItem(
                                          '${Formatters.dateFull(day)}\n$seriesName: ${Formatters.amountFromCents(cents)} XOF',
                                          const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
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
                                            padding: const EdgeInsets.only(
                                              right: 6,
                                            ),
                                            child: Text(
                                              Formatters.amountFromCents(cents),
                                              style: Theme.of(
                                                context,
                                              ).textTheme.bodySmall,
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
                                                    : (labels.length / 7)
                                                          .ceil())
                                                .toDouble(),
                                        getTitlesWidget: (v, meta) {
                                          final i = v.toInt();
                                          if (i < 0 || i >= labels.length) {
                                            return const SizedBox.shrink();
                                          }
                                          final d = labels[i];
                                          final short =
                                              '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
                                          return Padding(
                                            padding: const EdgeInsets.only(
                                              top: 6,
                                            ),
                                            child: Text(
                                              short,
                                              style: Theme.of(
                                                context,
                                              ).textTheme.bodySmall,
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                  borderData: FlBorderData(show: false),
                                  lineBarsData: [
                                    // index 0 -> Dépenses
                                    LineChartBarData(
                                      spots: debitSpots,
                                      isCurved: true,
                                      barWidth: 3,
                                      color: debitColor,
                                      dotData: const FlDotData(show: false),
                                    ),
                                    // index 1 -> Revenus
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
                ),

                const SizedBox(height: 16),

                // ====== Répartition (liste) ======
                if (rows.isNotEmpty) ...[
                  Text(
                    'Répartition',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  ...rows.asMap().entries.map((e) {
                    final i = e.key;
                    final r = e.value;
                    final label =
                        r['categoryCode']?.toString() ?? 'Non catégorisé';
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
                Text(
                  'Mis à jour ${Formatters.dateFull(DateTime.now())}',
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
