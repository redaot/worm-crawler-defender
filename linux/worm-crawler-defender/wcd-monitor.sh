#!/usr/bin/env bash
# Worm-Crawler Defender pentru Linux - paza principala (ruleaza ca root prin systemd)
# made by REDAOT
# Blocheaza reteaua si alerteaza cand detecteaza:
#   1. un proces care descarca si ruleaza direct cod ( curl|bash, base64 -d|sh, etc. )
#   2. un executabil pornit din /tmp, /dev/shm sau /var/tmp (stagiu tipic de dropper)
#   3. o persistenta noua adaugata (cron, serviciu systemd, autostart)
# Blocarea ramane activa pana se introduce PIN-ul.
set -u
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$DIR/wcd-lib.sh"

LAST_ALARM=0

# tipare de comanda suspecta (egrep, case-insensitive)
PAT_CMD='(\|[[:space:]]*(ba)?sh([[:space:]]|$))|((curl|wget|fetch)[[:space:]].*\|[[:space:]]*(ba)?sh)|(base64[[:space:]]+(-d|--decode))|((python[0-9]?|perl|ruby)[[:space:]].*(base64|b64decode|exec\(|eval\())|(echo[[:space:]].*\|[[:space:]]*base64)|([A-Za-z0-9+/]{200,}={0,2})'

snapshot_persistence() {
    {
        # cron
        cat /etc/crontab 2>/dev/null
        cat /etc/cron.d/* 2>/dev/null
        for f in /var/spool/cron/crontabs/* /var/spool/cron/*; do [ -f "$f" ] && echo "CRON:$f:$(cat "$f")"; done
        # servicii systemd (sistem + utilizator)
        ls -1 /etc/systemd/system/*.service /etc/systemd/system/*.timer 2>/dev/null
        ls -1 /home/*/.config/systemd/user/*.service 2>/dev/null
        # autostart grafic
        ls -1 /etc/xdg/autostart/*.desktop 2>/dev/null
        ls -1 /home/*/.config/autostart/*.desktop 2>/dev/null
    } 2>/dev/null | sort -u
}

raise_alarm() {  # $1 motiv, $2 detalii
    local motiv="$1" detalii="$2" now
    wcd_log "ALARMA: $motiv | $detalii"
    date +%s > "$VAR_DIR/.alarm_time"
    printf '%s | %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$motiv" > "$BLOCK_FLAG"
    wcd_net_block

    now="$(date +%s)"
    if [ $(( now - LAST_ALARM )) -gt 30 ]; then
        LAST_ALARM="$now"
        local body="ATENTIE! Posibil DROPPER / MALWARE detectat.
INTERNETUL A FOST BLOCAT.

Motiv: $motiv

Detalii: $detalii

Ce faci acum:
 - NU debloca internetul daca nu stii sigur ce a provocat alerta.
 - Opreste procesul / programul pe care tocmai l-ai rulat.
 - Internetul ramane blocat pana introduci PIN-ul:
     sudo wcd-unlock
   (sau din meniul aplicatiei, daca ai pus scurtaturile)

Jurnal: $LOG_FILE"
        wcd_alert_write "WORM-CRAWLER DEFENDER - MALWARE DETECTAT - INTERNET BLOCAT" "$body"
        wcd_gui_alert "WORM-CRAWLER DEFENDER - INTERNET BLOCAT" "$body"
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
            *worm-crawler-defender*) continue ;;   # nu ne monitorizam pe noi
        esac
        exe="$(readlink -f "/proc/$pid/exe" 2>/dev/null)"

        # browserele au voie sa-si citeasca propriile cookie-uri -> le sarim complet
        if printf '%s' "$exe" | grep -qiE "$WCD_BROWSER_EXE_RX"; then continue; fi

        # a) executabil pornit din locatii de stagiu
        case "$exe" in
            /tmp/*|/dev/shm/*|/var/tmp/*)
                raise_alarm "Un program ruleaza dintr-o locatie suspecta ($exe)." "PID $pid: $cmd"
                return ;;
        esac
        # b) comanda de tip dropper (descarca-si-ruleaza / cod codificat)
        if printf '%s' "$cmd" | grep -qiE "$PAT_CMD"; then
            raise_alarm "Comanda de tip dropper (descarca-si-ruleaza sau cod codificat)." "PID $pid: ${cmd:0:300}"
            return
        fi
        # c) un proces non-browser tine deschis un fisier de cookie-uri/parole
        if [ -d "/proc/$pid/fd" ]; then
            for fd in /proc/"$pid"/fd/*; do
                tgt="$(readlink "$fd" 2>/dev/null)" || continue
                if printf '%s' "$tgt" | grep -qE "$WCD_COOKIE_RX"; then
                    raise_alarm "Un program a deschis COOKIE-URILE / parolele din browser." "PID $pid ($exe)
Fisier: $tgt"
                    return
                fi
            done
        fi
    done
}

# ---------------------------------------------------------------- pornire
wcd_dirs
wcd_log "Worm-Crawler Defender pornit."
rm -f "$AUTH_FLAG"                      # pornire noua = protectie activa
[ -f "$BLOCK_FLAG" ] && { wcd_log "Internetul era blocat - raman blocat."; wcd_net_block; }

BASELINE="$(snapshot_persistence)"
tick=0
verif_alarmat=0

while true; do
    # tine reteaua blocata daca asteptam PIN-ul (chiar daca cineva o porneste din Setari)
    [ -f "$BLOCK_FLAG" ] && wcd_net_block

    scan_processes

    tick=$(( tick + 1 ))
    if [ $(( tick % 5 )) -eq 0 ]; then
        mkdir -p "$RUN_DIR"; date +%s > "$HEARTBEAT"

        # persistenta noua adaugata?
        now_snap="$(snapshot_persistence)"
        added="$(comm -13 <(printf '%s\n' "$BASELINE") <(printf '%s\n' "$now_snap") 2>/dev/null)"
        if [ -n "$added" ]; then
            raise_alarm "S-a adaugat o persistenta noua (cron / serviciu / autostart)." "$(printf '%s' "$added" | head -c 300)"
        fi
        BASELINE="$now_snap"

        # paza reciproca: watchdog-ul trebuie sa existe si sa fie activ
        if have systemctl; then
            if ! systemctl is-enabled wcd-watchdog.timer >/dev/null 2>&1; then
                if [ "$verif_alarmat" -eq 0 ]; then
                    verif_alarmat=1
                    raise_alarm "Verificarea automata (wcd-watchdog.timer) a fost dezactivata sau stearsa." "Cineva incearca sa dezactiveze protectia."
                fi
            else
                verif_alarmat=0
            fi
        fi
    fi
    sleep 2
done
