import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/detection_model.dart';
import '../providers/app_provider.dart';
import '../services/backend_service.dart';
import '../services/connectivity_service.dart';
import '../services/firebase_service.dart';

class DeveloperScreen extends StatefulWidget {
  static const route = '/developer';
  const DeveloperScreen({super.key});

  @override
  State<DeveloperScreen> createState() => _DeveloperScreenState();
}

class _DeveloperScreenState extends State<DeveloperScreen> {
  final BackendService _backend = const BackendService();
  final TextEditingController _ipController = TextEditingController();

  bool _isDirectStarting = false;
  bool _isUploading = false;
  int _latestImageVersion = DateTime.now().millisecondsSinceEpoch;
  String _backendCrop = 'rice';
  Uint8List? _selectedImageBytes;
  String? _selectedFileName;
  Map<String, dynamic>? _backendResult;
  String? _backendError;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final app = context.read<AppProvider>();
    if (_ipController.text != app.esp32Ip) {
      _ipController.text = app.esp32Ip;
    }
  }

  @override
  void dispose() {
    _ipController.dispose();
    super.dispose();
  }

  Future<void> _handleDirectStart(BuildContext context, AppProvider app) async {
    setState(() => _isDirectStarting = true);
    final result = await app.forceStartDirect();
    if (!mounted) return;
    setState(() => _isDirectStarting = false);
    _showSnackBar(
      result,
      isError: result.toLowerCase().contains('failed') || result.toLowerCase().contains('timeout'),
    );
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.single.bytes == null) return;

    setState(() {
      _selectedImageBytes = result.files.single.bytes;
      _selectedFileName = result.files.single.name;
      _backendError = null;
    });
  }

  Future<void> _uploadSelectedImage() async {
    if (_selectedImageBytes == null || _selectedFileName == null) {
      _showSnackBar('Choose an image before testing the backend.', isError: true);
      return;
    }

    setState(() {
      _isUploading = true;
      _backendError = null;
    });

    try {
      final result = await _backend.predictFromForm(
        bytes: _selectedImageBytes!,
        fileName: _selectedFileName!,
        crop: _backendCrop,
      );
      if (!mounted) return;
      setState(() {
        _backendResult = result;
        _latestImageVersion = DateTime.now().millisecondsSinceEpoch;
      });
      _showSnackBar('Backend test completed successfully.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _backendError = e.toString());
      _showSnackBar(_backendError!, isError: true);
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  void _refreshLatestImage() {
    setState(() => _latestImageVersion = DateTime.now().millisecondsSinceEpoch);
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError ? Colors.redAccent : const Color(0xFF2E7D32),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final status = app.droneStatus;

    return Scaffold(
      backgroundColor: const Color(0xFFF5FFFA),
      appBar: AppBar(
        title: const Text(
          'Developer Tools',
          style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _DevHeader(),
              const SizedBox(height: 20),
              _SectionCard(
                title: 'ESP32 Controls',
                subtitle: 'Local-only controls for the ESP32-CAM node. These do not depend on Firebase.',
                child: Column(
                  children: [
                    TextField(
                      controller: _ipController,
                      decoration: const InputDecoration(
                        labelText: 'ESP32 IP Address',
                        hintText: '192.168.1.76',
                        prefixIcon: Icon(Icons.router_outlined),
                      ),
                      onSubmitted: app.updateEsp32Ip,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _StatPill(
                            label: 'Current IP',
                            value: app.esp32Ip,
                            color: const Color(0xFF2E7D32),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatPill(
                            label: 'Connection',
                            value: app.connectionState.name.toUpperCase(),
                            color: _connectionColor(app.connectionState),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isDirectStarting
                                ? null
                                : () async {
                                    await app.updateEsp32Ip(_ipController.text);
                                    if (!mounted) return;
                                    await _handleDirectStart(this.context, app);
                                  },
                            icon: _isDirectStarting
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.play_arrow),
                            label: const Text('Trigger /START'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              await app.updateEsp32Ip(_ipController.text);
                              if (!mounted) return;
                              _showSnackBar('ESP32 IP saved for future sessions.');
                            },
                            icon: const Icon(Icons.save_outlined),
                            label: const Text('Save IP'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _SectionCard(
                title: 'Backend Testing',
                subtitle: 'Manual developer tools for the Render API. Use multipart upload testing without touching the raw ESP32 route.',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(value: 'rice', label: Text('Rice')),
                              ButtonSegment(value: 'wheat', label: Text('Wheat')),
                            ],
                            selected: {_backendCrop},
                            onSelectionChanged: (value) {
                              setState(() => _backendCrop = value.first);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed: _pickImage,
                          icon: const Icon(Icons.upload_file_outlined),
                          label: Text(_selectedFileName ?? 'Choose Image'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_selectedImageBytes != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Image.memory(
                          _selectedImageBytes!,
                          height: 200,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      )
                    else
                      const _EmptyStatePanel(
                        icon: Icons.image_search_outlined,
                        title: 'No image selected',
                        message: 'Pick a leaf image to test the backend via POST /predict_form.',
                      ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isUploading ? null : _uploadSelectedImage,
                        icon: _isUploading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.cloud_upload_outlined),
                        label: const Text('Run Backend Test'),
                      ),
                    ),
                    if (_backendError != null) ...[
                      const SizedBox(height: 12),
                      _ErrorBanner(message: _backendError!),
                    ],
                    if (_backendResult != null) ...[
                      const SizedBox(height: 16),
                      _BackendResultCard(result: _backendResult!),
                    ],
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Latest backend debug image',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        IconButton(
                          onPressed: _refreshLatestImage,
                          icon: const Icon(Icons.refresh),
                          tooltip: 'Refresh latest image',
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Image.network(
                          _backend.latestDebugImageUrl(cacheBust: _latestImageVersion),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const _EmptyStatePanel(
                            icon: Icons.broken_image_outlined,
                            title: 'No backend image yet',
                            message: 'Run a backend test or send an ESP32 frame, then refresh this panel.',
                          ),
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return const Center(child: CircularProgressIndicator());
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _SectionCard(
                title: 'Firebase Status',
                subtitle: 'Cloud state from the live Firebase streams currently wired into the app.',
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _StatPill(
                            label: 'Mission Status',
                            value: status?.isActive == true ? 'ACTIVE' : 'IDLE',
                            color: status?.isActive == true ? Colors.orange : const Color(0xFF2E7D32),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatPill(
                            label: 'Crop Type',
                            value: app.selectedCropType,
                            color: const Color(0xFF1565C0),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatPill(
                            label: 'Firebase',
                            value: app.firebaseConnected ? 'CONNECTED' : 'OFFLINE',
                            color: app.firebaseConnected ? Colors.green : Colors.redAccent,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _FirebaseSnapshotCard(
                      latestDetection: app.detections.isNotEmpty ? app.detections.first : null,
                      status: status,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _SectionCard(
                title: 'Diagnostics',
                subtitle: 'Low-level inspection panels for developer verification and cloud/local troubleshooting.',
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _StatPill(
                            label: 'Latency',
                            value: '${app.currentLatency.inMilliseconds} ms',
                            color: const Color(0xFF6A1B9A),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatPill(
                            label: 'Detection Count',
                            value: app.detections.length.toString(),
                            color: const Color(0xFF00897B),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatPill(
                            label: 'Backend Debug URL',
                            value: '/debug/latest.jpg',
                            color: const Color(0xFFEF6C00),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    StreamBuilder<String>(
                      stream: context.read<AppProvider>().rawDroneStream,
                      builder: (context, snapshot) {
                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF101811),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Text(
                            snapshot.data ?? '{}',
                            style: const TextStyle(
                              color: Color(0xFFB7F07A),
                              fontFamily: 'monospace',
                              fontSize: 12,
                            ),
                          ),
                        );
                      },
                    ),
                    _JsonTelemetryFeed(detections: app.detections),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _connectionColor(DroneConnectionState state) {
    switch (state) {
      case DroneConnectionState.direct:
        return Colors.green;
      case DroneConnectionState.cloud:
        return Colors.blue;
      case DroneConnectionState.offline:
        return Colors.redAccent;
    }
  }
}

class _DevHeader extends StatelessWidget {
  const _DevHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF123524), Color(0xFF2E7D32), Color(0xFF7CB342)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Developer Tools',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Local ESP32 controls, backend validation, Firebase inspection, and deployment-safe diagnostics in one place.',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(subtitle, style: const TextStyle(color: Color(0xFF6B7A6D), height: 1.4)),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatPill({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF607060), fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}

class _BackendResultCard extends StatelessWidget {
  final Map<String, dynamic> result;
  const _BackendResultCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final detections = (result['all_detections'] as List?) ?? const [];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF8EF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF2E7D32).withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Result: ${result['disease'] ?? 'Unknown'}', style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text('Confidence: ${result['confidence']}'),
          Text('Debug saved: ${result['debug_saved']}'),
          Text('Firebase saved: ${result['firebase_saved']}'),
          if (detections.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              const JsonEncoder.withIndent('  ').convert(detections),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

class _FirebaseSnapshotCard extends StatelessWidget {
  final DetectionModel? latestDetection;
  final DroneStatus? status;

  const _FirebaseSnapshotCard({
    required this.latestDetection,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FCF7),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF2E7D32).withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Battery: ${status?.battery ?? 0}%'),
          Text('Connected: ${status?.connected == true}'),
          Text('Flying: ${status?.flying == true}'),
          Text('Latest image URL: ${status?.latestImageUrl ?? 'Unavailable'}'),
          const SizedBox(height: 12),
          Text(
            latestDetection == null
                ? 'No Firebase detection available yet.'
                : 'Latest detection: ${latestDetection!.crop} · ${latestDetection!.disease} · ${latestDetection!.confidence.toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.redAccent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.2)),
      ),
      child: Text(message, style: const TextStyle(color: Colors.redAccent)),
    );
  }
}

class _EmptyStatePanel extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _EmptyStatePanel({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAF5),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF2E7D32).withValues(alpha: 0.12)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 34, color: const Color(0xFF2E7D32)),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF607060))),
        ],
      ),
    );
  }
}

class _JsonTelemetryFeed extends StatelessWidget {
  final List<DetectionModel> detections;
  const _JsonTelemetryFeed({required this.detections});

  @override
  Widget build(BuildContext context) {
    final last10 = detections.take(10).toList();

    return Container(
      height: 300,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      clipBehavior: Clip.antiAlias,
      child: last10.isEmpty
          ? const Center(child: Text('Awaiting AI logs...', style: TextStyle(color: Colors.grey)))
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: last10.length,
              separatorBuilder: (_, __) => const Divider(color: Colors.white10),
              itemBuilder: (context, index) {
                final d = last10[index];
                return Text(
                  const JsonEncoder.withIndent('  ').convert(d.toJson()),
                  style: const TextStyle(color: Color(0xFFADFF2F), fontSize: 11, fontFamily: 'monospace'),
                );
              },
            ),
    );
  }
}
