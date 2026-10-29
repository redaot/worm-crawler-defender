# Changelog

All notable changes to Worm-Crawler Defender are documented here.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and the project aims to follow [Semantic Versioning](https://semver.org/).

## [1.0.0] — 2026-10-29

First public release. A behavioural tripwire that cuts the network and raises a
PIN-locked alert when a program behaves like a dropper or an infostealer.

### Added
- **Windows build** (PowerShell + Scheduled Tasks, runs as SYSTEM):
  - Detects a new Microsoft Defender exclusion and real-time protection being turned off.
  - Detects PowerShell launched with a hidden `-EncodedCommand` (decodes it into the log).
  - **Browser cookie/credential theft detection** via File System object-access
    auditing (SACL + event 4663): alarms when a non-browser process reads
    `Cookies`, `Login Data`, `Local State`, `cookies.sqlite`, `logins.json`, `key4.db`.
  - System-tray icon with status, log, unlock, stop/start, change-PIN.
- **Linux build** (Bash + systemd, with a cron fallback for non-systemd):
  - Detects download-and-run / obfuscated commands (`curl|bash`, `base64 -d|bash`,
    `python -c` with exec/base64, long base64 blobs).
  - Detects binaries executing from `/tmp`, `/dev/shm`, `/var/tmp`.
  - Detects new persistence (cron, systemd unit, autostart).
  - **Browser cookie/credential theft detection** via `/proc/*/fd`.
  - Auto-detects the distribution and init system during install.
- **Failsafe browser coverage**: cookie/credential files are recognised by
  structure and filename (Chromium `User Data`, Mozilla `cookies.sqlite`/
  `logins.json`/`key4.db`, Opera-style profiles), so Chrome, Edge, Brave, Opera,
  Opera GX, Vivaldi, Yandex, Firefox and forks (LibreWolf, Waterfox, Pale Moon,
  Tor) are covered, including per-user installs. Electron apps reading their own
  cookie stores (Discord, Slack, VS Code) are excluded to avoid false positives.
- **4-digit PIN** required to unlock the network, stop protection, change the PIN,
  or uninstall. Stored only as a PBKDF2 hash (100,000 iterations), in a folder
  separate from the program so it survives deletion of the program folder, with a
  backup copy.
- **Self-protection**: on a forced shutdown without the PIN, a watchdog blocks the
  network within a minute, tries to restart, and alerts; the guard and the
  watchdog protect each other.
- On-screen **alert window** (not just a notification) + full log.

### Known limitations
- Detection runs on a ~2-second cycle; a forced shutdown is caught within a
  minute. A very fast stealer may send data before the tool reacts — it reduces
  damage, it does not eliminate it.
- Cutting the network reliably stops *exfiltration*; it cannot guarantee the local
  *read* was prevented. Preventing the read itself needs a kernel driver / EDR.
- A root/admin-level attacker that deletes all components at once leaves nothing to react.
- A very exotic browser whose process is not in the trusted list may cause a false
  positive when it reads its own cookies.

[1.0.0]: https://github.com/redaot/worm-crawler-defender/releases/tag/v1.0.0
