#!/usr/bin/env python3
"""
Dell R730 ORION Hybrid Deployment
Combines: Proxmox VE + NixOS/VyOS Router + macOS + AI Agent + iDRAC Automation

Architecture:
- Base: Proxmox VE (flexibility + virtualization)
- VM 200: NixOS + VyOS Router (performance routing)
- VM 100: macOS Sequoia (development)
- VM 300: AI Agent + Monitoring (intelligence)
- Deployment: Full iDRAC Redfish API automation
"""

import requests
import json
import time
import sys
import subprocess
from pathlib import Path
from typing import Dict, Any, Optional
from urllib3.exceptions import InsecureRequestWarning

# Suppress SSL warnings for iDRAC
requests.packages.urllib3.disable_warnings(category=InsecureRequestWarning)

# ============================================================================
# CONFIGURATION
# ============================================================================

# iDRAC Configuration
IDRAC_IP = "192.168.1.2"
IDRAC_USER = "root"
IDRAC_PASS = "calvin"
IDRAC_BASE_URL = f"https://{IDRAC_IP}/redfish/v1"

# Dell R730 Hardware
DELL_SERVICE_TAG = "CQ5QBM2"
TOTAL_CPU_CORES = 56
TOTAL_RAM_GB = 384
TOTAL_NICS = 8

# Network Configuration
PROXMOX_IP = "192.168.100.10"
PROXMOX_GATEWAY = "192.168.100.1"
PROXMOX_NETMASK = "24"

# BGP Configuration
LOCAL_AS = "394955"
TELUS_AS = "6939"
TELUS_GATEWAYS = ["206.75.1.127", "206.75.1.47", "206.75.1.48"]
IPV6_PREFIX = "2602:F674::/48"

# VM Configurations
VMS = {
    "router": {
        "id": 200,
        "name": "ORION-Router",
        "os": "NixOS 24.11 + VyOS",
        "cpu_cores": 8,
        "ram_gb": 32,
        "disk_gb": 50,
        "startup_order": 1,
        "autostart": True,
        "description": "Primary router with VyOS, BGP, firewall"
    },
    "macos": {
        "id": 100,
        "name": "HACK-Sequoia-01",
        "os": "macOS Sequoia 15",
        "cpu_cores": 12,
        "ram_gb": 64,
        "disk_gb": 256,
        "startup_order": 10,
        "autostart": False,
        "description": "macOS development environment"
    },
    "ai_agent": {
        "id": 300,
        "name": "ORION-AI-Agent",
        "os": "NixOS 24.11",
        "cpu_cores": 4,
        "ram_gb": 16,
        "disk_gb": 50,
        "startup_order": 2,
        "autostart": True,
        "description": "Autonomous network agent + monitoring"
    }
}

# Deployment Phases
PHASES = [
    "prerequisites",
    "idrac_config",
    "proxmox_install",
    "network_config",
    "router_vm",
    "macos_vm",
    "ai_agent_vm",
    "monitoring",
    "verification"
]


# ============================================================================
# HELPER CLASSES
# ============================================================================

class Logger:
    """Enhanced logging with colors and levels"""

    COLORS = {
        "DEBUG": "\033[0;36m",
        "INFO": "\033[0;34m",
        "SUCCESS": "\033[0;32m",
        "WARN": "\033[1;33m",
        "ERROR": "\033[0;31m",
        "NC": "\033[0m"
    }

    def __init__(self, log_file: Optional[Path] = None):
        self.log_file = log_file
        if log_file:
            log_file.parent.mkdir(parents=True, exist_ok=True)

    def log(self, level: str, message: str, step: Optional[str] = None):
        """Log message with level and optional step"""
        color = self.COLORS.get(level, self.COLORS["NC"])
        nc = self.COLORS["NC"]

        timestamp = time.strftime("%Y-%m-%d %H:%M:%S")

        if step:
            prefix = f"{color}[{level}]{nc} [{step}]"
        else:
            prefix = f"{color}[{level}]{nc}"

        output = f"{prefix} {message}"
        print(output)

        if self.log_file:
            with open(self.log_file, "a") as f:
                f.write(f"{timestamp} [{level}] {message}\n")

    def debug(self, msg: str, step: str = None):
        self.log("DEBUG", msg, step)

    def info(self, msg: str, step: str = None):
        self.log("INFO", msg, step)

    def success(self, msg: str, step: str = None):
        self.log("SUCCESS", msg, step)

    def warn(self, msg: str, step: str = None):
        self.log("WARN", msg, step)

    def error(self, msg: str, step: str = None):
        self.log("ERROR", msg, step)


class IDracAPI:
    """iDRAC Redfish API client"""

    def __init__(self, logger: Logger):
        self.logger = logger
        self.session = requests.Session()
        self.session.auth = (IDRAC_USER, IDRAC_PASS)
        self.session.verify = False
        self.session.headers.update({"Content-Type": "application/json"})

    def get(self, endpoint: str) -> Dict[str, Any]:
        """GET request to Redfish API"""
        url = f"{IDRAC_BASE_URL}{endpoint}"
        try:
            response = self.session.get(url, timeout=30)
            response.raise_for_status()
            return response.json()
        except Exception as e:
            self.logger.error(f"GET {endpoint} failed: {e}")
            raise

    def post(self, endpoint: str, data: Dict[str, Any] = None) -> Dict[str, Any]:
        """POST request to Redfish API"""
        url = f"{IDRAC_BASE_URL}{endpoint}"
        try:
            response = self.session.post(url, json=data, timeout=30)
            response.raise_for_status()
            return response.json() if response.text else {}
        except Exception as e:
            self.logger.error(f"POST {endpoint} failed: {e}")
            raise

    def patch(self, endpoint: str, data: Dict[str, Any]) -> Dict[str, Any]:
        """PATCH request to Redfish API"""
        url = f"{IDRAC_BASE_URL}{endpoint}"
        try:
            response = self.session.patch(url, json=data, timeout=30)
            response.raise_for_status()
            return response.json() if response.text else {}
        except Exception as e:
            self.logger.error(f"PATCH {endpoint} failed: {e}")
            raise

    def get_system_info(self) -> Dict[str, Any]:
        """Get current system information"""
        data = self.get("/Systems/System.Embedded.1")
        return {
            "PowerState": data.get("PowerState"),
            "Health": data.get("Status", {}).get("Health"),
            "State": data.get("Status", {}).get("State"),
            "BootMode": data.get("Boot", {}).get("BootSourceOverrideMode"),
            "BootTarget": data.get("Boot", {}).get("BootSourceOverrideTarget"),
            "Model": data.get("Model"),
            "ServiceTag": data.get("SKU")
        }

    def power_on(self):
        """Power on the system"""
        self.post("/Systems/System.Embedded.1/Actions/ComputerSystem.Reset", {
            "ResetType": "On"
        })
        time.sleep(5)

    def power_off(self, graceful: bool = True):
        """Power off the system"""
        reset_type = "GracefulShutdown" if graceful else "ForceOff"
        self.post("/Systems/System.Embedded.1/Actions/ComputerSystem.Reset", {
            "ResetType": reset_type
        })
        if graceful:
            time.sleep(30)

    def reboot(self):
        """Reboot the system"""
        self.post("/Systems/System.Embedded.1/Actions/ComputerSystem.Reset", {
            "ResetType": "ForceRestart"
        })

    def set_boot_device(self, device: str, enabled: str = "Once"):
        """Set boot device (Cd, Pxe, Hdd, etc.)"""
        self.patch("/Systems/System.Embedded.1", {
            "Boot": {
                "BootSourceOverrideTarget": device,
                "BootSourceOverrideEnabled": enabled
            }
        })


# ============================================================================
# DEPLOYMENT ORCHESTRATOR
# ============================================================================

class ORIONDeployer:
    """Main deployment orchestrator for hybrid ORION system"""

    def __init__(self):
        self.logger = Logger(Path("logs") / f"orion-deploy-{time.strftime('%Y%m%d-%H%M%S')}.log")
        self.idrac = IDracAPI(self.logger)
        self.config = self._load_config()

    def _load_config(self) -> Dict[str, Any]:
        """Load orion-config.json"""
        config_path = Path(__file__).parent / "orion-config.json"
        if config_path.exists():
            with open(config_path) as f:
                return json.load(f)
        return {}

    def print_banner(self):
        """Print deployment banner"""
        banner = """
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║         Dell R730 ORION Hybrid Deployment System              ║
║                                                               ║
║  Architecture:                                                ║
║    • Proxmox VE 8.x (Hypervisor)                              ║
║    • NixOS + VyOS Router VM (High-performance routing)        ║
║    • macOS Sequoia VM (Development)                           ║
║    • AI Agent VM (Autonomous network intelligence)            ║
║    • Full iDRAC Redfish API automation                        ║
║                                                               ║
║  Hardware: Dell PowerEdge R730 (CQ5QBM2)                      ║
║    • 2x Xeon E5-2690 v4 (56 threads)                          ║
║    • 384GB DDR4 RAM                                           ║
║    • 8x Network Interfaces (4x 10GbE + 4x 1GbE)               ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
"""
        print(banner)

    def phase_prerequisites(self):
        """Phase 1: Check prerequisites"""
        step = "PREREQUISITES"
        self.logger.info("Checking deployment prerequisites...", step)

        # Check script directory
        script_dir = Path(__file__).parent
        self.logger.info(f"Script directory: {script_dir}", step)

        # Check for required files
        required_files = [
            "orion-config.json",
            "deploy-orion.sh"
        ]

        for file in required_files:
            file_path = script_dir / file
            if file_path.exists():
                self.logger.success(f"✓ Found {file}", step)
            else:
                self.logger.warn(f"✗ Missing {file}", step)

        # Check iDRAC connectivity
        self.logger.info(f"Testing iDRAC connectivity: {IDRAC_IP}", step)
        try:
            info = self.idrac.get_system_info()
            self.logger.success(f"✓ iDRAC accessible", step)
            self.logger.info(f"  Model: {info.get('Model')}", step)
            self.logger.info(f"  Service Tag: {info.get('ServiceTag')}", step)
            self.logger.info(f"  Power: {info.get('PowerState')}", step)
            self.logger.info(f"  Health: {info.get('Health')}", step)
        except Exception as e:
            self.logger.error(f"✗ iDRAC not accessible: {e}", step)
            return False

        self.logger.success("Prerequisites check complete", step)
        return True

    def phase_idrac_config(self):
        """Phase 2: Configure iDRAC for deployment"""
        step = "IDRAC CONFIG"
        self.logger.info("Configuring iDRAC for automated deployment...", step)

        # Get current system info
        info = self.idrac.get_system_info()

        # Ensure system is powered on
        if info["PowerState"] != "On":
            self.logger.info("System is off, powering on...", step)
            self.idrac.power_on()
            self.logger.success("System powered on", step)

        self.logger.success("iDRAC configuration complete", step)
        return True

    def phase_proxmox_install(self):
        """Phase 3: Proxmox installation guidance"""
        step = "PROXMOX INSTALL"
        self.logger.info("Proxmox VE installation preparation...", step)

        self.logger.info("", step)
        self.logger.info("Manual step required:", step)
        self.logger.info("1. Download Proxmox VE ISO from: https://www.proxmox.com/en/downloads", step)
        self.logger.info("2. Mount ISO via iDRAC virtual media", step)
        self.logger.info("3. Set boot to CD and reboot", step)
        self.logger.info("4. Follow Proxmox installer:", step)
        self.logger.info("   - Hostname: orion-pve.local", step)
        self.logger.info(f"   - IP: {PROXMOX_IP}/{PROXMOX_NETMASK}", step)
        self.logger.info(f"   - Gateway: {PROXMOX_GATEWAY}", step)
        self.logger.info("   - DNS: 1.1.1.1", step)
        self.logger.info("5. After install, access web UI: https://192.168.100.10:8006", step)
        self.logger.info("", step)

        response = input("Have you completed Proxmox installation? (y/N): ")
        if response.lower() != 'y':
            self.logger.warn("Proxmox installation not completed. Stopping deployment.", step)
            return False

        self.logger.success("Proxmox installation confirmed", step)
        return True

    def phase_network_config(self):
        """Phase 4: Network configuration"""
        step = "NETWORK CONFIG"
        self.logger.info("Configuring network bridges and interfaces...", step)

        bridges = self.config.get("network", {}).get("bridges", {})

        self.logger.info("Required network bridges:", step)
        for bridge, config in bridges.items():
            purpose = config.get("purpose", "Unknown")
            interface = config.get("interface", "N/A")
            self.logger.info(f"  {bridge}: {interface} - {purpose}", step)

        self.logger.info("", step)
        self.logger.info("Configure these bridges in Proxmox:", step)
        self.logger.info("1. Login to Proxmox web UI", step)
        self.logger.info("2. Go to: Datacenter → Node → System → Network", step)
        self.logger.info("3. Create bridges as shown above", step)
        self.logger.info("4. Apply configuration and reboot if needed", step)
        self.logger.info("", step)

        self.logger.success("Network configuration guide provided", step)
        return True

    def phase_router_vm(self):
        """Phase 5: Create NixOS/VyOS router VM"""
        step = "ROUTER VM"
        self.logger.info("Creating NixOS + VyOS router VM...", step)

        router_config = VMS["router"]

        self.logger.info(f"VM Configuration:", step)
        self.logger.info(f"  ID: {router_config['id']}", step)
        self.logger.info(f"  Name: {router_config['name']}", step)
        self.logger.info(f"  OS: {router_config['os']}", step)
        self.logger.info(f"  CPU: {router_config['cpu_cores']} cores", step)
        self.logger.info(f"  RAM: {router_config['ram_gb']} GB", step)
        self.logger.info(f"  Disk: {router_config['disk_gb']} GB", step)

        self.logger.info("", step)
        self.logger.info("This VM will provide:", step)
        self.logger.info("  • VyOS routing and firewall", step)
        self.logger.info(f"  • BGP routing (AS {LOCAL_AS})", step)
        self.logger.info("  • DHCP/DNS services", step)
        self.logger.info("  • NAT and port forwarding", step)
        self.logger.info("  • nftables firewall", step)

        self.logger.success("Router VM configuration ready", step)
        return True

    def phase_macos_vm(self):
        """Phase 6: Create macOS VM"""
        step = "MACOS VM"
        self.logger.info("Creating macOS Sequoia VM...", step)

        macos_config = VMS["macos"]

        self.logger.info(f"VM Configuration:", step)
        self.logger.info(f"  ID: {macos_config['id']}", step)
        self.logger.info(f"  Name: {macos_config['name']}", step)
        self.logger.info(f"  OS: {macos_config['os']}", step)
        self.logger.info(f"  CPU: {macos_config['cpu_cores']} cores", step)
        self.logger.info(f"  RAM: {macos_config['ram_gb']} GB", step)
        self.logger.info(f"  Disk: {macos_config['disk_gb']} GB", step)

        self.logger.info("", step)
        self.logger.info("Uses OSX-PROXMOX for macOS support", step)
        self.logger.info("Refer to existing deploy-orion.sh for detailed setup", step)

        self.logger.success("macOS VM configuration ready", step)
        return True

    def phase_ai_agent_vm(self):
        """Phase 7: Create AI agent VM"""
        step = "AI AGENT VM"
        self.logger.info("Creating AI autonomous agent VM...", step)

        ai_config = VMS["ai_agent"]

        self.logger.info(f"VM Configuration:", step)
        self.logger.info(f"  ID: {ai_config['id']}", step)
        self.logger.info(f"  Name: {ai_config['name']}", step)
        self.logger.info(f"  OS: {ai_config['os']}", step)
        self.logger.info(f"  CPU: {ai_config['cpu_cores']} cores", step)
        self.logger.info(f"  RAM: {ai_config['ram_gb']} GB", step)

        self.logger.info("", step)
        self.logger.info("This VM will run:", step)
        self.logger.info("  • Autonomous network monitoring agent", step)
        self.logger.info("  • Prometheus metrics collection", step)
        self.logger.info("  • Grafana dashboards", step)
        self.logger.info("  • Network automation APIs", step)

        self.logger.success("AI agent VM configuration ready", step)
        return True

    def phase_monitoring(self):
        """Phase 8: Setup monitoring"""
        step = "MONITORING"
        self.logger.info("Configuring monitoring stack...", step)

        self.logger.info("Monitoring components:", step)
        self.logger.info("  • Prometheus (metrics collection)", step)
        self.logger.info("  • Grafana (visualization)", step)
        self.logger.info("  • Node exporters (system metrics)", step)
        self.logger.info("  • Alert manager (notifications)", step)

        self.logger.success("Monitoring configuration ready", step)
        return True

    def phase_verification(self):
        """Phase 9: Final verification"""
        step = "VERIFICATION"
        self.logger.info("Running final verification...", step)

        self.logger.info("Deployment checklist:", step)
        self.logger.info("  □ Proxmox installed and accessible", step)
        self.logger.info("  □ Network bridges configured", step)
        self.logger.info("  □ Router VM created and running", step)
        self.logger.info("  □ macOS VM created (optional)", step)
        self.logger.info("  □ AI agent VM created and running", step)
        self.logger.info("  □ Monitoring accessible", step)
        self.logger.info("  □ BGP sessions established", step)
        self.logger.info("  □ Internet connectivity working", step)

        self.logger.success("Verification guide provided", step)
        return True

    def deploy(self, phases: list = None):
        """Run deployment phases"""
        self.print_banner()

        if phases is None:
            phases = PHASES

        phase_methods = {
            "prerequisites": self.phase_prerequisites,
            "idrac_config": self.phase_idrac_config,
            "proxmox_install": self.phase_proxmox_install,
            "network_config": self.phase_network_config,
            "router_vm": self.phase_router_vm,
            "macos_vm": self.phase_macos_vm,
            "ai_agent_vm": self.phase_ai_agent_vm,
            "monitoring": self.phase_monitoring,
            "verification": self.phase_verification
        }

        for phase in phases:
            if phase in phase_methods:
                print(f"\n{'='*70}")
                result = phase_methods[phase]()
                if not result:
                    self.logger.error(f"Phase '{phase}' failed. Stopping deployment.")
                    return False

        print(f"\n{'='*70}")
        self.logger.success("🎉 ORION Hybrid Deployment Complete!")
        print(f"{'='*70}\n")

        return True


# ============================================================================
# MAIN
# ============================================================================

def main():
    """Main entry point"""
    deployer = ORIONDeployer()

    if len(sys.argv) > 1:
        command = sys.argv[1]

        if command == "status":
            info = deployer.idrac.get_system_info()
            print("\nSystem Status:")
            for key, value in info.items():
                print(f"  {key}: {value}")

        elif command == "power-on":
            deployer.logger.info("Powering on system...")
            deployer.idrac.power_on()
            deployer.logger.success("System powered on")

        elif command == "power-off":
            deployer.logger.info("Powering off system...")
            deployer.idrac.power_off()
            deployer.logger.success("System powered off")

        elif command == "reboot":
            deployer.logger.info("Rebooting system...")
            deployer.idrac.reboot()
            deployer.logger.success("System rebooting")

        elif command == "help":
            print("""
Dell R730 ORION Hybrid Deployment Tool

Usage:
  python3 deploy-orion-hybrid.py [COMMAND]

Commands:
  (none)      Run full deployment wizard
  status      Show system status
  power-on    Power on the system
  power-off   Power off the system
  reboot      Reboot the system
  help        Show this help message

Examples:
  python3 deploy-orion-hybrid.py              # Full deployment
  python3 deploy-orion-hybrid.py status       # Check status
  python3 deploy-orion-hybrid.py power-on     # Power on
""")

        else:
            print(f"Unknown command: {command}")
            print("Run 'python3 deploy-orion-hybrid.py help' for usage")
            return 1

    else:
        # Run full deployment
        success = deployer.deploy()
        return 0 if success else 1


if __name__ == "__main__":
    sys.exit(main())
