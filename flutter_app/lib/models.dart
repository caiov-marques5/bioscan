/// Data models mirroring the BioScan 3D backend schemas.

class SegmentInput {
  final double circumferenceCm;
  final double lengthCm;
  const SegmentInput(this.circumferenceCm, this.lengthCm);

  Map<String, dynamic> toJson() => {
        'circumference_cm': circumferenceCm,
        'length_cm': lengthCm,
      };
}

class ScanInput {
  String sex; // "male" | "female"
  int age;
  double heightCm;
  double weightKg;
  double waistCm;
  double hipCm;
  Map<String, SegmentInput> segments;
  double? visualBodyfatPct;

  ScanInput({
    required this.sex,
    required this.age,
    required this.heightCm,
    required this.weightKg,
    required this.waistCm,
    required this.hipCm,
    required this.segments,
    this.visualBodyfatPct,
  });

  Map<String, dynamic> toJson() => {
        'sex': sex,
        'age': age,
        'height_cm': heightCm,
        'weight_kg': weightKg,
        'waist_cm': waistCm,
        'hip_cm': hipCm,
        'segments': segments.map((k, v) => MapEntry(k, v.toJson())),
        if (visualBodyfatPct != null) 'visual_bodyfat_pct': visualBodyfatPct,
      };

  /// A sensible default so the demo screen is pre-filled.
  factory ScanInput.sample() => ScanInput(
        sex: 'male',
        age: 32,
        heightCm: 178,
        weightKg: 80,
        waistCm: 88,
        hipCm: 98,
        segments: {
          'right_arm': const SegmentInput(32, 58),
          'left_arm': const SegmentInput(31.5, 58),
          'trunk': const SegmentInput(95, 54),
          'right_leg': const SegmentInput(56, 80),
          'left_leg': const SegmentInput(55.5, 80),
        },
        visualBodyfatPct: 19,
      );
}

class SegmentResult {
  final String segment;
  final double volumeL, leanMassKg, fatMassKg, muscleMassKg;
  SegmentResult.fromJson(Map<String, dynamic> j)
      : segment = j['segment'],
        volumeL = (j['volume_l'] as num).toDouble(),
        leanMassKg = (j['lean_mass_kg'] as num).toDouble(),
        fatMassKg = (j['fat_mass_kg'] as num).toDouble(),
        muscleMassKg = (j['muscle_mass_kg'] as num).toDouble();
}

class CompositionResult {
  final double weightKg,
      bodyFatPct,
      fatMassKg,
      leanMassKg,
      skeletalMuscleMassKg,
      totalBodyWaterL,
      bmi,
      ffmi,
      waistHipRatio,
      geometricBodyFatPct;
  final double? visualBodyFatPct;
  final int visceralFatLevel;
  final String fusionNote, disclaimer;
  final List<SegmentResult> segments;

  CompositionResult.fromJson(Map<String, dynamic> j)
      : weightKg = (j['weight_kg'] as num).toDouble(),
        bodyFatPct = (j['body_fat_pct'] as num).toDouble(),
        fatMassKg = (j['fat_mass_kg'] as num).toDouble(),
        leanMassKg = (j['lean_mass_kg'] as num).toDouble(),
        skeletalMuscleMassKg = (j['skeletal_muscle_mass_kg'] as num).toDouble(),
        totalBodyWaterL = (j['total_body_water_l'] as num).toDouble(),
        bmi = (j['bmi'] as num).toDouble(),
        ffmi = (j['ffmi'] as num).toDouble(),
        waistHipRatio = (j['waist_hip_ratio'] as num).toDouble(),
        geometricBodyFatPct = (j['geometric_body_fat_pct'] as num).toDouble(),
        visualBodyFatPct = j['visual_body_fat_pct'] == null
            ? null
            : (j['visual_body_fat_pct'] as num).toDouble(),
        visceralFatLevel = j['visceral_fat_level'] as int,
        fusionNote = j['fusion_note'],
        disclaimer = j['disclaimer'],
        segments = (j['segments'] as List)
            .map((e) => SegmentResult.fromJson(e))
            .toList();
}
