import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

const chartPalette = [
  Color(0xFF1B7F4B),
  Color(0xFF3E63DD),
  Color(0xFFF5A524),
  Color(0xFF8E4EC6),
  Color(0xFFE5484D),
  Color(0xFF12A594),
  Color(0xFF6B7280),
];

FlTitlesData _titles(List<String> labels) => FlTitlesData(
      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 26,
          interval: 1,
          getTitlesWidget: (v, meta) {
            final i = v.toInt();
            if (i < 0 || i >= labels.length || v != i.toDouble()) return const SizedBox();
            return Padding(padding: const EdgeInsets.only(top: 6), child: Text(labels[i], style: const TextStyle(fontSize: 10)));
          },
        ),
      ),
    );

class CategoryPie extends StatelessWidget {
  final Map<String, double> data;
  const CategoryPie({super.key, required this.data});
  @override
  Widget build(BuildContext context) {
    final total = data.values.fold<double>(0, (a, b) => a + b);
    var i = 0;
    return SizedBox(
      height: 220,
      child: PieChart(PieChartData(
        sectionsSpace: 2,
        centerSpaceRadius: 46,
        sections: [
          for (final e in data.entries)
            PieChartSectionData(
              value: e.value,
              color: chartPalette[i++ % chartPalette.length],
              radius: 56,
              title: total == 0 ? '' : '${(e.value / total * 100).round()}%',
              titleStyle: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
            ),
        ],
      )),
    );
  }
}

class GroupedBars extends StatelessWidget {
  final List<String> labels;
  final List<List<double>> series; // series[s][i]
  final List<Color> colors;
  const GroupedBars({super.key, required this.labels, required this.series, this.colors = const [AppColors.primary, AppColors.expense]});
  @override
  Widget build(BuildContext context) => SizedBox(
        height: 220,
        child: BarChart(BarChartData(
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: _titles(labels),
          barGroups: [
            for (var i = 0; i < labels.length; i++)
              BarChartGroupData(x: i, barsSpace: 3, barRods: [
                for (var s = 0; s < series.length; s++)
                  BarChartRodData(toY: series[s][i], color: colors[s % colors.length], width: series.length > 1 ? 7 : 14, borderRadius: BorderRadius.circular(3)),
              ]),
          ],
        )),
      );
}

class TrendLine extends StatelessWidget {
  final List<String> labels;
  final List<double> values;
  final Color color;
  const TrendLine({super.key, required this.labels, required this.values, this.color = AppColors.primary});
  @override
  Widget build(BuildContext context) => SizedBox(
        height: 200,
        child: LineChart(LineChartData(
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: _titles(labels),
          lineBarsData: [
            LineChartBarData(
              spots: [for (var i = 0; i < values.length; i++) FlSpot(i.toDouble(), values[i])],
              isCurved: true,
              color: color,
              barWidth: 3,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(show: true, color: color.withOpacity(0.12)),
            ),
          ],
        )),
      );
}
