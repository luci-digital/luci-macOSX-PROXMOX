{ modulesPath, lib, pkgs, ... }:

{
  imports = [
    (modulesPath + "/virtualisation/proxmox-lxc.nix")
  ];

  # System configuration
  system.stateVersion = "24.11";
  networking.hostName = "autopve-server";
  networking.domain = "lucia-ai.internal";

  # Disable sandboxing in containers
  nix.settings.sandbox = false;

  # Enable networking
  networking.useDHCP = false;
  networking.interfaces.eth0.useDHCP = true;

  # Install Docker for running AutoPVE
  virtualisation.docker = {
    enable = true;
    autoPrune.enable = true;
  };

  # System packages
  environment.systemPackages = with pkgs; [
    vim
    wget
    curl
    git
    docker
    docker-compose
    python3
    python3Packages.ansible
    jq
  ];

  # AutoPVE docker-compose service
  systemd.services.autopve = {
    description = "AutoPVE - Proxmox Automated Installation Server";
    after = [ "docker.service" "network.target" ];
    wants = [ "docker.service" ];
    wantedBy = [ "multi-user.target" ];

    path = [ pkgs.docker pkgs.docker-compose ];

    script = ''
      cd /opt/autopve
      ${pkgs.docker-compose}/bin/docker-compose up -d
    '';

    preStart = ''
      mkdir -p /opt/autopve
      cd /opt/autopve

      # Download docker-compose.yml if not exists
      if [ ! -f docker-compose.yml ]; then
        ${pkgs.wget}/bin/wget -O docker-compose.yml \
          https://raw.githubusercontent.com/natankeddem/autopve/main/docker-compose.yml
      fi

      # Create custom configuration
      cat > docker-compose.override.yml <<EOF
      version: '3.8'
      services:
        autopve:
          container_name: autopve
          ports:
            - "8080:8080"
          environment:
            - AUTOPVE_PORT=8080
            - AUTOPVE_LOG_LEVEL=info
          restart: unless-stopped
          volumes:
            - ./data:/app/data
            - ./config:/app/config
      EOF
    '';

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      Restart = "on-failure";
      RestartSec = "30s";
    };
  };

  # Firewall
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [
      22    # SSH
      8080  # AutoPVE
    ];
  };

  # SSH
  services.openssh = {
    enable = true;
    settings.PermitRootLogin = "yes";
    settings.PasswordAuthentication = false;
  };

  # Create admin user
  users.users.admin = {
    isNormalUser = true;
    extraGroups = [ "wheel" "docker" ];
    openssh.authorizedKeys.keys = [
      # Add your SSH public key here
    ];
  };

  # Sudo without password
  security.sudo.wheelNeedsPassword = false;

  # Create required directories
  systemd.tmpfiles.rules = [
    "d /opt/autopve 0755 root root -"
    "d /opt/autopve/data 0755 root root -"
    "d /opt/autopve/config 0755 root root -"
  ];
}
