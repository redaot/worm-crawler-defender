#!/usr/bin/env bash
# Worm-Crawler Defender - deblocheaza internetul (cere PIN-ul). made by REDAOT
set -u
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$DIR/wcd-lib.sh"
if [ "$(id -u)" -ne 0 ]; then echo "Ruleaza cu: sudo wcd-unlock"; exit 1; fi

echo "== Worm-Crawler Defender - Deblocheaza internetul =="
[ -f "$BLOCK_FLAG" ] && echo "Motivul blocarii: $(cat "$BLOCK_FLAG")"
echo
if ! wcd_pin_prompt "deblocarea internetului"; then
    echo "PIN gresit de 3 ori. Internetul ramane blocat."; exit 1
fi
wcd_net_restore
wcd_log "Internet deblocat manual de utilizator (PIN corect)."
echo
echo "Internetul a fost deblocat. Poate dura cateva secunde pana se reconecteaza."
echo "made by REDAOT"
