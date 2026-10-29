# Worm-Crawler Defender - functii pentru PIN (made by REDAOT)
# PIN-ul nu e salvat in clar: doar un hash PBKDF2 (100.000 iteratii) cu sare aleatoare.
# Se tine INTR-UN FOLDER SEPARAT de cel al programului, ca sa supravietuiasca stergerii
# folderului C:\ProgramData\WormCrawler. Folderul are nume clar si permisiuni care
# permit stergerea doar Administratorilor si SYSTEM. In plus se pastreaza o copie de rezerva.

$script:WCDir     = 'C:\ProgramData\WormCrawler'           # folderul programului
$script:SecureDir = 'C:\ProgramData\WormCrawler-Secure'    # folder separat, protejat
$script:PinFile   = Join-Path $script:SecureDir 'pin.dat'
$script:PinBak    = Join-Path $script:SecureDir 'pin.bak'

function Protect-SecureDir {
    if (-not (Test-Path $script:SecureDir)) { New-Item -ItemType Directory -Path $script:SecureDir -Force | Out-Null }
    # Doar SYSTEM si Administratorii au drepturi depline (inclusiv stergere).
    # Utilizatorii obisnuiti nu pot nici citi, nici sterge, nici modifica.
    & icacls.exe $script:SecureDir /inheritance:r /grant:r '*S-1-5-18:(OI)(CI)F' '*S-1-5-32-544:(OI)(CI)F' | Out-Null
}

function Get-PinHash([string]$pin, [byte[]]$salt) {
    $kdf = New-Object System.Security.Cryptography.Rfc2898DeriveBytes($pin, $salt, 100000)
    $h = $kdf.GetBytes(32); $kdf.Dispose()
    return [Convert]::ToBase64String($h)
}

function Test-PinExists { return ((Test-Path $script:PinFile) -or (Test-Path $script:PinBak)) }

# Daca fisierul principal lipseste dar exista copia (sau invers), le reface pe amandoua.
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

function Read-PinFromUser([string]$prompt) {
    $sec = Read-Host -Prompt $prompt -AsSecureString
    $b = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
    try { return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($b) }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($b) }
}

function Set-NewPin {
    while ($true) {
        $p1 = Read-PinFromUser 'Alege un PIN din 4 cifre'
        if ($p1 -notmatch '^\d{4}$') { Write-Host 'PIN-ul trebuie sa aiba exact 4 cifre.' -ForegroundColor Yellow; continue }
        $p2 = Read-PinFromUser 'Repeta PIN-ul'
        if ($p1 -ne $p2) { Write-Host 'PIN-urile nu coincid. Mai incearca.' -ForegroundColor Yellow; continue }
        break
    }
    $salt = New-Object byte[] 16
    [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($salt)
    $line = [Convert]::ToBase64String($salt) + ':' + (Get-PinHash $p1 $salt)
    Protect-SecureDir
    Set-Content -Path $script:PinFile -Value $line -Encoding ASCII
    Set-Content -Path $script:PinBak  -Value $line -Encoding ASCII
    Protect-SecureDir
    Write-Host '[OK] PIN salvat (cu o copie de rezerva). Nu-l uita!' -ForegroundColor Green
}

function Test-PinValue([string]$pin) {
    $line = Get-PinLine
    if (-not $line) { return $false }
    $parts = $line.Split(':')
    if ($parts.Count -ne 2) { return $false }
    $salt = [Convert]::FromBase64String($parts[0])
    return ((Get-PinHash $pin $salt) -eq $parts[1])
}

# Cere PIN-ul (3 incercari). Intoarce $true daca e corect.
function Confirm-Pin([string]$motiv) {
    if (-not (Test-PinExists)) {
        Write-Host 'Nu exista PIN setat. Seteaza unul acum.' -ForegroundColor Yellow
        Set-NewPin
        return $true
    }
    for ($i = 1; $i -le 3; $i++) {
        $p = Read-PinFromUser "PIN pentru: $motiv (incercarea $i din 3)"
        if (Test-PinValue $p) { return $true }
        Write-Host 'PIN gresit.' -ForegroundColor Red
        if (Test-Path $script:WCDir) {
            Add-Content -Path (Join-Path $script:WCDir 'wormcrawler.log') -Encoding UTF8 `
                -Value ('{0}  PIN GRESIT introdus pentru: {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $motiv)
        }
    }
    Start-Sleep -Seconds 5
    return $false
}
