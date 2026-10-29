# Worm-Crawler Defender - dezinstalare (cere PIN-ul)
# made by REDAOT
$ErrorActionPreference = 'SilentlyContinue'
$Dir = 'C:\ProgramData\WormCrawler'
$pinLib = Join-Path $Dir 'pin.ps1'
if (-not (Test-Path $pinLib)) { $pinLib = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'pin.ps1' }
. $pinLib

Write-Host '== Worm-Crawler Defender - Dezinstalare ==' -ForegroundColor Cyan
if (Test-PinExists) {
    if (-not (Confirm-Pin 'dezinstalare')) { Write-Host 'PIN gresit. Dezinstalarea a fost anulata.' -ForegroundColor Red; exit 1 }
}

# oprire autorizata, ca verificarea automata sa nu blocheze internetul in timpul dezinstalarii
Set-Content -Path (Join-Path $Dir 'autorizat.flag') -Value (Get-Date -Format 'o') -Encoding ASCII
Stop-ScheduledTask -TaskPath '\WormCrawler\' -TaskName 'WormCrawler'
Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" |
    Where-Object { $_.CommandLine -like '*\ProgramData\WormCrawler\*' } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force }
foreach ($t in 'WormCrawler-Verificare', 'WormCrawler', 'WormCrawler-Alerta', 'WormCrawler-Tray') {
    Unregister-ScheduledTask -TaskPath '\WormCrawler\' -TaskName $t -Confirm:$false
}

# Reporneste internetul daca era blocat
if (Test-Path (Join-Path $Dir 'adaptoare_oprite.txt')) {
    Get-Content (Join-Path $Dir 'adaptoare_oprite.txt') | Where-Object { $_ } |
        ForEach-Object { Enable-NetAdapter -Name $_ -Confirm:$false }
}
Remove-Item $Dir -Recurse -Force
# folderul protejat cu PIN-ul (Administratorii au drepturi depline, deci se poate sterge aici)
& icacls.exe 'C:\ProgramData\WormCrawler-Secure' /grant:r '*S-1-5-32-544:(OI)(CI)F' | Out-Null
Remove-Item 'C:\ProgramData\WormCrawler-Secure' -Recurse -Force
Remove-Item (Join-Path ([Environment]::GetFolderPath('CommonDesktopDirectory')) 'Worm-Crawler Defender - Reporneste internetul.lnk') -Force
Write-Host 'Worm-Crawler Defender a fost dezinstalat.' -ForegroundColor Green
Write-Host '(Auditul de procese ramane activ - nu deranjeaza nimic.)'
Write-Host 'made by REDAOT' -ForegroundColor DarkGray
