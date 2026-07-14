import 'package:flutter/material.dart';
import 'models.dart';

/// InBody-style report screen.
class ResultScreen extends StatelessWidget {
  final CompositionResult r;
  const ResultScreen(this.r, {super.key});

  static const _labels = {
    'right_arm': 'Braço D.',
    'left_arm': 'Braço E.',
    'trunk': 'Tronco',
    'right_leg': 'Perna D.',
    'left_leg': 'Perna E.',
  };

  @override
  Widget build(BuildContext context) {
    final maxMuscle = r.segments
        .map((s) => s.muscleMassKg)
        .fold<double>(0, (a, b) => a > b ? a : b);
    return Scaffold(
      appBar: AppBar(title: const Text('Resultado do Scan')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _headline(context),
          const SizedBox(height: 16),
          _metricsGrid(),
          const SizedBox(height: 20),
          const Text('Análise segmentar (massa muscular)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          ...r.segments.map((s) => _segmentBar(s, maxMuscle)),
          const SizedBox(height: 20),
          Card(
            color: const Color(0xFFEEF3F8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Fusão de métodos',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(r.fusionNote),
                  const SizedBox(height: 6),
                  Text('Geométrico (InBody-like): '
                      '${r.geometricBodyFatPct}%'),
                  if (r.visualBodyFatPct != null)
                    Text('Visual (Shaped-like): ${r.visualBodyFatPct}%'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(r.disclaimer,
              style: const TextStyle(
                  fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _headline(BuildContext context) => Card(
        color: const Color(0xFF1F3A5F),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Text('% Gordura corporal',
                  style: TextStyle(color: Colors.white70)),
              Text('${r.bodyFatPct}%',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 48,
                      fontWeight: FontWeight.bold)),
              Text('Massa magra ${r.leanMassKg} kg  ·  Peso ${r.weightKg} kg',
                  style: const TextStyle(color: Colors.white70)),
            ],
          ),
        ),
      );

  Widget _metricsGrid() {
    final items = <List<String>>[
      ['Massa muscular', '${r.skeletalMuscleMassKg} kg'],
      ['Massa de gordura', '${r.fatMassKg} kg'],
      ['Água corporal', '${r.totalBodyWaterL} L'],
      ['Gordura visceral', 'nível ${r.visceralFatLevel}'],
      ['IMC', '${r.bmi}'],
      ['FFMI', '${r.ffmi}'],
      ['Razão cintura-quadril', '${r.waistHipRatio}'],
    ];
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: items
          .map((it) => SizedBox(
                width: 160,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(it[0],
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey)),
                        const SizedBox(height: 4),
                        Text(it[1],
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ))
          .toList(),
    );
  }

  Widget _segmentBar(SegmentResult s, double maxMuscle) {
    final frac = maxMuscle > 0 ? s.muscleMassKg / maxMuscle : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(width: 72, child: Text(_labels[s.segment] ?? s.segment)),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: frac,
                minHeight: 18,
                backgroundColor: const Color(0xFFE0E6EC),
                color: const Color(0xFF2E86AB),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
              width: 56,
              child: Text('${s.muscleMassKg} kg',
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}
