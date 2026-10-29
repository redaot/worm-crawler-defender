#!/usr/bin/env bash
# Worm-Crawler Defender - verificare automata (ruleaza la fiecare minut, ca root)
# Daca paza NU ruleaza si nu a fost oprita cu PIN: blocheaza internetul, incearca
# s-o reporneasca si afiseaza o fereastra de alerta. made by REDAOT
set -u
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$DIR/wcd-lib.sh"

COOL="$VAR_DIR/.wd_cooldown"

alive() {
    if have systemctl; then
        systemctl is-active --quiet worm-crawler-defender.service || return 1
    fi
    [ -f "$HEARTBEAT" ] || return 1
    local age=$(( $(date +%s) - $(cat "$HEARTBEAT" 2>/dev/null || echo 0) ))
    [ "$age" -le 90 ]
}

alive && exit 0
[ -f "$AUTH_FLAG" ] && exit 0            # oprit cu PIN -> ok, nu facem nimic

wcd_dirs
problema="Worm-Crawler Defender nu ruleaza (inchis fortat, fara PIN)."
wcd_log "[Watchdog] $problema Blochez internetul si incerc repornirea."
[ -f "$BLOCK_FLAG" ] || printf '%s | %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$problema" > "$BLOCK_FLAG"
wcd_net_block

repornit=0
if have systemctl; then
    systemctl reset-failed worm-crawler-defender.service >/dev/null 2>&1
    systemctl start worm-crawler-defender.service >/dev/null 2>&1
    sleep 20
    alive && repornit=1
fi
wcd_log "[Watchdog] Rezultat repornire: $([ "$repornit" = 1 ] && echo reusita || echo ESUATA)"

# aceeasi alerta cel mult o data la 15 minute
if [ -f "$COOL" ]; then
    age=$(( $(date +%s) - $(cat "$COOL" 2>/dev/null || echo 0) ))
    [ "$age" -lt 900 ] && exit 0
fi
date +%s > "$COOL"

comun="INTERNETUL A FOST BLOCAT si ramane blocat pana introduci PIN-ul (sudo wcd-unlock).

"
if [ "$repornit" = 1 ]; then
    title="WORM-CRAWLER DEFENDER - OPRIT FARA PIN - INTERNET BLOCAT"
    body="ATENTIE! $problema

${comun}Protectia a fost repornita automat si functioneaza din nou.
Daca nu l-ai oprit tu, un program a incercat sa-l opreasca. Scaneaza sistemul.

Jurnal: $LOG_FILE"
else
    title="WORM-CRAWLER DEFENDER NU RULEAZA - INTERNET BLOCAT"
    body="ATENTIE! $problema

${comun}Repornirea automata NU a reusit.
Ruleaza din nou install.sh. Daca nu l-ai oprit tu, nu rula programe noi si scaneaza sistemul.

Jurnal: $LOG_FILE"
fi
wcd_alert_write "$title" "$body"
wcd_gui_alert "$title" "$body"
