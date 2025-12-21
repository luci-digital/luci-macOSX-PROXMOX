# LuciVerse Nix Declarative Infrastructure

**Version**: 2.0.0-nix
**Created**: 2025-01-22
**Status**: Ready for deployment

---

## 🎯 Overview

Complete declarative infrastructure management for LuciVerse using Nix flakes, inspired by best practices from the Nix community and adapted for AI-first infrastructure.

### Key Features

- **100% Declarative**: All infrastructure defined as code
- **Reproducible**: Bit-for-bit reproducible builds
- **Version Controlled**: Infrastructure changes tracked in Git
- **Type Safe**: Nix's type system prevents configuration errors
- **Modular**: Reusable modules for common patterns
- **Developer Friendly**: Rich development environment with `devenv`

---

## 🏗️ Architecture

```
LuciVerse Nix Infrastructure
├── flake.nix                      # Main flake - infrastructure entry point
├── devenv.nix                     # Development environment with tools
├── modules/                       # Reusable NixOS modules
│   ├── common.nix                # Common configuration
│   ├── security.nix              # Security hardening
│   ├── monitoring.nix            # Prometheus/Grafana
│   ├── ollama.nix                # Ollama LLM server
│   ├── gobgp.nix                 # GoBGP routing
│   ├── ai-agent.nix              # AI agent framework
│   ├── k3s-master.nix            # K3s control plane
│   └── k3s-worker.nix            # K3s worker nodes
├── vm-configs/                    # VM-specific configurations
│   ├── router-vm/                # Router VM (VM 200)
│   ├── ai-agent-vm/              # AI Agent VM (VM 300)
│   ├── netbox-vm/                # NetBox VM (VM 500)
│   ├── k3s-master/               # K3s master (VM 600)
│   └── k3s-worker/               # K3s workers (VM 601-603)
├── lxc-configs/                   # LXC container templates
│   ├── base-template.nix         # Base NixOS LXC template
│   ├── ollama-container.nix      # Ollama LXC
│   └── autopve-container.nix     # AutoPVE LXC
└── scripts/                       # Deployment automation
    └── deploy-autopve.sh         # AutoPVE deployment script
```

---

## 🚀 Quick Start

### Prerequisites

```bash
# Install Nix with flakes support
sh <(curl -L https://nixos.org/nix/install) --daemon

# Enable flakes
mkdir -p ~/.config/nix
cat > ~/.config/nix/nix.conf <<EOF
experimental-features = nix-command flakes
auto-optimise-store = true
EOF
```

### Initialize Development Environment

```bash
# Clone repository
git clone https://github.com/luci-digital/luci-macOSX-PROXMOX.git
cd luci-macOSX-PROXMOX

# Enter development shell (installs all tools automatically)
nix develop

# Or use direnv for automatic environment loading
echo "use flake" > .envrc
direnv allow
```

### Build Infrastructure

```bash
# Build all NixOS VM configurations
build-vms

# Build LXC templates
nix build .#nixos-lxc-template
nix build .#ollama-lxc
nix build .#autopve-lxc

# Deploy AI stack
deploy-ai-stack
```

---

## 📦 NixOS Modules

### Ollama Module

Provides declarative configuration for Ollama LLM server:

```nix
{ config, ... }:
{
  services.ollama-agent = {
    enable = true;
    listenAddress = "0.0.0.0:11434";
    models = [ "llama3.2" "mistral" "codellama" ];
    gpuSupport = true;
    maxConnections = 100;
  };
}
```

**Features**:
- Automatic model downloading
- GPU acceleration support
- Prometheus metrics export
- Security hardening
- Resource limits

### AI Agent Module

Framework for autonomous AI agents:

```nix
{ config, ... }:
{
  services.orion-ai-agent = {
    enable = true;
    ollama.endpoint = "http://localhost:11434";
    prometheus.endpoint = "http://localhost:9090";
    actions = {
      network-monitoring = true;
      auto-scaling = true;
      incident-response = true;
    };
  };
}
```

### GoBGP Module

Programmable BGP routing:

```nix
{ config, ... }:
{
  services.gobgp = {
    enable = true;
    as = 394955;
    routerId = "192.168.100.1";
    neighbors = [
      {
        address = "2602:F674:0000::ffff";
        peerAs = 6939;
        description = "Telus Gateway 1";
      }
    ];
    api.grpc.enable = true;
    api.rest.enable = true;
  };
}
```

---

## 🐳 LXC Container Templates

### Building Templates

```bash
# Build NixOS base template
nix build .#nixos-lxc-template -o result-nixos-lxc

# Build Ollama container
nix build .#ollama-lxc -o result-ollama

# Build AutoPVE container
nix build .#autopve-lxc -o result-autopve

# Templates are in result-*/tarball/*.tar.xz
```

### Deploying to Proxmox

```bash
# Upload template to Proxmox
TEMPLATE_FILE="result-ollama/tarball/nixos-system-x86_64-linux.tar.xz"
scp "$TEMPLATE_FILE" root@proxmox:/var/lib/vz/template/cache/nixos-ollama.tar.xz

# Create container
pct create 1000 local:vztmpl/nixos-ollama.tar.xz \
  --hostname ollama \
  --ostype unmanaged \
  --cores 8 \
  --memory 16384 \
  --rootfs local-lvm:100 \
  --unprivileged 1 \
  --features nesting=1 \
  --net0 name=eth0,bridge=vmbr1,ip=192.168.100.100/24,gw=192.168.100.1 \
  --start 1
```

---

## 🤖 AutoPVE Integration

AutoPVE provides automated Proxmox installation capabilities, deployed as a NixOS LXC container.

### Automated Deployment

```bash
# Deploy AutoPVE with single command
./scripts/deploy-autopve.sh

# Or build manually
nix build .#autopve-lxc
```

### Configuration

The AutoPVE container includes:
- Docker for running AutoPVE
- Automatic docker-compose setup
- Pre-configured networking
- Web UI at http://192.168.100.110:8080

### Usage

```bash
# Access AutoPVE web interface
open http://192.168.100.110:8080

# Answer endpoint for automated installs
curl http://192.168.100.110:8080/answer

# Playbook webhook
curl http://192.168.100.110:8080/playbook/post-install
```

---

## 🔧 Development Environment (devenv.nix)

### Features

- **Auto-loaded environment**: `direnv` integration
- **50+ helper commands**: Pre-configured scripts
- **Python venv**: Auto-managed with dependencies
- **Pre-commit hooks**: Code quality enforcement
- **Service processes**: Run services locally

### Available Commands

```bash
# Infrastructure status
orion-status              # Show complete infrastructure status

# SSH shortcuts
ssh-router                # SSH to router VM
ssh-ai-agent              # SSH to AI agent VM

# Building
build-vms                 # Build all NixOS configurations
deploy-ai-stack           # Deploy AI/ML containers

# Development
nix flake update          # Update all dependencies
nixpkgs-fmt .             # Format all Nix files

# Help
orion-help                # Show all available commands
```

### Python Environment

Automatically includes:
- OpenAI SDK
- Anthropic SDK
- LangChain
- Llama Index
- Prometheus client
- Ansible
- Infrastructure automation libraries

---

## 📋 Common Workflows

### Adding a New VM

1. **Create configuration:**

```bash
mkdir -p vm-configs/new-vm
cat > vm-configs/new-vm/configuration.nix <<EOF
{ config, pkgs, ... }:
{
  imports = [ ../common.nix ];

  networking.hostName = "new-vm";
  # ... rest of configuration
}
EOF
```

2. **Add to flake.nix:**

```nix
nixosConfigurations.new-vm = nixpkgs.lib.nixosSystem {
  system = "x86_64-linux";
  modules = [ ./vm-configs/new-vm/configuration.nix ];
};
```

3. **Build:**

```bash
nix build .#nixosConfigurations.new-vm.config.system.build.toplevel
```

### Creating a New Module

1. **Create module file:**

```bash
cat > modules/my-service.nix <<EOF
{ config, lib, pkgs, ... }:
with lib;
let
  cfg = config.services.my-service;
in {
  options.services.my-service = {
    enable = mkEnableOption "My Service";
    # ... options
  };

  config = mkIf cfg.enable {
    # ... implementation
  };
}
EOF
```

2. **Use in configuration:**

```nix
{ config, ... }:
{
  imports = [ ../modules/my-service.nix ];

  services.my-service.enable = true;
}
```

### Updating the System

```bash
# Update flake inputs
nix flake update

# Rebuild specific VM
nix build .#nixosConfigurations.orion-ai-agent.config.system.build.toplevel

# Deploy to Proxmox (manual)
nixos-rebuild switch --target-host admin@192.168.100.20 --flake .#orion-ai-agent
```

---

## 🔐 Security Best Practices

### Built-in Security Features

All modules include security hardening:

```nix
{
  # Systemd service hardening
  serviceConfig = {
    NoNewPrivileges = true;
    PrivateTmp = true;
    ProtectSystem = "strict";
    ProtectHome = true;
    DynamicUser = true;
  };

  # Firewall
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ /* minimal ports */ ];
  };

  # SSH hardening
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "prohibit-password";
      PasswordAuthentication = false;
    };
  };
}
```

---

## 📚 References & Inspirations

This implementation draws from:

- **jmatsushita's nix-darwin setup**: M1 Mac configuration patterns
- **nixos-generators**: LXC template generation
- **devenv**: Development environment management
- **NixOS modules**: Best practices from nixpkgs

### Key Patterns Used

1. **Flakes for dependency management**: Pin exact versions
2. **Overlays for customization**: Add custom packages
3. **Modules for reusability**: DRY principle
4. **Development shells**: Reproducible dev environments
5. **Security by default**: Hardened configurations

---

## 🎯 Next Steps

### Immediate

- [ ] Test AutoPVE deployment script
- [ ] Add more AI agent modules
- [ ] Create K3s cluster automation
- [ ] Add Terraform integration

### Future

- [ ] CI/CD with GitHub Actions
- [ ] Automated testing with NixOS tests
- [ ] Binary cache setup (Cachix)
- [ ] Documentation website
- [ ] Home-manager for user configs

---

## 🤝 Contributing

1. Fork repository
2. Create feature branch
3. Make changes
4. Run `nixpkgs-fmt .` to format
5. Test with `nix flake check`
6. Submit PR

---

## 📄 License

MIT License - see LICENSE file

---

**Questions?** Open an issue or check the docs/

**Need Help?** Run `orion-help` in development environment
