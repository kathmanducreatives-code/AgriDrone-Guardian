import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/app_providers.dart';
import '../widgets/glass_card.dart';

class MissionScreen extends ConsumerStatefulWidget {
  const MissionScreen({super.key});

  @override
  ConsumerState<MissionScreen> createState() => _MissionScreenState();
}

class _MissionScreenState extends ConsumerState<MissionScreen> {
  final _ipController = TextEditingController();
  final _deviceIdController = TextEditingController(text: 'esp32-drone-01');
  static const _green = Color(0xFF4ADE80);
  static const _bg = Color(0xFF0A0F0D);
  static const _surface = Color(0xFF1A2A1E);
  static const _red = Color(0xFFF87171);
  static const _orange = Color(0xFFFB923C);
  static const _textPrimary = Color(0xFFE8F5E9);
  static const _textSecondary = Color(0xFF86A98E);

  @override
  void initState() {
    super.initState();
    final mission = ref.read(missionProvider);
    _ipController.text = mission.esp32Ip;
  }

  @override
  void dispose() {
    _ipController.dispose();
    _deviceIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mission = ref.watch(missionProvider);

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        title: Text('Mission Control',
            style: GoogleFonts.syne(fontWeight: FontWeight.w800, fontSize: 18, color: _textPrimary)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SessionCounterCard(mission: mission),
            const SizedBox(height: 20),
            _sectionLabel('ESP32 CONNECTION'),
            const SizedBox(height: 10),
            GlassCard(
              child: Column(
                children: [
                  TextField(
                    controller: _ipController,
                    style: GoogleFonts.dmMono(color: _textPrimary, fontSize: 14),
                    decoration: InputDecoration(
                      labelText: 'ESP32 IP',
                      labelStyle: GoogleFonts.instrumentSans(color: _textSecondary, fontSize: 13),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: _green.withOpacity(0.3)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: _green.withOpacity(0.2)),
                      ),
                    ),
                    onChanged: (v) => ref.read(missionProvider.notifier).setEsp32Ip(v.trim()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _deviceIdController,
                    style: GoogleFonts.dmMono(color: _textPrimary, fontSize: 14),
                    decoration: InputDecoration(
                      labelText: 'Device ID',
                      labelStyle: GoogleFonts.instrumentSans(color: _textSecondary, fontSize: 13),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: _green.withOpacity(0.3)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: _green.withOpacity(0.2)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _sectionLabel('AUTO-CAPTURE'),
            const SizedBox(height: 10),
            GlassCard(
              child: Column(
                children: [
                  if (mission.lastError != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        mission.lastError!,
                        style: GoogleFonts.instrumentSans(color: _red, fontSize: 12),
                      ),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: _ActionButton(
                          label: mission.isAutoCapturing ? 'STOP MISSION' : 'START MISSION',
                          color: mission.isAutoCapturing ? _red : _green,
                          onPressed: () async {
                            if (mission.isAutoCapturing) {
                              ref.read(missionProvider.notifier).stopAutoCapture();
                            } else {
                              await ref.read(missionProvider.notifier).startAutoCapture(
                                    deviceId: _deviceIdController.text.trim().isNotEmpty
                                        ? _deviceIdController.text.trim()
                                        : 'esp32-drone-01',
                                    captureIntervalMs: 5000,
                              );
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  if (mission.isAutoCapturing) ...[
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      backgroundColor: _surface,
                      valueColor: AlwaysStoppedAnimation<Color>(_green.withOpacity(0.7)),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            CameraSettingsPanel(esp32Ip: mission.esp32Ip),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Text(
      label,
      style: GoogleFonts.dmMono(
        fontSize: 11,
        letterSpacing: 2.0,
        color: const Color(0xFF86A98E),
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

class _SessionCounterCard extends StatelessWidget {
  final MissionState mission;

  const _SessionCounterCard({required this.mission});

  static const _green = Color(0xFF4ADE80);
  static const _textPrimary = Color(0xFFE8F5E9);
  static const _textSecondary = Color(0xFF86A98E);

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _green.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.camera_alt_outlined, color: _green, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Session: ${mission.sessionCapturedCount} photos',
                  style: GoogleFonts.syne(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: _textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  mission.missionFolder != null
                      ? 'Mission · ${mission.missionFolder}'
                      : 'No active mission',
                  style: GoogleFonts.dmMono(
                    fontSize: 11,
                    color: _textSecondary,
                    letterSpacing: 0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (mission.isAutoCapturing)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _green.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _green.withOpacity(0.4)),
              ),
              child: Text('LIVE',
                  style: GoogleFonts.dmMono(
                      fontSize: 10, color: _green, letterSpacing: 1.5, fontWeight: FontWeight.w700)),
            ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onPressed;

  const _ActionButton({required this.label, required this.color, required this.onPressed});

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
          style: GoogleFonts.dmMono(fontWeight: FontWeight.w700, fontSize: 13, letterSpacing: 1.5)),
    );
  }
}

// ─── Camera Settings Panel ───────────────────────────────────────────────────

class CameraSettingsPanel extends ConsumerStatefulWidget {
  final String esp32Ip;

  const CameraSettingsPanel({super.key, required this.esp32Ip});

  @override
  ConsumerState<CameraSettingsPanel> createState() => _CameraSettingsPanelState();
}

class _CameraSettingsPanelState extends ConsumerState<CameraSettingsPanel> {
  static const _green = Color(0xFF4ADE80);
  static const _textPrimary = Color(0xFFE8F5E9);
  static const _textSecondary = Color(0xFF86A98E);
  static const _surface = Color(0xFF1A2A1E);

  String? _savedVar;
  bool _saveFailed = false;
  bool _loading = false;

  static const _framesizes = [
    {'label': 'QQVGA (160×120)', 'val': 0},
    {'label': 'QVGA (320×240)', 'val': 5},
    {'label': 'VGA (640×480)', 'val': 8},
    {'label': 'SVGA (800×600)', 'val': 9},
    {'label': 'XGA (1024×768)', 'val': 10},
    {'label': 'SXGA (1280×1024)', 'val': 12},
    {'label': 'UXGA (1600×1200)', 'val': 13},
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    await ref.read(missionProvider.notifier).fetchCameraStatus();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _set(String varName, int val) async {
    setState(() {
      _savedVar = null;
      _saveFailed = false;
    });
    final ok = await ref.read(missionProvider.notifier).setCameraControl(varName, val);
    if (mounted) {
      setState(() {
        _savedVar = ok ? varName : null;
        _saveFailed = !ok;
      });
    }
  }

  int _status(String key, int fallback) {
    final cam = ref.watch(missionProvider).cameraStatus;
    if (cam == null) return fallback;
    return (cam[key] as num?)?.toInt() ?? fallback;
  }

  @override
  Widget build(BuildContext context) {
    final cam = ref.watch(missionProvider).cameraStatus;

    return Theme(
      data: Theme.of(context).copyWith(
        dividerColor: Colors.transparent,
      ),
      child: GlassCard(
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(top: 8),
          title: Row(
            children: [
              Icon(Icons.camera_outlined, color: _green, size: 20),
              const SizedBox(width: 10),
              Text('Camera Settings',
                  style: GoogleFonts.syne(
                      fontWeight: FontWeight.w700, fontSize: 14, color: _textPrimary)),
              const Spacer(),
              if (_loading)
                const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: _green)),
              if (!_loading)
                GestureDetector(
                  onTap: _load,
                  child: Icon(Icons.refresh, color: _green.withOpacity(0.7), size: 18),
                ),
            ],
          ),
          children: [
            if (cam == null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text('No camera data. Tap ↻ to fetch.',
                    style: GoogleFonts.instrumentSans(color: _textSecondary, fontSize: 13)),
              )
            else ...[
              if (_savedVar != null)
                _feedback('✓ Saved', _green),
              if (_saveFailed)
                _feedback('✗ Failed to apply', const Color(0xFFF87171)),
              _dividerLabel('RESOLUTION'),
              _dropdownRow(
                label: 'Framesize',
                items: _framesizes,
                currentVal: _status('framesize', 8),
                onChanged: (v) => _set('framesize', v),
              ),
              _dividerLabel('QUALITY'),
              _sliderRow('quality', 'JPEG Quality', 4, 63, _status('quality', 12)),
              _dividerLabel('IMAGE'),
              _sliderRow('brightness', 'Brightness', -2, 2, _status('brightness', 0)),
              _sliderRow('contrast', 'Contrast', -2, 2, _status('contrast', 0)),
              _sliderRow('saturation', 'Saturation', -2, 2, _status('saturation', 0)),
              _dividerLabel('MIRROR / FLIP'),
              _switchRow('hmirror', 'H-Mirror', _status('hmirror', 0) == 1),
              _switchRow('vflip', 'V-Flip', _status('vflip', 0) == 1),
              _dividerLabel('AUTO CONTROLS'),
              _switchRow('awb', 'Auto White Balance', _status('awb', 1) == 1),
              _switchRow('awb_gain', 'AWB Gain', _status('awb_gain', 1) == 1),
              _switchRow('aec', 'Auto Exposure', _status('aec', 1) == 1),
              _switchRow('night_mode', 'Night Mode', _status('night_mode', 0) == 1),
            ],
          ],
        ),
      ),
    );
  }

  Widget _feedback(String msg, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(msg,
          style: GoogleFonts.dmMono(fontSize: 11, color: color, letterSpacing: 0.5)),
    );
  }

  Widget _dividerLabel(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 10, 0, 4),
      child: Text(
        label,
        style: GoogleFonts.dmMono(fontSize: 10, color: _textSecondary, letterSpacing: 1.8),
      ),
    );
  }

  Widget _dropdownRow({
    required String label,
    required List<Map<String, dynamic>> items,
    required int currentVal,
    required void Function(int) onChanged,
  }) {
    final match = items.firstWhere(
      (e) => e['val'] == currentVal,
      orElse: () => items.last,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
              child: Text(label,
                  style: GoogleFonts.instrumentSans(color: _textPrimary, fontSize: 13))),
          DropdownButton<int>(
            value: match['val'] as int,
            dropdownColor: _surface,
            style: GoogleFonts.dmMono(color: _textPrimary, fontSize: 12),
            underline: const SizedBox(),
            items: items.map((e) {
              return DropdownMenuItem<int>(
                value: e['val'] as int,
                child: Text(e['label'] as String),
              );
            }).toList(),
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
          ),
        ],
      ),
    );
  }

  Widget _sliderRow(String varName, String label, int min, int max, int current) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(label,
                style: GoogleFonts.instrumentSans(color: _textPrimary, fontSize: 12)),
          ),
          Expanded(
            child: Slider(
              value: current.clamp(min, max).toDouble(),
              min: min.toDouble(),
              max: max.toDouble(),
              divisions: max - min,
              activeColor: _green,
              inactiveColor: _green.withOpacity(0.15),
              onChanged: (v) => _set(varName, v.round()),
            ),
          ),
          SizedBox(
            width: 28,
            child: Text('$current',
                style: GoogleFonts.dmMono(color: _textSecondary, fontSize: 11)),
          ),
        ],
      ),
    );
  }

  Widget _switchRow(String varName, String label, bool currentValue) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
              child: Text(label,
                  style: GoogleFonts.instrumentSans(color: _textPrimary, fontSize: 13))),
          Switch(
            value: currentValue,
            activeColor: _green,
            onChanged: (v) => _set(varName, v ? 1 : 0),
          ),
        ],
      ),
    );
  }
}
