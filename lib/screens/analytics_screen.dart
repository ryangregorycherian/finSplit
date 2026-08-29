import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../providers/expense_provider.dart';
import '../providers/group_provider.dart';
import '../widgets/expense_tile.dart';

const List<Color> _palette = [
  Color(0xFF4F86C6),
  Color(0xFFE07A5F),
  Color(0xFF81B29A),
  Color(0xFFF2CC8F),
  Color(0xFF9B5DE5),
];

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final groupProvider = context.watch<GroupProvider>();
    final expenseProvider = context.watch<ExpenseProvider>();

    if (groupProvider.activeGroupId == null) return const Center(child: Text('No active group'));

    final categoryTotals = expenseProvider.categoryBreakdown;
    final monthlyTotals = expenseProvider.monthlyBreakdown;

    if (categoryTotals.isEmpty) {
      return const Center(child: Text('Log some expenses to see analytics.'));
    }

    final categoryEntries = categoryTotals.entries.toList();
    final monthEntries = monthlyTotals.entries.toList()..sort((a, b) => a.key.compareTo(b.key));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Spend by category', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        SizedBox(
          height: 220,
          child: PieChart(
            PieChartData(
              sections: [
                for (int i = 0; i < categoryEntries.length; i++)
                  PieChartSectionData(
                    value: categoryEntries[i].value,
                    title: categoryEntries[i].key,
                    color: _palette[i % _palette.length],
                    radius: 90,
                    titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
              ],
              sectionsSpace: 2,
              centerSpaceRadius: 30,
            ),
          ),
        ),
        const SizedBox(height: 28),
        Text('Monthly trend', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        SizedBox(
          height: 220,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      final i = value.toInt();
                      if (i < 0 || i >= monthEntries.length) return const SizedBox();
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(monthEntries[i].key.substring(5), style: const TextStyle(fontSize: 11)),
                      );
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              barGroups: [
                for (int i = 0; i < monthEntries.length; i++)
                  BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: monthEntries[i].value,
                        color: _palette[i % _palette.length],
                        width: 22,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        // Simple legend so category colors are readable without hovering.
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            for (int i = 0; i < categoryEntries.length; i++)
              Chip(
                avatar: CircleAvatar(backgroundColor: _palette[i % _palette.length]),
                label: Text('${categoryEntries[i].key}: ₹${categoryEntries[i].value.toStringAsFixed(0)}'),
              ),
          ],
        ),
        const SizedBox(height: 80),
      ],
    );
  }
}
