#!/usr/bin/env python3
"""
LuciVerse Embedder Service

Provides vector embeddings for text using sentence-transformers.
Exposes FastAPI endpoint for embedding generation.

Models are loaded from artifact storage or Ollama API.
"""

import asyncio
import logging
import os
from typing import List, Optional

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field
from prometheus_client import Counter, Histogram, make_asgi_app
from sentence_transformers import SentenceTransformer
import torch
import uvicorn

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Prometheus metrics
embedding_requests = Counter(
    "embedder_requests_total", "Total embedding requests", ["status"]
)
embedding_duration = Histogram(
    "embedder_duration_seconds", "Embedding generation duration"
)

# Configuration from environment
MODEL_NAME = os.getenv("MODEL_NAME", "all-MiniLM-L6-v2")
MODEL_PATH = os.getenv("MODEL_PATH", None)
DEVICE = os.getenv("DEVICE", "cuda" if torch.cuda.is_available() else "cpu")
BATCH_SIZE = int(os.getenv("BATCH_SIZE", "32"))
PORT = int(os.getenv("PORT", "8001"))


class EmbedRequest(BaseModel):
    """Request model for embedding generation."""

    texts: List[str] = Field(..., description="List of texts to embed")
    normalize: bool = Field(True, description="Normalize embeddings to unit length")


class EmbedResponse(BaseModel):
    """Response model for embedding generation."""

    embeddings: List[List[float]] = Field(..., description="List of embedding vectors")
    model: str = Field(..., description="Model used for embedding")
    dimension: int = Field(..., description="Embedding dimension")


class HealthResponse(BaseModel):
    """Health check response."""

    status: str
    model: str
    device: str
    gpu_available: bool


# Global model instance
model: Optional[SentenceTransformer] = None


def load_model() -> SentenceTransformer:
    """Load the embedding model."""
    global model

    if model is not None:
        return model

    logger.info(f"Loading model: {MODEL_NAME}")
    logger.info(f"Device: {DEVICE}")

    if MODEL_PATH:
        logger.info(f"Loading from local path: {MODEL_PATH}")
        model = SentenceTransformer(MODEL_PATH, device=DEVICE)
    else:
        logger.info(f"Downloading model from HuggingFace: {MODEL_NAME}")
        model = SentenceTransformer(MODEL_NAME, device=DEVICE)

    logger.info(f"Model loaded successfully. Dimension: {model.get_sentence_embedding_dimension()}")

    return model


# Create FastAPI app
app = FastAPI(
    title="LuciVerse Embedder Service",
    description="Vector embedding service using sentence-transformers",
    version="0.1.0",
)

# Mount Prometheus metrics
metrics_app = make_asgi_app()
app.mount("/metrics", metrics_app)


@app.on_event("startup")
async def startup_event():
    """Load model on startup."""
    logger.info("Starting LuciVerse Embedder Service")
    load_model()


@app.get("/health", response_model=HealthResponse)
async def health():
    """Health check endpoint."""
    return HealthResponse(
        status="healthy",
        model=MODEL_NAME,
        device=DEVICE,
        gpu_available=torch.cuda.is_available(),
    )


@app.post("/embed", response_model=EmbedResponse)
async def embed(request: EmbedRequest):
    """
    Generate embeddings for input texts.

    Args:
        request: EmbedRequest with texts to embed

    Returns:
        EmbedResponse with embeddings
    """
    global model

    if model is None:
        embedding_requests.labels(status="error").inc()
        raise HTTPException(status_code=500, detail="Model not loaded")

    if not request.texts:
        embedding_requests.labels(status="error").inc()
        raise HTTPException(status_code=400, detail="No texts provided")

    try:
        with embedding_duration.time():
            # Generate embeddings
            embeddings = model.encode(
                request.texts,
                batch_size=BATCH_SIZE,
                normalize_embeddings=request.normalize,
                show_progress_bar=False,
            )

        embedding_requests.labels(status="success").inc()

        return EmbedResponse(
            embeddings=embeddings.tolist(),
            model=MODEL_NAME,
            dimension=model.get_sentence_embedding_dimension(),
        )

    except Exception as e:
        embedding_requests.labels(status="error").inc()
        logger.error(f"Embedding error: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/")
async def root():
    """Root endpoint."""
    return {
        "service": "LuciVerse Embedder",
        "version": "0.1.0",
        "model": MODEL_NAME,
        "device": DEVICE,
        "endpoints": {
            "health": "/health",
            "embed": "/embed",
            "metrics": "/metrics",
        },
    }


def main():
    """Run the embedder service."""
    logger.info(f"Starting embedder on 0.0.0.0:{PORT}")

    uvicorn.run(
        app,
        host="0.0.0.0",
        port=PORT,
        log_level="info",
    )


if __name__ == "__main__":
    main()
