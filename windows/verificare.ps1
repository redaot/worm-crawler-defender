# ==========================================================================
#  WORM-CRAWLER DEFENDER - verificare automata (ca SYSTEM, la fiecare minut)
#  Daca protectia NU ruleaza si nu a fost oprita cu PIN:
#    -> BLOCHEAZA internetul (si il tine blocat pana se introduce PIN-ul)
#    -> incearca s-o reporneasca
#    -> afiseaza o FEREASTRA de alerta pe ecran
#  made by REDAOT
# ==========================================================================
$ErrorActionPreference = 'SilentlyContinue'
$Dir       = 'C:\ProgramData\WormCrawler'
$BeatFile  = Join-Path $Dir 'heartbeat.txt'
$AlertFile = Join-Path $Dir 'alerta.txt'
$LogFile   = Join-Path $Dir 'wormcrawler.log'
$CoolFile  = Join-Path $Dir 'ultima_alerta_verificare.txt'
$AdaptFile = Join-Path $Dir 'adaptoare_oprite.txt'
$BlockFlag = Join-Path $Dir 'blocare.flag'
$AuthFlag  = Join-Path $Dir 'autorizat.flag'

function Write-Log([string]$msg) {
    Add-Content -Path $LogFile -Encoding UTF8 -Value ('{0}  [Verificare] {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $msg)
}

function Disable-Network {
    $active = @(Get-NetAdapter | Where-Object { $_.Status -ne 'Disabled' })
    if ($active.Count -eq 0) { return }
    $names = $active | ForEach-Object { $_.Name }
    $old = @()
    if (Test-Path $AdaptFile) { $old = @(Get-Content $AdaptFile) }
    ($old + $names) | Where-Object { $_ } | Sort-Object -Unique | Set-Content -Path $AdaptFile -Encoding UTF8
    $active | Disable-NetAdapter -Confirm:$false
    Write-Log ("Retea oprita: " + ($names -join ', '))
}

function Test-WCAlive {
    $task = Get-ScheduledTask -TaskPath '\WormCrawler\' -TaskName 'WormCrawler'
    if (-not $task) { return 'lipsa' }
    if ($task.State -eq 'Disabled') { return 'dezactivat' }
    if ($task.State -ne 'Running') { return 'oprit' }
    if (-not (Test-Path $BeatFile)) { return 'blocat' }
    $age = ((Get-Date) - (Get-Item $BeatFile).LastWriteTime).TotalSeconds
    if ($age -gt 90) { return 'blocat' }
    return 'ok'
}

$status = Test-WCAlive
if ($status -eq 'ok') { exit 0 }

# Oprit cu PIN -> totul e in regula, nu facem nimic
if (Test-Path $AuthFlag) { exit 0 }

# ---- oprit FARA PIN: blocheaza internetul
$problema = switch ($status) {
    'lipsa'      { 'Taskul WormCrawler a fost STERS din Task Scheduler.' }
    'dezactivat' { 'Taskul WormCrawler a fost DEZACTIVAT.' }
    'oprit'      { 'Worm-Crawler Defender a fost OPRIT (inchis fortat, fara PIN).' }
    'blocat'     { 'Worm-Crawler Defender ruleaza, dar nu mai raspunde (blocat).' }
}
Write-Log "Protectie oprita fara PIN (stare: $status). Blochez internetul si incerc repornirea..."
if (-not (Test-Path $BlockFlag)) {
    Set-Content -Path $BlockFlag -Value ("{0} | {1}" -f (Get-Date -Format 'o'), $problema) -Encoding UTF8
}
Disable-Network

# ---- incearca repornirea
$repornit = $false
if ($status -ne 'lipsa') {
    if ($status -eq 'dezactivat') { Enable-ScheduledTask -TaskPath '\WormCrawler\' -TaskName 'WormCrawler' | Out-Null }
    if ($status -eq 'blocat') { Stop-ScheduledTask -TaskPath '\WormCrawler\' -TaskName 'WormCrawler'; Start-Sleep -Seconds 3 }
    Start-ScheduledTask -TaskPath '\WormCrawler\' -TaskName 'WormCrawler'
    Start-Sleep -Seconds 25
    if ((Test-WCAlive) -eq 'ok') { $repornit = $true }
}
Write-Log ("Rezultat repornire: " + $(if ($repornit) { 'reusita' } else { 'ESUATA' }))

# ---- fereastra de alerta (aceeasi alerta cel mult o data la 15 minute)
if ((Test-Path $CoolFile) -and (((Get-Date) - (Get-Item $CoolFile).LastWriteTime).TotalMinutes -lt 15)) { exit 0 }
Set-Content -Path $CoolFile -Value (Get-Date -Format 'o')

$comun = "INTERNETUL A FOST BLOCAT si ramane blocat pana introduci PIN-ul tau`r`n" +
         "('Worm-Crawler Defender - Reporneste internetul', de pe Desktop sau din iconita).`r`n`r`n"
if ($repornit) {
    $title = 'WORM-CRAWLER DEFENDER - OPRIT FARA PIN - INTERNET BLOCAT'
    $body  = "ATENTIE! $problema`r`n`r`n" + $comun +
             "Protectia a fost repornita automat si functioneaza din nou.`r`n`r`n" +
             "Daca nu l-ai oprit tu, un program a incercat sa-l opreasca.`r`n" +
             "Gandeste-te ce ai instalat / rulat recent si scaneaza PC-ul.`r`n`r`n" +
             "Jurnal: $LogFile"
} else {
    $title = 'WORM-CRAWLER DEFENDER NU RULEAZA - INTERNET BLOCAT'
    $body  = "ATENTIE! $problema`r`n`r`n" + $comun +
             "Repornirea automata NU a reusit.`r`n`r`n" +
             "Ce faci:`r`n" +
             " - Ruleaza din nou 1_Instaleaza.cmd`r`n" +
             " - Daca nu l-ai oprit tu, nu rula programe noi si scaneaza PC-ul.`r`n`r`n" +
             "Jurnal: $LogFile"
}
Set-Content -Path $AlertFile -Value ("$title`r`n" + $body) -Encoding UTF8

if (Get-ScheduledTask -TaskPath '\WormCrawler\' -TaskName 'WormCrawler-Alerta') {
    Start-ScheduledTask -TaskPath '\WormCrawler\' -TaskName 'WormCrawler-Alerta'
} else {
    & msg.exe * /TIME:0 "$title - $problema"
}
