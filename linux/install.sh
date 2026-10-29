#!/usr/bin/env bash
# =====================================================================
#  Worm-Crawler Defender for Linux - installer (made by REDAOT)
#  Auto-detects the distribution and init system, and does everything.
#  Run:  sudo ./install.sh     (or: ./install.sh  -> it asks for sudo itself)
# =====================================================================
set -u
SRC="$(cd "$(dirname "$0")" && pwd)/worm-crawler-defender"
PROG_DIR="/opt/worm-crawler-defender"
BINDIR="/usr/local/bin"
UNITDIR="/etc/systemd/system"

# --- auto-sudo ---
if [ "$(id -u)" -ne 0 ]; then
    echo "Administrator rights are required (sudo)..."
    exec sudo -- "$0" "$@"
fi

# version from the library
. "$SRC/wcd-lib.sh"

echo "=================================================="
echo "   WORM-CRAWLER DEFENDER $WCD_VERSION (Linux)  -  made by REDAOT"
echo "=================================================="

# --- 1. detect environment ---
DISTRO="unknown"
[ -r /etc/os-release ] && . /etc/os-release && DISTRO="${PRETTY_NAME:-$ID}"
if pidof systemd >/dev/null 2>&1 || [ -d /run/systemd/system ]; then INIT="systemd"; else INIT="other"; fi
echo "[i] Distribution : $DISTRO"
echo "[i] Init         : $INIT"

command -v bash >/dev/null || { echo "ERROR: bash is missing."; exit 1; }
if ! command -v python3 >/dev/null && ! command -v openssl >/dev/null; then
    echo "ERROR: python3 OR openssl is required for the PIN."
    echo "       Install one, e.g. 'sudo apt install python3' or 'sudo dnf install python3'."
    exit 1
fi
command -v ip   >/dev/null || echo "[!] 'ip' is missing; network blocking relies on nmcli if present."
command -v nmcli >/dev/null && echo "[i] Network      : NetworkManager (nmcli)" || echo "[i] Network      : via 'ip link'"
command -v zenity >/dev/null || command -v kdialog >/dev/null || command -v notify-send >/dev/null || command -v xmessage >/dev/null \
    || echo "[!] No graphical alert tool (zenity/kdialog/notify-send/xmessage). Alerts will only appear in the terminal ('wall')."

# --- 2. PIN (separate folder, survives deletion of /opt) ---
wcd_dirs
if wcd_pin_exists; then
    echo; echo "Worm-Crawler Defender is already installed. Reinstall requires the PIN."
    if ! wcd_pin_prompt "reinstall"; then echo "Wrong PIN. Installation cancelled."; exit 1; fi
    read -r -p "Do you want to change the PIN? (y/N): " r
    case "$r" in [yY]*) wcd_pin_set ;; esac
    date +%s > "$AUTH_FLAG"
    [ "$INIT" = systemd ] && systemctl stop worm-crawler-defender.service >/dev/null 2>&1
else
    echo; echo "Choose a 4-digit PIN. You will use it to unlock the internet,"
    echo "stop the protection, and uninstall the program."
    wcd_pin_set || exit 1
fi

# --- 3. copy files ---
mkdir -p "$PROG_DIR"
cp -f "$SRC"/wcd-*.sh "$PROG_DIR"/ 2>/dev/null
cp -f "$SRC"/wormcrawler.png "$PROG_DIR"/ 2>/dev/null
chmod 755 "$PROG_DIR"/wcd-*.sh
chown -R root:root "$PROG_DIR"
echo "[OK] Files copied to $PROG_DIR"

ln -sf "$PROG_DIR/wcd-unlock.sh"  "$BINDIR/wcd-unlock"
ln -sf "$PROG_DIR/wcd-protect.sh" "$BINDIR/wcd-protect"
ln -sf "$PROG_DIR/wcd-test.sh"    "$BINDIR/wcd-test"
echo "[OK] Commands: wcd-unlock, wcd-protect, wcd-test"

# --- 4. automatic start ---
if [ "$INIT" = systemd ]; then
    cat > "$UNITDIR/worm-crawler-defender.service" <<EOF
[Unit]
Description=Worm-Crawler Defender (made by REDAOT)
After=network.target
[Service]
Type=simple
ExecStart=$PROG_DIR/wcd-monitor.sh
Restart=always
RestartSec=5
[Install]
WantedBy=multi-user.target
EOF
    cat > "$UNITDIR/wcd-watchdog.service" <<EOF
[Unit]
Description=Worm-Crawler Defender - watchdog (made by REDAOT)
[Service]
Type=oneshot
ExecStart=$PROG_DIR/wcd-watchdog.sh
EOF
    cat > "$UNITDIR/wcd-watchdog.timer" <<EOF
[Unit]
Description=Worm-Crawler Defender - check every minute (made by REDAOT)
[Timer]
OnBootSec=60
OnUnitActiveSec=60
AccuracySec=10
[Install]
WantedBy=timers.target
EOF
    systemctl daemon-reload
    systemctl enable --now worm-crawler-defender.service >/dev/null 2>&1
    systemctl enable --now wcd-watchdog.timer >/dev/null 2>&1
    rm -f "$AUTH_FLAG"
    sleep 3
    if systemctl is-active --quiet worm-crawler-defender.service; then
        echo "[OK] The service is RUNNING (systemd). Log: $LOG_FILE"
    else
        echo "[!] The service did not start. Check: systemctl status worm-crawler-defender"
    fi
else
    # fallback without systemd: boot supervisor + watchdog in cron
    SUP="$PROG_DIR/wcd-supervise.sh"
    cat > "$SUP" <<EOF
#!/usr/bin/env bash
while true; do "$PROG_DIR/wcd-monitor.sh"; sleep 3; done
EOF
    chmod 755 "$SUP"
    ( crontab -l 2>/dev/null | grep -v 'worm-crawler-defender'; \
      echo "@reboot $SUP >/dev/null 2>&1 &"; \
      echo "* * * * * $PROG_DIR/wcd-watchdog.sh >/dev/null 2>&1" ) | crontab -
    nohup "$SUP" >/dev/null 2>&1 &
    rm -f "$AUTH_FLAG"
    echo "[OK] Started via cron @reboot + supervisor (system without systemd)."
fi

# graphical shortcut (optional, if a desktop environment is present)
if [ -d /usr/share/applications ]; then
    cat > /usr/share/applications/worm-crawler-defender.desktop <<EOF
[Desktop Entry]
Type=Application
Name=Worm-Crawler Defender - Unlock Internet
Exec=pkexec $PROG_DIR/wcd-unlock.sh
Icon=$PROG_DIR/wormcrawler.png
Terminal=true
Categories=Security;System;
EOF
fi

echo
echo "Done. Test with:   sudo wcd-test"
echo "Status:            wcd-protect status"
echo "made by REDAOT  -  $WCD_VERSION"
