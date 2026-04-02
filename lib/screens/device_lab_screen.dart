import 'dart:async';
import 'dart:html' as html;
import 'dart:ui_web' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/drone_models.dart';
import '../providers/app_providers.dart';
import '../widgets/glass_card.dart';
import '../widgets/pulsing_dot.dart';

class DeviceLabScreen extends ConsumerStatefulWidget {
  const DeviceLabScreen({super.key});

  @override
  ConsumerState<DeviceLabScreen> createState() => _DeviceLabScreenState();
}

class _DeviceLabScreenState extends ConsumerState<DeviceLabScreen>
    with SingleTickerProviderStateMixin {
  static const Color _background = Color(0xFF0A0F0D);
  static const Color _primary = Color(0xFF4ADE80);
  static const Color _secondary = Color(0xFF38BDF8);
  static const Color _warning = Color(0xFFFB923C);
  static const Color _danger = Color(0xFFF87171);
  static const Color _muted = Color(0xFF86A98E);

  late final TabController _tabController;
  final TextEditingController _ipController = TextEditingController();

  int? _scanBaselineTimestamp;
  Timer? _scanTimeoutTimer;
  bool _streamReachable = false;
  int _snapshotNonce = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _scanTimeoutTimer?.cancel();
    _tabController.dispose();
    _ipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final labIpAsync = ref.watch(labDeviceIpProvider);
    final statusAsync = ref.watch(labDeviceStatusProvider);
    final status = statusAsync.asData?.value;
    final config = ref.watch(configProvider).value ?? AppConfig();
    final scanState = ref.watch(labScanStateProvider);
    final inferenceState = ref.watch(labInferenceStateProvider);
    final inferenceResult = ref.watch(labInferenceResultProvider);
    final cameraConfig = ref.watch(labCameraConfigProvider);
    final cameraApplyState = ref.watch(labCameraApplyStateProvider);

    ref.listen<AsyncValue<EspDeviceStatus>>(labDeviceStatusProvider, (
      previous,
      next,
    ) {
      final deviceStatus = next.asData?.value;
      if (deviceStatus == null || !deviceStatus.isOnline) return;

      final sourceIp = ref.read(labCameraConfigSourceIpProvider);
      if (sourceIp != deviceStatus.ip) {
        ref.read(labCameraConfigProvider.notifier).state =
            deviceStatus.cameraConfig;
        ref.read(labCameraConfigSourceIpProvider.notifier).state =
            deviceStatus.ip;
      }
    });

    ref.listen<AsyncValue<Detection>>(latestDetectionProvider, (
      previous,
      next,
    ) {
      if (_scanBaselineTimestamp == null) return;

      final latest = next.asData?.value;
      if (latest == null) return;

      if (latest.timestamp > _scanBaselineTimestamp!) {
        ref.read(labScanStateProvider.notifier).state = LabCommandState.success(
          'scan',
          message: 'New detection received from Firebase',
        );
        _scanTimeoutTimer?.cancel();
        if (mounted) {
          setState(() {
            _scanBaselineTimestamp = null;
          });
        }
      }
    });

    final resolvedIp = labIpAsync.asData?.value ?? status?.ip ?? config.ip;
    if (resolvedIp.isNotEmpty && _ipController.text != resolvedIp) {
      _ipController.value = TextEditingValue(
        text: resolvedIp,
        selection: TextSelection.collapsed(offset: resolvedIp.length),
      );
    }

    final snapshotUrl = _snapshotUrl(resolvedIp);
    final streamUrl = _streamUrl(resolvedIp);
    final isDeviceOnline = status?.isOnline ?? false;

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        elevation: 0,
        title: Text(
          'Device Lab',
          style: GoogleFonts.syne(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: const Color(0xFFE8F5E9),
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: _primary,
          labelColor: _primary,
          unselectedLabelColor: _muted,
          labelStyle: GoogleFonts.dmMono(fontSize: 11, letterSpacing: 1.2),
          tabs: const [
            Tab(text: 'STREAM'),
            Tab(text: 'SCAN'),
            Tab(text: 'UPLOAD'),
            Tab(text: 'CAMERA'),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: _buildConnectionCard(
              context: context,
              labIpAsync: labIpAsync,
              statusAsync: statusAsync,
              resolvedIp: resolvedIp,
              isDeviceOnline: isDeviceOnline,
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildStreamTab(
                  context: context,
                  statusAsync: statusAsync,
                  status: status,
                  streamUrl: streamUrl,
                  snapshotUrl: snapshotUrl,
                  resolvedIp: resolvedIp,
                ),
                _buildScanTab(
                  context: context,
                  isDeviceOnline: isDeviceOnline,
                  scanState: scanState,
                ),
                _buildUploadTab(
                  context: context,
                  config: config,
                  inferenceState: inferenceState,
                  inferenceResult: inferenceResult,
                ),
                _buildCameraTab(
                  context: context,
                  cameraConfig: cameraConfig,
                  applyState: cameraApplyState,
                  canApply: resolvedIp.isNotEmpty && isDeviceOnline,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionCard({
    required BuildContext context,
    required AsyncValue<String> labIpAsync,
    required AsyncValue<EspDeviceStatus> statusAsync,
    required String resolvedIp,
    required bool isDeviceOnline,
  }) {
    final status = statusAsync.asData?.value;
    final isLoading = labIpAsync.isLoading || statusAsync.isLoading;

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'LOCAL ESP32 CONNECTION',
            style: GoogleFonts.dmMono(
              fontSize: 10,
              letterSpacing: 2,
              color: _muted,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ipController,
                  style: GoogleFonts.dmMono(
                    fontSize: 13,
                    color: const Color(0xFFE8F5E9),
                  ),
                  decoration: InputDecoration(
                    labelText: 'ESP32 IP Address',
                    labelStyle: GoogleFonts.instrumentSans(
                      fontSize: 12,
                      color: _muted,
                    ),
                    filled: true,
                    fillColor: Colors.black.withOpacity(0.15),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Colors.white.withOpacity(0.06),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: _primary.withOpacity(0.55)),
                    ),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _saveDeviceIp(),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: _saveDeviceIp,
                style: FilledButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 16,
                  ),
                ),
                icon: const Icon(Icons.wifi_tethering_rounded, size: 18),
                label: Text(
                  'Connect',
                  style: GoogleFonts.dmMono(fontSize: 11, letterSpacing: 1.0),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _statusChip(
                label: isLoading
                    ? 'Checking device'
                    : isDeviceOnline
                        ? 'Device online'
                        : 'Device offline',
                color: isLoading
                    ? _secondary
                    : isDeviceOnline
                        ? _primary
                        : _danger,
                pulse: isDeviceOnline,
              ),
              _statusChip(
                label:
                    _streamReachable ? 'Stream ready' : 'Stream not confirmed',
                color: _streamReachable ? _secondary : _warning,
              ),
              _statusChip(label: 'IP $resolvedIp', color: _muted),
              if (status != null)
                _statusChip(
                  label: status.uploadMessage,
                  color: status.uploadInProgress
                      ? _warning
                      : status.uploadComplete
                          ? _primary
                          : _muted,
                ),
            ],
          ),
          if (status?.error != null) ...[
            const SizedBox(height: 10),
            Text(
              status!.error!,
              style: GoogleFonts.instrumentSans(fontSize: 12, color: _danger),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStreamTab({
    required BuildContext context,
    required AsyncValue<EspDeviceStatus> statusAsync,
    required EspDeviceStatus? status,
    required String streamUrl,
    required String snapshotUrl,
    required String resolvedIp,
  }) {
    final aspectRatio = 4 / 3;
    final isOnline = status?.isOnline ?? false;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: [
        GlassCard(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'LIVE MJPEG STREAM',
                    style: GoogleFonts.dmMono(
                      fontSize: 10,
                      letterSpacing: 2,
                      color: _muted,
                    ),
                  ),
                  const Spacer(),
                  if (statusAsync.isLoading)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _primary,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              AspectRatio(
                aspectRatio: aspectRatio,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black,
                      border: Border.all(color: Colors.white.withOpacity(0.06)),
                    ),
                    child: isOnline
                        ? Stack(
                            fit: StackFit.expand,
                            children: [
                              _LabStreamView(
                                url: streamUrl,
                                onReachabilityChanged: (ready) {
                                  if (mounted && ready != _streamReachable) {
                                    setState(() {
                                      _streamReachable = ready;
                                    });
                                  }
                                },
                              ),
                              Positioned(
                                top: 12,
                                left: 12,
                                child: _statusChip(
                                  label: 'LIVE',
                                  color: _danger,
                                  pulse: true,
                                ),
                              ),
                              Positioned(
                                top: 12,
                                right: 12,
                                child: _statusChip(
                                  label: status?.cameraConfig.framesizeLabel ??
                                      'Stream',
                                  color: _secondary,
                                ),
                              ),
                            ],
                          )
                        : _buildStreamOfflineState(streamUrl),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _actionButton(
                    label: 'Refresh status',
                    icon: Icons.refresh_rounded,
                    color: _primary,
                    onPressed: _refreshDeviceStatus,
                  ),
                  _actionButton(
                    label: 'Open snapshot',
                    icon: Icons.open_in_new_rounded,
                    color: _secondary,
                    onPressed: () => _launchExternal(snapshotUrl),
                  ),
                  _actionButton(
                    label: 'Refresh snapshot',
                    icon: Icons.photo_camera_back_rounded,
                    color: _warning,
                    onPressed: () {
                      setState(() {
                        _snapshotNonce++;
                      });
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        GlassCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SNAPSHOT PREVIEW',
                style: GoogleFonts.dmMono(
                  fontSize: 10,
                  letterSpacing: 2,
                  color: _muted,
                ),
              ),
              const SizedBox(height: 12),
              AspectRatio(
                aspectRatio: aspectRatio,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: status?.isOnline == true
                      ? Image.network(
                          snapshotUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _buildSnapshotError(),
                        )
                      : _buildSnapshotError(),
                ),
              ),
              const SizedBox(height: 12),
              if (status != null)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _statusChip(
                      label: '${status.bufferedPatchCount} buffered patches',
                      color: _primary,
                    ),
                    _statusChip(
                      label: status.gpsFix
                          ? 'GPS ${status.lat?.toStringAsFixed(5)}, ${status.lon?.toStringAsFixed(5)}'
                          : 'GPS unavailable',
                      color: status.gpsFix ? _secondary : _warning,
                    ),
                    _statusChip(
                      label:
                          '${status.flashUsedBytes ~/ 1024}KB / ${status.flashTotalBytes ~/ 1024}KB',
                      color: _muted,
                    ),
                  ],
                ),
            ],
          ),
        ),
        if (resolvedIp.isNotEmpty) ...[
          const SizedBox(height: 16),
          GlassCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ENDPOINTS',
                  style: GoogleFonts.dmMono(
                    fontSize: 10,
                    letterSpacing: 2,
                    color: _muted,
                  ),
                ),
                const SizedBox(height: 12),
                _endpointText(streamUrl),
                const SizedBox(height: 6),
                _endpointText(snapshotUrl),
                const SizedBox(height: 6),
                _endpointText('http://$resolvedIp:81/api/status'),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildScanTab({
    required BuildContext context,
    required bool isDeviceOnline,
    required LabCommandState scanState,
  }) {
    final latestAsync = ref.watch(latestDetectionProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: [
        GestureDetector(
          onTap: (!scanState.isPending && isDeviceOnline) ? _triggerScan : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: scanState.isPending
                  ? _warning.withOpacity(0.12)
                  : isDeviceOnline
                      ? _primary.withOpacity(0.12)
                      : Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: scanState.isPending
                    ? _warning
                    : isDeviceOnline
                        ? _primary.withOpacity(0.45)
                        : Colors.white.withOpacity(0.08),
                width: 1.4,
              ),
            ),
            child: Column(
              children: [
                if (scanState.isPending)
                  const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: _warning,
                    ),
                  )
                else
                  Icon(
                    Icons.radar_rounded,
                    size: 34,
                    color: isDeviceOnline ? _primary : _muted,
                  ),
                const SizedBox(height: 12),
                Text(
                  scanState.isPending
                      ? 'SCAN REQUEST SENT'
                      : isDeviceOnline
                          ? 'TRIGGER FIREBASE SCAN'
                          : 'DEVICE OFFLINE',
                  style: GoogleFonts.syne(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: scanState.isPending
                        ? _warning
                        : isDeviceOnline
                            ? const Color(0xFFE8F5E9)
                            : _muted,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  scanState.isPending
                      ? 'Waiting for /detection/latest to update'
                      : 'Writes "scan" to Firebase RTDB at /drone/command',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.instrumentSans(
                    fontSize: 13,
                    color: _muted,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        GlassCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SCAN STATE',
                style: GoogleFonts.dmMono(
                  fontSize: 10,
                  letterSpacing: 2,
                  color: _muted,
                ),
              ),
              const SizedBox(height: 12),
              _commandBanner(scanState),
              const SizedBox(height: 12),
              Text(
                'The Lab tab does not poll-wait on the device. It watches Firebase and marks the scan complete when /detection/latest gets a newer timestamp.',
                style: GoogleFonts.instrumentSans(fontSize: 13, color: _muted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        GlassCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'LATEST DETECTION',
                style: GoogleFonts.dmMono(
                  fontSize: 10,
                  letterSpacing: 2,
                  color: _muted,
                ),
              ),
              const SizedBox(height: 12),
              latestAsync.when(
                data: (detection) => _buildDetectionCard(detection),
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(color: _primary),
                  ),
                ),
                error: (error, _) => Text(
                  error.toString(),
                  style: GoogleFonts.instrumentSans(
                    fontSize: 13,
                    color: _danger,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUploadTab({
    required BuildContext context,
    required AppConfig config,
    required LabCommandState inferenceState,
    required InferenceResult? inferenceResult,
  }) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: [
        GlassCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'MANUAL MODEL TEST',
                style: GoogleFonts.dmMono(
                  fontSize: 10,
                  letterSpacing: 2,
                  color: _muted,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _statusChip(label: 'Crop ${config.crop}', color: _primary),
                  _statusChip(
                    label: 'Confidence ${config.confidence.toStringAsFixed(2)}',
                    color: _secondary,
                  ),
                  _statusChip(label: 'POST /predict_form', color: _warning),
                ],
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: inferenceState.isPending ? null : _pickAndInfer,
                style: FilledButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
                icon: inferenceState.isPending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                    : const Icon(Icons.upload_file_rounded, size: 18),
                label: Text(
                  inferenceState.isPending ? 'Uploading…' : 'Select image',
                  style: GoogleFonts.dmMono(fontSize: 12, letterSpacing: 1.0),
                ),
              ),
              const SizedBox(height: 12),
              _commandBanner(inferenceState),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (inferenceResult != null)
          _buildInferenceResultCard(inferenceResult)
        else
          GlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Icon(
                  Icons.cloud_upload_outlined,
                  color: _muted,
                  size: 38,
                ),
                const SizedBox(height: 12),
                Text(
                  'Pick a leaf or crop image to send directly to the legacy FastAPI test route.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.instrumentSans(
                    fontSize: 13,
                    color: _muted,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildCameraTab({
    required BuildContext context,
    required CameraConfig cameraConfig,
    required LabCommandState applyState,
    required bool canApply,
  }) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: [
        GlassCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'LIVE CAMERA CONTROL',
                style: GoogleFonts.dmMono(
                  fontSize: 10,
                  letterSpacing: 2,
                  color: _muted,
                ),
              ),
              const SizedBox(height: 12),
              _commandBanner(applyState),
              const SizedBox(height: 12),
              Text(
                'The controls below are hydrated from /api/status on connect, applied over local HTTP via /api/control, and mirrored to Firebase config/camera for persistence.',
                style: GoogleFonts.instrumentSans(fontSize: 13, color: _muted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        GlassCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionLabel('RESOLUTION'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: const [
                  _FramesizeChoice(label: 'VGA 640×480', value: 7),
                  _FramesizeChoice(label: 'SVGA 800×600', value: 8),
                  _FramesizeChoice(label: 'XGA 1024×768', value: 9),
                  _FramesizeChoice(label: 'SXGA 1280×1024', value: 11),
                ],
              ),
              const SizedBox(height: 18),
              _sectionLabel('JPEG QUALITY'),
              _LabSlider(
                value: cameraConfig.quality.toDouble(),
                min: 4,
                max: 30,
                onChanged: (value) => _updateCameraConfig(
                  cameraConfig.copyWith(quality: value.round()),
                ),
              ),
              _sectionLabel('BRIGHTNESS'),
              _LabSlider(
                value: cameraConfig.brightness.toDouble(),
                min: -2,
                max: 2,
                onChanged: (value) => _updateCameraConfig(
                  cameraConfig.copyWith(brightness: value.round()),
                ),
              ),
              _sectionLabel('CONTRAST'),
              _LabSlider(
                value: cameraConfig.contrast.toDouble(),
                min: -2,
                max: 2,
                onChanged: (value) => _updateCameraConfig(
                  cameraConfig.copyWith(contrast: value.round()),
                ),
              ),
              _sectionLabel('SATURATION'),
              _LabSlider(
                value: cameraConfig.saturation.toDouble(),
                min: -2,
                max: 2,
                onChanged: (value) => _updateCameraConfig(
                  cameraConfig.copyWith(saturation: value.round()),
                ),
              ),
              _sectionLabel('SHARPNESS'),
              _LabSlider(
                value: cameraConfig.sharpness.toDouble(),
                min: 0,
                max: 3,
                onChanged: (value) => _updateCameraConfig(
                  cameraConfig.copyWith(sharpness: value.round()),
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: cameraConfig.vflip,
                activeColor: _primary,
                title: Text(
                  'Vertical Flip',
                  style: GoogleFonts.instrumentSans(
                    fontSize: 14,
                    color: const Color(0xFFE8F5E9),
                  ),
                ),
                onChanged: (value) =>
                    _updateCameraConfig(cameraConfig.copyWith(vflip: value)),
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: cameraConfig.hmirror,
                activeColor: _primary,
                title: Text(
                  'Horizontal Mirror',
                  style: GoogleFonts.instrumentSans(
                    fontSize: 14,
                    color: const Color(0xFFE8F5E9),
                  ),
                ),
                onChanged: (value) =>
                    _updateCameraConfig(cameraConfig.copyWith(hmirror: value)),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: canApply ? _applyCameraConfig : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: _primary,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      icon: applyState.isPending
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black,
                              ),
                            )
                          : const Icon(Icons.tune_rounded, size: 18),
                      label: Text(
                        applyState.isPending ? 'Applying…' : 'Apply to ESP32',
                        style: GoogleFonts.dmMono(
                          fontSize: 12,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton(
                    onPressed: () => _updateCameraConfig(const CameraConfig()),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _muted,
                      side: BorderSide(color: Colors.white.withOpacity(0.12)),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                    child: Text(
                      'Reset',
                      style: GoogleFonts.dmMono(
                        fontSize: 12,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetectionCard(Detection detection) {
    final confidence = (detection.confidence * 100).clamp(0, 100);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          detection.disease,
          style: GoogleFonts.syne(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: const Color(0xFFE8F5E9),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _statusChip(
              label: '${confidence.toStringAsFixed(1)}% confidence',
              color: _primary,
            ),
            _statusChip(
              label: detection.severity,
              color: _severityColor(detection.severity),
            ),
            _statusChip(label: detection.crop, color: _secondary),
          ],
        ),
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: LinearProgressIndicator(
            value: detection.confidence.clamp(0.0, 1.0),
            minHeight: 10,
            backgroundColor: Colors.white.withOpacity(0.06),
            valueColor: AlwaysStoppedAnimation<Color>(
              _severityColor(detection.severity),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInferenceResultCard(InferenceResult result) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'INFERENCE RESULT',
            style: GoogleFonts.dmMono(
              fontSize: 10,
              letterSpacing: 2,
              color: _muted,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            result.disease,
            style: GoogleFonts.syne(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: const Color(0xFFE8F5E9),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _statusChip(
                label:
                    '${(result.confidence * 100).toStringAsFixed(1)}% confidence',
                color: _primary,
              ),
              _statusChip(
                label: result.severity,
                color: _severityColor(result.severity),
              ),
              if (result.model != null)
                _statusChip(label: result.model!, color: _secondary),
            ],
          ),
          if (result.cropWarning != null && result.cropWarning!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              result.cropWarning!,
              style: GoogleFonts.instrumentSans(fontSize: 13, color: _warning),
            ),
          ],
          if (result.allDetections.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'ALL DETECTIONS',
              style: GoogleFonts.dmMono(
                fontSize: 10,
                letterSpacing: 2,
                color: _muted,
              ),
            ),
            const SizedBox(height: 8),
            ...result.allDetections.map(
              (detection) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        detection.disease,
                        style: GoogleFonts.instrumentSans(
                          fontSize: 13,
                          color: const Color(0xFFE8F5E9),
                        ),
                      ),
                    ),
                    Text(
                      '${(detection.confidence * 100).toStringAsFixed(1)}%',
                      style: GoogleFonts.dmMono(
                        fontSize: 11,
                        color: _severityColor(detection.severity),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (result.latestImageUrl != null ||
              result.latestDecodedImageUrl != null) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                if (result.latestImageUrl != null)
                  _actionButton(
                    label: 'Latest raw image',
                    icon: Icons.image_outlined,
                    color: _secondary,
                    onPressed: () => _launchExternal(result.latestImageUrl!),
                  ),
                if (result.latestDecodedImageUrl != null)
                  _actionButton(
                    label: 'Decoded image',
                    icon: Icons.auto_awesome_motion_outlined,
                    color: _primary,
                    onPressed: () =>
                        _launchExternal(result.latestDecodedImageUrl!),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _saveDeviceIp() async {
    final ip = _ipController.text.trim();
    if (ip.isEmpty) return;

    await ref.read(labDeviceIpProvider.notifier).setIp(ip);
    _refreshDeviceStatus();
  }

  void _refreshDeviceStatus() {
    ref.invalidate(labDeviceStatusProvider);
    if (mounted) {
      setState(() {
        _streamReachable = false;
        _snapshotNonce++;
      });
    }
  }

  Future<void> _triggerScan() async {
    final baseline =
        ref.read(latestDetectionProvider).asData?.value.timestamp ?? 0;
    ref.read(labScanStateProvider.notifier).state = LabCommandState.pending(
      'scan',
      message: 'Command written to Firebase. Waiting for detection update…',
    );

    try {
      await triggerScanCommand();
      _scanTimeoutTimer?.cancel();
      _scanTimeoutTimer = Timer(const Duration(seconds: 30), () {
        ref.read(labScanStateProvider.notifier).state = LabCommandState.error(
          'scan',
          message: 'Timed out waiting for /detection/latest',
        );
        if (mounted) {
          setState(() {
            _scanBaselineTimestamp = null;
          });
        }
      });

      if (mounted) {
        setState(() {
          _scanBaselineTimestamp = baseline;
        });
      }
    } catch (error) {
      ref.read(labScanStateProvider.notifier).state = LabCommandState.error(
        'scan',
        message: error.toString(),
      );
    }
  }

  Future<void> _pickAndInfer() async {
    final config = ref.read(configProvider).value ?? AppConfig();
    ref.read(labInferenceStateProvider.notifier).state =
        LabCommandState.pending(
      'upload',
      message: 'Uploading image to /predict_form…',
    );
    ref.read(labInferenceResultProvider.notifier).state = null;

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (result == null || result.files.isEmpty) {
        ref.read(labInferenceStateProvider.notifier).state =
            LabCommandState.idle(
          'upload',
          message: 'Image selection cancelled',
        );
        return;
      }

      final file = result.files.single;
      final bytes = file.bytes;
      if (bytes == null) {
        throw Exception('The selected file could not be read in the browser.');
      }

      final inference = await ref.read(inferenceApiServiceProvider).predictForm(
            fileName: file.name,
            bytes: bytes,
            crop: config.crop.toLowerCase(),
            confidence: config.confidence,
          );

      ref.read(labInferenceResultProvider.notifier).state = inference;
      ref.read(labInferenceStateProvider.notifier).state =
          LabCommandState.success(
        'upload',
        message: 'Inference completed and Firebase save was requested',
      );
      ref.invalidate(latestDetectionProvider);
    } catch (error) {
      ref.read(labInferenceStateProvider.notifier).state =
          LabCommandState.error('upload', message: error.toString());
    }
  }

  void _updateCameraConfig(CameraConfig config) {
    ref.read(labCameraConfigProvider.notifier).state = config;
  }

  Future<void> _applyCameraConfig() async {
    final ip = ref.read(labDeviceIpProvider).asData?.value ??
        _ipController.text.trim();
    if (ip.isEmpty) return;

    final config = ref.read(labCameraConfigProvider);
    ref.read(labCameraApplyStateProvider.notifier).state =
        LabCommandState.pending(
      'camera',
      message: 'Sending /api/control to the ESP32…',
    );

    try {
      final applied = await ref
          .read(espApiServiceProvider)
          .applyCameraConfig(ip: ip, config: config);

      ref.read(labCameraConfigProvider.notifier).state = applied;
      ref.read(labCameraConfigSourceIpProvider.notifier).state = ip;
      await updateConfig('camera', applied.toMap());
      ref.read(labCameraApplyStateProvider.notifier).state =
          LabCommandState.success(
        'camera',
        message: 'Camera settings applied successfully',
      );
      _refreshDeviceStatus();
    } catch (error) {
      ref.read(labCameraApplyStateProvider.notifier).state =
          LabCommandState.error('camera', message: error.toString());
    }
  }

  Future<void> _launchExternal(String rawUrl) async {
    final uri = Uri.parse(rawUrl);
    await launchUrl(uri, webOnlyWindowName: '_blank');
  }

  String _streamUrl(String ip) => 'http://$ip:81/stream';

  String _snapshotUrl(String ip) => 'http://$ip:81/capture?t=$_snapshotNonce';

  Widget _buildStreamOfflineState(String streamUrl) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 48, color: _danger),
            const SizedBox(height: 12),
            Text(
              'No stream available',
              style: GoogleFonts.syne(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: const Color(0xFFE8F5E9),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              streamUrl,
              textAlign: TextAlign.center,
              style: GoogleFonts.dmMono(fontSize: 11, color: _muted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSnapshotError() {
    return Container(
      color: Colors.black,
      child: Center(
        child: Text(
          'Snapshot unavailable',
          style: GoogleFonts.dmMono(fontSize: 12, color: _muted),
        ),
      ),
    );
  }

  Widget _commandBanner(LabCommandState state) {
    final color = switch (state.phase) {
      LabCommandPhase.idle => _muted,
      LabCommandPhase.pending => _warning,
      LabCommandPhase.success => _primary,
      LabCommandPhase.error => _danger,
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          Icon(
            switch (state.phase) {
              LabCommandPhase.idle => Icons.radio_button_unchecked_rounded,
              LabCommandPhase.pending => Icons.hourglass_top_rounded,
              LabCommandPhase.success => Icons.check_circle_outline_rounded,
              LabCommandPhase.error => Icons.error_outline_rounded,
            },
            size: 18,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              state.message,
              style: GoogleFonts.instrumentSans(fontSize: 13, color: color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip({
    required String label,
    required Color color,
    bool pulse = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.28),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (pulse) ...[
            PulsingDot(color: color, size: 8),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: GoogleFonts.dmMono(
              fontSize: 10,
              letterSpacing: 1.1,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withOpacity(0.35)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      icon: Icon(icon, size: 16),
      label: Text(
        label,
        style: GoogleFonts.dmMono(fontSize: 11, letterSpacing: 1.0),
      ),
    );
  }

  Widget _endpointText(String value) {
    return SelectableText(
      value,
      style: GoogleFonts.dmMono(fontSize: 11, color: const Color(0xFFE8F5E9)),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.dmMono(fontSize: 10, letterSpacing: 2, color: _muted),
    );
  }

  Color _severityColor(String severity) {
    final normalized = severity.toLowerCase();
    if (normalized.contains('severe')) return _danger;
    if (normalized.contains('moderate')) return _warning;
    return _primary;
  }
}

class _LabStreamView extends StatefulWidget {
  const _LabStreamView({
    required this.url,
    required this.onReachabilityChanged,
  });

  final String url;
  final ValueChanged<bool> onReachabilityChanged;

  @override
  State<_LabStreamView> createState() => _LabStreamViewState();
}

class _LabStreamViewState extends State<_LabStreamView> {
  static int _viewCounter = 0;

  late String _viewType;

  @override
  void initState() {
    super.initState();
    _registerView();
  }

  @override
  void didUpdateWidget(covariant _LabStreamView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      widget.onReachabilityChanged(false);
      _registerView();
    }
  }

  void _registerView() {
    _viewType = 'lab-stream-${_viewCounter++}';

    // ignore: undefined_prefixed_name
    ui.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final frame = html.IFrameElement()
        ..src = widget.url
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.backgroundColor = 'black';

      frame.onLoad.listen((_) => widget.onReachabilityChanged(true));
      frame.onError.listen((_) => widget.onReachabilityChanged(false));
      return frame;
    });
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }
}

class _LabSlider extends StatelessWidget {
  const _LabSlider({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          min.toInt().toString(),
          style: GoogleFonts.dmMono(
            fontSize: 10,
            color: _DeviceLabScreenState._muted,
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: _DeviceLabScreenState._primary,
              inactiveTrackColor: _DeviceLabScreenState._primary.withOpacity(
                0.12,
              ),
              thumbColor: _DeviceLabScreenState._primary,
              overlayColor: _DeviceLabScreenState._primary.withOpacity(0.12),
            ),
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
        ),
        SizedBox(
          width: 42,
          child: Text(
            value.round().toString(),
            textAlign: TextAlign.end,
            style: GoogleFonts.dmMono(
              fontSize: 11,
              color: const Color(0xFFE8F5E9),
            ),
          ),
        ),
      ],
    );
  }
}

class _FramesizeChoice extends ConsumerWidget {
  const _FramesizeChoice({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(labCameraConfigProvider);
    final selected = config.framesize == value;

    return GestureDetector(
      onTap: () {
        ref.read(labCameraConfigProvider.notifier).state = config.copyWith(
          framesize: value,
        );
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? _DeviceLabScreenState._primary.withOpacity(0.12)
              : Colors.black.withOpacity(0.16),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? _DeviceLabScreenState._primary.withOpacity(0.45)
                : Colors.white.withOpacity(0.06),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.dmMono(
            fontSize: 10,
            letterSpacing: 0.6,
            color: selected
                ? _DeviceLabScreenState._primary
                : _DeviceLabScreenState._muted,
          ),
        ),
      ),
    );
  }
}

extension on CameraConfig {
  String get framesizeLabel {
    switch (framesize) {
      case 7:
        return 'VGA';
      case 8:
        return 'SVGA';
      case 9:
        return 'XGA';
      case 11:
        return 'SXGA';
      default:
        return 'Frame $framesize';
    }
  }
}
