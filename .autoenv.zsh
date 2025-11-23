# ORION Auto-Environment
# Automatically loaded when entering this directory via zsh-autoenv
# See: https://github.com/Tarrasch/zsh-autoenv

# ============================================================================
# ORION Configuration Variables
# ============================================================================

export ORION_ROOT="$PWD"
export ORION_VERSION="2.0.0-hybrid"

# iDRAC Configuration
export IDRAC_IP="${IDRAC_IP:-192.168.1.2}"
export IDRAC_USER="${IDRAC_USER:-root}"
export IDRAC_PASS="${IDRAC_PASS:-calvin}"

# Proxmox Configuration
export PROXMOX_IP="${PROXMOX_IP:-192.168.100.10}"
export PROXMOX_PORT="${PROXMOX_PORT:-8006}"
export PROXMOX_USER="${PROXMOX_USER:-root@pam}"

# ORION Network Infrastructure
export ROUTER_IP="${ROUTER_IP:-192.168.100.1}"
export AI_AGENT_IP="${AI_AGENT_IP:-192.168.100.20}"
export MACOS_VM_IP="${MACOS_VM_IP:-192.168.100.50}"

# Service Ports
export GRAFANA_PORT="${GRAFANA_PORT:-3000}"
export PROMETHEUS_PORT="${PROMETHEUS_PORT:-9090}"
export NODE_EXPORTER_PORT="${NODE_EXPORTER_PORT:-9100}"

# BGP Configuration
export BGP_LOCAL_AS="${BGP_LOCAL_AS:-394955}"
export BGP_REMOTE_AS="${BGP_REMOTE_AS:-6939}"

# ============================================================================
# Python Virtual Environment
# ============================================================================

if [[ ! -d "$ORION_ROOT/.venv" ]]; then
    echo "📦 Creating Python virtual environment..."
    python3 -m venv "$ORION_ROOT/.venv"
    source "$ORION_ROOT/.venv/bin/activate"
    pip install --upgrade pip > /dev/null 2>&1
    pip install requests > /dev/null 2>&1
    echo "✓ Virtual environment created"
else
    source "$ORION_ROOT/.venv/bin/activate"
fi

# ============================================================================
# PATH Configuration
# ============================================================================

# Add ORION scripts to PATH
autoenv_prepend_path "$ORION_ROOT/scripts"
autoenv_prepend_path "$ORION_ROOT/tools"

# ============================================================================
# SSH Agent
# ============================================================================

# Start SSH agent if not running
if [[ -z "$SSH_AUTH_SOCK" ]]; then
    eval $(ssh-agent -s) > /dev/null 2>&1

    # Add SSH keys if available
    for key in ~/.ssh/id_{ed25519,rsa}; do
        if [[ -f "$key" ]]; then
            ssh-add "$key" 2>/dev/null
        fi
    done
fi

# ============================================================================
# Aliases
# ============================================================================

# Deployment
alias orion-deploy='python3 deploy-orion-hybrid.py'
alias orion-status='python3 deploy-orion-hybrid.py status'
alias orion-reboot='python3 deploy-orion-hybrid.py reboot'
alias orion-power-on='python3 deploy-orion-hybrid.py power-on'
alias orion-power-off='python3 deploy-orion-hybrid.py power-off'

# Validation
alias orion-pre-check='./scripts/pre-deployment-check.sh'
alias orion-post-check='./scripts/post-deployment-check.sh'
alias orion-validate='orion-post-check'

# SSH Access
alias ssh-router='ssh admin@$ROUTER_IP'
alias ssh-agent-vm='ssh admin@$AI_AGENT_IP'
alias ssh-macos='ssh admin@$MACOS_VM_IP'

# Web Services
alias grafana='open http://$AI_AGENT_IP:$GRAFANA_PORT'
alias prometheus='open http://$AI_AGENT_IP:$PROMETHEUS_PORT'
alias proxmox='open https://$PROXMOX_IP:$PROXMOX_PORT'
alias idrac='open https://$IDRAC_IP'

# Monitoring
alias orion-metrics='curl -s http://$AI_AGENT_IP:$PROMETHEUS_PORT/api/v1/targets | jq'
alias orion-bgp='ssh admin@$ROUTER_IP "birdc show protocols"'
alias orion-routes='ssh admin@$ROUTER_IP "birdc show route"'
alias orion-firewall='ssh admin@$ROUTER_IP "sudo nft list ruleset"'

# Logs
alias router-logs='ssh admin@$ROUTER_IP "sudo journalctl -f"'
alias agent-logs='ssh admin@$AI_AGENT_IP "sudo journalctl -u orion-agent -f"'
alias bird-logs='ssh admin@$ROUTER_IP "sudo journalctl -u bird2 -f"'

# Quick Actions
alias orion-restart-bgp='ssh admin@$ROUTER_IP "sudo systemctl restart bird2"'
alias orion-restart-agent='ssh admin@$AI_AGENT_IP "sudo systemctl restart orion-agent"'
alias orion-restart-grafana='ssh admin@$AI_AGENT_IP "sudo systemctl restart grafana"'

# Documentation
alias orion-docs='cat ORION_HYBRID_ARCHITECTURE.md | less'
alias orion-quickstart='cat QUICKSTART_HYBRID.md | less'
alias orion-checklist='cat DEPLOYMENT_CHECKLIST.md | less'

# VM Management (Proxmox CLI - if available)
if command -v qm &> /dev/null; then
    alias vm-list='qm list'
    alias vm-router='qm console 200'
    alias vm-agent='qm console 300'
    alias vm-macos='qm console 100'
    alias vm-start-router='qm start 200'
    alias vm-start-agent='qm start 300'
    alias vm-start-macos='qm start 100'
fi

# ============================================================================
# Functions
# ============================================================================

# Show ORION status overview
orion-overview() {
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🚀 ORION Hybrid Infrastructure - Status Overview"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # Check iDRAC
    if ping -c 1 -W 1 $IDRAC_IP &> /dev/null; then
        echo "✓ iDRAC:      $IDRAC_IP (reachable)"
    else
        echo "✗ iDRAC:      $IDRAC_IP (unreachable)"
    fi

    # Check Proxmox
    if ping -c 1 -W 1 $PROXMOX_IP &> /dev/null; then
        echo "✓ Proxmox:    https://$PROXMOX_IP:$PROXMOX_PORT (reachable)"
    else
        echo "✗ Proxmox:    https://$PROXMOX_IP:$PROXMOX_PORT (unreachable)"
    fi

    # Check Router
    if ping -c 1 -W 1 $ROUTER_IP &> /dev/null; then
        echo "✓ Router:     $ROUTER_IP (reachable)"
    else
        echo "✗ Router:     $ROUTER_IP (unreachable)"
    fi

    # Check AI Agent
    if ping -c 1 -W 1 $AI_AGENT_IP &> /dev/null; then
        echo "✓ AI Agent:   $AI_AGENT_IP (reachable)"
    else
        echo "✗ AI Agent:   $AI_AGENT_IP (unreachable)"
    fi

    # Check Grafana
    if curl -s --connect-timeout 2 http://$AI_AGENT_IP:$GRAFANA_PORT/api/health &> /dev/null; then
        echo "✓ Grafana:    http://$AI_AGENT_IP:$GRAFANA_PORT (running)"
    else
        echo "✗ Grafana:    http://$AI_AGENT_IP:$GRAFANA_PORT (not running)"
    fi

    # Check Prometheus
    if curl -s --connect-timeout 2 http://$AI_AGENT_IP:$PROMETHEUS_PORT/-/ready &> /dev/null; then
        echo "✓ Prometheus: http://$AI_AGENT_IP:$PROMETHEUS_PORT (running)"
    else
        echo "✗ Prometheus: http://$AI_AGENT_IP:$PROMETHEUS_PORT (not running)"
    fi

    echo ""
    echo "Quick Commands:"
    echo "  orion-deploy      - Deploy ORION infrastructure"
    echo "  orion-validate    - Run post-deployment validation"
    echo "  orion-help        - Show all available commands"
    echo ""
}

# Show help
orion-help() {
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🚀 ORION Helper Commands"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "📦 DEPLOYMENT:"
    echo "  orion-deploy           Deploy ORION infrastructure"
    echo "  orion-status           Check system power status"
    echo "  orion-power-on         Power on system via iDRAC"
    echo "  orion-power-off        Power off system via iDRAC"
    echo "  orion-reboot           Reboot system via iDRAC"
    echo ""
    echo "✅ VALIDATION:"
    echo "  orion-pre-check        Run pre-deployment checks"
    echo "  orion-post-check       Run post-deployment validation"
    echo "  orion-validate         Alias for orion-post-check"
    echo "  orion-overview         Show quick status overview"
    echo ""
    echo "🔌 SSH ACCESS:"
    echo "  ssh-router             SSH to Router VM"
    echo "  ssh-agent-vm           SSH to AI Agent VM"
    echo "  ssh-macos              SSH to macOS VM"
    echo ""
    echo "🌐 WEB SERVICES:"
    echo "  proxmox                Open Proxmox web UI"
    echo "  grafana                Open Grafana dashboard"
    echo "  prometheus             Open Prometheus"
    echo "  idrac                  Open iDRAC console"
    echo ""
    echo "📊 MONITORING:"
    echo "  orion-metrics          Show Prometheus targets"
    echo "  orion-bgp              Show BGP status"
    echo "  orion-routes           Show routing table"
    echo "  orion-firewall         Show firewall rules"
    echo ""
    echo "📝 LOGS:"
    echo "  router-logs            Stream router logs"
    echo "  agent-logs             Stream AI agent logs"
    echo "  bird-logs              Stream BGP logs"
    echo ""
    echo "🔧 QUICK ACTIONS:"
    echo "  orion-restart-bgp      Restart BGP service"
    echo "  orion-restart-agent    Restart AI agent"
    echo "  orion-restart-grafana  Restart Grafana"
    echo ""
    echo "📚 DOCUMENTATION:"
    echo "  orion-docs             View architecture docs"
    echo "  orion-quickstart       View quick start guide"
    echo "  orion-checklist        View deployment checklist"
    echo ""
    echo "Environment Variables:"
    echo "  ORION_ROOT:      $ORION_ROOT"
    echo "  IDRAC_IP:        $IDRAC_IP"
    echo "  PROXMOX_IP:      $PROXMOX_IP"
    echo "  ROUTER_IP:       $ROUTER_IP"
    echo "  AI_AGENT_IP:     $AI_AGENT_IP"
    echo ""
}

# Quick network test
orion-test() {
    echo "🧪 Testing ORION connectivity..."
    echo ""

    echo -n "iDRAC:     "
    if ping -c 1 -W 1 $IDRAC_IP &> /dev/null; then
        echo "✓"
    else
        echo "✗"
    fi

    echo -n "Proxmox:   "
    if ping -c 1 -W 1 $PROXMOX_IP &> /dev/null; then
        echo "✓"
    else
        echo "✗"
    fi

    echo -n "Router:    "
    if ping -c 1 -W 1 $ROUTER_IP &> /dev/null; then
        echo "✓"
    else
        echo "✗"
    fi

    echo -n "AI Agent:  "
    if ping -c 1 -W 1 $AI_AGENT_IP &> /dev/null; then
        echo "✓"
    else
        echo "✗"
    fi

    echo ""
}

# ============================================================================
# Welcome Message
# ============================================================================

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🚀 ORION Hybrid Infrastructure Environment"
echo "   Version: $ORION_VERSION"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Infrastructure:"
echo "  🔧 iDRAC:     $IDRAC_IP"
echo "  🖥  Proxmox:   $PROXMOX_IP"
echo "  🌐 Router:    $ROUTER_IP"
echo "  🤖 AI Agent:  $AI_AGENT_IP"
echo ""
echo "Quick Start:"
echo "  orion-help      Show all available commands"
echo "  orion-overview  Show system status"
echo "  orion-deploy    Deploy infrastructure"
echo ""

# Auto-run overview if deployed
if ping -c 1 -W 1 $ROUTER_IP &> /dev/null 2>&1; then
    orion-overview
fi
