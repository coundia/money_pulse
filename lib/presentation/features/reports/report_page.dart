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
  bool isDebit = true; // true = Dépenses, false = Revenus
  ReportRange range = ReportRange.thisMonth();

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

  Future<List<Map<String, Object?>>> _loadDailySeries() async {
    final acc = await ref.read(accountRepoProvider).findDefault();
    if (acc == null) return <Map<String, Object?>>[];
    // Approximation: on demande N jours de série selon la plage choisie.
    final days = (range.to.difference(range.from).inDays).clamp(1, 365);
    return ref
        .read(reportRepoProvider)
        .dailyTotals(
          acc.id,
          typeEntry: isDebit ? 'DEBIT' : 'CREDIT',
          days: days,
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
        // Exemple lisible : « septembre 2025 »
        final d = DateTime(r.from.year, r.from.month, 1);
        // On recycle dateFull puis on simplifie (utile si ton Formatters localise déjà).
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

  // Helpers robustes pour parser la série
  DateTime _parseDay(Map<String, Object?> row) {
    final v = row['date'] ?? row['day'] ?? row['d'];
    if (v is DateTime) return v;
    if (v is String) {
      try {
        return DateTime.parse(v);
      } catch (_) {}
    }
    if (v is int) {
      try {
        return DateTime.fromMillisecondsSinceEpoch(v);
      } catch (_) {}
    }
    return DateTime.now();
  }

  int _parseTotal(Map<String, Object?> row) {
    final v = row['total'];
    if (v is int) return v;
    if (v is num) return v.toInt();
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(transactionsProvider); // pour rafraîchir après changements
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

                // ====== Courbe (journalière) ======
                FutureBuilder<List<Map<String, Object?>>>(
                  future: _loadDailySeries(),
                  builder: (context, seriesSnap) {
                    final series =
                        seriesSnap.data ?? const <Map<String, Object?>>[];
                    if (seriesSnap.connectionState == ConnectionState.waiting) {
                      return const SizedBox(
                        height: 220,
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (series.isEmpty) {
                      return const SizedBox(
                        height: 120,
                        child: Center(
                          child: Text(
                            'Aucune courbe disponible sur cette période',
                          ),
                        ),
                      );
                    }

                    // Prépare les spots & labels
                    final sorted = [...series]
                      ..sort((a, b) => _parseDay(a).compareTo(_parseDay(b)));
                    final labels = <DateTime>[];
                    final spots = <FlSpot>[];
                    for (var i = 0; i < sorted.length; i++) {
                      labels.add(_parseDay(sorted[i]));
                      spots.add(
                        FlSpot(
                          i.toDouble(),
                          (_parseTotal(sorted[i])).toDouble() / 100.0,
                        ),
                      );
                    }

                    final maxY = (spots.isEmpty
                        ? 0.0
                        : spots
                              .map((e) => e.y)
                              .reduce((a, b) => a > b ? a : b));
                    final interval = labels.length <= 7
                        ? 1
                        : (labels.length / 7).ceil();

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
                            Text(
                              'Courbe quotidienne',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 6),
                            SizedBox(
                              height: 220,
                              child: LineChart(
                                LineChartData(
                                  minX: 0,
                                  maxX: (spots.length - 1).toDouble(),
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
                                        return LineTooltipItem(
                                          '${Formatters.dateFull(day)}\n${Formatters.amountFromCents(cents)} XOF',
                                          const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                  gridData: FlGridData(
                                    show: true,
                                    horizontalInterval:
                                        (maxY == 0 ? 1 : maxY / 4)
                                            .clamp(1, maxY)
                                            .toDouble(),
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
                                        interval: interval.toDouble(),
                                        getTitlesWidget: (v, meta) {
                                          final i = v.toInt();
                                          if (i < 0 || i >= labels.length)
                                            return const SizedBox.shrink();
                                          final d = labels[i];
                                          // Etiquette courte JJ/MM
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
                                    LineChartBarData(
                                      spots: spots,
                                      isCurved: true,
                                      barWidth: 3,
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
                if (rows.isNotEmpty)
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
