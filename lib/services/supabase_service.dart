import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/drone_log.dart';

/// Queries Supabase REST API directly — no supabase_flutter package needed.
/// Uses the same credentials hard-coded in config.h so both ends are in sync.
class SupabaseService {
  static const _url = 'https://luvostyizefajbltukkc.supabase.co';
  static const _anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9'
      '.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imx1dm9zdHlpemVmYWpibHR1a2tjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzcxMDA1NDgsImV4cCI6MjA5MjY3NjU0OH0'
      '.FcihW48l30A7sxv5IC5GdekKCNTmFo2xEnAebBen5UI';

  static Map<String, String> get _headers => {
        'apikey': _anonKey,
        'Authorization': 'Bearer $_anonKey',
        'Content-Type': 'application/json',
      };

  /// Returns all capture-type logs (log_type=capture), newest first.
  /// Pass [sessionId] to filter to one session, or null for all.
  Future<List<DroneLog>> fetchCaptures({
    String? sessionId,
    int limit = 200,
  }) async {
    final params = <String, String>{
      'log_type': 'eq.capture',
      'order': 'captured_at.desc',
      'limit': '$limit',
      'select': '*',
    };
    if (sessionId != null && sessionId.isNotEmpty) {
      params['session_id'] = 'eq.$sessionId';
    }

    final uri = Uri.parse('$_url/rest/v1/drone_logs')
        .replace(queryParameters: params);
    final res = await http
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 10));

    if (res.statusCode != 200) {
      throw Exception('Supabase drone_logs → HTTP ${res.statusCode}: ${res.body}');
    }
    final list = jsonDecode(res.body) as List<dynamic>;
    return list
        .map((e) => DroneLog.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Returns GPS-track points for a session (log_type=gps), oldest first.
  Future<List<DroneLog>> fetchGpsTrack({
    required String sessionId,
    int limit = 500,
  }) async {
    final params = {
      'log_type': 'eq.gps',
      'session_id': 'eq.$sessionId',
      'order': 'captured_at.asc',
      'limit': '$limit',
      'select': 'id,lat,lng,altitude_m,gps_valid,captured_at',
    };

    final uri = Uri.parse('$_url/rest/v1/drone_logs')
        .replace(queryParameters: params);
    final res = await http
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 10));

    if (res.statusCode != 200) {
      throw Exception('Supabase gps_track → HTTP ${res.statusCode}');
    }
    final list = jsonDecode(res.body) as List<dynamic>;
    return list
        .map((e) => DroneLog.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Returns all distinct session IDs seen in drone_logs, newest first.
  Future<List<String>> fetchSessions() async {
    final uri = Uri.parse('$_url/rest/v1/drone_logs').replace(
      queryParameters: {
        'select': 'session_id',
        'order': 'captured_at.desc',
      },
    );
    final res = await http
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 10));

    if (res.statusCode != 200) return [];
    final list = jsonDecode(res.body) as List<dynamic>;
    final seen = <String>{};
    final result = <String>[];
    for (final row in list) {
      final sid = (row as Map<String, dynamic>)['session_id'] as String?;
      if (sid != null && seen.add(sid)) result.add(sid);
    }
    return result;
  }
}
