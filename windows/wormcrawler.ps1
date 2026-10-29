# ==========================================================================
#  WORM-CRAWLER DEFENDER - paza anti-dropper / anti-stealer
#  Ruleaza permanent ca SYSTEM (task programat la pornire).
#  Opreste internetul si afiseaza alerta cand detecteaza:
#    1. o excludere noua adaugata in Microsoft Defender
#    2. protectia in timp real a Defender oprita
#    3. PowerShell pornit cu comanda codificata (-EncodedCommand)
#    4. un alt proces decat browserul citeste cookie-urile/parolele din browser
# ==========================================================================

$ErrorActionPreference = 'SilentlyContinue'
$Dir        = 'C:\ProgramData\WormCrawler'
. (Join-Path $Dir 'cookie-guard.ps1')
$LogFile    = Join-Path $Dir 'wormcrawler.log'
$AlertFile  = Join-Path $Dir 'alerta.txt'
$AdaptFile  = Join-Path $Dir 'adaptoare_oprite.txt'
$BeatFile   = Join-Path $Dir 'heartbeat.txt'
$BlockFlag  = Join-Path $Dir 'blocare.flag'     # internet blocat pana se introduce PIN-ul
$AuthFlag   = Join-Path $Dir 'autorizat.flag'   # oprire autorizata cu PIN
$DefLog     = 'Microsoft-Windows-Windows Defender/Operational'

function Write-Log([string]$msg) {
    $line = '{0}  {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $msg
    Add-Content -Path $LogFile -Value $line -Encoding UTF8
}

function Get-LastRecordId([string]$log) {
    $e = Get-WinEvent -LogName $log -MaxEvents 1
    if ($e) { return [int64]$e.RecordId } else { return [int64]0 }
}

function Get-NewEvents([string]$log, [int]$id, [int64]$after, [int64]$upto = [int64]::MaxValue) {
    $xp = "*[System[EventID=$id and EventRecordID>$after and EventRecordID<=$upto]]"
    $ev = Get-WinEvent -LogName $log -FilterXPath $xp
    if ($ev) { return @($ev | Sort-Object RecordId) } else { return @() }
}

function Get-NewEventsMulti([string]$log, [int[]]$ids, [int64]$after, [int64]$upto) {
    $cond = ($ids | ForEach-Object { "EventID=$_" }) -join ' or '
    $xp = "*[System[($cond) and EventRecordID>$after and EventRecordID<=$upto]]"
    $ev = Get-WinEvent -LogName $log -FilterXPath $xp -MaxEvents 400
    if ($ev) { return @($ev | Sort-Object RecordId) } else { return @() }
}

function Get-EventField($evt, [string]$name) {
    $x = [xml]$evt.ToXml()
    return ($x.Event.EventData.Data | Where-Object { $_.Name -eq $name } | Select-Object -First 1).'#text'
}

function Get-Exclusions {
    $p = Get-MpPreference
    if (-not $p) { return $null }
    $all = @()
    $all += @($p.ExclusionPath      | ForEach-Object { "Cale: $_" })
    $all += @($p.ExclusionProcess   | ForEach-Object { "Proces: $_" })
    $all += @($p.ExclusionExtension | ForEach-Object { "Extensie: $_" })
    $all += @($p.ExclusionIpAddress | ForEach-Object { "IP: $_" })
    return @($all | Where-Object { $_ -and $_ -notmatch 'N/A' } | Sort-Object -Unique)
}

function Enable-ProcessAuditing {
    # Audit "Process Creation" (GUID, merge pe orice limba a Windows-ului)
    auditpol.exe /set /subcategory:"{0CCE922B-69AE-11D9-BED3-505054503030}" /success:enable | Out-Null
    $k = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\Audit'
    if (-not (Test-Path $k)) { New-Item -Path $k -Force | Out-Null }
    Set-ItemProperty -Path $k -Name 'ProcessCreationIncludeCmdLine_Enabled' -Value 1 -Type DWord
}

$script:LastAlarm = [datetime]::MinValue

function Disable-Network {
    # Opreste toate placile de retea active (Ethernet, Wi-Fi etc.) si le noteaza
    $active = @(Get-NetAdapter | Where-Object { $_.Status -ne 'Disabled' })
    if ($active.Count -eq 0) { return }
    $names = $active | ForEach-Object { $_.Name }
    $old = @()
    if (Test-Path $AdaptFile) { $old = @(Get-Content $AdaptFile) }
    ($old + $names) | Where-Object { $_ } | Sort-Object -Unique | Set-Content -Path $AdaptFile -Encoding UTF8
    $active | Disable-NetAdapter -Confirm:$false
    Write-Log ("Retea oprita: " + ($names -join ', '))
}

function Invoke-Alarm([string]$motiv, [string]$detalii) {
    Write-Log "ALARMA: $motiv | $detalii"

    # 1. Blocheaza internetul pana la introducerea PIN-ului
    Set-Content -Path $BlockFlag -Value ("{0} | {1}" -f (Get-Date -Format 'o'), $motiv) -Encoding UTF8
    Disable-Network

    # 2. Alerta pe ecran (cel mult o data la 30 de secunde, ca sa nu faca spam)
    if (((Get-Date) - $script:LastAlarm).TotalSeconds -gt 30) {
        $script:LastAlarm = Get-Date
        $text = "ATENTIE! Posibil DROPPER / MALWARE detectat.`r`n" +
                "INTERNETUL (LAN / Wi-Fi) A FOST BLOCAT.`r`n`r`n" +
                "Motiv: $motiv`r`n`r`n" +
                "Detalii: $detalii`r`n`r`n" +
                "Ce faci acum:`r`n" +
                " - NU reporni internetul daca nu stii sigur ce a provocat alerta.`r`n" +
                " - Inchide programul pe care tocmai l-ai rulat / instalat.`r`n" +
                " - Scaneaza cu ESET Online Scanner (de pe alt dispozitiv il descarci pe stick).`r`n" +
                " - Internetul ramane blocat pana introduci PIN-ul tau, din`r`n" +
                "   'Worm-Crawler Defender - Reporneste internetul' (Desktop sau iconita).`r`n`r`n" +
                "Jurnal complet: $LogFile"
        Set-Content -Path $AlertFile -Value ("WORM-CRAWLER DEFENDER - MALWARE DETECTAT - INTERNET BLOCAT`r`n" + $text) -Encoding UTF8
        Start-ScheduledTask -TaskPath '\WormCrawler\' -TaskName 'WormCrawler-Alerta'
    }
}

# ---------------------------------------------------------------- pornire
if (-not (Test-Path $Dir)) { New-Item -ItemType Directory -Path $Dir -Force | Out-Null }
Write-Log 'Worm-Crawler Defender pornit.'
# o pornire noua inseamna protectie activa: anuleaza o eventuala oprire autorizata
Remove-Item $AuthFlag -Force
if (Test-Path $BlockFlag) {
    Write-Log 'Internetul era blocat (fara PIN) - blocarea ramane activa.'
    Disable-Network
}
$verifAlarm = $false
Enable-ProcessAuditing
$nAudit = Set-CookieAudit
Write-Log ("Audit cookie-uri activat pe $nAudit fisiere de browser.")

$lastSec  = Get-LastRecordId 'Security'
$lastDef  = Get-LastRecordId $DefLog
$baseline = Get-Exclusions
if ($null -eq $baseline) { $baseline = @() }
Write-Log ("Excluderi existente la pornire: " + $(if ($baseline.Count) { $baseline -join '; ' } else { '(niciuna)' }))

$encRegex = '(?i)(^|\s)[-/]e[a-z]*\s+["'']?[A-Za-z0-9+/=]{40,}'
$tick = 0

# ---------------------------------------------------------------- bucla
while ($true) {
    try {
        # 0) Blocare activa -> tine internetul oprit (chiar daca cineva il porneste din Setari)
        if (Test-Path $BlockFlag) { Disable-Network }

        # A) Evenimente din Security: 4688 = proces nou, 4663 = acces la fisier auditat
        $newestSec = Get-LastRecordId 'Security'
        foreach ($e in (Get-NewEventsMulti 'Security' @(4688, 4663) $lastSec $newestSec)) {
            if ($e.Id -eq 4688) {
                $proc = Get-EventField $e 'NewProcessName'
                if ($proc -notmatch '(?i)\\(powershell|pwsh)\.exe$') { continue }
                $cmd = Get-EventField $e 'CommandLine'
                if ($cmd -and $cmd -match $encRegex) {
                    $decoded = ''
                    $b64 = [regex]::Match($cmd, '[A-Za-z0-9+/=]{40,}').Value
                    try { $decoded = [Text.Encoding]::Unicode.GetString([Convert]::FromBase64String($b64)) } catch {}
                    if ($decoded.Length -gt 400) { $decoded = $decoded.Substring(0, 400) + '...' }
                    $parent = Get-EventField $e 'ParentProcessName'
                    Write-Log "Comanda PowerShell decodificata: $decoded"
                    Invoke-Alarm 'PowerShell a fost pornit cu o comanda ascunsa (codificata).' "Pornit de: $parent"
                }
            }
            elseif ($e.Id -eq 4663) {
                $obj = Get-EventField $e 'ObjectName'
                if ($obj -and ($obj -match $script:CookieRegex)) {
                    $pn = Get-EventField $e 'ProcessName'
                    $leaf = (($pn -split '\\')[-1]).ToLower()
                    if (($script:BrowserWhitelist -notcontains $leaf) -and ($pn -notmatch '(?i)WormCrawler')) {
                        Invoke-Alarm 'Un program a incercat sa citeasca COOKIE-URILE / parolele din browser.' "Program: $pn`r`nFisier: $obj"
                    }
                }
            }
        }
        $lastSec = $newestSec

        # B) Excludere noua in Defender (eveniment 5007 = configuratie schimbata)
        $newestDef = Get-LastRecordId $DefLog
        foreach ($e in (Get-NewEvents $DefLog 5007 $lastDef $newestDef)) {
            $new = Get-EventField $e 'New Value'
            if (-not $new) { $new = [string]$e.Properties[$e.Properties.Count - 1].Value }
            if ($new -match '(?i)\\Exclusions\\') {
                Invoke-Alarm 'S-a adaugat o EXCLUDERE in Windows Defender.' $new
                $baseline = Get-Exclusions
            }
        }

        # C) Protectia in timp real oprita (eveniment 5001)
        $rt = Get-NewEvents $DefLog 5001 $lastDef $newestDef
        if ($rt.Count -gt 0) {
            Invoke-Alarm 'Protectia in timp real din Windows Defender a fost OPRITA.' 'Eveniment Defender 5001'
        }
        if ($newestDef -gt $lastDef) { $lastDef = $newestDef }

        # D) Verificare de rezerva: lista de excluderi, la fiecare ~10 secunde
        $tick++
        if ($tick % 5 -eq 0) {
            # semn de viata pentru verificarea automata (WormCrawler-Verificare)
            Set-Content -Path $BeatFile -Value (Get-Date -Format 'o') -Encoding ASCII

            # E) Paza reciproca: verificarea automata trebuie sa existe si sa fie activa
            $vt = Get-ScheduledTask -TaskPath '\WormCrawler\' -TaskName 'WormCrawler-Verificare'
            if ((-not $vt) -or ($vt.State -eq 'Disabled')) {
                if (-not $verifAlarm) {
                    $verifAlarm = $true
                    Invoke-Alarm 'Verificarea automata (WormCrawler-Verificare) a fost STEARSA sau DEZACTIVATA.' 'Cineva incearca sa dezactiveze protectia.'
                }
            } else { $verifAlarm = $false }
            $now = Get-Exclusions
            if ($null -ne $now) {
                $added = @($now | Where-Object { $baseline -notcontains $_ })
                if ($added.Count -gt 0) {
                    Invoke-Alarm 'S-a adaugat o EXCLUDERE in Windows Defender.' ($added -join '; ')
                }
                $baseline = $now
            }
        }
        if ($tick % 150 -eq 0) { Enable-ProcessAuditing; Set-CookieAudit | Out-Null }   # reaplica la ~5 minute (si pe profile noi)
    }
    catch {
        Write-Log "Eroare interna: $($_.Exception.Message)"
    }
    Start-Sleep -Seconds 2
}
