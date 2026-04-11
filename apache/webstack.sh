#!/bin/bash

LOG_FILE="$HOME/.local/share/webstack_toggle.log"
SERVICES=("apache2" "mariadb")

log() {
    local MSG="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo "$MSG"
    echo "$MSG" >> "$LOG_FILE"
}

notify() {
    local TITLE="$1"
    local BODY="$2"
    local ICON="$3"
    notify-send "$TITLE" "$BODY" --icon="$ICON" 2>/dev/null || true
}

service_state() {
    systemctl is-active "$1" 2>/dev/null
}

log "========== webstack_toggle invoked by $USER =========="

APACHE_STATE=$(service_state apache2)
MYSQL_STATE=$(service_state mariadb)

log "Current state — apache2: $APACHE_STATE | mariadb: $MYSQL_STATE"

if [ "$APACHE_STATE" = "active" ] && [ "$MYSQL_STATE" = "active" ]; then
    ACTION="stop"
    log "Both services active. Stopping both."
elif [ "$APACHE_STATE" = "inactive" ] && [ "$MYSQL_STATE" = "inactive" ]; then
    ACTION="start"
    log "Both services inactive. Starting both."
else
    ACTION="stop"
    log "Mixed state detected. Stopping both to restore baseline."
fi

export ACTION
export SERVICES_STR="${SERVICES[*]}"

pkexec env ACTION="$ACTION" SERVICES_STR="$SERVICES_STR" bash -c '
set -e
for SVC in $SERVICES_STR; do
    if [ "$ACTION" = "start" ]; then
        systemctl disable "$SVC" >/dev/null 2>&1 || true
        systemctl start "$SVC"
    else
        systemctl stop "$SVC" || true
        systemctl disable "$SVC" >/dev/null 2>&1 || true
    fi
done
'

RESULT=$?

APACHE_FINAL=$(service_state apache2)
MYSQL_FINAL=$(service_state mariadb)

log "Final state — apache2: $APACHE_FINAL | mariadb: $MYSQL_FINAL"

if [ $RESULT -eq 0 ]; then
    if [ "$ACTION" = "start" ]; then
        notify "Web Stack" "apache2: $APACHE_FINAL | mariadb: $MYSQL_FINAL" "network-transmit-receive"
        log "Web stack STARTED."
    else
        notify "Web Stack" "Services stopped. Stack offline." "network-offline"
        log "Web stack STOPPED."
    fi
else
    notify "Web Stack" "Action failed." "dialog-error"
    log "ERROR: pkexec action failed."
fi

log "========== webstack_toggle complete =========="
