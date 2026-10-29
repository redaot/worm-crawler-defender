# Worm-Crawler Defender - PIN helper functions (made by REDAOT)
# The PIN is never stored in clear text: only a PBKDF2 hash (100,000 iterations)
# with a random salt. It is kept in a folder SEPARATE from the program so it
# survives deletion of the program folder. A backup copy is also kept.

$script:WCDir     = 'C:\ProgramData\WormCrawler'           # program folder
$script:SecureDir = 'C:\ProgramData\WormCrawler-Secure'    # separate, protected folder
$script:PinFile   = Join-Path $script:SecureDir 'pin.dat'
$script:PinBak    = Join-Path $script:SecureDir 'pin.bak'

function Protect-SecureDir {
    if (-not (Test-Path $script:SecureDir)) { New-Item -ItemType Directory -Path $script:SecureDir -Force | Out-Null }
    # Only SYSTEM and Administrators get full control (including delete).
    # Standard users cannot read, delete or modify it.
    & icacls.exe $script:SecureDir /inheritance:r /grant:r '*S-1-5-18:(OI)(CI)F' '*S-1-5-32-544:(OI)(CI)F' | Out-Null
}

function Get-PinHash([string]$pin, [byte[]]$salt) {
    $kdf = New-Object System.Security.Cryptography.Rfc2898DeriveBytes($pin, $salt, 100000)
    $h = $kdf.GetBytes(32); $kdf.Dispose()
    return [Convert]::ToBase64String($h)
}

function Test-PinExists { return ((Test-Path $script:PinFile) -or (Test-Path $script:PinBak)) }

# Restore a missing file from its backup copy (or vice versa).
function Restore-PinFiles {
    if ((Test-Path $script:PinFile) -and -not (Test-Path $script:PinBak)) {
        Protect-SecureDir; Copy-Item $script:PinFile $script:PinBak -Force
    } elseif ((Test-Path $script:PinBak) -and -not (Test-Path $script:PinFile)) {
        Protect-SecureDir; Copy-Item $script:PinBak $script:PinFile -Force
    }
}

function Get-PinLine {
    Restore-PinFiles
    if (Test-Path $script:PinFile) { return (Get-Content $script:PinFile -Raw).Trim() }
    if (Test-Path $script:PinBak)  { return (Get-Content $script:PinBak  -Raw).Trim() }
    return $null
}

function Set-NewPin {  # interactively ask for a new 4-digit PIN and save it
    while ($true) {
        $p1 = Read-Host -AsSecureString 'Choose a 4-digit PIN'
        $p1 = [Runtime.InteropServices.Marshal]::PtrToStringBSTR([Runtime.InteropServices.Marshal]::SecureStringToBSTR($p1))
        if ($p1 -notmatch '^\d{4}$') { Write-Host 'The PIN must be exactly 4 digits.' -ForegroundColor Yellow; continue }
        $p2 = Read-Host -AsSecureString 'Repeat the PIN'
        $p2 = [Runtime.InteropServices.Marshal]::PtrToStringBSTR([Runtime.InteropServices.Marshal]::SecureStringToBSTR($p2))
        if ($p1 -ne $p2) { Write-Host 'The PINs do not match. Try again.' -ForegroundColor Yellow; continue }
        break
    }
    $salt = New-Object byte[] 16
    [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($salt)
    $line = [Convert]::ToBase64String($salt) + ':' + (Get-PinHash $p1 $salt)
    Protect-SecureDir
    Set-Content -Path $script:PinFile -Value $line -Encoding ASCII
    Set-Content -Path $script:PinBak  -Value $line -Encoding ASCII
    Protect-SecureDir
    Write-Host '[OK] PIN saved (with a backup copy). Do not forget it!' -ForegroundColor Green
}

function Test-PinValue([string]$pin) {
    $line = Get-PinLine
    if (-not $line) { return $false }
    $parts = $line.Split(':')
    if ($parts.Count -ne 2) { return $false }
    $salt = [Convert]::FromBase64String($parts[0])
    return ((Get-PinHash $pin $salt) -eq $parts[1])
}

# Ask for the PIN (3 attempts). Returns $true if correct.
function Confirm-Pin([string]$reason) {
    if (-not (Test-PinExists)) {
        Write-Host 'No PIN is set. Set one now.' -ForegroundColor Yellow
        Set-NewPin
        return $true
    }
    for ($i = 1; $i -le 3; $i++) {
        $sec = Read-Host -AsSecureString "PIN for: $reason (attempt $i of 3)"
        $p = [Runtime.InteropServices.Marshal]::PtrToStringBSTR([Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec))
        if (Test-PinValue $p) { return $true }
        Write-Host 'Wrong PIN.' -ForegroundColor Red
        if (Test-Path $script:WCDir) {
            Add-Content -Path (Join-Path $script:WCDir 'wormcrawler.log') -Encoding UTF8 `
                -Value ('{0}  WRONG PIN entered for: {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $reason)
        }
    }
    Start-Sleep -Seconds 5
    return $false
}
