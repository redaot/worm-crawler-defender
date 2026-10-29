# Install Worm-Crawler Defender (runs as Administrator, via 1_Install.cmd)
$WcdVersion = 'v1.1.0'
$ErrorActionPreference = 'Stop'
$Src = Split-Path -Parent $MyInvocation.MyCommand.Path
$Dir = 'C:\ProgramData\WormCrawler'

Write-Host '==================================================' -ForegroundColor Cyan
Write-Host "   WORM-CRAWLER DEFENDER $WcdVersion  -  made by REDAOT" -ForegroundColor Cyan
Write-Host '==================================================' -ForegroundColor Cyan

# 0. Clean up the old version (when the program was called "Garda"), if present
if (Get-ScheduledTask -TaskPath '\Garda\' -ErrorAction SilentlyContinue) {
    foreach ($t in 'Garda', 'Garda-Alerta', 'Garda-Verificare', 'Garda-Tray') {
        Stop-ScheduledTask -TaskPath '\Garda\' -TaskName $t -ErrorAction SilentlyContinue
        Unregister-ScheduledTask -TaskPath '\Garda\' -TaskName $t -Confirm:$false -ErrorAction SilentlyContinue
    }
    Remove-Item 'C:\ProgramData\Garda' -Recurse -Force -ErrorAction SilentlyContinue
    $d0 = [Environment]::GetFolderPath('CommonDesktopDirectory')
    Remove-Item (Join-Path $d0 'Garda - Reporneste internetul.lnk'), (Join-Path $d0 'Garda - Reporneste internetul.cmd') -Force -ErrorAction SilentlyContinue
    Write-Host '[OK] The old version (Garda) was replaced'
}
# 0a. Clean up the previous Romanian-named layout, if present (upgrade to English build)
foreach ($t in 'WormCrawler-Alerta', 'WormCrawler-Verificare') {
    Unregister-ScheduledTask -TaskPath '\WormCrawler\' -TaskName $t -Confirm:$false -ErrorAction SilentlyContinue
}
$deskOld = [Environment]::GetFolderPath('CommonDesktopDirectory')
Remove-Item (Join-Path $deskOld 'Worm-Crawler Defender - Reporneste internetul.lnk') -Force -ErrorAction SilentlyContinue
foreach ($of in 'alerta.ps1','verificare.ps1','protectie.ps1','reporneste_internet.ps1','instaleaza.ps1','dezinstaleaza.ps1',
                'reporneste_internet.cmd','opreste_protectia.cmd','porneste_protectia.cmd','schimba_pin.cmd') {
    Remove-Item (Join-Path $Dir $of) -Force -ErrorAction SilentlyContinue
}

# 0b. PIN: on reinstall the existing PIN is required; on first install you choose one.
#     The PIN is kept in a separate folder (C:\ProgramData\WormCrawler-Secure),
#     so it survives deletion of the program folder.
. (Join-Path $Src 'pin.ps1')
Protect-SecureDir
if (Test-PinExists) {
    Write-Host 'Worm-Crawler Defender is already installed. Reinstall/update requires the PIN.'
    if (-not (Confirm-Pin 'reinstall')) { Write-Host 'Wrong PIN. Installation cancelled.' -ForegroundColor Red; exit 1 }
    $r = Read-Host 'Do you want to change the PIN? (y/N)'
    if ($r -match '^[yY]') { Set-NewPin }
} else {
    Write-Host ''
    Write-Host 'Choose a 4-digit PIN. You will use it to stop the protection,' -ForegroundColor Cyan
    Write-Host 'unlock the internet after an alert, and uninstall the program.' -ForegroundColor Cyan
    Set-NewPin
}

# 0c. Temporarily stop the installed version (authorized stop) so it can be replaced
if (Test-Path $Dir) { Set-Content -Path (Join-Path $Dir 'authorized.flag') -Value (Get-Date -Format 'o') -Encoding ASCII }
Stop-ScheduledTask -TaskPath '\WormCrawler\' -TaskName 'WormCrawler' -ErrorAction SilentlyContinue
Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" |
    Where-Object { $_.CommandLine -like '*\ProgramData\WormCrawler\*' } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }

# 1. Copy files
New-Item -ItemType Directory -Path $Dir -Force | Out-Null
foreach ($f in 'wormcrawler.ps1', 'alert.ps1', 'watchdog.ps1', 'tray.ps1', 'unlock-internet.ps1', 'pin.ps1', 'protect.ps1', 'cookie-guard.ps1', 'wormcrawler.ico', 'wormcrawler.png') {
    Copy-Item -Path (Join-Path $Src $f) -Destination $Dir -Force
}
# enable cookie auditing on the browser secret files right away
. (Join-Path $Dir 'cookie-guard.ps1')
$nCk = Set-CookieAudit
Write-Host "[OK] Cookie auditing enabled on $nCk browser files"

function New-ElevatedCmd([string]$name, [string]$title, [string]$psArgs) {
    $c = "@echo off`r`ntitle $title - made by REDAOT`r`n" +
         "net session >nul 2>&1 || (powershell -NoProfile -Command `"Start-Process -FilePath '%~f0' -Verb RunAs`" & exit /b)`r`n" +
         "powershell -NoProfile -ExecutionPolicy Bypass $psArgs`r`npause`r`n"
    Set-Content -Path (Join-Path $Dir $name) -Value $c -Encoding ASCII
}
New-ElevatedCmd 'unlock-internet.cmd'  'Worm-Crawler Defender - Unlock Internet'  "-File `"$Dir\unlock-internet.ps1`""
New-ElevatedCmd 'stop-protection.cmd'  'Worm-Crawler Defender - Stop Protection'  "-File `"$Dir\protect.ps1`" -Action Stop"
New-ElevatedCmd 'start-protection.cmd' 'Worm-Crawler Defender - Start Protection' "-File `"$Dir\protect.ps1`" -Action Start"
New-ElevatedCmd 'change-pin.cmd'       'Worm-Crawler Defender - Change PIN'       "-File `"$Dir\protect.ps1`" -Action ChangePin"
Get-ChildItem $Dir -File | Unblock-File

# 2. Permissions: only Administrators and SYSTEM can modify the scripts.
#    (Otherwise a non-admin program could modify the script that runs as SYSTEM.)
& icacls.exe $Dir /inheritance:r /grant:r '*S-1-5-18:(OI)(CI)F' '*S-1-5-32-544:(OI)(CI)F' '*S-1-5-32-545:(OI)(CI)RX' | Out-Null
Write-Host '[OK] Files copied to C:\ProgramData\WormCrawler'

# 3. Enable process-creation auditing (needed for encoded-PowerShell detection)
auditpol.exe /set /subcategory:"{0CCE922B-69AE-11D9-BED3-505054503030}" /success:enable | Out-Null
$k = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\Audit'
if (-not (Test-Path $k)) { New-Item -Path $k -Force | Out-Null }
Set-ItemProperty -Path $k -Name 'ProcessCreationIncludeCmdLine_Enabled' -Value 1 -Type DWord
Write-Host '[OK] Process auditing enabled'

# 4. Main task: runs as SYSTEM, at PC startup, restarts if stopped
Unregister-ScheduledTask -TaskPath '\WormCrawler\' -TaskName 'WormCrawler' -Confirm:$false -ErrorAction SilentlyContinue
$act  = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$Dir\wormcrawler.ps1`""
$trg  = New-ScheduledTaskTrigger -AtStartup
$prn  = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
$set  = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable `
        -ExecutionTimeLimit ([TimeSpan]::Zero) -RestartCount 999 -RestartInterval (New-TimeSpan -Minutes 1) `
        -MultipleInstances IgnoreNew
Register-ScheduledTask -TaskPath '\WormCrawler\' -TaskName 'WormCrawler' -Action $act -Trigger $trg -Principal $prn -Settings $set -Force | Out-Null
Write-Host '[OK] Task "WormCrawler" created (runs as SYSTEM at every startup)'

# 5. Alert task: shows the message on any logged-in user's screen
Unregister-ScheduledTask -TaskPath '\WormCrawler\' -TaskName 'WormCrawler-Alert' -Confirm:$false -ErrorAction SilentlyContinue
$users = (New-Object System.Security.Principal.SecurityIdentifier 'S-1-5-32-545').Translate([System.Security.Principal.NTAccount]).Value
$actA  = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$Dir\alert.ps1`""
$prnA  = New-ScheduledTaskPrincipal -GroupId $users -RunLevel Limited
$setA  = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -MultipleInstances Parallel
Register-ScheduledTask -TaskPath '\WormCrawler\' -TaskName 'WormCrawler-Alert' -Action $actA -Principal $prnA -Settings $setA -Force | Out-Null
Write-Host '[OK] Task "WormCrawler-Alert" created'

# 5b. Watchdog task: at logon + every minute, check that Worm-Crawler Defender is running
Unregister-ScheduledTask -TaskPath '\WormCrawler\' -TaskName 'WormCrawler-Watchdog' -Confirm:$false -ErrorAction SilentlyContinue
$actV = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$Dir\watchdog.ps1`""
$trgL = New-ScheduledTaskTrigger -AtLogOn
$trgL.Delay = 'PT1M'
$trgR = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) -RepetitionInterval (New-TimeSpan -Minutes 1)
$prnV = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
$setV = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable `
        -ExecutionTimeLimit (New-TimeSpan -Minutes 2) -MultipleInstances IgnoreNew
Register-ScheduledTask -TaskPath '\WormCrawler\' -TaskName 'WormCrawler-Watchdog' -Action $actV -Trigger $trgL, $trgR -Principal $prnV -Settings $setV -Force | Out-Null
Write-Host '[OK] Task "WormCrawler-Watchdog" created (at logon and every minute)'

# 5c. System-tray icon, at each user's logon
Unregister-ScheduledTask -TaskPath '\WormCrawler\' -TaskName 'WormCrawler-Tray' -Confirm:$false -ErrorAction SilentlyContinue
$actT = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -STA -File `"$Dir\tray.ps1`""
$trgT = New-ScheduledTaskTrigger -AtLogOn
$prnT = New-ScheduledTaskPrincipal -GroupId $users -RunLevel Limited
$setT = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit ([TimeSpan]::Zero) -MultipleInstances Parallel
Register-ScheduledTask -TaskPath '\WormCrawler\' -TaskName 'WormCrawler-Tray' -Action $actT -Trigger $trgT -Principal $prnT -Settings $setT -Force | Out-Null
Write-Host '[OK] System-tray icon (starts at logon)'

# 6. Desktop shortcut (with the Worm-Crawler Defender icon) to unlock the internet
$desk = [Environment]::GetFolderPath('CommonDesktopDirectory')
$wsh = New-Object -ComObject WScript.Shell
$lnk = $wsh.CreateShortcut((Join-Path $desk 'Worm-Crawler Defender - Unlock Internet.lnk'))
$lnk.TargetPath   = "$Dir\unlock-internet.cmd"
$lnk.IconLocation = "$Dir\wormcrawler.ico,0"
$lnk.Description  = 'Worm-Crawler Defender - unlock the internet (made by REDAOT)'
$lnk.Save()
Write-Host '[OK] Desktop shortcut "Worm-Crawler Defender - Unlock Internet" created'

# 7. Start now (cancel the temporary stop from step 0c)
Remove-Item (Join-Path $Dir 'authorized.flag') -Force -ErrorAction SilentlyContinue
Start-ScheduledTask -TaskPath '\WormCrawler\' -TaskName 'WormCrawler'
Start-ScheduledTask -TaskPath '\WormCrawler\' -TaskName 'WormCrawler-Tray'
Start-Sleep -Seconds 3
$state = (Get-ScheduledTask -TaskPath '\WormCrawler\' -TaskName 'WormCrawler').State
Write-Host ''
if ($state -eq 'Running') {
    Write-Host "Worm-Crawler Defender is RUNNING. Log: $Dir\wormcrawler.log" -ForegroundColor Green
} else {
    Write-Host "Warning: the WormCrawler task is in state '$state'. Check Task Scheduler > WormCrawler." -ForegroundColor Yellow
}
Write-Host ''
Write-Host "made by REDAOT  -  $WcdVersion" -ForegroundColor DarkGray
