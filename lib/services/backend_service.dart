import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/photo_model.dart';

class BackendService {
  static String baseUrl = 'https://agridrone-api.onrender.com';

  static Uri _uri(String path, [Map<String, String>? params]) {
    final uri = Uri.parse('$baseUrl$path');
    return params != null ? uri.replace(queryParameters: params) : uri;
  }

  Future<Map<String, dynamic>> getCameraStatus(String esp32Ip) async {
    final response = await http.get(
      _uri('/v1/esp32/camera-status', {'esp32_ip': esp32Ip}),
    ).timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) {
      throw Exception('camera-status HTTP ${response.statusCode}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<void> setCameraControl(String esp32Ip, String varName, int val) async {
    final response = await http.post(
      _uri('/v1/esp32/camera-control', {'esp32_ip': esp32Ip}),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'var': varName, 'val': val}),
    ).timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) {
      throw Exception('camera-control HTTP ${response.statusCode}');
    }
  }

  /// Creates a new flight mission. Returns the flight payload including `storage_folder`.
  Future<Map<String, dynamic>> createFlight({
    required String deviceId,
    String fieldId = 'field-default',
    String cropType = 'rice',
    int? captureIntervalMs,
  }) async {
    final response = await http.post(
      _uri('/v1/flights'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'device_id': deviceId,
        'field_id': fieldId,
        'crop_type': cropType,
        if (captureIntervalMs != null) 'capture_interval_ms': captureIntervalMs,
      }),
    ).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception('createFlight HTTP ${response.statusCode}: ${response.body}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Triggers an ESP32 capture and stores it under the flight.
  Future<Map<String, dynamic>> esp32Capture({
    required String flightId,
    required String esp32Ip,
    required int patchIndex,
    String cropType = 'rice',
  }) async {
    final response = await http.post(
      _uri('/v1/flights/$flightId/esp32-capture'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'esp32_ip': esp32Ip,
        'patch_index': patchIndex,
        'crop_type': cropType,
        'gps_fix': false,
      }),
    ).timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw Exception('esp32Capture HTTP ${response.statusCode}: ${response.body}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<List<PhotoModel>> listPhotos({String? flightId, int limit = 50}) async {
    final params = <String, String>{'limit': '$limit'};
    if (flightId != null) params['flight_id'] = flightId;
    final response = await http.get(
      _uri('/v1/photos', params),
    ).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw Exception('listPhotos HTTP ${response.statusCode}');
    }
    final list = jsonDecode(response.body) as List<dynamic>;
    return list.map((e) => PhotoModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Returns the current LAN IP for [deviceId] from the FastAPI device registry.
  /// Returns null if the device hasn't registered or the server is unreachable.
  Future<String?> fetchDeviceIp(String deviceId) async {
    try {
      final response = await http
          .get(_uri('/v1/devices/$deviceId'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['ip'] as String?;
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
