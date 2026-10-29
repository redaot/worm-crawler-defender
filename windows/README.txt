WORM-CRAWLER DEFENDER (Windows)  -  v1.1.0
made by REDAOT
==========================================================

WHAT IT DOES
Runs permanently in the background (as SYSTEM, starts with Windows) and
BLOCKS THE INTERNET + shows an alert when it sees:
  1. a new EXCLUSION added in Windows Defender
  2. Defender real-time protection turned OFF
  3. PowerShell started with a HIDDEN command (-EncodedCommand)
  4. a program other than the browser READING the browser cookies/credentials
  5. an UNSIGNED program launched from a staging location (Temp / Downloads)
The internet stays blocked until you enter your 4-digit PIN.

BROWSER COOKIE/CREDENTIAL DETECTION (signal 4)
  It puts an AUDIT on the browsers' secret files (Cookies, Login Data,
  Local State, cookies.sqlite, logins.json, key4.db). When a process that
  is NOT the browser reads them, it cuts the internet. It is failsafe for
  all common browsers (Chrome, Edge, Brave, Opera/GX, Vivaldi, Yandex,
  Firefox and forks), recognised by structure and filename, not a fixed list.
  IMPORTANT: reading a local file is almost instant, so what is reliably
  stopped is the SENDING of the data (the slower step), not necessarily the
  read. It greatly reduces the risk but does not make it zero - for that you
  would need a kernel driver / EDR.

4-DIGIT PIN
  On first install you choose a 4-digit PIN. Without it you CANNOT:
    - unlock the internet after an alert
    - stop the protection
    - change the PIN or uninstall/reinstall
  If the protection is force-closed WITHOUT the PIN, within a minute the
  internet is BLOCKED and stays blocked until you enter the PIN.
  Change the PIN from the tray icon: "Change PIN".
  Forgot the PIN? Boot into Safe Mode, delete the folder
  C:\ProgramData\WormCrawler-Secure, reboot, then run 1_Install.cmd again.

INSTALL
  1. Unzip the folder (e.g. onto the Desktop).
  2. Double-click 1_Install.cmd -> accept the Administrator prompt.
  3. Choose a 4-digit PIN.
  4. Run 2_Test.cmd to check it works (the test command is harmless; the
     internet will be blocked and an alert will appear).
  5. Unlock the internet (with the PIN) using the Desktop shortcut
     "Worm-Crawler Defender - Unlock Internet".
  After install you can delete the unzipped folder; the program stays in
  C:\ProgramData\WormCrawler.

AUTOMATIC START AND WATCHDOG
  - Worm-Crawler Defender starts with the PC and restarts if it stops.
  - "WormCrawler-Watchdog" checks at logon and every minute that the
    protection is running. If it was closed WITHOUT the PIN, it blocks the
    internet, tries to restart it, and shows an on-screen WINDOW:
      * "STOPPED WITHOUT PIN - INTERNET BLOCKED" -> it was restarted; if you
        did not do it, it's suspicious. Unlock the internet with your PIN.
      * "NOT RUNNING - INTERNET BLOCKED" -> restart failed; run 1_Install.cmd again.
  - Mutual guard: if the watchdog is deleted/disabled, the main guard also
    blocks the internet.

SYSTEM-TRAY ICON
  Next to the clock. Right-click: Status, Open log, Unlock Internet (PIN),
  Stop Protection (PIN), Start Protection, Change PIN. If the protection is
  not responding, the icon turns into a yellow warning triangle.

WHERE THINGS ARE
  C:\ProgramData\WormCrawler          scripts
  C:\ProgramData\WormCrawler-Secure   PIN (pin.dat, pin.bak) - admin only
  C:\ProgramData\WormCrawler\wormcrawler.log   the log
  Scheduled tasks: WormCrawler, WormCrawler-Watchdog, WormCrawler-Alert, WormCrawler-Tray

UNINSTALL
  3_Uninstall.cmd (asks for the PIN)

LIMITS (important)
  - Any exclusion added in Defender, including by you, triggers the alert.
    That's intentional: it's exactly the moment to stop and think.
  - Some legitimate programs use encoded PowerShell; rarely you may get a
    false alert. Check the log to see which command it was.
  - A malware running WITH ADMINISTRATOR rights can, in theory, stop the
    protection; then the internet is blocked. If it deletes all components
    at once, nothing is left to react.
  - Detection runs on a ~2-second cycle. A very fast stealer may send
    something first; it reduces damage, it does not guarantee zero.
  - KEYLOGGERS are NOT detected on Windows. Reliable keylogger detection
    needs ETW or a kernel driver / EDR, which is out of scope for a script
    tool. The tool still helps against stealers that bundle a keylogger
    (it catches the dropper / cookie theft and cuts the network before the
    captured data can be sent). The Linux build has a best-effort keyboard
    (/dev/input) signal; the Windows build does not.
  - Not an antivirus/EDR. The best protection is still not running files
    received in private messages, whoever the sender appears to be.
