import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import '../providers/app_provider.dart';

class DeveloperScreen extends StatefulWidget {
  static const route = '/developer';
  const DeveloperScreen({super.key});

  @override
  State<DeveloperScreen> createState() => _DeveloperScreenState();
}

class _DeveloperScreenState extends State<DeveloperScreen> {
  String? _pingResult;
  bool _isPinging = false;

  Future<void> _pingRender() async {
    setState(() {
      _isPinging = true;
      _pingResult = 'Pinging...';
    });
    final sw = Stopwatch()..start();
    try {
      final response = await http.get(Uri.parse('https://agridrone-api.onrender.com/')).timeout(const Duration(seconds: 15));
      sw.stop();
      setState(() {
        _pingResult = 'Status: ${response.statusCode}\nTime: ${sw.elapsedMilliseconds}ms';
      });
    } catch (e) {
      sw.stop();
      setState(() {
        _pingResult = 'Error: $e\nTime: ${sw.elapsedMilliseconds}ms';
      });
    } finally {
      setState(() => _isPinging = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Developer Console', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1B3A1E),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Section(
            title: 'Endpoint Test',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Test Render.com API connectivity', style: TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _isPinging ? null : _pingRender,
                  icon: const Icon(Icons.network_check),
                  label: const Text('Ping Render API'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    foregroundColor: Colors.white,
                  ),
                ),
                if (_pingResult != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(_pingResult!, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          _Section(
            title: 'Manual Override',
            child: Consumer<AppProvider>(
              builder: (context, provider, _) {
                final isActive = provider.droneStatus?.isActive ?? false;
                return Column(
                  children: [
                    SwitchListTile(
                      title: const Text('Mission is_active'),
                      subtitle: const Text('Toggle Firebase drone/status/is_active'),
                      value: isActive,
                      onChanged: (val) => provider.triggerMission(val),
                      activeColor: const Color(0xFF2E7D32),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          _Section(
            title: 'Raw Firebase Data',
            child: Consumer<AppProvider>(
              builder: (context, provider, _) {
                return StreamBuilder<String>(
                  stream: provider.rawDroneStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        snapshot.data ?? '{}',
                        style: const TextStyle(color: Colors.greenAccent, fontFamily: 'monospace', fontSize: 11),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF2E7D32))),
            const Divider(),
            child,
          ],
        ),
      ),
    );
  }
}
