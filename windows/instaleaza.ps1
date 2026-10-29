# Instalare Worm-Crawler Defender (se ruleaza ca Administrator, prin Instaleaza.cmd)
$ErrorActionPreference = 'Stop'
$Src = Split-Path -Parent $MyInvocation.MyCommand.Path
$Dir = 'C:\ProgramData\WormCrawler'

Write-Host '==================================' -ForegroundColor Cyan
Write-Host '   WORM-CRAWLER DEFENDER  -  made by REDAOT' -ForegroundColor Cyan
Write-Host '==================================' -ForegroundColor Cyan

# 0. Curata versiunea veche (cand programul se numea Garda), daca exista
if (Get-ScheduledTask -TaskPath '\Garda\' -ErrorAction SilentlyContinue) {
    foreach ($t in 'Garda', 'Garda-Alerta', 'Garda-Verificare', 'Garda-Tray') {
        Stop-ScheduledTask -TaskPath '\Garda\' -TaskName $t -ErrorAction SilentlyContinue
        Unregister-ScheduledTask -TaskPath '\Garda\' -TaskName $t -Confirm:$false -ErrorAction SilentlyContinue
    }
    Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" |
        Where-Object { $_.CommandLine -like '*\ProgramData\Garda\*' } |
        ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
    if (Test-Path 'C:\ProgramData\Garda\adaptoare_oprite.txt') {
        Get-Content 'C:\ProgramData\Garda\adaptoare_oprite.txt' | Where-Object { $_ } |
            ForEach-Object { Enable-NetAdapter -Name $_ -Confirm:$false -ErrorAction SilentlyContinue }
    }
    Remove-Item 'C:\ProgramData\Garda' -Recurse -Force -ErrorAction SilentlyContinue
    $d0 = [Environment]::GetFolderPath('CommonDesktopDirectory')
    Remove-Item (Join-Path $d0 'Garda - Reporneste internetul.lnk'), (Join-Path $d0 'Garda - Reporneste internetul.cmd') -Force -ErrorAction SilentlyContinue
    Write-Host '[OK] Versiunea veche (Garda) a fost inlocuita'
}

# 0b. PIN: la o reinstalare se cere PIN-ul existent; la prima instalare se alege unul
#     PIN-ul se tine intr-un folder separat (C:\ProgramData\WormCrawler-Secure),
#     ca sa supravietuiasca stergerii folderului programului.
. (Join-Path $Src 'pin.ps1')
Protect-SecureDir
if (Test-PinExists) {
    Write-Host 'Worm-Crawler Defender e deja instalat. Pentru reinstalare/actualizare e nevoie de PIN.'
    if (-not (Confirm-Pin 'reinstalare')) { Write-Host 'PIN gresit. Instalarea a fost anulata.' -ForegroundColor Red; exit 1 }
    $r = Read-Host 'Vrei sa schimbi PIN-ul? (D/N)'
    if ($r -match '^[dDyY]') { Set-NewPin }
} else {
    Write-Host ''
    Write-Host 'Alege un PIN din 4 cifre. Il vei folosi ca sa opresti protectia,' -ForegroundColor Cyan
    Write-Host 'sa repornesti internetul dupa o alerta si sa dezinstalezi programul.' -ForegroundColor Cyan
    Set-NewPin
}

# 0c. Opreste temporar versiunea instalata (oprire autorizata), ca sa poata fi inlocuita
if (Test-Path $Dir) { Set-Content -Path (Join-Path $Dir 'autorizat.flag') -Value (Get-Date -Format 'o') -Encoding ASCII }
Stop-ScheduledTask -TaskPath '\WormCrawler\' -TaskName 'WormCrawler' -ErrorAction SilentlyContinue
Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" |
    Where-Object { $_.CommandLine -like '*\ProgramData\WormCrawler\*' } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }

# 1. Copiere fisiere
New-Item -ItemType Directory -Path $Dir -Force | Out-Null
foreach ($f in 'wormcrawler.ps1', 'alerta.ps1', 'verificare.ps1', 'tray.ps1', 'reporneste_internet.ps1', 'pin.ps1', 'protectie.ps1', 'cookie-guard.ps1', 'wormcrawler.ico', 'wormcrawler.png') {
    Copy-Item -Path (Join-Path $Src $f) -Destination $Dir -Force
}
# activeaza imediat auditul pe fisierele de cookie-uri ale browserelor
. (Join-Path $Dir 'cookie-guard.ps1')
$nCk = Set-CookieAudit
Write-Host "[OK] Audit cookie-uri activat pe $nCk fisiere de browser"
function New-ElevatedCmd([string]$name, [string]$title, [string]$psArgs) {
    $c = "@echo off`r`ntitle $title - made by REDAOT`r`n" +
         "net session >nul 2>&1 || (powershell -NoProfile -Command `"Start-Process -FilePath '%~f0' -Verb RunAs`" & exit /b)`r`n" +
         "powershell -NoProfile -ExecutionPolicy Bypass $psArgs`r`npause`r`n"
    Set-Content -Path (Join-Path $Dir $name) -Value $c -Encoding ASCII
}
New-ElevatedCmd 'reporneste_internet.cmd' 'Worm-Crawler Defender - Reporneste internetul' "-File `"$Dir\reporneste_internet.ps1`""
New-ElevatedCmd 'opreste_protectia.cmd'   'Worm-Crawler Defender - Opreste protectia'     "-File `"$Dir\protectie.ps1`" -Actiune Opreste"
New-ElevatedCmd 'porneste_protectia.cmd'  'Worm-Crawler Defender - Porneste protectia'    "-File `"$Dir\protectie.ps1`" -Actiune Porneste"
New-ElevatedCmd 'schimba_pin.cmd'         'Worm-Crawler Defender - Schimba PIN-ul'        "-File `"$Dir\protectie.ps1`" -Actiune SchimbaPin"
Get-ChildItem $Dir -File | Unblock-File

# 2. Permisiuni: doar Administratorii si SYSTEM pot modifica scripturile.
#    (Altfel un program fara drepturi de admin ar putea modifica scriptul care ruleaza ca SYSTEM.)
& icacls.exe $Dir /inheritance:r /grant:r '*S-1-5-18:(OI)(CI)F' '*S-1-5-32-544:(OI)(CI)F' '*S-1-5-32-545:(OI)(CI)RX' | Out-Null
Write-Host '[OK] Fisiere copiate in C:\ProgramData\WormCrawler'

# 3. Activare audit pentru procese noi (necesar pentru detectarea PowerShell codificat)
auditpol.exe /set /subcategory:"{0CCE922B-69AE-11D9-BED3-505054503030}" /success:enable | Out-Null
$k = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\Audit'
if (-not (Test-Path $k)) { New-Item -Path $k -Force | Out-Null }
Set-ItemProperty -Path $k -Name 'ProcessCreationIncludeCmdLine_Enabled' -Value 1 -Type DWord
Write-Host '[OK] Audit procese activat'

# 4. Task principal: ruleaza ca SYSTEM, la pornirea PC-ului, se reporneste daca e oprit
Unregister-ScheduledTask -TaskPath '\WormCrawler\' -TaskName 'WormCrawler' -Confirm:$false -ErrorAction SilentlyContinue
$act  = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$Dir\wormcrawler.ps1`""
$trg  = New-ScheduledTaskTrigger -AtStartup
$prn  = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
$set  = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable `
        -ExecutionTimeLimit ([TimeSpan]::Zero) -RestartCount 999 -RestartInterval (New-TimeSpan -Minutes 1) `
        -MultipleInstances IgnoreNew
Register-ScheduledTask -TaskPath '\WormCrawler\' -TaskName 'WormCrawler' -Action $act -Trigger $trg -Principal $prn -Settings $set -Force | Out-Null
Write-Host '[OK] Task "WormCrawler" creat (ruleaza ca SYSTEM la fiecare pornire)'

# 5. Task de alerta: afiseaza mesajul pe ecranul oricarui utilizator logat
Unregister-ScheduledTask -TaskPath '\WormCrawler\' -TaskName 'WormCrawler-Alerta' -Confirm:$false -ErrorAction SilentlyContinue
$users = (New-Object System.Security.Principal.SecurityIdentifier 'S-1-5-32-545').Translate([System.Security.Principal.NTAccount]).Value
$actA  = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$Dir\alerta.ps1`""
$prnA  = New-ScheduledTaskPrincipal -GroupId $users -RunLevel Limited
$setA  = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -MultipleInstances Parallel
Register-ScheduledTask -TaskPath '\WormCrawler\' -TaskName 'WormCrawler-Alerta' -Action $actA -Principal $prnA -Settings $setA -Force | Out-Null
Write-Host '[OK] Task "WormCrawler-Alerta" creat'

# 5b. Task de verificare: la logare + la fiecare minut verifica daca Worm-Crawler Defender ruleaza
Unregister-ScheduledTask -TaskPath '\WormCrawler\' -TaskName 'WormCrawler-Verificare' -Confirm:$false -ErrorAction SilentlyContinue
$actV = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$Dir\verificare.ps1`""
$trgL = New-ScheduledTaskTrigger -AtLogOn
$trgL.Delay = 'PT1M'
$trgR = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) -RepetitionInterval (New-TimeSpan -Minutes 1)
$prnV = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
$setV = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable `
        -ExecutionTimeLimit (New-TimeSpan -Minutes 2) -MultipleInstances IgnoreNew
Register-ScheduledTask -TaskPath '\WormCrawler\' -TaskName 'WormCrawler-Verificare' -Action $actV -Trigger $trgL, $trgR -Principal $prnV -Settings $setV -Force | Out-Null
Write-Host '[OK] Task "WormCrawler-Verificare" creat (la logare si la fiecare minut)'

# 5c. Iconita in system tray, la logarea fiecarui utilizator
Unregister-ScheduledTask -TaskPath '\WormCrawler\' -TaskName 'WormCrawler-Tray' -Confirm:$false -ErrorAction SilentlyContinue
$actT = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -STA -File `"$Dir\tray.ps1`""
$trgT = New-ScheduledTaskTrigger -AtLogOn
$prnT = New-ScheduledTaskPrincipal -GroupId $users -RunLevel Limited
$setT = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit ([TimeSpan]::Zero) -MultipleInstances Parallel
Register-ScheduledTask -TaskPath '\WormCrawler\' -TaskName 'WormCrawler-Tray' -Action $actT -Trigger $trgT -Principal $prnT -Settings $setT -Force | Out-Null
Write-Host '[OK] Iconita in system tray (porneste la logare)'

# 6. Scurtatura pe Desktop (cu iconita Worm-Crawler Defender) pentru repornirea internetului
$desk = [Environment]::GetFolderPath('CommonDesktopDirectory')
Remove-Item (Join-Path $desk 'Worm-Crawler Defender - Reporneste internetul.cmd') -Force -ErrorAction SilentlyContinue
$wsh = New-Object -ComObject WScript.Shell
$lnk = $wsh.CreateShortcut((Join-Path $desk 'Worm-Crawler Defender - Reporneste internetul.lnk'))
$lnk.TargetPath   = "$Dir\reporneste_internet.cmd"
$lnk.IconLocation = "$Dir\wormcrawler.ico,0"
$lnk.Description  = 'Worm-Crawler Defender - reporneste internetul (made by REDAOT)'
$lnk.Save()
Write-Host '[OK] Scurtatura "Worm-Crawler Defender - Reporneste internetul" pusa pe Desktop'

# 7. Pornire imediata (anuleaza oprirea temporara de la pasul 0c)
Remove-Item (Join-Path $Dir 'autorizat.flag') -Force -ErrorAction SilentlyContinue
Start-ScheduledTask -TaskPath '\WormCrawler\' -TaskName 'WormCrawler'
Start-ScheduledTask -TaskPath '\WormCrawler\' -TaskName 'WormCrawler-Tray'
Start-Sleep -Seconds 3
$state = (Get-ScheduledTask -TaskPath '\WormCrawler\' -TaskName 'WormCrawler').State
Write-Host ''
if ($state -eq 'Running') {
    Write-Host "Worm-Crawler Defender RULEAZA. Jurnal: $Dir\wormcrawler.log" -ForegroundColor Green
} else {
    Write-Host "Atentie: taskul WormCrawler are starea '$state'. Verifica in Task Scheduler > WormCrawler." -ForegroundColor Yellow
}
Write-Host ''
Write-Host 'made by REDAOT' -ForegroundColor DarkGray
