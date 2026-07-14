"""Pydantic schemas for the BioScan 3D API."""
from __future__ import annotations
from enum import Enum
from typing import Optional
from pydantic import BaseModel, Field


class Sex(str, Enum):
    male = "male"
    female = "female"


class Segment(str, Enum):
    right_arm = "right_arm"
    left_arm = "left_arm"
    trunk = "trunk"
    right_leg = "right_leg"
    left_leg = "left_leg"


class SegmentInput(BaseModel):
    """Circumference (cm) and length (cm) of one body cylinder, from the 3D mesh."""
    circumference_cm: float = Field(..., gt=0, description="Mean girth of the segment")
    length_cm: float = Field(..., gt=0, description="Length of the segment cylinder")


class ScanInput(BaseModel):
    """Anthropometry + per-segment geometry. Geometry stands in for the 3D mesh."""
    sex: Sex
    age: int = Field(..., ge=10, le=100)
    height_cm: float = Field(..., gt=100, lt=250)
    weight_kg: float = Field(..., gt=25, lt=300)
    waist_cm: float = Field(..., gt=0, description="Waist circumference (for VAT)")
    hip_cm: float = Field(..., gt=0, description="Hip circumference (for VAT)")
    segments: dict[Segment, SegmentInput]
    # Optional Shaped-style visual estimate (0-100). If provided, fused with the geometric branch.
    visual_bodyfat_pct: Optional[float] = Field(None, ge=2, le=70)


class SegmentResult(BaseModel):
    segment: Segment
    volume_l: float
    lean_mass_kg: float
    fat_mass_kg: float
    muscle_mass_kg: float


class CompositionResult(BaseModel):
    # Totals (InBody-style report)
    weight_kg: float
    body_fat_pct: float
    fat_mass_kg: float
    lean_mass_kg: float  # fat-free mass
    skeletal_muscle_mass_kg: float
    total_body_water_l: float
    visceral_fat_level: int
    bmi: float
    ffmi: float
    waist_hip_ratio: float
    # Branch breakdown (transparency about the fusion)
    geometric_body_fat_pct: float
    visual_body_fat_pct: Optional[float]
    fusion_note: str
    # Segmental analysis (the InBody signature)
    segments: list[SegmentResult]
    disclaimer: str
