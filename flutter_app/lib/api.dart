import 'dart:convert';
import 'package:http/http.dart' as http;
import 'models.dart';

/// Thin client for the BioScan 3D backend.
class BioScanApi {
  /// Change to your machine's LAN IP when running on a physical device.
  /// Android emulator uses 10.0.2.2 to reach the host's localhost.
  final String baseUrl;
  BioScanApi(this.baseUrl);

  Future<CompositionResult> compute(ScanInput scan) async {
    final res = await http.post(
      Uri.parse('$baseUrl/v1/compute'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(scan.toJson()),
    );
    if (res.statusCode != 200) {
      throw Exception('compute failed (${res.statusCode}): ${res.body}');
    }
    return CompositionResult.fromJson(jsonDecode(res.body));
  }

  Future<CompositionResult> computeMesh({
    required List<int> bytes,
    required String filename,
    required String sex,
    required int age,
    required double weightKg,
    double? heightCm,
  }) async {
    final req = http.MultipartRequest(
        'POST', Uri.parse('$baseUrl/v1/compute-mesh'))
      ..fields['sex'] = sex
      ..fields['age'] = '$age'
      ..fields['weight_kg'] = '$weightKg'
      ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));
    if (heightCm != null) req.fields['height_cm'] = '$heightCm';

    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);
    if (res.statusCode != 200) {
      throw Exception('compute-mesh failed (${res.statusCode}): ${res.body}');
    }
    return CompositionResult.fromJson(jsonDecode(res.body));
  }
}
