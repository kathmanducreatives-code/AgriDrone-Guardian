import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:html' as html;
import 'dart:ui_web' as ui;
import '../providers/app_providers.dart';
import '../models/drone_models.dart';
import '../widgets/pulsing_dot.dart';

class LiveStreamScreen extends ConsumerStatefulWidget {
  const LiveStreamScreen({super.key});

  @override
  ConsumerState<LiveStreamScreen> createState() => _LiveStreamScreenState();
}

class _LiveStreamScreenState extends ConsumerState<LiveStreamScreen> {
  static bool _registered = false;
  String? _currentUrl;

  void _registerView(String url) {
    if (_registered && _currentUrl == url) return;
    _registered = true;
    _currentUrl = url;
    // ignore: undefined_prefixed_name
    ui.platformViewRegistry.registerViewFactory('mjpeg-stream-$url', (int id) {
      final el = html.IFrameElement()
        ..src = url
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.objectFit = 'cover'
        ..style.backgroundColor = 'black';
      return el;
    });
  }

  @override
  Widget build(BuildContext context) {
    final statusAsync = ref.watch(droneStatusProvider);
    final status = statusAsync.value ?? DroneStatus();
    final ip = status.ip.isNotEmpty ? status.ip : '192.168.1.76';
    final streamUrl = 'http://$ip:81/stream';
    final configAsync = ref.watch(configProvider);
    final crop = configAsync.value?.crop ?? 'Rice';
    final isOnline = status.status.toLowerCase() == 'online';

    _registerView(streamUrl);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // — Stream or offline
          if (isOnline)
            HtmlElementView(viewType: 'mjpeg-stream-$streamUrl')
          else
            _buildOfflineOverlay(context),

          // — Crosshair
          if (isOnline) _buildCrosshair(),

          // — Corner brackets
          const Positioned(top: 60, left: 16, child: _Corner(flip: false, flipV: false)),
          const Positioned(top: 60, right: 16, child: _Corner(flip: true, flipV: false)),
          const Positioned(bottom: 100, left: 16, child: _Corner(flip: false, flipV: true)),
          const Positioned(bottom: 100, right: 16, child: _Corner(flip: true, flipV: true)),

          // — Top HUD
          Positioned(
            top: 52,
            left: 28,
            child: Text('AGRIDRONE GUARDIAN',
                style: GoogleFonts.dmMono(
                    fontSize: 11,
                    letterSpacing: 2.5,
                    color: const Color(0xFF4ADE80).withOpacity(0.8))),
          ),
          Positioned(
            top: 50,
            right: 28,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.55),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: Colors.white.withOpacity(0.12)),
              ),
              child: Row(
                children: [
                  if (isOnline)
                    const PulsingDot(color: Color(0xFFF87171), size: 8)
                  else
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                          color: Color(0xFF4A6B51),
                          shape: BoxShape.circle),
                    ),
                  const SizedBox(width: 7),
                  Text(isOnline ? 'LIVE' : 'OFFLINE',
                      style: GoogleFonts.dmMono(
                          fontSize: 11,
                          letterSpacing: 1.5,
                          color: isOnline
                              ? Colors.white
                              : const Color(0xFF4A6B51))),
                ],
              ),
            ),
          ),

          // — Bottom HUD
          Positioned(
            bottom: 96,
            left: 28,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: const Color(0xFF4ADE80).withOpacity(0.2)),
              ),
              child: Text('${status.camera} · 1024×768',
                  style: GoogleFonts.dmMono(
                      fontSize: 10,
                      color: const Color(0xFF4ADE80).withOpacity(0.8))),
            ),
          ),
          Positioned(
            bottom: 96,
            right: 28,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: const Color(0xFF38BDF8).withOpacity(0.3)),
              ),
              child: Text(crop.toUpperCase(),
                  style: GoogleFonts.dmMono(
                      fontSize: 10,
                      color: const Color(0xFF38BDF8).withOpacity(0.9))),
            ),
          ),

          // — Bottom action bar
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              color: Colors.black.withOpacity(0.7),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _actionBtn(
                      icon: Icons.photo_camera_rounded,
                      label: 'SNAPSHOT',
                      color: const Color(0xFF4ADE80)),
                  _actionBtn(
                      icon: Icons.fullscreen,
                      label: 'FULLSCREEN',
                      color: const Color(0xFF86A98E)),
                  _actionBtn(
                      icon: Icons.hd,
                      label: 'XGA 1024×768',
                      color: const Color(0xFF38BDF8)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfflineOverlay(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Center(
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
            const SizedBox(height: 10),
            Text('Drone is offline or unreachable',
                style: GoogleFonts.instrumentSans(
                    fontSize: 14, color: const Color(0xFF86A98E))),
            const SizedBox(height: 28),
            GestureDetector(
              onTap: () => setState(() {}),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
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

  Widget _buildCrosshair() {
    return Center(
      child: SizedBox(
        width: 40,
        height: 40,
        child: CustomPaint(painter: _CrosshairPainter()),
      ),
    );
  }

  Widget _actionBtn(
      {required IconData icon, required String label, required Color color}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 4),
        Text(label,
            style: GoogleFonts.dmMono(
                fontSize: 9, letterSpacing: 1, color: color.withOpacity(0.7))),
      ],
    );
  }
}

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
        width: 28,
        height: 28,
        child: CustomPaint(painter: _CornerPainter()),
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF4ADE80).withOpacity(0.7)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square;

    canvas.drawLine(Offset.zero, Offset(size.width, 0), paint);
    canvas.drawLine(Offset.zero, Offset(0, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _CrosshairPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF4ADE80).withOpacity(0.25)
      ..strokeWidth = 1.0;

    final cx = size.width / 2;
    final cy = size.height / 2;
    canvas.drawLine(Offset(0, cy), Offset(size.width, cy), paint);
    canvas.drawLine(Offset(cx, 0), Offset(cx, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
