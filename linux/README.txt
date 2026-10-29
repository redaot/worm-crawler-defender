WORM-CRAWLER DEFENDER for Linux  -  v1.0.0
made by REDAOT
==================================================

WHAT IT DOES
Runs permanently in the background (as a root service, starts with the
system) and BLOCKS THE INTERNET + shows an alert when it detects:
  1. a "download-and-run" process  ( curl|bash, wget|sh, base64 -d|bash,
     python -c with exec/base64, long base64 blobs )
  2. an executable started from /tmp, /dev/shm or /var/tmp
     (the typical place a dropper leaves its payload)
  3. new persistence added: cron, systemd service, or autostart
  4. a non-browser process opening the browser cookies/credentials
     (Firefox: cookies.sqlite/logins.json/key4.db;
      Chrome/Chromium/Brave/Edge/Opera/Vivaldi: Cookies / Login Data)
  5. the protection being force-closed (without the PIN)
The internet stays blocked until you enter your 4-digit PIN.

BROWSER COOKIE/CREDENTIAL DETECTION (signal 4)
  Every cycle the guard checks (via /proc/*/fd) whether a process that is
  NOT the browser holds a cookie/credential file open. If so, it cuts the
  internet. It is failsafe for all common browsers (recognised by filename
  and folder, not a fixed list). IMPORTANT: a local read is almost instant,
  so what is reliably stopped is the SENDING of the data, not necessarily
  the read. It greatly reduces the risk but does not make it zero (for that
  you would need fanotify/EDR at the kernel level).

COMPATIBILITY
  - Any systemd distro: Ubuntu, Debian, Linux Mint, Fedora, Arch, Manjaro,
    openSUSE, Pop!_OS, etc. (auto-detected).
  - Without systemd: started via cron @reboot + a supervisor (automatic).
  - Needs python3 OR openssl (for the PIN) - present on almost every distro.
    Graphical alerts use zenity/kdialog/notify-send/xmessage if available;
    otherwise the alert appears in the terminal.

INSTALL
  1. Unzip the folder.
  2. In a terminal, inside the folder:   sudo ./install.sh
     (if you forget 'sudo', the script asks for it itself)
  3. Choose a 4-digit PIN.
  4. Test:   sudo wcd-test
     (the test command is harmless; the internet blocks and an alert appears)
  5. Unlock the internet:   sudo wcd-unlock   (enter the PIN)

COMMANDS
  sudo wcd-unlock              unlock the internet after an alert (asks for PIN)
  wcd-protect status           show the protection + internet state
  sudo wcd-protect stop        stop the protection (asks for PIN)
  sudo wcd-protect start       start it again
  sudo wcd-protect pin         change the PIN (asks for the old PIN)

THE 4-DIGIT PIN
  - Without it you cannot unlock the internet, stop the protection or uninstall.
  - Stored only as a cryptographic hash (PBKDF2, 100,000 iterations), in a
    SEPARATE folder:  /etc/worm-crawler-defender/secure  (root only). This
    way it survives deletion of the program folder (/opt/worm-crawler-defender).
    It also has a backup copy (pin.bak): if one is deleted, the other restores it.
  - Force shutdown without the PIN -> within a minute the watchdog blocks the
    internet, restarts the guard, and shows a window.
  - Mutual guard: if the watchdog is disabled, the main guard also blocks the internet.
  - Forgot the PIN? As root:  sudo rm -rf /etc/worm-crawler-defender
    then run  sudo ./install.sh  again and choose a new one.

WHERE THINGS ARE
  /opt/worm-crawler-defender          the scripts
  /etc/worm-crawler-defender/secure   the PIN (pin.dat, pin.bak) - root only
  /var/lib/worm-crawler-defender      state (blocked.flag, saved_net...)
  /var/log/worm-crawler-defender.log  the log
  systemd: worm-crawler-defender.service + wcd-watchdog.timer

UNINSTALL
  sudo ./uninstall.sh     (asks for the PIN)

LIMITS (important)
  - Process/file scanning runs on a ~2-second cycle; a very fast program may
    send something first. It reduces damage, it does not eliminate it.
  - A root attacker can delete all components at once; then nothing is left
    to react. If it merely stops the protection, the internet is blocked.
  - Some legitimate commands (installers that do 'curl | bash') may trigger a
    false alert. Check the log to see which command it was.
  - Not an antivirus/EDR. An extra layer + good habits: do not run files
    received in private messages.
