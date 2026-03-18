import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

class BackendService {
  static const String defaultBaseUrl = 'https://agridrone-api.onrender.com';

  final String baseUrl;

  const BackendService({this.baseUrl = defaultBaseUrl});

  String latestDebugImageUrl({int? cacheBust}) {
    final ts = cacheBust ?? DateTime.now().millisecondsSinceEpoch;
    return '$baseUrl/debug/latest.jpg?ts=$ts';
  }

  Future<Map<String, dynamic>> predictFromForm({
    required Uint8List bytes,
    required String fileName,
    required String crop,
    double confidence = 0.3,
    bool saveToFirebase = true,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/predict_form'
      '?crop=${Uri.encodeQueryComponent(crop)}'
      '&confidence=$confidence'
      '&save_to_firebase=$saveToFirebase',
    );

    final request = http.MultipartRequest('POST', uri)
      ..files.add(
        http.MultipartFile.fromBytes(
          'image',
          bytes,
          filename: fileName,
        ),
      );

    final response = await request.send();
    final responseBody = await response.stream.bytesToString();
    final decoded = responseBody.isNotEmpty ? jsonDecode(responseBody) : <String, dynamic>{};

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return Map<String, dynamic>.from(decoded as Map);
    }

    final detail = decoded is Map && decoded['detail'] != null
        ? decoded['detail'].toString()
        : 'Backend request failed with ${response.statusCode}.';
    throw Exception(detail);
  }
}
