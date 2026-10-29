# Worm-Crawler Defender - reporneste internetul (cere PIN-ul)
# made by REDAOT
$ErrorActionPreference = 'SilentlyContinue'
$Dir = 'C:\ProgramData\WormCrawler'
. (Join-Path $Dir 'pin.ps1')
$AdaptFile = Join-Path $Dir 'adaptoare_oprite.txt'
$BlockFlag = Join-Path $Dir 'blocare.flag'

Write-Host '== Worm-Crawler Defender - Reporneste internetul ==' -ForegroundColor Cyan
if (Test-Path $BlockFlag) {
    Write-Host ('Motivul blocarii: ' + (Get-Content $BlockFlag -Raw).Trim()) -ForegroundColor Yellow
}
Write-Host ''
if (-not (Confirm-Pin 'repornirea internetului')) {
    Write-Host 'PIN gresit de 3 ori. Internetul ramane blocat.' -ForegroundColor Red
    exit 1
}

# intai ridicam blocarea, altfel protectia ar opri din nou placile
Remove-Item $BlockFlag -Force

$names = @()
if (Test-Path $AdaptFile) { $names = @(Get-Content $AdaptFile | Where-Object { $_ }) }
if ($names.Count -gt 0) {
    foreach ($n in $names) {
        Enable-NetAdapter -Name $n -Confirm:$false
        Write-Host "Pornit: $n" -ForegroundColor Green
    }
    Remove-Item $AdaptFile -Force
} else {
    Write-Host 'Nu exista placi oprite de Worm-Crawler Defender. Pornesc toate placile de retea dezactivate...' -ForegroundColor Yellow
    Get-NetAdapter | Where-Object { $_.Status -eq 'Disabled' } | ForEach-Object {
        Enable-NetAdapter -Name $_.Name -Confirm:$false
        Write-Host "Pornit: $($_.Name)" -ForegroundColor Green
    }
}
Add-Content -Path (Join-Path $Dir 'wormcrawler.log') -Encoding UTF8 -Value ('{0}  Internet repornit manual de utilizator (PIN corect).' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))
Write-Host ''
Write-Host 'Internetul a fost repornit. Poate dura cateva secunde pana se conecteaza.'
Write-Host 'made by REDAOT' -ForegroundColor DarkGray
