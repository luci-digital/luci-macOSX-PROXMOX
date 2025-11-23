# ORION Smart Development Environment

**Auto-loading environment with intelligent aliases and shortcuts**

---

## Overview

The ORION development environment uses **zsh-autoenv** to automatically configure your shell when you enter the ORION directory. This gives you instant access to all ORION commands, infrastructure details, and helper functions without manual setup.

### What It Does

✅ **Auto-loads** when you `cd` into ORION directory
✅ **Auto-unloads** when you leave
✅ **Activates** Python virtual environment
✅ **Configures** environment variables
✅ **Provides** 50+ helper commands and aliases
✅ **Manages** SSH keys automatically

---

## Quick Start

### Installation (One-Time Setup)

```bash
cd /home/user/luci-macOSX-PROXMOX

# Run setup script
chmod +x scripts/setup-dev-env.sh
./scripts/setup-dev-env.sh

# Restart terminal or run:
exec zsh
```

**What gets installed**:
- zsh (modern shell)
- antigen (plugin manager)
- zsh-autoenv (auto-loading environments)
- zsh-syntax-highlighting
- zsh-autosuggestions
- zsh-completions

### First Use

```bash
# Navigate to ORION directory
cd /home/user/luci-macOSX-PROXMOX

# You'll see this prompt (first time only):
# autoenv: Would you like to authorize this file? [yes/no]
yes

# Environment loads automatically!
# You'll see:
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 🚀 ORION Hybrid Infrastructure Environment
#    Version: 2.0.0-hybrid
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### Usage

Every time you `cd` into the ORION directory, the environment auto-loads:

```bash
cd ~/other-directory
# Normal shell

cd /home/user/luci-macOSX-PROXMOX
# 🚀 ORION environment loaded!
# All commands available!

orion-help  # See all commands
```

---

## Available Commands

### 📦 Deployment Commands

```bash
orion-deploy         # Deploy ORION infrastructure
orion-status         # Check system power status (iDRAC)
orion-power-on       # Power on Dell R730
orion-power-off      # Power off Dell R730
orion-reboot         # Reboot Dell R730
```

### ✅ Validation Commands

```bash
orion-pre-check      # Run pre-deployment validation
orion-post-check     # Run post-deployment validation
orion-validate       # Alias for post-check
orion-overview       # Quick status overview
orion-test           # Quick connectivity test
```

### 🔌 SSH Access

```bash
ssh-router           # SSH to Router VM (192.168.100.1)
ssh-agent-vm         # SSH to AI Agent VM (192.168.100.20)
ssh-macos            # SSH to macOS VM (192.168.100.50)
```

### 🌐 Web Services

```bash
proxmox              # Open Proxmox web UI
grafana              # Open Grafana dashboard
prometheus           # Open Prometheus
idrac                # Open iDRAC console
```

### 📊 Monitoring Commands

```bash
orion-metrics        # Show Prometheus targets (JSON)
orion-bgp            # Show BGP session status
orion-routes         # Show BGP routing table
orion-firewall       # Show nftables firewall rules
```

### 📝 Log Streaming

```bash
router-logs          # Stream router system logs
agent-logs           # Stream AI agent logs
bird-logs            # Stream BGP daemon logs
```

### 🔧 Quick Actions

```bash
orion-restart-bgp       # Restart BGP service
orion-restart-agent     # Restart AI autonomous agent
orion-restart-grafana   # Restart Grafana
```

### 📚 Documentation

```bash
orion-docs           # View full architecture docs
orion-quickstart     # View quick start guide
orion-checklist      # View deployment checklist
orion-help           # Show all commands
```

### 🖥️ VM Management (Proxmox)

If running on Proxmox host:

```bash
vm-list              # List all VMs
vm-router            # Open Router VM console
vm-agent             # Open AI Agent VM console
vm-macos             # Open macOS VM console
vm-start-router      # Start Router VM
vm-start-agent       # Start AI Agent VM
vm-start-macos       # Start macOS VM
```

---

## Environment Variables

When ORION environment is loaded, these variables are available:

### Infrastructure IPs

```bash
$ORION_ROOT          # /home/user/luci-macOSX-PROXMOX
$ORION_VERSION       # 2.0.0-hybrid

$IDRAC_IP            # 192.168.1.2
$IDRAC_USER          # root
$IDRAC_PASS          # calvin (override with: export IDRAC_PASS=newpass)

$PROXMOX_IP          # 192.168.100.10
$PROXMOX_PORT        # 8006
$PROXMOX_USER        # root@pam

$ROUTER_IP           # 192.168.100.1
$AI_AGENT_IP         # 192.168.100.20
$MACOS_VM_IP         # 192.168.100.50
```

### Service Ports

```bash
$GRAFANA_PORT        # 3000
$PROMETHEUS_PORT     # 9090
$NODE_EXPORTER_PORT  # 9100
```

### BGP Configuration

```bash
$BGP_LOCAL_AS        # 394955
$BGP_REMOTE_AS       # 6939
```

### Using Variables

```bash
# In scripts or commands
curl http://$AI_AGENT_IP:$GRAFANA_PORT/api/health

# Override defaults
export ROUTER_IP="192.168.100.100"
```

---

## Advanced Features

### Python Virtual Environment

The environment automatically creates and activates a Python venv:

```bash
cd /home/user/luci-macOSX-PROXMOX
# (.venv) automatically activated

pip list  # See installed packages
python3 deploy-orion-hybrid.py  # Uses venv Python

cd ..
# (.venv) automatically deactivated
```

### SSH Agent Integration

SSH keys are automatically loaded:

```bash
# On environment load:
# - Starts ssh-agent if not running
# - Loads ~/.ssh/id_ed25519
# - Loads ~/.ssh/id_rsa

# Now you can SSH without passwords
ssh-router  # No password needed!
```

### PATH Management

ORION scripts are automatically added to PATH:

```bash
# Can run scripts without ./
pre-deployment-check.sh      # Instead of: ./scripts/pre-deployment-check.sh
post-deployment-check.sh     # Instead of: ./scripts/post-deployment-check.sh
```

---

## Example Workflow

### Daily Usage

```bash
# Morning: Check ORION status
cd ~/luci-macOSX-PROXMOX
# Environment loads automatically

orion-overview
# ✓ Shows status of all services

grafana
# Opens Grafana in browser

# Check BGP
orion-bgp
# Shows BGP session status

# View router logs
router-logs
# Streams live logs (Ctrl+C to exit)
```

### Deployment Workflow

```bash
cd ~/luci-macOSX-PROXMOX

# 1. Pre-check
orion-pre-check
# ✓ Ready for deployment!

# 2. Deploy
orion-deploy
# Follow wizard...

# 3. Validate
orion-post-check
# ✓ Deployment successful!

# 4. Access services
grafana           # Open Grafana
ssh-router        # Configure router
orion-bgp         # Check BGP sessions
```

### Troubleshooting Workflow

```bash
cd ~/luci-macOSX-PROXMOX

# Quick status check
orion-test
# Shows connectivity to all services

# Check specific service
ssh-router
birdc show protocols
exit

# Stream logs
agent-logs
# Watch for errors...

# Restart if needed
orion-restart-agent
```

---

## Customization

### Override Default IPs

Create `~/.orion_env` (sourced before autoenv):

```bash
# ~/.orion_env
export IDRAC_IP="192.168.1.100"
export ROUTER_IP="10.0.0.1"
export AI_AGENT_IP="10.0.0.20"
```

### Add Custom Aliases

Edit `.autoenv.zsh`:

```bash
# Add your custom aliases
alias my-command='ssh admin@$ROUTER_IP "some-command"'
alias my-script='python3 my-script.py'
```

### Disable Auto-Loading

Temporarily disable autoenv:

```bash
export AUTOENV_DISABLED=1
cd /home/user/luci-macOSX-PROXMOX
# No auto-load

unset AUTOENV_DISABLED
# Re-enable
```

---

## Troubleshooting

### Environment Not Loading

**Problem**: `cd` into directory but no ORION environment

**Solution**:
```bash
# Check if zsh-autoenv is loaded
antigen list | grep autoenv

# Reload .zshrc
source ~/.zshrc

# Re-approve .autoenv.zsh
rm ~/.autoenv_authorized
cd /home/user/luci-macOSX-PROXMOX
# Answer 'yes' when prompted
```

### Python Venv Issues

**Problem**: Virtual environment not activating

**Solution**:
```bash
# Remove and recreate venv
rm -rf .venv
cd ..
cd /home/user/luci-macOSX-PROXMOX
# Venv recreated automatically
```

### SSH Key Not Loading

**Problem**: SSH still asks for password

**Solution**:
```bash
# Check SSH agent
echo $SSH_AUTH_SOCK

# Manually add key
ssh-add ~/.ssh/id_ed25519

# Generate key if missing
ssh-keygen -t ed25519 -C "your-email@example.com"
```

### Commands Not Found

**Problem**: `orion-*` commands not available

**Solution**:
```bash
# Ensure you're in ORION directory
pwd
# Should show: /home/user/luci-macOSX-PROXMOX

# Check if environment loaded
echo $ORION_ROOT
# Should show: /home/user/luci-macOSX-PROXMOX

# Reload environment
cd ..
cd /home/user/luci-macOSX-PROXMOX
```

---

## Security Notes

### Autoenv Authorization

The first time you enter the ORION directory, you'll be prompted:

```
autoenv: Would you like to authorize this file?
/home/user/luci-macOSX-PROXMOX/.autoenv.zsh

yes/no:
```

Type `yes` - this is a security feature that prevents malicious code from auto-executing.

### Credentials

**Never commit sensitive credentials to Git:**

```bash
# Use environment variables for secrets
export IDRAC_PASS="your-secure-password"
export PROXMOX_PASS="your-proxmox-password"

# Or create ~/.orion_secrets (git-ignored)
source ~/.orion_secrets  # In .autoenv.zsh
```

### SSH Keys

Public keys are safe to share. Private keys should be:
- Chmod 600: `chmod 600 ~/.ssh/id_ed25519`
- Password-protected
- Backed up securely

---

## Comparison: Before vs After

### Before (Manual)

```bash
cd ~/luci-macOSX-PROXMOX

# Manual setup every time
export IDRAC_IP="192.168.1.2"
export ROUTER_IP="192.168.100.1"
export AI_AGENT_IP="192.168.100.20"

# Long commands
python3 deploy-orion-hybrid.py status
ssh admin@192.168.100.1
curl http://192.168.100.20:9090/api/v1/targets
./scripts/post-deployment-check.sh

# Need to remember all IPs
open https://192.168.100.10:8006
```

### After (Auto)

```bash
cd ~/luci-macOSX-PROXMOX
# Environment auto-loads ✨

# Short, memorable commands
orion-status
ssh-router
orion-metrics
orion-validate

# Simple shortcuts
proxmox  # Opens browser automatically
```

**Time saved**: ~30 seconds per command × 50 commands/day = **25 minutes/day**

---

## Tips & Tricks

### 1. Chain Commands

```bash
# Deploy and validate in one line
orion-deploy && orion-validate
```

### 2. Background Tasks

```bash
# Stream logs in background
router-logs &
agent-logs &

# Bring to foreground
fg %1  # Router logs
fg %2  # Agent logs
```

### 3. Quick Network Test

```bash
# Test all connectivity at once
orion-test
```

### 4. Copy-Paste Friendly

```bash
# All IPs available as variables
echo $ROUTER_IP | pbcopy     # macOS
echo $ROUTER_IP | xclip -i   # Linux
```

### 5. Explore Completions

```bash
orion-<TAB>
# Shows all orion-* commands

ssh-<TAB>
# Shows all ssh-* commands
```

---

## What's Next?

After setting up the smart environment:

1. **Deploy ORION**: `orion-deploy`
2. **Validate**: `orion-validate`
3. **Explore**: `orion-help`
4. **Monitor**: `grafana`
5. **Customize**: Add your own aliases to `.autoenv.zsh`

---

## Support

**Problems?**
- Check troubleshooting section above
- Review `.autoenv.zsh` for loaded config
- Run: `orion-help` for command list
- Check logs: `echo $ORION_ROOT`

**Want to enhance?**
- Edit `.autoenv.zsh` - Add custom commands
- Edit `.autoenv_leave.zsh` - Add cleanup steps
- Submit PR with improvements!

---

**Enjoy your intelligent ORION environment! 🚀**
