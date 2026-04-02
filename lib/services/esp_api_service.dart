import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/drone_models.dart';

class EspApiService {
  const EspApiService();

  Uri _uri(String ip, String path, [Map<String, dynamic>? query]) {
    final queryParameters = query == null
        ? null
        : query.map((key, value) => MapEntry(key, value.toString()));
    return Uri.parse(
      'http://$ip:81$path',
    ).replace(queryParameters: queryParameters);
  }

  Future<EspDeviceStatus> fetchStatus(String ip) async {
    final response = await http
        .get(_uri(ip, '/api/status'))
        .timeout(const Duration(seconds: 4));

    if (response.statusCode != 200) {
      throw Exception('ESP32 status HTTP ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('ESP32 status returned invalid JSON');
    }
    return EspDeviceStatus.fromJson(decoded);
  }

  Future<CameraConfig> applyCameraConfig({
    required String ip,
    required CameraConfig config,
  }) async {
    final response = await http
        .get(_uri(ip, '/api/control', config.toMap()))
        .timeout(const Duration(seconds: 5));

    if (response.statusCode != 200) {
      throw Exception('ESP32 control HTTP ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('ESP32 control returned invalid JSON');
    }

    return CameraConfig.fromMap(decoded);
  }
}
