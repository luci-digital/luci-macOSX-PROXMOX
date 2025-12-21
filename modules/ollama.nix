{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.ollama-agent;
in
{
  options.services.ollama-agent = {
    enable = mkEnableOption "Ollama LLM server for LuciVerse";

    package = mkOption {
      type = types.package;
      default = pkgs.ollama;
      description = "The Ollama package to use";
    };

    listenAddress = mkOption {
      type = types.str;
      default = "0.0.0.0:11434";
      description = "Address and port for Ollama to listen on";
    };

    models = mkOption {
      type = types.listOf types.str;
      default = [ "llama3.2" "mistral" "codellama" ];
      description = "Models to pre-download during activation";
    };

    dataDir = mkOption {
      type = types.path;
      default = "/var/lib/ollama";
      description = "Directory to store Ollama data and models";
    };

    gpuSupport = mkOption {
      type = types.bool;
      default = true;
      description = "Enable GPU acceleration if available";
    };

    maxConnections = mkOption {
      type = types.int;
      default = 100;
      description = "Maximum number of concurrent connections";
    };
  };

  config = mkIf cfg.enable {
    # Install Ollama package
    environment.systemPackages = [ cfg.package ];

    # Create ollama user
    users.users.ollama = {
      isSystemUser = true;
      group = "ollama";
      description = "Ollama LLM Server";
      home = cfg.dataDir;
      createHome = true;
    };

    users.groups.ollama = {};

    # Systemd service
    systemd.services.ollama = {
      description = "Ollama LLM Server";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      environment = {
        OLLAMA_HOST = cfg.listenAddress;
        OLLAMA_MODELS = "${cfg.dataDir}/models";
      } // optionalAttrs cfg.gpuSupport {
        # Enable GPU support if available
        OLLAMA_GPU = "1";
      };

      serviceConfig = {
        Type = "simple";
        User = "ollama";
        Group = "ollama";
        ExecStart = "${cfg.package}/bin/ollama serve";
        Restart = "on-failure";
        RestartSec = "10s";

        # Security hardening
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [ cfg.dataDir ];

        # Resource limits
        LimitNOFILE = toString (cfg.maxConnections * 2);
        MemoryHigh = "32G";
        MemoryMax = "48G";
      };
    };

    # Model download service (runs once at startup)
    systemd.services.ollama-model-pull = {
      description = "Download Ollama models";
      after = [ "ollama.service" ];
      wants = [ "ollama.service" ];
      wantedBy = [ "multi-user.target" ];

      path = [ cfg.package pkgs.curl ];

      script = ''
        # Wait for Ollama to be ready
        until curl -s http://localhost:11434/api/tags > /dev/null; do
          echo "Waiting for Ollama to start..."
          sleep 2
        done

        # Pull each model
        ${concatMapStringsSep "\n" (model: ''
          echo "Pulling model: ${model}"
          ${cfg.package}/bin/ollama pull ${model} || true
        '') cfg.models}

        echo "All models downloaded"
      '';

      serviceConfig = {
        Type = "oneshot";
        User = "ollama";
        Group = "ollama";
        RemainAfterExit = true;
      };
    };

    # Prometheus exporter for Ollama metrics
    systemd.services.ollama-exporter = {
      description = "Prometheus exporter for Ollama";
      after = [ "ollama.service" ];
      wants = [ "ollama.service" ];
      wantedBy = [ "multi-user.target" ];

      script = ''
        ${pkgs.python3}/bin/python3 ${./ollama-exporter.py}
      '';

      serviceConfig = {
        Type = "simple";
        User = "ollama";
        Group = "ollama";
        Restart = "on-failure";
      };
    };

    # Firewall configuration
    networking.firewall = {
      allowedTCPPorts = [
        11434  # Ollama API
        9100   # Prometheus node exporter
        9101   # Ollama custom exporter
      ];
    };

    # Create data directories
    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0755 ollama ollama -"
      "d ${cfg.dataDir}/models 0755 ollama ollama -"
    ];
  };
}
