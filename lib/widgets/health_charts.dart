import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:gluco_care_app/screens/fullscreen_chart.dart';
import 'package:intl/intl.dart';

class HealthChart extends StatefulWidget {
  final List<Map<String, dynamic>> allLogs;
  final bool isPremium;

  const HealthChart({
    super.key,
    required this.allLogs,
    this.isPremium = false,
  });

  @override
  State<HealthChart> createState() => _HealthChartState();
}

class _HealthChartState extends State<HealthChart> {
  final _scrollController = ScrollController();

  // Ancho fijo por punto — da espacio suficiente para etiquetas y dots
  static const double _pxPerPoint = 65.0;

  @override
  void initState() {
    super.initState();
    _jumpToEnd();
  }

  @override
  void didUpdateWidget(HealthChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.allLogs.length != widget.allLogs.length) {
      _jumpToEnd();
    }
  }

  void _jumpToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final logs = widget.allLogs.reversed.toList();

    final List<FlSpot> glucoseSpots = [];
    final List<FlSpot> pressureSpots = [];

    for (int i = 0; i < logs.length; i++) {
      final log = logs[i];
      if (log['type'] == 'glucose') {
        glucoseSpots.add(FlSpot(i.toDouble(), (log['value'] as num).toDouble()));
      } else if (log['type'] == 'pressure') {
        pressureSpots.add(FlSpot(i.toDouble(), (log['systolic'] as num).toDouble()));
      }
    }

    final double screenW = MediaQuery.of(context).size.width - 80;
    final double chartWidth = max(screenW, logs.length * _pxPerPoint);

    return LayoutBuilder(
      builder: (context, constraints) {
        // En un ScrollView la altura es infinita → usamos el default de 210px.
        // En el fullscreen (altura acotada) calculamos el espacio real restando
        // el overhead fijo: container padding (32) + header (48) + legend (20)
        // + spacer (12) + hint (28) = 140px.
        final double chartAreaHeight = constraints.maxHeight.isFinite
            ? (constraints.maxHeight - 140).clamp(80.0, double.infinity)
            : 210.0;

        return _buildContainer(
          context, isDark, logs, glucoseSpots, pressureSpots,
          chartWidth, chartAreaHeight,
        );
      },
    );
  }

  Widget _buildContainer(
    BuildContext context,
    bool isDark,
    List<Map<String, dynamic>> logs,
    List<FlSpot> glucoseSpots,
    List<FlSpot> pressureSpots,
    double chartWidth,
    double chartAreaHeight,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Header ──────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.isPremium ? "Tendencia Completa" : "Tendencia (Reciente)",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    "Objetivo: 70 – 130 mg/dL",
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                  ),
                ],
              ),
              IconButton(
                icon: Icon(Icons.fullscreen_exit_outlined, color: Colors.blue.shade300),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FullscreenChartScreen(
                      allLogs: widget.allLogs,
                      isPremium: widget.isPremium,
                    ),
                  ),
                ),
              ),
            ],
          ),

          // ── Leyenda ─────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _legendDot("Glucosa", Colors.blueAccent),
              const SizedBox(width: 24),
              _legendDot("Presión sistólica", Colors.redAccent),
            ],
          ),
          const SizedBox(height: 12),

          // ── Área del gráfico (scrolleable) ──────────────────────
          SizedBox(
            height: chartAreaHeight,
            child: logs.isEmpty
                ? _emptyState(isDark)
                : SingleChildScrollView(
                    controller: _scrollController,
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: SizedBox(
                      width: chartWidth,
                      child: LineChart(_buildChartData(logs, glucoseSpots, pressureSpots, isDark)),
                    ),
                  ),
          ),

          // ── Hint de scroll ───────────────────────────────────────
          if (logs.length > 5)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.swipe_rounded, size: 13, color: Colors.grey.shade400),
                  const SizedBox(width: 5),
                  Text(
                    "Desliza para ver más historial",
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade400),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ── LineChartData ──────────────────────────────────────────────
  LineChartData _buildChartData(
    List<Map<String, dynamic>> logs,
    List<FlSpot> glucoseSpots,
    List<FlSpot> pressureSpots,
    bool isDark,
  ) {
    return LineChartData(
      minX: -0.5,
      maxX: logs.length - 0.5,
      clipData: const FlClipData.all(),

      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipColor: (_) => const Color(0xFF1E2746),
          fitInsideHorizontally: true,
          fitInsideVertically: true,
          getTooltipItems: (spots) => spots.map((s) {
            final i = s.x.toInt();
            final log = (i >= 0 && i < logs.length) ? logs[i] : null;
            final time = log != null
                ? DateFormat('HH:mm  dd/MM').format(
                    (log['created_at'] as Timestamp).toDate())
                : '';
            final label = s.barIndex == 0 ? 'Glucosa' : 'Presión';
            final unit  = s.barIndex == 0 ? 'mg/dL'  : 'mmHg';
            return LineTooltipItem(
              '$label: ${s.y.toInt()} $unit',
              const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
              children: [
                TextSpan(
                  text: '\n$time',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.normal,
                    color: Colors.white70,
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),

      extraLinesData: ExtraLinesData(
        horizontalLines: [
          HorizontalLine(
            y: 130,
            color: Colors.green.withValues(alpha: 0.5),
            strokeWidth: 1,
            dashArray: [5, 5],
            label: HorizontalLineLabel(
              show: true,
              alignment: Alignment.topRight,
              style: const TextStyle(fontSize: 9, color: Colors.green),
              labelResolver: (_) => 'Límite Alto',
            ),
          ),
          HorizontalLine(
            y: 70,
            color: Colors.orange.withValues(alpha: 0.5),
            strokeWidth: 1,
            dashArray: [5, 5],
            label: HorizontalLineLabel(
              show: true,
              alignment: Alignment.bottomRight,
              style: const TextStyle(fontSize: 9, color: Colors.orange),
              labelResolver: (_) => 'Límite Bajo',
            ),
          ),
        ],
      ),

      gridData: FlGridData(
        show: true,
        drawVerticalLine: true,
        getDrawingHorizontalLine: (_) => FlLine(
          color: isDark ? Colors.white10 : Colors.black12,
          strokeWidth: 1,
        ),
        getDrawingVerticalLine: (_) => FlLine(
          color: Colors.black.withValues(alpha: isDark ? 0.04 : 0.04),
          strokeWidth: 1,
        ),
      ),

      titlesData: FlTitlesData(
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: 1,
            reservedSize: 38,
            getTitlesWidget: (value, _) {
              final i = value.toInt();
              if (i < 0 || i >= logs.length) return const SizedBox.shrink();
              final date = (logs[i]['created_at'] as Timestamp).toDate();
              return Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      DateFormat('dd/MM').format(date),
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 9,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      DateFormat('HH:mm').format(date),
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 8,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: 40,
            reservedSize: 30,
            getTitlesWidget: (value, _) => Text(
              value.toInt().toString(),
              style: TextStyle(color: Colors.grey.shade500, fontSize: 10),
            ),
          ),
        ),
      ),

      borderData: FlBorderData(show: false),

      lineBarsData: [
        if (glucoseSpots.isNotEmpty)
          LineChartBarData(
            spots: glucoseSpots,
            isCurved: true,
            curveSmoothness: 0.35,
            color: Colors.blueAccent,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (_, _, _, _) => FlDotCirclePainter(
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
                  Colors.blueAccent.withValues(alpha: 0.2),
                  Colors.blueAccent.withValues(alpha: 0.0),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        if (pressureSpots.isNotEmpty)
          LineChartBarData(
            spots: pressureSpots,
            isCurved: true,
            curveSmoothness: 0.35,
            color: Colors.redAccent,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (_, _, _, _) => FlDotCirclePainter(
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
                  Colors.redAccent.withValues(alpha: 0.1),
                  Colors.redAccent.withValues(alpha: 0.0),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
      ],
    );
  }

  Widget _legendDot(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 4),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: color.withValues(alpha: 0.85),
          ),
        ),
      ],
    );
  }

  Widget _emptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.show_chart_rounded,
            size: 40,
            color: isDark ? Colors.white24 : Colors.grey.shade300,
          ),
          const SizedBox(height: 8),
          Text(
            "Sin datos para graficar",
            style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
