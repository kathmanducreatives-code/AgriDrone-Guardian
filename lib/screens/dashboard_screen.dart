import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/drone_models.dart';
import '../providers/app_providers.dart';
import '../widgets/glass_card.dart';
import '../widgets/pulsing_dot.dart';
import '../widgets/animated_scan_button.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with TickerProviderStateMixin {
  late final AnimationController _staggerCtrl;
  bool _scanning = false;

  @override
  void initState() {
    super.initState();
    _staggerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
  }

  @override
  void dispose() {
    _staggerCtrl.dispose();
    super.dispose();
  }

  Animation<double> _stagger(int index) {
    final start = index * 0.15;
    final end = (start + 0.5).clamp(0.0, 1.0);
    return CurvedAnimation(
      parent: _staggerCtrl,
      curve: Interval(start, end, curve: Curves.easeOut),
    );
  }

  IconData _signalIcon(int rssi) {
    if (rssi >= -60) return Icons.signal_wifi_4_bar;
    if (rssi >= -70) return Icons.network_wifi_3_bar;
    if (rssi >= -80) return Icons.network_wifi_2_bar;
    return Icons.network_wifi_1_bar;
  }

  Color _signalColor(int rssi) {
    if (rssi >= -60) return const Color(0xFF4ADE80);
    if (rssi >= -70) return const Color(0xFF86EFAC);
    if (rssi >= -80) return const Color(0xFFFB923C);
    return const Color(0xFFF87171);
  }

  String _lastSeenText(int ms) {
    if (ms == 0) return 'never';
    final diff = DateTime.now()
        .difference(DateTime.fromMillisecondsSinceEpoch(ms));
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    return '${diff.inHours}h ago';
  }

  @override
  Widget build(BuildContext context) {
    final statusAsync = ref.watch(droneStatusProvider);
    final latestAsync = ref.watch(latestDetectionProvider);
    final soilAsync = ref.watch(soilDataProvider);

    final status = statusAsync.value ?? DroneStatus();
    final isOnline = status.status.toLowerCase() == 'online';
    final isScanning = _scanning || status.status.toLowerCase() == 'scanning';

    return Scaffold(
      backgroundColor: const Color(0xFF0A0F0D),
      appBar: _buildAppBar(context, status, isOnline),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _sectionLabel('DRONE TELEMETRY'),
            const SizedBox(height: 10),
            FadeTransition(
              opacity: _stagger(0),
              child: SlideTransition(
                position: Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero)
                    .animate(_stagger(0)),
                child: _buildDroneCard(context, status, isOnline),
              ),
            ),
            const SizedBox(height: 28),
            _sectionLabel('LATEST DETECTION'),
            const SizedBox(height: 10),
            FadeTransition(
              opacity: _stagger(1),
              child: SlideTransition(
                position: Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero)
                    .animate(_stagger(1)),
                child: latestAsync.when(
                  data: (d) => _buildDetectionCard(context, d),
                  loading: () => _shimmer(height: 160),
                  error: (_, __) => _buildDetectionEmpty(context),
                ),
              ),
            ),
            const SizedBox(height: 28),
            _sectionLabel('ENVIRONMENT'),
            const SizedBox(height: 10),
            FadeTransition(
              opacity: _stagger(2),
              child: SlideTransition(
                position: Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero)
                    .animate(_stagger(2)),
                child: soilAsync.when(
                  data: (s) => _buildSoilRow(context, s),
                  loading: () => Row(children: [
                    Expanded(child: _shimmer(height: 130)),
                    const SizedBox(width: 10),
                    Expanded(child: _shimmer(height: 130)),
                    const SizedBox(width: 10),
                    Expanded(child: _shimmer(height: 130)),
                  ]),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: AnimatedScanButton(
          isScanning: isScanning,
          onPressed: () async {
            setState(() => _scanning = true);
            await FirebaseDatabase.instance.ref('drone/command').set('scan');
            await Future.delayed(const Duration(seconds: 5));
            if (mounted) setState(() => _scanning = false);
          },
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
      BuildContext context, DroneStatus status, bool isOnline) {
    return AppBar(
      backgroundColor: const Color(0xFF0A0F0D),
      elevation: 0,
      titleSpacing: 16,
      title: Row(
        children: [
          const Icon(Icons.hexagon_outlined,
              color: Color(0xFF4ADE80), size: 26),
          const SizedBox(width: 10),
          Text('AgriDrone',
              style: GoogleFonts.syne(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: const Color(0xFFE8F5E9))),
        ],
      ),
      actions: [
        _pill(
          icon: Icons.battery_full_rounded,
          label: '${status.battery}%',
          iconColor: const Color(0xFF4ADE80),
        ),
        const SizedBox(width: 6),
        _connectedPill(isOnline),
        const SizedBox(width: 6),
        _pill(
          icon: Icons.flight_takeoff_rounded,
          label: status.isFlying ? 'FLYING' : 'GROUNDED',
          iconColor:
              status.isFlying ? const Color(0xFF38BDF8) : const Color(0xFF4A6B51),
        ),
        const SizedBox(width: 14),
      ],
    );
  }

  Widget _pill({required IconData icon, required String label, required Color iconColor}) {
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
          Icon(icon, size: 13, color: iconColor),
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

  Widget _connectedPill(bool isOnline) {
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
          if (isOnline)
            const PulsingDot(color: Color(0xFF4ADE80), size: 8)
          else
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Color(0xFFF87171),
                shape: BoxShape.circle,
              ),
            ),
          const SizedBox(width: 6),
          Text(isOnline ? 'ONLINE' : 'OFFLINE',
              style: GoogleFonts.dmMono(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: isOnline
                    ? const Color(0xFF4ADE80)
                    : const Color(0xFFF87171),
                letterSpacing: 0.5,
              )),
        ],
      ),
    );
  }

  Widget _buildDroneCard(
      BuildContext context, DroneStatus status, bool isOnline) {
    final signalColor = _signalColor(status.rssi);
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
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(status.ip,
                          style: GoogleFonts.dmMono(
                              fontSize: 22,
                              fontWeight: FontWeight.w400,
                              color: const Color(0xFFE8F5E9),
                              letterSpacing: 1)),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(6),
                      border:
                          Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: Text(status.camera,
                        style: GoogleFonts.dmMono(
                            fontSize: 10,
                            color: const Color(0xFF86A98E))),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text('${status.rssi} dBm',
                          style: GoogleFonts.dmMono(
                              fontSize: 11, color: signalColor)),
                      const SizedBox(width: 6),
                      Icon(_signalIcon(status.rssi),
                          color: signalColor, size: 22),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(height: 1, color: Colors.white.withOpacity(0.06)),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(Icons.schedule_rounded,
                  size: 14, color: Color(0xFF86A98E)),
              const SizedBox(width: 6),
              Expanded(
                child: Text('Last seen ${_lastSeenText(status.lastSeen)}',
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.instrumentSans(
                        fontSize: 13, color: const Color(0xFF86A98E))),
              ),
              const SizedBox(width: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isOnline
                      ? const Color(0xFF4ADE80).withOpacity(0.12)
                      : const Color(0xFFF87171).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isOnline
                        ? const Color(0xFF4ADE80).withOpacity(0.4)
                        : const Color(0xFFF87171).withOpacity(0.4),
                  ),
                ),
                child: Text(
                  status.status.toUpperCase(),
                  style: GoogleFonts.dmMono(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: isOnline
                        ? const Color(0xFF4ADE80)
                        : const Color(0xFFF87171),
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetectionCard(BuildContext context, Detection d) {
    final formattedDisease = d.disease.replaceAll('_', ' ');
    final isUnknown =
        d.disease == 'Unknown' || d.confidence == 0 || d.disease.isEmpty;
    final isHealthy = d.disease.toLowerCase() == 'healthy';
    final conf = d.confidence;
    Color sev = const Color(0xFF4ADE80);
    if (conf < 0.4) sev = const Color(0xFFF87171);
    else if (conf < 0.7) sev = const Color(0xFFFB923C);

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1A2A1E), Color(0xFF111A14)],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: const Color(0xFF4ADE80).withOpacity(0.12)),
          boxShadow: [
            BoxShadow(
                color: sev.withOpacity(0.08),
                blurRadius: 20,
                offset: const Offset(0, 8)),
          ],
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: sev,
                  borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      bottomLeft: Radius.circular(20)),
                  boxShadow: [
                    BoxShadow(
                        color: sev.withOpacity(0.5), blurRadius: 10)
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(d.crop.toUpperCase(),
                                style: GoogleFonts.dmMono(
                                    fontSize: 10,
                                    color: const Color(0xFF86A98E),
                                    letterSpacing: 1)),
                          ),
                          if (!isUnknown)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: sev.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                    color: sev.withOpacity(0.4)),
                              ),
                              child: Text(
                                isHealthy
                                    ? 'HEALTHY'
                                    : (conf >= 0.7
                                        ? 'HIGH CONF'
                                        : conf >= 0.4
                                            ? 'MEDIUM'
                                            : 'LOW CONF'),
                                style: GoogleFonts.dmMono(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                    color: sev,
                                    letterSpacing: 0.8),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        isUnknown ? 'Awaiting Scan...' : formattedDisease,
                        style: GoogleFonts.syne(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          color: isUnknown
                              ? const Color(0xFF4A6B51)
                              : const Color(0xFFE8F5E9),
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 18),
                      if (!isUnknown) ...[
                        Row(children: [
                          Text('${(conf * 100).toStringAsFixed(1)}%',
                              style: GoogleFonts.dmMono(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: sev)),
                          const SizedBox(width: 14),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: TweenAnimationBuilder<double>(
                                tween: Tween(begin: 0, end: conf),
                                duration: const Duration(milliseconds: 900),
                                curve: Curves.easeOut,
                                builder: (_, v, __) =>
                                    LinearProgressIndicator(
                                  value: v,
                                  backgroundColor:
                                      Colors.black.withOpacity(0.4),
                                  valueColor:
                                      AlwaysStoppedAnimation<Color>(sev),
                                  minHeight: 10,
                                ),
                              ),
                            ),
                          ),
                        ]),
                        const SizedBox(height: 12),
                      ],
                      Text(
                        d.timestamp > 0
                            ? 'Scanned ${DateFormat('MMM dd · HH:mm').format(DateTime.fromMillisecondsSinceEpoch(d.timestamp))}'
                            : 'No timestamp',
                        style: GoogleFonts.instrumentSans(
                            fontSize: 12,
                            color: const Color(0xFF4A6B51)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetectionEmpty(BuildContext context) {
    return GlassCard(
      child: Center(
        child: Column(children: [
          const Icon(Icons.radar, color: Color(0xFF4A6B51), size: 40),
          const SizedBox(height: 12),
          Text('Awaiting Scan...',
              style: GoogleFonts.syne(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF4A6B51))),
        ]),
      ),
    );
  }

  Widget _buildSoilRow(BuildContext context, SoilData s) {
    return Row(children: [
      Expanded(
          child: _soilCard(
        context,
        icon: Icons.water_drop_rounded,
        value: '${s.moisture.toStringAsFixed(1)}%',
        label: 'MOISTURE',
        tint: const Color(0xFF38BDF8),
        up: true,
      )),
      const SizedBox(width: 10),
      Expanded(
          child: _soilCard(
        context,
        icon: Icons.thermostat_rounded,
        value: '${s.temperature.toStringAsFixed(1)}°',
        label: 'TEMP',
        tint: const Color(0xFFFB923C),
        up: false,
      )),
      const SizedBox(width: 10),
      Expanded(
          child: _soilCard(
        context,
        icon: Icons.cloud_rounded,
        value: '${s.humidity.toStringAsFixed(1)}%',
        label: 'HUMIDITY',
        tint: const Color(0xFF4ADE80),
        up: true,
      )),
    ]);
  }

  Widget _soilCard(BuildContext context,
      {required IconData icon,
      required String value,
      required String label,
      required Color tint,
      required bool up}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            tint.withOpacity(0.08),
            const Color(0xFF111A14),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tint.withOpacity(0.18)),
        boxShadow: [
          BoxShadow(
              color: tint.withOpacity(0.05),
              blurRadius: 16,
              offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: tint.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: tint, size: 18),
              ),
              Icon(
                up ? Icons.arrow_upward : Icons.arrow_downward,
                size: 13,
                color: const Color(0xFF4A6B51),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(value,
              style: GoogleFonts.dmMono(
                  fontSize: 20,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFFE8F5E9))),
          const SizedBox(height: 4),
          Text(label,
              style: GoogleFonts.instrumentSans(
                  fontSize: 10,
                  letterSpacing: 1.5,
                  color: const Color(0xFF4A6B51))),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(text,
        style: GoogleFonts.dmMono(
            fontSize: 10,
            letterSpacing: 2.5,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF4A6B51)));
  }

  Widget _shimmer({required double height}) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF1A2A1E), const Color(0xFF1F3224)],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
    );
  }
}
