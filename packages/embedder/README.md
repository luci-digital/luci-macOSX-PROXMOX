# LuciVerse Embedder Service

Vector embedding service using sentence-transformers.

## Features

- **FastAPI REST API** for embedding generation
- **GPU support** via CUDA (optional)
- **Prometheus metrics** for observability
- **Batch processing** for efficiency
- **Content-addressed models** from artifact storage

## Building with Nix

```bash
# CPU version
nix build .#embedder

# GPU version
nix build .#embedder --arg cudaSupport true

# OCI image
nix build .#embedder-image
```

## Running

```bash
# Direct execution
./result/bin/embedder

# With Docker
docker load < result
docker run -p 8001:8001 luciverse/embedder:latest

# With environment variables
MODEL_NAME=all-MiniLM-L6-v2 \
DEVICE=cuda:0 \
BATCH_SIZE=64 \
./result/bin/embedder
```

## API Usage

```bash
# Health check
curl http://localhost:8001/health

# Generate embeddings
curl -X POST http://localhost:8001/embed \
  -H "Content-Type: application/json" \
  -d '{
    "texts": ["Hello world", "Nix is declarative"],
    "normalize": true
  }'

# Prometheus metrics
curl http://localhost:8001/metrics
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `MODEL_NAME` | `all-MiniLM-L6-v2` | HuggingFace model name |
| `MODEL_PATH` | None | Local model path (optional) |
| `DEVICE` | `cuda` or `cpu` | Compute device |
| `BATCH_SIZE` | `32` | Batch size for processing |
| `PORT` | `8001` | HTTP server port |

## Testing

```bash
# Run tests
nix build .#embedder.tests

# With coverage
pytest tests/ --cov=embedder --cov-report=html

# Skip GPU tests
pytest tests/ -m "not gpu"
```

## Deployment

### Kubernetes

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: embedder
spec:
  replicas: 3
  template:
    spec:
      containers:
      - name: embedder
        image: luciverse/embedder:latest
        ports:
        - containerPort: 8001
        resources:
          limits:
            nvidia.com/gpu: 1
            memory: 4Gi
        env:
        - name: MODEL_NAME
          value: "all-MiniLM-L6-v2"
        - name: DEVICE
          value: "cuda:0"
```

### NixOS Module

```nix
{
  services.luciverse-embedder = {
    enable = true;
    modelName = "all-MiniLM-L6-v2";
    device = "cuda:0";
    port = 8001;
  };
}
```

## Models as Artifacts

Models are fetched from content-addressed storage:

```nix
# models/manifest.nix
{
  all-MiniLM-L6-v2 = {
    hash = "sha256-abc123...";
    url = "https://artifacts.luciverse.ai/models/all-MiniLM-L6-v2.tar.gz";
  };
}
```

## Architecture

```
┌──────────────┐
│  HTTP Request│
└──────┬───────┘
       │
       ▼
┌──────────────────┐
│   FastAPI App    │
├──────────────────┤
│ /embed endpoint  │
└──────┬───────────┘
       │
       ▼
┌──────────────────┐
│ sentence-trans-  │
│    formers       │
├──────────────────┤
│  Model Inference │
│  (GPU/CPU)       │
└──────┬───────────┘
       │
       ▼
┌──────────────────┐
│ Vector Embeddings│
│  (normalized)    │
└──────────────────┘
```

## Performance

- **Throughput**: ~1000 texts/sec (GPU), ~100 texts/sec (CPU)
- **Latency**: ~10ms per batch (GPU), ~100ms per batch (CPU)
- **Memory**: ~2GB (model) + batch size overhead

## Observability

Prometheus metrics exposed at `/metrics`:

- `embedder_requests_total` - Total requests (labeled by status)
- `embedder_duration_seconds` - Request duration histogram

Integrate with Grafana for dashboards.
