"""
Vercel serverless entrypoint.

Vercel routes /health and /v1/* to this ASGI app (see vercel.json rewrites).
The mesh-upload endpoint depends on heavy libs (trimesh/scipy) that are omitted
from the serverless bundle, so it returns a graceful 400 in production. Run the
full backend locally (see backend/) when you need mesh processing.
"""
import os
import sys

# Make the backend package importable from the repo root.
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "backend"))

from app.main import app  # noqa: E402

# Vercel's Python runtime detects the ASGI `app` object.
