import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/app_providers.dart';
import '../models/drone_models.dart';
import '../widgets/pulsing_dot.dart';

class FieldMapScreen extends ConsumerStatefulWidget {
  const FieldMapScreen({super.key});

  @override
  ConsumerState<FieldMapScreen> createState() => _FieldMapScreenState();
}

class _FieldMapScreenState extends ConsumerState<FieldMapScreen>
    with TickerProviderStateMixin {
  late final AnimationController _markerPulse;

  @override
  void initState() {
    super.initState();
    _markerPulse = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat();
  }

  @override
  void dispose() {
    _markerPulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final soilAsync = ref.watch(soilDataProvider);
    final statusAsync = ref.watch(droneStatusProvider);
    final historyAsync = ref.watch(detectionHistoryProvider);

    final soil = soilAsync.value ?? SoilData();
    final status = statusAsync.value ?? DroneStatus();
    final history = historyAsync.value ?? [];

    final dronePos = LatLng(
      soil.gpsLat != 0 ? soil.gpsLat : 27.7172,
      soil.gpsLng != 0 ? soil.gpsLng : 85.3240,
    );

    final totalScans = history.length;
    final healthyCount =
        history.where((d) => d.disease.toLowerCase() == 'healthy').length;
    final healthPct =
        totalScans > 0 ? (healthyCount / totalScans * 100).round() : 0;

    // group by disease
    final Map<String, int> diseaseCounts = {};
    for (final d in history) {
      final key = d.disease.replaceAll('_', ' ');
      diseaseCounts[key] = (diseaseCounts[key] ?? 0) + 1;
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: dronePos,
              initialZoom: 15.0,
            ),
            children: [
              // Dark tile layer (CartoDB dark matter)
              TileLayer(
                urlTemplate:
                    'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.agridrone.guardian',
              ),
              // Drone marker
              MarkerLayer(
                markers: [
                  Marker(
                    point: dronePos,
                    width: 50,
                    height: 50,
                    child: AnimatedBuilder(
                      animation: _markerPulse,
                      builder: (_, __) {
                        final scale = 1.0 +
                            0.3 *
                                (1 - (_markerPulse.value - 0.5).abs() * 2)
                                    .clamp(0.0, 1.0);
                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            Transform.scale(
                              scale: scale,
                              child: Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFF4ADE80).withOpacity(0.15),
                                  border: Border.all(
                                    color: const Color(0xFF4ADE80).withOpacity(0.3),
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ),
                            Container(
                              width: 20,
                              height: 20,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFF4ADE80),
                                boxShadow: [
                                  BoxShadow(
                                      color: Color(0x884ADE80),
                                      blurRadius: 12)
                                ],
                              ),
                              child: const Icon(Icons.flight,
                                  color: Color(0xFF0A0F0D), size: 12),
                            )
                          ],
                        );
                      },
                    ),
                  ),
                  // Soil sensor marker
                  Marker(
                    point: LatLng(dronePos.latitude + 0.0003,
                        dronePos.longitude + 0.0003),
                    width: 36,
                    height: 36,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF38BDF8).withOpacity(0.15),
                        border: Border.all(
                            color: const Color(0xFF38BDF8).withOpacity(0.5)),
                      ),
                      child: Icon(Icons.water_drop_rounded,
                          color: const Color(0xFF38BDF8), size: 16),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Top label
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 16,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: const Color(0xFF4ADE80).withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  PulsingDot(
                    color: status.status.toLowerCase() == 'online'
                        ? const Color(0xFF4ADE80)
                        : const Color(0xFFF87171),
                    size: 8,
                  ),
                  const SizedBox(width: 8),
                  Text('LIVE FIELD MAP',
                      style: GoogleFonts.dmMono(
                          fontSize: 11,
                          letterSpacing: 2,
                          color: const Color(0xFFE8F5E9))),
                ],
              ),
            ),
          ),

          // Bottom sheet
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF0A0F0D).withOpacity(0.0),
                    const Color(0xFF0A0F0D),
                  ],
                  stops: const [0.0, 0.3],
                ),
              ),
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _sectionLabel('FIELD HEALTH'),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text('$healthPct%',
                          style: GoogleFonts.syne(
                              fontSize: 46,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF4ADE80),
                              height: 1)),
                      const SizedBox(width: 10),
                      Text('HEALTHY',
                          style: GoogleFonts.dmMono(
                              fontSize: 13,
                              letterSpacing: 2,
                              color: const Color(0xFF86A98E))),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Disease breakdown bars
                  ...diseaseCounts.entries.take(4).map((e) {
                    final pct =
                        totalScans > 0 ? e.value / totalScans : 0.0;
                    final isH = e.key.toLowerCase() == 'healthy';
                    final color = isH
                        ? const Color(0xFF4ADE80)
                        : const Color(0xFFFB923C);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(children: [
                        SizedBox(
                          width: 110,
                          child: Text(e.key,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.instrumentSans(
                                  fontSize: 12,
                                  color: const Color(0xFF86A98E))),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: pct,
                              backgroundColor:
                                  Colors.white.withOpacity(0.06),
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(color),
                              minHeight: 6,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('${e.value}',
                            style: GoogleFonts.dmMono(
                                fontSize: 11,
                                color: const Color(0xFF4A6B51))),
                      ]),
                    );
                  }),
                  const SizedBox(height: 8),
                  Text('$totalScans total scans recorded',
                      style: GoogleFonts.instrumentSans(
                          fontSize: 12, color: const Color(0xFF4A6B51))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String t) => Text(t,
      style: GoogleFonts.dmMono(
          fontSize: 10,
          letterSpacing: 2.5,
          fontWeight: FontWeight.w500,
          color: const Color(0xFF4A6B51)));
}
