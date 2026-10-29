# Worm-Crawler Defender - stop / start protection, change PIN. made by REDAOT
#   protect.ps1 -Action Stop       (asks for PIN)
#   protect.ps1 -Action Start
#   protect.ps1 -Action ChangePin  (asks for the old PIN, then sets a new one)
#   protect.ps1 -Action Status
param([ValidateSet('Stop', 'Start', 'ChangePin', 'Status')][string]$Action = 'Status')
$WcdVersion = 'v1.0.0'
$ErrorActionPreference = 'SilentlyContinue'
$Dir = 'C:\ProgramData\WormCrawler'
. (Join-Path $Dir 'pin.ps1')
$AuthFlag = Join-Path $Dir 'authorized.flag'
$Log = Join-Path $Dir 'wormcrawler.log'
function Write-Log([string]$m) { Add-Content -Path $Log -Encoding UTF8 -Value ('{0}  {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $m) }

Write-Host "== Worm-Crawler Defender $WcdVersion - $Action ==" -ForegroundColor Cyan
switch ($Action) {
    'Stop' {
        if (-not (Confirm-Pin 'stopping the protection')) { Write-Host 'Wrong PIN. The protection stays on.' -ForegroundColor Red; exit 1 }
        if (-not (Test-Path $Dir)) { New-Item -ItemType Directory -Path $Dir -Force | Out-Null }
        Set-Content -Path $AuthFlag -Value (Get-Date -Format 'o') -Encoding ASCII
        Stop-ScheduledTask -TaskPath '\WormCrawler\' -TaskName 'WormCrawler'
        Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" |
            Where-Object { $_.CommandLine -like '*\WormCrawler\wormcrawler.ps1*' } |
            ForEach-Object { Stop-Process -Id $_.ProcessId -Force }
        Write-Log 'Protection STOPPED by the user (correct PIN).'
        Write-Host 'Protection is OFF. It starts again automatically at the next boot,' -ForegroundColor Yellow
        Write-Host 'or from the tray icon: "Start Protection".' -ForegroundColor Yellow
    }
    'Start' {
        Remove-Item $AuthFlag -Force
        Start-ScheduledTask -TaskPath '\WormCrawler\' -TaskName 'WormCrawler'
        Write-Log 'Protection STARTED by the user.'
        Write-Host 'Protection is ON.' -ForegroundColor Green
    }
    'ChangePin' {
        if (-not (Confirm-Pin 'changing the PIN')) { Write-Host 'Wrong PIN. The PIN was not changed.' -ForegroundColor Red; exit 1 }
        Set-NewPin
        Write-Log 'PIN changed by the user.'
    }
    'Status' {
        if (Test-Path $AuthFlag) { Write-Host 'Protection: STOPPED (with PIN)' }
        elseif (Get-ScheduledTask -TaskPath '\WormCrawler\' -TaskName 'WormCrawler' | Where-Object { $_.State -eq 'Running' }) { Write-Host 'Protection: ACTIVE' }
        else { Write-Host 'Protection: NOT RUNNING' }
        if (Test-Path (Join-Path $Dir 'blocked.flag')) { Write-Host 'Internet: BLOCKED (unlock with: Unlock Internet)' } else { Write-Host 'Internet: free' }
    }
}
Write-Host 'made by REDAOT' -ForegroundColor DarkGray
