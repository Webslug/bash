#!/bin/bash
# nursery-mkdir.sh
# Creates the canonical /opt/nursery folder structure per project spec Section 4.
# Safe to run multiple times — mkdir -p skips existing dirs.
# Run as: sudo bash nursery-mkdir.sh

set -euo pipefail

echo "=== Nursery Guardian: Folder Scaffold ==="

# /opt/nursery tree
sudo mkdir -p /opt/nursery/assets
sudo mkdir -p /opt/nursery/config
sudo mkdir -p /opt/nursery/db
sudo mkdir -p /opt/nursery/ext
sudo mkdir -p /opt/nursery/guardian
sudo mkdir -p /opt/nursery/scripts
sudo mkdir -p /opt/nursery/scores

# Log dir lives under /var/log, not /opt
sudo mkdir -p /var/log/nursery

# Set ownership — root owns everything
sudo chown -R root:root /opt/nursery
sudo chown -R root:root /var/log/nursery

# Permissions
sudo chmod 755 /opt/nursery
sudo chmod 755 /opt/nursery/assets
sudo chmod 755 /opt/nursery/config
sudo chmod 755 /opt/nursery/db
sudo chmod 755 /opt/nursery/ext
sudo chmod 755 /opt/nursery/guardian
sudo chmod 755 /opt/nursery/scripts
sudo chmod 750 /opt/nursery/scores      # slightly tighter — future AI outputs
sudo chmod 755 /var/log/nursery

echo ""
echo "=== Result ==="
find /opt/nursery /var/log/nursery -maxdepth 1 -type d | sort
echo ""
echo "Done. Verify with: ls -la /opt/nursery"
