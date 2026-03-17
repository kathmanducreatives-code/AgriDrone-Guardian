import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';

class DeveloperScreen extends StatelessWidget {
  static const route = '/developer';
  const DeveloperScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final isActive = app.droneStatus?.isActive ?? false;

    return Scaffold(
      backgroundColor: const Color(0xFFF5FFFA),
      body: CustomScrollView(
        slivers: [
          _SliverHeader(isActive: isActive),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isActive) const _ActiveMissionBanner(),
                  const SizedBox(height: 16),
                  const _SectionTitle(title: 'Mission Configuration'),
                  const SizedBox(height: 12),
                  const _MissionControlCard(),
                  const SizedBox(height: 24),
                  const _SectionTitle(title: 'Diagnostic Tools'),
                  const SizedBox(height: 12),
                  const _DiagnosticToolsCard(),
                  const SizedBox(height: 24),
                  const _SectionTitle(title: 'Live AI Results Feed'),
                  const SizedBox(height: 12),
                  const _DetectionsFeed(),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SliverHeader extends StatelessWidget {
  final bool isActive;
  const _SliverHeader({required this.isActive});

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 120,
      pinned: true,
      backgroundColor: Colors.white,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Text(
              'Mission Control',
              style: TextStyle(
                color: Color(0xFF1B3A1E),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            if (isActive)
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.emerald,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ActiveMissionBanner extends StatefulWidget {
  const _ActiveMissionBanner();

  @override
  State<_ActiveMissionBanner> createState() => _ActiveMissionBannerState();
}

class _ActiveMissionBannerState extends State<_ActiveMissionBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500))
      ..repeat(reverse: true);
    _opacity = Tween<double>(begin: 0.4, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.emerald.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.emerald.withValues(alpha: 0.3)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.radar, color: Colors.emerald, size: 18),
            SizedBox(width: 8),
            Text(
              'MISSION ACTIVE',
              style: TextStyle(
                color: Colors.emerald,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        color: const Color(0xFF2E7D32).withValues(alpha: 0.6),
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.5,
      ),
    );
  }
}

class _MissionControlCard extends StatelessWidget {
  const _MissionControlCard();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final isActive = app.droneStatus?.isActive ?? false;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF2E7D32).withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Drone Link',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  Text('Remote Command State',
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
              const Spacer(),
              _GlassToggle(
                value: isActive,
                onChanged: (val) => app.triggerMission(val),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(),
          ),
          Row(
            children: [
              const Icon(Icons.grass, color: Color(0xFF2E7D32), size: 20),
              const SizedBox(width: 12),
              const Text('Target Crop',
                  style: TextStyle(fontWeight: FontWeight.w500)),
              const Spacer(),
              DropdownButton<String>(
                value: app.selectedCropType,
                underline: const SizedBox(),
                items: ['Rice', 'Wheat']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) app.updateCropConfig(val);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GlassToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _GlassToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 60,
        height: 32,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: value
              ? Colors.emerald.withValues(alpha: 0.2)
              : Colors.black.withValues(alpha: 0.05),
          border: Border.all(
            color: value
                ? Colors.emerald.withValues(alpha: 0.4)
                : Colors.black.withValues(alpha: 0.1),
          ),
        ),
        padding: const EdgeInsets.all(4),
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutBack,
              left: value ? 28 : 0,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: value ? Colors.emerald : Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: (value ? Colors.emerald : Colors.black)
                          .withValues(alpha: 0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    )
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DiagnosticToolsCard extends StatelessWidget {
  const _DiagnosticToolsCard();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border:
            Border.all(color: const Color(0xFF2E7D32).withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('System diagnostics',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                final result = await app.forceStartDirect();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(result),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              icon: const Icon(Icons.flash_on),
              label: const Text('Force Start (Direct HTTP)'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                foregroundColor: Colors.orange,
                side: const BorderSide(color: Colors.orange),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetectionsFeed extends StatelessWidget {
  const _DetectionsFeed();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final detections = app.detections;

    if (detections.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Center(
          child: Column(
            children: [
              Icon(Icons.inventory_2_outlined, color: Colors.grey, size: 40),
              SizedBox(height: 12),
              Text('No telemetry data received yet',
                  style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: detections.length,
      itemBuilder: (context, index) {
        final d = detections[index];
        final severityColor = _getSeverityColor(d.severity);
        final severityLabel = d.severity.toUpperCase();

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02), blurRadius: 10)
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: d.imageUrl != null
                        ? Image.network(d.imageUrl!, fit: BoxFit.cover)
                        : Container(color: Colors.grey[200]),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                        child: Row(
                          children: [
                            const Icon(Icons.auto_fix_high,
                                color: Colors.white, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              '${(d.confidence * 100).toInt()}% Confidence',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(d.disease,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          Text(d.crop.toUpperCase(),
                              style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 10,
                                  letterSpacing: 1)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: severityColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: severityColor.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        severityLabel,
                        style: TextStyle(
                            color: severityColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 10),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Color _getSeverityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'severe':
        return Colors.red;
      case 'moderate':
        return Colors.orange;
      case 'mild':
        return Colors.green;
      default:
        return Colors.blue;
    }
  }
}
