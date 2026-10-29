# ==========================================================================
#  WORM-CRAWLER DEFENDER - watchdog (runs as SYSTEM, every minute)
#  If the protection is NOT running and was not stopped with the PIN:
#    -> BLOCKS the internet (and keeps it blocked until the PIN is entered)
#    -> tries to restart the protection
#    -> shows an on-screen alert WINDOW
#  made by REDAOT
# ==========================================================================
$WcdVersion = 'v1.1.0'
$ErrorActionPreference = 'SilentlyContinue'
$Dir       = 'C:\ProgramData\WormCrawler'
$BeatFile  = Join-Path $Dir 'heartbeat.txt'
$AlertFile = Join-Path $Dir 'alert.txt'
$LogFile   = Join-Path $Dir 'wormcrawler.log'
$CoolFile  = Join-Path $Dir 'wd_cooldown.txt'
$AdaptFile = Join-Path $Dir 'saved_adapters.txt'
$BlockFlag = Join-Path $Dir 'blocked.flag'
$AuthFlag  = Join-Path $Dir 'authorized.flag'

function Write-Log([string]$msg) {
    Add-Content -Path $LogFile -Encoding UTF8 -Value ('{0}  [Watchdog] {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $msg)
}

function Disable-Network {
    $active = @(Get-NetAdapter | Where-Object { $_.Status -ne 'Disabled' })
    if ($active.Count -eq 0) { return }
    $names = $active | ForEach-Object { $_.Name }
    $old = @()
    if (Test-Path $AdaptFile) { $old = @(Get-Content $AdaptFile) }
    ($old + $names) | Where-Object { $_ } | Sort-Object -Unique | Set-Content -Path $AdaptFile -Encoding UTF8
    $active | Disable-NetAdapter -Confirm:$false
    Write-Log ("Network disabled: " + ($names -join ', '))
}

function Test-WCAlive {
    $task = Get-ScheduledTask -TaskPath '\WormCrawler\' -TaskName 'WormCrawler'
    if (-not $task) { return 'missing' }
    if ($task.State -eq 'Disabled') { return 'disabled' }
    if ($task.State -ne 'Running') { return 'stopped' }
    if (-not (Test-Path $BeatFile)) { return 'stuck' }
    $age = ((Get-Date) - (Get-Item $BeatFile).LastWriteTime).TotalSeconds
    if ($age -gt 90) { return 'stuck' }
    return 'ok'
}

$status = Test-WCAlive
if ($status -eq 'ok') { exit 0 }

# Stopped with the PIN -> everything is fine, do nothing
if (Test-Path $AuthFlag) { exit 0 }

# ---- stopped WITHOUT the PIN: block the internet
$problem = switch ($status) {
    'missing'  { 'The WormCrawler task was DELETED from Task Scheduler.' }
    'disabled' { 'The WormCrawler task was DISABLED.' }
    'stopped'  { 'Worm-Crawler Defender was STOPPED (force-closed, without PIN).' }
    'stuck'    { 'Worm-Crawler Defender is running but not responding (stuck).' }
}
Write-Log "Protection stopped without PIN (state: $status). Blocking the internet and trying to restart..."
if (-not (Test-Path $BlockFlag)) {
    Set-Content -Path $BlockFlag -Value ("{0} | {1}" -f (Get-Date -Format 'o'), $problem) -Encoding UTF8
}
Disable-Network

# ---- try to restart
$restarted = $false
if ($status -ne 'missing') {
    if ($status -eq 'disabled') { Enable-ScheduledTask -TaskPath '\WormCrawler\' -TaskName 'WormCrawler' | Out-Null }
    if ($status -eq 'stuck') { Stop-ScheduledTask -TaskPath '\WormCrawler\' -TaskName 'WormCrawler'; Start-Sleep -Seconds 3 }
    Start-ScheduledTask -TaskPath '\WormCrawler\' -TaskName 'WormCrawler'
    Start-Sleep -Seconds 25
    if ((Test-WCAlive) -eq 'ok') { $restarted = $true }
}
Write-Log ("Restart result: " + $(if ($restarted) { 'success' } else { 'FAILED' }))

# ---- alert window (same alert at most once every 15 minutes)
if ((Test-Path $CoolFile) -and (((Get-Date) - (Get-Item $CoolFile).LastWriteTime).TotalMinutes -lt 15)) { exit 0 }
Set-Content -Path $CoolFile -Value (Get-Date -Format 'o')

$common = "THE INTERNET HAS BEEN BLOCKED and stays blocked until you enter your PIN`r`n" +
          "('Worm-Crawler Defender - Unlock Internet', from the Desktop or the tray icon).`r`n`r`n"
if ($restarted) {
    $title = "WORM-CRAWLER DEFENDER $WcdVersion - STOPPED WITHOUT PIN - INTERNET BLOCKED"
    $body  = "WARNING! $problem`r`n`r`n" + $common +
             "The protection was restarted automatically and is working again.`r`n`r`n" +
             "If you did not stop it, a program tried to kill it.`r`n" +
             "Think about what you installed / ran recently and scan the PC.`r`n`r`n" +
             "Log: $LogFile"
} else {
    $title = "WORM-CRAWLER DEFENDER $WcdVersion - NOT RUNNING - INTERNET BLOCKED"
    $body  = "WARNING! $problem`r`n`r`n" + $common +
             "The automatic restart FAILED.`r`n`r`n" +
             "What to do:`r`n" +
             " - Run 1_Install.cmd again`r`n" +
             " - If you did not stop it, do not run new programs and scan the PC.`r`n`r`n" +
             "Log: $LogFile"
}
Set-Content -Path $AlertFile -Value ("$title`r`n" + $body) -Encoding UTF8

if (Get-ScheduledTask -TaskPath '\WormCrawler\' -TaskName 'WormCrawler-Alert') {
    Start-ScheduledTask -TaskPath '\WormCrawler\' -TaskName 'WormCrawler-Alert'
} else {
    & msg.exe * /TIME:0 "$title - $problem"
}
