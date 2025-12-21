{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    "${modulesPath}/virtualisation/proxmox-image.nix"
  ];

  # System configuration
  system.stateVersion = "24.11";
  networking.hostName = "orion-router";
  networking.domain = "lucia-ai.internal";

  # Proxmox VM configuration
  proxmox = {
    qemuConf = {
      # VM Resources
      cores = 8;
      memory = 32768; # 32GB RAM for routing
      bios = "ovmf"; # UEFI

      # VM Name
      name = "orion-router-nixos";

      # Network - multiple interfaces for router
      net0 = "virtio=00:00:00:00:00:01,bridge=vmbr0,firewall=1"; # WAN
      # Additional NICs will be configured via qemuExtraConf

      # Storage
      virtio0 = "local-lvm:vm-200-disk-0";
      additionalSpace = "5G";

      # Serial console
      serial0 = "socket";

      # QEMU Guest Agent
      agent = true;
    };

    # Additional QEMU options for router
    qemuExtraConf = {
      cpu = "host";
      onboot = 1;
      protection = 0;
      # Additional network interfaces
      net1 = "virtio=00:00:00:00:00:02,bridge=vmbr1,firewall=1"; # LAN
      net2 = "virtio=00:00:00:00:00:03,bridge=vmbr2,firewall=1"; # Guest
      net3 = "virtio=00:00:00:00:00:04,bridge=vmbr3,firewall=1"; # Management
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
    filenameSuffix = "200-orion-router";
  };

  # Disk size
  virtualisation.diskSize = "50G";

  # Boot configuration
  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.kernelModules = [ "kvm-intel" ];

  # Enable IP forwarding for routing
  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
    "net.ipv6.conf.all.forwarding" = 1;
    "net.ipv4.conf.all.rp_filter" = 0;
    "net.ipv4.conf.default.rp_filter" = 0;
  };

  # Firewall will be managed by nftables
  networking.firewall.enable = false;
  networking.nftables.enable = true;
  networking.nftables.ruleset = ''
    table inet filter {
      chain input {
        type filter hook input priority 0; policy drop;

        # Accept loopback
        iif lo accept

        # Accept established/related
        ct state {established, related} accept

        # Accept ICMP
        ip protocol icmp accept
        ip6 nexthdr icmpv6 accept

        # Accept SSH from LAN
        iif eth1 tcp dport 22 accept
        iif eth3 tcp dport 22 accept

        # Accept BGP from WAN
        iif eth0 tcp dport 179 accept

        # Drop everything else
        counter drop
      }

      chain forward {
        type filter hook forward priority 0; policy drop;

        # Accept established/related
        ct state {established, related} accept

        # Allow LAN to WAN
        iif eth1 oif eth0 accept

        # Allow Guest to WAN (restricted)
        iif eth2 oif eth0 accept

        # Drop everything else
        counter drop
      }

      chain output {
        type filter hook output priority 0; policy accept;
      }
    }

    table ip nat {
      chain postrouting {
        type nat hook postrouting priority 100; policy accept;

        # NAT for LAN
        oif eth0 ip saddr 192.168.100.0/24 masquerade

        # NAT for Guest
        oif eth0 ip saddr 192.168.200.0/24 masquerade
      }
    }
  '';

  # GoBGP for routing (using our custom module)
  services.gobgp = {
    enable = true;
    as = 394955;
    routerId = "192.168.100.1";
    api = {
      grpc.enable = true;
      grpc.port = 50051;
      rest.enable = true;
      rest.port = 8080;
    };
  };

  # DHCP Server
  services.kea.dhcp4 = {
    enable = true;
    settings = {
      interfaces-config = {
        interfaces = [ "eth1" ];
      };
      lease-database = {
        type = "memfile";
        persist = true;
        name = "/var/lib/kea/dhcp4.leases";
      };
      subnet4 = [{
        id = 1;
        subnet = "192.168.100.0/24";
        pools = [{ pool = "192.168.100.100 - 192.168.100.200"; }];
        option-data = [
          {
            name = "routers";
            data = "192.168.100.1";
          }
          {
            name = "domain-name-servers";
            data = "192.168.100.1";
          }
        ];
      }];
    };
  };

  # DNS Server (Unbound)
  services.unbound = {
    enable = true;
    settings = {
      server = {
        interface = [ "192.168.100.1" "127.0.0.1" ];
        access-control = [
          "192.168.100.0/24 allow"
          "127.0.0.0/8 allow"
        ];

        # Forward to Cloudflare/Google
        forward-zone = [
          {
            name = ".";
            forward-addr = [
              "1.1.1.1@853#cloudflare-dns.com"
              "1.0.0.1@853#cloudflare-dns.com"
              "8.8.8.8@853#dns.google"
              "8.8.4.4@853#dns.google"
            ];
            forward-tls-upstream = true;
          }
        ];
      };
    };
  };

  # Monitoring - node exporter
  services.prometheus.exporters.node = {
    enable = true;
    enabledCollectors = [ "systemd" "network" ];
    port = 9100;
  };

  # SSH
  services.openssh = {
    enable = true;
    settings.PermitRootLogin = "prohibit-password";
    settings.PasswordAuthentication = false;
  };

  # System packages
  environment.systemPackages = with pkgs; [
    vim
    wget
    curl
    htop
    iftop
    tcpdump
    mtr
    bind  # for dig/nslookup
    iproute2
    nftables
    bird2
    gobgp
    python3
  ];

  # Automatic system upgrades
  system.autoUpgrade = {
    enable = true;
    allowReboot = false;
    dates = "weekly";
  };
}
