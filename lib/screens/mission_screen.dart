import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/app_providers.dart';
import '../models/drone_status_v3.dart';
import '../widgets/glass_card.dart';
import '../widgets/pulsing_dot.dart';

class MissionScreen extends ConsumerStatefulWidget {
  const MissionScreen({super.key});

  @override
  ConsumerState<MissionScreen> createState() => _MissionScreenState();
}

class _MissionScreenState extends ConsumerState<MissionScreen> {
  final _ipController = TextEditingController();

  static const _green = Color(0xFF4ADE80);
  static const _red = Color(0xFFF87171);
  static const _bg = Color(0xFF0A0F0D);
  static const _textPrimary = Color(0xFFE8F5E9);
  static const _textSecondary = Color(0xFF86A98E);

  @override
  void initState() {
    super.initState();
    _ipController.text = ref.read(esp32IpProvider);
  }

  @override
  void dispose() {
    _ipController.dispose();
    super.dispose();
  }

  // Auto-discover IP from FastAPI device registry
  Future<void> _autoDiscover() async {
    try {
      final ip = await ref
          .read(backendServiceProvider)
          .fetchDeviceIp('esp32-drone-01');
      if (ip != null && ip.trim().isNotEmpty) {
        await ref.read(esp32IpProvider.notifier).set(ip.trim());
        _ipController.text = ip.trim();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Found drone at $ip',
                  style: GoogleFonts.dmMono(fontSize: 12)),
              backgroundColor: const Color(0xFF1A2A1E),
            ),
          );
        }
      } else {
        _showError('Device not found in registry. Enter IP manually.');
      }
    } catch (e) {
      _showError('Discovery failed: $e');
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.dmMono(fontSize: 12)),
        backgroundColor: const Color(0xFF3A1010),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mission = ref.watch(missionProvider);
    final statusAsync = ref.watch(esp32StatusProvider);
    final liveStatus = statusAsync.value; // null = offline
    final isOnline = liveStatus != null;

    // Sync live capture count into mission state
    if (liveStatus != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(missionProvider.notifier).syncFromStatus(liveStatus);
      });
    }

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        title: Text('Mission Control',
            style: GoogleFonts.syne(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: _textPrimary)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Session counter ────────────────────────────────────
            _SessionCounterCard(
                mission: mission, liveStatus: liveStatus),
            const SizedBox(height: 20),

            // ── ESP32 connection ───────────────────────────────────
            _sectionLabel('ESP32 CONNECTION'),
            const SizedBox(height: 10),
            GlassCard(
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _ipController,
                          style: GoogleFonts.dmMono(
                              color: _textPrimary, fontSize: 14),
                          decoration: InputDecoration(
                            labelText: 'Drone IP  (e.g. 192.168.1.76)',
                            labelStyle: GoogleFonts.instrumentSans(
                                color: _textSecondary, fontSize: 13),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide:
                                  BorderSide(color: _green.withOpacity(0.3)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide:
                                  BorderSide(color: _green.withOpacity(0.2)),
                            ),
                          ),
                          onChanged: (v) =>
                              ref.read(esp32IpProvider.notifier).set(v.trim()),
                          onSubmitted: (v) =>
                              ref.read(esp32IpProvider.notifier).set(v.trim()),
                        ),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: _autoDiscover,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(
                                color: _green.withOpacity(0.4)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.search_rounded,
                              color: _green, size: 22),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(children: [
                    Container(
                      width: 8, height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isOnline
                            ? const Color(0xFF4ADE80)
                            : const Color(0xFFF87171),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isOnline
                          ? 'Connected · ${liveStatus!.ip}  ${liveStatus.rssiDbm} dBm'
                          : 'Not reachable — check IP or power',
                      style: GoogleFonts.dmMono(
                          fontSize: 11,
                          color: isOnline
                              ? _green
                              : _textSecondary),
                    ),
                  ]),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Session controls ───────────────────────────────────
            _sectionLabel('SESSION'),
            const SizedBox(height: 10),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (mission.lastError != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(mission.lastError!,
                          style: GoogleFonts.instrumentSans(
                              color: _red, fontSize: 12)),
                    ),
                  Row(children: [
                    Expanded(
                      child: _ActionButton(
                        label: mission.sessionActive
                            ? '■ STOP SESSION'
                            : '▶ START SESSION',
                        color: mission.sessionActive ? _red : _green,
                        onPressed: () async {
                          if (mission.sessionActive) {
                            await ref
                                .read(missionProvider.notifier)
                                .stopSession();
                          } else {
                            await ref
                                .read(missionProvider.notifier)
                                .startSession();
                          }
                        },
                      ),
                    ),
                  ]),
                  if (mission.sessionActive) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Session: ${mission.sessionId.isNotEmpty ? mission.sessionId.substring(0, 8) : "---"}…',
                      style: GoogleFonts.dmMono(
                          fontSize: 10, color: _textSecondary),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Auto-capture ───────────────────────────────────────
            _sectionLabel('AUTO-CAPTURE'),
            const SizedBox(height: 10),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Fires GET /capture every 5 s during flight.\n'
                    'Firmware uploads each JPEG to Supabase automatically.',
                    style: GoogleFonts.instrumentSans(
                        fontSize: 12, color: _textSecondary, height: 1.5),
                  ),
                  const SizedBox(height: 14),
                  Row(children: [
                    Expanded(
                      child: _ActionButton(
                        label: mission.isAutoCapturing
                            ? '⏹ STOP AUTO'
                            : '⏺ START AUTO',
                        color: mission.isAutoCapturing ? _red : _green,
                        onPressed: () async {
                          if (mission.isAutoCapturing) {
                            ref
                                .read(missionProvider.notifier)
                                .stopAutoCapture();
                          } else {
                            await ref
                                .read(missionProvider.notifier)
                                .startAutoCapture(intervalMs: 5000);
                          }
                        },
                      ),
                    ),
                  ]),
                  if (mission.isAutoCapturing) ...[
                    const SizedBox(height: 10),
                    Row(children: [
                      const PulsingDot(color: Color(0xFF4ADE80), size: 8),
                      const SizedBox(width: 8),
                      Text('Capturing every 5 s…',
                          style: GoogleFonts.dmMono(
                              fontSize: 11, color: _green)),
                    ]),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Manual snapshot ────────────────────────────────────
            _sectionLabel('MANUAL CAPTURE'),
            const SizedBox(height: 10),
            GlassCard(
              child: _ActionButton(
                label: '📷 TAKE SNAPSHOT',
                color: const Color(0xFF38BDF8),
                onPressed: () =>
                    ref.read(missionProvider.notifier).takeSnapshot(),
              ),
            ),

            // ── Live telemetry summary ─────────────────────────────
            if (liveStatus != null) ...[
              const SizedBox(height: 20),
              _sectionLabel('LIVE TELEMETRY'),
              const SizedBox(height: 10),
              _TelemetrySummary(status: liveStatus),
            ],
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String label) => Text(
        label,
        style: GoogleFonts.dmMono(
            fontSize: 11,
            letterSpacing: 2.0,
            color: const Color(0xFF86A98E),
            fontWeight: FontWeight.w500),
      );
}

// ─── Session counter ──────────────────────────────────────────────────────────

class _SessionCounterCard extends StatelessWidget {
  final MissionState mission;
  final DroneStatusV3? liveStatus;
  const _SessionCounterCard({required this.mission, this.liveStatus});

  @override
  Widget build(BuildContext context) {
    final count = liveStatus?.captureCount ?? mission.captureCount;
    final active = liveStatus?.sessionActive ?? mission.sessionActive;
    const green = Color(0xFF4ADE80);

    return GlassCard(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: green.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.camera_alt_outlined,
                color: green, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count photos captured',
                  style: GoogleFonts.syne(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: const Color(0xFFE8F5E9)),
                ),
                const SizedBox(height: 4),
                Text(
                  active && liveStatus != null
                      ? 'Session · ${liveStatus!.sessionShort}…'
                      : 'No active session',
                  style: GoogleFonts.dmMono(
                      fontSize: 11,
                      color: const Color(0xFF86A98E),
                      letterSpacing: 0.5),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (active)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: green.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: green.withOpacity(0.4)),
              ),
              child: Text('LIVE',
                  style: GoogleFonts.dmMono(
                      fontSize: 10,
                      color: green,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w700)),
            ),
        ],
      ),
    );
  }
}

// ─── Telemetry summary ────────────────────────────────────────────────────────

class _TelemetrySummary extends StatelessWidget {
  final DroneStatusV3 status;
  const _TelemetrySummary({required this.status});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Wrap(
        spacing: 20,
        runSpacing: 12,
        children: [
          _cell('GPS', status.gpsValid ? 'LOCK' : 'NO FIX',
              status.gpsValid
                  ? const Color(0xFF4ADE80)
                  : const Color(0xFFF87171)),
          _cell('LAT', status.lat.toStringAsFixed(5),
              const Color(0xFFE8F5E9)),
          _cell('LNG', status.lng.toStringAsFixed(5),
              const Color(0xFFE8F5E9)),
          _cell('ALT', '${status.altM.toStringAsFixed(1)} m',
              const Color(0xFF38BDF8)),
          _cell('HDOP', status.hdop.toStringAsFixed(1),
              const Color(0xFF86A98E)),
          _cell('RSSI', '${status.rssiDbm} dBm',
              const Color(0xFF86A98E)),
          _cell('UPTIME', status.uptimeFormatted,
              const Color(0xFF86A98E)),
        ],
      ),
    );
  }

  Widget _cell(String label, String value, Color color) => Column(
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
              style: GoogleFonts.dmMono(fontSize: 13, color: color)),
        ],
      );
}

// ─── Action button ────────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback? onPressed;
  const _ActionButton(
      {required this.label, required this.color, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.15),
        foregroundColor: color,
        side: BorderSide(color: color.withOpacity(0.5)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
      child: Text(label,
          style: GoogleFonts.dmMono(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              letterSpacing: 1.5)),
    );
  }
}
