import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/drone_status_v3.dart';

/// Talks directly to the ESP32-S3 firmware (port 80).
/// Matches the exact endpoints in webserver.cpp:
///   GET  /status         → DroneStatusV3 JSON
///   GET  /capture        → JPEG bytes (returns image URL after upload)
///   POST /session/start  → {ok, session_id}
///   POST /session/stop   → {ok, session_id, total_captures}
class DroneService {
  final String ip;

  DroneService(this.ip);

  String get _base => 'http://$ip';

  /// Fetches the current telemetry from GET /status.
  /// Throws on timeout / network error.
  Future<DroneStatusV3> getStatus() async {
    final res = await http
        .get(Uri.parse('$_base/status'))
        .timeout(const Duration(seconds: 5));
    if (res.statusCode != 200) {
      throw Exception('GET /status → HTTP ${res.statusCode}');
    }
    return DroneStatusV3.fromJson(
        jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// POSTs to /session/start. Returns the new session UUID.
  Future<String> startSession() async {
    final res = await http
        .post(Uri.parse('$_base/session/start'))
        .timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) {
      throw Exception('POST /session/start → HTTP ${res.statusCode}');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return data['session_id'] as String? ?? '';
  }

  /// POSTs to /session/stop. Returns {session_id, total_captures}.
  Future<Map<String, dynamic>> stopSession() async {
    final res = await http
        .post(Uri.parse('$_base/session/stop'))
        .timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) {
      throw Exception('POST /session/stop → HTTP ${res.statusCode}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// Triggers a high-res capture. The firmware uploads to Supabase
  /// internally if a session is active. Returns the JPEG image bytes
  /// so the app can display an immediate preview.
  Future<List<int>> capture() async {
    final res = await http
        .get(Uri.parse('$_base/capture'))
        .timeout(const Duration(seconds: 30));
    if (res.statusCode != 200) {
      throw Exception('GET /capture → HTTP ${res.statusCode}');
    }
    return res.bodyBytes;
  }

  /// Stream that polls /status every [intervalSeconds] seconds.
  /// Emits null on any error (drone offline) so the UI can show
  /// a disconnected state without crashing.
  Stream<DroneStatusV3?> statusStream({int intervalSeconds = 3}) async* {
    while (true) {
      try {
        yield await getStatus();
      } catch (_) {
        yield null;
      }
      await Future.delayed(Duration(seconds: intervalSeconds));
    }
  }
}
