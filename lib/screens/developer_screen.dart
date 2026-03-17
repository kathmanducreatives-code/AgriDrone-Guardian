import 'dart:ui';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import '../providers/app_provider.dart';
import '../models/detection_model.dart';

class DeveloperScreen extends StatefulWidget {
  static const route = '/developer';
  const DeveloperScreen({super.key});

  @override
  State<DeveloperScreen> createState() => _DeveloperScreenState();
}

class _DeveloperScreenState extends State<DeveloperScreen> {
  bool _isDirectStarting = false;

  Future<void> _handleDirectStart(BuildContext context, AppProvider app) async {
    setState(() => _isDirectStarting = true);
    
    final result = await app.forceStartDirect();
    
    if (mounted) {
      setState(() => _isDirectStarting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result),
          behavior: SnackBarBehavior.floating,
          backgroundColor: result.contains('Failed') ? Colors.redAccent : Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final status = app.droneStatus;
    final isCloudConnected = status?.connected ?? false;
    final isActive = status?.isActive ?? false;

    return Scaffold(
      backgroundColor: const Color(0xFFF5FFFA),
      appBar: AppBar(
        title: const Text('Architecture Console', 
          style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // HARDWARE HEALTH CARD
            const _SectionHeader(title: 'Hardware Health'),
            const SizedBox(height: 12),
            _HardwareHealthCard(isCloudConnected: isCloudConnected),
            
            const SizedBox(height: 24),
            
            // MISSION CONTROL
            const _SectionHeader(title: 'Mission cloud controls'),
            const SizedBox(height: 12),
            _MissionControlCard(app: app, isActive: isActive),
            
            const SizedBox(height: 24),
            
            // DIAGNOSTICS
            const _SectionHeader(title: 'Direct Diagnostics'),
            const SizedBox(height: 12),
            _DiagnosticTriggerCard(
              isLoading: _isDirectStarting,
              onPressed: () => _handleDirectStart(context, app),
            ),
            
            const SizedBox(height: 24),
            
            // LIVE TELEMETRY FEED (JSON)
            const _SectionHeader(title: 'Live Telemetry Feed (Raw JSON)'),
            const SizedBox(height: 12),
            _JsonTelemetryFeed(detections: app.detections),
            
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        color: const Color(0xFF2E7D32).withValues(alpha: 0.6),
        fontSize: 10,
        fontWeight: FontWeight.w900,
        letterSpacing: 2,
      ),
    );
  }
}

class _HardwareHealthCard extends StatelessWidget {
  final bool isCloudConnected;
  const _HardwareHealthCard({required this.isCloudConnected});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF2E7D32).withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF2E7D32).withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.router, color: Color(0xFF2E7D32)),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ESP32-CAM Node', style: TextStyle(fontWeight: FontWeight.bold)),
                Text('IP: 192.168.1.76', style: TextStyle(color: Colors.grey, fontSize: 13)),
              ],
            ),
          ),
          _PulseDot(active: isCloudConnected),
        ],
      ),
    );
  }
}

class _PulseDot extends StatefulWidget {
  final bool active;
  const _PulseDot({required this.active});

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.active ? Colors.green : Colors.red;
    return Stack(
      alignment: Alignment.center,
      children: [
        if (widget.active)
          ScaleTransition(
            scale: _animation,
            child: FadeTransition(
              opacity: ReverseAnimation(_animation),
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.4),
                ),
              ),
            ),
          ),
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 4, spreadRadius: 1)
            ],
          ),
        ),
      ],
    );
  }
}

class _MissionControlCard extends StatelessWidget {
  final AppProvider app;
  final bool isActive;
  const _MissionControlCard({required this.app, required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF2E7D32).withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Text('Cloud Trigger', style: TextStyle(fontWeight: FontWeight.bold)),
              const Spacer(),
              _GlassSwitch(
                value: isActive,
                onChanged: (val) => app.triggerMission(val),
              ),
            ],
          ),
          const Divider(height: 32),
          Row(
            children: [
              const Text('Target Crop Config', style: TextStyle(fontWeight: FontWeight.w500)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF2E7D32).withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButton<String>(
                  value: app.selectedCropType,
                  underline: const SizedBox(),
                  icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF2E7D32)),
                  items: ['Rice', 'Wheat'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (val) {
                    if (val != null) app.updateCropConfig(val);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GlassSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const _GlassSwitch({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 54,
        height: 28,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: value ? const Color(0xFF2E7D32).withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.05),
          border: Border.all(color: value ? const Color(0xFF2E7D32).withValues(alpha: 0.3) : Colors.black.withValues(alpha: 0.1)),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutBack,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: value ? const Color(0xFF2E7D32) : Colors.white,
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(0, 2))
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DiagnosticTriggerCard extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onPressed;
  const _DiagnosticTriggerCard({required this.isLoading, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          const Text('Local Hardware Diagnostic', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: isLoading ? null : onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: isLoading 
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Direct Capture Override (HTTP /START)', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
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
