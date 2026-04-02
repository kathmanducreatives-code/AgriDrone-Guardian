import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/app_providers.dart';
import '../models/drone_models.dart';
import '../widgets/glass_card.dart';
import '../widgets/pulsing_dot.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _ipController = TextEditingController(text: '192.168.1.76');

  static const _crops = [
    {'label': 'Rice', 'icon': Icons.grass},
    {'label': 'Wheat', 'icon': Icons.landscape},
    {'label': 'Maize', 'icon': Icons.eco},
    {'label': 'Tomato', 'icon': Icons.circle},
    {'label': 'Potato', 'icon': Icons.spa},
  ];

  @override
  void dispose() {
    _ipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final configAsync = ref.watch(configProvider);
    final statusAsync = ref.watch(droneStatusProvider);

    final config = configAsync.value ?? AppConfig();
    final isOnline = statusAsync.value?.status.toLowerCase() == 'online';

    if (_ipController.text != config.ip) {
      _ipController.value = TextEditingValue(
        text: config.ip,
        selection: TextSelection.collapsed(offset: config.ip.length),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A0F0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0F0D),
        elevation: 0,
        title: Text(
          'Settings',
          style: GoogleFonts.syne(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: const Color(0xFFE8F5E9),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 60),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Connection Status
            _sectionLabel('CONNECTION'),
            const SizedBox(height: 10),
            GlassCard(
              child: Column(
                children: [
                  _connectionRow(
                    icon: Icons.cloud_queue_rounded,
                    label: 'Firebase RTDB',
                    status: isOnline ? 'CONNECTED' : 'DISCONNECTED',
                    ok: isOnline,
                    subtitle: 'agridrone-guardian.asia-southeast1',
                  ),
                  const SizedBox(height: 16),
                  Divider(height: 1, color: Colors.white.withOpacity(0.06)),
                  const SizedBox(height: 16),
                  _connectionRow(
                    icon: Icons.api_rounded,
                    label: 'Inference API',
                    status: 'RENDER',
                    ok: true,
                    subtitle: 'agridrone-api.onrender.com',
                    trailingWidget: IconButton(
                      icon: const Icon(
                        Icons.copy_rounded,
                        size: 16,
                        color: Color(0xFF4A6B51),
                      ),
                      onPressed: () {
                        Clipboard.setData(
                          const ClipboardData(
                            text: 'https://agridrone-api.onrender.com',
                          ),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Copied!',
                              style: GoogleFonts.instrumentSans(),
                            ),
                            backgroundColor: const Color(0xFF1A2A1E),
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  Divider(height: 1, color: Colors.white.withOpacity(0.06)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFF38BDF8).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.router_rounded,
                          color: Color(0xFF38BDF8),
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _ipController,
                          style: GoogleFonts.dmMono(
                            fontSize: 13,
                            color: const Color(0xFFE8F5E9),
                          ),
                          decoration: InputDecoration(
                            labelText: 'Drone IP Address',
                            labelStyle: GoogleFonts.instrumentSans(
                              fontSize: 12,
                              color: const Color(0xFF4A6B51),
                            ),
                            border: InputBorder.none,
                            isDense: true,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          // Update drone IP via Firebase
                          updateConfig('ip', _ipController.text.trim());
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4ADE80).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: const Color(0xFF4ADE80).withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            'CONNECT',
                            style: GoogleFonts.dmMono(
                              fontSize: 10,
                              letterSpacing: 1,
                              color: const Color(0xFF4ADE80),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Hardware Config
            _sectionLabel('HARDWARE CONFIG'),
            const SizedBox(height: 10),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CROP TYPE',
                    style: GoogleFonts.dmMono(
                      fontSize: 10,
                      letterSpacing: 2,
                      color: const Color(0xFF4A6B51),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _crops.map((c) {
                        final label = c['label'] as String;
                        final icon = c['icon'] as IconData;
                        final selected = config.crop == label;
                        return Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: GestureDetector(
                            onTap: () => updateConfig('crop', label),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: selected
                                    ? const Color(0xFF4ADE80).withOpacity(0.12)
                                    : Colors.white.withOpacity(0.04),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: selected
                                      ? const Color(0xFF4ADE80).withOpacity(0.5)
                                      : Colors.white.withOpacity(0.08),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    icon,
                                    size: 15,
                                    color: selected
                                        ? const Color(0xFF4ADE80)
                                        : const Color(0xFF4A6B51),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    label,
                                    style: GoogleFonts.instrumentSans(
                                      fontSize: 13,
                                      fontWeight: selected
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                      color: selected
                                          ? const Color(0xFFE8F5E9)
                                          : const Color(0xFF86A98E),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Scan interval slider
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'SCAN INTERVAL',
                        style: GoogleFonts.dmMono(
                          fontSize: 10,
                          letterSpacing: 2,
                          color: const Color(0xFF4A6B51),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4ADE80).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFF4ADE80).withOpacity(0.2),
                          ),
                        ),
                        child: Text(
                          '${config.scanInterval}s',
                          style: GoogleFonts.dmMono(
                            fontSize: 13,
                            color: const Color(0xFF4ADE80),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: const Color(0xFF4ADE80),
                      inactiveTrackColor: const Color(
                        0xFF4ADE80,
                      ).withOpacity(0.1),
                      thumbColor: const Color(0xFF4ADE80),
                      overlayColor: const Color(0xFF4ADE80).withOpacity(0.15),
                      trackHeight: 3,
                    ),
                    child: Slider(
                      value: config.scanInterval.toDouble().clamp(10, 300),
                      min: 10,
                      max: 300,
                      divisions: 29,
                      onChanged: (_) {},
                      onChangeEnd: (v) =>
                          updateConfig('scan_interval', v.toInt()),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Confidence threshold slider
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'CONFIDENCE THRESHOLD',
                        style: GoogleFonts.dmMono(
                          fontSize: 10,
                          letterSpacing: 2,
                          color: const Color(0xFF4A6B51),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4ADE80).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFF4ADE80).withOpacity(0.2),
                          ),
                        ),
                        child: Text(
                          '${(config.confidence * 100).toStringAsFixed(0)}%',
                          style: GoogleFonts.dmMono(
                            fontSize: 13,
                            color: const Color(0xFF4ADE80),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: const Color(0xFF4ADE80),
                      inactiveTrackColor: const Color(
                        0xFF4ADE80,
                      ).withOpacity(0.1),
                      thumbColor: const Color(0xFF4ADE80),
                      overlayColor: const Color(0xFF4ADE80).withOpacity(0.15),
                      trackHeight: 3,
                    ),
                    child: Slider(
                      value: config.confidence.clamp(0.1, 0.9),
                      min: 0.1,
                      max: 0.9,
                      divisions: 8,
                      onChanged: (_) {},
                      onChangeEnd: (v) => updateConfig('confidence', v),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // About
            _sectionLabel('ABOUT'),
            const SizedBox(height: 10),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFF4ADE80).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFF4ADE80).withOpacity(0.2),
                          ),
                        ),
                        child: const Icon(
                          Icons.hexagon_outlined,
                          color: Color(0xFF4ADE80),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'AgriDrone Guardian',
                            style: GoogleFonts.syne(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFFE8F5E9),
                            ),
                          ),
                          Text(
                            'Version 2.0.0 · Build 2404A',
                            style: GoogleFonts.dmMono(
                              fontSize: 11,
                              color: const Color(0xFF4A6B51),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Divider(height: 1, color: Colors.white.withOpacity(0.06)),
                  const SizedBox(height: 16),
                  _aboutRow('Module', 'CC4003NI · Agricultural Tech'),
                  _aboutRow('Institution', 'Islington College'),
                  _aboutRow('Validated by', 'London Metropolitan University'),
                  _aboutRow('Firebase Project', 'agridrone-guardian'),
                  _aboutRow(
                    'Inference Engine',
                    'YOLOv8 · FastAPI · Render.com',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _connectionRow({
    required IconData icon,
    required String label,
    required String status,
    required bool ok,
    required String subtitle,
    Widget? trailingWidget,
  }) {
    final color = ok ? const Color(0xFF4ADE80) : const Color(0xFFF87171);
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.instrumentSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFE8F5E9),
                ),
              ),
              Text(
                subtitle,
                style: GoogleFonts.dmMono(
                  fontSize: 10,
                  color: const Color(0xFF4A6B51),
                ),
              ),
            ],
          ),
        ),
        if (trailingWidget != null) trailingWidget,
        Row(
          children: [
            if (ok)
              PulsingDot(color: color, size: 6)
            else
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
            const SizedBox(width: 6),
            Text(
              status,
              style: GoogleFonts.dmMono(
                fontSize: 10,
                letterSpacing: 1,
                color: color,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _aboutRow(String key, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              key,
              style: GoogleFonts.instrumentSans(
                fontSize: 12,
                color: const Color(0xFF4A6B51),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.instrumentSans(
                fontSize: 12,
                color: const Color(0xFF86A98E),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String t) => Text(
    t,
    style: GoogleFonts.dmMono(
      fontSize: 10,
      letterSpacing: 2.5,
      fontWeight: FontWeight.w500,
      color: const Color(0xFF4A6B51),
    ),
  );
}
