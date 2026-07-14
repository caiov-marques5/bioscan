import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'api.dart';
import 'models.dart';
import 'result_screen.dart';

/// Camera/LiDAR scan screen. Talks to the native ARKit BodyScanPlugin over a
/// MethodChannel, receives measurements, then calls the backend to compute
/// composition. iOS-only (physical LiDAR device).
class ScanScreen extends StatefulWidget {
  final BioScanApi api;
  final String sex;
  final int age;
  final double weightKg;
  const ScanScreen({
    super.key,
    required this.api,
    required this.sex,
    required this.age,
    required this.weightKg,
  });

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  static const _channel = MethodChannel('bioscan/body_scan');
  String _status = 'Pronto para escanear';
  bool _busy = false;

  Future<void> _scan() async {
    setState(() {
      _busy = true;
      _status = 'Escaneando... fique de corpo inteiro no quadro por ~2s';
    });
    try {
      final supported = await _channel.invokeMethod<bool>('isSupported') ?? false;
      if (!supported) {
        setState(() => _status =
            'Este aparelho não suporta scan (precisa de iPhone Pro com LiDAR).');
        return;
      }
      final raw = await _channel.invokeMethod<Map>('startScan');
      if (raw == null) {
        setState(() => _status = 'Scan não retornou dados.');
        return;
      }

      // Build ScanInput from the native measurements + user anthropometry.
      final segs = (raw['segments'] as Map).map((k, v) {
        final m = v as Map;
        return MapEntry(
          k as String,
          SegmentInput(
            (m['circumference_cm'] as num).toDouble(),
            (m['length_cm'] as num).toDouble(),
          ),
        );
      });
      final scan = ScanInput(
        sex: widget.sex,
        age: widget.age,
        heightCm: (raw['height_cm'] as num).toDouble(),
        weightKg: widget.weightKg,
        waistCm: (raw['waist_cm'] as num).toDouble(),
        hipCm: (raw['hip_cm'] as num).toDouble(),
        segments: segs,
      );

      setState(() => _status = 'Calculando composição...');
      final result = await widget.api.compute(scan);
      if (!mounted) return;
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => ResultScreen(result)));
    } on PlatformException catch (e) {
      setState(() => _status = 'Erro no scan: ${e.message}');
    } catch (e) {
      setState(() => _status = 'Erro: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan por câmera (LiDAR)')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.view_in_ar, size: 96, color: Color(0xFF2E86AB)),
            const SizedBox(height: 24),
            Text(_status, textAlign: TextAlign.center),
            const SizedBox(height: 32),
            if (_busy)
              const CircularProgressIndicator()
            else
              FilledButton.icon(
                onPressed: _scan,
                icon: const Icon(Icons.camera_alt),
                label: const Text('Iniciar scan'),
              ),
            const SizedBox(height: 16),
            const Text(
              'Apoie o celular, afaste-se ~2m e mostre o corpo inteiro. '
              'Só funciona em iPhone Pro com LiDAR.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
