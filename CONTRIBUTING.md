# Contributing

Thanks for your interest in Worm-Crawler Defender! Bug reports, false-positive
reports, and pull requests are all welcome.

## Reporting a bug

Open a GitHub **Issue** and include:

- **OS and version** (e.g. Windows 11 23H2, Ubuntu 24.04, Fedora 40).
- **Which build**: Windows or Linux.
- **What happened vs. what you expected.**
- **Relevant log lines** from:
  - Windows: `C:\ProgramData\WormCrawler\wormcrawler.log`
  - Linux: `/var/log/worm-crawler-defender.log`
- Steps to reproduce, if you have them.

## Reporting a false positive

If the tool blocked the network for something harmless, that's useful to know.
Please include, from the log, the **reason line** and especially:

- the **process name/path** that triggered it, and
- the **file or command** involved.

For the common case — *a legitimate browser whose process isn't on the trusted
list, triggering on its own cookies* — just tell us the **exact process name**
(Windows) or **executable path** (Linux) and we'll add it.

## ⚠️ Do NOT attach malware

This is a security project. **Never** attach real malware samples, live payloads,
or working exploit code to an issue or PR. Instead share:

- a **SHA-256 hash**, and/or
- a link to a sandbox report (e.g. tria.ge, any.run, VirusTotal).

## Development notes

The tool is deliberately dependency-light and readable.

- **Windows**: PowerShell 5.1 (built into Windows) + Scheduled Tasks. No external modules.
- **Linux**: Bash + coreutils + systemd; `python3` *or* `openssl` for the PIN. No extra packages required.
- Keep it **portable** (works across distros / Windows editions) and **transparent**
  (clearly named files, no hiding, no masquerading as system components).

### Before opening a PR

- **Windows**: syntax-check each script, e.g.
  ```powershell
  Get-ChildItem *.ps1 | ForEach-Object {
    $e=$null; [System.Management.Automation.Language.Parser]::ParseFile($_.FullName,[ref]$null,[ref]$e) | Out-Null
    if ($e.Count) { "$($_.Name): $($e.Count) errors" }
  }
  ```
- **Linux**: `bash -n` every script:
  ```bash
  for f in install.sh uninstall.sh worm-crawler-defender/*.sh; do bash -n "$f" || echo "ERR $f"; done
  ```
- Test on a spare machine or VM, not your main system. Use the built-in
  `2_Test.cmd` / `sudo wcd-test` to confirm detection still fires.
- Keep line endings correct: **CRLF** for Windows files, **LF** for Linux files.

### Scope & philosophy

Worm-Crawler Defender is a lightweight **extra layer**, not an antivirus or EDR.
Changes should keep it simple, auditable, and honest about its limits. Features
that would make it behave like malware (hiding, disguising files, tampering with
other software without consent) are out of scope.

## License

By contributing, you agree that your contributions are licensed under the
project's [MIT License](LICENSE).
