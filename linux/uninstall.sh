#!/usr/bin/env bash
# Worm-Crawler Defender for Linux - uninstall (asks for the PIN). made by REDAOT
set -u
PROG_DIR="/opt/worm-crawler-defender"
BINDIR="/usr/local/bin"
UNITDIR="/etc/systemd/system"
LIB="$PROG_DIR/wcd-lib.sh"
[ -r "$LIB" ] || LIB="$(cd "$(dirname "$0")" && pwd)/worm-crawler-defender/wcd-lib.sh"

if [ "$(id -u)" -ne 0 ]; then echo "Re-running with sudo..."; exec sudo -- "$0" "$@"; fi
. "$LIB"

echo "== Worm-Crawler Defender $WCD_VERSION - Uninstall =="
if wcd_pin_exists; then
    if ! wcd_pin_prompt "uninstall"; then echo "Wrong PIN. Uninstall cancelled."; exit 1; fi
fi

# authorized stop, so the watchdog does not block the network during uninstall
wcd_dirs; date +%s > "$AUTH_FLAG"

if have systemctl; then
    systemctl disable --now worm-crawler-defender.service >/dev/null 2>&1
    systemctl disable --now wcd-watchdog.timer >/dev/null 2>&1
    rm -f "$UNITDIR/worm-crawler-defender.service" "$UNITDIR/wcd-watchdog.service" "$UNITDIR/wcd-watchdog.timer"
    systemctl daemon-reload
else
    crontab -l 2>/dev/null | grep -v 'worm-crawler-defender' | crontab -
    pkill -f 'worm-crawler-defender/wcd-' 2>/dev/null
fi

# unblock the network if it was blocked
[ -f "$BLOCK_FLAG" ] && wcd_net_restore

rm -f "$BINDIR/wcd-unlock" "$BINDIR/wcd-protect" "$BINDIR/wcd-test"
rm -f /usr/share/applications/worm-crawler-defender.desktop
rm -rf "$PROG_DIR" "$VAR_DIR" "$RUN_DIR"
rm -rf /etc/worm-crawler-defender          # includes the PIN-protected folder
echo "Worm-Crawler Defender has been uninstalled."
echo "made by REDAOT  -  $WCD_VERSION"
