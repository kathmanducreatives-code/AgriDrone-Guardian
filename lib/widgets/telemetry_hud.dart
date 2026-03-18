import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../services/connectivity_service.dart';

class TelemetryHud extends StatelessWidget {
  const TelemetryHud({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        final isDirect = provider.connectionState == DroneConnectionState.direct;
        
        return Positioned(
          top: 20,
          left: 20,
          right: 20,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildHudItem(
                      icon: Icons.signal_wifi_4_bar,
                      label: 'RSSI',
                      value: isDirect ? '-42 dBm' : 'N/A',
                      color: isDirect ? Colors.teal : Colors.grey,
                    ),
                    _buildHudItem(
                      icon: Icons.timer_outlined,
                      label: 'LATENCY',
                      value: provider.currentLatency.inMilliseconds > 0 
                          ? '${provider.currentLatency.inMilliseconds}ms' 
                          : '--',
                      color: _getLatencyColor(provider.currentLatency),
                    ),
                    _buildHudItem(
                      icon: Icons.dns_outlined,
                      label: 'IP ADDR',
                      value: provider.esp32Ip,
                      color: Colors.white70,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHudItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }

  Color _getLatencyColor(Duration latency) {
    if (latency == Duration.zero) return Colors.grey;
    if (latency.inMilliseconds < 50) return Colors.teal;
    if (latency.inMilliseconds < 150) return Colors.orange;
    return Colors.red;
  }
}
