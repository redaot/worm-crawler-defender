#!/usr/bin/env bash
# Worm-Crawler Defender - stop / start protection, change PIN. made by REDAOT
#   wcd-protect stop      (asks for PIN)
#   wcd-protect start
#   wcd-protect pin       (asks for the old PIN, then sets a new one)
#   wcd-protect status
set -u
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$DIR/wcd-lib.sh"
ACT="${1:-status}"
if [ "$ACT" != status ] && [ "$(id -u)" -ne 0 ]; then echo "Run with: sudo wcd-protect $ACT"; exit 1; fi

case "$ACT" in
    stop)
        if ! wcd_pin_prompt "stopping the protection"; then echo "Wrong PIN. The protection stays on."; exit 1; fi
        wcd_dirs; date +%s > "$AUTH_FLAG"
        have systemctl && systemctl stop worm-crawler-defender.service >/dev/null 2>&1
        wcd_log "Protection STOPPED by the user (correct PIN)."
        echo "Protection is OFF. It starts again at the next boot, or with: sudo wcd-protect start"
        ;;
    start)
        rm -f "$AUTH_FLAG"
        have systemctl && systemctl start worm-crawler-defender.service >/dev/null 2>&1
        wcd_log "Protection STARTED by the user."
        echo "Protection is ON."
        ;;
    pin)
        if ! wcd_pin_prompt "changing the PIN"; then echo "Wrong PIN. The PIN was not changed."; exit 1; fi
        wcd_pin_set && wcd_log "PIN changed by the user."
        ;;
    status)
        if [ -f "$AUTH_FLAG" ]; then echo "Protection: STOPPED (with PIN)"
        elif have systemctl && systemctl is-active --quiet worm-crawler-defender.service; then echo "Protection: ACTIVE"
        else echo "Protection: NOT RUNNING"; fi
        [ -f "$BLOCK_FLAG" ] && echo "Internet: BLOCKED (unlock with: sudo wcd-unlock)" || echo "Internet: free"
        ;;
    *) echo "Usage: wcd-protect {stop|start|pin|status}"; exit 1 ;;
esac
echo "made by REDAOT"
