import 'package:flutter/material.dart';

class TransactionSummaryCard extends StatelessWidget {
  final String periodLabel;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onTapPeriod;
  final String expenseText;
  final String incomeText;
  final String netText;
  final bool netPositive;
  final VoidCallback onOpenReport;
  final VoidCallback? onAddExpense;
  final VoidCallback? onAddIncome;

  const TransactionSummaryCard({
    super.key,
    required this.periodLabel,
    required this.onPrev,
    required this.onNext,
    required this.onTapPeriod,
    required this.expenseText,
    required this.incomeText,
    required this.netText,
    required this.netPositive,
    required this.onOpenReport,
    this.onAddExpense,
    this.onAddIncome,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'Previous',
                  icon: const Icon(Icons.chevron_left),
                  onPressed: onPrev,
                ),
                Expanded(
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      transitionBuilder: (c, a) =>
                          FadeTransition(opacity: a, child: c),
                      child: InkWell(
                        key: ValueKey(periodLabel),
                        onTap: onTapPeriod,
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.calendar_month, size: 18),
                              const SizedBox(width: 6),
                              Text(
                                periodLabel,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Next',
                  icon: const Icon(Icons.chevron_right),
                  onPressed: onNext,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _summaryText(context, 'Expense', expenseText, Colors.red),
                _summaryText(context, 'Income', incomeText, Colors.green),
                _summaryText(
                  context,
                  'Net',
                  netText,
                  netPositive ? Colors.green : Colors.red,
                ),
                IconButton(
                  tooltip: 'Report',
                  icon: const Icon(Icons.pie_chart),
                  onPressed: onOpenReport,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onAddExpense,
                    icon: const Icon(Icons.remove_circle_outline),
                    label: const Text('Add expense'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.redAccent.withOpacity(0.12),
                      foregroundColor: Colors.red.shade700,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onAddIncome,
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text('Add income'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.greenAccent.withOpacity(0.12),
                      foregroundColor: Colors.green.shade800,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryText(
    BuildContext context,
    String label,
    String value,
    Color color,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(color: color, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}
