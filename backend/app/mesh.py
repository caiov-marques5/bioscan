"""
Mesh measurement extraction — prototype.

Given a 3D body mesh (OBJ/PLY/GLB) already scaled to real size (the iPhone LiDAR
gives metric scale), slice it horizontally to estimate girths and segment lengths.

For the prototype we use trimesh cross-sections. In production this step would run
against a registered SMPL template so slices are anatomically consistent.
"""
from __future__ import annotations
import numpy as np

try:
    import trimesh
    HAVE_TRIMESH = True
except Exception:  # pragma: no cover
    HAVE_TRIMESH = False

from .schemas import Segment, SegmentInput


def _girth_at_height(mesh, z: float) -> float | None:
    """Perimeter (cm) of the mesh cross-section at height z (mesh units = cm)."""
    section = mesh.section(plane_origin=[0, 0, z], plane_normal=[0, 0, 1])
    if section is None:
        return None
    planar, _ = section.to_planar()
    # sum of closed-loop perimeters; take the largest loop (main body)
    lengths = [entity.length(planar.vertices) if hasattr(entity, "length") else 0
               for entity in planar.entities]
    try:
        return float(planar.length)
    except Exception:
        return float(max(lengths)) if lengths else None


def extract_segments(mesh_path: str) -> tuple[dict[Segment, SegmentInput], dict]:
    """
    Load a mesh and return per-segment circumference/length plus waist/hip.

    Returns (segments_dict, extras) where extras has waist_cm, hip_cm, height_cm.
    Assumes mesh is in centimeters and standing upright with Z as vertical axis.
    """
    if not HAVE_TRIMESH:
        raise RuntimeError("trimesh not installed; install to enable mesh upload.")

    mesh = trimesh.load(mesh_path, force="mesh")
    if mesh.is_empty:
        raise ValueError("Empty or unreadable mesh.")

    zmin, zmax = mesh.bounds[0][2], mesh.bounds[1][2]
    height = zmax - zmin

    def girth(frac: float) -> float:
        g = _girth_at_height(mesh, zmin + frac * height)
        return round(g, 1) if g else 0.0

    # Heights are rough anatomical fractions of stature.
    waist = girth(0.58)
    hip = girth(0.50)
    trunk_girth = girth(0.65)
    arm_girth = girth(0.68)       # upper-arm band (approx, near shoulder line)
    leg_girth = girth(0.30)       # thigh band

    seg_len_arm = 0.32 * height
    seg_len_trunk = 0.30 * height
    seg_len_leg = 0.45 * height

    segments = {
        Segment.right_arm: SegmentInput(circumference_cm=arm_girth or 28, length_cm=seg_len_arm),
        Segment.left_arm: SegmentInput(circumference_cm=arm_girth or 28, length_cm=seg_len_arm),
        Segment.trunk: SegmentInput(circumference_cm=trunk_girth or 90, length_cm=seg_len_trunk),
        Segment.right_leg: SegmentInput(circumference_cm=leg_girth or 52, length_cm=seg_len_leg),
        Segment.left_leg: SegmentInput(circumference_cm=leg_girth or 52, length_cm=seg_len_leg),
    }
    extras = {
        "waist_cm": waist or 85.0,
        "hip_cm": hip or 95.0,
        "height_cm": round(float(height), 1),
    }
    return segments, extras
