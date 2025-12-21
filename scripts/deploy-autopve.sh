#!/usr/bin/env bash
#
# AutoPVE Deployment Script for LuciVerse
# Deploys AutoPVE as a NixOS LXC container on Proxmox
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
PROXMOX_HOST="${PROXMOX_HOST:-192.168.100.10}"
PROXMOX_USER="${PROXMOX_USER:-root@pam}"
CONTAINER_ID="${AUTOPVE_CT_ID:-1100}"
CONTAINER_HOSTNAME="autopve-server"
CONTAINER_IP="192.168.100.110"
CONTAINER_GATEWAY="192.168.100.1"
CONTAINER_CORES=2
CONTAINER_RAM=4096
CONTAINER_DISK=20
STORAGE="${STORAGE:-local-lvm}"
TEMPLATE_STORAGE="${TEMPLATE_STORAGE:-local}"

echo -e "${GREEN}🚀 LuciVerse AutoPVE Deployment${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Step 1: Build NixOS LXC template
echo -e "${YELLOW}📦 Step 1: Building NixOS LXC template for AutoPVE...${NC}"
nix build .#autopve-lxc -o result-autopve-lxc

TEMPLATE_FILE=$(find result-autopve-lxc/tarball -name "*.tar.xz" | head -1)
if [ -z "$TEMPLATE_FILE" ]; then
    echo -e "${RED}❌ Template build failed${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Template built: $TEMPLATE_FILE${NC}"
echo ""

# Step 2: Upload template to Proxmox
echo -e "${YELLOW}📤 Step 2: Uploading template to Proxmox...${NC}"
TEMPLATE_NAME="nixos-autopve-$(date +%Y%m%d).tar.xz"

scp "$TEMPLATE_FILE" "${PROXMOX_USER}@${PROXMOX_HOST}:/var/lib/vz/template/cache/${TEMPLATE_NAME}"

echo -e "${GREEN}✅ Template uploaded${NC}"
echo ""

# Step 3: Create LXC container
echo -e "${YELLOW}🏗️  Step 3: Creating LXC container...${NC}"

ssh "${PROXMOX_USER}@${PROXMOX_HOST}" bash <<EOF
# Stop and remove existing container if it exists
if pct status ${CONTAINER_ID} &>/dev/null; then
    echo "Stopping existing container ${CONTAINER_ID}..."
    pct stop ${CONTAINER_ID} || true
    sleep 2
    pct destroy ${CONTAINER_ID} || true
fi

# Create new container
pct create ${CONTAINER_ID} \
    ${TEMPLATE_STORAGE}:vztmpl/${TEMPLATE_NAME} \
    --hostname ${CONTAINER_HOSTNAME} \
    --ostype unmanaged \
    --arch amd64 \
    --cores ${CONTAINER_CORES} \
    --memory ${CONTAINER_RAM} \
    --swap 0 \
    --storage ${STORAGE} \
    --rootfs ${STORAGE}:${CONTAINER_DISK} \
    --unprivileged 1 \
    --features nesting=1 \
    --net0 name=eth0,bridge=vmbr1,firewall=1,ip=${CONTAINER_IP}/24,gw=${CONTAINER_GATEWAY} \
    --onboot 1

# Set console mode
pct set ${CONTAINER_ID} --console mode=console

echo "✅ Container ${CONTAINER_ID} created"

# Start container
pct start ${CONTAINER_ID}

echo "✅ Container ${CONTAINER_ID} started"
EOF

echo -e "${GREEN}✅ Container created and started${NC}"
echo ""

# Step 4: Wait for container to be ready
echo -e "${YELLOW}⏳ Step 4: Waiting for container to be ready...${NC}"
sleep 10

# Step 5: Configure AutoPVE
echo -e "${YELLOW}⚙️  Step 5: Configuring AutoPVE...${NC}"

ssh "${PROXMOX_USER}@${PROXMOX_HOST}" bash <<EOF
pct exec ${CONTAINER_ID} -- bash -c '
    # Wait for AutoPVE service to start
    echo "Waiting for AutoPVE to start..."
    for i in {1..30}; do
        if systemctl is-active --quiet autopve; then
            echo "AutoPVE service is active"
            break
        fi
        sleep 2
    done

    # Wait for Docker and AutoPVE container
    echo "Waiting for AutoPVE container..."
    for i in {1..60}; do
        if docker ps | grep -q autopve; then
            echo "AutoPVE container is running"
            break
        fi
        sleep 2
    done

    # Check AutoPVE is responding
    if curl -s http://localhost:8080 > /dev/null; then
        echo "✅ AutoPVE is responding"
    else
        echo "⚠️  AutoPVE may not be fully started yet"
    fi
'
EOF

echo -e "${GREEN}✅ AutoPVE configured${NC}"
echo ""

# Step 6: Display access information
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ AutoPVE Deployment Complete!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "📝 Access Information:"
echo "  Container ID: ${CONTAINER_ID}"
echo "  Hostname: ${CONTAINER_HOSTNAME}"
echo "  IP Address: ${CONTAINER_IP}"
echo ""
echo "🌐 AutoPVE Web Interface:"
echo "  URL: http://${CONTAINER_IP}:8080"
echo "  Answer Endpoint: http://${CONTAINER_IP}:8080/answer"
echo "  Playbook Webhook: http://${CONTAINER_IP}:8080/playbook/<name>"
echo ""
echo "🔧 SSH Access:"
echo "  ssh admin@${CONTAINER_IP}"
echo ""
echo "📊 Container Management:"
echo "  pct status ${CONTAINER_ID}"
echo "  pct stop ${CONTAINER_ID}"
echo "  pct start ${CONTAINER_ID}"
echo "  pct exec ${CONTAINER_ID} -- bash"
echo ""
echo "🔍 Check AutoPVE Status:"
echo "  curl http://${CONTAINER_IP}:8080"
echo ""

# Test AutoPVE connection
if curl -s "http://${CONTAINER_IP}:8080" > /dev/null 2>&1; then
    echo -e "${GREEN}✅ AutoPVE is accessible and responding${NC}"
else
    echo -e "${YELLOW}⚠️  AutoPVE may still be starting up. Please wait a moment and check manually.${NC}"
fi

echo ""
echo "📚 Next Steps:"
echo "  1. Access AutoPVE web interface at http://${CONTAINER_IP}:8080"
echo "  2. Configure automated installation profiles"
echo "  3. Set up answer templates for Proxmox automated installs"
echo "  4. Configure post-installation playbooks"
echo ""
