import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';

class SettingsScreen extends StatefulWidget {
  static const route = '/settings';
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final farmController = TextEditingController(text: 'Green Valley Farm');
  final locationController = TextEditingController(text: 'Nepal');
  bool alertsEnabled = true;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF5FBF5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text('Settings', style: TextStyle(color: Color(0xFF1B3A1E), fontWeight: FontWeight.w700)),
        iconTheme: const IconThemeData(color: Color(0xFF2E7D32)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Firebase Status Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: (app.firebaseConnected ? const Color(0xFF2E7D32) : const Color(0xFFE53935)).withOpacity(0.25),
              ),
              boxShadow: [BoxShadow(
                color: (app.firebaseConnected ? const Color(0xFF2E7D32) : const Color(0xFFE53935)).withOpacity(0.07),
                blurRadius: 16, offset: const Offset(0, 4),
              )],
            ),
            child: Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: (app.firebaseConnected ? const Color(0xFF2E7D32) : const Color(0xFFE53935)).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    app.firebaseConnected ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
                    color: app.firebaseConnected ? const Color(0xFF2E7D32) : const Color(0xFFE53935),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Firebase Status', style: TextStyle(color: Color(0xFF9E9E9E), fontSize: 11, letterSpacing: 0.5)),
                    const SizedBox(height: 2),
                    Text(
                      app.firebaseConnected ? 'Online · Realtime Sync Active' : 'Offline · Using Cached Data',
                      style: TextStyle(
                        color: app.firebaseConnected ? const Color(0xFF2E7D32) : const Color(0xFFE53935),
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          _SectionHeader(text: 'Farm Details'),
          const SizedBox(height: 10),
          _StyledTextField(controller: farmController, label: 'Farm Name', icon: Icons.home_work_outlined),
          const SizedBox(height: 10),
          _StyledTextField(controller: locationController, label: 'Location', icon: Icons.location_on_outlined),
          const SizedBox(height: 20),

          _SectionHeader(text: 'Notifications'),
          const SizedBox(height: 10),
          _ToggleTile(
            icon: Icons.notifications_outlined,
            title: 'Disease Alerts',
            subtitle: 'Get notified when a new disease is detected',
            value: alertsEnabled,
            onChanged: (v) => setState(() => alertsEnabled = v),
          ),
          const SizedBox(height: 20),

          _SectionHeader(text: 'About'),
          const SizedBox(height: 10),
          _InfoTile(icon: Icons.info_outline, title: 'App Version', subtitle: '1.0.0'),
          _InfoTile(icon: Icons.flight_outlined, title: 'Project', subtitle: 'AgriDrone Guardian'),
          _InfoTile(icon: Icons.cloud_outlined, title: 'Database', subtitle: 'Asia Southeast 1'),
          _InfoTile(icon: Icons.security_outlined, title: 'Firebase Project', subtitle: 'agridrone-guardian'),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 3, height: 14, decoration: BoxDecoration(color: const Color(0xFF2E7D32), borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(color: Color(0xFF2E7D32), fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.3)),
      ],
    );
  }
}

class _StyledTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  const _StyledTextField({required this.controller, required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Color(0xFF1B3A1E)),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF9E9E9E)),
        prefixIcon: Icon(icon, color: const Color(0xFF2E7D32).withOpacity(0.6), size: 20),
        filled: true,
        fillColor: Colors.white,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: const Color(0xFF2E7D32).withOpacity(0.15)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2E7D32), width: 1.5),
        ),
      ),
    );
  }
}

class _ToggleTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _ToggleTile({required this.icon, required this.title, required this.subtitle, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2E7D32).withOpacity(0.12)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: const Color(0xFF2E7D32).withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: const Color(0xFF2E7D32), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Color(0xFF1B3A1E), fontWeight: FontWeight.w600, fontSize: 14)),
                Text(subtitle, style: const TextStyle(color: Color(0xFF9E9E9E), fontSize: 11)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFF2E7D32),
            trackColor: MaterialStateProperty.resolveWith((states) {
              if (states.contains(MaterialState.selected)) return const Color(0xFF2E7D32).withOpacity(0.25);
              return Colors.grey.withOpacity(0.2);
            }),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _InfoTile({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2E7D32).withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF2E7D32).withOpacity(0.5), size: 18),
          const SizedBox(width: 12),
          Expanded(child: Text(title, style: const TextStyle(color: Color(0xFF6B7C6E), fontSize: 13))),
          Text(subtitle, style: const TextStyle(color: Color(0xFF1B3A1E), fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
