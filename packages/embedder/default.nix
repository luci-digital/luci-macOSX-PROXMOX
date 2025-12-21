{ lib
, python3Packages
, cudaSupport ? false
, fetchFromGitHub
}:

python3Packages.buildPythonApplication {
  pname = "luciverse-embedder";
  version = "0.1.0";

  src = ./.;

  format = "pyproject";

  nativeBuildInputs = with python3Packages; [
    poetry-core
  ];

  propagatedBuildInputs = with python3Packages; [
    # Web framework
    fastapi
    uvicorn

    # Embeddings
    sentence-transformers
    numpy

    # Torch (GPU or CPU)
    (if cudaSupport then torch-bin else torch)

    # Observability
    prometheus-client

    # Utilities
    pydantic
    pyyaml
    aiohttp
  ];

  checkInputs = with python3Packages; [
    pytest
    pytest-asyncio
    pytest-cov
    httpx  # for testing FastAPI
  ];

  # Skip tests that require GPU
  checkPhase = ''
    export HOME=$(mktemp -d)
    pytest tests/ -v ${lib.optionalString (!cudaSupport) "-m 'not gpu'"}
  '';

  pythonImportsCheck = [ "embedder" ];

  meta = with lib; {
    description = "LuciVerse Embedder Service - Vector embeddings for NLP";
    homepage = "https://github.com/luci-digital/luci-macOSX-PROXMOX";
    license = licenses.mit;
    maintainers = [ ];
  };
}
