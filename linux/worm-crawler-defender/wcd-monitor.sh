#!/usr/bin/env bash
# Worm-Crawler Defender for Linux - main guard (runs as root via systemd)
# made by REDAOT
# Blocks the network and alerts when it detects:
#   1. a process that downloads and runs code directly ( curl|bash, base64 -d|sh, etc. )
#   2. an executable started from /tmp, /dev/shm or /var/tmp (typical dropper staging)
#   3. new persistence added (cron, systemd unit, autostart)
#   4. a non-browser process opening the browser cookies/credentials
#   5. a non-input process reading the keyboard devices (/dev/input/*) - keylogger
# The block stays active until the PIN is entered.
set -u
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$DIR/wcd-lib.sh"

LAST_ALARM=0

# suspicious command patterns (egrep, case-insensitive)
PAT_CMD='(\|[[:space:]]*(ba)?sh([[:space:]]|$))|((curl|wget|fetch)[[:space:]].*\|[[:space:]]*(ba)?sh)|(base64[[:space:]]+(-d|--decode))|((python[0-9]?|perl|ruby)[[:space:]].*(base64|b64decode|exec\(|eval\())|(echo[[:space:]].*\|[[:space:]]*base64)|([A-Za-z0-9+/]{200,}={0,2})'

snapshot_persistence() {
    {
        # cron
        cat /etc/crontab 2>/dev/null
        cat /etc/cron.d/* 2>/dev/null
        for f in /var/spool/cron/crontabs/* /var/spool/cron/*; do [ -f "$f" ] && echo "CRON:$f:$(cat "$f")"; done
        # systemd units (system + user)
        ls -1 /etc/systemd/system/*.service /etc/systemd/system/*.timer 2>/dev/null
        ls -1 /home/*/.config/systemd/user/*.service 2>/dev/null
        # graphical autostart
        ls -1 /etc/xdg/autostart/*.desktop 2>/dev/null
        ls -1 /home/*/.config/autostart/*.desktop 2>/dev/null
    } 2>/dev/null | sort -u
}

raise_alarm() {  # $1 reason, $2 details
    local reason="$1" details="$2" now
    wcd_log "ALARM: $reason | $details"
    date +%s > "$VAR_DIR/.alarm_time"
    printf '%s | %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$reason" > "$BLOCK_FLAG"
    wcd_net_block

    now="$(date +%s)"
    if [ $(( now - LAST_ALARM )) -gt 30 ]; then
        LAST_ALARM="$now"
        local body="WARNING! Possible DROPPER / MALWARE detected.
THE INTERNET HAS BEEN BLOCKED.

Reason: $reason

Details: $details

What to do now:
 - Do NOT unlock the internet unless you are sure what triggered the alert.
 - Stop the process / program you just ran.
 - The internet stays blocked until you enter your PIN:
     sudo wcd-unlock
   (or from the app menu, if you added the shortcuts)

Log: $LOG_FILE"
        wcd_alert_write "WORM-CRAWLER DEFENDER $WCD_VERSION - MALWARE DETECTED - INTERNET BLOCKED" "$body"
        wcd_gui_alert "WORM-CRAWLER DEFENDER - INTERNET BLOCKED" "$body"
    fi
}

scan_processes() {
    local pid cmd exe fd tgt
    for pid in /proc/[0-9]*; do
        pid="${pid#/proc/}"
        [ -r "/proc/$pid/cmdline" ] || continue
        cmd="$(tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null)"
        [ -z "$cmd" ] && continue
        case "$cmd" in
            *worm-crawler-defender*) continue ;;   # do not monitor ourselves
        esac
        exe="$(readlink -f "/proc/$pid/exe" 2>/dev/null)"

        # browsers are allowed to read their own cookies -> skip them entirely
        if printf '%s' "$exe" | grep -qiE "$WCD_BROWSER_EXE_RX"; then continue; fi

        # a) executable started from a staging location
        case "$exe" in
            /tmp/*|/dev/shm/*|/var/tmp/*)
                raise_alarm "A program is running from a suspicious location ($exe)." "PID $pid: $cmd"
                return ;;
        esac
        # b) dropper-style command (download-and-run / encoded code)
        if printf '%s' "$cmd" | grep -qiE "$PAT_CMD"; then
            raise_alarm "Dropper-style command (download-and-run or encoded code)." "PID $pid: ${cmd:0:300}"
            return
        fi
        # c) open file descriptors: cookie/credential files, or keyboard devices
        if [ -d "/proc/$pid/fd" ]; then
            for fd in /proc/"$pid"/fd/*; do
                tgt="$(readlink "$fd" 2>/dev/null)" || continue
                # c1) a non-browser process has a cookie/credential file open
                if printf '%s' "$tgt" | grep -qE "$WCD_COOKIE_RX"; then
                    raise_alarm "A program opened the browser COOKIES / credentials." "PID $pid ($exe)
File: $tgt"
                    return
                fi
                # c2) a non-input process reading keyboard devices = possible keylogger
                if printf '%s' "$tgt" | grep -qE "$WCD_INPUT_RX"; then
                    if [ -n "$exe" ] && ! printf '%s' "$exe" | grep -qiE "$WCD_INPUT_OK_RX"; then
                        raise_alarm "A program is reading the KEYBOARD input (possible keylogger)." "PID $pid ($exe)
Device: $tgt"
                        return
                    fi
                fi
            done
        fi
    done
}

# ---------------------------------------------------------------- startup
wcd_dirs
wcd_log "Worm-Crawler Defender $WCD_VERSION started."
rm -f "$AUTH_FLAG"                      # a fresh start means protection is active
[ -f "$BLOCK_FLAG" ] && { wcd_log 'The internet was blocked - it stays blocked.'; wcd_net_block; }

BASELINE="$(snapshot_persistence)"
tick=0
watch_alarmed=0

while true; do
    # keep the network down if we are waiting for the PIN (even if someone re-enables it from Settings)
    [ -f "$BLOCK_FLAG" ] && wcd_net_block

    scan_processes

    tick=$(( tick + 1 ))
    if [ $(( tick % 5 )) -eq 0 ]; then
        mkdir -p "$RUN_DIR"; date +%s > "$HEARTBEAT"

        # new persistence added?
        now_snap="$(snapshot_persistence)"
        added="$(comm -13 <(printf '%s\n' "$BASELINE") <(printf '%s\n' "$now_snap") 2>/dev/null)"
        if [ -n "$added" ]; then
            raise_alarm "New persistence was added (cron / service / autostart)." "$(printf '%s' "$added" | head -c 300)"
        fi
        BASELINE="$now_snap"

        # mutual guard: the watchdog must exist and be enabled
        if have systemctl; then
            if ! systemctl is-enabled wcd-watchdog.timer >/dev/null 2>&1; then
                if [ "$watch_alarmed" -eq 0 ]; then
                    watch_alarmed=1
                    raise_alarm "The watchdog (wcd-watchdog.timer) was deleted or disabled." "Someone is trying to disable the protection."
                fi
            else watch_alarmed=0; fi
        fi
    fi
    sleep 2
done
