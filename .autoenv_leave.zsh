# ORION Auto-Environment - Cleanup
# Automatically executed when leaving this directory via zsh-autoenv

# Deactivate Python virtual environment
if [[ -n "$VIRTUAL_ENV" ]]; then
    deactivate 2>/dev/null || true
fi

# Remove ORION scripts from PATH
if [[ -n "$ORION_ROOT" ]]; then
    autoenv_remove_path "$ORION_ROOT/scripts"
    autoenv_remove_path "$ORION_ROOT/tools"
fi

# Unset ORION-specific aliases
unalias orion-deploy 2>/dev/null || true
unalias orion-status 2>/dev/null || true
unalias orion-reboot 2>/dev/null || true
unalias orion-power-on 2>/dev/null || true
unalias orion-power-off 2>/dev/null || true
unalias orion-pre-check 2>/dev/null || true
unalias orion-post-check 2>/dev/null || true
unalias orion-validate 2>/dev/null || true
unalias ssh-router 2>/dev/null || true
unalias ssh-agent-vm 2>/dev/null || true
unalias ssh-macos 2>/dev/null || true
unalias grafana 2>/dev/null || true
unalias prometheus 2>/dev/null || true
unalias proxmox 2>/dev/null || true
unalias idrac 2>/dev/null || true
unalias orion-metrics 2>/dev/null || true
unalias orion-bgp 2>/dev/null || true
unalias orion-routes 2>/dev/null || true
unalias orion-firewall 2>/dev/null || true
unalias router-logs 2>/dev/null || true
unalias agent-logs 2>/dev/null || true
unalias bird-logs 2>/dev/null || true
unalias orion-restart-bgp 2>/dev/null || true
unalias orion-restart-agent 2>/dev/null || true
unalias orion-restart-grafana 2>/dev/null || true
unalias orion-docs 2>/dev/null || true
unalias orion-quickstart 2>/dev/null || true
unalias orion-checklist 2>/dev/null || true
unalias vm-list 2>/dev/null || true
unalias vm-router 2>/dev/null || true
unalias vm-agent 2>/dev/null || true
unalias vm-macos 2>/dev/null || true
unalias vm-start-router 2>/dev/null || true
unalias vm-start-agent 2>/dev/null || true
unalias vm-start-macos 2>/dev/null || true

# Unset ORION-specific functions
unfunction orion-overview 2>/dev/null || true
unfunction orion-help 2>/dev/null || true
unfunction orion-test 2>/dev/null || true

# Unset ORION environment variables
unset ORION_ROOT
unset ORION_VERSION
unset IDRAC_IP
unset IDRAC_USER
unset IDRAC_PASS
unset PROXMOX_IP
unset PROXMOX_PORT
unset PROXMOX_USER
unset ROUTER_IP
unset AI_AGENT_IP
unset MACOS_VM_IP
unset GRAFANA_PORT
unset PROMETHEUS_PORT
unset NODE_EXPORTER_PORT
unset BGP_LOCAL_AS
unset BGP_REMOTE_AS

# Goodbye message
echo "👋 ORION environment unloaded"
