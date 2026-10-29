#!/usr/bin/env bash
# =====================================================================
#  Worm-Crawler Defender pentru Linux - instalare (made by REDAOT)
#  Detecteaza singur distributia si sistemul de init si face totul in spate.
#  Ruleaza:  sudo ./install.sh     (sau: ./install.sh  -> cere singur sudo)
# =====================================================================
set -u
SRC="$(cd "$(dirname "$0")" && pwd)/worm-crawler-defender"
PROG_DIR="/opt/worm-crawler-defender"
BINDIR="/usr/local/bin"
UNITDIR="/etc/systemd/system"

# --- auto-sudo ---
if [ "$(id -u)" -ne 0 ]; then
    echo "Am nevoie de drepturi de administrator (sudo)..."
    exec sudo -- "$0" "$@"
fi

echo "=================================================="
echo "   WORM-CRAWLER DEFENDER (Linux)  -  made by REDAOT"
echo "=================================================="

# --- 1. detectare mediu ---
DISTRO="necunoscut"
[ -r /etc/os-release ] && . /etc/os-release && DISTRO="${PRETTY_NAME:-$ID}"
if pidof systemd >/dev/null 2>&1 || [ -d /run/systemd/system ]; then INIT="systemd"; else INIT="other"; fi
echo "[i] Distributie : $DISTRO"
echo "[i] Init        : $INIT"

# dependinte minime
command -v bash >/dev/null || { echo "EROARE: lipseste bash."; exit 1; }
if ! command -v python3 >/dev/null && ! command -v openssl >/dev/null; then
    echo "EROARE: am nevoie de python3 SAU openssl pentru PIN."
    echo "        Instaleaza unul: ex. 'sudo apt install python3' sau 'sudo dnf install python3'."
    exit 1
fi
command -v ip   >/dev/null || echo "[!] 'ip' lipseste; blocarea retelei se bazeaza pe nmcli daca exista."
command -v nmcli >/dev/null && echo "[i] Retea       : NetworkManager (nmcli)" || echo "[i] Retea       : prin 'ip link'"
command -v zenity >/dev/null || command -v kdialog >/dev/null || command -v notify-send >/dev/null || command -v xmessage >/dev/null \
    || echo "[!] Niciun instrument grafic de alerta (zenity/kdialog/notify-send/xmessage). Alertele vor aparea doar in terminal ('wall')."

# --- 2. PIN (folder separat, supravietuieste stergerii /opt) ---
. "$SRC/wcd-lib.sh"
wcd_dirs
if wcd_pin_exists; then
    echo; echo "Worm-Crawler Defender e deja instalat. Pentru reinstalare e nevoie de PIN."
    if ! wcd_pin_prompt "reinstalare"; then echo "PIN gresit. Instalarea a fost anulata."; exit 1; fi
    read -r -p "Vrei sa schimbi PIN-ul? (d/N): " r
    case "$r" in [dDyY]*) wcd_pin_set ;; esac
    # opreste varianta veche ca sa poata fi inlocuita
    date +%s > "$AUTH_FLAG"
    [ "$INIT" = systemd ] && systemctl stop worm-crawler-defender.service >/dev/null 2>&1
else
    echo; echo "Alege un PIN din 4 cifre. Il vei folosi ca sa deblochezi internetul,"
    echo "sa opresti protectia si sa dezinstalezi programul."
    wcd_pin_set || exit 1
fi

# --- 3. copiere fisiere ---
mkdir -p "$PROG_DIR"
cp -f "$SRC"/wcd-*.sh "$PROG_DIR"/ 2>/dev/null
cp -f "$SRC"/wormcrawler.png "$PROG_DIR"/ 2>/dev/null
chmod 755 "$PROG_DIR"/wcd-*.sh
chown -R root:root "$PROG_DIR"
echo "[OK] Fisiere copiate in $PROG_DIR"

# comenzi scurte
ln -sf "$PROG_DIR/wcd-unlock.sh"  "$BINDIR/wcd-unlock"
ln -sf "$PROG_DIR/wcd-protect.sh" "$BINDIR/wcd-protect"
ln -sf "$PROG_DIR/wcd-test.sh"    "$BINDIR/wcd-test"
echo "[OK] Comenzi: wcd-unlock, wcd-protect, wcd-test"

# --- 4. pornire automata ---
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
Description=Worm-Crawler Defender - verificare automata (made by REDAOT)
[Service]
Type=oneshot
ExecStart=$PROG_DIR/wcd-watchdog.sh
EOF
    cat > "$UNITDIR/wcd-watchdog.timer" <<EOF
[Unit]
Description=Worm-Crawler Defender - verificare la fiecare minut (made by REDAOT)
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
        echo "[OK] Serviciul RULEAZA (systemd). Jurnal: $LOG_FILE"
    else
        echo "[!] Serviciul nu a pornit. Verifica: systemctl status worm-crawler-defender"
    fi
else
    # fallback fara systemd: supervizor la boot + watchdog in cron
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
    echo "[OK] Pornire prin cron @reboot + supervizor (sistem fara systemd)."
fi

# scurtatura grafica (optional, daca exista mediu desktop)
if [ -d /usr/share/applications ]; then
    cat > /usr/share/applications/worm-crawler-defender.desktop <<EOF
[Desktop Entry]
Type=Application
Name=Worm-Crawler Defender - Deblocheaza internetul
Exec=pkexec $PROG_DIR/wcd-unlock.sh
Icon=$PROG_DIR/wormcrawler.png
Terminal=true
Categories=Security;System;
EOF
fi

echo
echo "Gata. Testeaza cu:   sudo wcd-test"
echo "Stare:               wcd-protect status"
echo "made by REDAOT"
