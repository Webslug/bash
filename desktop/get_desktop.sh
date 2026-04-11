#!/bin/bash
echo $XDG_CURRENT_DESKTOP
systemctl status display-manager | grep "Loaded"
