import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../services/connectivity_service.dart';

class StatusBar extends StatefulWidget {
  const StatusBar({super.key});

  @override
  State<StatusBar> createState() => _StatusBarState();
}

class _StatusBarState extends State<StatusBar> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(_pulseController);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        Color color;
        String text;
        bool pulse = false;

        switch (provider.connectionState) {
          case DroneConnectionState.direct:
            color = Colors.emerald;
            text = 'DIRECT CONNECTION';
            pulse = true;
            break;
          case DroneConnectionState.cloud:
            color = Colors.blue;
            text = 'CLOUD MONITORING';
            break;
          case DroneConnectionState.offline:
            color = Colors.grey;
            text = 'OFFLINE';
            break;
        }

        return Container(
          width: double.infinity,
          height: 4,
          color: color.withOpacity(0.2),
          child: Stack(
            children: [
              if (pulse)
                FadeTransition(
                  opacity: _pulseAnimation,
                  child: Container(
                    width: double.infinity,
                    height: 4,
                    decoration: BoxDecoration(
                      color: color,
                      boxShadow: [
                        BoxShadow(
                          color: color.withOpacity(0.5),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                )
              else
                Container(
                  width: double.infinity,
                  height: 4,
                  color: color,
                ),
            ],
          ),
        );
      },
    );
  }
}

class ConnectionStatusLabel extends StatelessWidget {
  const ConnectionStatusLabel({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        IconData icon;
        Color color;
        String label;

        switch (provider.connectionState) {
          case DroneConnectionState.direct:
            icon = Icons.wifi;
            color = Colors.emerald;
            label = 'Direct';
            break;
          case DroneConnectionState.cloud:
            icon = Icons.cloud_queue;
            color = Colors.blue;
            label = 'Cloud';
            break;
          case DroneConnectionState.offline:
            icon = Icons.wifi_off;
            color = Colors.grey;
            label = 'Offline';
            break;
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withOpacity(0.5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
