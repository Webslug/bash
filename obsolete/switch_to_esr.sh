#!/bin/bash
# =============================================================================
# switch_to_firefox_esr.sh
# Replaces snap Firefox with Firefox ESR from the Mozilla PPA.
#
# WHY: Snap Firefox hard-ignores xpinstall.signatures.required=false
#      and sandboxes file:// URLs. ESR respects both, and is what
#      schools and enterprises actually use for managed deployments.
#
# USAGE:
#   sudo bash switch_to_firefox_esr.sh           # do the switch
#   bash switch_to_firefox_esr.sh --check         # just check current state
#
# IMPORTANT: This will close Firefox. Save your work first.
# =============================================================================

set -euo pipefail

CHECK_ONLY=false
[[ "${1:-}" == "--check" ]] && CHECK_ONLY=true

log() { echo "[$(date '+%H:%M:%S')] $1"; }

# --- Check current state -----------------------------------------------------

check_state() {
    echo ""
    echo "=== Firefox Installation Check ==="

    if snap list firefox &>/dev/null 2>&1; then
        echo "  Firefox: SNAP (this is the problem)"
        echo "  Version: $(snap list firefox 2>/dev/null | tail -1 | awk '{print $2}')"
    elif dpkg -l firefox-esr 2>/dev/null | grep -q '^ii'; then
        echo "  Firefox: ESR (deb) — this is what you want"
        echo "  Version: $(firefox-esr --version 2>/dev/null || echo 'unknown')"
    elif dpkg -l firefox 2>/dev/null | grep -q '^ii'; then
        echo "  Firefox: deb (non-ESR)"
        echo "  Version: $(firefox --version 2>/dev/null || echo 'unknown')"
    else
        echo "  Firefox: NOT FOUND"
    fi

    echo ""
    echo "=== Policies Check ==="

    for path in /etc/firefox/policies/policies.json /etc/firefox-esr/policies/policies.json; do
        if [ -f "$path" ]; then
            echo "  FOUND: $path ($(stat -c '%s' "$path") bytes)"
        else
            echo "  MISSING: $path"
        fi
    done

    echo ""
    echo "=== Extension XPI Check ==="

    for path in /etc/firefox/policies/extensions /etc/firefox-esr/policies/extensions; do
        local xpi="$path/governor@nursery.local.xpi"
        if [ -f "$xpi" ]; then
            echo "  FOUND: $xpi ($(stat -c '%s' "$xpi") bytes)"
        else
            echo "  MISSING: $xpi"
        fi
    done

    echo ""
}

if $CHECK_ONLY; then
    check_state
    exit 0
fi

# --- Require root ------------------------------------------------------------

if [ "$(id -u)" -ne 0 ]; then
    echo "This script requires root. Run with: sudo bash $0"
    exit 1
fi

# --- Confirm with user -------------------------------------------------------

echo ""
echo "This will:"
echo "  1. Remove snap Firefox"
echo "  2. Install Firefox ESR from Mozilla PPA"
echo "  3. Set up policies paths for ESR"
echo ""
echo "Firefox will be closed. Save your work first."
echo ""
read -rp "Continue? [y/N] " confirm
[[ "$confirm" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 0; }

# --- Step 1: Kill Firefox ----------------------------------------------------

log "Closing Firefox..."
pkill -f firefox 2>/dev/null || true
sleep 2

# --- Step 2: Remove snap Firefox --------------------------------------------

if snap list firefox &>/dev/null 2>&1; then
    log "Removing snap Firefox..."
    snap remove firefox --purge 2>/dev/null || snap remove firefox
    log "Snap Firefox removed."
else
    log "Snap Firefox not installed — skipping removal."
fi

# --- Step 3: Block snap from reinstalling Firefox ----------------------------

log "Blocking snap Firefox from being reinstalled..."
mkdir -p /etc/apt/preferences.d

cat > /etc/apt/preferences.d/no-snap-firefox << 'EOF'
Package: firefox
Pin: origin "snapcraft.io"
Pin-Priority: -1
EOF

# --- Step 4: Add Mozilla PPA ------------------------------------------------

log "Adding Mozilla Team PPA..."
if ! grep -r "mozillateam" /etc/apt/sources.list.d/ &>/dev/null; then
    add-apt-repository ppa:mozillateam/ppa -y
else
    log "Mozilla PPA already present."
fi

# --- Step 5: Pin PPA version higher than snap --------------------------------

log "Setting PPA priority..."
cat > /etc/apt/preferences.d/mozilla-firefox << 'EOF'
Package: firefox*
Pin: release o=LP-PPA-mozillateam
Pin-Priority: 1001
EOF

# --- Step 6: Install Firefox ESR ---------------------------------------------

log "Installing Firefox ESR..."
apt update -qq
apt install firefox-esr -y

log "Firefox ESR installed: $(firefox-esr --version 2>/dev/null || echo 'check manually')"

# --- Step 7: Set up policies paths for ESR -----------------------------------

log "Setting up policies paths..."

# ESR may look in /etc/firefox-esr/policies/ instead of /etc/firefox/policies/
# Create symlinks so both paths work

mkdir -p /etc/firefox/policies/extensions
mkdir -p /etc/firefox-esr/policies

# If policies.json exists in the original path, symlink for ESR
if [ -f /etc/firefox/policies/policies.json ]; then
    ln -sf /etc/firefox/policies/policies.json /etc/firefox-esr/policies/policies.json
    log "Symlinked policies.json for ESR"
fi

# Symlink extensions directory
if [ -d /etc/firefox/policies/extensions ]; then
    ln -sf /etc/firefox/policies/extensions /etc/firefox-esr/policies/extensions
    log "Symlinked extensions directory for ESR"
fi

# --- Done --------------------------------------------------------------------

echo ""
log "============================================="
log "Switch complete!"
log ""
log "Firefox ESR is now installed."
log "Your existing policies.json and XPI are symlinked."
log ""
log "Next steps:"
log "  1. Run your install_extension.sh to ensure XPI is in place"
log "  2. Open Firefox ESR"
log "  3. Go to about:policies — should say 'Active'"
log "  4. Extension should load and enforce whitelist"
log "============================================="
echo ""

check_state
