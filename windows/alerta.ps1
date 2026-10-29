# Afiseaza alerta Worm-Crawler Defender pe ecranul utilizatorului (pornit de taskul WormCrawler-Alerta)
# made by REDAOT
$ErrorActionPreference = 'SilentlyContinue'
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$Dir   = 'C:\ProgramData\WormCrawler'
$lines = @(Get-Content -Path "$Dir\alerta.txt" -Encoding UTF8)
$title = 'WORM-CRAWLER DEFENDER - ALERTA'
$text  = "ATENTIE! Worm-Crawler Defender a detectat o problema.`r`nVezi $Dir\wormcrawler.log"
if ($lines.Count -ge 2) { $title = $lines[0]; $text = ($lines[1..($lines.Count - 1)] -join "`r`n") }

1..3 | ForEach-Object { [System.Media.SystemSounds]::Hand.Play(); Start-Sleep -Milliseconds 400 }

$form = New-Object System.Windows.Forms.Form
$form.Text            = "$title  |  made by REDAOT"
$form.StartPosition   = 'CenterScreen'
$form.TopMost         = $true
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox     = $false
$form.MinimizeBox     = $false
$form.ClientSize      = New-Object System.Drawing.Size(640, 470)
$form.BackColor       = [System.Drawing.Color]::White
if (Test-Path "$Dir\wormcrawler.ico") { $form.Icon = New-Object System.Drawing.Icon("$Dir\wormcrawler.ico") }

# Banda rosie de sus
$head = New-Object System.Windows.Forms.Panel
$head.Dock = 'Top'; $head.Height = 110
$head.BackColor = [System.Drawing.Color]::FromArgb(178, 34, 34)
$form.Controls.Add($head)

if (Test-Path "$Dir\wormcrawler.png") {
    $pic = New-Object System.Windows.Forms.PictureBox
    $pic.Image    = [System.Drawing.Image]::FromFile("$Dir\wormcrawler.png")
    $pic.SizeMode = 'Zoom'
    $pic.Size     = New-Object System.Drawing.Size(90, 90)
    $pic.Location = New-Object System.Drawing.Point(12, 10)
    $pic.BackColor = [System.Drawing.Color]::Transparent
    $head.Controls.Add($pic)
}
$lblTitle = New-Object System.Windows.Forms.Label
$lblTitle.Text      = $title
$lblTitle.ForeColor = [System.Drawing.Color]::White
$lblTitle.Font      = New-Object System.Drawing.Font('Segoe UI', 15, [System.Drawing.FontStyle]::Bold)
$lblTitle.Location  = New-Object System.Drawing.Point(115, 18)
$lblTitle.Size      = New-Object System.Drawing.Size(510, 75)
$head.Controls.Add($lblTitle)

# Textul alertei
$box = New-Object System.Windows.Forms.TextBox
$box.Multiline   = $true
$box.ReadOnly    = $true
$box.ScrollBars  = 'Vertical'
$box.BorderStyle = 'None'
$box.BackColor   = [System.Drawing.Color]::White
$box.Font        = New-Object System.Drawing.Font('Segoe UI', 10.5)
$box.Text        = $text
$box.Location    = New-Object System.Drawing.Point(20, 125)
$box.Size        = New-Object System.Drawing.Size(600, 270)
$form.Controls.Add($box)

# Subsol: made by REDAOT + buton
$credit = New-Object System.Windows.Forms.Label
$credit.Text      = 'made by REDAOT'
$credit.ForeColor = [System.Drawing.Color]::Gray
$credit.Font      = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Italic)
$credit.Location  = New-Object System.Drawing.Point(20, 425)
$credit.AutoSize  = $true
$form.Controls.Add($credit)

$btnLog = New-Object System.Windows.Forms.Button
$btnLog.Text     = 'Deschide jurnalul'
$btnLog.Size     = New-Object System.Drawing.Size(140, 34)
$btnLog.Location = New-Object System.Drawing.Point(330, 415)
$btnLog.Add_Click({ Start-Process notepad.exe "$Dir\wormcrawler.log" })
$form.Controls.Add($btnLog)

$btnOk = New-Object System.Windows.Forms.Button
$btnOk.Text         = 'Am inteles'
$btnOk.Size         = New-Object System.Drawing.Size(130, 34)
$btnOk.Location     = New-Object System.Drawing.Point(490, 415)
$btnOk.DialogResult = 'OK'
$form.AcceptButton  = $btnOk
$form.Controls.Add($btnOk)

$form.Add_Shown({ $form.Activate(); $btnOk.Focus() })
[void]$form.ShowDialog()
$form.Dispose()
