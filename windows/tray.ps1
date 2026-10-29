# Iconita Worm-Crawler Defender in system tray (porneste la logarea fiecarui utilizator)
# made by REDAOT
$ErrorActionPreference = 'SilentlyContinue'
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

# o singura iconita per utilizator
$created = $false
$mutex = New-Object System.Threading.Mutex($true, "Local\WormCrawlerTray_REDAOT", [ref]$created)
if (-not $created) { exit }

$Dir      = 'C:\ProgramData\WormCrawler'
$BeatFile = "$Dir\heartbeat.txt"

$icoOk = if (Test-Path "$Dir\wormcrawler.ico") { New-Object System.Drawing.Icon("$Dir\wormcrawler.ico", 32, 32) } else { [System.Drawing.SystemIcons]::Shield }

$tray = New-Object System.Windows.Forms.NotifyIcon
$tray.Icon    = $icoOk
$tray.Text    = 'Worm-Crawler Defender - pornire...'
$tray.Visible = $true

function Get-Status {
    if (Test-Path "$Dir\autorizat.flag") { return 'pauza' }
    if ((Test-Path $BeatFile) -and (((Get-Date) - (Get-Item $BeatFile).LastWriteTime).TotalSeconds -lt 60)) { return 'activ' }
    return 'mort'
}

function Show-Status {
    $st = Get-Status
    $msg = switch ($st) {
        'activ' { "Worm-Crawler Defender RULEAZA si iti protejeaza PC-ul.`r`n`r`n" }
        'pauza' { "Protectia e OPRITA (cu PIN-ul tau).`r`nO pornesti din meniu: 'Porneste protectia'.`r`n`r`n" }
        'mort'  { "ATENTIE: Worm-Crawler Defender NU raspunde!`r`nDaca a fost inchis fara PIN, internetul va fi blocat.`r`nRuleaza din nou 1_Instaleaza.cmd daca problema persista.`r`n`r`n" }
    }
    if (Test-Path "$Dir\blocare.flag") { $msg += "INTERNETUL E BLOCAT. Il repornesti cu PIN-ul: 'Reporneste internetul'.`r`n`r`n" }
    $msg += "Monitorizeaza:`r`n - excluderi noi in Windows Defender`r`n - oprirea protectiei in timp real`r`n - PowerShell cu comenzi ascunse`r`n - inchiderea fortata a protectiei (fara PIN)`r`n`r`nmade by REDAOT"
    $icon = if ($st -eq 'activ') { 'Information' } else { 'Warning' }
    [void][System.Windows.Forms.MessageBox]::Show($msg, 'Worm-Crawler Defender  |  made by REDAOT', 'OK', $icon)
}

$menu = New-Object System.Windows.Forms.ContextMenuStrip
$hdr = $menu.Items.Add('Worm-Crawler Defender  -  made by REDAOT'); $hdr.Enabled = $false
[void]$menu.Items.Add('-')
$menu.Items.Add('Stare').Add_Click({ Show-Status })
$menu.Items.Add('Deschide jurnalul').Add_Click({ Start-Process notepad.exe "$Dir\wormcrawler.log" })
$menu.Items.Add('Reporneste internetul (PIN)').Add_Click({ Start-Process "$Dir\reporneste_internet.cmd" })
[void]$menu.Items.Add('-')
$menu.Items.Add('Opreste protectia (PIN)').Add_Click({ Start-Process "$Dir\opreste_protectia.cmd" })
$menu.Items.Add('Porneste protectia').Add_Click({ Start-Process "$Dir\porneste_protectia.cmd" })
$menu.Items.Add('Schimba PIN-ul').Add_Click({ Start-Process "$Dir\schimba_pin.cmd" })
$tray.ContextMenuStrip = $menu
$tray.Add_DoubleClick({ Show-Status })

# actualizeaza starea la fiecare 15 secunde
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 15000
$update = {
    $st = Get-Status
    $blk = Test-Path "$Dir\blocare.flag"
    if ($st -eq 'activ' -and -not $blk) {
        $tray.Text = 'Worm-Crawler Defender - ACTIV (made by REDAOT)'
        $tray.Icon = $icoOk
    } elseif ($st -eq 'activ' -and $blk) {
        $tray.Text = 'Worm-Crawler Defender - INTERNET BLOCAT (PIN)'
        $tray.Icon = [System.Drawing.SystemIcons]::Error
    } elseif ($st -eq 'pauza') {
        $tray.Text = 'Worm-Crawler Defender - OPRIT cu PIN'
        $tray.Icon = [System.Drawing.SystemIcons]::Information
    } else {
        $tray.Text = 'Worm-Crawler Defender - NU RASPUNDE!'
        $tray.Icon = [System.Drawing.SystemIcons]::Warning
    }
}
$timer.Add_Tick($update)
$timer.Start()
& $update

[System.Windows.Forms.Application]::Run()
$tray.Visible = $false
$tray.Dispose()
