#!/bin/bash
# ORION Pre-Deployment Validation Script
# Checks all prerequisites before starting deployment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
IDRAC_IP="192.168.1.2"
REQUIRED_PYTHON_VERSION="3.8"

echo "=========================================="
echo "ORION Pre-Deployment Validation"
echo "=========================================="
echo ""

# Track overall status
CHECKS_PASSED=0
CHECKS_FAILED=0
CHECKS_WARNED=0

# Helper functions
check_pass() {
    echo -e "${GREEN}✓${NC} $1"
    ((CHECKS_PASSED++))
}

check_fail() {
    echo -e "${RED}✗${NC} $1"
    ((CHECKS_FAILED++))
}

check_warn() {
    echo -e "${YELLOW}⚠${NC} $1"
    ((CHECKS_WARNED++))
}

# Check 1: Python installation
echo "[1/10] Checking Python installation..."
if command -v python3 &> /dev/null; then
    PYTHON_VERSION=$(python3 --version | awk '{print $2}')
    PYTHON_MAJOR=$(echo $PYTHON_VERSION | cut -d. -f1)
    PYTHON_MINOR=$(echo $PYTHON_VERSION | cut -d. -f2)

    if [ "$PYTHON_MAJOR" -ge 3 ] && [ "$PYTHON_MINOR" -ge 8 ]; then
        check_pass "Python $PYTHON_VERSION installed"
    else
        check_fail "Python $PYTHON_VERSION is too old (need 3.8+)"
    fi
else
    check_fail "Python 3 not found"
fi

# Check 2: Python requests library
echo "[2/10] Checking Python dependencies..."
if python3 -c "import requests" 2>/dev/null; then
    check_pass "Python requests library installed"
else
    check_fail "Python requests library not installed (run: pip3 install requests)"
fi

# Check 3: Network connectivity to iDRAC
echo "[3/10] Checking iDRAC connectivity..."
if ping -c 1 -W 2 $IDRAC_IP &> /dev/null; then
    check_pass "iDRAC at $IDRAC_IP is reachable"

    # Try to connect to iDRAC HTTPS
    if curl -k -s --connect-timeout 5 https://$IDRAC_IP &> /dev/null; then
        check_pass "iDRAC HTTPS service responding"
    else
        check_warn "iDRAC HTTPS not responding (may need to wait for boot)"
    fi
else
    check_fail "Cannot reach iDRAC at $IDRAC_IP"
fi

# Check 4: Repository files
echo "[4/10] Checking repository files..."
REQUIRED_FILES=(
    "deploy-orion-hybrid.py"
    "orion-config.json"
    "vm-configs/router-vm/configuration.nix"
    "vm-configs/ai-agent-vm/configuration.nix"
    "vm-configs/ai-agent-vm/autonomous_agent.py"
)

for file in "${REQUIRED_FILES[@]}"; do
    if [ -f "$file" ]; then
        check_pass "Found $file"
    else
        check_fail "Missing $file"
    fi
done

# Check 5: Proxmox ISO availability
echo "[5/10] Checking for Proxmox ISO..."
if [ -f "/tmp/proxmox-ve.iso" ] || [ -f "$HOME/Downloads/proxmox-ve*.iso" ]; then
    check_pass "Proxmox ISO found locally"
else
    check_warn "Proxmox ISO not found (download from: https://www.proxmox.com/en/downloads)"
fi

# Check 6: NixOS ISO availability
echo "[6/10] Checking for NixOS ISO..."
if [ -f "/tmp/nixos-minimal.iso" ] || [ -f "$HOME/Downloads/nixos-*.iso" ]; then
    check_pass "NixOS ISO found locally"
else
    check_warn "NixOS ISO not found (will be downloaded during deployment)"
fi

# Check 7: Disk space
echo "[7/10] Checking available disk space..."
AVAILABLE_SPACE=$(df -BG . | tail -1 | awk '{print $4}' | sed 's/G//')
if [ "$AVAILABLE_SPACE" -gt 10 ]; then
    check_pass "Sufficient disk space ($AVAILABLE_SPACE GB available)"
else
    check_warn "Low disk space ($AVAILABLE_SPACE GB available, recommend 10GB+)"
fi

# Check 8: Git repository status
echo "[8/10] Checking git repository..."
if git rev-parse --git-dir > /dev/null 2>&1; then
    check_pass "Git repository initialized"

    # Check for uncommitted changes
    if git diff-index --quiet HEAD --; then
        check_pass "No uncommitted changes"
    else
        check_warn "You have uncommitted changes"
    fi
else
    check_warn "Not a git repository (optional)"
fi

# Check 9: SSH key availability
echo "[9/10] Checking SSH keys..."
if [ -f "$HOME/.ssh/id_rsa.pub" ] || [ -f "$HOME/.ssh/id_ed25519.pub" ]; then
    check_pass "SSH public key found"
else
    check_warn "No SSH public key found (generate with: ssh-keygen -t ed25519)"
fi

# Check 10: Network configuration
echo "[10/10] Checking network configuration..."
if ip route | grep -q "192.168.1.0/24"; then
    check_pass "Management network route configured"
else
    check_warn "No route to 192.168.1.0/24 (iDRAC network)"
fi

echo ""
echo "=========================================="
echo "Validation Summary"
echo "=========================================="
echo -e "${GREEN}Passed:${NC} $CHECKS_PASSED"
echo -e "${YELLOW}Warnings:${NC} $CHECKS_WARNED"
echo -e "${RED}Failed:${NC} $CHECKS_FAILED"
echo ""

if [ $CHECKS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ Ready for deployment!${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. Review QUICKSTART_HYBRID.md"
    echo "  2. Run: python3 deploy-orion-hybrid.py"
    echo ""
    exit 0
else
    echo -e "${RED}✗ Please resolve failed checks before deploying${NC}"
    echo ""
    echo "Common fixes:"
    echo "  - Install Python 3.8+: apt-get install python3"
    echo "  - Install requests: pip3 install requests"
    echo "  - Check network connectivity to iDRAC"
    echo "  - Ensure all repository files are present"
    echo ""
    exit 1
fi
