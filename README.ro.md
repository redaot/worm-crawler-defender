# Worm-Crawler Defender

**O „capcană” comportamentală ușoară împotriva dropperelor și a infostealerelor, pentru Windows și Linux.**
*made by REDAOT — v1.0.0*

🇬🇧 English version: [README.md](README.md)

Worm-Crawler Defender rulează discret în fundal. În momentul în care un program
începe să se comporte ca un dropper sau ca un infostealer, **taie internetul** și
afișează o alertă pe tot ecranul. Conexiunea rămâne blocată până introduci
**PIN-ul tău din 4 cifre**.

**Nu** înlocuiește un antivirus sau un EDR. Este un strat în plus care lucrează
alături de ele, construit pe o idee simplă: *dacă ceva pare că e pe cale să-ți
fure datele, taie conexiunea înainte ca datele să poată pleca.*

---

## De ce există

A fost construit după un atac real: un „installer de joc” fals
(`installer-v3_1.exe`, numele intern `Adobe Desktop Service.exe`) a descărcat un
infostealer care a luat parolele și cookie-urile de sesiune din browser, ceea ce
a dus la preluarea unor conturi (Epic, Riot, EA, Microsoft, Facebook,
Instagram...). La momentul atacului, **doar 1 din 68 de antivirusuri** detecta
fișierul.

Pentru că detecția bazată pe semnături l-a ratat, Worm-Crawler Defender nu caută
viruși cunoscuți. Urmărește **comportamentul** comun dropperelor și stealerelor
și reacționează tăind conexiunea, ca datele furate să nu poată fi trimise.

---

## Ce detectează

| # | Semnal | Windows | Linux |
|---|--------|---------|-------|
| 1 | **Descarcă-și-rulează / cod ascuns** | PowerShell pornit cu `-EncodedCommand` | `curl\|bash`, `wget\|sh`, `base64 -d\|bash`, `python -c` cu exec/base64, blocuri base64 lungi |
| 2 | **Manipularea protecției** | O **excludere** nouă în Microsoft Defender; protecția în timp real **oprită** | — |
| 3 | **Locație suspectă de execuție** | — | Un binar care rulează din `/tmp`, `/dev/shm`, `/var/tmp` |
| 4 | **Persistență nouă adăugată** | (acoperit de auditul excluderilor/autostart) | Cron nou, serviciu systemd, sau autostart |
| 5 | **Furt de cookie-uri/parole din browser** | Un proces non-browser **citește** `Cookies`, `Login Data`, `Local State`, `cookies.sqlite`, `logins.json`, `key4.db` | La fel, detectat prin descriptorii de fișiere deschiși |
| 6 | **Keylogger** | *Nedetectat* — necesită ETW / driver de kernel (în afara scopului) | Un proces non-input care citește tastatura `/dev/input/event*` (best-effort) |
| 7 | **Auto-sabotaj** | Protecția închisă/omorâtă fără PIN; watchdog șters/dezactivat | La fel |

Când se declanșează un semnal, programul:

1. **Blochează toate plăcile de rețea** (Ethernet, Wi-Fi). Blocarea e reaplicată
   continuu, deci repornirea plăcii din setările sistemului nu ajută.
2. **Afișează o alertă roșie pe ecran** (o fereastră, nu doar o notificare) cu motivul.
3. **Scrie totul în jurnal**, inclusiv comanda decodificată, ca să vezi exact ce s-a întâmplat.

Conexiunea rămâne blocată până introduci PIN-ul.

---

## Protecția cookie-urilor/parolelor din browser — și limita ei, cinstit

Acesta este semnalul #5 și merită explicat clar.

- **Windows:** instalarea pune o **regulă de audit (SACL)** pe fișierele secrete
  ale browserelor și activează auditul de acces la fișiere. Când un proces
  **diferit de browser** citește unul dintre acele fișiere, Windows scrie
  evenimentul **4663** în jurnalul Security; paza îl urmărește și taie rețeaua.
- **Linux:** la fiecare ciclu, paza verifică (prin `/proc/*/fd`) dacă un proces
  **non-browser** ține deschis un fișier de cookie-uri/parole și taie rețeaua.

> ⚠️ **Limitare importantă.** Citirea unui fișier local e aproape instantanee.
> Până observă o unealtă din spațiul utilizatorului accesul, stealer-ul poate
> avea deja octeții în memorie. Ce oprim **sigur** e **trimiterea** (pasul mai
> lent: DNS, handshake TLS, upload). Deci tăierea rețelei în momentul accesului
> **reduce mult** șansa ca datele să plece — dar nu o face zero. Împiedicarea
> *citirii în sine* necesită un driver de kernel / EDR.

Detectarea este **failsafe pentru toate browserele uzuale**: nu se bazează pe o
listă fixă, ci recunoaște fișierele după structură și nume (familia Chromium prin
folderele `User Data`, familia Mozilla prin `cookies.sqlite`/`logins.json`/
`key4.db`, plus profilurile tip Opera). Astfel acoperă Chrome, Edge, Brave, Opera,
Opera GX, Vivaldi, Yandex, Firefox și forkurile lui (LibreWolf, Waterfox, Pale
Moon, Tor), chiar instalate doar sub user. Aplicațiile Electron (Discord, Slack,
VS Code) care își citesc propriile cookie-uri sunt excluse, ca să nu dea alarme false.

---

## PIN-ul din 4 cifre

Alegi un PIN la instalare. E singura cale de a ridica o blocare sau de a opri
protecția. Fără el **nu poți**:

- debloca internetul după o alertă,
- opri protecția,
- schimba PIN-ul,
- dezinstala sau reinstala.

Ai 3 încercări la fiecare cerere; încercările greșite sunt notate în jurnal.

**Închiderea forțată.** Dacă protecția e oprită fără PIN (proces omorât,
task/serviciu șters sau dezactivat), watchdog-ul observă în cel mult **un minut**,
blochează internetul, încearcă să repornească protecția și afișează o alertă.
Cele două componente se păzesc reciproc: dacă watchdog-ul e eliminat, procesul
principal blochează și el rețeaua.

**Cum e păstrat PIN-ul.** Niciodată în clar — doar ca amprentă criptografică
(PBKDF2, 100.000 de iterații), într-un folder **separat de program** ca să
supraviețuiască ștergerii folderului programului, citibil doar de
administrator/root. O copie de rezervă (`pin.bak`) e păstrată; dacă un fișier e
șters, celălalt îl reface.

- Windows: `C:\ProgramData\WormCrawler-Secure`
- Linux: `/etc/worm-crawler-defender/secure`

**Ai uitat PIN-ul?**
- Windows: pornește în Safe Mode, șterge `C:\ProgramData\WormCrawler-Secure`, repornește, rulează din nou installer-ul.
- Linux: ca root, `sudo rm -rf /etc/worm-crawler-defender`, apoi rulează din nou `sudo ./install.sh`.

---

## Windows

### Cerințe
Windows 10 sau 11, cont de administrator, Windows Defender activ.

### Instalare
1. Dezarhivează `WormCrawler-Defender.zip`.
2. Dublu-click pe **`1_Install.cmd`** și acceptă cererea de administrator.
3. Alege un PIN din 4 cifre.
4. Rulează **`2_Test.cmd`** — pornește o comandă codificată inofensivă; internetul
   ar trebui să se blocheze și alerta să apară în câteva secunde.
5. Deblochează cu scurtătura de pe Desktop **„Worm-Crawler Defender - Unlock Internet”** + PIN.

### Utilizare zilnică
O **iconiță în system tray** arată starea (activ / internet blocat / oprit / nu răspunde).
Click dreapta pentru: Stare, Deschide jurnalul, Deblochează internetul (PIN),
Oprește protecția (PIN), Pornește protecția, Schimbă PIN-ul.

### Componente (taskuri programate)
| Task | Rulează ca | Când | Rol |
|------|-----------|------|-----|
| `WormCrawler` | SYSTEM | la boot, continuu | paza propriu-zisă |
| `WormCrawler-Watchdog` | SYSTEM | logare + la fiecare minut | watchdog |
| `WormCrawler-Alert` | utilizatorul logat | la alertă | afișează fereastra de alertă |
| `WormCrawler-Tray` | utilizatorul logat | la logare | iconița din tray |

Fișierele stau în `C:\ProgramData\WormCrawler`; jurnalul e `wormcrawler.log`.

### Dezinstalare
`3_Uninstall.cmd` (cere PIN-ul).

---

## Linux

### Compatibilitate
Orice distro cu systemd — Ubuntu, Debian, Linux Mint, Fedora, Arch, Manjaro,
openSUSE, Pop!_OS etc. (detectat automat). Fără systemd, cade pe un cron
`@reboot` plus un supervizor. Are nevoie de `python3` **sau** `openssl` pentru PIN
(prezente pe aproape orice distro). Alertele grafice folosesc
zenity/kdialog/notify-send/xmessage dacă există; altfel, alertele apar în terminal (`wall`).

### Instalare
```bash
unzip WormCrawler-Defender-Linux.zip
cd wcd-linux
sudo ./install.sh          # dacă uiți sudo, se re-lansează singur
```
Alege un PIN din 4 cifre, apoi testează:
```bash
sudo wcd-test              # inofensiv; internetul se blochează și apare o alertă
sudo wcd-unlock            # introdu PIN-ul ca să restaurezi
```

### Comenzi
```bash
sudo wcd-unlock            # deblochează internetul după o alertă (PIN)
wcd-protect status         # arată starea protecției + internetului
sudo wcd-protect stop      # oprește protecția (PIN)
sudo wcd-protect start     # o pornește la loc
sudo wcd-protect pin       # schimbă PIN-ul (cere PIN-ul vechi)
```

### Unde stau lucrurile
```
/opt/worm-crawler-defender          scripturile
/etc/worm-crawler-defender/secure   PIN (pin.dat, pin.bak) — doar root
/var/lib/worm-crawler-defender      stare (blocare.flag, plăci salvate...)
/var/log/worm-crawler-defender.log  jurnalul
systemd: worm-crawler-defender.service + wcd-watchdog.timer
```

### Dezinstalare
```bash
sudo ./uninstall.sh        # cere PIN-ul
```

---

## Limite (citește asta)

- **Detecția e în fereastră de timp.** Scanarea proceselor/fișierelor merge pe un
  ciclu de ~2 secunde; o închidere forțată e prinsă în cel mult un minut. Un
  stealer foarte rapid poate trimite ceva înainte să reacționeze. **Reduce paguba,
  nu o elimină.**
- **Un atacator cu drepturi de root/admin** poate, teoretic, să șteargă toate
  componentele deodată, fără să rămână nimic care să reacționeze. Dacă doar oprește
  protecția, rețeaua e blocată.
- **Apar și alarme false.** Unele instalatoare legitime folosesc `curl | bash`;
  unele unelte ating legitim fișiere de browser. Verifică jurnalul ca să vezi ce
  a declanșat alerta.
- **Keyloggere:** pe **Linux** există un semnal best-effort (un proces non-input
  care citește `/dev/input/event*`); pe **Windows** detectarea keyloggerelor **nu e
  în scop** (necesită ETW sau un driver de kernel / EDR). În ambele cazuri ce se
  oprește sigur e *trimiterea* tastelor capturate, nu captarea în sine.
- **Nu e antivirus/EDR.** Cea mai bună protecție rămâne să nu rulezi fișiere
  primite în mesaje private, oricine ar părea expeditorul.

---

## Siguranță & domeniu

E o unealtă defensivă. Blochează doar rețeaua **propriului tău calculator** și
cere un PIN **ales de tine**. Nu trimite nimic în afară, nu se ascunde și nu-și
deghizează fișierele ca pe componente de sistem — totul e cu nume clar și vizibil.

**Disclaimer:** oferit „ca atare”, fără garanții. Testează-l pe sistemul tău și
ține PIN-ul la loc sigur.

---

*Worm-Crawler Defender — made by REDAOT*
