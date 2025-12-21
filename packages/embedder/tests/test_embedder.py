"""Tests for embedder service."""

import pytest
from httpx import AsyncClient
from embedder.main import app


@pytest.mark.asyncio
async def test_health():
    """Test health endpoint."""
    async with AsyncClient(app=app, base_url="http://test") as ac:
        response = await ac.get("/health")

    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "healthy"
    assert "model" in data
    assert "device" in data


@pytest.mark.asyncio
async def test_embed_basic():
    """Test basic embedding generation."""
    async with AsyncClient(app=app, base_url="http://test") as ac:
        response = await ac.post(
            "/embed",
            json={"texts": ["Hello world", "Nix is declarative"], "normalize": True},
        )

    assert response.status_code == 200
    data = response.json()
    assert "embeddings" in data
    assert len(data["embeddings"]) == 2
    assert "dimension" in data
    assert data["dimension"] > 0


@pytest.mark.asyncio
async def test_embed_empty():
    """Test embedding with empty input."""
    async with AsyncClient(app=app, base_url="http://test") as ac:
        response = await ac.post("/embed", json={"texts": [], "normalize": True})

    assert response.status_code == 400


@pytest.mark.asyncio
async def test_embed_normalization():
    """Test that normalized embeddings have unit length."""
    import numpy as np

    async with AsyncClient(app=app, base_url="http://test") as ac:
        response = await ac.post(
            "/embed", json={"texts": ["Test normalization"], "normalize": True}
        )

    assert response.status_code == 200
    data = response.json()
    embedding = np.array(data["embeddings"][0])

    # Check unit length (within floating point tolerance)
    length = np.linalg.norm(embedding)
    assert abs(length - 1.0) < 1e-6


@pytest.mark.gpu
@pytest.mark.asyncio
async def test_gpu_inference():
    """Test GPU inference (requires GPU)."""
    import torch

    if not torch.cuda.is_available():
        pytest.skip("GPU not available")

    async with AsyncClient(app=app, base_url="http://test") as ac:
        response = await ac.get("/health")

    assert response.status_code == 200
    data = response.json()
    assert data["gpu_available"] is True


@pytest.mark.asyncio
async def test_batch_processing():
    """Test batch processing with multiple texts."""
    texts = [f"Test sentence {i}" for i in range(100)]

    async with AsyncClient(app=app, base_url="http://test") as ac:
        response = await ac.post("/embed", json={"texts": texts, "normalize": True})

    assert response.status_code == 200
    data = response.json()
    assert len(data["embeddings"]) == 100


@pytest.mark.asyncio
async def test_root_endpoint():
    """Test root endpoint."""
    async with AsyncClient(app=app, base_url="http://test") as ac:
        response = await ac.get("/")

    assert response.status_code == 200
    data = response.json()
    assert data["service"] == "LuciVerse Embedder"
    assert "endpoints" in data
