import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../providers/app_provider.dart';
import '../models/detection_model.dart';

class ResultScreen extends StatelessWidget {
  const ResultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF5FFFA),
      body: app.isLoading
          ? const _LoadingSkeleton()
          : RefreshIndicator(
              color: const Color(0xFF2E7D32),
              backgroundColor: Colors.white,
              onRefresh: () => app.refreshNow(),
              child: CustomScrollView(
                slivers: [
                  SliverAppBar(
                    pinned: true,
                    backgroundColor: Colors.white,
                    surfaceTintColor: Colors.transparent,
                    elevation: 0,
                    title: const Text('Disease Results', style: TextStyle(color: Color(0xFF1B3A1E), fontWeight: FontWeight.w700, letterSpacing: -0.3)),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        if (app.errorMessage != null) _MessageBanner(text: app.errorMessage!),
                        if (app.detections.isEmpty)
                          const _EmptyState()
                        else ...[
                          _LatestCard(detection: app.detections.first),
                          const SizedBox(height: 20),
                          _SummaryBarChart(detections: app.detections),
                          const SizedBox(height: 20),
                          _HistoryHeader(count: app.detections.length),
                          const SizedBox(height: 10),
                          ...app.detections.map((d) => _DetectionTile(d: d)),
                        ],
                      ]),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _LatestCard extends StatelessWidget {
  final DetectionModel detection;
  const _LatestCard({required this.detection});

  Color _severityColor(String s) {
    if (s.contains('severe')) return const Color(0xFFE53935);
    if (s.contains('moderate')) return const Color(0xFFFF9800);
    return const Color(0xFF2E7D32);
  }

  String _severityLabel(String s) {
    if (s.contains('severe')) return 'SEVERE';
    if (s.contains('moderate')) return 'MODERATE';
    return 'MILD';
  }

  @override
  Widget build(BuildContext context) {
    final color = _severityColor(detection.severity.toLowerCase());
    final label = _severityLabel(detection.severity.toLowerCase());
    final confidence = (detection.confidence * 100).toInt();
    final time = DateFormat.yMMMd().add_jm().format(DateTime.fromMillisecondsSinceEpoch(detection.timestamp));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.07), blurRadius: 20, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF2E7D32).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('LATEST', style: TextStyle(color: Color(0xFF2E7D32), fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1)),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(detection.disease, style: const TextStyle(color: Color(0xFF1B3A1E), fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.5)),
          const SizedBox(height: 4),
          Text(_tc(detection.crop), style: const TextStyle(color: Color(0xFF9E9E9E), fontSize: 14)),
          const SizedBox(height: 20),
          Row(
            children: [
              SizedBox(
                width: 70, height: 70,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: detection.confidence,
                      strokeWidth: 6,
                      color: color,
                      backgroundColor: color.withValues(alpha: 0.1),
                    ),
                    Text('$confidence%', style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 15)),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Confidence', style: TextStyle(color: Color(0xFF9E9E9E), fontSize: 11)),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: detection.confidence,
                        color: color,
                        backgroundColor: color.withValues(alpha: 0.1),
                        minHeight: 7,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('Detected at', style: TextStyle(color: Color(0xFF9E9E9E), fontSize: 11)),
                    const SizedBox(height: 2),
                    Text(time, style: const TextStyle(color: Color(0xFF6B7C6E), fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryBarChart extends StatelessWidget {
  final List<DetectionModel> detections;
  const _SummaryBarChart({required this.detections});

  @override
  Widget build(BuildContext context) {
    final counts = <String, int>{};
    for (final d in detections) {
      counts[d.disease] = (counts[d.disease] ?? 0) + 1;
    }
    if (counts.isEmpty) return const SizedBox();
    final maxCount = counts.values.reduce((a, b) => a > b ? a : b);

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
          const Text('Disease Frequency', style: TextStyle(color: Color(0xFF1B3A1E), fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 14),
          ...counts.entries.map((e) {
            final fraction = e.value / maxCount;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(e.key, style: const TextStyle(color: Color(0xFF6B7C6E), fontSize: 12))),
                      Text('${e.value}x', style: const TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.w700, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: fraction,
                      color: const Color(0xFF4CAF50),
                      backgroundColor: const Color(0xFF4CAF50).withValues(alpha: 0.1),
                      minHeight: 5,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _HistoryHeader extends StatelessWidget {
  final int count;
  const _HistoryHeader({required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 3, height: 16, decoration: BoxDecoration(color: const Color(0xFF2E7D32), borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Text('All Detections ($count)', style: const TextStyle(color: Color(0xFF1B3A1E), fontSize: 15, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _DetectionTile extends StatelessWidget {
  final DetectionModel d;
  const _DetectionTile({required this.d});

  Color _severityColor(String s) {
    if (s.contains('severe')) return const Color(0xFFE53935);
    if (s.contains('moderate')) return const Color(0xFFFF9800);
    return const Color(0xFF2E7D32);
  }

  @override
  Widget build(BuildContext context) {
    final color = _severityColor(d.severity.toLowerCase());
    final time = DateFormat.MMMd().add_jm().format(DateTime.fromMillisecondsSinceEpoch(d.timestamp));

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2E7D32).withValues(alpha: 0.1)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.biotech_outlined, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(d.disease, style: const TextStyle(color: Color(0xFF1B3A1E), fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(_tc(d.crop), style: const TextStyle(color: Color(0xFF9E9E9E), fontSize: 11)),
                    const Text(' · ', style: TextStyle(color: Color(0xFF9E9E9E))),
                    Text(time, style: const TextStyle(color: Color(0xFF9E9E9E), fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                child: Text(_tc(d.severity), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 4),
              Text('${(d.confidence * 100).toInt()}%', style: const TextStyle(color: Color(0xFF9E9E9E), fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 300,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.science_outlined, size: 64, color: const Color(0xFF2E7D32).withValues(alpha: 0.2)),
            const SizedBox(height: 16),
            const Text('No detections yet', style: TextStyle(color: Color(0xFF9E9E9E), fontSize: 16)),
            const SizedBox(height: 6),
            const Text('Pull to refresh or fly the drone', style: TextStyle(color: Color(0xFFBDBDBD), fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

class _MessageBanner extends StatelessWidget {
  final String text;
  const _MessageBanner({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFF9800).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Color(0xFFFF9800), size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(color: Color(0xFF795548), fontSize: 13))),
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
          Container(height: 200, decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(20))),
          const SizedBox(height: 16),
          ...List.generate(4, (i) => Container(
            height: 70,
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(14)),
          )),
        ],
      ),
    );
  }
}

String _tc(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
