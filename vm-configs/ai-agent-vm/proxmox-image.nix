{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    "${modulesPath}/virtualisation/proxmox-image.nix"
  ];

  # System configuration
  system.stateVersion = "24.11";
  networking.hostName = "orion-ai-agent";
  networking.domain = "lucia-ai.internal";

  # Proxmox VM configuration
  proxmox = {
    qemuConf = {
      # VM Resources
      cores = 8;
      memory = 16384; # 16GB RAM
      bios = "ovmf"; # UEFI

      # VM Name
      name = "orion-ai-agent-nixos";

      # Network
      net0 = "virtio=00:00:00:00:00:00,bridge=vmbr1,firewall=1";

      # Storage
      virtio0 = "local-lvm:vm-300-disk-0";
      additionalSpace = "10G";

      # Serial console
      serial0 = "socket";

      # QEMU Guest Agent
      agent = true;
    };

    # Additional QEMU options
    qemuExtraConf = {
      cpu = "host";
      onboot = 1;
      protection = 0;
    };

    # Partition table
    partitionTableType = "efi";

    # Cloud-init support
    cloudInit = {
      enable = true;
      defaultStorage = "local-lvm";
      device = "ide2";
    };

    # Filename for VMA archive
    filenameSuffix = "300-orion-ai-agent";
  };

  # Disk size
  virtualisation.diskSize = "100G";

  # Boot configuration (handled by proxmox-image.nix)
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # Firewall
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [
      22      # SSH
      3000    # Grafana
      9090    # Prometheus
      9100    # Node exporter
      11434   # Ollama
    ];
  };

  # Services - Prometheus
  services.prometheus = {
    enable = true;
    port = 9090;
    scrapeConfigs = [
      {
        job_name = "orion-router";
        static_configs = [{
          targets = [ "192.168.100.1:9100" ];
          labels = { alias = "router"; };
        }];
      }
      {
        job_name = "orion-ai-agent";
        static_configs = [{
          targets = [ "localhost:9100" ];
          labels = { alias = "ai-agent"; };
        }];
      }
      {
        job_name = "ollama";
        static_configs = [{
          targets = [ "localhost:11434" ];
          labels = { alias = "ollama-llm"; };
        }];
      }
    ];

    rules = [
      ''
        groups:
          - name: orion_alerts
            interval: 30s
            rules:
              - alert: HighCPUUsage
                expr: 100 - (avg by (instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 90
                for: 5m
                labels:
                  severity: warning
                annotations:
                  summary: "High CPU usage detected"
                  description: "CPU usage is above 90% for 5 minutes"

              - alert: OllamaDown
                expr: up{job="ollama"} == 0
                for: 1m
                labels:
                  severity: critical
                annotations:
                  summary: "Ollama LLM server is down"
                  description: "Ollama is not responding"
      ''
    ];
  };

  # Prometheus node exporter
  services.prometheus.exporters.node = {
    enable = true;
    enabledCollectors = [ "systemd" ];
    port = 9100;
  };

  # Grafana
  services.grafana = {
    enable = true;
    settings = {
      server = {
        http_addr = "0.0.0.0";
        http_port = 3000;
      };
      security = {
        admin_user = "admin";
        admin_password = "$__file{/run/grafana/admin-password}";
      };
    };

    provision = {
      enable = true;
      datasources.settings.datasources = [{
        name = "Prometheus";
        type = "prometheus";
        url = "http://localhost:9090";
        isDefault = true;
      }];
    };
  };

  # Ollama LLM server using our custom module
  services.ollama-agent = {
    enable = true;
    listenAddress = "0.0.0.0:11434";
    models = [
      "llama3.2"
      "mistral"
      "codellama"
      "deepseek-coder-v2"
    ];
    gpuSupport = true;
    maxConnections = 100;
  };

  # SSH
  services.openssh = {
    enable = true;
    settings.PermitRootLogin = "prohibit-password";
    settings.PasswordAuthentication = false;
  };

  # Cloud-init will manage the hostname and networking
  # Users will be configured via cloud-init

  # System packages
  environment.systemPackages = with pkgs; [
    vim
    wget
    curl
    htop
    git
    python3
    python3Packages.requests
    python3Packages.prometheus-client
    python3Packages.openai
    python3Packages.anthropic
    tmux
    jq
    ollama
  ];

  # Automatic system upgrades
  system.autoUpgrade = {
    enable = true;
    allowReboot = false;
    dates = "weekly";
  };
}
