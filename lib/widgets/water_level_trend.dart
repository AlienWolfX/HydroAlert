import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/water_level_unit.dart';

class WaterLevelTrend extends StatelessWidget {
  final double currentWaterLevel;
  final List<FlSpot> waterLevelData;
  final Color statusColor;
  final double normalThreshold;
  final double warningThreshold;
  final double dangerThreshold;
  final WaterLevelUnit unit;

  const WaterLevelTrend({
    super.key,
    required this.currentWaterLevel,
    required this.waterLevelData,
    required this.statusColor,
    required this.normalThreshold,
    required this.warningThreshold,
    required this.dangerThreshold,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Water Level Trend',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'Current Level',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    Text(
                      '${unit.formatValue(unit.fromMeters(currentWaterLevel))} ${unit.symbol}',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: true,
                    horizontalInterval: unit.getChartInterval(),
                    verticalInterval: 4,
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: 4,
                        getTitlesWidget: (value, meta) {
                          return SideTitleWidget(
                            axisSide: meta.axisSide,
                            child: Text('${value.toInt()}h'),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: unit.getChartInterval(),
                        reservedSize: 60,
                        getTitlesWidget: (value, meta) {
                          // Show labels at specific intervals based on unit
                          final shouldShowLabel = _shouldShowLabel(value, unit);
                          if (shouldShowLabel) {
                            final labelValue = _getLabelValue(value, unit);
                            return SideTitleWidget(
                              axisSide: meta.axisSide,
                              child: Text(
                                labelValue,
                                style: const TextStyle(fontSize: 11),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border.all(color: const Color(0xff37434d)),
                  ),
                  minX: 0,
                  maxX: 23,
                  minY: 0,
                  maxY: 1.0, // Chart Y axis
                  lineBarsData: [
                    LineChartBarData(
                      spots: waterLevelData,
                      isCurved: true,
                      gradient: LinearGradient(
                        colors: [statusColor, statusColor.withOpacity(0.3)],
                      ),
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [
                            statusColor.withOpacity(0.3),
                            statusColor.withOpacity(0.1),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ],
                  // Add threshold lines
                  extraLinesData: ExtraLinesData(
                    horizontalLines: [
                      HorizontalLine(
                        y: normalThreshold,
                        color: Colors.green.withOpacity(0.8),
                        strokeWidth: 2,
                        dashArray: [5, 5],
                      ),
                      HorizontalLine(
                        y: warningThreshold,
                        color: Colors.orange.withOpacity(0.8),
                        strokeWidth: 2,
                        dashArray: [5, 5],
                      ),
                      HorizontalLine(
                        y: dangerThreshold,
                        color: Colors.red.withOpacity(0.8),
                        strokeWidth: 2,
                        dashArray: [5, 5],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to determine if a label should be shown at this value
  bool _shouldShowLabel(double valueInMeters, WaterLevelUnit unit) {
    switch (unit) {
      case WaterLevelUnit.meters:
        // Show every meter (0, 1, 2, 3, 4, 5, 6)
        return (valueInMeters % 1.0).abs() < 0.1;
      case WaterLevelUnit.centimeters:
        // Show every 50 cm worth in meters (every 0.5m)
        return (valueInMeters % 0.5).abs() < 0.05;
      case WaterLevelUnit.feet:
        // Show every 2 feet worth in meters (every 0.6096m)
        return ((valueInMeters / 0.6096).round() * 0.6096 - valueInMeters)
                .abs() <
            0.05;
      case WaterLevelUnit.inches:
        // Show every 24 inches worth in meters (every 0.6096m = 24 inches)
        return ((valueInMeters / 0.6096).round() * 0.6096 - valueInMeters)
                .abs() <
            0.05;
    }
  }

  // Helper method to get the label value for display
  String _getLabelValue(double valueInMeters, WaterLevelUnit unit) {
    final displayValue = unit.fromMeters(valueInMeters);

    switch (unit) {
      case WaterLevelUnit.meters:
        return valueInMeters.toInt().toString();
      case WaterLevelUnit.centimeters:
        // Round to nearest 50 cm
        final cmValue = ((displayValue / 50).round() * 50).toInt();
        return cmValue.toString();
      case WaterLevelUnit.feet:
        // Round to nearest 2 feet
        final feetValue = ((displayValue / 2).round() * 2).toInt();
        return feetValue.toString();
      case WaterLevelUnit.inches:
        // Round to nearest 24 inches
        final inchValue = ((displayValue / 24).round() * 24).toInt();
        return inchValue.toString();
    }
  }
}
