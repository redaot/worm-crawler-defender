#!/usr/bin/env bash
# Worm-Crawler Defender - unlock the internet (asks for the PIN). made by REDAOT
set -u
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$DIR/wcd-lib.sh"
if [ "$(id -u)" -ne 0 ]; then echo "Run with: sudo wcd-unlock"; exit 1; fi

echo "== Worm-Crawler Defender $WCD_VERSION - Unlock Internet =="
[ -f "$BLOCK_FLAG" ] && echo "Block reason: $(cat "$BLOCK_FLAG")"
echo
if ! wcd_pin_prompt "unlocking the internet"; then
    echo "Wrong PIN 3 times. The internet stays blocked."; exit 1
fi
wcd_net_restore
wcd_log "Internet unlocked manually by the user (correct PIN)."
echo
echo "The internet has been unlocked. It may take a few seconds to reconnect."
echo "made by REDAOT"
