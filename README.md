<div align="center">

# 🚀 ORION - AI-First Infrastructure Stack

## Dell R730 Proxmox VE + Terraform + Kubernetes + AI Agents

![GitHub stars](https://img.shields.io/github/stars/luchina-gabriel/osx-proxmox?style=flat-square)
![GitHub forks](https://img.shields.io/github/forks/luchina-gabriel/OSX-PROXMOX?style=flat-square)
![GitHub license](https://img.shields.io/github/license/luchina-gabriel/osx-proxmox?style=flat-square)
![GitHub issues](https://img.shields.io/github/issues/luchina-gabriel/osx-proxmox?style=flat-square)

</div>

---

## 🎯 ORION v2.0 Architecture

Complete **Infrastructure as Code** stack for Dell PowerEdge R730, designed from the ground up as an **AI-first, agent-driven architecture** with multi-layer infrastructure.

### ✨ What's New in v2.0

- ✅ **Infrastructure as Code** - Terraform for VMs, Ansible for configuration
- ✅ **LXC AI/ML Stack** - Ollama, LiteLLM, FlowiseAI via helper scripts (5-minute deployment)
- ✅ **Kubernetes on K3s** - Lightweight orchestration for Backstage + Vapor API
- ✅ **Multi-Agent Architecture** - Proper 4-layer AI stack with specialized agents
- ✅ **IPv6 BGP Routing** - AS394955 with 2602:F674::/48 prefix
- ✅ **Security Through Obscurity** - "AI Maze" using Backstage + Swift/Vapor
- ✅ **One-Command Deployment** - Complete stack via Makefile
- ✅ **396 Helper Scripts** - Automated LXC container deployment

### 🚀 Quick Start

```bash
# Clone repository
git clone https://github.com/luci-digital/luci-macOSX-PROXMOX.git
cd luci-macOSX-PROXMOX

# Configure Terraform
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
nano terraform/terraform.tfvars  # Add Proxmox API token

# Deploy complete stack
make deploy-full

# Or deploy in phases:
make apply              # Deploy VMs with Terraform
make deploy-ai-stack    # Deploy AI/ML LXC containers
make configure          # Configure VMs with Ansible
make k8s-deploy         # Deploy K8s workloads
```

**Smart Development Environment** 🧠:
- 🎯 Auto-loads when entering directory
- ⚡ 50+ helpful commands and aliases (`orion-help`)
- 🔑 Auto-manages SSH keys and Python venv
- 📊 Quick access: `grafana`, `ssh-router`, `orion-status`
- 📚 [Setup Guide](DEV_ENVIRONMENT.md)

**Documentation**:
- 📘 **[Architecture Guide](ARCHITECTURE.md)** - Complete v2.0 architecture (THIS IS THE MAIN DOC!)
- 🔍 **[Architecture Review](ARCHITECTURE_REVIEW.md)** - AI engineering analysis
- 🤖 **[Helper Scripts Integration](docs/HELPER_SCRIPTS_INTEGRATION.md)** - LXC deployment guide
- 🌐 **[IPv6 Routing](docs/IPV6_ROUTING_INTEGRATION.md)** - BGP configuration
- 🤖 **[Claude Code Integration](docs/CLAUDE_CODE_INTEGRATION.md)** - AI-assisted development setup
- 💻 **[Development Environment](docs/DEVELOPMENT_ENVIRONMENT.md)** - Zsh, Oh My Zsh, Antigen setup
- 🏗️ **[Terraform Guide](terraform/README.md)** - Infrastructure deployment
- 📚 **[Reference Docs](docs/reference/)** - Archived v1.0 documentation

### 🏗️ Architecture Overview

```
Dell R730 ORION (56 cores, 384GB RAM)
├─ Proxmox VE 8.x (Hypervisor)
│
├─ Infrastructure VMs (Terraform)
│  ├─ VM 200: Router (BIRD2 BGP, IPv6, Firewall) - 8C/32GB
│  ├─ VM 300: AI Coordinator (Multi-agent orchestration) - 4C/16GB
│  ├─ VM 500: NetBox (IPAM) - 4C/8GB
│  └─ VM 600-603: K3s Cluster (1 master + 3 workers) - 16C/56GB
│
├─ LXC Containers (Helper Scripts - 5 min deploy)
│  ├─ LXC 1000: Ollama (LLM inference)
│  ├─ LXC 1001: OpenWebUI (ChatGPT-like UI)
│  ├─ LXC 1002: LiteLLM (API gateway)
│  ├─ LXC 1003: FlowiseAI (Visual agent builder)
│  ├─ LXC 1004: PostgreSQL + pgvector
│  ├─ LXC 1005: Redis
│  ├─ LXC 1006: Minio (S3 storage)
│  ├─ LXC 1007: Nginx Proxy Manager
│  └─ LXC 1008: Wireguard VPN
│
└─ Kubernetes Workloads (K3s)
   ├─ Infrastructure: Prometheus, Grafana, Cilium, Longhorn
   ├─ Applications: Backstage, Vapor API (Swift)
   └─ AI Agents: Infrastructure, Network, Security, DevOps
```

### 📦 Repository Structure

```
luci-macOSX-PROXMOX/
├── terraform/              # Infrastructure as Code
│   ├── main.tf            # VM definitions
│   ├── variables.tf       # Variables
│   └── outputs.tf         # Outputs
├── ansible/               # Configuration management
│   ├── playbooks/        # Ansible playbooks
│   └── roles/            # Ansible roles
├── kubernetes/            # K8s manifests
│   ├── infrastructure/   # Core services
│   ├── applications/     # Apps (Backstage, Vapor)
│   └── ai-agents/        # AI agents
├── router-configs/        # BIRD2/GoBGP configs
├── docs/                  # Documentation
│   ├── deployment-guide/
│   ├── ai-agent-design/
│   └── reference/        # Archived v1.0 docs
├── Makefile              # One-command deployment
├── ARCHITECTURE.md       # Main architecture doc
└── README.md             # This file
```

### 🌟 Key Features

**Infrastructure as Code**: Declarative, reproducible infrastructure via Terraform + Ansible

**LXC for AI/ML**: 5-minute deployment vs hours of manual K8s configuration

**4-Layer AI Stack**: Proper architecture - Inference → Orchestration → Agents → Coordinator

**Security "AI Maze"**: Backstage frontend + Swift/Vapor API to confuse automated scanners

**IPv6 BGP**: Production AS394955, peering with Telus AS6939, prefix 2602:F674::/48

**Hybrid Orchestration**: VMs for infra, LXC for AI/ML, K8s for apps - right tool for the job

**396 Helper Scripts**: Community-maintained automation for everything from databases to VPNs

### 🎯 What Makes This Different?

| Aspect | v1.0 (Old) | v2.0 (Current) |
|--------|-----------|----------------|
| **Deployment** | 4 conflicting scripts | Single Makefile path |
| **AI Stack** | Manual K8s manifests | 5-min LXC deployment |
| **Infrastructure** | Bash scripts | Terraform + Ansible |
| **Documentation** | Scattered | Consolidated |
| **Architecture** | Ambiguous | 4-layer AI stack |
| **Deployment Time** | 4-6 hours | ~30 minutes |

---

## 🍎 Original OSX-PROXMOX Guide

![v15 - Sequoia](https://github.com/user-attachments/assets/4efd8874-dbc8-48b6-a485-73f7c38a5e06)

The following guide provides the original OSX-PROXMOX installation method for running macOS on Proxmox VE with AMD or Intel hardware.

---

## 🛠 Installation Guide

1. Install a **FRESH/CLEAN** version of Proxmox VE (v7.0.XX ~ 8.4.XX) - just follow the Next, Next & Finish (NNF) approach.
   * Preliminary support for Proxmox VE V9.0.0 BETA.
2. Open the **Proxmox Web Console** → Navigate to `Datacenter > YOUR_HOST_NAME > Shell`.
3. Copy, paste, and execute the command below:

```bash
/bin/bash -c "$(curl -fsSL https://install.osx-proxmox.com)"
```

🎉 Voilà! You can now install macOS!
![osx-terminal](https://github.com/user-attachments/assets/ea81b920-f3e2-422e-b1ff-0d9045adc55e)
---

## 🔧 Additional Configuration

### Install EFI Package in macOS (Disable Gatekeeper First)

```bash
sudo spctl --master-disable
```

---

## 🍏 macOS Versions Supported
✅ macOS High Sierra - 10.13  
✅ macOS Mojave - 10.14  
✅ macOS Catalina - 10.15  
✅ macOS Big Sur - 11  
✅ macOS Monterey - 12  
✅ macOS Ventura - 13  
✅ macOS Sonoma - 14  
✅ macOS Sequoia - 15  

---

## 🖥 Proxmox VE Versions Supported
✅ v7.0.XX ~ 8.4.XX

### 🔄 OpenCore Version
- **April/2025 - 1.0.4** → with SIP Enabled, DMG only signed by Apple and all features of securities

---

## ☁️ Cloud Support (Run Hackintosh in the Cloud!)
- [🌍 VultR](https://www.vultr.com/?ref=9035565-8H)
- [📺 Video Tutorial](https://youtu.be/8QsMyL-PNrM) (Enable captions for better understanding)
- Now has configurable bridges, and can add as many bridges and specify the subnet for them.

---

## ⚠️ Disclaimer

🚨 **FOR DEVELOPMENT, STUDENT, AND TESTING PURPOSES ONLY.**

I am **not responsible** for any issues, damage, or data loss. Always back up your system before making any changes.

---

## 📌 Requirements

Since macOS Monterey, your host must have a **working TSC (timestamp counter)**. Otherwise, if you assign multiple cores to the VM, macOS may **crash due to time inconsistencies**. To check if your host is compatible, run the following command in Proxmox:

```bash
dmesg | grep -i -e tsc -e clocksource
```

### ✅ Expected Output (for working hosts):
```
clocksource: Switched to clocksource tsc
```

### ❌ Problematic Output (for broken hosts):
```
tsc: Marking TSC unstable due to check_tsc_sync_source failed
clocksource: Switched to clocksource hpet
```

### 🛠 Possible Fixes
1. Disable "ErP mode" and **all C-state power-saving modes** in your BIOS. Then power off your machine completely and restart.
2. Try forcing TSC in GRUB:
   - Edit `/etc/default/grub` and add:
     ```bash
     clocksource=tsc tsc=reliable
     ```
   - Run `update-grub` and reboot (This may cause instability).
3. Verify the TSC clock source:
   ```bash
   cat /sys/devices/system/clocksource/clocksource0/current_clocksource
   ```
   The output **must be `tsc`**.

[Read More](https://www.nicksherlock.com/2022/10/installing-macos-13-ventura-on-proxmox/comment-page-1/#comment-55532)

---

## 🔍 Troubleshooting

### ❌ High Sierra & Below - *Recovery Server Could Not Be Contacted*

If you encounter this error, you need to switch from **HTTPS** to **HTTP** in the installation URL:

1. When the error appears, leave the window open.
2. Open **Installer Log** (`Window > Installer Log`).
3. Search for "Failed to load catalog" → Copy the log entry.
4. Close the error message and return to `macOS Utilities`.
5. Open **Terminal**, paste the copied data, and **remove everything except the URL** (e.g., `https://example.sucatalog`).
6. Change `https://` to `http://`.
7. Run the command:

   ```bash
   nvram IASUCatalogURL="http://your-http-url.sucatalog"
   ```

8. Quit Terminal and restart the installation.

[Reference & More Details](https://mrmacintosh.com/how-to-fix-the-recovery-server-could-not-be-contacted-error-high-sierra-recovery-is-still-online-but-broken/)

### ❌ Problem for GPU Passthrough

If you see an Apple logo and the bar doesn’t move on your external display, you need to disable “above 4g decoding” in the motherboard’s BIOS.

In some environments it is necessary to segment the IOMMU Groups to be able to pass the GPU to the VM.

1. Add the content `pcie_acs_override=downstream,multifunction pci=nommconf` in the file `/etc/default/grub` at the end of the line `GRUB_CMDLINE_LINUX_DEFAULT`;
2. After changing the grub file, run the command `update-grub` and reboot your PVE.

---

## 🎥 Demonstration (in Portuguese)

📽️ [Watch on YouTube](https://youtu.be/dil6iRWiun0)  
*(Enable auto-translate captions for English subtitles!)*

---

## 🎖 Credits

- **OpenCore/Acidanthera Team** - Open-source bootloader
- **Corpnewt** - Tools (ProperTree, GenSMBIOS, etc.)
- **Apple** - macOS
- **Proxmox** - Fantastic virtualization platform & documentation

---

## 🌎 Join Our Community - Universo Hackintosh Discord

💬 [**Join Here!**](https://discord.universohackintosh.com.br)

