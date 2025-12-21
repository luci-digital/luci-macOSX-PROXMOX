# Proxmox VMA Image Deployment Guide

**Using Official NixOS proxmox-image.nix Module**

---

## 🎯 Overview

This guide shows how to build and deploy **VMA (Virtual Machine Archive)** format images for Proxmox VE using the official NixOS `proxmox-image.nix` module. These images can be directly restored into Proxmox, providing a fully declarative way to deploy VMs.

### What is VMA?

VMA is Proxmox's backup format. By building VMA images with Nix, you get:
- **Reproducible VMs**: Exact same VM every time
- **Cloud-init ready**: Automatic configuration on first boot
- **Version controlled**: Infrastructure defined as code
- **Fast deployment**: Just restore the VMA file

---

## 🔧 Building VMA Images

### Quick Start

```bash
# Build all VMA images at once
nix run .#build-vma-images

# Or build individually
nix build .#proxmox-router-vma -o result-router-vma
nix build .#proxmox-ai-agent-vma -o result-ai-agent-vma
```

### What Gets Built

Each VMA image includes:
- Complete NixOS system
- All configured services
- Cloud-init support
- Compressed with zstd (`.vma.zst`)
- Ready-to-restore format

---

## 📦 Available VMA Images

### 1. Router VM (VM 200)

**Image**: `vzdump-qemu-200-orion-router.vma.zst`

**Configuration**:
- 8 CPU cores
- 32GB RAM
- UEFI (OVMF) BIOS
- 4 network interfaces (WAN, LAN, Guest, Management)
- GoBGP for routing
- Unbound DNS
- Kea DHCP server
- nftables firewall

**Build**:
```bash
nix build .#proxmox-router-vma -o result-router-vma
```

### 2. AI Agent VM (VM 300)

**Image**: `vzdump-qemu-300-orion-ai-agent.vma.zst`

**Configuration**:
- 8 CPU cores
- 16GB RAM
- UEFI (OVMF) BIOS
- Ollama LLM server
- Prometheus monitoring
- Grafana dashboards
- AI agent framework

**Build**:
```bash
nix build .#proxmox-ai-agent-vma -o result-ai-agent-vma
```

---

## 🚀 Deploying to Proxmox

### Method 1: Direct Restore (Recommended)

**Step 1: Upload VMA file to Proxmox**

```bash
# From your local machine
scp result-router-vma/vzdump-qemu-200-orion-router.vma.zst \
    root@proxmox:/var/lib/vz/dump/

scp result-ai-agent-vma/vzdump-qemu-300-orion-ai-agent.vma.zst \
    root@proxmox:/var/lib/vz/dump/
```

**Step 2: Restore VMA on Proxmox**

```bash
# SSH to Proxmox host
ssh root@proxmox

# Restore router VM (VM ID 200)
qmrestore /var/lib/vz/dump/vzdump-qemu-200-orion-router.vma.zst 200 \
  --storage local-lvm

# Restore AI agent VM (VM ID 300)
qmrestore /var/lib/vz/dump/vzdump-qemu-300-orion-ai-agent.vma.zst 300 \
  --storage local-lvm
```

**Step 3: Configure Cloud-init (Optional)**

```bash
# Set cloud-init user
qm set 200 --ciuser admin --cipassword your-password
qm set 300 --ciuser admin --cipassword your-password

# Add SSH keys
qm set 200 --sshkeys ~/.ssh/authorized_keys
qm set 300 --sshkeys ~/.ssh/authorized_keys

# Set IP address (or use DHCP)
qm set 200 --ipconfig0 ip=192.168.100.1/24,gw=192.168.100.254
qm set 300 --ipconfig0 ip=192.168.100.20/24,gw=192.168.100.1
```

**Step 4: Start VMs**

```bash
qm start 200
qm start 300
```

### Method 2: Automated Deployment Script

```bash
#!/bin/bash
# deploy-vma.sh

PROXMOX_HOST="192.168.100.10"
PROXMOX_USER="root"

# Build images
echo "Building VMA images..."
nix run .#build-vma-images

# Upload to Proxmox
echo "Uploading to Proxmox..."
scp result-router-vma/*.vma.zst ${PROXMOX_USER}@${PROXMOX_HOST}:/var/lib/vz/dump/
scp result-ai-agent-vma/*.vma.zst ${PROXMOX_USER}@${PROXMOX_HOST}:/var/lib/vz/dump/

# Restore VMs
ssh ${PROXMOX_USER}@${PROXMOX_HOST} bash <<'EOF'
  # Restore router
  qmrestore /var/lib/vz/dump/vzdump-qemu-200-orion-router.vma.zst 200 --storage local-lvm

  # Configure cloud-init
  qm set 200 --ciuser admin --ipconfig0 ip=192.168.100.1/24

  # Start VM
  qm start 200

  # Same for AI agent...
  qmrestore /var/lib/vz/dump/vzdump-qemu-300-orion-ai-agent.vma.zst 300 --storage local-lvm
  qm set 300 --ciuser admin --ipconfig0 ip=192.168.100.20/24,gw=192.168.100.1
  qm start 300
EOF

echo "✅ VMs deployed and started!"
```

---

## 🔧 Customizing VMA Images

### Editing VM Configuration

Edit the respective `proxmox-image.nix` file:

```nix
# vm-configs/ai-agent-vm/proxmox-image.nix
{
  proxmox.qemuConf = {
    cores = 16;        # Change CPU cores
    memory = 32768;    # Change RAM (in MB)
    bios = "ovmf";     # UEFI or "seabios" for legacy
  };

  virtualisation.diskSize = "200G";  # Change disk size

  # Add more services
  services.postgresql.enable = true;
}
```

### Adding New Services

```nix
{
  # Add Redis
  services.redis.servers."" = {
    enable = true;
    port = 6379;
  };

  # Open firewall
  networking.firewall.allowedTCPPorts = [ 6379 ];
}
```

### Rebuild After Changes

```bash
nix build .#proxmox-ai-agent-vma -o result-ai-agent-vma
```

---

## 🎨 Advanced Configuration

### Multi-Network Setup

```nix
proxmox.qemuExtraConf = {
  # Additional network interfaces
  net1 = "virtio=AA:BB:CC:DD:EE:02,bridge=vmbr1,firewall=1";
  net2 = "virtio=AA:BB:CC:DD:EE:03,bridge=vmbr2,firewall=1";
};
```

### Custom Partition Table

```nix
proxmox.partitionTableType = "hybrid";  # BIOS + UEFI support
# Options: "efi", "legacy", "hybrid", "legacy+gpt"
```

### Disk Size and Additional Space

```nix
proxmox.qemuConf = {
  additionalSpace = "50G";  # Extra space beyond base image
  bootSize = "512M";        # EFI boot partition size
};

virtualisation.diskSize = "100G";  # Total disk size
```

### Cloud-init Configuration

```nix
proxmox.cloudInit = {
  enable = true;
  defaultStorage = "local-lvm";
  device = "ide2";  # or "scsi0", "sata0", etc.
};
```

---

## 📋 Official Module Options

The official `proxmox-image.nix` module provides these options:

### Essential Options

```nix
proxmox.qemuConf = {
  boot = "";                                    # Boot device order
  scsihw = "virtio-scsi-single";               # SCSI controller
  virtio0 = "local-lvm:vm-999-disk-0";         # Disk configuration
  ostype = "l26";                              # OS type (Linux 2.6+)
  cores = 4;                                   # CPU cores
  memory = 8192;                               # RAM in MB
  bios = "ovmf";                               # "ovmf" or "seabios"
};
```

### Optional Options

```nix
proxmox.qemuConf = {
  name = "my-nixos-vm";                        # VM name
  additionalSpace = "10G";                     # Extra disk space
  bootSize = "256M";                           # Boot partition size
  net0 = "virtio=...,bridge=vmbr0";           # Network config
  serial0 = "socket";                          # Serial console
  agent = true;                                # QEMU guest agent
};
```

### Extra Configuration

```nix
proxmox.qemuExtraConf = {
  cpu = "host";        # CPU type
  onboot = 1;          # Start on boot
  protection = 0;      # Deletion protection
};
```

---

## 🔍 Troubleshooting

### Issue: "VMA format not supported"

**Solution**: VMA is a Proxmox-specific format. The module automatically patches QEMU with VMA support during build.

### Issue: "Cloud-init not working"

**Solution**: Ensure you've attached the cloud-init drive:

```bash
qm set <VMID> --ide2 local-lvm:cloudinit
```

### Issue: "VM won't boot"

**Check**:
1. BIOS type matches partition table:
   - `bios = "ovmf"` requires `partitionTableType = "efi"` or `"hybrid"`
   - `bios = "seabios"` requires `partitionTableType = "legacy"` or `"legacy+gpt"`

2. Verify boot order:
   ```bash
   qm config <VMID> | grep boot
   ```

### Issue: "Network not configured"

**Solution**: Use cloud-init to configure network:

```bash
qm set <VMID> --ipconfig0 ip=dhcp
# Or static:
qm set <VMID> --ipconfig0 ip=192.168.1.100/24,gw=192.168.1.1
```

---

## 📊 Comparison: VMA vs LXC

| Feature | VMA Images | LXC Containers |
|---------|------------|----------------|
| **Isolation** | Full VM | Container (shared kernel) |
| **Resources** | Higher overhead | Lightweight |
| **Use Case** | Complex services, routing | Microservices, apps |
| **Boot Time** | Slower (~30s) | Fast (~2s) |
| **Kernel** | Own kernel | Host kernel |
| **Network** | Full control | Limited |
| **Best For** | Routers, complex systems | AI services, databases |

### When to Use VMA Images

- ✅ Network routing (multiple NICs, BGP)
- ✅ Custom kernels or modules
- ✅ Full system control
- ✅ Running multiple distributions

### When to Use LXC Containers

- ✅ AI/ML services (Ollama, LiteLLM)
- ✅ Application servers
- ✅ Databases (PostgreSQL, Redis)
- ✅ Lightweight, single-purpose services

---

## 🚀 LuciVerse Deployment Strategy

Our **hybrid approach** uses both:

### VMA Images For:
- VM 200: Router (requires multiple NICs, BGP, kernel tuning)
- VM 600-603: K3s cluster (full system control)

### LXC Containers For:
- Ollama LLM server
- LiteLLM API gateway
- FlowiseAI
- PostgreSQL with pgvector
- Redis
- MinIO

### Benefits:
- **Performance**: LXC containers for AI services (lower overhead)
- **Flexibility**: VMs for complex infrastructure
- **Cost**: Better resource utilization
- **Management**: Right tool for the job

---

## 📚 References

- [Official proxmox-image.nix module](https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/virtualisation/proxmox-image.nix)
- [Proxmox VE Documentation](https://pve.proxmox.com/wiki/Main_Page)
- [NixOS Manual - Proxmox](https://nixos.org/manual/nixos/stable/index.html#sec-building-image-proxmox)
- [VMA Format Specification](https://git.proxmox.com/?p=pve-qemu.git)

---

## 🎯 Next Steps

1. **Build your first VMA image**:
   ```bash
   nix build .#proxmox-ai-agent-vma
   ```

2. **Deploy to Proxmox**:
   ```bash
   qmrestore vzdump-qemu-300-orion-ai-agent.vma.zst 300
   ```

3. **Customize for your needs**:
   - Edit `vm-configs/ai-agent-vm/proxmox-image.nix`
   - Rebuild and redeploy

4. **Automate deployments**:
   - Use the provided deployment scripts
   - Integrate with CI/CD

5. **Combine with LXC**:
   - Use VMA for infrastructure VMs
   - Use LXC for application services

---

**Happy deploying! 🚀**
