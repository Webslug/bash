#!/usr/bin/env bash
set -euo pipefail

APP_NAME="Firefox Kiddle Kiosk"
DESKTOP_ID="firefox-kiddle-kiosk.desktop"
URL="https://www.kiddle.co"

REMOVE_FIREFOX_SHORTCUTS=false
ICON_STYLE="blocks"   # blocks | rattle

USER_HOME="${HOME}"
LOCAL_APPS_DIR="${USER_HOME}/.local/share/applications"
LOCAL_BIN_DIR="${USER_HOME}/.local/bin"
LOCAL_ICON_DIR="${USER_HOME}/.local/share/icons"
LXQT_DIR="${USER_HOME}/.config/lxqt"
PANEL_CONF="${LXQT_DIR}/panel.conf"
BACKUP_DIR="${LXQT_DIR}/backups"
STAMP="$(date +%Y%m%d_%H%M%S)"

WRAPPER="${LOCAL_BIN_DIR}/firefox-kiddle-kiosk.sh"
DESKTOP_FILE="${LOCAL_APPS_DIR}/${DESKTOP_ID}"
ICON_FILE="${LOCAL_ICON_DIR}/firefox-kiddle-kiosk.svg"

mkdir -p "${LOCAL_APPS_DIR}" "${LOCAL_BIN_DIR}" "${LOCAL_ICON_DIR}" "${LXQT_DIR}" "${BACKUP_DIR}"

cat > "${WRAPPER}" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

URL="https://www.kiddle.co"

if command -v firefox-esr >/dev/null 2>&1; then
    exec firefox-esr --kiosk "$URL"
elif command -v firefox >/dev/null 2>&1; then
    exec firefox --kiosk "$URL"
else
    echo "Firefox not found."
    exit 1
fi
EOF
chmod +x "${WRAPPER}"

if [ "${ICON_STYLE}" = "rattle" ]; then
cat > "${ICON_FILE}" <<'EOF'
<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128">
  <rect width="128" height="128" rx="24" fill="#fff7fb"/>
  <circle cx="48" cy="42" r="24" fill="#ffb3d9" stroke="#d63384" stroke-width="6"/>
  <circle cx="40" cy="36" r="5" fill="#ffffff"/>
  <rect x="64" y="58" width="14" height="40" rx="7" transform="rotate(35 71 78)" fill="#ffd166" stroke="#cc9a00" stroke-width="4"/>
  <circle cx="87" cy="95" r="8" fill="#8ecae6" stroke="#4a90a4" stroke-width="3"/>
</svg>
EOF
else
cat > "${ICON_FILE}" <<'EOF'
<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128">
  <rect width="128" height="128" rx="24" fill="#fff7fb"/>
  <rect x="18" y="54" width="34" height="34" rx="6" fill="#ff8fab" stroke="#d63384" stroke-width="4"/>
  <rect x="47" y="36" width="34" height="34" rx="6" fill="#ffd166" stroke="#cc9a00" stroke-width="4"/>
  <rect x="76" y="54" width="34" height="34" rx="6" fill="#90dbf4" stroke="#4a90a4" stroke-width="4"/>
  <text x="35" y="77" font-size="16" text-anchor="middle" fill="#ffffff" font-family="sans-serif" font-weight="700">A</text>
  <text x="64" y="59" font-size="16" text-anchor="middle" fill="#ffffff" font-family="sans-serif" font-weight="700">B</text>
  <text x="93" y="77" font-size="16" text-anchor="middle" fill="#ffffff" font-family="sans-serif" font-weight="700">C</text>
</svg>
EOF
fi

cat > "${DESKTOP_FILE}" <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=${APP_NAME}
Comment=Launch Firefox in kiosk mode with Kiddle
Exec=${WRAPPER}
Icon=${ICON_FILE}
Terminal=false
Categories=Network;WebBrowser;
StartupNotify=false
EOF

if [ -f "${PANEL_CONF}" ]; then
    cp "${PANEL_CONF}" "${BACKUP_DIR}/panel.conf.${STAMP}.bak"
else
    echo "No ${PANEL_CONF} found. Desktop file created, but there is no panel config to patch."
    echo "You may need to add the launcher manually to the LXQt panel."
    exit 0
fi

python3 <<PY
from pathlib import Path
import re

panel_conf = Path("${PANEL_CONF}")
desktop_file = "${DESKTOP_FILE}"
text = panel_conf.read_text(encoding="utf-8")

changed = False

pattern = re.compile(r'^(apps\\\\\d+\\\\desktop=)(.*firefox.*\.desktop.*)$', re.IGNORECASE | re.MULTILINE)

def repl(m):
    return f"{m.group(1)}{desktop_file}"

new_text, count = pattern.subn(repl, text)
if count > 0:
    changed = True

if not changed:
    lines = text.splitlines()
    quicklaunch_start = None
    quicklaunch_end = None

    for i, line in enumerate(lines):
        s = line.strip()
        if s.startswith("[") and s.endswith("]"):
            section = s[1:-1].strip().lower()
            if section.startswith("quicklaunch"):
                quicklaunch_start = i
                continue
            if quicklaunch_start is not None and quicklaunch_end is None:
                quicklaunch_end = i
                break

    if quicklaunch_start is not None:
        if quicklaunch_end is None:
            quicklaunch_end = len(lines)

        max_idx = 0
        idx_pat = re.compile(r'^apps\\\\(\d+)\\\\desktop=')
        for line in lines[quicklaunch_start:quicklaunch_end]:
            m = idx_pat.match(line.strip())
            if m:
                max_idx = max(max_idx, int(m.group(1)))

        insert_line = f"apps\\\\{max_idx + 1}\\\\desktop={desktop_file}"
        lines.insert(quicklaunch_end, insert_line)
        new_text = "\n".join(lines) + ("\n" if text.endswith("\n") else "")
        changed = True

if changed:
    panel_conf.write_text(new_text, encoding="utf-8")
    print("Patched panel.conf successfully.")
else:
    print("No quicklaunch Firefox entry found and no quicklaunch block detected.")
    print("Desktop launcher was created, but panel replacement was not possible automatically.")
PY

if [ "${REMOVE_FIREFOX_SHORTCUTS}" = "true" ]; then
    find "${LOCAL_APPS_DIR}" -maxdepth 1 -type f \
        \( -iname '*firefox*.desktop' -o -iname '*firefox-esr*.desktop' \) \
        ! -iname "${DESKTOP_ID}" \
        -print -delete || true
fi

pkill -x lxqt-panel >/dev/null 2>&1 || true
nohup lxqt-panel >/dev/null 2>&1 & disown || true

echo
echo "Done."
echo "Launcher created: ${DESKTOP_FILE}"
echo "Wrapper created:  ${WRAPPER}"
echo "Icon created:     ${ICON_FILE}"
echo "Panel backup:     ${BACKUP_DIR}/panel.conf.${STAMP}.bak"
echo
echo "If the icon does not change immediately, log out and back in."
