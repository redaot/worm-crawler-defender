# Worm-Crawler Defender - system tray icon (starts at each user's logon)
# made by REDAOT
$WcdVersion = 'v1.1.0'
$ErrorActionPreference = 'SilentlyContinue'
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

# only one icon per user
$created = $false
$mutex = New-Object System.Threading.Mutex($true, "Local\WormCrawlerTray_REDAOT", [ref]$created)
if (-not $created) { exit }

$Dir      = 'C:\ProgramData\WormCrawler'
$BeatFile = "$Dir\heartbeat.txt"

$icoOk = if (Test-Path "$Dir\wormcrawler.ico") { New-Object System.Drawing.Icon("$Dir\wormcrawler.ico", 32, 32) } else { [System.Drawing.SystemIcons]::Shield }

$tray = New-Object System.Windows.Forms.NotifyIcon
$tray.Icon    = $icoOk
$tray.Text    = 'Worm-Crawler Defender - starting...'
$tray.Visible = $true

function Get-Status {
    if (Test-Path "$Dir\authorized.flag") { return 'paused' }
    if ((Test-Path $BeatFile) -and (((Get-Date) - (Get-Item $BeatFile).LastWriteTime).TotalSeconds -lt 60)) { return 'active' }
    return 'dead'
}

function Show-Status {
    $st = Get-Status
    $msg = switch ($st) {
        'active' { "Worm-Crawler Defender is RUNNING and protecting your PC.`r`n`r`n" }
        'paused' { "Protection is STOPPED (with your PIN).`r`nStart it from the menu: 'Start Protection'.`r`n`r`n" }
        'dead'   { "WARNING: Worm-Crawler Defender is NOT responding!`r`nIf it was closed without the PIN, the internet will be blocked.`r`nRun 1_Install.cmd again if the problem persists.`r`n`r`n" }
    }
    if (Test-Path "$Dir\blocked.flag") { $msg += "THE INTERNET IS BLOCKED. Unlock it with your PIN: 'Unlock Internet'.`r`n`r`n" }
    $msg += "Monitors:`r`n - new exclusions in Windows Defender`r`n - real-time protection being turned off`r`n - PowerShell with hidden commands`r`n - reading of browser cookies/credentials`r`n - forced shutdown of the protection (without PIN)`r`n`r`nmade by REDAOT  -  $WcdVersion"
    $icon = if ($st -eq 'active') { 'Information' } else { 'Warning' }
    [void][System.Windows.Forms.MessageBox]::Show($msg, "Worm-Crawler Defender $WcdVersion  |  made by REDAOT", 'OK', $icon)
}

$menu = New-Object System.Windows.Forms.ContextMenuStrip
$hdr = $menu.Items.Add("Worm-Crawler Defender $WcdVersion  -  made by REDAOT"); $hdr.Enabled = $false
[void]$menu.Items.Add('-')
$menu.Items.Add('Status').Add_Click({ Show-Status })
$menu.Items.Add('Open log').Add_Click({ Start-Process notepad.exe "$Dir\wormcrawler.log" })
$menu.Items.Add('Unlock Internet (PIN)').Add_Click({ Start-Process "$Dir\unlock-internet.cmd" })
[void]$menu.Items.Add('-')
$menu.Items.Add('Stop Protection (PIN)').Add_Click({ Start-Process "$Dir\stop-protection.cmd" })
$menu.Items.Add('Start Protection').Add_Click({ Start-Process "$Dir\start-protection.cmd" })
$menu.Items.Add('Change PIN').Add_Click({ Start-Process "$Dir\change-pin.cmd" })
$tray.ContextMenuStrip = $menu
$tray.Add_DoubleClick({ Show-Status })

# refresh the state every 15 seconds
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 15000
$update = {
    $st = Get-Status
    $blk = Test-Path "$Dir\blocked.flag"
    if ($st -eq 'active' -and -not $blk) {
        $tray.Text = "Worm-Crawler Defender - ACTIVE ($WcdVersion)"
        $tray.Icon = $icoOk
    } elseif ($st -eq 'active' -and $blk) {
        $tray.Text = 'Worm-Crawler Defender - INTERNET BLOCKED (PIN)'
        $tray.Icon = [System.Drawing.SystemIcons]::Error
    } elseif ($st -eq 'paused') {
        $tray.Text = 'Worm-Crawler Defender - STOPPED with PIN'
        $tray.Icon = [System.Drawing.SystemIcons]::Information
    } else {
        $tray.Text = 'Worm-Crawler Defender - NOT RESPONDING!'
        $tray.Icon = [System.Drawing.SystemIcons]::Warning
    }
}
$timer.Add_Tick($update)
$timer.Start()
& $update

[System.Windows.Forms.Application]::Run()
$tray.Visible = $false
$tray.Dispose()
