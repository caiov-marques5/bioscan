"""
Composition engine — prototype.

Reproduces the *methodology* of two products (not their proprietary coefficients):

  * InBody-style: Direct Segmental analysis. Body is 5 cylinders (arms, trunk,
    legs). We estimate lean/fat per segment from geometry, then SUM the segments
    (the "sum of segments" approach). Instead of electrical impedance we drive the
    model with volume + circumference extracted from the 3D mesh.

  * Shaped-style: a single visual body-fat % estimate (here a stub/optional input),
    fused with the geometric branch for a more stable final number.

IMPORTANT: coefficients below are illustrative placeholders for a working
prototype. They are NOT clinically validated and must be re-fit against DXA
before any real use.
"""
from __future__ import annotations
import math
from .schemas import (
    ScanInput, Sex, Segment, SegmentInput,
    SegmentResult, CompositionResult,
)

# Approx. tissue densities (kg/L)
DENSITY_LEAN = 1.05
DENSITY_FAT = 0.90

# Fraction of a segment's volume that is lean tissue, baseline by sex.
# Higher circumference-to-length ratio (thicker) => proportionally more fat.
_LEAN_BASE = {Sex.male: 0.82, Sex.female: 0.74}

# Skeletal-muscle fraction of lean mass (rest is water/organs/bone in this model)
_SMM_FRACTION = 0.52
# Total body water as fraction of lean (fat-free) mass — physiological ~0.73
_TBW_FRACTION = 0.72


def _segment_volume_l(seg: SegmentInput) -> float:
    """Cylinder volume from girth + length. Girth = 2*pi*r => r = C/(2*pi)."""
    r_cm = seg.circumference_cm / (2 * math.pi)
    vol_cm3 = math.pi * r_cm * r_cm * seg.length_cm
    return vol_cm3 / 1000.0  # cm^3 -> liters


def _segment_lean_fraction(seg: SegmentInput, sex: Sex) -> float:
    """Thicker cylinders (high C/L) carry proportionally more fat."""
    base = _LEAN_BASE[sex]
    thickness = seg.circumference_cm / seg.length_cm  # dimensionless
    # Penalise lean fraction as thickness grows past a reference of ~0.6
    adj = max(-0.18, min(0.10, (0.6 - thickness) * 0.25))
    return max(0.45, min(0.92, base + adj))


def _geometric_branch(scan: ScanInput) -> tuple[float, list[SegmentResult], float, float]:
    """InBody-like sum-of-segments. Returns (bodyfat_pct, segments, ffm_kg, tbw_l)."""
    seg_results: list[SegmentResult] = []
    total_lean = 0.0
    total_fat = 0.0
    total_smm = 0.0

    # First pass: raw lean/fat per segment from geometry
    raw = {}
    raw_mass_total = 0.0
    for seg_name, seg in scan.segments.items():
        vol = _segment_volume_l(seg)
        lean_frac = _segment_lean_fraction(seg, scan.sex)
        lean_vol = vol * lean_frac
        fat_vol = vol * (1 - lean_frac)
        lean_kg = lean_vol * DENSITY_LEAN
        fat_kg = fat_vol * DENSITY_FAT
        raw[seg_name] = (vol, lean_kg, fat_kg)
        raw_mass_total += lean_kg + fat_kg

    # Scale segment masses so their sum matches the measured body weight
    # (calibrates the geometric volumes to real mass — like using known weight).
    scale = scan.weight_kg / raw_mass_total if raw_mass_total > 0 else 1.0

    for seg_name, (vol, lean_kg, fat_kg) in raw.items():
        lean_kg *= scale
        fat_kg *= scale
        smm_kg = lean_kg * _SMM_FRACTION
        total_lean += lean_kg
        total_fat += fat_kg
        total_smm += smm_kg
        seg_results.append(SegmentResult(
            segment=seg_name,
            volume_l=round(vol, 2),
            lean_mass_kg=round(lean_kg, 2),
            fat_mass_kg=round(fat_kg, 2),
            muscle_mass_kg=round(smm_kg, 2),
        ))

    bodyfat_pct = 100.0 * total_fat / scan.weight_kg
    tbw_l = total_lean * _TBW_FRACTION  # ~1 L water ≈ 1 kg
    # keep segment order stable: arms, trunk, legs
    order = [Segment.right_arm, Segment.left_arm, Segment.trunk,
             Segment.right_leg, Segment.left_leg]
    seg_results.sort(key=lambda s: order.index(s.segment))
    return bodyfat_pct, seg_results, total_lean, tbw_l


def _visceral_fat_level(scan: ScanInput) -> int:
    """Crude VAT level (1-20) from waist and waist-hip ratio + sex."""
    whr = scan.waist_cm / scan.hip_cm
    base = (scan.waist_cm - (90 if scan.sex == Sex.male else 80)) / 3.0
    base += (whr - (0.9 if scan.sex == Sex.male else 0.8)) * 20
    return int(max(1, min(20, round(6 + base))))


def compute(scan: ScanInput) -> CompositionResult:
    geo_bf, segments, ffm_geo, tbw = _geometric_branch(scan)

    # Fusion with the Shaped-style visual estimate, if present.
    if scan.visual_bodyfat_pct is not None:
        # weight geometry a bit more (it has real scale from LiDAR)
        final_bf = 0.6 * geo_bf + 0.4 * scan.visual_bodyfat_pct
        note = ("Fusão: 60% geométrico (InBody-like) + 40% visual (Shaped-like).")
    else:
        final_bf = geo_bf
        note = "Somente ramo geométrico (nenhuma estimativa visual fornecida)."

    fat_mass = scan.weight_kg * final_bf / 100.0
    lean_mass = scan.weight_kg - fat_mass
    smm = sum(s.muscle_mass_kg for s in segments)
    # rescale SMM/TBW to the fused lean mass
    if ffm_geo > 0:
        smm *= lean_mass / ffm_geo
        tbw *= lean_mass / ffm_geo
    bmi = scan.weight_kg / (scan.height_cm / 100) ** 2
    ffmi = lean_mass / (scan.height_cm / 100) ** 2

    return CompositionResult(
        weight_kg=round(scan.weight_kg, 1),
        body_fat_pct=round(final_bf, 1),
        fat_mass_kg=round(fat_mass, 1),
        lean_mass_kg=round(lean_mass, 1),
        skeletal_muscle_mass_kg=round(smm, 1),
        total_body_water_l=round(tbw, 1),
        visceral_fat_level=_visceral_fat_level(scan),
        bmi=round(bmi, 1),
        ffmi=round(ffmi, 1),
        waist_hip_ratio=round(scan.waist_cm / scan.hip_cm, 2),
        geometric_body_fat_pct=round(geo_bf, 1),
        visual_body_fat_pct=(round(scan.visual_bodyfat_pct, 1)
                             if scan.visual_bodyfat_pct is not None else None),
        fusion_note=note,
        segments=segments,
        disclaimer=("Estimativa prototipal, não é dispositivo médico nem "
                    "bioimpedância elétrica. Coeficientes ilustrativos, precisam "
                    "de validação contra DXA."),
    )
