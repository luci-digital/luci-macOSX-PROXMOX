#!/bin/bash
#
# IPv6 Routing Deployment Script for ORION Router VM
# Configures BGP, Router Advertisements, and IPv6 firewall
#
# Run this script on Router VM (200) after base OS installation
#

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
IPV6_PREFIX="2602:F674::/48"
LOCAL_AS="394955"
REMOTE_AS="6939"
ROUTER_IP_LAN="2602:F674:1000::1"
ROUTER_IP_WAN="2602:F674:0000::1"

# Functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_banner() {
    cat << "EOF"
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║          IPv6 BGP Routing Deployment - ORION Router           ║
║                                                               ║
║  AS Number: 394955                                            ║
║  IPv6 Prefix: 2602:F674::/48                                  ║
║  Upstream: Telus (AS6939)                                     ║
║                                                               ║
║  Components:                                                  ║
║    • BIRD2 (BGP routing daemon)                               ║
║    • radvd (Router Advertisement daemon)                      ║
║    • nftables (IPv6 firewall)                                 ║
║    • Network interface configuration                          ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
EOF
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        exit 1
    fi
}

check_prerequisites() {
    log_info "Checking prerequisites..."

    # Check if we're on the router VM
    HOSTNAME=$(hostname)
    if [[ ! "$HOSTNAME" =~ "router" ]] && [[ ! "$HOSTNAME" =~ "ORION" ]]; then
        log_warn "Hostname doesn't match expected router name. Continue anyway? (y/N)"
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi

    # Check network interfaces
    for iface in eth0 eth1 eth2 eth3; do
        if ip link show "$iface" &> /dev/null; then
            log_success "Interface $iface found"
        else
            log_warn "Interface $iface not found"
        fi
    done

    log_success "Prerequisites check complete"
}

install_packages() {
    log_info "Installing required packages..."

    # Update package list
    apt-get update

    # Install packages
    PACKAGES="bird2 radvd nftables tcpdump net-tools iputils-ping dnsutils"

    for pkg in $PACKAGES; do
        if dpkg -l | grep -q "^ii  $pkg "; then
            log_info "$pkg already installed"
        else
            log_info "Installing $pkg..."
            apt-get install -y "$pkg"
        fi
    done

    log_success "Packages installed"
}

configure_sysctl() {
    log_info "Configuring kernel parameters for IPv6..."

    # Backup original sysctl.conf
    if [[ ! -f /etc/sysctl.conf.backup ]]; then
        cp /etc/sysctl.conf /etc/sysctl.conf.backup
    fi

    # IPv6 forwarding and RA settings
    cat >> /etc/sysctl.conf << 'EOF'

# IPv6 Configuration for ORION Router
# Added by deploy-ipv6-routing.sh

# Enable IPv6 forwarding
net.ipv6.conf.all.forwarding=1
net.ipv6.conf.default.forwarding=1

# Accept Router Advertisements on WAN (even with forwarding enabled)
net.ipv6.conf.eth0.accept_ra=2
net.ipv6.conf.all.accept_ra=2

# Don't accept RAs on LAN interfaces (we're the router)
net.ipv6.conf.eth1.accept_ra=0
net.ipv6.conf.eth2.accept_ra=0
net.ipv6.conf.eth3.accept_ra=0

# Disable IPv6 autoconfiguration on LAN interfaces
net.ipv6.conf.eth1.autoconf=0
net.ipv6.conf.eth2.autoconf=0
net.ipv6.conf.eth3.autoconf=0

# Accept redirects only on WAN
net.ipv6.conf.eth0.accept_redirects=1
net.ipv6.conf.eth1.accept_redirects=0
net.ipv6.conf.eth2.accept_redirects=0
net.ipv6.conf.eth3.accept_redirects=0

# Increase neighbor cache size
net.ipv6.neigh.default.gc_thresh1=1024
net.ipv6.neigh.default.gc_thresh2=2048
net.ipv6.neigh.default.gc_thresh3=4096

# Enable source validation (Reverse Path Filtering)
net.ipv6.conf.all.rp_filter=1
net.ipv6.conf.default.rp_filter=1

EOF

    # Apply sysctl settings
    sysctl -p

    log_success "Kernel parameters configured"
}

configure_network_interfaces() {
    log_info "Configuring network interfaces with IPv6..."

    # Backup existing interfaces file
    if [[ ! -f /etc/network/interfaces.backup ]]; then
        cp /etc/network/interfaces /etc/network/interfaces.backup
    fi

    # This will append IPv6 configuration
    # Note: You should verify and adjust based on your actual interface config

    cat >> /etc/network/interfaces << 'EOF'

# IPv6 Configuration - Added by deploy-ipv6-routing.sh

# WAN Interface (eth0) - IPv6
iface eth0 inet6 static
    address 2602:F674:0000::1/64
    # Gateway will be learned via BGP
    dns-nameservers 2606:4700:4700::1111 2606:4700:4700::1001

# LAN Interface (eth1) - IPv6
iface eth1 inet6 static
    address 2602:F674:1000::1/64

# Guest Interface (eth2) - IPv6
iface eth2 inet6 static
    address 2602:F674:2000::1/64

# Management Interface (eth3) - IPv6
iface eth3 inet6 static
    address 2602:F674:3000::1/64

EOF

    log_success "Network interface configuration updated"
    log_warn "You may need to restart networking: systemctl restart networking"
    log_warn "Or reboot the system for changes to take effect"
}

configure_bird() {
    log_info "Configuring BIRD2 for IPv6 BGP..."

    # Backup existing BIRD config
    if [[ -f /etc/bird/bird.conf ]]; then
        cp /etc/bird/bird.conf /etc/bird/bird.conf.backup.$(date +%Y%m%d-%H%M%S)
    fi

    # Copy our BIRD6 configuration
    if [[ -f ./router-configs/bird2/bird6.conf ]]; then
        cp ./router-configs/bird2/bird6.conf /etc/bird/bird.conf
        log_success "BIRD configuration copied from router-configs/bird2/bird6.conf"
    else
        log_error "BIRD configuration file not found: ./router-configs/bird2/bird6.conf"
        log_info "Please ensure you're running this script from the repository root"
        exit 1
    fi

    # Test BIRD configuration
    log_info "Testing BIRD configuration..."
    if bird -c /etc/bird/bird.conf -p; then
        log_success "BIRD configuration is valid"
    else
        log_error "BIRD configuration has errors. Please fix before continuing."
        exit 1
    fi

    # Enable and restart BIRD
    systemctl enable bird
    systemctl restart bird

    # Wait a moment for BIRD to start
    sleep 2

    # Check BIRD status
    if systemctl is-active --quiet bird; then
        log_success "BIRD is running"
    else
        log_error "BIRD failed to start. Check logs: journalctl -u bird"
        exit 1
    fi

    log_success "BIRD2 configured and running"
}

configure_radvd() {
    log_info "Configuring radvd for IPv6 Router Advertisements..."

    # Backup existing radvd config
    if [[ -f /etc/radvd.conf ]]; then
        cp /etc/radvd.conf /etc/radvd.conf.backup.$(date +%Y%m%d-%H%M%S)
    fi

    # Copy our radvd configuration
    if [[ -f ./router-configs/network/radvd.conf ]]; then
        cp ./router-configs/network/radvd.conf /etc/radvd.conf
        log_success "radvd configuration copied from router-configs/network/radvd.conf"
    else
        log_error "radvd configuration file not found: ./router-configs/network/radvd.conf"
        exit 1
    fi

    # Test radvd configuration
    log_info "Testing radvd configuration..."
    if radvd -c /etc/radvd.conf -C; then
        log_success "radvd configuration is valid"
    else
        log_error "radvd configuration has errors. Please fix before continuing."
        exit 1
    fi

    # Enable and start radvd
    systemctl enable radvd
    systemctl restart radvd

    # Check radvd status
    if systemctl is-active --quiet radvd; then
        log_success "radvd is running"
    else
        log_error "radvd failed to start. Check logs: journalctl -u radvd"
        exit 1
    fi

    log_success "radvd configured and running"
}

configure_firewall() {
    log_info "Configuring nftables firewall for IPv6..."

    # Create nftables configuration
    cat > /etc/nftables.conf << 'NFTABLES_EOF'
#!/usr/sbin/nft -f
# IPv6 Firewall Rules for ORION Router
# Generated by deploy-ipv6-routing.sh

# Flush existing rules
flush ruleset

# IPv6 Filter Table
table ip6 filter {
    chain input {
        type filter hook input priority 0; policy drop;

        # Accept loopback
        iif "lo" accept

        # Accept established/related connections
        ct state established,related accept

        # Accept ICMPv6 (essential for IPv6 operation)
        icmpv6 type {
            destination-unreachable,
            packet-too-big,
            time-exceeded,
            parameter-problem,
            echo-request,
            echo-reply,
            nd-router-advert,
            nd-router-solicit,
            nd-neighbor-solicit,
            nd-neighbor-advert
        } accept

        # Accept BGP from peers (port 179)
        ip6 saddr 2602:F674:0000::/64 tcp dport 179 accept
        tcp sport 179 ct state established,related accept

        # Accept SSH from management network
        ip6 saddr 2602:F674:3000::/64 tcp dport 22 accept

        # Accept DNS queries from LAN networks
        ip6 saddr { 2602:F674:1000::/64, 2602:F674:2000::/64, 2602:F674:3000::/64 } udp dport 53 accept
        ip6 saddr { 2602:F674:1000::/64, 2602:F674:2000::/64, 2602:F674:3000::/64 } tcp dport 53 accept

        # Accept DHCPv6 from clients
        ip6 saddr fe80::/10 udp sport 546 udp dport 547 accept

        # Accept NTP from LAN
        ip6 saddr { 2602:F674:1000::/64, 2602:F674:2000::/64 } udp dport 123 accept

        # Log dropped packets (rate limited)
        limit rate 5/minute log prefix "IPv6-INPUT-DROP: "

        # Drop everything else
        drop
    }

    chain forward {
        type filter hook forward priority 0; policy drop;

        # Accept established/related
        ct state established,related accept

        # Accept ICMPv6 forwarding
        icmpv6 type {
            destination-unreachable,
            packet-too-big,
            time-exceeded,
            parameter-problem,
            echo-request,
            echo-reply
        } accept

        # Forward from LAN to WAN
        iif "eth1" oif "eth0" ip6 saddr 2602:F674:1000::/64 accept

        # Forward from Guest to WAN (no access to LAN)
        iif "eth2" oif "eth0" ip6 saddr 2602:F674:2000::/64 accept

        # Forward from Management to WAN
        iif "eth3" oif "eth0" ip6 saddr 2602:F674:3000::/64 accept

        # Block guest network from accessing LAN
        iif "eth2" oif { "eth1", "eth3" } drop
        iif { "eth1", "eth3" } oif "eth2" drop

        # Log dropped forwards (rate limited)
        limit rate 5/minute log prefix "IPv6-FORWARD-DROP: "

        drop
    }

    chain output {
        type filter hook output priority 0; policy accept;
    }
}

# IPv6 NAT table (usually not needed for IPv6, but included for completeness)
table ip6 nat {
    chain postrouting {
        type nat hook postrouting priority 100; policy accept;
        # IPv6 typically doesn't use NAT
        # If you need NPTv6 (Network Prefix Translation), add rules here
    }
}
NFTABLES_EOF

    # Make executable
    chmod +x /etc/nftables.conf

    # Test nftables configuration
    log_info "Testing nftables configuration..."
    if nft -c -f /etc/nftables.conf; then
        log_success "nftables configuration is valid"
    else
        log_error "nftables configuration has errors"
        exit 1
    fi

    # Apply nftables rules
    nft -f /etc/nftables.conf

    # Enable nftables service
    systemctl enable nftables

    log_success "nftables firewall configured"
}

verify_configuration() {
    log_info "Verifying IPv6 configuration..."

    echo ""
    echo "=== Interface IPv6 Addresses ==="
    ip -6 addr show | grep -E "inet6|^[0-9]:"
    echo ""

    echo "=== IPv6 Routing Table ==="
    ip -6 route show
    echo ""

    echo "=== BIRD Protocols ==="
    birdc show protocols 2>/dev/null || log_warn "BIRD not responding (may need to restart)"
    echo ""

    echo "=== radvd Status ==="
    systemctl status radvd --no-pager | head -10
    echo ""

    echo "=== Firewall Rules ==="
    nft list ruleset | grep -A3 "table ip6"
    echo ""

    log_success "Verification complete"
}

print_next_steps() {
    cat << 'EOF'

╔═══════════════════════════════════════════════════════════════╗
║                 DEPLOYMENT COMPLETE                           ║
╚═══════════════════════════════════════════════════════════════╝

Next Steps:

1. Update BIRD Configuration with Actual Telus Gateway Addresses:
   - Edit /etc/bird/bird.conf
   - Replace placeholder addresses (fe80::1, fe80::2, fe80::3)
   - With actual Telus IPv6 gateway addresses
   - Restart BIRD: systemctl restart bird

2. Verify BGP Sessions:
   birdc show protocols
   birdc show protocols all telus_peer1_v6

3. Check Routes:
   birdc show route protocol telus_peer1_v6
   ip -6 route show

4. Test Connectivity:
   ping6 google.com
   ping6 2606:4700:4700::1111

5. Verify Router Advertisements:
   # On a LAN client
   rdisc6 eth0
   ip -6 addr show

6. Monitor Logs:
   journalctl -u bird -f
   journalctl -u radvd -f
   journalctl -k | grep IPv6

7. Optional: Restart networking if interfaces didn't configure:
   systemctl restart networking
   # Or reboot: reboot

Configuration Files:
- BIRD: /etc/bird/bird.conf
- radvd: /etc/radvd.conf
- nftables: /etc/nftables.conf
- sysctl: /etc/sysctl.conf

Documentation:
- Full guide: IPV6_ROUTING_INTEGRATION.md
- Architecture: ORION_HYBRID_ARCHITECTURE.md

EOF
}

# Main execution
main() {
    print_banner
    echo ""

    check_root
    check_prerequisites
    echo ""

    install_packages
    echo ""

    configure_sysctl
    echo ""

    log_warn "The following step will modify network configuration."
    log_warn "Continue? (y/N)"
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        log_info "Aborting."
        exit 0
    fi

    configure_network_interfaces
    echo ""

    configure_bird
    echo ""

    configure_radvd
    echo ""

    configure_firewall
    echo ""

    verify_configuration
    echo ""

    print_next_steps
}

# Run main function
main "$@"
