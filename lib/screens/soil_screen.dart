import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

import '../providers/app_provider.dart';
import '../models/soil_model.dart';

class SoilScreen extends StatelessWidget {
  const SoilScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final latest = app.soil.isNotEmpty ? app.soil.last : null;

    return Scaffold(
      backgroundColor: const Color(0xFFF5FFFA),
      body: app.isLoading
          ? const _LoadingSkeleton()
          : CustomScrollView(
              slivers: [
                SliverAppBar(
                  pinned: true,
                  backgroundColor: Colors.white,
                  surfaceTintColor: Colors.transparent,
                  elevation: 0,
                  title: const Text('Soil Moisture', style: TextStyle(color: Color(0xFF1B3A1E), fontWeight: FontWeight.w700, letterSpacing: -0.3)),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      if (latest != null) _MoistureGaugeCard(latest: latest),
                      const SizedBox(height: 16),
                      _SoilReadingsChart(data: app.soil),
                      const SizedBox(height: 16),
                      if (app.soil.isNotEmpty) _ReadingsTable(readings: app.soil),
                    ]),
                  ),
                ),
              ],
            ),
    );
  }
}

class _MoistureGaugeCard extends StatelessWidget {
  final SoilModel latest;
  const _MoistureGaugeCard({required this.latest});

  @override
  Widget build(BuildContext context) {
    final moisture = latest.moisture;
    Color color;
    String status;
    String recommendation;
    IconData icon;

    if (moisture < 30) {
      color = const Color(0xFFE53935);
      status = 'CRITICAL';
      recommendation = 'Irrigate immediately';
      icon = Icons.water_drop;
    } else if (moisture < 60) {
      color = const Color(0xFFFF9800);
      status = 'MODERATE';
      recommendation = 'Monitor — may need irrigation soon';
      icon = Icons.opacity;
    } else {
      color = const Color(0xFF2E7D32);
      status = 'OPTIMAL';
      recommendation = 'Soil moisture is at ideal level';
      icon = Icons.check_circle_outline;
    }

    final time = DateFormat.yMMMd().add_jm().format(DateTime.fromMillisecondsSinceEpoch(latest.timestamp));

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.07), blurRadius: 20, offset: const Offset(0, 6))],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                child: Text(status, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1)),
              ),
              const Spacer(),
              Text(time, style: const TextStyle(color: Color(0xFF9E9E9E), fontSize: 11)),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: 130, height: 130,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: moisture / 100,
                  strokeWidth: 10,
                  color: color,
                  backgroundColor: color.withValues(alpha: 0.1),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: color, size: 22),
                    const SizedBox(height: 2),
                    Text('${moisture.toStringAsFixed(1)}%', style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w800)),
                    Text('moisture', style: const TextStyle(color: Color(0xFF9E9E9E), fontSize: 10)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.tips_and_updates_outlined, color: color, size: 16),
                const SizedBox(width: 8),
                Text(recommendation, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SoilReadingsChart extends StatelessWidget {
  final List<SoilModel> data;
  const _SoilReadingsChart({required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return Container(
        height: 200,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFF2E7D32).withValues(alpha: 0.12))),
        child: const Center(child: Text('No data', style: TextStyle(color: Color(0xFF9E9E9E)))),
      );
    }

    final spots = <FlSpot>[];
    for (var i = 0; i < data.length; i++) {
      spots.add(FlSpot(i.toDouble(), data[i].moisture));
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF2E7D32).withValues(alpha: 0.12)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Moisture Trend', style: TextStyle(color: Color(0xFF1B3A1E), fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  minY: 0,
                  maxY: 100,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) => FlLine(color: const Color(0xFF2E7D32).withValues(alpha: 0.07), strokeWidth: 1),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        getTitlesWidget: (value, meta) {
                          if (value % 25 == 0) {
                            return Text('${value.toInt()}', style: const TextStyle(color: Color(0xFF9E9E9E), fontSize: 10));
                          }
                          return const SizedBox();
                        },
                      ),
                    ),
                    bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      curveSmoothness: 0.3,
                      color: const Color(0xFF2E7D32),
                      barWidth: 2.5,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                          radius: 4,
                          color: Colors.white,
                          strokeColor: const Color(0xFF2E7D32),
                          strokeWidth: 2,
                        ),
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [const Color(0xFF4CAF50).withValues(alpha: 0.2), const Color(0xFF4CAF50).withValues(alpha: 0.0)],
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

class _ReadingsTable extends StatelessWidget {
  final List<SoilModel> readings;
  const _ReadingsTable({required this.readings});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF2E7D32).withValues(alpha: 0.12)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('All Readings', style: TextStyle(color: Color(0xFF1B3A1E), fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 12),
          const Divider(color: Color(0xFFE8F5E9)),
          ...readings.reversed.map((r) {
            final moisture = r.moisture;
            Color color;
            if (moisture < 30) {
              color = const Color(0xFFE53935);
            } else if (moisture < 60) {
              color = const Color(0xFFFF9800);
            } else {
              color = const Color(0xFF2E7D32);
            }
            final time = DateFormat.MMMd().add_jm().format(DateTime.fromMillisecondsSinceEpoch(r.timestamp));
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
                    child: Icon(Icons.water_drop_outlined, color: color, size: 16),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(time, style: const TextStyle(color: Color(0xFF6B7C6E), fontSize: 13))),
                  Text('${moisture.toStringAsFixed(1)}%', style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 15)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 80, 16, 16),
      child: Column(
        children: [
          Container(height: 250, decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(20))),
          const SizedBox(height: 16),
          Container(height: 240, decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(18))),
        ],
      ),
    );
  }
}
