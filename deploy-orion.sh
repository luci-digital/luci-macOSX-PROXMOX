#!/bin/bash

#########################################################################################################################
#
# Script: deploy-orion.sh
# Purpose: Deploy Proxmox with macOS support on Dell R730 ORION
# Description: Automated deployment script for integrating OSX-PROXMOX with Dell PowerEdge R730 CQ5QBM2
#
# Usage: ./deploy-orion.sh [OPTIONS]
# Options:
#   --install-proxmox     Install and configure Proxmox VE base system
#   --configure-network   Configure network bridges for routing and VMs
#   --install-osx         Install OSX-PROXMOX for macOS support
#   --create-router-vm    Create and configure router VM (pfSense)
#   --create-macos-vm     Create macOS Sequoia VM
#   --full-deploy         Execute all deployment steps
#   --help                Display this help message
#
#########################################################################################################################

# Exit on any error
set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="/var/log/orion-deploy"
LOG_FILE="${LOG_DIR}/deploy-$(date +%Y%m%d-%H%M%S).log"
CONFIG_FILE="${SCRIPT_DIR}/orion-config.json"

# Dell R730 ORION Specifications
DELL_SERVICE_TAG="CQ5QBM2"
TOTAL_CPU_CORES=56
TOTAL_RAM_GB=384
TOTAL_NICS=8

# Network Interface Mapping (Dell R730 specific)
WAN_INTERFACE="eno3"           # D0:94:66:24:96:7E - 10GbE
LAN_INTERFACE="eno4"           # D0:94:66:24:96:80 - 10GbE
MACOS_INTERFACE="eno5"         # 10GbE
STORAGE_INTERFACE="eno6"       # 10GbE
MGMT_INTERFACE="eno1"          # 1GbE - Proxmox management

# Network Configuration
PROXMOX_IP="192.168.100.10"
PROXMOX_GATEWAY="192.168.100.1"
PROXMOX_NETMASK="24"
PROXMOX_DNS="1.1.1.1 8.8.8.8"

# Telus BGP Configuration
TELUS_AS="6939"
LOCAL_AS="394955"
TELUS_GATEWAY1="206.75.1.127"
TELUS_GATEWAY2="206.75.1.47"
TELUS_GATEWAY3="206.75.1.48"
IPV6_PREFIX="2602:F674::/48"

# VM Configuration
ROUTER_VM_ID=200
ROUTER_VM_NAME="ORION-Router"
ROUTER_CPU_CORES=8
ROUTER_RAM_GB=32
ROUTER_DISK_GB=50

MACOS_VM_ID=100
MACOS_VM_NAME="HACK-Sequoia-01"
MACOS_CPU_CORES=12
MACOS_RAM_GB=64
MACOS_DISK_GB=256

# Functions

log() {
    local level=$1
    shift
    local message="$@"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    case $level in
        INFO)
            echo -e "${BLUE}[INFO]${NC} $message" | tee -a "$LOG_FILE"
            ;;
        SUCCESS)
            echo -e "${GREEN}[SUCCESS]${NC} $message" | tee -a "$LOG_FILE"
            ;;
        WARNING)
            echo -e "${YELLOW}[WARNING]${NC} $message" | tee -a "$LOG_FILE"
            ;;
        ERROR)
            echo -e "${RED}[ERROR]${NC} $message" | tee -a "$LOG_FILE"
            ;;
    esac

    echo "${timestamp} [${level}] ${message}" >> "$LOG_FILE"
}

check_root() {
    if [ "$EUID" -ne 0 ]; then
        log ERROR "This script must be run as root"
        exit 1
    fi
}

check_hardware() {
    log INFO "Validating Dell R730 hardware..."

    # Check if running on Dell hardware
    if command -v dmidecode >/dev/null 2>&1; then
        local system_manufacturer=$(dmidecode -s system-manufacturer 2>/dev/null)
        local system_product=$(dmidecode -s system-product-name 2>/dev/null)
        local service_tag=$(dmidecode -s system-serial-number 2>/dev/null)

        log INFO "System Manufacturer: $system_manufacturer"
        log INFO "System Product: $system_product"
        log INFO "Service Tag: $service_tag"

        if [[ ! "$system_manufacturer" =~ "Dell" ]]; then
            log WARNING "Not running on Dell hardware. Proceeding anyway..."
        fi

        if [[ "$service_tag" != "$DELL_SERVICE_TAG" ]]; then
            log WARNING "Service tag mismatch. Expected: $DELL_SERVICE_TAG, Got: $service_tag"
            log WARNING "Proceeding anyway, but configuration may need adjustment."
        fi
    else
        log WARNING "dmidecode not available. Skipping hardware validation."
    fi

    # Check CPU cores
    local cpu_cores=$(nproc)
    log INFO "Detected CPU cores: $cpu_cores"

    if [ "$cpu_cores" -lt 28 ]; then
        log WARNING "Expected $TOTAL_CPU_CORES cores, found $cpu_cores. Configuration may need adjustment."
    fi

    # Check RAM
    local total_ram_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    local total_ram_gb=$((total_ram_kb / 1024 / 1024))
    log INFO "Detected RAM: ${total_ram_gb}GB"

    if [ "$total_ram_gb" -lt 256 ]; then
        log WARNING "Expected ${TOTAL_RAM_GB}GB RAM, found ${total_ram_gb}GB. Configuration may need adjustment."
    fi

    # Check network interfaces
    local nic_count=$(ip link show | grep -c "^[0-9].*: en")
    log INFO "Detected network interfaces: $nic_count"

    log SUCCESS "Hardware validation complete"
}

check_proxmox() {
    log INFO "Checking Proxmox VE installation..."

    if ! command -v pveversion >/dev/null 2>&1; then
        log ERROR "Proxmox VE not detected. Please install Proxmox VE first."
        log INFO "Visit: https://www.proxmox.com/en/downloads/proxmox-virtual-environment/iso"
        exit 1
    fi

    local pve_version=$(pveversion | grep "pve-manager" | awk '{print $2}')
    log INFO "Proxmox VE version: $pve_version"

    # Check if version is 7.0 or higher
    local major_version=$(echo $pve_version | cut -d'/' -f1 | cut -d'.' -f1)
    if [ "$major_version" -lt 7 ]; then
        log WARNING "Proxmox VE version $pve_version is older than recommended (7.0+)"
    fi

    log SUCCESS "Proxmox VE installation verified"
}

configure_repositories() {
    log INFO "Configuring Proxmox repositories..."

    # Remove enterprise repositories
    if [ -f /etc/apt/sources.list.d/pve-enterprise.list ]; then
        log INFO "Removing enterprise repository..."
        rm -f /etc/apt/sources.list.d/pve-enterprise.list
    fi

    if [ -f /etc/apt/sources.list.d/pve-enterprise.sources ]; then
        rm -f /etc/apt/sources.list.d/pve-enterprise.sources
    fi

    if [ -f /etc/apt/sources.list.d/ceph.list ]; then
        rm -f /etc/apt/sources.list.d/ceph.list
    fi

    if [ -f /etc/apt/sources.list.d/ceph.sources ]; then
        rm -f /etc/apt/sources.list.d/ceph.sources
    fi

    # Add no-subscription repository
    log INFO "Adding no-subscription repository..."
    cat > /etc/apt/sources.list.d/pve-no-subscription.list <<EOF
deb http://download.proxmox.com/debian/pve bookworm pve-no-subscription
EOF

    # Update package lists
    log INFO "Updating package lists..."
    apt-get update >> "$LOG_FILE" 2>&1

    log SUCCESS "Repositories configured"
}

install_packages() {
    log INFO "Installing required packages..."

    local packages=(
        "git" "curl" "wget" "vim" "tmux" "htop" "iotop"
        "net-tools" "bridge-utils" "vlan" "ifenslave"
        "ethtool" "smartmontools" "lm-sensors"
        "iperf3" "tcpdump" "nmap" "mtr"
        "jq" "bc" "pv" "rsync"
        "python3-pip" "build-essential"
    )

    for package in "${packages[@]}"; do
        if ! dpkg -l | grep -q "^ii  $package"; then
            log INFO "Installing $package..."
            apt-get install -y "$package" >> "$LOG_FILE" 2>&1
        else
            log INFO "$package already installed"
        fi
    done

    log SUCCESS "Packages installed"
}

configure_network_bridges() {
    log INFO "Configuring network bridges..."

    # Backup existing configuration
    if [ -f /etc/network/interfaces ]; then
        log INFO "Backing up existing network configuration..."
        cp /etc/network/interfaces /etc/network/interfaces.backup-$(date +%Y%m%d-%H%M%S)
    fi

    # Create new network configuration
    log INFO "Creating network bridge configuration..."
    cat > /etc/network/interfaces <<EOF
# /etc/network/interfaces
# Deployed by ORION automation script
# Generated: $(date)

auto lo
iface lo inet loopback

# Management Interface (Proxmox Web UI)
auto ${MGMT_INTERFACE}
iface ${MGMT_INTERFACE} inet static
    address ${PROXMOX_IP}/${PROXMOX_NETMASK}
    gateway ${PROXMOX_GATEWAY}
    dns-nameservers ${PROXMOX_DNS}
    # Dell iDRAC management

# WAN Bridge (for Router VM) - ${WAN_INTERFACE} (D0:94:66:24:96:7E)
auto vmbr0
iface vmbr0 inet manual
    bridge-ports ${WAN_INTERFACE}
    bridge-stp off
    bridge-fd 0
    bridge-vlan-aware yes
    # WAN interface for Router VM - Telus Fiber connection

# LAN Bridge (Internal Network) - ${LAN_INTERFACE} (D0:94:66:24:96:80)
auto vmbr1
iface vmbr1 inet static
    address ${PROXMOX_GATEWAY}/${PROXMOX_NETMASK}
    bridge-ports ${LAN_INTERFACE}
    bridge-stp off
    bridge-fd 0
    bridge-vlan-aware yes
    # LAN interface for all VMs - Internal network

# macOS VM Bridge (Dedicated 10GbE) - ${MACOS_INTERFACE}
auto vmbr2
iface vmbr2 inet manual
    bridge-ports ${MACOS_INTERFACE}
    bridge-stp off
    bridge-fd 0
    # Dedicated network for macOS VMs (high performance)

# Storage/Backup Bridge - ${STORAGE_INTERFACE}
auto vmbr3
iface vmbr3 inet manual
    bridge-ports ${STORAGE_INTERFACE}
    bridge-stp off
    bridge-fd 0
    # Storage network (NFS, iSCSI, backup targets)
EOF

    log SUCCESS "Network bridge configuration created"
    log WARNING "Network configuration has been updated. A reboot is required to apply changes."
    log INFO "To apply now without reboot (may interrupt network): systemctl restart networking"
}

verify_network() {
    log INFO "Verifying network configuration..."

    # Check if bridges exist
    for bridge in vmbr0 vmbr1 vmbr2 vmbr3; do
        if ip link show "$bridge" >/dev/null 2>&1; then
            log SUCCESS "Bridge $bridge exists"

            # Show bridge members
            local members=$(bridge link show | grep "$bridge" | awk '{print $2}' | cut -d'@' -f1 | tr '\n' ' ')
            log INFO "  Members: $members"
        else
            log WARNING "Bridge $bridge does not exist (may need reboot)"
        fi
    done

    # Check internet connectivity
    if ping -c 3 1.1.1.1 >/dev/null 2>&1; then
        log SUCCESS "Internet connectivity verified"
    else
        log WARNING "No internet connectivity detected"
    fi
}

install_osx_proxmox() {
    log INFO "Installing OSX-PROXMOX..."

    # Run the official installer
    log INFO "Running OSX-PROXMOX installer from https://install.osx-proxmox.com"

    if /bin/bash -c "$(curl -fsSL https://install.osx-proxmox.com)" >> "$LOG_FILE" 2>&1; then
        log SUCCESS "OSX-PROXMOX installed successfully"
    else
        log ERROR "OSX-PROXMOX installation failed. Check log: $LOG_FILE"
        exit 1
    fi
}

create_router_vm() {
    log INFO "Creating router VM (pfSense)..."

    # Check if VM already exists
    if qm status "$ROUTER_VM_ID" >/dev/null 2>&1; then
        log WARNING "VM $ROUTER_VM_ID already exists. Skipping creation."
        return 0
    fi

    # Download pfSense ISO if not present
    local pfsense_iso="/var/lib/vz/template/iso/pfSense-CE-2.7.2-RELEASE-amd64.iso"
    if [ ! -f "$pfsense_iso" ]; then
        log INFO "Downloading pfSense ISO..."
        cd /var/lib/vz/template/iso/
        wget -q --show-progress \
            https://sgpfiles.netgate.com/mirror/downloads/pfSense-CE-2.7.2-RELEASE-amd64.iso.gz \
            -O pfSense-CE-2.7.2-RELEASE-amd64.iso.gz
        gunzip pfSense-CE-2.7.2-RELEASE-amd64.iso.gz
        log SUCCESS "pfSense ISO downloaded"
    else
        log INFO "pfSense ISO already present"
    fi

    # Create VM
    log INFO "Creating VM $ROUTER_VM_ID ($ROUTER_VM_NAME)..."
    qm create "$ROUTER_VM_ID" \
        --name "$ROUTER_VM_NAME" \
        --memory $((ROUTER_RAM_GB * 1024)) \
        --cores "$ROUTER_CPU_CORES" \
        --cpu host \
        --sockets 1 \
        --numa 1 \
        --ostype other \
        --boot order='ide2;scsi0' \
        --ide2 local:iso/pfSense-CE-2.7.2-RELEASE-amd64.iso,media=cdrom \
        --scsi0 local-lvm:${ROUTER_DISK_GB},cache=writeback,discard=on,ssd=1 \
        --scsihw virtio-scsi-pci \
        --net0 virtio,bridge=vmbr0,firewall=0 \
        --net1 virtio,bridge=vmbr1,firewall=0 \
        --net2 virtio,bridge=vmbr2,firewall=0 \
        --net3 virtio,bridge=vmbr3,firewall=0 \
        --agent 1 \
        --onboot 1 \
        --startup order=1,up=30 \
        >> "$LOG_FILE" 2>&1

    log SUCCESS "Router VM created (ID: $ROUTER_VM_ID)"
    log INFO "To complete setup:"
    log INFO "  1. Start VM: qm start $ROUTER_VM_ID"
    log INFO "  2. Open console: Access via Proxmox web UI"
    log INFO "  3. Install pfSense and configure interfaces"
    log INFO "  4. Configure BGP with Telus gateways"
}

create_macos_vm() {
    log INFO "Creating macOS VM..."

    # Check if VM already exists
    if qm status "$MACOS_VM_ID" >/dev/null 2>&1; then
        log WARNING "VM $MACOS_VM_ID already exists. Skipping creation."
        return 0
    fi

    # This requires OSX-PROXMOX to be installed first
    if [ ! -d "/root/OSX-PROXMOX" ]; then
        log ERROR "OSX-PROXMOX not installed. Run --install-osx first."
        exit 1
    fi

    log INFO "Launching OSX-PROXMOX setup wizard..."
    log INFO "Please follow the interactive prompts to create macOS VM."
    log INFO "Recommended settings:"
    log INFO "  - macOS Version: Sequoia (15)"
    log INFO "  - VM ID: $MACOS_VM_ID"
    log INFO "  - VM Name: $MACOS_VM_NAME"
    log INFO "  - CPU Cores: $MACOS_CPU_CORES"
    log INFO "  - RAM: ${MACOS_RAM_GB}GB"
    log INFO "  - Disk Size: ${MACOS_DISK_GB}GB"
    log INFO "  - Network Bridge: vmbr2"

    # Run the setup script
    /root/OSX-PROXMOX/setup

    log SUCCESS "macOS VM creation wizard completed"
}

generate_summary() {
    log INFO "========================================"
    log INFO "ORION Deployment Summary"
    log INFO "========================================"
    log INFO ""
    log INFO "Hardware:"
    log INFO "  Dell PowerEdge R730 (Service Tag: $DELL_SERVICE_TAG)"
    log INFO "  CPU: $TOTAL_CPU_CORES cores"
    log INFO "  RAM: ${TOTAL_RAM_GB}GB"
    log INFO "  NICs: $TOTAL_NICS x 10GbE/1GbE"
    log INFO ""
    log INFO "Proxmox VE:"
    log INFO "  Management IP: https://${PROXMOX_IP}:8006"
    log INFO "  Default credentials: root / (password set during install)"
    log INFO ""
    log INFO "Network Bridges:"
    log INFO "  vmbr0: WAN (${WAN_INTERFACE}) - Router VM"
    log INFO "  vmbr1: LAN (${LAN_INTERFACE}) - Internal network"
    log INFO "  vmbr2: macOS (${MACOS_INTERFACE}) - macOS VMs"
    log INFO "  vmbr3: Storage (${STORAGE_INTERFACE}) - Storage network"
    log INFO ""
    log INFO "Virtual Machines:"
    log INFO "  VM $ROUTER_VM_ID: $ROUTER_VM_NAME (${ROUTER_CPU_CORES} cores, ${ROUTER_RAM_GB}GB RAM)"
    log INFO "  VM $MACOS_VM_ID: $MACOS_VM_NAME (${MACOS_CPU_CORES} cores, ${MACOS_RAM_GB}GB RAM)"
    log INFO ""
    log INFO "Telus BGP Configuration:"
    log INFO "  Local AS: $LOCAL_AS"
    log INFO "  Telus AS: $TELUS_AS"
    log INFO "  Gateway 1: $TELUS_GATEWAY1"
    log INFO "  Gateway 2: $TELUS_GATEWAY2"
    log INFO "  Gateway 3: $TELUS_GATEWAY3"
    log INFO "  IPv6 Prefix: $IPV6_PREFIX"
    log INFO ""
    log INFO "Next Steps:"
    log INFO "  1. Configure pfSense router (VM $ROUTER_VM_ID)"
    log INFO "  2. Setup BGP peering with Telus gateways"
    log INFO "  3. Install macOS on VM $MACOS_VM_ID"
    log INFO "  4. Configure monitoring and backups"
    log INFO ""
    log INFO "Documentation:"
    log INFO "  ${SCRIPT_DIR}/DELL_R730_ORION_PROXMOX_INTEGRATION.md"
    log INFO ""
    log INFO "Logs:"
    log INFO "  $LOG_FILE"
    log INFO ""
    log INFO "========================================"
}

show_help() {
    cat <<EOF
ORION Deployment Script for Dell R730 with Proxmox and macOS

Usage: $0 [OPTIONS]

Options:
    --install-proxmox     Install and configure Proxmox VE base system
    --configure-network   Configure network bridges for routing and VMs
    --install-osx         Install OSX-PROXMOX for macOS support
    --create-router-vm    Create and configure router VM (pfSense)
    --create-macos-vm     Create macOS Sequoia VM
    --full-deploy         Execute all deployment steps (except Proxmox install)
    --verify              Verify system configuration and health
    --help                Display this help message

Examples:
    # Full automated deployment (after Proxmox is installed)
    $0 --full-deploy

    # Configure network only
    $0 --configure-network

    # Create router VM only
    $0 --create-router-vm

    # Verify existing deployment
    $0 --verify

Notes:
    - This script must be run on a Proxmox VE host
    - Proxmox VE must be installed before running this script
    - Root/sudo access is required
    - Internet connectivity is required for package downloads

Hardware:
    - Dell PowerEdge R730 (Service Tag: CQ5QBM2)
    - 2x Intel Xeon E5-2690 v4 (56 cores total)
    - 384GB RAM
    - 8x Network Interfaces (4x10GbE + 2x1GbE + 2x10GbE)

Documentation:
    See DELL_R730_ORION_PROXMOX_INTEGRATION.md for complete guide

EOF
}

main() {
    # Create log directory
    mkdir -p "$LOG_DIR"

    log INFO "========================================"
    log INFO "ORION Deployment Script Starting"
    log INFO "========================================"
    log INFO "Timestamp: $(date)"
    log INFO "Script: $0"
    log INFO "Arguments: $@"
    log INFO "Log file: $LOG_FILE"
    log INFO ""

    # Parse arguments
    if [ $# -eq 0 ]; then
        show_help
        exit 0
    fi

    case "$1" in
        --install-proxmox)
            log ERROR "Proxmox installation must be done manually using ISO installer"
            log INFO "Download from: https://www.proxmox.com/en/downloads/proxmox-virtual-environment/iso"
            log INFO "After Proxmox is installed, run: $0 --full-deploy"
            exit 1
            ;;

        --configure-network)
            check_root
            check_proxmox
            configure_network_bridges
            verify_network
            ;;

        --install-osx)
            check_root
            check_proxmox
            install_osx_proxmox
            ;;

        --create-router-vm)
            check_root
            check_proxmox
            create_router_vm
            ;;

        --create-macos-vm)
            check_root
            check_proxmox
            create_macos_vm
            ;;

        --full-deploy)
            check_root
            check_hardware
            check_proxmox
            configure_repositories
            install_packages
            configure_network_bridges

            log INFO ""
            log WARNING "Network configuration complete. Restarting networking..."
            log WARNING "This may temporarily interrupt network connectivity."
            read -p "Continue? (y/n) " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                systemctl restart networking
                sleep 5
                verify_network
            else
                log INFO "Skipping network restart. Please restart manually: systemctl restart networking"
            fi

            install_osx_proxmox
            create_router_vm

            log INFO ""
            log INFO "Would you like to create a macOS VM now?"
            read -p "Create macOS VM? (y/n) " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                create_macos_vm
            else
                log INFO "Skipping macOS VM creation. Run later with: $0 --create-macos-vm"
            fi

            generate_summary
            ;;

        --verify)
            check_root
            check_hardware
            check_proxmox
            verify_network

            log INFO ""
            log INFO "Checking VMs..."
            if qm status "$ROUTER_VM_ID" >/dev/null 2>&1; then
                local router_status=$(qm status "$ROUTER_VM_ID" | awk '{print $2}')
                log INFO "Router VM ($ROUTER_VM_ID): $router_status"
            else
                log WARNING "Router VM ($ROUTER_VM_ID) not found"
            fi

            if qm status "$MACOS_VM_ID" >/dev/null 2>&1; then
                local macos_status=$(qm status "$MACOS_VM_ID" | awk '{print $2}')
                log INFO "macOS VM ($MACOS_VM_ID): $macos_status"
            else
                log WARNING "macOS VM ($MACOS_VM_ID) not found"
            fi
            ;;

        --help|-h)
            show_help
            ;;

        *)
            log ERROR "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac

    log INFO ""
    log SUCCESS "Operation completed successfully"
    log INFO "========================================"
}

# Run main function
main "$@"
