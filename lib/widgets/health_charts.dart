import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HealthChart extends StatelessWidget {
  final List<Map<String, dynamic>> allLogs;
  final bool isPremium;

  const HealthChart({super.key, required this.allLogs, this.isPremium = false});

  @override
  Widget build(BuildContext context) {
    // Invertimos los logs para que el tiempo corra de izquierda a derecha
    final reversedLogs = allLogs.reversed.toList();
    List<FlSpot> glucoseSpots = [];
    List<FlSpot> pressureSpots = [];

    for (int i = 0; i < reversedLogs.length; i++) {
      final log = reversedLogs[i];
      if (log['type'] == 'glucose') {
        glucoseSpots.add(
          FlSpot(i.toDouble(), (log['value'] as num).toDouble()),
        );
      } else if (log['type'] == 'pressure') {
        pressureSpots.add(
          FlSpot(i.toDouble(), (log['systolic'] as num).toDouble()),
        );
      }
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isPremium ? "Tendencia Completa" : "Tendencia (Reciente)",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const Icon(Icons.show_chart, color: Colors.grey, size: 20),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (spot) => const Color(0xFF1E2746),
                    getTooltipItems: (spots) => spots
                        .map(
                          (s) => LineTooltipItem(
                            "${s.barIndex == 0 ? 'Gluco' : 'Pres'}: ${s.y.toInt()}",
                            const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
                gridData: const FlGridData(show: false),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  if (glucoseSpots.isNotEmpty)
                    LineChartBarData(
                      spots: glucoseSpots,
                      isCurved: true,
                      color: Colors.blue,
                      barWidth: 4,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.blue.withOpacity(0.05),
                      ),
                    ),
                  if (pressureSpots.isNotEmpty)
                    LineChartBarData(
                      spots: pressureSpots,
                      isCurved: true,
                      color: Colors.redAccent,
                      barWidth: 4,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.redAccent.withOpacity(0.05),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
