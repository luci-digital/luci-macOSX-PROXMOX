#!/bin/bash

#########################################################################################################################
#
# Script: install-orion-services.sh
# Purpose: Install ORION monitoring and automation services
# Description: Deploys systemd services and scripts for ORION deployment
#
#########################################################################################################################

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    local level=$1
    shift
    case $level in
        INFO)    echo -e "${BLUE}[INFO]${NC} $@" ;;
        SUCCESS) echo -e "${GREEN}[SUCCESS]${NC} $@" ;;
        WARNING) echo -e "${YELLOW}[WARNING]${NC} $@" ;;
        ERROR)   echo -e "${RED}[ERROR]${NC} $@" ;;
    esac
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    log ERROR "This script must be run as root"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(dirname "$SCRIPT_DIR")"

log INFO "Installing ORION services..."
log INFO "Script directory: $SCRIPT_DIR"
log INFO "Parent directory: $PARENT_DIR"

# 1. Copy scripts to /usr/local/bin
log INFO "Installing monitoring scripts to /usr/local/bin..."
cp "$SCRIPT_DIR/orion-gateway-monitor" /usr/local/bin/
cp "$SCRIPT_DIR/orion-bgp-monitor" /usr/local/bin/
cp "$SCRIPT_DIR/orion-vm-watchdog" /usr/local/bin/
cp "$SCRIPT_DIR/orion-performance-tuning" /usr/local/bin/

chmod +x /usr/local/bin/orion-gateway-monitor
chmod +x /usr/local/bin/orion-bgp-monitor
chmod +x /usr/local/bin/orion-vm-watchdog
chmod +x /usr/local/bin/orion-performance-tuning

log SUCCESS "Scripts installed"

# 2. Copy systemd service files
log INFO "Installing systemd service files..."
cp "$PARENT_DIR/systemd/"*.service /etc/systemd/system/

# 3. Create log directory
mkdir -p /var/log/orion
mkdir -p /var/run/orion

log SUCCESS "Log directories created"

# 4. Reload systemd
log INFO "Reloading systemd daemon..."
systemctl daemon-reload

# 5. Enable services (but don't start yet)
log INFO "Enabling ORION services..."
systemctl enable orion-performance-tuning.service
systemctl enable orion-gateway-monitor.service
systemctl enable orion-bgp-monitor.service
systemctl enable orion-vm-watchdog.service

log SUCCESS "Services enabled"

# 6. Start performance tuning (one-time)
log INFO "Running performance tuning..."
systemctl start orion-performance-tuning.service

log SUCCESS "Performance tuning complete"

# 7. Show status
log INFO ""
log INFO "Service Status:"
log INFO "==============="
systemctl status orion-performance-tuning.service --no-pager || true
echo ""

# 8. Instructions
log INFO ""
log INFO "ORION services have been installed and enabled."
log INFO ""
log INFO "To start monitoring services:"
log INFO "  systemctl start orion-gateway-monitor.service"
log INFO "  systemctl start orion-bgp-monitor.service"
log INFO "  systemctl start orion-vm-watchdog.service"
log INFO ""
log INFO "To view logs:"
log INFO "  journalctl -u orion-gateway-monitor -f"
log INFO "  journalctl -u orion-bgp-monitor -f"
log INFO "  journalctl -u orion-vm-watchdog -f"
log INFO ""
log INFO "Log files are located in: /var/log/orion/"
log INFO "State files are located in: /var/run/orion/"
log INFO ""
log SUCCESS "Installation complete!"

exit 0
