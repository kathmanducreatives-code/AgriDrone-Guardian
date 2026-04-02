import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../models/drone_models.dart';

class InferenceApiService {
  const InferenceApiService({
    this.baseUrl = 'https://agridrone-api.onrender.com',
  });

  final String baseUrl;

  Future<InferenceResult> predictForm({
    required String fileName,
    required Uint8List bytes,
    required String crop,
    required double confidence,
  }) async {
    final uri = Uri.parse('$baseUrl/predict_form').replace(
      queryParameters: {
        'crop': crop,
        'confidence': confidence.toString(),
        'save_to_firebase': 'true',
      },
    );

    final request = http.MultipartRequest('POST', uri)
      ..files.add(
        http.MultipartFile.fromBytes('image', bytes, filename: fileName),
      );

    final streamed = await request.send().timeout(const Duration(seconds: 30));
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode != 200) {
      throw Exception('Inference HTTP ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Inference returned invalid JSON');
    }

    return InferenceResult.fromJson(decoded);
  }
}
