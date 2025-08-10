import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:money_pulse/presentation/app/providers.dart';

class ReportPage extends ConsumerWidget {
  const ReportPage({super.key});

  Future<List<Map<String, Object?>>> _load(WidgetRef ref) async {
    final acc = await ref.read(accountRepoProvider).findDefault();
    if (acc == null) return <Map<String, Object?>>[];
    return ref
        .read(transactionRepoProvider)
        .spendingByCategoryLast30Days(acc.id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<List<Map<String, Object?>>>(
      future: _load(ref),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final rows = snap.data ?? <Map<String, Object?>>[];
        if (rows.isEmpty) return const Center(child: Text('No data'));
        final total = rows.fold<int>(
          0,
          (p, e) => p + (e['total'] as int? ?? 0),
        );
        final sections = <PieChartSectionData>[];
        for (var i = 0; i < rows.length; i++) {
          final r = rows[i];
          final v = (r['total'] as int? ?? 0).toDouble();
          final label = r['categoryCode']?.toString() ?? 'Uncategorized';
          sections.add(PieChartSectionData(value: v, title: label, radius: 60));
        }
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Text('Spending last 30 days'),
              const SizedBox(height: 12),
              SizedBox(
                height: 240,
                child: PieChart(
                  PieChartData(
                    sections: sections,
                    sectionsSpace: 2,
                    centerSpaceRadius: 0,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text('Total ${(total ~/ 100)}'),
            ],
          ),
        );
      },
    );
  }
}
