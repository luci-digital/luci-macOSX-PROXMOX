# ORION Deployment Checklist

**Complete deployment guide for Dell R730 ORION Hybrid Infrastructure**

---

## Pre-Deployment Phase (30 minutes)

### ☐ 1. Verify Hardware

- [ ] Dell R730 powered on and accessible
- [ ] iDRAC configured at 192.168.1.2
- [ ] All 8 network cables connected
- [ ] RAID controller configured (RAID 10 recommended)
- [ ] Server shows healthy status in iDRAC

**Verification**:
```bash
# Access iDRAC
open https://192.168.1.2
# Login: root / calvin
```

### ☐ 2. Prepare Workstation

- [ ] Python 3.8+ installed
- [ ] Git installed
- [ ] Network access to 192.168.1.0/24

**Verification**:
```bash
python3 --version  # Should show 3.8+
git --version
ping -c 3 192.168.1.2
```

### ☐ 3. Clone Repository

```bash
git clone https://github.com/luci-digital/luci-macOSX-PROXMOX.git
cd luci-macOSX-PROXMOX
```

- [ ] Repository cloned successfully
- [ ] All files present

### ☐ 4. Install Dependencies

```bash
pip3 install requests
```

- [ ] Python requests library installed

### ☐ 5. Download Required ISOs

**Proxmox VE**:
```bash
# Download from: https://www.proxmox.com/en/downloads
# Save to: ~/Downloads/proxmox-ve_8.x.iso
```

**NixOS** (optional - can download later):
```bash
# Download from: https://nixos.org/download.html
# Direct link: https://channels.nixos.org/nixos-24.11/latest-nixos-minimal-x86_64-linux.iso
wget -O /tmp/nixos-minimal.iso \
  https://channels.nixos.org/nixos-24.11/latest-nixos-minimal-x86_64-linux.iso
```

- [ ] Proxmox ISO downloaded (~1GB)
- [ ] NixOS ISO downloaded (~900MB) - optional

### ☐ 6. Run Pre-Deployment Check

```bash
chmod +x scripts/pre-deployment-check.sh
./scripts/pre-deployment-check.sh
```

- [ ] All checks passed (or only warnings)
- [ ] Ready to proceed

**Expected output**: "✓ Ready for deployment!"

---

## Deployment Phase (2-3 hours)

### ☐ 7. Install Proxmox VE

**Time: 30 minutes**

1. **Mount ISO via iDRAC**:
   ```
   - Open https://192.168.1.2
   - Go to: Virtual Console → Launch Virtual Console
   - Virtual Media → Connect Virtual Media
   - Map CD/DVD → Select proxmox-ve_8.x.iso
   ```

2. **Configure boot**:
   ```bash
   python3 deploy-orion-hybrid.py
   # Follow wizard to configure boot to CD
   ```

3. **Install Proxmox**:
   - Boot system (will boot from virtual CD)
   - Follow Proxmox installer:
     * Target disk: /dev/sda (or appropriate disk)
     * Country: Your location
     * Timezone: Your timezone
     * Password: Set strong password (save it!)
     * Email: your-email@domain.com
     * Hostname: `orion-pve.local`
     * IP: `192.168.100.10/24`
     * Gateway: `192.168.100.1`
     * DNS: `1.1.1.1`
   - Click Install
   - Wait for installation (10-15 minutes)
   - Reboot when prompted

4. **Verify Proxmox**:
   ```bash
   # Wait 2-3 minutes after reboot
   curl -k https://192.168.100.10:8006
   # Should return HTML
   ```

- [ ] Proxmox installed successfully
- [ ] Can access web UI: https://192.168.100.10:8006
- [ ] Can login as root

**Checkpoint**: Proxmox web UI accessible ✓

---

### ☐ 8. Configure Network Bridges

**Time: 10 minutes**

1. **Login to Proxmox web UI**:
   - URL: https://192.168.100.10:8006
   - User: root
   - Password: (from step 7)

2. **Create bridges**:
   - Navigate to: Datacenter → pve → System → Network
   - Click "Create" → "Linux Bridge"

   **vmbr0 (WAN)**:
   ```
   Name: vmbr0
   Bridge ports: eno3
   Comment: WAN - Telus Fiber
   VLAN aware: ✓
   ```

   **vmbr1 (LAN)**:
   ```
   Name: vmbr1
   Bridge ports: eno4
   IPv4/CIDR: 192.168.100.1/24
   Comment: LAN - Internal Network
   VLAN aware: ✓
   ```

   **vmbr2 (Guest)**:
   ```
   Name: vmbr2
   Bridge ports: eno5
   Comment: Guest Network
   ```

   **vmbr3 (Storage)**:
   ```
   Name: vmbr3
   Bridge ports: eno6
   Comment: Storage Network
   ```

3. **Apply configuration**:
   - Click "Apply Configuration"
   - May need to reboot Proxmox

- [ ] All 4 bridges created
- [ ] Configuration applied
- [ ] Proxmox still accessible after changes

**Checkpoint**: Network bridges configured ✓

---

### ☐ 9. Create Router VM (VM 200)

**Time: 45 minutes**

1. **Create VM in Proxmox**:
   ```
   - Click "Create VM"
   - General:
     * Node: pve
     * VM ID: 200
     * Name: ORION-Router
   - OS:
     * ISO: Upload NixOS ISO first, then select it
     * Type: Linux
     * Version: 6.x - 2.6 Kernel
   - System:
     * BIOS: OVMF (UEFI)
     * Add EFI Disk: ✓
     * Machine: q35
   - Disks:
     * Bus/Device: SCSI
     * Storage: local-lvm
     * Size: 50 GB
   - CPU:
     * Cores: 8
     * Type: host
   - Memory:
     * Memory: 32768 MB (32 GB)
   - Network:
     * net0: vmbr0 (WAN)
     * Add 3 more NICs:
       - net1: vmbr1 (LAN)
       - net2: vmbr2 (Guest)
       - net3: vmbr1 (Management)
   ```

2. **Start VM and install NixOS**:
   ```bash
   # In Proxmox web UI
   - Select VM 200
   - Click "Start"
   - Click "Console"
   ```

3. **In NixOS installer console**:
   ```bash
   # Partition disk
   parted /dev/sda -- mklabel gpt
   parted /dev/sda -- mkpart ESP fat32 1MiB 512MiB
   parted /dev/sda -- set 1 esp on
   parted /dev/sda -- mkpart primary 512MiB 100%

   # Format
   mkfs.fat -F 32 -n boot /dev/sda1
   mkfs.ext4 -L nixos /dev/sda2

   # Mount
   mount /dev/disk/by-label/nixos /mnt
   mkdir -p /mnt/boot
   mount /dev/disk/by-label/boot /mnt/boot

   # Generate config
   nixos-generate-config --root /mnt
   ```

4. **Transfer configuration**:
   ```bash
   # On your workstation
   scp vm-configs/router-vm/configuration.nix nixos@<ROUTER_IP>:/tmp/

   # In NixOS installer console
   mv /tmp/configuration.nix /mnt/etc/nixos/

   # Install
   nixos-install
   # Set root password when prompted

   # Reboot
   reboot
   ```

5. **Verify router**:
   ```bash
   # After reboot (wait 2-3 minutes)
   ping -c 3 192.168.100.1
   ssh admin@192.168.100.1  # May need to setup SSH key first
   ```

- [ ] VM 200 created
- [ ] NixOS installed
- [ ] Router configuration applied
- [ ] Router accessible at 192.168.100.1
- [ ] Can ping router

**Checkpoint**: Router VM running and accessible ✓

---

### ☐ 10. Configure Router SSH Access

**Time: 5 minutes**

```bash
# Generate SSH key if you don't have one
ssh-keygen -t ed25519 -C "your-email@domain.com"

# Copy public key to router
# You'll need to do this via console first time

# In router VM console:
mkdir -p /home/admin/.ssh
nano /home/admin/.ssh/authorized_keys
# Paste your public key (from ~/.ssh/id_ed25519.pub)

# Set permissions
chmod 700 /home/admin/.ssh
chmod 600 /home/admin/.ssh/authorized_keys
chown -R admin:admin /home/admin/.ssh

# Test SSH
ssh admin@192.168.100.1
```

- [ ] SSH key generated
- [ ] Public key added to router
- [ ] Can SSH without password

---

### ☐ 11. Verify Router Services

**Time: 10 minutes**

```bash
# SSH to router
ssh admin@192.168.100.1

# Check BIRD BGP
sudo birdc show protocols
# Should show 3 BGP peers (may be down until WAN is configured)

# Check firewall
sudo nft list ruleset
# Should show nftables rules

# Check DNS
dig @127.0.0.1 google.com
# Should resolve

# Check DHCP
systemctl status kea-dhcp4
# Should be active

# Check node exporter
curl http://localhost:9100/metrics
# Should return metrics
```

- [ ] BGP service running (BIRD2)
- [ ] Firewall active (nftables)
- [ ] DNS resolving (Unbound)
- [ ] DHCP server running (Kea)
- [ ] Node exporter running

**Checkpoint**: Router services operational ✓

---

### ☐ 12. Create AI Agent VM (VM 300)

**Time: 30 minutes**

1. **Create VM**:
   ```
   - Click "Create VM"
   - VM ID: 300
   - Name: ORION-AI-Agent
   - OS: NixOS ISO
   - Cores: 4
   - Memory: 16384 MB (16 GB)
   - Disk: 50 GB
   - Network: net0 → vmbr1 (LAN)
   ```

2. **Install NixOS** (same process as router):
   ```bash
   # Partition, format, mount (same as router)
   # Transfer configuration
   scp vm-configs/ai-agent-vm/configuration.nix nixos@<IP>:/tmp/
   scp vm-configs/ai-agent-vm/autonomous_agent.py nixos@<IP>:/tmp/

   # Install
   nixos-install
   reboot
   ```

3. **Verify AI Agent**:
   ```bash
   ping -c 3 192.168.100.20
   ssh admin@192.168.100.20

   # Check services
   systemctl status prometheus
   systemctl status grafana
   systemctl status orion-agent
   ```

- [ ] VM 300 created
- [ ] NixOS installed
- [ ] AI Agent configuration applied
- [ ] Prometheus running (port 9090)
- [ ] Grafana running (port 3000)
- [ ] AI agent service running

**Checkpoint**: AI Agent VM operational ✓

---

### ☐ 13. Configure Monitoring

**Time: 10 minutes**

1. **Access Grafana**:
   ```
   URL: http://192.168.100.20:3000
   Username: admin
   Password: orion2025
   ```

2. **Change password**:
   - Profile → Change Password
   - Set new strong password

3. **Verify Prometheus data source**:
   - Configuration → Data Sources
   - Should see "Prometheus" configured

4. **Check targets**:
   ```bash
   # Visit Prometheus
   open http://192.168.100.20:9090/targets
   # Should show:
   # - orion-router (192.168.100.1:9100) - UP
   # - orion-ai-agent (localhost:9100) - UP
   # - proxmox (192.168.100.10:9100) - UP/DOWN (if exporter installed)
   ```

- [ ] Can access Grafana
- [ ] Password changed
- [ ] Prometheus collecting metrics
- [ ] At least 2 targets UP

**Checkpoint**: Monitoring operational ✓

---

### ☐ 14. Test Internet Connectivity

**Time: 5 minutes**

```bash
# From your workstation
ping -c 3 192.168.100.1

# Set your workstation to use router as gateway
# (or connect a device to LAN)

# Test DNS
dig @192.168.100.1 google.com

# Test internet
ping -c 3 8.8.8.8
ping -c 3 google.com

# Test BGP (on router)
ssh admin@192.168.100.1 "birdc show protocols"
```

- [ ] Can reach router
- [ ] DNS resolving through router
- [ ] Internet connectivity working
- [ ] BGP sessions established (if WAN configured)

**Checkpoint**: Network routing functional ✓

---

### ☐ 15. Run Post-Deployment Validation

**Time: 5 minutes**

```bash
chmod +x scripts/post-deployment-check.sh
./scripts/post-deployment-check.sh
```

- [ ] All critical checks passed
- [ ] No failed checks
- [ ] System ready for use

**Expected output**: "✓ Deployment successful!"

---

## Post-Deployment Phase (30 minutes)

### ☐ 16. Security Hardening

- [ ] Change default passwords:
  - [ ] Proxmox root password
  - [ ] Router admin password
  - [ ] AI Agent admin password
  - [ ] Grafana admin password

- [ ] Configure SSH keys (disable password auth):
  ```bash
  # On each VM, edit /etc/nixos/configuration.nix
  services.openssh.settings.PasswordAuthentication = false;

  # Rebuild
  sudo nixos-rebuild switch
  ```

- [ ] Review firewall rules:
  ```bash
  ssh admin@192.168.100.1 "sudo nft list ruleset"
  ```

### ☐ 17. Configure Backups

```bash
# Setup Proxmox backup schedule
# In Proxmox web UI:
# Datacenter → Backup → Add

# Backup VMs weekly:
# - Schedule: Weekly, Sunday 2:00 AM
# - VMs: 200, 300
# - Retention: Keep 4 backups
```

- [ ] Proxmox backup schedule configured
- [ ] VM configs backed up to Git
- [ ] Backup destination configured

### ☐ 18. Documentation

- [ ] Network diagram updated
- [ ] Passwords stored in password manager
- [ ] IP addresses documented
- [ ] SSH keys backed up
- [ ] Configuration files committed to Git

---

## Optional Enhancements

### ☐ macOS VM (VM 100)

Follow existing `deploy-orion.sh` guide for macOS setup.

**Time: 2-3 hours**

- [ ] macOS VM created
- [ ] macOS installed
- [ ] OSX-PROXMOX configured
- [ ] OrbStack installed (for future glass UI)

### ☐ Additional Monitoring

- [ ] Custom Grafana dashboards created
- [ ] Email alerts configured
- [ ] Slack notifications setup
- [ ] Mobile access configured

### ☐ VPN Access

- [ ] WireGuard VPN configured on router
- [ ] Remote access tested
- [ ] Mobile clients configured

---

## Troubleshooting Guide

### Router VM won't boot

```bash
# Check VM settings in Proxmox
# Ensure:
# - Boot order: scsi0 first
# - EFI disk enabled
# - Correct network bridges

# View console for errors
# In Proxmox: VM 200 → Console
```

### BGP sessions not establishing

```bash
ssh admin@192.168.100.1

# Check WAN interface has IP
ip addr show eth0

# Test connectivity to BGP peers
ping -c 3 206.75.1.127

# Check BIRD logs
journalctl -u bird2 -f

# Restart BIRD
sudo systemctl restart bird2
```

### Grafana not accessible

```bash
ssh admin@192.168.100.20

# Check service
systemctl status grafana

# Check firewall
sudo nft list ruleset | grep 3000

# Check logs
journalctl -u grafana -f

# Restart
sudo systemctl restart grafana
```

### No internet from LAN

```bash
# On router
ssh admin@192.168.100.1

# Check NAT
sudo nft list table ip nat

# Check routing
ip route show

# Check WAN interface
ip addr show eth0

# Test from router itself
ping -c 3 8.8.8.8
```

---

## Success Criteria

✅ **Deployment is successful when**:

1. Proxmox web UI accessible
2. Router VM routing traffic
3. BGP sessions established (3/3)
4. AI Agent collecting metrics
5. Grafana showing dashboards
6. Internet connectivity working
7. DNS resolution working
8. All VMs auto-start on boot
9. Monitoring shows all services healthy
10. Post-deployment check passes

---

## Timeline Summary

| Phase | Time | Tasks |
|-------|------|-------|
| Pre-Deployment | 30 min | Setup, downloads, validation |
| Proxmox Install | 30 min | Install and configure Proxmox |
| Network Config | 10 min | Create bridges |
| Router VM | 45 min | Install and configure |
| AI Agent VM | 30 min | Install and configure |
| Testing | 15 min | Validate deployment |
| Security | 30 min | Harden security |
| **Total** | **3-4 hours** | Complete deployment |

---

## Support

If you encounter issues:

1. Check troubleshooting section above
2. Review logs: `journalctl -xe`
3. Check VM console output in Proxmox
4. Consult `ORION_HYBRID_ARCHITECTURE.md`
5. Verify network configuration
6. Re-run validation scripts

**Happy Deploying! 🚀**
