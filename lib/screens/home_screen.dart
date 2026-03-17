import "package:agridrone_guardian/services/connectivity_service.dart";
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../providers/app_provider.dart';
import '../models/detection_model.dart';
import '../widgets/telemetry_hud.dart';
import '../widgets/status_bar.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    return Scaffold(
      backgroundColor: const Color(0xFFF5FBF5),
      body: app.isLoading
          ? const _LoadingSkeleton()
          : Stack(
              children: [
                RefreshIndicator(
                  color: const Color(0xFF2E7D32),
                  backgroundColor: Colors.white,
                  onRefresh: () => app.refreshNow(),
                  child: CustomScrollView(
                    slivers: [
                      _AgriAppBar(app: app),
                      SliverToBoxAdapter(child: const StatusBar()),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate([
                            const SizedBox(height: 16),
                            _DroneStatusCard(app: app),
                            const SizedBox(height: 16),
                            _StatsRow(app: app),
                            const SizedBox(height: 24),
                            const _SectionHeader(title: 'Select Crop to Monitor'),
                            const SizedBox(height: 12),
                            _CropSelector(app: app),
                            const SizedBox(height: 24),
                            if (app.detections.isNotEmpty) ...[
                              const _SectionHeader(title: 'Recent Detections'),
                              const SizedBox(height: 12),
                              ...app.detections.take(3).map((d) => _RecentDetectionTile(d: d)),
                            ],
                          ]),
                        ),
                      ),
                    ],
                  ),
                ),
                const TelemetryHud(),
                if (app.isScanning) const _ScanningOverlay(),
              ],
            ),
      floatingActionButton: app.connectionState == DroneConnectionState.direct
          ? FloatingActionButton.extended(
              onPressed: app.isScanning ? null : () => app.triggerCapture(),
              backgroundColor: const Color(0xFF2E7D32),
              icon: const Icon(Icons.camera_alt, color: Colors.white),
              label: const Text('Capture', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
          : null,
    );
  }
}

class _ScanningOverlay extends StatelessWidget {
  const _ScanningOverlay();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.7),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 80,
              height: 80,
              child: CircularProgressIndicator(
                strokeWidth: 6,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2E7D32)),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'SCANNING...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Analyzing crop health via ESP32-CAM',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AgriAppBar extends StatelessWidget {
  final AppProvider app;
  const _AgriAppBar({required this.app});

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 130,
      pinned: true,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shadowColor: const Color(0xFF2E7D32).withOpacity(0.08),
      actions: [
        IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF2E7D32).withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.settings_outlined, color: Color(0xFF2E7D32)),
          ),
          onPressed: () => Navigator.of(context).pushNamed('/settings'),
        ),
        const SizedBox(width: 8),
      ],
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.fromLTRB(20, 0, 0, 16),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'AgriDrone',
              style: TextStyle(
                color: Color(0xFF1B3A1E),
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            Text(
              'Guardian',
              style: TextStyle(
                color: const Color(0xFF2E7D32).withOpacity(0.6),
                fontSize: 12,
                fontWeight: FontWeight.w400,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
        background: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(color: const Color(0xFF2E7D32).withOpacity(0.1)),
            ),
          ),
        ),
      ),
    );
  }
}

class _DroneStatusCard extends StatelessWidget {
  final AppProvider app;
  const _DroneStatusCard({required this.app});

  @override
  Widget build(BuildContext context) {
    final status = app.droneStatus;
    final connected = status?.connected == true;
    final flying = status?.flying == true;
    final battery = status?.battery ?? 0;

    Color statusColor = const Color(0xFFE53935);
    String statusText = 'Disconnected';
    if (connected && flying) {
      statusColor = const Color(0xFFFF9800);
      statusText = 'In Flight';
    } else if (connected) {
      statusColor = const Color(0xFF2E7D32);
      statusText = 'Connected · Ready';
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.air, color: statusColor, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Drone Status', style: TextStyle(color: Color(0xFF9E9E9E), fontSize: 12, letterSpacing: 0.3)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 8, height: 8,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: statusColor.withOpacity(0.4), blurRadius: 4)],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(statusText, style: const TextStyle(color: Color(0xFF1B3A1E), fontSize: 15, fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
          ),
          if (connected)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text('Battery', style: TextStyle(color: Color(0xFF9E9E9E), fontSize: 11)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      battery > 50 ? Icons.battery_full : battery > 20 ? Icons.battery_3_bar : Icons.battery_alert,
                      color: battery > 50 ? const Color(0xFF2E7D32) : battery > 20 ? const Color(0xFFFF9800) : const Color(0xFFE53935),
                      size: 20,
                    ),
                    const SizedBox(width: 4),
                    Text('$battery%', style: const TextStyle(color: Color(0xFF1B3A1E), fontWeight: FontWeight.w700, fontSize: 16)),
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final AppProvider app;
  const _StatsRow({required this.app});

  @override
  Widget build(BuildContext context) {
    final lastScan = app.detections.isNotEmpty
        ? DateTime.fromMillisecondsSinceEpoch(app.detections.first.timestamp)
        : null;
    final severeCount = app.detections.where((d) => d.severity.toLowerCase().contains('severe')).length;

    return Row(
      children: [
        Expanded(child: _StatCard(icon: Icons.document_scanner, label: 'Total Scans', value: '${app.detections.length}', accent: const Color(0xFF2E7D32))),
        const SizedBox(width: 12),
        Expanded(child: _StatCard(icon: Icons.warning_amber_rounded, label: 'Severe Cases', value: '$severeCount', accent: severeCount > 0 ? const Color(0xFFE53935) : const Color(0xFF2E7D32))),
        const SizedBox(width: 12),
        Expanded(child: _StatCard(icon: Icons.schedule, label: 'Last Scan', value: lastScan == null ? 'None' : DateFormat.MMMd().format(lastScan), accent: const Color(0xFF388E3C))),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color accent;
  const _StatCard({required this.icon, required this.label, required this.value, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withOpacity(0.15)),
        boxShadow: [BoxShadow(color: accent.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accent, size: 22),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(color: accent, fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: Color(0xFF9E9E9E), fontSize: 11)),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 3, height: 16, decoration: BoxDecoration(color: const Color(0xFF2E7D32), borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(color: Color(0xFF1B3A1E), fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0.2)),
      ],
    );
  }
}

class _CropSelector extends StatelessWidget {
  final AppProvider app;
  const _CropSelector({required this.app});

  static const _crops = [
    {'label': 'Rice', 'emoji': '🌾', 'key': 'rice'},
    {'label': 'Wheat', 'emoji': '🌿', 'key': 'wheat'},
    {'label': 'Maize', 'emoji': '🌽', 'key': 'maize'},
    {'label': 'Potato', 'emoji': '🥔', 'key': 'potato'},
    {'label': 'Tomato', 'emoji': '🍅', 'key': 'tomato'},
    {'label': 'Pepper', 'emoji': '🫑', 'key': 'pepper'},
  ];

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: MediaQuery.of(context).size.width < 600 ? 3 : 6,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.0,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      children: _crops.map((c) {
        final selected = app.selectedCrop == c['key'];
        return GestureDetector(
          onTap: () => app.setCrop(c['key']!),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: selected ? const Color(0xFF2E7D32).withOpacity(0.08) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? const Color(0xFF2E7D32) : const Color(0xFF2E7D32).withOpacity(0.15),
                width: selected ? 1.5 : 1,
              ),
              boxShadow: selected ? [BoxShadow(color: const Color(0xFF2E7D32).withOpacity(0.15), blurRadius: 12)] : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(c['emoji']!, style: const TextStyle(fontSize: 28)),
                const SizedBox(height: 6),
                Text(
                  c['label']!,
                  style: TextStyle(
                    color: selected ? const Color(0xFF2E7D32) : const Color(0xFF6B7C6E),
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _RecentDetectionTile extends StatelessWidget {
  final DetectionModel d;
  const _RecentDetectionTile({required this.d});

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
        border: Border.all(color: const Color(0xFF2E7D32).withOpacity(0.1)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.coronavirus_outlined, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${_tc(d.crop)} · ${d.disease}', style: const TextStyle(color: Color(0xFF1B3A1E), fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 2),
                Text(time, style: const TextStyle(color: Color(0xFF9E9E9E), fontSize: 11)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: color.withOpacity(0.10), borderRadius: BorderRadius.circular(20)),
            child: Text('${(d.confidence * 100).toInt()}%', style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  String _tc(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: List.generate(5, (i) => Container(
          height: i == 0 ? 80 : 60,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F5E9),
            borderRadius: BorderRadius.circular(16),
          ),
        )),
      ),
    );
  }
}
