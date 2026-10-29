# Worm-Crawler Defender - opreste / porneste protectia
#   protectie.ps1 -Actiune Opreste   (cere PIN-ul)
#   protectie.ps1 -Actiune Porneste
#   protectie.ps1 -Actiune SchimbaPin (cere PIN-ul vechi)
# made by REDAOT
param([ValidateSet('Opreste', 'Porneste', 'SchimbaPin')][string]$Actiune = 'Opreste')
$ErrorActionPreference = 'SilentlyContinue'
$Dir = 'C:\ProgramData\WormCrawler'
. (Join-Path $Dir 'pin.ps1')
$AuthFlag = Join-Path $Dir 'autorizat.flag'
$Log = Join-Path $Dir 'wormcrawler.log'
function Write-Log([string]$m) { Add-Content -Path $Log -Encoding UTF8 -Value ('{0}  {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $m) }

Write-Host "== Worm-Crawler Defender - $Actiune ==" -ForegroundColor Cyan
switch ($Actiune) {
    'Opreste' {
        if (-not (Confirm-Pin 'oprirea protectiei')) { Write-Host 'PIN gresit. Protectia ramane pornita.' -ForegroundColor Red; exit 1 }
        Set-Content -Path $AuthFlag -Value (Get-Date -Format 'o') -Encoding ASCII
        Stop-ScheduledTask -TaskPath '\WormCrawler\' -TaskName 'WormCrawler'
        Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" |
            Where-Object { $_.CommandLine -like '*\WormCrawler\wormcrawler.ps1*' } |
            ForEach-Object { Stop-Process -Id $_.ProcessId -Force }
        Write-Log 'Protectie OPRITA de utilizator (PIN corect).'
        Write-Host 'Protectia e OPRITA. Porneste din nou automat la urmatoarea pornire a PC-ului,' -ForegroundColor Yellow
        Write-Host 'sau din iconita: "Porneste protectia".' -ForegroundColor Yellow
    }
    'Porneste' {
        Remove-Item $AuthFlag -Force
        Start-ScheduledTask -TaskPath '\WormCrawler\' -TaskName 'WormCrawler'
        Write-Log 'Protectie PORNITA de utilizator.'
        Write-Host 'Protectia e PORNITA.' -ForegroundColor Green
    }
    'SchimbaPin' {
        if (-not (Confirm-Pin 'schimbarea PIN-ului')) { Write-Host 'PIN gresit. PIN-ul nu a fost schimbat.' -ForegroundColor Red; exit 1 }
        Set-NewPin
        Write-Log 'PIN schimbat de utilizator.'
    }
}
Write-Host 'made by REDAOT' -ForegroundColor DarkGray
