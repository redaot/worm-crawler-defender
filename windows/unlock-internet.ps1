# Worm-Crawler Defender - unlock the internet (asks for the PIN)
# made by REDAOT
$WcdVersion = 'v1.0.0'
$ErrorActionPreference = 'SilentlyContinue'
$Dir = 'C:\ProgramData\WormCrawler'
. (Join-Path $Dir 'pin.ps1')
$AdaptFile = Join-Path $Dir 'saved_adapters.txt'
$BlockFlag = Join-Path $Dir 'blocked.flag'

Write-Host "== Worm-Crawler Defender $WcdVersion - Unlock Internet ==" -ForegroundColor Cyan
if (Test-Path $BlockFlag) {
    Write-Host ('Block reason: ' + (Get-Content $BlockFlag -Raw).Trim()) -ForegroundColor Yellow
}
Write-Host ''
if (-not (Confirm-Pin 'unlocking the internet')) {
    Write-Host 'Wrong PIN 3 times. The internet stays blocked.' -ForegroundColor Red
    exit 1
}

# lift the block first, otherwise the guard would disable the adapters again
Remove-Item $BlockFlag -Force

$names = @()
if (Test-Path $AdaptFile) { $names = @(Get-Content $AdaptFile | Where-Object { $_ }) }
if ($names.Count -gt 0) {
    foreach ($n in $names) {
        Enable-NetAdapter -Name $n -Confirm:$false
        Write-Host "Enabled: $n" -ForegroundColor Green
    }
    Remove-Item $AdaptFile -Force
} else {
    Write-Host 'No adapters recorded by Worm-Crawler Defender. Enabling all disabled adapters...' -ForegroundColor Yellow
    Get-NetAdapter | Where-Object { $_.Status -eq 'Disabled' } | ForEach-Object {
        Enable-NetAdapter -Name $_.Name -Confirm:$false
        Write-Host "Enabled: $($_.Name)" -ForegroundColor Green
    }
}
Add-Content -Path (Join-Path $Dir 'wormcrawler.log') -Encoding UTF8 -Value ('{0}  Internet unlocked manually by the user (correct PIN).' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))
Write-Host ''
Write-Host 'The internet has been unlocked. It may take a few seconds to reconnect.'
Write-Host 'made by REDAOT' -ForegroundColor DarkGray
