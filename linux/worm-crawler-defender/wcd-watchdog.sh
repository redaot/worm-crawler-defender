#!/usr/bin/env bash
# ==========================================================================
#  WORM-CRAWLER DEFENDER - watchdog (runs as root, every minute)
#  If the guard is NOT running and was not stopped with the PIN:
#    -> BLOCKS the internet (and keeps it blocked until the PIN is entered)
#    -> tries to restart it
#    -> shows an on-screen alert WINDOW
#  made by REDAOT
# ==========================================================================
set -u
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$DIR/wcd-lib.sh"

COOL="$VAR_DIR/wd_cooldown"

alive() {
    if have systemctl; then
        systemctl is-active --quiet worm-crawler-defender.service || return 1
    fi
    [ -f "$HEARTBEAT" ] || return 1
    local age=$(( $(date +%s) - $(cat "$HEARTBEAT" 2>/dev/null || echo 0) ))
    [ "$age" -le 90 ]
}

alive && exit 0
[ -f "$AUTH_FLAG" ] && exit 0            # stopped with the PIN -> ok, do nothing

wcd_dirs
problem="Worm-Crawler Defender is not running (force-closed, without PIN)."
wcd_log "[Watchdog] $problem Blocking the internet and trying to restart."
[ -f "$BLOCK_FLAG" ] || printf '%s | %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$problem" > "$BLOCK_FLAG"
wcd_net_block

restarted=0
if have systemctl; then
    systemctl reset-failed worm-crawler-defender.service >/dev/null 2>&1
    systemctl start worm-crawler-defender.service >/dev/null 2>&1
    sleep 20
    alive && restarted=1
fi
wcd_log "[Watchdog] Restart result: $([ "$restarted" = 1 ] && echo success || echo FAILED)"

# same alert at most once every 15 minutes
if [ -f "$COOL" ]; then
    age=$(( $(date +%s) - $(cat "$COOL" 2>/dev/null || echo 0) ))
    [ "$age" -lt 900 ] && exit 0
fi
date +%s > "$COOL"

common="THE INTERNET HAS BEEN BLOCKED and stays blocked until you enter the PIN (sudo wcd-unlock).

"
if [ "$restarted" = 1 ]; then
    title="WORM-CRAWLER DEFENDER $WCD_VERSION - STOPPED WITHOUT PIN - INTERNET BLOCKED"
    body="WARNING! $problem

${common}The protection was restarted automatically and is working again.
If you did not stop it, a program tried to kill it. Scan the system.

Log: $LOG_FILE"
else
    title="WORM-CRAWLER DEFENDER $WCD_VERSION - NOT RUNNING - INTERNET BLOCKED"
    body="WARNING! $problem

${common}The automatic restart FAILED.
Run install.sh again. If you did not stop it, do not run new programs and scan the system.

Log: $LOG_FILE"
fi
wcd_alert_write "$title" "$body"
wcd_gui_alert "$title" "$body"
