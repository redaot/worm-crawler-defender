# Worm-Crawler Defender - browser cookie/credential guard (made by REDAOT)
# Places an AUDIT (SACL) on the browsers' secret files. When a process other than
# the browser reads one of them, Windows writes event 4663 to the Security log,
# which the main guard watches and then cuts the internet.

# Add the secret files from a Chromium profile folder (User Data or an Opera profile).
function Add-ChromiumSecrets([string]$udPath, $list) {
    foreach ($leaf in @('Local State', 'Network\Cookies', 'Cookies', 'Login Data')) {
        $p = Join-Path $udPath $leaf; if (Test-Path $p) { $list.Add($p) }
    }
    foreach ($prof in (Get-ChildItem $udPath -Directory -ErrorAction SilentlyContinue)) {
        foreach ($leaf in @('Network\Cookies', 'Cookies', 'Login Data')) {
            $p = Join-Path $prof.FullName $leaf; if (Test-Path $p) { $list.Add($p) }
        }
    }
}
# Add the secret files from a Mozilla-family "Profiles" folder.
function Add-MozillaSecrets([string]$profilesPath, $list) {
    foreach ($prof in (Get-ChildItem $profilesPath -Directory -ErrorAction SilentlyContinue)) {
        foreach ($leaf in @('cookies.sqlite', 'logins.json', 'key4.db')) {
            $p = Join-Path $prof.FullName $leaf; if (Test-Path $p) { $list.Add($p) }
        }
    }
}

# List the existing secret files for every account on the PC.
# FAILSAFE: does not rely on a fixed list of browsers; it discovers profiles by
# STRUCTURE ("User Data" / "Profiles" folders / Opera-style profile) by walking
# everything in AppData\Local and AppData\Roaming. Covers any common browser
# (Chrome, Edge, Brave, Opera/GX, Vivaldi, Yandex, Firefox and forks such as
# LibreWolf/Waterfox/Pale Moon, Thunderbird), installed system-wide OR per-user.
function Get-BrowserSecretFiles {
    $files = New-Object System.Collections.Generic.List[string]
    foreach ($u in (Get-ChildItem 'C:\Users' -Directory -ErrorAction SilentlyContinue)) {
        foreach ($root in @((Join-Path $u.FullName 'AppData\Local'), (Join-Path $u.FullName 'AppData\Roaming'))) {
            if (-not (Test-Path $root)) { continue }
            foreach ($vendor in (Get-ChildItem $root -Directory -ErrorAction SilentlyContinue)) {
                # vendor\User Data   and   vendor\Profiles
                $ud = Join-Path $vendor.FullName 'User Data'; if (Test-Path $ud) { Add-ChromiumSecrets $ud $files }
                $pf = Join-Path $vendor.FullName 'Profiles';  if (Test-Path $pf) { Add-MozillaSecrets  $pf $files }
                foreach ($sub in (Get-ChildItem $vendor.FullName -Directory -ErrorAction SilentlyContinue)) {
                    # vendor\<Browser>\User Data   (Chrome, Edge, Brave, Yandex...)
                    $ud2 = Join-Path $sub.FullName 'User Data'; if (Test-Path $ud2) { Add-ChromiumSecrets $ud2 $files }
                    # vendor\<Browser>\Profiles    (Firefox = Mozilla\Firefox\Profiles)
                    $pf2 = Join-Path $sub.FullName 'Profiles';  if (Test-Path $pf2) { Add-MozillaSecrets  $pf2 $files }
                    # Opera-style profile: the folder holds Local State / Cookies directly
                    if ((Test-Path (Join-Path $sub.FullName 'Local State')) -or
                        (Test-Path (Join-Path $sub.FullName 'Cookies')) -or
                        (Test-Path (Join-Path $sub.FullName 'Network\Cookies'))) {
                        Add-ChromiumSecrets $sub.FullName $files
                    }
                }
            }
        }
    }
    return ($files | Sort-Object -Unique)
}

# Enable file-access auditing and put a SACL on the secret files.
function Set-CookieAudit {
    # Audit "File System" (object access), GUID is language-independent
    auditpol.exe /set /subcategory:"{0CCE921D-69AE-11D9-BED3-505054503030}" /success:enable | Out-Null
    # larger Security log so events are not lost (64 MB)
    wevtutil.exe sl Security /ms:67108864 2>$null | Out-Null

    $everyone = New-Object System.Security.Principal.SecurityIdentifier('S-1-1-0')
    $rule = New-Object System.Security.AccessControl.FileSystemAuditRule(
        $everyone,
        [System.Security.AccessControl.FileSystemRights]::ReadData,
        [System.Security.AccessControl.AuditFlags]::Success)

    $n = 0
    foreach ($f in (Get-BrowserSecretFiles)) {
        try {
            $acl = Get-Acl -Path $f -Audit
            $acl.AddAuditRule($rule) | Out-Null
            Set-Acl -Path $f -AclObject $acl
            $n++
        } catch {}
    }
    return $n
}

# Processes allowed to read the files (the browsers themselves + system).
$script:BrowserWhitelist = @(
    'chrome.exe', 'msedge.exe', 'msedgewebview2.exe', 'brave.exe', 'firefox.exe',
    'opera.exe', 'opera_gx.exe', 'vivaldi.exe', 'chromium.exe', 'browser.exe',
    'librewolf.exe', 'waterfox.exe', 'palemoon.exe', 'thunderbird.exe', 'tor.exe',
    'yandex.exe',
    'searchprotocolhost.exe', 'searchindexer.exe', 'msmpeng.exe', 'system'
)

# FAILSAFE by file signature:
#  - Chromium: any ...\User Data\...\(Network\)?Cookies / Login Data / Local State
#    (Electron apps - Discord/Slack/VSCode - do NOT use "User Data", so no false alarms)
#  - Opera: the "...\Opera* \ ..." profile (no "User Data")
#  - Mozilla: the names cookies.sqlite / logins.json / key4.db anywhere (unique to Mozilla)
$script:CookieRegex = '(?i)(\\User Data\\[^\\]*\\?(Network\\)?Cookies$)|(\\User Data\\[^\\]*\\?Login Data$)|(\\User Data\\Local State$)|(\\Opera[^\\]*\\(Network\\)?Cookies$)|(\\Opera[^\\]*\\Login Data$)|(\\Opera[^\\]*\\Local State$)|(\\(cookies\.sqlite|logins\.json|key4\.db)$)'
