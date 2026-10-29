# Worm-Crawler Defender - uninstall (asks for the PIN). made by REDAOT
$WcdVersion = 'v1.0.0'
$ErrorActionPreference = 'SilentlyContinue'
$Dir = 'C:\ProgramData\WormCrawler'
$pinLib = Join-Path $Dir 'pin.ps1'
if (-not (Test-Path $pinLib)) { $pinLib = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'pin.ps1' }
. $pinLib

Write-Host "== Worm-Crawler Defender $WcdVersion - Uninstall ==" -ForegroundColor Cyan
if (Test-PinExists) {
    if (-not (Confirm-Pin 'uninstall')) { Write-Host 'Wrong PIN. Uninstall cancelled.' -ForegroundColor Red; exit 1 }
}

# authorized stop, so the watchdog does not block the internet during uninstall
if (-not (Test-Path $Dir)) { New-Item -ItemType Directory -Path $Dir -Force | Out-Null }
Set-Content -Path (Join-Path $Dir 'authorized.flag') -Value (Get-Date -Format 'o') -Encoding ASCII
Stop-ScheduledTask -TaskPath '\WormCrawler\' -TaskName 'WormCrawler'
Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" |
    Where-Object { $_.CommandLine -like '*\WormCrawler\wormcrawler.ps1*' -or $_.CommandLine -like '*\WormCrawler\tray.ps1*' } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force }
foreach ($t in 'WormCrawler-Watchdog', 'WormCrawler', 'WormCrawler-Alert', 'WormCrawler-Tray', 'WormCrawler-Verificare', 'WormCrawler-Alerta') {
    Unregister-ScheduledTask -TaskPath '\WormCrawler\' -TaskName $t -Confirm:$false
}

# unblock the internet if it was blocked
if (Test-Path (Join-Path $Dir 'saved_adapters.txt')) {
    Get-Content (Join-Path $Dir 'saved_adapters.txt') | Where-Object { $_ } |
        ForEach-Object { Enable-NetAdapter -Name $_ -Confirm:$false }
}
Remove-Item $Dir -Recurse -Force
# the PIN-protected folder (Administrators have full control, so it can be removed here)
& icacls.exe 'C:\ProgramData\WormCrawler-Secure' /grant:r '*S-1-5-32-544:(OI)(CI)F' | Out-Null
Remove-Item 'C:\ProgramData\WormCrawler-Secure' -Recurse -Force
$desk = [Environment]::GetFolderPath('CommonDesktopDirectory')
Remove-Item (Join-Path $desk 'Worm-Crawler Defender - Unlock Internet.lnk') -Force
Remove-Item (Join-Path $desk 'Worm-Crawler Defender - Reporneste internetul.lnk') -Force
Write-Host 'Worm-Crawler Defender has been uninstalled.' -ForegroundColor Green
Write-Host '(Process auditing stays enabled - it does not bother anything.)'
Write-Host "made by REDAOT  -  $WcdVersion" -ForegroundColor DarkGray
