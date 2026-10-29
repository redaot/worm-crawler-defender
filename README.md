# Worm-Crawler Defender

**A lightweight behavioural tripwire against droppers and infostealers, for Windows and Linux.**
*made by REDAOT — v1.0.0*

🇷🇴 Versiunea în română: [README.ro.md](README.ro.md)

Worm-Crawler Defender runs quietly in the background. The moment a program starts
behaving like a dropper or an infostealer, it **cuts the internet** and shows a
full-screen alert. The connection stays blocked until you enter your **4-digit PIN**.

It does **not** replace an antivirus or EDR. It is an extra layer that works
alongside them, built around one idea: *if something looks like it is about to
steal your data, pull the plug before the data can leave.*

---

## Why it exists

It was built after a real attack: a fake "game installer" (`installer-v3_1.exe`,
internally named `Adobe Desktop Service.exe`) dropped an infostealer that took
browser passwords and session cookies, which led to account takeovers (Epic,
Riot, EA, Microsoft, Facebook, Instagram...). At the time of the attack **only
1 of 68 antivirus engines** detected the file.

Because signature-based detection missed it, Worm-Crawler Defender does not look
for known viruses. It watches **behaviour** that droppers and stealers share, and
reacts by killing network connectivity so stolen data cannot be uploaded.

---

## What it detects

| # | Signal | Windows | Linux |
|---|--------|---------|-------|
| 1 | **Download-and-run / obfuscated code** | PowerShell started with `-EncodedCommand` | `curl\|bash`, `wget\|sh`, `base64 -d\|bash`, `python -c` with exec/base64, long base64 blobs |
| 2 | **Security product tampering** | A new Microsoft Defender **exclusion** added; real-time protection turned **off** | — |
| 3 | **Suspicious execution location** | — | A binary running from `/tmp`, `/dev/shm`, `/var/tmp` |
| 4 | **New persistence added** | (covered by exclusion/autostart audit) | New cron job, systemd unit, or autostart entry |
| 5 | **Browser cookie/credential theft** | A non-browser process **reads** `Cookies`, `Login Data`, `Local State`, `cookies.sqlite`, `logins.json`, `key4.db` | Same, detected via open file descriptors |
| 6 | **Keylogger** | *Not detected* — needs ETW / a kernel driver (out of scope) | A non-input process reading the keyboard devices `/dev/input/event*` (best-effort) |
| 7 | **Self-tampering** | Protection closed/killed without PIN; watchdog deleted/disabled | Same |

When any signal fires, the tool:

1. **Blocks every network interface** (Ethernet, Wi-Fi). The block is re-applied
   continuously, so turning the adapter back on from the OS settings does not help.
2. **Shows a red on-screen alert** (a window, not just a notification) with the reason.
3. **Logs everything**, including the decoded command, so you can see exactly what happened.

The connection stays blocked until you run the unlock command and enter your PIN.

---

## Browser cookie/credential protection — and its honest limit

This is signal #5 and deserves a clear explanation.

- **Windows:** the installer places an **audit rule (SACL)** on the browsers'
  secret files and enables File System object-access auditing. When a process
  **other than the browser** reads one of those files, Windows writes event
  **4663** to the Security log; the monitor watches for it and cuts the network.
- **Linux:** every cycle the monitor checks (via `/proc/*/fd`) whether a
  **non-browser** process holds a cookie/credential file open, and cuts the network if so.

> ⚠️ **Important limitation.** Reading a local file is almost instantaneous. By the
> time any user-space tool notices the access, the stealer may already have the
> bytes in memory. What this **reliably** stops is the **exfiltration** (the slower
> step: DNS, TLS handshake, upload). So cutting the network the instant cookie
> access is seen **greatly reduces** the chance the data leaves — but it cannot
> guarantee zero. Preventing the *read itself* requires a kernel driver / EDR.

---

## The 4-digit PIN

You choose a PIN during installation. It is the only way to lift a block or stop
the protection. Without it you **cannot**:

- unlock the internet after an alert,
- stop the protection,
- change the PIN,
- uninstall or reinstall.

You get 3 attempts per prompt; wrong attempts are logged.

**Forced shutdown.** If the protection is stopped without the PIN (process killed,
task/service deleted or disabled), the watchdog notices within **one minute**,
blocks the internet, tries to restart the protection, and shows an alert. The two
components guard each other: if the watchdog is removed, the main process also
blocks the network.

**How the PIN is stored.** Never in clear text — only as a cryptographic hash
(PBKDF2, 100,000 iterations), in a folder **separate from the program** so it
survives deletion of the program folder, readable only by the administrator/root.
A backup copy (`pin.bak`) is kept; if one file is deleted, the other restores it.

- Windows: `C:\ProgramData\WormCrawler-Secure`
- Linux: `/etc/worm-crawler-defender/secure`

**Forgot the PIN?**
- Windows: boot into Safe Mode, delete `C:\ProgramData\WormCrawler-Secure`, reboot, run the installer again.
- Linux: as root, `sudo rm -rf /etc/worm-crawler-defender`, then run `sudo ./install.sh` again.

---

## Windows

### Requirements
Windows 10 or 11, an administrator account, and Windows Defender enabled.

### Install
1. Unzip `WormCrawler-Defender.zip`.
2. Double-click **`1_Install.cmd`** and accept the administrator prompt.
3. Choose a 4-digit PIN.
4. Run **`2_Test.cmd`** — it launches a harmless encoded command; the internet
   should block and the alert should appear within seconds.
5. Unlock with the Desktop shortcut **"Worm-Crawler Defender - Unlock Internet"** + PIN.

### Everyday use
A **system-tray icon** shows the state (active / internet blocked / stopped / not responding).
Right-click it for: Status, Open log, Unlock Internet (PIN), Stop Protection (PIN),
Start Protection, Change PIN.

### Components (scheduled tasks)
| Task | Runs as | When | Role |
|------|---------|------|------|
| `WormCrawler` | SYSTEM | at boot, continuous | the guard itself |
| `WormCrawler-Watchdog` | SYSTEM | logon + every minute | watchdog |
| `WormCrawler-Alert` | logged-in user | on alert | shows the alert window |
| `WormCrawler-Tray` | logged-in user | at logon | tray icon |

Files live in `C:\ProgramData\WormCrawler`; the log is `wormcrawler.log`.

### Uninstall
`3_Uninstall.cmd` (asks for the PIN).

---

## Linux

### Compatibility
Any systemd distro — Ubuntu, Debian, Linux Mint, Fedora, Arch, Manjaro, openSUSE,
Pop!_OS, etc. (auto-detected). Without systemd it falls back to a `@reboot` cron
job plus a supervisor. Needs `python3` **or** `openssl` for the PIN (present on
virtually every distro). Graphical alerts use zenity/kdialog/notify-send/xmessage
if present; otherwise alerts go to the terminal (`wall`).

### Install
```bash
unzip WormCrawler-Defender-Linux.zip
cd wcd-linux
sudo ./install.sh          # if you forget sudo, it re-invokes itself
```
Choose a 4-digit PIN, then test:
```bash
sudo wcd-test              # harmless; the internet blocks and an alert appears
sudo wcd-unlock            # enter the PIN to restore
```

### Commands
```bash
sudo wcd-unlock            # unlock the internet after an alert (PIN)
wcd-protect status         # show protection + internet state
sudo wcd-protect stop      # stop protection (PIN)
sudo wcd-protect start     # start it again
sudo wcd-protect pin       # change the PIN (old PIN required)
```

### Where things live
```
/opt/worm-crawler-defender          scripts
/etc/worm-crawler-defender/secure   PIN (pin.dat, pin.bak) — root only
/var/lib/worm-crawler-defender      state (block flag, saved interfaces...)
/var/log/worm-crawler-defender.log  log
systemd: worm-crawler-defender.service + wcd-watchdog.timer
```

### Uninstall
```bash
sudo ./uninstall.sh        # asks for the PIN
```

---

## Limitations (read this)

- **Detection is time-boxed.** Process/file scanning runs on a ~2-second cycle;
  a forced shutdown is caught within a minute. A very fast stealer may send
  something before the tool reacts. It **reduces damage, it does not eliminate it.**
- **A root/admin-level attacker** can, in theory, delete every component at once,
  leaving nothing to react. If it merely stops the protection, the network is blocked.
- **False positives happen.** Some legitimate installers use `curl | bash`; some
  tools legitimately touch browser files. Check the log to see what triggered an alert.
- **Keyloggers:** on **Linux** there is a best-effort signal (a non-input process
  reading `/dev/input/event*`); on **Windows** keylogger detection is **not in scope**
  (it needs ETW or a kernel driver / EDR). In both cases what is reliably stopped is
  the *sending* of captured keystrokes, not the capture itself.
- **Not an antivirus/EDR.** The strongest protection is still not running files sent
  to you in private messages, whoever the sender appears to be.

---

## Safety & scope

This is a defensive tool. It only ever **blocks your own machine's network** and
requires a PIN **you** set. It does not exfiltrate anything, hide itself, or
disguise its files as system components — everything is clearly named and visible.

**Disclaimer:** provided as-is, without warranty. Test it on your own system and
keep your PIN somewhere safe.

---

*Worm-Crawler Defender — made by REDAOT*
