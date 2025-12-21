{
  description = "LuciVerse - Declarative AI-First Infrastructure Stack for Proxmox";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    flake-utils.url = "github:numtide/flake-utils";

    # NixOS generators for LXC/Proxmox templates
    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Home manager for user environments
    home-manager = {
      url = "github:nix-community/home-manager/release-24.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Development environments
    devenv = {
      url = "github:cachix/devenv";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, flake-utils, nixos-generators, home-manager, devenv, ... }@inputs:
    let
      inherit (nixpkgs.lib) attrValues makeOverridable optionalAttrs;

      # Shared nixpkgs configuration
      nixpkgsConfig = {
        config = {
          allowUnfree = true;
          allowBroken = false;
        };
        overlays = attrValues self.overlays;
      };

      # Common modules shared across all VMs
      commonModules = [
        ./modules/common.nix
        ./modules/security.nix
        ./modules/monitoring.nix
      ];

    in
    {
      # NixOS Configurations for Proxmox VMs
      nixosConfigurations = {
        # VM 200: ORION Router with GoBGP
        orion-router = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = commonModules ++ [
            ./vm-configs/router-vm/configuration.nix
            ./modules/gobgp.nix
            ./modules/routing.nix
          ];
          specialArgs = { inherit inputs; };
        };

        # VM 300: AI Agent Coordinator with Ollama
        orion-ai-agent = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = commonModules ++ [
            ./vm-configs/ai-agent-vm/configuration.nix
            ./modules/ai-agent.nix
            ./modules/ollama.nix
            ./modules/prometheus.nix
          ];
          specialArgs = { inherit inputs; };
        };

        # VM 500: NetBox IPAM
        orion-netbox = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = commonModules ++ [
            ./vm-configs/netbox-vm/configuration.nix
            ./modules/netbox.nix
          ];
          specialArgs = { inherit inputs; };
        };

        # VM 600-603: K3s Kubernetes Cluster
        orion-k3s-master = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = commonModules ++ [
            ./vm-configs/k3s-master/configuration.nix
            ./modules/k3s-master.nix
          ];
          specialArgs = { inherit inputs; };
        };

        orion-k3s-worker = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = commonModules ++ [
            ./vm-configs/k3s-worker/configuration.nix
            ./modules/k3s-worker.nix
          ];
          specialArgs = { inherit inputs; };
        };
      };

      # Proxmox LXC Container Templates
      packages.x86_64-linux = {
        # NixOS LXC template for Proxmox
        nixos-lxc-template = nixos-generators.nixosGenerate {
          system = "x86_64-linux";
          format = "proxmox-lxc";
          modules = [
            ./lxc-configs/base-template.nix
          ];
        };

        # Ollama LXC container
        ollama-lxc = nixos-generators.nixosGenerate {
          system = "x86_64-linux";
          format = "proxmox-lxc";
          modules = [
            ./lxc-configs/ollama-container.nix
            ./modules/ollama.nix
          ];
        };

        # AutoPVE deployment container
        autopve-lxc = nixos-generators.nixosGenerate {
          system = "x86_64-linux";
          format = "proxmox-lxc";
          modules = [
            ./lxc-configs/autopve-container.nix
          ];
        };

        # Proxmox VMA Images (Full VMs using official proxmox-image.nix module)
        # These create .vma.zst files that can be restored directly in Proxmox

        # Router VM VMA image
        proxmox-router-vma = (nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            ./vm-configs/router-vm/proxmox-image.nix
            ./modules/gobgp.nix
          ];
          specialArgs = { inherit inputs; };
        }).config.system.build.VMA;

        # AI Agent VM VMA image
        proxmox-ai-agent-vma = (nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            ./vm-configs/ai-agent-vm/proxmox-image.nix
            ./modules/ollama.nix
          ];
          specialArgs = { inherit inputs; };
        }).config.system.build.VMA;
      };

      # Overlays for custom packages
      overlays = {
        # Unstable packages overlay
        unstable = final: prev: {
          unstable = import nixpkgs-unstable {
            system = final.system;
            config.allowUnfree = true;
          };
        };

        # AI/ML packages
        ai-ml = final: prev: {
          ollama = prev.unstable.ollama or prev.ollama;
          litellm = prev.unstable.litellm or prev.litellm;
        };

        # Custom LuciVerse tools
        luciverse = final: prev: {
          # GoBGP with custom configuration
          gobgp-orion = prev.gobgp.overrideAttrs (old: {
            postInstall = ''
              ${old.postInstall or ""}
              mkdir -p $out/etc/gobgp
              cp ${./configs/gobgp/gobgpd.toml} $out/etc/gobgp/gobgpd.toml
            '';
          });

          # Custom AI agent scripts
          orion-agent = prev.python3Packages.buildPythonPackage {
            pname = "orion-agent";
            version = "2.0.0";
            src = ./agents/orion-agent;
            propagatedBuildInputs = with prev.python3Packages; [
              requests
              prometheus-client
              pyyaml
              aiohttp
              openai
            ];
          };
        };
      };

      # Reusable NixOS modules
      nixosModules = {
        # Common configuration for all VMs
        common = import ./modules/common.nix;

        # Security hardening
        security = import ./modules/security.nix;

        # Monitoring with Prometheus
        monitoring = import ./modules/monitoring.nix;

        # AI Agent module
        ai-agent = import ./modules/ai-agent.nix;

        # Ollama LLM server
        ollama = import ./modules/ollama.nix;

        # GoBGP routing
        gobgp = import ./modules/gobgp.nix;

        # NetBox IPAM
        netbox = import ./modules/netbox.nix;

        # K3s Kubernetes
        k3s-master = import ./modules/k3s-master.nix;
        k3s-worker = import ./modules/k3s-worker.nix;
      };

      # Development shells
      devShells = flake-utils.lib.eachDefaultSystem (system:
        let
          pkgs = import nixpkgs {
            inherit system;
            config = nixpkgsConfig.config;
            overlays = nixpkgsConfig.overlays;
          };
        in
        {
          # Default development environment
          default = pkgs.mkShell {
            name = "luciverse-dev";

            buildInputs = with pkgs; [
              # Infrastructure tools
              terraform
              ansible
              kubectl
              k9s

              # Nix tools
              nixos-rebuild
              nixpkgs-fmt
              nil # Nix language server

              # Python for AI agents
              (python3.withPackages (ps: with ps; [
                requests
                prometheus-client
                pyyaml
                aiohttp
                openai
                anthropic
              ]))

              # Utilities
              jq
              yq
              git
              tmux
              htop

              # Custom packages
              gobgp-orion
              orion-agent
            ];

            shellHook = ''
              echo "🚀 LuciVerse Development Environment"
              echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
              echo "Terraform: $(terraform version | head -1)"
              echo "Ansible: $(ansible --version | head -1)"
              echo "kubectl: $(kubectl version --client --short 2>/dev/null)"
              echo ""
              echo "Available commands:"
              echo "  make deploy-full    - Deploy complete stack"
              echo "  make deploy-ai      - Deploy AI/ML containers"
              echo "  terraform apply     - Provision infrastructure"
              echo "  ansible-playbook    - Configure systems"
              echo "  kubectl get pods    - Check K8s pods"
              echo ""
              echo "Documentation: docs/"
              echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

              # Set up environment variables
              export KUBECONFIG="$PWD/kubeconfig"
              export ANSIBLE_INVENTORY="$PWD/ansible/inventory/hosts.yml"
              export TF_VAR_proxmox_host="192.168.100.10"
            '';
          };

          # Specialized shell for AI development
          ai-dev = pkgs.mkShell {
            name = "luciverse-ai-dev";

            buildInputs = with pkgs; [
              ollama
              litellm
              python3Packages.langchain
              python3Packages.openai
              python3Packages.anthropic
              orion-agent
            ];

            shellHook = ''
              echo "🤖 LuciVerse AI Development Environment"
              echo "Ollama: $(ollama --version 2>/dev/null || echo 'not installed')"
            '';
          };
        }
      ).devShells;

      # Deployment automation scripts
      apps = flake-utils.lib.eachDefaultSystem (system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        {
          # Deploy complete infrastructure
          deploy-all = {
            type = "app";
            program = "${pkgs.writeShellScript "deploy-all" ''
              set -e
              echo "🚀 Deploying LuciVerse Infrastructure"

              # Build NixOS configurations
              echo "Building NixOS configurations..."
              nix build .#nixosConfigurations.orion-router.config.system.build.toplevel
              nix build .#nixosConfigurations.orion-ai-agent.config.system.build.toplevel

              # Build LXC templates
              echo "Building LXC templates..."
              nix build .#nixos-lxc-template
              nix build .#ollama-lxc

              # Deploy with Terraform
              echo "Deploying with Terraform..."
              cd terraform && terraform apply -auto-approve && cd ..

              # Configure with Ansible
              echo "Configuring with Ansible..."
              cd ansible && ansible-playbook -i inventory/hosts.yml playbooks/site.yml && cd ..

              echo "✅ Deployment complete!"
            ''}";
          };

          # Build all LXC templates
          build-lxc-templates = {
            type = "app";
            program = "${pkgs.writeShellScript "build-lxc-templates" ''
              set -e
              echo "🔨 Building LXC templates for Proxmox"

              nix build .#nixos-lxc-template -o result-nixos-lxc
              nix build .#ollama-lxc -o result-ollama-lxc
              nix build .#autopve-lxc -o result-autopve-lxc

              echo "✅ Templates built:"
              ls -lh result-*/tarball/*.tar.xz
            ''}";
          };

          # Build all Proxmox VMA images
          build-vma-images = {
            type = "app";
            program = "${pkgs.writeShellScript "build-vma-images" ''
              set -e
              echo "🏗️  Building Proxmox VMA images"
              echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
              echo ""
              echo "These are full VM images in VMA format that can be"
              echo "restored directly in Proxmox using 'qmrestore'."
              echo ""

              echo "Building Router VMA image..."
              nix build .#proxmox-router-vma -o result-router-vma

              echo "Building AI Agent VMA image..."
              nix build .#proxmox-ai-agent-vma -o result-ai-agent-vma

              echo ""
              echo "✅ VMA images built successfully!"
              echo ""
              echo "Images ready for Proxmox:"
              ls -lh result-*-vma/*.vma.zst

              echo ""
              echo "📚 To restore in Proxmox:"
              echo "  1. Upload VMA file to Proxmox server"
              echo "  2. qmrestore vzdump-qemu-200-orion-router.vma.zst 200"
              echo "  3. qmrestore vzdump-qemu-300-orion-ai-agent.vma.zst 300"
              echo ""
            ''}";
          };

          # Update all systems
          update-all = {
            type = "app";
            program = "${pkgs.writeShellScript "update-all" ''
              set -e
              echo "🔄 Updating all LuciVerse systems"

              # Update flake inputs
              nix flake update

              # Rebuild all configurations
              for host in orion-router orion-ai-agent orion-netbox orion-k3s-master orion-k3s-worker; do
                echo "Building $host..."
                nix build .#nixosConfigurations.$host.config.system.build.toplevel
              done

              echo "✅ Update complete!"
            ''}";
          };
        }
      ).apps;

      # Formatter for Nix files
      formatter = flake-utils.lib.eachDefaultSystem (system:
        nixpkgs.legacyPackages.${system}.nixpkgs-fmt
      ).formatter;
    };

  nixConfig = {
    extra-substituters = [
      "https://cache.nixos.org"
      "https://nix-community.cachix.org"
      "https://devenv.cachix.org"
    ];
    extra-trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw="
    ];

    # Enable flakes and nix command
    experimental-features = [ "nix-command" "flakes" ];

    # Optimize store automatically
    auto-optimise-store = true;
  };
}
