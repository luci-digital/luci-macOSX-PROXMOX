# LuciVerse NLP Stack - Declarative Architecture

**Implementing the "Golden Shape" for AI-First Infrastructure**

---

## 🎯 Architecture Overview

### One Flake to Rule Them All

```
flake.nix (already exists)
├── devShells:      nlp-dev, gpu-dev, ops-dev
├── packages:       ingest, embedder, retriever, reranker, api
├── nixosModules:   ollama, vector-db, prometheus
├── images:         OCI images for K8s deployment
└── checks:         tests, linting, model validation
```

---

## 🧩 Split NLP into "Boring Services"

Instead of monolithic AI apps, we decompose into:

### 1. **Ingest Service**
**Purpose**: Normalize diverse data sources into canonical objects

```python
# packages/ingest/src/main.py
"""
Pulls from:
- Prometheus metrics
- System logs
- Network events
- BGP routing changes

Outputs: Canonical JSON/CBOR events
"""
```

**Nix Package**:
```nix
# packages/ingest/default.nix
{ pkgs, python3Packages }:

python3Packages.buildPythonApplication {
  pname = "luciverse-ingest";
  version = "0.1.0";

  src = ./.;

  propagatedBuildInputs = with python3Packages; [
    aiohttp
    prometheus-client
    pyyaml
    msgpack  # for CBOR
  ];

  checkInputs = with python3Packages; [
    pytest
    pytest-asyncio
  ];
}
```

### 2. **Embedder Service**
**Purpose**: Turn objects into vectors (CPU or GPU)

```python
# packages/embedder/src/main.py
"""
Uses:
- sentence-transformers (CPU/GPU)
- or Ollama embeddings API

Outputs: Vector embeddings
"""
```

**Nix Package**:
```nix
# packages/embedder/default.nix
{ pkgs, python3Packages, cudaSupport ? true }:

python3Packages.buildPythonApplication {
  pname = "luciverse-embedder";
  version = "0.1.0";

  src = ./.;

  propagatedBuildInputs = with python3Packages; [
    sentence-transformers
    torch
    numpy
  ] ++ pkgs.lib.optionals cudaSupport [
    torch-bin  # GPU version
  ];
}
```

### 3. **Retriever Service**
**Purpose**: Vector DB query + filtering

```python
# packages/retriever/src/main.py
"""
Queries:
- pgvector (PostgreSQL extension)
- or Qdrant
- or Weaviate

With filtering by metadata
"""
```

### 4. **Reranker Service**
**Purpose**: Optional LLM rerank for precision

```python
# packages/reranker/src/main.py
"""
Uses Ollama API to rerank results
Models: mistral, llama3.2
"""
```

### 5. **API Gateway**
**Purpose**: Thin orchestration layer

```python
# packages/api/src/main.py
"""
FastAPI gateway that:
1. Receives query
2. Calls embedder
3. Calls retriever
4. Calls reranker (optional)
5. Returns results
"""
```

---

## 📦 Deterministic Dependency Pinning

### Python Stack with uv2nix

```nix
# Use uv for fast, deterministic Python builds
{ pkgs, ... }:

let
  # Pin Python dependencies with uv
  python-env = pkgs.buildEnv {
    name = "luciverse-python";
    paths = with pkgs.python311Packages; [
      fastapi
      uvicorn
      sentence-transformers
      torch
      psycopg2
      redis
      prometheus-client
    ];
  };
in
{
  # Development shell with pinned dependencies
  devShell = pkgs.mkShell {
    buildInputs = [ python-env pkgs.uv ];
  };
}
```

### Rust for Performance-Critical Parts

```nix
# packages/tokenizer-rs/default.nix
{ pkgs, rustPlatform }:

rustPlatform.buildRustPackage {
  pname = "luciverse-tokenizer";
  version = "0.1.0";

  src = ./.;

  cargoLock = {
    lockFile = ./Cargo.lock;
  };

  # Fast tokenization for preprocessing
  buildInputs = with pkgs; [ openssl ];
}
```

---

## 🤖 Models as Artifacts (Not Dependencies)

### Model Manifest Pattern

```nix
# packages/models/manifest.nix
{
  models = {
    embedder = {
      name = "all-MiniLM-L6-v2";
      hash = "sha256-abc123...";
      url = "https://artifacts.luciverse.ai/models/all-MiniLM-L6-v2.tar.gz";
      size = "90MB";
    };

    llm = {
      name = "llama3.2";
      hash = "sha256-def456...";
      url = "https://artifacts.luciverse.ai/models/llama3.2.gguf";
      size = "4.7GB";
    };

    reranker = {
      name = "bge-reranker-base";
      hash = "sha256-ghi789...";
      url = "https://artifacts.luciverse.ai/models/bge-reranker.tar.gz";
      size = "278MB";
    };
  };
}
```

### Model Fetcher

```nix
# packages/models/fetch.nix
{ pkgs, manifest }:

pkgs.runCommand "fetch-models" {
  buildInputs = [ pkgs.curl pkgs.zstd ];

  outputHashAlgo = "sha256";
  outputHash = manifest.hash;

} ''
  curl -L ${manifest.url} -o model.tar.gz
  echo "${manifest.hash}  model.tar.gz" | sha256sum -c

  mkdir -p $out
  tar xzf model.tar.gz -C $out
''
```

### Ollama Model Pulling

```nix
# Instead of storing models in Nix store, pull via Ollama
systemd.services.ollama-pull-models = {
  description = "Pull Ollama models from registry";
  after = [ "ollama.service" ];

  script = ''
    # Pull models defined in manifest
    ${pkgs.ollama}/bin/ollama pull llama3.2
    ${pkgs.ollama}/bin/ollama pull mistral
    ${pkgs.ollama}/bin/ollama pull all-minilm
  '';

  serviceConfig = {
    Type = "oneshot";
    User = "ollama";
  };
}
```

---

## 🚀 Declarative Deployment

### OCI Images from Nix

```nix
# Build OCI images for each service
packages.x86_64-linux = {
  # Embedder OCI image
  embedder-image = pkgs.dockerTools.buildImage {
    name = "luciverse/embedder";
    tag = "latest";

    config = {
      Cmd = [ "${self.packages.x86_64-linux.embedder}/bin/embedder" ];
      ExposedPorts = { "8001/tcp" = {}; };
      Env = [
        "MODEL_PATH=/models/all-MiniLM-L6-v2"
        "DEVICE=cuda:0"
      ];
    };

    contents = [
      self.packages.x86_64-linux.embedder
      pkgs.cacert  # for HTTPS
    ];
  };

  # API Gateway OCI image
  api-image = pkgs.dockerTools.buildImage {
    name = "luciverse/api";
    tag = "latest";

    config = {
      Cmd = [ "${self.packages.x86_64-linux.api}/bin/api" ];
      ExposedPorts = { "8000/tcp" = {}; };
    };

    contents = [ self.packages.x86_64-linux.api ];
  };
};
```

### K8s Manifests from Nix

```nix
# k8s/manifests.nix
{ pkgs, ... }:

let
  renderManifest = name: config: pkgs.writeText "${name}.yaml" (
    pkgs.lib.generators.toYAML {} config
  );
in
{
  embedder-deployment = renderManifest "embedder" {
    apiVersion = "apps/v1";
    kind = "Deployment";
    metadata.name = "embedder";
    spec = {
      replicas = 3;
      template.spec.containers = [{
        name = "embedder";
        image = "luciverse/embedder:latest";
        resources = {
          limits = {
            "nvidia.com/gpu" = 1;
            memory = "4Gi";
          };
        };
      }];
    };
  };
}
```

---

## 🏗️ Complete Flake Extension

```nix
# flake.nix (extension to existing)
{
  outputs = { self, nixpkgs, ... }@inputs: {

    # NLP Microservices Packages
    packages.x86_64-linux = {
      # Services
      ingest = import ./packages/ingest { inherit pkgs; };
      embedder = import ./packages/embedder { inherit pkgs; cudaSupport = true; };
      retriever = import ./packages/retriever { inherit pkgs; };
      reranker = import ./packages/reranker { inherit pkgs; };
      api = import ./packages/api { inherit pkgs; };

      # Rust performance tools
      tokenizer-rs = import ./packages/tokenizer-rs { inherit pkgs; };

      # OCI Images
      ingest-image = import ./images/ingest.nix { inherit pkgs self; };
      embedder-image = import ./images/embedder.nix { inherit pkgs self; };
      retriever-image = import ./images/retriever.nix { inherit pkgs self; };
      reranker-image = import ./images/reranker.nix { inherit pkgs self; };
      api-image = import ./images/api.nix { inherit pkgs self; };

      # K8s manifests
      k8s-manifests = import ./k8s/manifests.nix { inherit pkgs; };
    };

    # Specialized Development Shells
    devShells.x86_64-linux = {
      # NLP development with GPU support
      nlp-dev = pkgs.mkShell {
        buildInputs = with pkgs; [
          python311
          python311Packages.torch
          python311Packages.sentence-transformers
          python311Packages.fastapi
          cudaPackages.cudatoolkit
          poetry
          uv
        ];

        shellHook = ''
          echo "🧠 NLP Development Environment (GPU enabled)"
          nvidia-smi || echo "No GPU detected"
        '';
      };

      # GPU-specific development
      gpu-dev = pkgs.mkShell {
        buildInputs = with pkgs; [
          cudaPackages.cudatoolkit
          cudaPackages.cudnn
          python311Packages.torch-bin
        ];

        shellHook = ''
          echo "🎮 GPU Development Environment"
          export CUDA_VISIBLE_DEVICES=0
        '';
      };

      # Operations/deployment shell
      ops-dev = pkgs.mkShell {
        buildInputs = with pkgs; [
          kubectl
          helm
          k9s
          skopeo  # for OCI image operations
          dive    # for image inspection
        ];

        shellHook = ''
          echo "🚀 Operations Development Environment"
        '';
      };
    };

    # NixOS Modules for each service
    nixosModules = {
      nlp-ingest = import ./modules/nlp-ingest.nix;
      nlp-embedder = import ./modules/nlp-embedder.nix;
      nlp-retriever = import ./modules/nlp-retriever.nix;
      nlp-api = import ./modules/nlp-api.nix;

      # Vector database
      pgvector = import ./modules/pgvector.nix;
    };

    # Checks for CI/CD
    checks.x86_64-linux = {
      # Unit tests
      test-ingest = self.packages.x86_64-linux.ingest.overrideAttrs (old: {
        checkPhase = "pytest tests/";
      });

      # Lint
      lint-python = pkgs.runCommand "lint" {
        buildInputs = [ pkgs.ruff pkgs.black ];
      } ''
        ruff check packages/
        black --check packages/
        touch $out
      '';

      # Model format validation
      validate-models = pkgs.runCommand "validate-models" {
        buildInputs = [ pkgs.python311Packages.torch ];
      } ''
        # Check model manifests
        python3 ${./scripts/validate-models.py}
        touch $out
      '';

      # SBOM generation (optional)
      sbom = pkgs.runCommand "sbom" {
        buildInputs = [ pkgs.syft ];
      } ''
        syft packages -o cyclonedx-json > $out/sbom.json
      '';
    };
  };
}
```

---

## 📁 Directory Structure

```
luciverse/
├── flake.nix                    # Main flake (extended)
├── packages/
│   ├── ingest/
│   │   ├── default.nix
│   │   ├── pyproject.toml
│   │   └── src/main.py
│   ├── embedder/
│   │   ├── default.nix
│   │   └── src/main.py
│   ├── retriever/
│   ├── reranker/
│   ├── api/
│   └── tokenizer-rs/
│       ├── default.nix
│       ├── Cargo.toml
│       └── src/lib.rs
├── modules/
│   ├── nlp-ingest.nix
│   ├── nlp-embedder.nix
│   ├── pgvector.nix
│   └── (existing modules)
├── images/
│   ├── ingest.nix
│   ├── embedder.nix
│   └── api.nix
├── k8s/
│   ├── manifests.nix
│   └── helm/
│       └── luciverse-nlp/
├── models/
│   ├── manifest.nix
│   └── fetch.nix
└── scripts/
    └── validate-models.py
```

---

## 🎯 Usage Examples

### Development

```bash
# Enter NLP development shell
nix develop .#nlp-dev

# Enter GPU development shell
nix develop .#gpu-dev

# Enter operations shell
nix develop .#ops-dev
```

### Building Services

```bash
# Build all microservices
nix build .#ingest .#embedder .#retriever .#reranker .#api

# Build OCI images
nix build .#embedder-image
nix build .#api-image

# Load into Docker
docker load < result
```

### Running Checks

```bash
# Run all checks
nix flake check

# Run specific checks
nix build .#checks.x86_64-linux.test-ingest
nix build .#checks.x86_64-linux.lint-python
```

### Deployment to K8s

```bash
# Build K8s manifests
nix build .#k8s-manifests

# Apply to cluster
kubectl apply -f result/

# Or use Helm
helm install luciverse-nlp ./k8s/helm/luciverse-nlp/
```

---

## 🔄 Integration with Existing LuciVerse

### How This Fits

```
Existing Infrastructure (VMA + LXC)
├── VM 200: Router (BGP, Firewall)
├── VM 300: AI Agent Coordinator
│   └── Ollama (LLM inference)
├── LXC 1000: Ollama
├── LXC 1004: PostgreSQL + pgvector ← Retriever uses this
└── K3s Cluster (VMs 600-603)
    └── Deploy NLP microservices here
        ├── Ingest (DaemonSet on all nodes)
        ├── Embedder (GPU node)
        ├── Retriever (connects to LXC 1004)
        ├── Reranker (uses Ollama API)
        └── API Gateway (LoadBalancer)
```

### Data Flow

```
Network Events → Ingest → Embedder → pgvector
                                        ↓
                            User Query → API → Retriever → Reranker → Response
                                                              ↓
                                                           Ollama
```

---

## 🚀 Next Steps

1. **Implement Base Services**:
   ```bash
   mkdir -p packages/{ingest,embedder,retriever,reranker,api}
   ```

2. **Add Python Packages**:
   ```bash
   # Each service gets pyproject.toml + default.nix
   cd packages/embedder && poetry init
   ```

3. **Build OCI Images**:
   ```bash
   nix build .#embedder-image
   ```

4. **Deploy to K3s**:
   ```bash
   kubectl apply -f k8s/manifests/
   ```

5. **Model Management**:
   - Set up artifact storage (MinIO in LXC 1006)
   - Create model manifests
   - Implement fetch/validation

---

## 📊 Benefits of This Architecture

| Aspect | Benefit |
|--------|---------|
| **Reproducibility** | Exact same build every time, pinned deps |
| **Modularity** | Each service independently deployable |
| **Testability** | `nix flake check` runs all tests |
| **Performance** | Rust for hot paths, GPU for embeddings |
| **Observability** | Prometheus metrics in every service |
| **Scalability** | K8s HPA for each microservice |
| **Model Versioning** | Content-addressed, hash-verified |

---

This architecture gives you the **"golden shape"** for declarative AI infrastructure, integrated seamlessly with your existing LuciVerse setup!
