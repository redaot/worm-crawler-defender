#!/usr/bin/env bash
# Worm-Crawler Defender - opreste / porneste protectia, schimba PIN. made by REDAOT
#   wcd-protect stop      (cere PIN)
#   wcd-protect start
#   wcd-protect pin       (cere PIN vechi, apoi seteaza unul nou)
#   wcd-protect status
set -u
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$DIR/wcd-lib.sh"
ACT="${1:-status}"
if [ "$ACT" != status ] && [ "$(id -u)" -ne 0 ]; then echo "Ruleaza cu: sudo wcd-protect $ACT"; exit 1; fi

case "$ACT" in
    stop)
        if ! wcd_pin_prompt "oprirea protectiei"; then echo "PIN gresit. Protectia ramane pornita."; exit 1; fi
        wcd_dirs; date +%s > "$AUTH_FLAG"
        have systemctl && systemctl stop worm-crawler-defender.service >/dev/null 2>&1
        wcd_log "Protectie OPRITA de utilizator (PIN corect)."
        echo "Protectia e OPRITA. Porneste automat la urmatorul boot, sau cu: sudo wcd-protect start"
        ;;
    start)
        rm -f "$AUTH_FLAG"
        have systemctl && systemctl start worm-crawler-defender.service >/dev/null 2>&1
        wcd_log "Protectie PORNITA de utilizator."
        echo "Protectia e PORNITA."
        ;;
    pin)
        if ! wcd_pin_prompt "schimbarea PIN-ului"; then echo "PIN gresit. PIN-ul nu a fost schimbat."; exit 1; fi
        wcd_pin_set && wcd_log "PIN schimbat de utilizator."
        ;;
    status)
        if [ -f "$AUTH_FLAG" ]; then echo "Protectie: OPRITA (cu PIN)"
        elif have systemctl && systemctl is-active --quiet worm-crawler-defender.service; then echo "Protectie: ACTIVA"
        else echo "Protectie: NU RULEAZA"; fi
        [ -f "$BLOCK_FLAG" ] && echo "Internet: BLOCAT (deblocheaza cu: sudo wcd-unlock)" || echo "Internet: liber"
        ;;
    *) echo "Foloseste: wcd-protect {stop|start|pin|status}"; exit 1 ;;
esac
echo "made by REDAOT"
