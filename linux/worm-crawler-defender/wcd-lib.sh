#!/usr/bin/env bash
# Worm-Crawler Defender for Linux - shared library (made by REDAOT)
# Functions for: logging, PIN, network block/restore, alerts, persistence baseline.

WCD_VERSION="v1.0.0"

# --- paths ---
PROG_DIR="/opt/worm-crawler-defender"              # the program
SECURE_DIR="/etc/worm-crawler-defender/secure"     # the PIN, separate; survives deletion of /opt
PIN_FILE="$SECURE_DIR/pin.dat"
PIN_BAK="$SECURE_DIR/pin.bak"
VAR_DIR="/var/lib/worm-crawler-defender"           # persistent state (survives reboot)
RUN_DIR="/run/worm-crawler-defender"               # volatile state (heartbeat)
LOG_FILE="/var/log/worm-crawler-defender.log"
BLOCK_FLAG="$VAR_DIR/blocked.flag"                 # exists while the network is blocked, waiting for the PIN
AUTH_FLAG="$VAR_DIR/authorized.flag"               # exists while protection is stopped with the PIN
SAVED_NET="$VAR_DIR/saved_net"                     # what we disabled, so we re-enable exactly those
HEARTBEAT="$RUN_DIR/heartbeat"

have() { command -v "$1" >/dev/null 2>&1; }

# Browser cookie/credential files (full path, any user).
# FAILSAFE:
#  - Mozilla (Firefox and forks, Thunderbird): the names cookies.sqlite/logins.json/key4.db
#    anywhere (incl. snap/flatpak) - unique to the Mozilla family, so no false alarms.
#  - Chromium: a "Cookies"/"Login Data" file under a known browser folder (.config or
#    flatpak), so we do NOT alarm when Discord/Slack/VSCode read their own cookies.
WCD_COOKIE_RX='/(cookies\.sqlite|logins\.json|key4\.db)$|/(\.config|\.var/app/[^/]+/config)/(google-chrome|chrome|chromium|BraveSoftware|brave|microsoft-edge|edge|vivaldi|opera|yandex-browser)[^/]*/(.*/)?(Network/)?Cookies$|/(\.config|\.var/app/[^/]+/config)/(google-chrome|chrome|chromium|BraveSoftware|brave|microsoft-edge|edge|vivaldi|opera|yandex-browser)[^/]*/(.*/)?Login Data$'
# the browser executable (its processes are allowed to read their own cookies)
WCD_BROWSER_EXE_RX='(firefox|thunderbird|librewolf|waterfox|palemoon|/chrome|/chromium|chrome-sandbox|/brave|microsoft-edge|/msedge|/opera|vivaldi|yandex)'

# keyboard input devices (a keylogger reads these directly)
WCD_INPUT_RX='^/dev/input/(event|by-id/|by-path/)'
# programs legitimately allowed to read input (display servers, compositors,
# input daemons, gaming). A process reading /dev/input that is NOT one of these
# is a classic Linux keylogger pattern.
WCD_INPUT_OK_RX='(/Xorg$|/X$|Xwayland|gnome-shell|/kwin|mutter|/sway$|Hyprland|hyprland|/weston|wayfire|labwc|cosmic-comp|gamescope|plymouthd|systemd-logind|systemd-udevd|/udevd|ibus-|fcitx|libinput|/steam|steamwebhelper|/evsieve|/keyd$|/kanata|/interception|input-remapper|/ydotoold|/wev$)'

wcd_log() {
    mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null
    printf '%s  %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >> "$LOG_FILE" 2>/dev/null
}

wcd_dirs() {
    mkdir -p "$PROG_DIR" "$SECURE_DIR" "$VAR_DIR" "$RUN_DIR" 2>/dev/null
    chmod 700 "$SECURE_DIR" "$VAR_DIR" 2>/dev/null
}

# ===================== PIN =====================
# File format: algo:salt_hex:hash_hex   (algo = pbkdf2 or openssl)
wcd_hash() {  # $1 pin, $2 salt_hex, $3 algo
    local pin="$1" salt="$2" algo="$3"
    case "$algo" in
        pbkdf2)
            python3 - "$pin" "$salt" <<'PY'
import sys, hashlib, binascii
pin = sys.argv[1].encode()
salt = binascii.unhexlify(sys.argv[2])
print(hashlib.pbkdf2_hmac('sha256', pin, salt, 100000).hex())
PY
            ;;
        openssl)
            printf '%s' "$pin" | openssl kdf -keylen 32 -kdfopt digest:SHA256 \
                -kdfopt pass:"$pin" -kdfopt hexsalt:"$salt" -kdfopt iter:100000 PBKDF2 2>/dev/null \
                | tr -d ':' | tr 'A-F' 'a-f'
            ;;
    esac
}

wcd_pin_algo() {  # pick an available algorithm
    if have python3; then echo pbkdf2
    elif have openssl; then echo openssl
    else echo none; fi
}

wcd_pin_exists() { [ -s "$PIN_FILE" ] || [ -s "$PIN_BAK" ]; }

wcd_pin_restore_copies() {  # restore the missing file from the backup
    if [ -s "$PIN_FILE" ] && [ ! -s "$PIN_BAK" ]; then cp -f "$PIN_FILE" "$PIN_BAK"; chmod 600 "$PIN_BAK"
    elif [ -s "$PIN_BAK" ] && [ ! -s "$PIN_FILE" ]; then cp -f "$PIN_BAK" "$PIN_FILE"; chmod 600 "$PIN_FILE"; fi
}

wcd_pin_line() {
    wcd_pin_restore_copies
    if [ -s "$PIN_FILE" ]; then cat "$PIN_FILE"
    elif [ -s "$PIN_BAK" ]; then cat "$PIN_BAK"; fi
}

wcd_pin_read() {  # read a PIN without echo
    local p
    read -r -s -p "$1" p; echo >&2
    printf '%s' "$p"
}

wcd_pin_set() {  # interactively ask for a new 4-digit PIN and save it
    local algo p1 p2 salt hash
    algo="$(wcd_pin_algo)"
    if [ "$algo" = none ]; then
        echo "ERROR: python3 or openssl is required to secure the PIN." >&2
        return 1
    fi
    while true; do
        p1="$(wcd_pin_read 'Choose a 4-digit PIN: ')"
        if ! printf '%s' "$p1" | grep -qE '^[0-9]{4}$'; then echo "The PIN must be exactly 4 digits."; continue; fi
        p2="$(wcd_pin_read 'Repeat the PIN: ')"
        if [ "$p1" != "$p2" ]; then echo "The PINs do not match. Try again."; continue; fi
        break
    done
    salt="$(openssl rand -hex 16 2>/dev/null || head -c16 /dev/urandom | od -An -tx1 | tr -d ' \n')"
    hash="$(wcd_hash "$p1" "$salt" "$algo")"
    if [ -z "$hash" ]; then echo "ERROR while computing the PIN." >&2; return 1; fi
    mkdir -p "$SECURE_DIR"; chmod 700 "$SECURE_DIR"
    printf '%s:%s:%s\n' "$algo" "$salt" "$hash" > "$PIN_FILE"
    printf '%s:%s:%s\n' "$algo" "$salt" "$hash" > "$PIN_BAK"
    chmod 600 "$PIN_FILE" "$PIN_BAK"
    echo "[OK] PIN saved (with a backup copy). Do not forget it!"
}

wcd_pin_check() {  # $1 pin -> 0 if correct
    local line algo salt want got
    line="$(wcd_pin_line)"; [ -z "$line" ] && return 1
    algo="${line%%:*}"; line="${line#*:}"
    salt="${line%%:*}"; want="${line#*:}"
    got="$(wcd_hash "$1" "$salt" "$algo")"
    [ -n "$got" ] && [ "$got" = "$want" ]
}

# Ask for the PIN (3 attempts). Returns 0 if correct.
wcd_pin_prompt() {  # $1 reason
    local reason="$1" i p
    if ! wcd_pin_exists; then
        echo "No PIN is set. Set one now."
        wcd_pin_set; return $?
    fi
    for i in 1 2 3; do
        p="$(wcd_pin_read "PIN for: $reason (attempt $i of 3): ")"
        if wcd_pin_check "$p"; then return 0; fi
        echo "Wrong PIN."
        wcd_log "WRONG PIN entered for: $reason"
    done
    sleep 5
    return 1
}

# ===================== NETWORK =====================
wcd_net_ifaces() {  # physical/virtual adapters, without loopback
    local i
    for i in /sys/class/net/*; do
        i="$(basename "$i")"
        [ "$i" = lo ] && continue
        echo "$i"
    done
}

wcd_net_block() {
    # record what was up, only once
    if [ ! -f "$SAVED_NET" ]; then
        mkdir -p "$VAR_DIR"
        if have nmcli; then
            echo "nmcli" > "$SAVED_NET"
        else
            local i
            for i in $(wcd_net_ifaces); do
                if [ "$(cat "/sys/class/net/$i/operstate" 2>/dev/null)" != down ]; then echo "$i"; fi
            done > "$SAVED_NET"
        fi
    fi
    # apply the block (idempotent)
    if have nmcli && grep -qx nmcli "$SAVED_NET" 2>/dev/null; then
        nmcli networking off 2>/dev/null
    else
        local i
        for i in $(wcd_net_ifaces); do ip link set "$i" down 2>/dev/null; done
    fi
}

wcd_net_restore() {
    if have nmcli && grep -qx nmcli "$SAVED_NET" 2>/dev/null; then
        nmcli networking on 2>/dev/null
    else
        local i
        if [ -f "$SAVED_NET" ]; then
            while read -r i; do [ -n "$i" ] && ip link set "$i" up 2>/dev/null; done < "$SAVED_NET"
        else
            for i in $(wcd_net_ifaces); do ip link set "$i" up 2>/dev/null; done
        fi
    fi
    rm -f "$SAVED_NET" "$BLOCK_FLAG"
}

# ===================== ON-SCREEN ALERT =====================
wcd_alert_write() {  # $1 title, $2 body -> write the alert file (the GUI reads it)
    mkdir -p "$VAR_DIR"
    printf '%s\n%s\n' "$1" "$2" > "$VAR_DIR/alert.txt"
}

wcd_gui_alert() {  # $1 title, $2 body : a window for each graphical user + text in terminals
    local title="$1" body="$2"
    printf '%s\n\n%s\n' "$title" "$body" | wall 2>/dev/null

    local sessions u uid disp
    if have loginctl; then
        sessions="$(loginctl list-sessions --no-legend 2>/dev/null | awk '{print $1}')"
        local sid
        for sid in $sessions; do
            u="$(loginctl show-session "$sid" -p Name --value 2>/dev/null)"
            disp="$(loginctl show-session "$sid" -p Display --value 2>/dev/null)"
            [ -z "$u" ] && continue
            uid="$(id -u "$u" 2>/dev/null)" || continue
            [ -z "$disp" ] && disp=":0"
            _wcd_alert_user "$u" "$uid" "$disp" "$title" "$body"
        done
    else
        who 2>/dev/null | while read -r u _ _ _ rest; do
            disp="$(printf '%s' "$rest" | grep -oE '\(:[0-9]+\)' | tr -d '():')"
            [ -z "$disp" ] && continue
            uid="$(id -u "$u" 2>/dev/null)" || continue
            _wcd_alert_user "$u" "$uid" ":$disp" "$title" "$body"
        done
    fi
}

_wcd_alert_user() {  # $1 user $2 uid $3 display $4 title $5 body
    local u="$1" uid="$2" disp="$3" title="$4" body="$5"
    local bus="unix:path=/run/user/$uid/bus"
    sudo -u "$u" DISPLAY="$disp" DBUS_SESSION_BUS_ADDRESS="$bus" XAUTHORITY="/home/$u/.Xauthority" \
        bash -c '
            T="$1"; B="$2"
            if command -v zenity >/dev/null 2>&1; then
                zenity --error --width=480 --title="$T" --text="$B"
            elif command -v kdialog >/dev/null 2>&1; then
                kdialog --title "$T" --error "$B"
            elif command -v notify-send >/dev/null 2>&1; then
                notify-send -u critical "$T" "$B"
            elif command -v xmessage >/dev/null 2>&1; then
                printf "%s\n\n%s\n" "$T" "$B" | xmessage -center -file -
            fi
        ' _ "$title" "$body" >/dev/null 2>&1 &
}
