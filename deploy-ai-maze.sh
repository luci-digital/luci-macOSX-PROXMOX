#!/bin/bash
#
# AI Maze Deployment Script
# Deploys Backstage + Vapor API middleware on Proxmox
# Creates security-through-obscurity "maze" for infrastructure management
#
# Prerequisites:
# - Proxmox VE installed and accessible
# - Base ORION infrastructure deployed
# - Ubuntu 24.04 ISO available
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROXMOX_HOST="192.168.100.10"
PROXMOX_USER="root@pam"
UBUNTU_ISO="/var/lib/vz/template/iso/ubuntu-24.04-live-server-amd64.iso"
UBUNTU_ISO_URL="https://releases.ubuntu.com/24.04/ubuntu-24.04-live-server-amd64.iso"

# VM Configurations
VAPOR_VM_ID=401
VAPOR_VM_NAME="ORION-VaporAPI"
VAPOR_VM_CORES=4
VAPOR_VM_MEMORY=8192
VAPOR_VM_DISK=50
VAPOR_VM_IP="192.168.100.41"

BACKSTAGE_VM_ID=400
BACKSTAGE_VM_NAME="ORION-Backstage"
BACKSTAGE_VM_CORES=4
BACKSTAGE_VM_MEMORY=16384
BACKSTAGE_VM_DISK=100
BACKSTAGE_VM_IP="192.168.100.40"

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
║              AI MAZE DEPLOYMENT SYSTEM                        ║
║                                                               ║
║  Architecture:                                                ║
║    Layer 1: Backstage Developer Portal (React/Node.js)        ║
║    Layer 2: Vapor API Middleware (Swift) ← The Maze          ║
║    Layer 3: Proxmox VE (Protected Infrastructure)             ║
║                                                               ║
║  Security Features:                                           ║
║    ✓ Uncommon tech stack (confuses scanners)                 ║
║    ✓ Honeypot endpoints (detects/bans attackers)             ║
║    ✓ Request obfuscation (AI confusion)                      ║
║    ✓ Defense in depth (multiple layers)                      ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
EOF
}

check_prerequisites() {
    log_info "Checking prerequisites..."

    # Check if running on Proxmox host or remote
    if ! command -v qm &> /dev/null; then
        log_error "This script must run on the Proxmox host or you need SSH access"
        log_info "Attempting to connect to Proxmox at $PROXMOX_HOST..."

        if ! ssh "${PROXMOX_USER}@${PROXMOX_HOST}" "qm list" &> /dev/null; then
            log_error "Cannot connect to Proxmox. Please ensure SSH access is configured."
            exit 1
        fi

        log_success "Connected to Proxmox via SSH"
        REMOTE_EXEC="ssh ${PROXMOX_USER}@${PROXMOX_HOST}"
    else
        log_success "Running on Proxmox host"
        REMOTE_EXEC=""
    fi

    # Check for Ubuntu ISO
    if $REMOTE_EXEC test -f "$UBUNTU_ISO"; then
        log_success "Ubuntu ISO found: $UBUNTU_ISO"
    else
        log_warn "Ubuntu ISO not found. Downloading..."
        $REMOTE_EXEC wget -O "$UBUNTU_ISO" "$UBUNTU_ISO_URL"
        log_success "Ubuntu ISO downloaded"
    fi

    log_success "Prerequisites check complete"
}

create_vapor_vm() {
    log_info "Creating Vapor API VM (VM $VAPOR_VM_ID)..."

    # Check if VM already exists
    if $REMOTE_EXEC qm status "$VAPOR_VM_ID" &> /dev/null; then
        log_warn "VM $VAPOR_VM_ID already exists. Skipping creation."
        return 0
    fi

    # Create VM
    $REMOTE_EXEC qm create "$VAPOR_VM_ID" \
        --name "$VAPOR_VM_NAME" \
        --cores "$VAPOR_VM_CORES" \
        --memory "$VAPOR_VM_MEMORY" \
        --cpu host \
        --sockets 1 \
        --numa 0 \
        --ostype l26 \
        --scsihw virtio-scsi-pci \
        --scsi0 "local-lvm:${VAPOR_VM_DISK},cache=writeback,discard=on,ssd=1" \
        --net0 "virtio,bridge=vmbr1,firewall=1" \
        --ide2 "local:iso/ubuntu-24.04-live-server-amd64.iso,media=cdrom" \
        --boot "order=scsi0;ide2" \
        --agent 1 \
        --onboot 1 \
        --startup "order=4,up=30"

    log_success "Vapor API VM created successfully"

    log_info "Next steps for VM $VAPOR_VM_ID:"
    echo "  1. Start VM: qm start $VAPOR_VM_ID"
    echo "  2. Open console and install Ubuntu 24.04"
    echo "  3. Set static IP: $VAPOR_VM_IP/24"
    echo "  4. After OS install, run: ./setup-vapor-vm.sh"
}

create_backstage_vm() {
    log_info "Creating Backstage VM (VM $BACKSTAGE_VM_ID)..."

    # Check if VM already exists
    if $REMOTE_EXEC qm status "$BACKSTAGE_VM_ID" &> /dev/null; then
        log_warn "VM $BACKSTAGE_VM_ID already exists. Skipping creation."
        return 0
    fi

    # Create VM
    $REMOTE_EXEC qm create "$BACKSTAGE_VM_ID" \
        --name "$BACKSTAGE_VM_NAME" \
        --cores "$BACKSTAGE_VM_CORES" \
        --memory "$BACKSTAGE_VM_MEMORY" \
        --cpu host \
        --sockets 1 \
        --numa 0 \
        --ostype l26 \
        --scsihw virtio-scsi-pci \
        --scsi0 "local-lvm:${BACKSTAGE_VM_DISK},cache=writeback,discard=on,ssd=1" \
        --net0 "virtio,bridge=vmbr1,firewall=1" \
        --ide2 "local:iso/ubuntu-24.04-live-server-amd64.iso,media=cdrom" \
        --boot "order=scsi0;ide2" \
        --agent 1 \
        --onboot 1 \
        --startup "order=5,up=30"

    log_success "Backstage VM created successfully"

    log_info "Next steps for VM $BACKSTAGE_VM_ID:"
    echo "  1. Start VM: qm start $BACKSTAGE_VM_ID"
    echo "  2. Open console and install Ubuntu 24.04"
    echo "  3. Set static IP: $BACKSTAGE_VM_IP/24"
    echo "  4. After OS install, run: ./setup-backstage-vm.sh"
}

create_setup_scripts() {
    log_info "Creating VM setup scripts..."

    # Vapor VM setup script
    cat > setup-vapor-vm.sh << 'VAPOR_SETUP_EOF'
#!/bin/bash
# Run this script on VM 401 after Ubuntu installation

set -euo pipefail

echo "Setting up Vapor API VM..."

# Update system
apt-get update
apt-get upgrade -y

# Install dependencies
apt-get install -y \
    wget curl git vim \
    build-essential \
    libssl-dev \
    libsqlite3-dev \
    redis-server

# Install Swift 5.10
wget https://download.swift.org/swift-5.10-release/ubuntu2404/swift-5.10-RELEASE/swift-5.10-RELEASE-ubuntu24.04.tar.gz
tar xzf swift-5.10-RELEASE-ubuntu24.04.tar.gz
mv swift-5.10-RELEASE-ubuntu24.04 /opt/swift
echo 'export PATH=/opt/swift/usr/bin:$PATH' >> /etc/profile.d/swift.sh
source /etc/profile.d/swift.sh

# Verify Swift installation
swift --version

# Install Vapor toolbox
git clone https://github.com/vapor/toolbox.git
cd toolbox
git checkout 18.7.4
swift build -c release
mv .build/release/vapor /usr/local/bin/
cd ..
rm -rf toolbox

# Create Vapor project
mkdir -p /opt/orion-api
cd /opt/orion-api

# Initialize Vapor project
vapor new . --template api --non-interactive

# Create systemd service
cat > /etc/systemd/system/orion-api.service << 'SERVICE_EOF'
[Unit]
Description=ORION Vapor API
After=network.target redis-server.service

[Service]
Type=simple
User=root
WorkingDirectory=/opt/orion-api
ExecStart=/opt/swift/usr/bin/swift run App serve --hostname 0.0.0.0 --port 8080
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
SERVICE_EOF

# Enable but don't start yet (need to configure first)
systemctl daemon-reload
systemctl enable orion-api

echo "Vapor API VM setup complete!"
echo ""
echo "Next steps:"
echo "1. Configure Vapor API code in /opt/orion-api"
echo "2. Start service: systemctl start orion-api"
echo "3. Check logs: journalctl -u orion-api -f"
VAPOR_SETUP_EOF

    chmod +x setup-vapor-vm.sh

    # Backstage VM setup script
    cat > setup-backstage-vm.sh << 'BACKSTAGE_SETUP_EOF'
#!/bin/bash
# Run this script on VM 400 after Ubuntu installation

set -euo pipefail

echo "Setting up Backstage VM..."

# Update system
apt-get update
apt-get upgrade -y

# Install dependencies
apt-get install -y \
    wget curl git vim \
    build-essential \
    python3 python3-pip

# Install Node.js 20 LTS
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs

# Install Yarn
npm install -g yarn

# Verify installations
node --version
npm --version
yarn --version

# Install PostgreSQL (for Backstage catalog)
apt-get install -y postgresql postgresql-contrib
systemctl enable postgresql
systemctl start postgresql

# Create Backstage database
sudo -u postgres psql << 'PSQL_EOF'
CREATE USER backstage WITH PASSWORD 'backstage_password_change_me';
CREATE DATABASE backstage;
GRANT ALL PRIVILEGES ON DATABASE backstage TO backstage;
PSQL_EOF

# Create Backstage app
mkdir -p /opt/backstage
cd /opt/backstage

# Create app (will prompt for name)
npx @backstage/create-app@latest

echo "Follow the prompts to create your Backstage app"
echo ""
echo "After creation, configure:"
echo "1. Edit app-config.yaml for PostgreSQL connection"
echo "2. Install Proxmox plugin"
echo "3. Configure authentication (OAuth2/OIDC)"
echo "4. Start: yarn dev (development) or yarn build && yarn start (production)"

echo ""
echo "Backstage VM setup complete!"
BACKSTAGE_SETUP_EOF

    chmod +x setup-backstage-vm.sh

    log_success "Setup scripts created: setup-vapor-vm.sh, setup-backstage-vm.sh"
}

configure_firewall() {
    log_info "Configuring firewall rules..."

    cat > firewall-rules.sh << 'FIREWALL_EOF'
#!/bin/bash
# Run this on Router VM (200) to configure AI Maze firewall

# Allow Backstage -> Vapor API
nft add rule inet filter input ip saddr 192.168.100.40 tcp dport 8080 ip daddr 192.168.100.41 accept comment "Backstage -> Vapor API"

# Block all other access to Vapor API
nft add rule inet filter input tcp dport 8080 drop comment "Block direct Vapor API access"

# Allow Vapor API -> Proxmox
nft add rule inet filter input ip saddr 192.168.100.41 tcp dport 8006 ip daddr 192.168.100.10 accept comment "Vapor -> Proxmox API"

# Block all other access to Proxmox web UI (except from management network)
nft add rule inet filter input ip saddr != 192.168.1.0/24 tcp dport 8006 drop comment "Block external Proxmox access"

# Allow Backstage web UI from LAN
nft add rule inet filter input tcp dport 7007 ip saddr 192.168.100.0/24 accept comment "Allow Backstage web UI"

echo "Firewall rules configured for AI Maze"
nft list ruleset | grep -E "8080|8006|7007"
FIREWALL_EOF

    chmod +x firewall-rules.sh

    log_success "Firewall configuration script created: firewall-rules.sh"
    log_warn "Remember to run this on Router VM (200) after VMs are deployed"
}

print_next_steps() {
    cat << 'EOF'

╔═══════════════════════════════════════════════════════════════╗
║                  DEPLOYMENT COMPLETE                          ║
╚═══════════════════════════════════════════════════════════════╝

Next Steps:

1. Start and Configure Vapor API VM (401):
   qm start 401
   # Install Ubuntu via console
   # Set IP: 192.168.100.41/24
   # Copy and run: ./setup-vapor-vm.sh

2. Start and Configure Backstage VM (400):
   qm start 400
   # Install Ubuntu via console
   # Set IP: 192.168.100.40/24
   # Copy and run: ./setup-backstage-vm.sh

3. Configure Firewall (on Router VM 200):
   ssh root@192.168.100.1
   # Copy and run: ./firewall-rules.sh

4. Develop Vapor API:
   - Implement Proxmox API client
   - Add honeypot endpoints
   - Configure authentication
   - See: AI_MAZE_ARCHITECTURE.md for code samples

5. Configure Backstage:
   - Install Proxmox plugin
   - Configure OAuth2/OIDC
   - Create service catalog
   - Add infrastructure templates

6. Test the Maze:
   - Access Backstage: http://192.168.100.40:7007
   - Verify Vapor API is not directly accessible
   - Test honeypot endpoints trigger bans
   - Monitor with Grafana on AI Agent VM

Documentation:
- Full architecture: AI_MAZE_ARCHITECTURE.md
- Base infrastructure: DELL_R730_ORION_PROXMOX_INTEGRATION.md
- Hybrid setup: ORION_HYBRID_ARCHITECTURE.md

EOF
}

# Main execution
main() {
    print_banner
    echo ""

    check_prerequisites
    echo ""

    create_vapor_vm
    echo ""

    create_backstage_vm
    echo ""

    create_setup_scripts
    echo ""

    configure_firewall
    echo ""

    print_next_steps
}

# Run main function
main "$@"
