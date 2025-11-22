#!/bin/bash
# ORION Post-Deployment Validation Script
# Verifies all services are running correctly

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
PROXMOX_IP="192.168.100.10"
ROUTER_IP="192.168.100.1"
AI_AGENT_IP="192.168.100.20"
IDRAC_IP="192.168.1.2"

echo "=========================================="
echo "ORION Post-Deployment Validation"
echo "=========================================="
echo ""

CHECKS_PASSED=0
CHECKS_FAILED=0
CHECKS_WARNED=0

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

# Check 1: iDRAC accessibility
echo "[1/15] Checking iDRAC..."
if curl -k -s --connect-timeout 5 https://$IDRAC_IP &> /dev/null; then
    check_pass "iDRAC at $IDRAC_IP is accessible"
else
    check_fail "iDRAC not accessible"
fi

# Check 2: Proxmox web UI
echo "[2/15] Checking Proxmox..."
if curl -k -s --connect-timeout 5 https://$PROXMOX_IP:8006 &> /dev/null; then
    check_pass "Proxmox web UI at $PROXMOX_IP:8006 is accessible"
else
    check_fail "Proxmox web UI not accessible"
fi

# Check 3: Router reachability
echo "[3/15] Checking Router VM..."
if ping -c 3 -W 2 $ROUTER_IP &> /dev/null; then
    check_pass "Router VM at $ROUTER_IP is reachable"
else
    check_fail "Router VM not reachable"
fi

# Check 4: Router SSH
echo "[4/15] Checking Router SSH..."
if nc -z -w 2 $ROUTER_IP 22 2>/dev/null; then
    check_pass "Router SSH port is open"
else
    check_warn "Router SSH not accessible (may need SSH key setup)"
fi

# Check 5: Router DNS
echo "[5/15] Checking Router DNS..."
if nc -z -u -w 2 $ROUTER_IP 53 2>/dev/null; then
    check_pass "Router DNS service is running"
else
    check_warn "Router DNS not responding"
fi

# Check 6: DNS resolution
echo "[6/15] Testing DNS resolution..."
if dig @$ROUTER_IP google.com +short +timeout=5 &> /dev/null; then
    check_pass "DNS resolution working"
else
    check_warn "DNS resolution not working"
fi

# Check 7: BGP sessions (if router is accessible)
echo "[7/15] Checking BGP sessions..."
if command -v ssh &> /dev/null && ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no admin@$ROUTER_IP "birdc show protocols" 2>/dev/null | grep -q "Established"; then
    BGP_COUNT=$(ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no admin@$ROUTER_IP "birdc show protocols" 2>/dev/null | grep -c "Established" || echo "0")
    check_pass "BGP sessions established ($BGP_COUNT peers)"
else
    check_warn "Cannot check BGP sessions (SSH required)"
fi

# Check 8: AI Agent reachability
echo "[8/15] Checking AI Agent VM..."
if ping -c 3 -W 2 $AI_AGENT_IP &> /dev/null; then
    check_pass "AI Agent VM at $AI_AGENT_IP is reachable"
else
    check_fail "AI Agent VM not reachable"
fi

# Check 9: Prometheus
echo "[9/15] Checking Prometheus..."
if curl -s --connect-timeout 5 http://$AI_AGENT_IP:9090/-/ready &> /dev/null; then
    check_pass "Prometheus is running on $AI_AGENT_IP:9090"
else
    check_warn "Prometheus not accessible"
fi

# Check 10: Grafana
echo "[10/15] Checking Grafana..."
if curl -s --connect-timeout 5 http://$AI_AGENT_IP:3000/api/health | grep -q "ok"; then
    check_pass "Grafana is running on $AI_AGENT_IP:3000"
else
    check_warn "Grafana not accessible"
fi

# Check 11: Prometheus targets
echo "[11/15] Checking Prometheus targets..."
if curl -s --connect-timeout 5 "http://$AI_AGENT_IP:9090/api/v1/targets" | grep -q "up"; then
    TARGETS_UP=$(curl -s "http://$AI_AGENT_IP:9090/api/v1/targets" | grep -o '"health":"up"' | wc -l)
    check_pass "Prometheus monitoring $TARGETS_UP target(s)"
else
    check_warn "Cannot verify Prometheus targets"
fi

# Check 12: Internet connectivity through router
echo "[12/15] Checking internet connectivity..."
if ping -c 3 -W 5 8.8.8.8 &> /dev/null; then
    check_pass "Internet connectivity working"
else
    check_warn "No internet connectivity (check WAN configuration)"
fi

# Check 13: IPv6 connectivity
echo "[13/15] Checking IPv6 connectivity..."
if ping6 -c 3 -W 5 2001:4860:4860::8888 &> /dev/null; then
    check_pass "IPv6 connectivity working"
else
    check_warn "No IPv6 connectivity (may be expected)"
fi

# Check 14: AI Agent service
echo "[14/15] Checking AI Agent service..."
if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no admin@$AI_AGENT_IP "systemctl is-active orion-agent" 2>/dev/null | grep -q "active"; then
    check_pass "AI Agent service is running"
else
    check_warn "Cannot verify AI Agent service (SSH required)"
fi

# Check 15: Node exporters
echo "[15/15] Checking node exporters..."
EXPORTER_COUNT=0
for IP in $ROUTER_IP $AI_AGENT_IP $PROXMOX_IP; do
    if curl -s --connect-timeout 2 "http://$IP:9100/metrics" &> /dev/null; then
        ((EXPORTER_COUNT++))
    fi
done
if [ $EXPORTER_COUNT -gt 0 ]; then
    check_pass "Node exporters running ($EXPORTER_COUNT/3)"
else
    check_warn "No node exporters responding"
fi

echo ""
echo "=========================================="
echo "Validation Summary"
echo "=========================================="
echo -e "${GREEN}Passed:${NC} $CHECKS_PASSED"
echo -e "${YELLOW}Warnings:${NC} $CHECKS_WARNED"
echo -e "${RED}Failed:${NC} $CHECKS_FAILED"
echo ""

if [ $CHECKS_FAILED -eq 0 ] && [ $CHECKS_PASSED -ge 10 ]; then
    echo -e "${GREEN}✓ Deployment successful!${NC}"
    echo ""
    echo "Access Points:"
    echo "  - Proxmox:    https://$PROXMOX_IP:8006"
    echo "  - Grafana:    http://$AI_AGENT_IP:3000 (admin/orion2025)"
    echo "  - Prometheus: http://$AI_AGENT_IP:9090"
    echo "  - Router SSH: ssh admin@$ROUTER_IP"
    echo "  - iDRAC:      https://$IDRAC_IP"
    echo ""
    echo "Next steps:"
    echo "  1. Change Grafana password"
    echo "  2. Setup SSH keys for VMs"
    echo "  3. Configure backups"
    echo "  4. Review monitoring dashboards"
    echo ""
    exit 0
elif [ $CHECKS_FAILED -gt 0 ]; then
    echo -e "${RED}✗ Deployment has issues${NC}"
    echo ""
    echo "Troubleshooting:"
    echo "  - Check Proxmox VM status: qm list"
    echo "  - View VM console: qm console <vmid>"
    echo "  - Check VM logs in Proxmox web UI"
    echo "  - Verify network bridge configuration"
    echo "  - See ORION_HYBRID_ARCHITECTURE.md troubleshooting section"
    echo ""
    exit 1
else
    echo -e "${YELLOW}⚠ Deployment partially complete${NC}"
    echo ""
    echo "Some services are not yet accessible."
    echo "This may be normal if VMs are still starting up."
    echo "Wait 5 minutes and run this script again."
    echo ""
    exit 0
fi
