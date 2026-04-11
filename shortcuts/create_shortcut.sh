#!/usr/bin/env bash
set -euo pipefail

ROOT="/home/kim/projects/echo"
CONTROL_SCRIPT="$ROOT/tts_daemon_turbo.py"
MENU_SCRIPT="$ROOT/echo_tts_command_menu.sh"

DESKTOP_DIR="$(xdg-user-dir DESKTOP 2>/dev/null || printf '%s/Desktop' "$HOME")"
APP_DIR="$HOME/.local/share/applications"
DESKTOP_FILE_APP="$APP_DIR/echo-tts-command-menu.desktop"
DESKTOP_FILE_DESKTOP="$DESKTOP_DIR/echo-tts-command-menu.desktop"

mkdir -p "$APP_DIR" "$DESKTOP_DIR"

if [[ ! -f "$CONTROL_SCRIPT" ]]; then
    echo "Missing controller: $CONTROL_SCRIPT"
    exit 1
fi

cat > "$MENU_SCRIPT" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

ROOT="/home/kim/projects/echo"
CONTROL_SCRIPT="$ROOT/tts_daemon_turbo.py"

pause() {
    printf '\nPress Enter to continue...'
    read -r
}

run_cmd() {
    echo
    echo "----------------------------------------"
    echo "Running: $*"
    echo "----------------------------------------"
    "$@" || true
    echo
}

while true; do
    clear
    echo "========================================"
    echo " Echo TTS Turbo Command Menu"
    echo "========================================"
    echo
    python3 "$CONTROL_SCRIPT" status || true
    echo
    echo "1. Start daemon"
    echo "2. Stop daemon"
    echo "3. Speak text"
    echo "4. Install user unit"
    echo "5. Uninstall user unit"
    echo "6. Status"
    echo "7. Toggle start/stop"
    echo "8. Exit"
    echo
    printf "Choose an option [1-8]: "
    read -r choice

    case "$choice" in
        1)
            run_cmd python3 "$CONTROL_SCRIPT" start
            pause
            ;;
        2)
            run_cmd python3 "$CONTROL_SCRIPT" stop
            pause
            ;;
        3)
            echo
            printf "Enter text to speak: "
            read -r text
            if [[ -z "${text// }" ]]; then
                echo
                echo "No text entered."
            else
                run_cmd python3 "$CONTROL_SCRIPT" speak "$text"
            fi
            pause
            ;;
        4)
            run_cmd python3 "$CONTROL_SCRIPT" install
            pause
            ;;
        5)
            run_cmd python3 "$CONTROL_SCRIPT" uninstall
            pause
            ;;
        6)
            run_cmd python3 "$CONTROL_SCRIPT" status
            pause
            ;;
        7)
            run_cmd python3 "$CONTROL_SCRIPT"
            pause
            ;;
        8)
            exit 0
            ;;
        *)
            echo
            echo "Invalid option."
            pause
            ;;
    esac
done
EOF

chmod +x "$MENU_SCRIPT"

cat > "$DESKTOP_FILE_APP" <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Echo TTS Commands
Comment=Run Echo TTS Turbo controller commands
Exec=/bin/bash -lc '$MENU_SCRIPT'
Icon=audio-speakers
Terminal=true
Categories=Utility;AudioVideo;
StartupNotify=true
EOF

cp "$DESKTOP_FILE_APP" "$DESKTOP_FILE_DESKTOP"
chmod +x "$DESKTOP_FILE_DESKTOP"

update-desktop-database "$APP_DIR" >/dev/null 2>&1 || true

echo
echo "Created:"
echo "  $MENU_SCRIPT"
echo "  $DESKTOP_FILE_APP"
echo "  $DESKTOP_FILE_DESKTOP"
echo
echo "Launcher name:"
echo "  Echo TTS Commands"
