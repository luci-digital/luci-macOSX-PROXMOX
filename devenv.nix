{ pkgs, lib, config, inputs, ... }:

{
  # https://devenv.sh/basics/
  env.GREET = "🚀 Welcome to LuciVerse Development Environment";
  env.KUBECONFIG = "./kubeconfig";
  env.ANSIBLE_INVENTORY = "./ansible/inventory/hosts.yml";
  env.TF_VAR_proxmox_host = "192.168.100.10";
  env.PROXMOX_VE_ENDPOINT = "https://192.168.100.10:8006/api2/json";

  # https://devenv.sh/packages/
  packages = with pkgs; [
    # Infrastructure as Code
    terraform
    ansible
    ansible-lint

    # Kubernetes tools
    kubectl
    k9s
    helm
    kustomize

    # Nix tools
    nixos-rebuild
    nixpkgs-fmt
    nil # Nix LSP

    # Python for AI agents and automation
    python311
    python311Packages.pip
    python311Packages.virtualenv

    # Container tools
    docker-compose
    podman

    # Proxmox tools
    qemu
    cloud-init

    # Utilities
    git
    jq
    yq-go
    tmux
    htop
    curl
    wget
    openssh
    gnumake

    # Network tools
    mtr
    tcpdump
    nmap
    dig
  ];

  # https://devenv.sh/scripts/
  scripts.hello.exec = ''
    echo "$GREET"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
  '';

  scripts.orion-status.exec = ''
    echo "📊 ORION Infrastructure Status"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    if command -v terraform &> /dev/null; then
      echo "🏗️  Terraform Status:"
      cd terraform && terraform show -no-color | head -20 && cd ..
      echo ""
    fi

    if command -v kubectl &> /dev/null && [ -f "$KUBECONFIG" ]; then
      echo "☸️  Kubernetes Status:"
      kubectl get nodes
      kubectl get pods --all-namespaces
      echo ""
    fi

    if command -v ansible &> /dev/null; then
      echo "🎭 Ansible Inventory:"
      ansible-inventory --list | jq -r '.all.hosts | keys[]'
      echo ""
    fi
  '';

  scripts.deploy-ai-stack.exec = ''
    echo "🤖 Deploying AI/ML Stack"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # Build Ollama LXC container
    echo "Building Ollama LXC container..."
    nix build .#ollama-lxc -o result-ollama

    # Build AutoPVE container
    echo "Building AutoPVE container..."
    nix build .#autopve-lxc -o result-autopve

    echo ""
    echo "✅ AI stack built successfully!"
    echo "Templates available in:"
    ls -lh result-*/tarball/*.tar.xz
  '';

  scripts.build-vms.exec = ''
    echo "🏗️  Building all NixOS VM configurations"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    for host in orion-router orion-ai-agent orion-netbox orion-k3s-master orion-k3s-worker; do
      echo "Building $host..."
      nix build .#nixosConfigurations.$host.config.system.build.toplevel -o result-$host
    done

    echo "✅ All VM configurations built!"
  '';

  scripts.ssh-router.exec = ''
    ssh admin@192.168.100.1
  '';

  scripts.ssh-ai-agent.exec = ''
    ssh admin@192.168.100.20
  '';

  scripts.orion-help.exec = ''
    echo "🚀 LuciVerse/ORION Helper Commands"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "📊 Status & Monitoring:"
    echo "  orion-status        - Show infrastructure status"
    echo "  ssh-router          - SSH to router VM"
    echo "  ssh-ai-agent        - SSH to AI agent VM"
    echo ""
    echo "🏗️  Building & Deployment:"
    echo "  build-vms           - Build all NixOS VM configurations"
    echo "  deploy-ai-stack     - Build and deploy AI/ML LXC containers"
    echo ""
    echo "🔧 Development:"
    echo "  nix flake update    - Update all flake inputs"
    echo "  nixpkgs-fmt .       - Format all Nix files"
    echo ""
    echo "📚 Documentation:"
    echo "  cat docs/ARCHITECTURE.md"
    echo "  cat docs/QUICKSTART.md"
    echo ""
  '';

  enterShell = ''
    hello
    orion-help
  '';

  # https://devenv.sh/languages/
  languages.python = {
    enable = true;
    version = "3.11";
    venv.enable = true;
    venv.requirements = ''
      # AI/ML Libraries
      openai>=1.0.0
      anthropic>=0.8.0
      langchain>=0.1.0
      llama-index>=0.9.0

      # Prometheus client
      prometheus-client>=0.19.0

      # HTTP clients
      requests>=2.31.0
      aiohttp>=3.9.0
      httpx>=0.25.0

      # Infrastructure automation
      ansible>=2.16.0
      python-terraform>=0.10.1

      # Utilities
      pyyaml>=6.0
      python-dotenv>=1.0.0
      rich>=13.7.0
      typer>=0.9.0

      # Proxmox API
      proxmoxer>=2.0.0

      # NetBox API
      pynetbox>=7.0.0
    '';
  };

  languages.nix.enable = true;

  # https://devenv.sh/processes/
  processes = {
    # AI Agent development server
    ai-agent-dev.exec = ''
      echo "🤖 Starting AI Agent in development mode"
      cd agents/orion-agent
      python autonomous_agent.py
    '';

    # Prometheus for local testing
    prometheus-dev.exec = ''
      echo "📊 Starting Prometheus for development"
      prometheus --config.file=./configs/prometheus/prometheus-dev.yml
    '';
  };

  # https://devenv.sh/services/
  # Uncomment to enable services during development

  # services.postgres = {
  #   enable = true;
  #   initialDatabases = [{ name = "luciverse"; }];
  # };

  # services.redis = {
  #   enable = true;
  # };

  # https://devenv.sh/pre-commit-hooks/
  pre-commit.hooks = {
    # Nix formatting
    nixpkgs-fmt.enable = true;

    # Ansible linting
    ansible-lint = {
      enable = true;
      entry = "${pkgs.ansible-lint}/bin/ansible-lint";
      files = "\\.(yml|yaml)$";
      excludes = [ "kubernetes/" ];
    };

    # Python formatting
    black = {
      enable = true;
      entry = "${pkgs.python311Packages.black}/bin/black";
      files = "\\.py$";
    };

    # Python linting
    ruff = {
      enable = true;
      entry = "${pkgs.ruff}/bin/ruff check";
      files = "\\.py$";
    };

    # Terraform formatting
    terraform-format = {
      enable = true;
      entry = "${pkgs.terraform}/bin/terraform fmt -recursive";
      files = "\\.tf$";
      pass_filenames = false;
    };

    # YAML linting
    yamllint = {
      enable = true;
      entry = "${pkgs.yamllint}/bin/yamllint";
      files = "\\.(yml|yaml)$";
    };

    # Secrets detection
    gitleaks = {
      enable = true;
      entry = "${pkgs.gitleaks}/bin/gitleaks protect --staged";
      pass_filenames = false;
    };
  };

  # https://devenv.sh/integrations/dotenv/
  dotenv.enable = true;
  dotenv.filename = ".env.local";

  # Environment-specific tasks
  tasks = {
    "dev:setup" = {
      exec = ''
        echo "Setting up development environment..."

        # Create necessary directories
        mkdir -p terraform/environments/{dev,staging,prod}
        mkdir -p ansible/roles ansible/playbooks
        mkdir -p kubernetes/manifests
        mkdir -p configs/{prometheus,grafana,gobgp}
        mkdir -p agents/orion-agent
        mkdir -p lxc-configs
        mkdir -p modules

        # Initialize Python venv
        python -m venv .venv
        source .venv/bin/activate
        pip install -r <(echo "$PIP_REQUIREMENTS")

        # Initialize Terraform
        cd terraform && terraform init && cd ..

        # Create example configs if they don't exist
        if [ ! -f terraform/terraform.tfvars ]; then
          cp terraform/terraform.tfvars.example terraform/terraform.tfvars 2>/dev/null || true
        fi

        echo "✅ Development environment ready!"
      '';
    };

    "dev:clean" = {
      exec = ''
        echo "Cleaning build artifacts..."
        rm -rf result-* .venv .devenv .direnv
        echo "✅ Cleaned!"
      '';
    };
  };
}
