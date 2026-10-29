# Worm-Crawler Defender - paza pentru cookie-uri/parole din browsere (made by REDAOT)
# Pune un AUDIT (SACL) pe fisierele secrete ale browserelor. Cand un alt proces decat
# browserul le citeste, Windows scrie evenimentul 4663 in jurnalul Security, pe care
# paza principala il urmareste si taie internetul.

# Adauga fisierele secrete dintr-un folder de profil Chromium (User Data sau profil Opera).
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
# Adauga fisierele secrete dintr-un folder "Profiles" al familiei Mozilla.
function Add-MozillaSecrets([string]$profilesPath, $list) {
    foreach ($prof in (Get-ChildItem $profilesPath -Directory -ErrorAction SilentlyContinue)) {
        foreach ($leaf in @('cookies.sqlite', 'logins.json', 'key4.db')) {
            $p = Join-Path $prof.FullName $leaf; if (Test-Path $p) { $list.Add($p) }
        }
    }
}

# Lista fisierelor secrete existente, pentru toate conturile de pe PC.
# FAILSAFE: nu se bazeaza pe o lista fixa de browsere, ci descopera profilurile
# dupa STRUCTURA (foldere "User Data" / "Profiles" / profil Opera) parcurgand
# tot ce e in AppData\Local si AppData\Roaming. Acopera orice browser uzual
# (Chrome, Edge, Brave, Opera/GX, Vivaldi, Yandex, Firefox si forkuri ca
# LibreWolf/Waterfox/Pale Moon, Thunderbird), instalat pe sistem SAU doar sub user.
function Get-BrowserSecretFiles {
    $files = New-Object System.Collections.Generic.List[string]
    foreach ($u in (Get-ChildItem 'C:\Users' -Directory -ErrorAction SilentlyContinue)) {
        foreach ($root in @((Join-Path $u.FullName 'AppData\Local'), (Join-Path $u.FullName 'AppData\Roaming'))) {
            if (-not (Test-Path $root)) { continue }
            foreach ($vendor in (Get-ChildItem $root -Directory -ErrorAction SilentlyContinue)) {
                # vendor\User Data   si   vendor\Profiles
                $ud = Join-Path $vendor.FullName 'User Data'; if (Test-Path $ud) { Add-ChromiumSecrets $ud $files }
                $pf = Join-Path $vendor.FullName 'Profiles';  if (Test-Path $pf) { Add-MozillaSecrets  $pf $files }
                foreach ($sub in (Get-ChildItem $vendor.FullName -Directory -ErrorAction SilentlyContinue)) {
                    # vendor\<Browser>\User Data   (Chrome, Edge, Brave, Yandex...)
                    $ud2 = Join-Path $sub.FullName 'User Data'; if (Test-Path $ud2) { Add-ChromiumSecrets $ud2 $files }
                    # vendor\<Browser>\Profiles    (Firefox = Mozilla\Firefox\Profiles)
                    $pf2 = Join-Path $sub.FullName 'Profiles';  if (Test-Path $pf2) { Add-MozillaSecrets  $pf2 $files }
                    # profil tip Opera: folderul contine direct Local State / Cookies
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

# Activeaza auditul de acces la fisiere si pune SACL pe fisierele secrete.
function Set-CookieAudit {
    # Audit "File System" (object access), GUID independent de limba
    auditpol.exe /set /subcategory:"{0CCE921D-69AE-11D9-BED3-505054503030}" /success:enable | Out-Null
    # jurnal Security mai mare, ca sa nu se piarda evenimentele (64 MB)
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

# Lista proceselor carora li se permite accesul (browserele insele + sistem).
$script:BrowserWhitelist = @(
    'chrome.exe', 'msedge.exe', 'msedgewebview2.exe', 'brave.exe', 'firefox.exe',
    'opera.exe', 'opera_gx.exe', 'vivaldi.exe', 'chromium.exe', 'browser.exe',
    'librewolf.exe', 'waterfox.exe', 'palemoon.exe', 'thunderbird.exe', 'tor.exe',
    'yandex.exe',
    'searchprotocolhost.exe', 'searchindexer.exe', 'msmpeng.exe', 'system'
)

# Regex pentru fisierele secrete (cale Windows).
# FAILSAFE prin semnatura fisierului:
#  - Chromium: orice ...\User Data\...\(Network\)?Cookies / Login Data / Local State
#    (Electron-urile - Discord/Slack/VSCode - NU folosesc "User Data", deci nu dau alarme false)
#  - Opera: profilul "...\Opera* \ ..." (fara "User Data")
#  - Mozilla: numele cookies.sqlite / logins.json / key4.db oriunde (sunt unice familiei Mozilla)
$script:CookieRegex = '(?i)(\\User Data\\[^\\]*\\?(Network\\)?Cookies$)|(\\User Data\\[^\\]*\\?Login Data$)|(\\User Data\\Local State$)|(\\Opera[^\\]*\\(Network\\)?Cookies$)|(\\Opera[^\\]*\\Login Data$)|(\\Opera[^\\]*\\Local State$)|(\\(cookies\.sqlite|logins\.json|key4\.db)$)'
