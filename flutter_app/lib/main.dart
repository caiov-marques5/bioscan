import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'api.dart';
import 'models.dart';
import 'result_screen.dart';
import 'scan_screen.dart';

void main() => runApp(const BioScanApp());

class BioScanApp extends StatelessWidget {
  const BioScanApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BioScan 3D',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF1F3A5F),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _baseUrl =
      TextEditingController(text: kIsWeb ? '' : 'http://127.0.0.1:8000');
  final _scan = ScanInput.sample();
  bool _loading = false;
  String? _error;

  BioScanApi get _api => BioScanApi(_baseUrl.text.trim());

  bool get _isIOS =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  Future<void> _run(Future<CompositionResult> Function() call) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await call();
      if (!mounted) return;
      Navigator.push(
          context, MaterialPageRoute(builder: (_) => ResultScreen(r)));
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickMeshAndCompute() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['obj', 'ply', 'glb', 'stl'],
      withData: true,
    );
    if (picked == null || picked.files.single.bytes == null) return;
    final f = picked.files.single;
    await _run(() => _api.computeMesh(
          bytes: f.bytes!,
          filename: f.name,
          sex: _scan.sex,
          age: _scan.age,
          weightKg: _scan.weightKg,
          heightCm: _scan.heightCm,
        ));
  }

  void _openScan() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ScanScreen(
          api: _api,
          sex: _scan.sex,
          age: _scan.age,
          weightKg: _scan.weightKg,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('BioScan 3D — protótipo')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _baseUrl,
            decoration: const InputDecoration(
                labelText: 'URL do backend', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          _num('Idade', _scan.age.toDouble(), (v) => _scan.age = v.round()),
          _num('Altura (cm)', _scan.heightCm, (v) => _scan.heightCm = v),
          _num('Peso (kg)', _scan.weightKg, (v) => _scan.weightKg = v),
          _num('Cintura (cm)', _scan.waistCm, (v) => _scan.waistCm = v),
          _num('Quadril (cm)', _scan.hipCm, (v) => _scan.hipCm = v),
          Row(children: [
            const Text('Sexo:  '),
            DropdownButton<String>(
              value: _scan.sex,
              items: const [
                DropdownMenuItem(value: 'male', child: Text('Masculino')),
                DropdownMenuItem(value: 'female', child: Text('Feminino')),
              ],
              onChanged: (v) => setState(() => _scan.sex = v ?? 'male'),
            ),
          ]),
          const SizedBox(height: 12),
          if (_isIOS) ...[
            FilledButton.icon(
              style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2E86AB)),
              onPressed: _loading ? null : _openScan,
              icon: const Icon(Icons.view_in_ar),
              label: const Text('Escanear com câmera (LiDAR)'),
            ),
            const Divider(height: 32),
          ],
          const Text('Modo A: medidas simuladas (segmentos pré-preenchidos).',
              style: TextStyle(color: Colors.grey, fontSize: 13)),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _loading ? null : () => _run(() => _api.compute(_scan)),
            icon: const Icon(Icons.calculate),
            label: const Text('Calcular com medidas'),
          ),
          const Divider(height: 32),
          const Text('Modo B: enviar mesh 3D (OBJ/PLY/GLB/STL em cm).',
              style: TextStyle(color: Colors.grey, fontSize: 13)),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _loading ? null : _pickMeshAndCompute,
            icon: const Icon(Icons.upload_file),
            label: const Text('Enviar scan 3D'),
          ),
          const SizedBox(height: 24),
          if (_loading) const Center(child: CircularProgressIndicator()),
          if (_error != null)
            Card(
              color: Colors.red.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(_error!,
                    style: TextStyle(color: Colors.red.shade900)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _num(String label, double value, void Function(double) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextFormField(
        initialValue: value.toString(),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration:
            InputDecoration(labelText: label, border: const OutlineInputBorder()),
        onChanged: (t) {
          final v = double.tryParse(t);
          if (v != null) onChanged(v);
        },
      ),
    );
  }
}
