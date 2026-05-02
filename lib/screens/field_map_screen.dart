import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/app_providers.dart';
import '../models/drone_status_v3.dart';
import '../models/drone_log.dart';
import '../widgets/pulsing_dot.dart';

class FieldMapScreen extends ConsumerStatefulWidget {
  const FieldMapScreen({super.key});

  @override
  ConsumerState<FieldMapScreen> createState() => _FieldMapScreenState();
}

class _FieldMapScreenState extends ConsumerState<FieldMapScreen>
    with TickerProviderStateMixin {
  late final AnimationController _markerPulse;
  late final MapController _mapController;

  @override
  void initState() {
    super.initState();
    _markerPulse =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat();
    _mapController = MapController();
  }

  @override
  void dispose() {
    _markerPulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final statusAsync = ref.watch(esp32StatusProvider);
    final status = statusAsync.value; // null = offline

    // Current drone position — fall back to Kathmandu if no GPS
    final dronePos = LatLng(
      (status?.lat ?? 27.6907),
      (status?.lng ?? 85.2951),
    );

    // GPS track for the active session
    final sessionId = status?.sessionId ?? '';
    final trackAsync = sessionId.isNotEmpty
        ? ref.watch(gpsTrackProvider(sessionId))
        : null;
    final trackPoints = trackAsync?.value
            ?.where((l) => l.gpsValid)
            .map((l) => LatLng(l.lat, l.lng))
            .toList() ??
        [];

    // Capture thumbnails for markers
    final capturesAsync = ref.watch(droneLogsProvider);
    final captures = capturesAsync.value ?? [];
    final captureMarkers = captures
        .where((l) => l.gpsValid && l.hasImage)
        .map((l) => Marker(
              point: LatLng(l.lat, l.lng),
              width: 28,
              height: 28,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF4ADE80).withOpacity(0.2),
                  border: Border.all(
                      color: const Color(0xFF4ADE80).withOpacity(0.6),
                      width: 1.5),
                ),
                child: const Icon(Icons.photo_camera_rounded,
                    color: Color(0xFF4ADE80), size: 13),
              ),
            ))
        .toList();

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Map ────────────────────────────────────────────────────────
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: dronePos,
              initialZoom: 16.0,
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.agridrone.guardian',
              ),

              // GPS track polyline
              if (trackPoints.length >= 2)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: trackPoints,
                      strokeWidth: 2.5,
                      color: const Color(0xFF4ADE80).withOpacity(0.5),
                    ),
                  ],
                ),

              // Capture photo markers
              if (captureMarkers.isNotEmpty)
                MarkerLayer(markers: captureMarkers),

              // Drone position marker
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
                                (1 -
                                        (_markerPulse.value - 0.5).abs() *
                                            2)
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
                                  color: const Color(0xFF4ADE80)
                                      .withOpacity(0.15),
                                  border: Border.all(
                                    color: const Color(0xFF4ADE80)
                                        .withOpacity(0.3),
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
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),

          // ── Top HUD ────────────────────────────────────────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 16,
            right: 16,
            child: Row(
              children: [
                _topPill(context, status),
                const Spacer(),
                // Re-center button
                GestureDetector(
                  onTap: () => _mapController.move(dronePos, 16),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: const Color(0xFF4ADE80).withOpacity(0.2)),
                    ),
                    child: const Icon(Icons.my_location_rounded,
                        color: Color(0xFF4ADE80), size: 18),
                  ),
                ),
              ],
            ),
          ),

          // ── Bottom panel ───────────────────────────────────────────────
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: _BottomPanel(status: status, trackCount: trackPoints.length),
          ),
        ],
      ),
    );
  }

  Widget _topPill(BuildContext context, DroneStatusV3? status) {
    final online = status != null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: const Color(0xFF4ADE80).withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PulsingDot(
            color: online
                ? const Color(0xFF4ADE80)
                : const Color(0xFFF87171),
            size: 8,
          ),
          const SizedBox(width: 8),
          Text(
            online
                ? 'LIVE  ·  ${status!.lat.toStringAsFixed(4)}, ${status.lng.toStringAsFixed(4)}'
                : 'DRONE OFFLINE',
            style: GoogleFonts.dmMono(
                fontSize: 11,
                letterSpacing: 1.5,
                color: const Color(0xFFE8F5E9)),
          ),
        ],
      ),
    );
  }
}

// ─── Bottom panel ─────────────────────────────────────────────────────────────

class _BottomPanel extends StatelessWidget {
  final DroneStatusV3? status;
  final int trackCount;
  const _BottomPanel({this.status, required this.trackCount});

  @override
  Widget build(BuildContext context) {
    return Container(
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
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _label('GPS TELEMETRY'),
          const SizedBox(height: 12),
          if (status == null)
            Text('Drone offline — no GPS data',
                style: GoogleFonts.instrumentSans(
                    fontSize: 13, color: const Color(0xFF4A6B51)))
          else
            Wrap(
              spacing: 20,
              runSpacing: 10,
              children: [
                _stat('LAT', status!.lat.toStringAsFixed(6)),
                _stat('LNG', status!.lng.toStringAsFixed(6)),
                _stat('ALT', '${status!.altM.toStringAsFixed(1)} m'),
                _stat('HDOP', status!.hdop.toStringAsFixed(1)),
                _stat('GPS', status!.gpsValid ? 'LOCK' : 'NO FIX',
                    color: status!.gpsValid
                        ? const Color(0xFF4ADE80)
                        : const Color(0xFFF87171)),
                _stat('TRACK PTS', '$trackCount'),
              ],
            ),
          if (status?.sessionActive == true) ...[
            const SizedBox(height: 12),
            Row(children: [
              const Icon(Icons.fiber_manual_record,
                  color: Color(0xFFF87171), size: 10),
              const SizedBox(width: 6),
              Text(
                'Recording · ${status!.captureCount} captures',
                style: GoogleFonts.dmMono(
                    fontSize: 11, color: const Color(0xFF4ADE80)),
              ),
            ]),
          ],
        ],
      ),
    );
  }

  Widget _label(String t) => Text(t,
      style: GoogleFonts.dmMono(
          fontSize: 10,
          letterSpacing: 2.5,
          fontWeight: FontWeight.w500,
          color: const Color(0xFF4A6B51)));

  Widget _stat(String label, String value, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: GoogleFonts.dmMono(
                fontSize: 8,
                letterSpacing: 1.5,
                color: const Color(0xFF4A6B51))),
        const SizedBox(height: 2),
        Text(value,
            style: GoogleFonts.dmMono(
                fontSize: 13,
                color: color ?? const Color(0xFFE8F5E9))),
      ],
    );
  }
}
