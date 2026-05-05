import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:html' as html;
import 'dart:ui_web' as ui;
import '../providers/app_providers.dart';
import '../models/drone_status_v3.dart';
import '../widgets/pulsing_dot.dart';

class LiveStreamScreen extends ConsumerStatefulWidget {
  const LiveStreamScreen({super.key});

  @override
  ConsumerState<LiveStreamScreen> createState() => _LiveStreamScreenState();
}

class _LiveStreamScreenState extends ConsumerState<LiveStreamScreen> {
  // Registry key → never re-register the same URL
  static final _registered = <String>{};

  String? _previewUrl; // object URL for last snapshot preview
  bool _snapBusy = false;

  void _registerView(String url) {
    if (_registered.contains(url)) return;
    _registered.add(url);
    // ignore: undefined_prefixed_name
    ui.platformViewRegistry.registerViewFactory('mjpeg-$url', (int id) {
      final img = html.ImageElement()
        ..src = url
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.objectFit = 'cover'
        ..style.backgroundColor = 'black';
      return img;
    });
  }

  Future<void> _takeSnapshot() async {
    if (_snapBusy) return;
    setState(() => _snapBusy = true);
    try {
      await ref.read(missionProvider.notifier).takeSnapshot();
      final bytes = ref.read(missionProvider).lastPreviewBytes;
      if (bytes != null && mounted) {
        final blob = html.Blob([Uint8List.fromList(bytes)], 'image/jpeg');
        final url = html.Url.createObjectUrl(blob);
        setState(() => _previewUrl = url);
      }
    } finally {
      if (mounted) setState(() => _snapBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusAsync = ref.watch(esp32StatusProvider);
    final status = statusAsync.value; // null = offline
    final ip = ref.watch(esp32IpProvider);

    // Firmware streams on port 80 at /stream (NOT :81/stream)
    final streamUrl = 'http://$ip/stream';
    _registerView(streamUrl);

    final isOnline = status != null;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Stream or offline ──────────────────────────────────────────
          if (isOnline)
            HtmlElementView(viewType: 'mjpeg-$streamUrl')
          else
            _OfflineOverlay(ip: ip, onRetry: () => setState(() {})),

          // ── Crosshair ──────────────────────────────────────────────────
          if (isOnline) _buildCrosshair(),

          // ── Corner brackets ────────────────────────────────────────────
          const Positioned(top: 60, left: 16, child: _Corner(flip: false, flipV: false)),
          const Positioned(top: 60, right: 16, child: _Corner(flip: true,  flipV: false)),
          const Positioned(bottom: 100, left: 16, child: _Corner(flip: false, flipV: true)),
          const Positioned(bottom: 100, right: 16, child: _Corner(flip: true,  flipV: true)),

          // ── Title ──────────────────────────────────────────────────────
          Positioned(
            top: 52, left: 28,
            child: Text('AGRIDRONE GUARDIAN',
                style: GoogleFonts.dmMono(
                    fontSize: 11,
                    letterSpacing: 2.5,
                    color: const Color(0xFF4ADE80).withOpacity(0.8))),
          ),

          // ── LIVE / OFFLINE badge ───────────────────────────────────────
          Positioned(
            top: 50, right: 28,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.55),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.12)),
              ),
              child: Row(
                children: [
                  if (isOnline)
                    const PulsingDot(color: Color(0xFFF87171), size: 8)
                  else
                    Container(width: 8, height: 8,
                        decoration: const BoxDecoration(
                            color: Color(0xFF4A6B51),
                            shape: BoxShape.circle)),
                  const SizedBox(width: 7),
                  Text(isOnline ? 'LIVE' : 'OFFLINE',
                      style: GoogleFonts.dmMono(
                          fontSize: 11, letterSpacing: 1.5,
                          color: isOnline ? Colors.white : const Color(0xFF4A6B51))),
                ],
              ),
            ),
          ),

          // ── GPS HUD (bottom-left) ──────────────────────────────────────
          if (isOnline)
            Positioned(
              bottom: 96, left: 28,
              child: _GpsHud(status: status!),
            ),

          // ── Session HUD (bottom-right) ─────────────────────────────────
          if (isOnline && status!.sessionActive)
            Positioned(
              bottom: 96, right: 28,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: const Color(0xFF4ADE80).withOpacity(0.3)),
                ),
                child: Row(children: [
                  const PulsingDot(color: Color(0xFF4ADE80), size: 6),
                  const SizedBox(width: 6),
                  Text(
                    '${status.captureCount} SHOTS · ${status.sessionShort}…',
                    style: GoogleFonts.dmMono(
                        fontSize: 10,
                        color: const Color(0xFF4ADE80).withOpacity(0.9)),
                  ),
                ]),
              ),
            ),

          // ── Snapshot preview ───────────────────────────────────────────
          if (_previewUrl != null)
            Positioned(
              bottom: 100, left: 28,
              child: GestureDetector(
                onTap: () => setState(() => _previewUrl = null),
                child: Container(
                  width: 80, height: 60,
                  decoration: BoxDecoration(
                    border: Border.all(
                        color: const Color(0xFF4ADE80).withOpacity(0.5)),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: Image.network(_previewUrl!, fit: BoxFit.cover),
                  ),
                ),
              ),
            ),

          // ── Action bar ────────────────────────────────────────────────
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              color: Colors.black.withOpacity(0.7),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _ActionBtn(
                    icon: _snapBusy
                        ? Icons.hourglass_top_rounded
                        : Icons.photo_camera_rounded,
                    label: _snapBusy ? 'CAPTURING' : 'SNAPSHOT',
                    color: const Color(0xFF4ADE80),
                    onTap: _takeSnapshot,
                  ),
                  _ActionBtn(
                    icon: Icons.fit_screen_rounded,
                    label: 'FULLSCREEN',
                    color: const Color(0xFF86A98E),
                    onTap: () {
                      // Open stream in a new tab for fullscreen
                      html.window.open(streamUrl, '_blank');
                    },
                  ),
                  _ActionBtn(
                    icon: Icons.sensors_rounded,
                    label: isOnline
                        ? '${status!.rssiDbm} dBm'
                        : 'NO SIGNAL',
                    color: const Color(0xFF38BDF8),
                    onTap: null,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCrosshair() {
    return Center(
      child: SizedBox(
        width: 40, height: 40,
        child: CustomPaint(painter: _CrosshairPainter()),
      ),
    );
  }
}

// ─── GPS HUD ──────────────────────────────────────────────────────────────────

class _GpsHud extends StatelessWidget {
  final DroneStatusV3 status;
  const _GpsHud({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: const Color(0xFF4ADE80).withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 6, height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: status.gpsValid
                    ? const Color(0xFF4ADE80)
                    : const Color(0xFFF87171),
              ),
            ),
            const SizedBox(width: 5),
            Text(status.gpsValid ? 'GPS LOCK' : 'NO LOCK',
                style: GoogleFonts.dmMono(
                    fontSize: 9,
                    color: status.gpsValid
                        ? const Color(0xFF4ADE80)
                        : const Color(0xFFF87171))),
          ]),
          const SizedBox(height: 3),
          Text(
            '${status.lat.toStringAsFixed(5)}  ${status.lng.toStringAsFixed(5)}',
            style: GoogleFonts.dmMono(
                fontSize: 9, color: const Color(0xFFE8F5E9).withOpacity(0.8)),
          ),
          Text(
            'ALT ${status.altM.toStringAsFixed(1)} m',
            style: GoogleFonts.dmMono(
                fontSize: 9, color: const Color(0xFF86A98E)),
          ),
        ],
      ),
    );
  }
}

// ─── Offline overlay ──────────────────────────────────────────────────────────

class _OfflineOverlay extends StatelessWidget {
  final String ip;
  final VoidCallback onRetry;
  const _OfflineOverlay({required this.ip, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF1A2A1E),
                border: Border.all(
                    color: const Color(0xFF4ADE80).withOpacity(0.2), width: 2),
              ),
              child: const Icon(Icons.videocam_off_rounded,
                  color: Color(0xFF4A6B51), size: 36),
            ),
            const SizedBox(height: 24),
            Text('NO STREAM',
                style: GoogleFonts.syne(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFFE8F5E9))),
            const SizedBox(height: 8),
            Text('Drone offline · $ip',
                style: GoogleFonts.instrumentSans(
                    fontSize: 13, color: const Color(0xFF86A98E))),
            const SizedBox(height: 28),
            GestureDetector(
              onTap: onRetry,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF4ADE80).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                      color: const Color(0xFF4ADE80).withOpacity(0.4)),
                ),
                child: Text('RETRY',
                    style: GoogleFonts.dmMono(
                        fontSize: 12,
                        letterSpacing: 1.5,
                        color: const Color(0xFF4ADE80))),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Action button ────────────────────────────────────────────────────────────

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  const _ActionBtn(
      {required this.icon,
      required this.label,
      required this.color,
      this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 4),
          Text(label,
              style: GoogleFonts.dmMono(
                  fontSize: 9, letterSpacing: 1, color: color.withOpacity(0.7))),
        ],
      ),
    );
  }
}

// ─── Corner bracket decorator ────────────────────────────────────────────────

class _Corner extends StatelessWidget {
  final bool flip;
  final bool flipV;
  const _Corner({required this.flip, required this.flipV});

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scaleX: flip ? -1 : 1,
      scaleY: flipV ? -1 : 1,
      child: SizedBox(
        width: 28, height: 28,
        child: CustomPaint(painter: _CornerPainter()),
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0xFF4ADE80).withOpacity(0.7)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square;
    canvas.drawLine(Offset.zero, Offset(size.width, 0), p);
    canvas.drawLine(Offset.zero, Offset(0, size.height), p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

class _CrosshairPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0xFF4ADE80).withOpacity(0.25)
      ..strokeWidth = 1.0;
    final cx = size.width / 2;
    final cy = size.height / 2;
    canvas.drawLine(Offset(0, cy), Offset(size.width, cy), p);
    canvas.drawLine(Offset(cx, 0), Offset(cx, size.height), p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}
