"""
BioScan 3D — prototype backend (FastAPI).

Endpoints
  GET  /health              -> liveness
  POST /v1/compute          -> composition from anthropometry + segment geometry
  POST /v1/compute-mesh     -> upload a 3D mesh (OBJ/PLY/GLB) + basic anthropometry;
                               server extracts segments and computes composition
  GET  /v1/sample           -> a ready-made sample ScanInput for quick testing
"""
from __future__ import annotations
import os
import tempfile

from fastapi import FastAPI, UploadFile, File, Form, HTTPException
from fastapi.middleware.cors import CORSMiddleware

from .schemas import ScanInput, Sex, Segment, SegmentInput, CompositionResult
from . import composition

app = FastAPI(
    title="BioScan 3D API",
    version="0.1.0",
    description="Prototype: 3D-geometry body composition (InBody-like + Shaped-like fusion).",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # prototype only
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/health")
def health():
    return {"status": "ok", "service": "bioscan-3d", "version": "0.1.0"}


@app.get("/v1/sample", response_model=ScanInput)
def sample():
    """A realistic sample payload for /v1/compute."""
    return ScanInput(
        sex=Sex.male, age=32, height_cm=178, weight_kg=80,
        waist_cm=88, hip_cm=98,
        segments={
            Segment.right_arm: SegmentInput(circumference_cm=32, length_cm=58),
            Segment.left_arm: SegmentInput(circumference_cm=31.5, length_cm=58),
            Segment.trunk: SegmentInput(circumference_cm=95, length_cm=54),
            Segment.right_leg: SegmentInput(circumference_cm=56, length_cm=80),
            Segment.left_leg: SegmentInput(circumference_cm=55.5, length_cm=80),
        },
        visual_bodyfat_pct=19.0,
    )


@app.post("/v1/compute", response_model=CompositionResult)
def compute(scan: ScanInput):
    if set(scan.segments.keys()) != set(Segment):
        raise HTTPException(422, detail="Provide all 5 segments: "
                            "right_arm, left_arm, trunk, right_leg, left_leg.")
    return composition.compute(scan)


@app.post("/v1/compute-mesh", response_model=CompositionResult)
async def compute_mesh(
    file: UploadFile = File(..., description="Body mesh in cm scale (OBJ/PLY/GLB)"),
    sex: Sex = Form(...),
    age: int = Form(...),
    weight_kg: float = Form(...),
    height_cm: float | None = Form(None),
):
    from . import mesh as mesh_mod
    suffix = os.path.splitext(file.filename or "mesh.obj")[1] or ".obj"
    with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as tmp:
        tmp.write(await file.read())
        tmp_path = tmp.name
    try:
        segments, extras = mesh_mod.extract_segments(tmp_path)
    except Exception as e:
        raise HTTPException(400, detail=f"Mesh processing failed: {e}")
    finally:
        try:
            os.unlink(tmp_path)
        except OSError:
            pass

    scan = ScanInput(
        sex=sex, age=age,
        height_cm=height_cm or extras["height_cm"],
        weight_kg=weight_kg,
        waist_cm=extras["waist_cm"], hip_cm=extras["hip_cm"],
        segments=segments,
    )
    return composition.compute(scan)
