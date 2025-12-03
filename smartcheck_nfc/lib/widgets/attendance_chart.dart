import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

/// Widget hiển thị biểu đồ tròn thống kê điểm danh
/// File con: lib/widgets/attendance_chart.dart
/// File mẹ: Được sử dụng trong lib/screens/analytics_screen.dart
class AttendancePieChart extends StatelessWidget {
  final int onTimeCount;
  final int lateCount;
  final int absentCount;

  const AttendancePieChart({
    super.key,
    required this.onTimeCount,
    required this.lateCount,
    required this.absentCount,
  });

  @override
  Widget build(BuildContext context) {
    final total = onTimeCount + lateCount + absentCount;

    if (total == 0) {
      return Center(
        child: Text(
          'Chưa có dữ liệu',
          style: TextStyle(color: Colors.grey[400], fontSize: 16),
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 200,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 50,
              sections: [
                if (onTimeCount > 0)
                  PieChartSectionData(
                    value: onTimeCount.toDouble(),
                    title: '$onTimeCount',
                    color: Colors.green,
                    radius: 60,
                    titleStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                if (lateCount > 0)
                  PieChartSectionData(
                    value: lateCount.toDouble(),
                    title: '$lateCount',
                    color: Colors.orange,
                    radius: 60,
                    titleStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                if (absentCount > 0)
                  PieChartSectionData(
                    value: absentCount.toDouble(),
                    title: '$absentCount',
                    color: Colors.red,
                    radius: 60,
                    titleStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        // Chú thích
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildLegend('Đúng giờ', Colors.green, onTimeCount, total),
            _buildLegend('Đi muộn', Colors.orange, lateCount, total),
            _buildLegend('Vắng mặt', Colors.red, absentCount, total),
          ],
        ),
      ],
    );
  }

  Widget _buildLegend(String label, Color color, int count, int total) {
    final percentage = total > 0
        ? (count / total * 100).toStringAsFixed(1)
        : '0';

    return Column(
      children: [
        Row(
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '$percentage%',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

/// Widget hiển thị biểu đồ cột theo ngày
class AttendanceBarChart extends StatelessWidget {
  final Map<String, int> dailyData; // {'01/12': 45, '02/12': 48, ...}

  const AttendanceBarChart({super.key, required this.dailyData});

  @override
  Widget build(BuildContext context) {
    if (dailyData.isEmpty) {
      return Center(
        child: Text(
          'Chưa có dữ liệu',
          style: TextStyle(color: Colors.grey[400], fontSize: 16),
        ),
      );
    }

    final maxValue = dailyData.values
        .reduce((a, b) => a > b ? a : b)
        .toDouble();
    final entries = dailyData.entries.toList();

    return SizedBox(
      height: 250,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxValue + 5,
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final date = entries[group.x.toInt()].key;
                final count = rod.toY.toInt();
                return BarTooltipItem(
                  '$date\n$count người',
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  if (value.toInt() >= 0 && value.toInt() < entries.length) {
                    final date = entries[value.toInt()].key;
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(date, style: const TextStyle(fontSize: 10)),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toInt().toString(),
                    style: const TextStyle(fontSize: 10),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          borderData: FlBorderData(show: false),
          barGroups: List.generate(
            entries.length,
            (index) => BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: entries[index].value.toDouble(),
                  color: Colors.blue,
                  width: 20,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
