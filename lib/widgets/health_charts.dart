import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:gluco_care_app/screens/fullscreen_chart.dart';
import 'package:intl/intl.dart';

class HealthChart extends StatelessWidget {
  final List<Map<String, dynamic>> allLogs;
  final bool isPremium;

  const HealthChart({super.key, required this.allLogs, this.isPremium = false});

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
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

    return SizedBox(
      height: MediaQuery.of(context).orientation == Orientation.portrait
          ? 350
          : null,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isPremium ? "Tendencia Completa" : "Tendencia (Reciente)",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      "Rango Objetivo: 70 - 130 mg/dL",
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(
                    Icons.fullscreen_rounded,
                    color: Colors.blue.shade300,
                  ),
                  onPressed: () {
                    // Navegación con animación personalizada
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => FullscreenChartScreen(
                          allLogs: allLogs,
                          isPremium: isPremium,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 25),
            Expanded(
              child: LineChart(
                LineChartData(
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (spot) => const Color(0xFF1E2746),
                      getTooltipItems: (spots) => spots
                          .map(
                            (s) => LineTooltipItem(
                              "${s.barIndex == 0 ? 'Gluc' : 'Pres'}: ${s.y.toInt()}",
                              const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  // 1. LÍNEAS DE REFERENCIA Y ZONA VERDE
                  extraLinesData: ExtraLinesData(
                    horizontalLines: [
                      HorizontalLine(
                        y: 130,
                        color: Colors.green.withOpacity(0.5),
                        strokeWidth: 1,
                        dashArray: [5, 5],
                        label: HorizontalLineLabel(
                          show: true,
                          alignment: Alignment.topRight,
                          style: const TextStyle(
                            fontSize: 9,
                            color: Colors.green,
                          ),
                          labelResolver: (line) => 'Límite Alto',
                        ),
                      ),
                      HorizontalLine(
                        y: 70,
                        color: Colors.orange.withOpacity(0.5),
                        strokeWidth: 1,
                        dashArray: [5, 5],
                        label: HorizontalLineLabel(
                          show: true,
                          alignment: Alignment.bottomRight,
                          style: const TextStyle(
                            fontSize: 9,
                            color: Colors.orange,
                          ),
                          labelResolver: (line) => 'Límite Bajo',
                        ),
                      ),
                    ],
                  ),
                  // 2. CUADRÍCULA SUTIL
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: isDark ? Colors.white10 : Colors.black12,
                      strokeWidth: 1,
                    ),
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
                        interval: 1, // Muestra título para cada punto
                        getTitlesWidget: (value, meta) {
                          int index = value.toInt();
                          // Verificamos que el índice exista en nuestra lista ordenada
                          if (index >= 0 && index < reversedLogs.length) {
                            DateTime date =
                                (reversedLogs[index]['created_at'] as Timestamp)
                                    .toDate();
                            String formattedDate;

                            // Si es de hoy, mostramos hora. Si no, día y mes.
                            if (DateTime.now().day == date.day) {
                              formattedDate = DateFormat('HH:mm').format(date);
                            } else {
                              formattedDate = DateFormat('dd/MM').format(date);
                            }

                            return Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(
                                formattedDate,
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                        reservedSize: 30,
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 40,
                        getTitlesWidget: (value, meta) => Text(
                          value.toInt().toString(),
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 10,
                          ),
                        ),
                        reservedSize: 30,
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    // LÍNEA DE GLUCOSA (AZUL)
                    if (glucoseSpots.isNotEmpty)
                      LineChartBarData(
                        spots: glucoseSpots,
                        isCurved: true,
                        curveSmoothness: 0.35,
                        color: Colors.blueAccent,
                        barWidth: 4,
                        isStrokeCapRound: true,
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (spot, percent, barData, index) =>
                              FlDotCirclePainter(
                                radius: 4,
                                color: Colors.white,
                                strokeWidth: 2,
                                strokeColor: Colors.blueAccent,
                              ),
                        ),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            colors: [
                              Colors.blueAccent.withOpacity(0.2),
                              Colors.blueAccent.withOpacity(0.0),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    // LÍNEA DE PRESIÓN (ROJA)
                    if (pressureSpots.isNotEmpty)
                      LineChartBarData(
                        spots: pressureSpots,
                        isCurved: true,
                        curveSmoothness: 0.35,
                        color: Colors.redAccent,
                        barWidth: 3,
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (spot, percent, barData, index) =>
                              FlDotCirclePainter(
                                radius: 3,
                                color: Colors.white,
                                strokeWidth: 2,
                                strokeColor: Colors.redAccent,
                              ),
                        ),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            colors: [
                              Colors.redAccent.withOpacity(0.1),
                              Colors.redAccent.withOpacity(0.0),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
