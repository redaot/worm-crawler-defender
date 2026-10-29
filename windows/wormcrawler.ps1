# ==========================================================================
#  WORM-CRAWLER DEFENDER - anti-dropper / anti-stealer guard
#  Runs permanently as SYSTEM (scheduled task at startup).
#  Blocks the internet and shows an alert when it detects:
#    1. a new Microsoft Defender exclusion
#    2. Defender real-time protection turned off
#    3. PowerShell started with an encoded command (-EncodedCommand)
#    4. a non-browser process reading the browser cookies/credentials
# ==========================================================================

$WcdVersion = 'v1.0.0'
$ErrorActionPreference = 'SilentlyContinue'
$Dir        = 'C:\ProgramData\WormCrawler'
. (Join-Path $Dir 'cookie-guard.ps1')
$LogFile    = Join-Path $Dir 'wormcrawler.log'
$AlertFile  = Join-Path $Dir 'alert.txt'
$AdaptFile  = Join-Path $Dir 'saved_adapters.txt'
$BeatFile   = Join-Path $Dir 'heartbeat.txt'
$BlockFlag  = Join-Path $Dir 'blocked.flag'      # internet blocked until the PIN is entered
$AuthFlag   = Join-Path $Dir 'authorized.flag'   # protection stopped with the PIN
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
    $all += @($p.ExclusionPath      | ForEach-Object { "Path: $_" })
    $all += @($p.ExclusionProcess   | ForEach-Object { "Process: $_" })
    $all += @($p.ExclusionExtension | ForEach-Object { "Extension: $_" })
    $all += @($p.ExclusionIpAddress | ForEach-Object { "IP: $_" })
    return @($all | Where-Object { $_ -and $_ -notmatch 'N/A' } | Sort-Object -Unique)
}

function Enable-ProcessAuditing {
    # Audit "Process Creation" (GUID, works on any Windows language)
    auditpol.exe /set /subcategory:"{0CCE922B-69AE-11D9-BED3-505054503030}" /success:enable | Out-Null
    $k = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\Audit'
    if (-not (Test-Path $k)) { New-Item -Path $k -Force | Out-Null }
    Set-ItemProperty -Path $k -Name 'ProcessCreationIncludeCmdLine_Enabled' -Value 1 -Type DWord
}

$script:LastAlarm = [datetime]::MinValue

function Disable-Network {
    # Disable every active network adapter (Ethernet, Wi-Fi, etc.) and record them
    $active = @(Get-NetAdapter | Where-Object { $_.Status -ne 'Disabled' })
    if ($active.Count -eq 0) { return }
    $names = $active | ForEach-Object { $_.Name }
    $old = @()
    if (Test-Path $AdaptFile) { $old = @(Get-Content $AdaptFile) }
    ($old + $names) | Where-Object { $_ } | Sort-Object -Unique | Set-Content -Path $AdaptFile -Encoding UTF8
    $active | Disable-NetAdapter -Confirm:$false
    Write-Log ("Network disabled: " + ($names -join ', '))
}

function Invoke-Alarm([string]$reason, [string]$details) {
    Write-Log "ALARM: $reason | $details"

    # 1. Block the internet until the PIN is entered
    Set-Content -Path $BlockFlag -Value ("{0} | {1}" -f (Get-Date -Format 'o'), $reason) -Encoding UTF8
    Disable-Network

    # 2. On-screen alert (at most once every 30 seconds, to avoid spam)
    if (((Get-Date) - $script:LastAlarm).TotalSeconds -gt 30) {
        $script:LastAlarm = Get-Date
        $text = "WARNING! Possible DROPPER / MALWARE detected.`r`n" +
                "THE INTERNET (LAN / Wi-Fi) HAS BEEN BLOCKED.`r`n`r`n" +
                "Reason: $reason`r`n`r`n" +
                "Details: $details`r`n`r`n" +
                "What to do now:`r`n" +
                " - Do NOT unlock the internet unless you are sure what triggered the alert.`r`n" +
                " - Close the program you just ran / installed.`r`n" +
                " - Scan with ESET Online Scanner (download it on another device onto a USB stick).`r`n" +
                " - The internet stays blocked until you enter your PIN, from`r`n" +
                "   'Worm-Crawler Defender - Unlock Internet' (Desktop or tray icon).`r`n`r`n" +
                "Full log: $LogFile"
        Set-Content -Path $AlertFile -Value ("WORM-CRAWLER DEFENDER $WcdVersion - MALWARE DETECTED - INTERNET BLOCKED`r`n" + $text) -Encoding UTF8
        Start-ScheduledTask -TaskPath '\WormCrawler\' -TaskName 'WormCrawler-Alert'
    }
}

# ---------------------------------------------------------------- startup
if (-not (Test-Path $Dir)) { New-Item -ItemType Directory -Path $Dir -Force | Out-Null }
Write-Log "Worm-Crawler Defender $WcdVersion started."
# a fresh start means protection is active: cancel any authorized stop
Remove-Item $AuthFlag -Force
if (Test-Path $BlockFlag) {
    Write-Log 'The internet was blocked (no PIN) - the block stays active.'
    Disable-Network
}
$verifAlarm = $false
Enable-ProcessAuditing
$nAudit = Set-CookieAudit
Write-Log ("Cookie auditing enabled on $nAudit browser files.")

$lastSec  = Get-LastRecordId 'Security'
$lastDef  = Get-LastRecordId $DefLog
$baseline = Get-Exclusions
if ($null -eq $baseline) { $baseline = @() }
Write-Log ("Existing exclusions at startup: " + $(if ($baseline.Count) { $baseline -join '; ' } else { '(none)' }))

$encRegex = '(?i)(^|\s)[-/]e[a-z]*\s+["'']?[A-Za-z0-9+/=]{40,}'
$tick = 0

# ---------------------------------------------------------------- loop
while ($true) {
    try {
        # 0) Active block -> keep the internet down (even if someone re-enables it from Settings)
        if (Test-Path $BlockFlag) { Disable-Network }

        # A) Security events: 4688 = new process, 4663 = access to an audited file
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
                    Write-Log "Decoded PowerShell command: $decoded"
                    Invoke-Alarm 'PowerShell was started with a hidden (encoded) command.' "Started by: $parent"
                }
            }
            elseif ($e.Id -eq 4663) {
                $obj = Get-EventField $e 'ObjectName'
                if ($obj -and ($obj -match $script:CookieRegex)) {
                    $pn = Get-EventField $e 'ProcessName'
                    $leaf = (($pn -split '\\')[-1]).ToLower()
                    if (($script:BrowserWhitelist -notcontains $leaf) -and ($pn -notmatch '(?i)WormCrawler')) {
                        Invoke-Alarm 'A program tried to read the browser COOKIES / credentials.' "Program: $pn`r`nFile: $obj"
                    }
                }
            }
        }
        $lastSec = $newestSec

        # B) New Defender exclusion (event 5007 = configuration changed)
        $newestDef = Get-LastRecordId $DefLog
        foreach ($e in (Get-NewEvents $DefLog 5007 $lastDef $newestDef)) {
            $new = Get-EventField $e 'New Value'
            if (-not $new) { $new = [string]$e.Properties[$e.Properties.Count - 1].Value }
            if ($new -match '(?i)\\Exclusions\\') {
                Invoke-Alarm 'A new EXCLUSION was added in Windows Defender.' $new
                $baseline = Get-Exclusions
            }
        }

        # C) Real-time protection turned off (event 5001)
        $rt = Get-NewEvents $DefLog 5001 $lastDef $newestDef
        if ($rt.Count -gt 0) {
            Invoke-Alarm 'Windows Defender real-time protection was turned OFF.' 'Defender event 5001'
        }
        if ($newestDef -gt $lastDef) { $lastDef = $newestDef }

        # D) Backup check: the exclusions list, every ~10 seconds
        $tick++
        if ($tick % 5 -eq 0) {
            # heartbeat for the watchdog (WormCrawler-Watchdog)
            Set-Content -Path $BeatFile -Value (Get-Date -Format 'o') -Encoding ASCII

            # E) Mutual guard: the watchdog must exist and be enabled
            $vt = Get-ScheduledTask -TaskPath '\WormCrawler\' -TaskName 'WormCrawler-Watchdog'
            if ((-not $vt) -or ($vt.State -eq 'Disabled')) {
                if (-not $verifAlarm) {
                    $verifAlarm = $true
                    Invoke-Alarm 'The watchdog (WormCrawler-Watchdog) was DELETED or DISABLED.' 'Someone is trying to disable the protection.'
                }
            } else { $verifAlarm = $false }
            $now = Get-Exclusions
            if ($null -ne $now) {
                $added = @($now | Where-Object { $baseline -notcontains $_ })
                if ($added.Count -gt 0) {
                    Invoke-Alarm 'A new EXCLUSION was added in Windows Defender.' ($added -join '; ')
                }
                $baseline = $now
            }
        }
        if ($tick % 150 -eq 0) { Enable-ProcessAuditing; Set-CookieAudit | Out-Null }   # reapply every ~5 min (and for new profiles)
    }
    catch {
        Write-Log "Internal error: $($_.Exception.Message)"
    }
    Start-Sleep -Seconds 2
}
