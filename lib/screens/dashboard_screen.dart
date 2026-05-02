import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/drone_status_v3.dart';
import '../providers/app_providers.dart';
import '../widgets/glass_card.dart';
import '../widgets/pulsing_dot.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(esp32StatusProvider);
    final ip = ref.watch(esp32IpProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0F0D),
      appBar: _appBar(context, statusAsync.value),
      body: statusAsync.when(
        loading: () => const _LoadingBody(),
        error: (_, __) => _OfflineBody(ip: ip),
        data: (status) =>
            status == null ? _OfflineBody(ip: ip) : _OnlineBody(status: status),
      ),
    );
  }

  PreferredSizeWidget _appBar(BuildContext context, DroneStatusV3? status) {
    final online = status != null;
    return AppBar(
      backgroundColor: const Color(0xFF0A0F0D),
      elevation: 0,
      titleSpacing: 16,
      title: Row(
        children: [
          const Icon(Icons.hexagon_outlined, color: Color(0xFF4ADE80), size: 26),
          const SizedBox(width: 10),
          Text('AgriDrone',
              style: GoogleFonts.syne(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: const Color(0xFFE8F5E9))),
        ],
      ),
      actions: [
        _Pill(
          icon: Icons.wifi,
          label: status != null ? '${status.rssiDbm} dBm' : '---',
          color: _signalColor(status?.rssiDbm ?? -100),
        ),
        const SizedBox(width: 6),
        _StatusPill(online: online),
        const SizedBox(width: 14),
      ],
    );
  }

  static Color _signalColor(int rssi) {
    if (rssi >= -60) return const Color(0xFF4ADE80);
    if (rssi >= -70) return const Color(0xFF86EFAC);
    if (rssi >= -80) return const Color(0xFFFB923C);
    return const Color(0xFFF87171);
  }
}

// ─── Online body ─────────────────────────────────────────────────────────────

class _OnlineBody extends StatelessWidget {
  final DroneStatusV3 status;
  const _OnlineBody({required this.status});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _label('DEVICE TELEMETRY'),
          const SizedBox(height: 10),
          _TelemetryCard(status: status),
          const SizedBox(height: 24),
          _label('GPS POSITION'),
          const SizedBox(height: 10),
          _GpsCard(status: status),
          const SizedBox(height: 24),
          _label('ACTIVE SESSION'),
          const SizedBox(height: 10),
          _SessionCard(status: status),
          if (status.latestImageUrl.isNotEmpty) ...[
            const SizedBox(height: 24),
            _label('LATEST CAPTURE'),
            const SizedBox(height: 10),
            _LastImageCard(url: status.latestImageUrl),
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
}

// ─── Telemetry card ───────────────────────────────────────────────────────────

class _TelemetryCard extends StatelessWidget {
  final DroneStatusV3 status;
  const _TelemetryCard({required this.status});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('IP ADDRESS',
                        style: GoogleFonts.dmMono(
                            fontSize: 9,
                            letterSpacing: 2,
                            color: const Color(0xFF4A6B51))),
                    const SizedBox(height: 4),
                    Text(status.ip,
                        style: GoogleFonts.dmMono(
                            fontSize: 20,
                            fontWeight: FontWeight.w400,
                            color: const Color(0xFFE8F5E9),
                            letterSpacing: 1)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _chip(status.deviceId, const Color(0xFF4A6B51)),
                  const SizedBox(height: 8),
                  Text('UP ${status.uptimeFormatted}',
                      style: GoogleFonts.dmMono(
                          fontSize: 11, color: const Color(0xFF86A98E))),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(height: 1, color: Colors.white.withOpacity(0.06)),
          const SizedBox(height: 14),
          Row(
            children: [
              _statCell('RSSI', '${status.rssiDbm} dBm',
                  _signalColor(status.rssiDbm)),
              const SizedBox(width: 24),
              _statCell('SIGNAL', status.signalLabel,
                  _signalColor(status.rssiDbm)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Text(label,
            style:
                GoogleFonts.dmMono(fontSize: 10, color: color)),
      );

  Widget _statCell(String label, String value, Color color) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: GoogleFonts.dmMono(
                  fontSize: 9,
                  letterSpacing: 1.5,
                  color: const Color(0xFF4A6B51))),
          const SizedBox(height: 3),
          Text(value,
              style: GoogleFonts.dmMono(fontSize: 15, color: color)),
        ],
      );

  static Color _signalColor(int rssi) {
    if (rssi >= -60) return const Color(0xFF4ADE80);
    if (rssi >= -70) return const Color(0xFF86EFAC);
    if (rssi >= -80) return const Color(0xFFFB923C);
    return const Color(0xFFF87171);
  }
}

// ─── GPS card ─────────────────────────────────────────────────────────────────

class _GpsCard extends StatelessWidget {
  final DroneStatusV3 status;
  const _GpsCard({required this.status});

  @override
  Widget build(BuildContext context) {
    final locked = status.gpsValid;
    final lockColor =
        locked ? const Color(0xFF4ADE80) : const Color(0xFFF87171);

    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: lockColor,
                ),
              ),
              const SizedBox(width: 8),
              Text(locked ? 'GPS LOCK' : 'NO GPS LOCK',
                  style: GoogleFonts.dmMono(
                      fontSize: 11,
                      letterSpacing: 1.5,
                      color: lockColor)),
              if (locked) ...[
                const Spacer(),
                Text('HDOP ${status.hdop.toStringAsFixed(1)}',
                    style: GoogleFonts.dmMono(
                        fontSize: 10, color: const Color(0xFF86A98E))),
              ]
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _coord('LATITUDE', status.lat.toStringAsFixed(6)),
              ),
              Expanded(
                child: _coord('LONGITUDE', status.lng.toStringAsFixed(6)),
              ),
              Expanded(
                child: _coord('ALTITUDE',
                    '${status.altM.toStringAsFixed(1)} m'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _coord(String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: GoogleFonts.dmMono(
                  fontSize: 8,
                  letterSpacing: 1.5,
                  color: const Color(0xFF4A6B51))),
          const SizedBox(height: 3),
          Text(value,
              style: GoogleFonts.dmMono(
                  fontSize: 13, color: const Color(0xFFE8F5E9))),
        ],
      );
}

// ─── Session card ─────────────────────────────────────────────────────────────

class _SessionCard extends StatelessWidget {
  final DroneStatusV3 status;
  const _SessionCard({required this.status});

  @override
  Widget build(BuildContext context) {
    final active = status.sessionActive;
    final color =
        active ? const Color(0xFF4ADE80) : const Color(0xFF4A6B51);

    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              active
                  ? Icons.fiber_manual_record
                  : Icons.stop_circle_outlined,
              color: color,
              size: 26,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  active ? 'SESSION ACTIVE' : 'SESSION IDLE',
                  style: GoogleFonts.dmMono(
                      fontSize: 11,
                      letterSpacing: 1.5,
                      color: color),
                ),
                const SizedBox(height: 4),
                if (active && status.sessionId.isNotEmpty)
                  Text(
                    status.sessionShort + '...',
                    style: GoogleFonts.dmMono(
                        fontSize: 12, color: const Color(0xFF86A98E)),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${status.captureCount}',
                style: GoogleFonts.syne(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFFE8F5E9)),
              ),
              Text('CAPTURES',
                  style: GoogleFonts.dmMono(
                      fontSize: 9,
                      letterSpacing: 1.5,
                      color: const Color(0xFF4A6B51))),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Last image card ──────────────────────────────────────────────────────────

class _LastImageCard extends StatelessWidget {
  final String url;
  const _LastImageCard({required this.url});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: [
            Image.network(
              url,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                height: 160,
                color: const Color(0xFF1A2A1E),
                child: const Center(
                  child: Icon(Icons.broken_image_outlined,
                      color: Color(0xFF4A6B51), size: 40),
                ),
              ),
            ),
            Positioned(
              bottom: 8,
              right: 10,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('VIEW ↗',
                    style: GoogleFonts.dmMono(
                        fontSize: 9,
                        letterSpacing: 1.2,
                        color: const Color(0xFF4ADE80))),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Loading / offline states ─────────────────────────────────────────────────

class _LoadingBody extends StatelessWidget {
  const _LoadingBody();
  @override
  Widget build(BuildContext context) => const Center(
      child: CircularProgressIndicator(color: Color(0xFF4ADE80)));
}

class _OfflineBody extends StatelessWidget {
  final String ip;
  const _OfflineBody({required this.ip});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF1A2A1E),
                border: Border.all(
                    color: const Color(0xFFF87171).withOpacity(0.3),
                    width: 2),
              ),
              child: const Icon(Icons.wifi_off_rounded,
                  color: Color(0xFFF87171), size: 36),
            ),
            const SizedBox(height: 24),
            Text('DRONE OFFLINE',
                style: GoogleFonts.syne(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFFE8F5E9))),
            const SizedBox(height: 8),
            Text('Cannot reach $ip',
                style: GoogleFonts.instrumentSans(
                    fontSize: 13, color: const Color(0xFF86A98E))),
            const SizedBox(height: 6),
            Text('Set the correct IP in Mission → Settings',
                style: GoogleFonts.instrumentSans(
                    fontSize: 12, color: const Color(0xFF4A6B51))),
          ],
        ),
      ),
    );
  }
}

// ─── Reusable pill widget ─────────────────────────────────────────────────────

class _Pill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _Pill({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2A1E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(label,
              style: GoogleFonts.dmMono(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFFE8F5E9),
                  letterSpacing: 0.5)),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final bool online;
  const _StatusPill({required this.online});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2A1E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (online)
            const PulsingDot(color: Color(0xFF4ADE80), size: 8)
          else
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                  color: Color(0xFFF87171), shape: BoxShape.circle),
            ),
          const SizedBox(width: 6),
          Text(online ? 'ONLINE' : 'OFFLINE',
              style: GoogleFonts.dmMono(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: online
                      ? const Color(0xFF4ADE80)
                      : const Color(0xFFF87171),
                  letterSpacing: 0.5)),
        ],
      ),
    );
  }
}
