# Security Policy

## Reporting a vulnerability

If you find a security weakness in Worm-Crawler Defender itself — for example a
way to bypass the PIN, disable the protection without it, or make the tool run
attacker-controlled code — please report it **privately** first:

- Use GitHub's **"Report a vulnerability"** (Security → Advisories) if enabled, or
- open a minimal issue asking for a private contact, without the exploit details.

Please do **not** post a working bypass or exploit publicly before it is fixed.

Include, if you can:
- affected build (Windows / Linux) and version,
- a clear description of the weakness and its impact,
- steps or a proof of concept (describe it; don't attach live malware — share a
  SHA-256 hash or a sandbox link instead).

## Scope

In scope: the tool's own scripts, the PIN mechanism, the network-block and
watchdog logic, the installer/uninstaller.

Out of scope (known and documented in the README): the ~2-second detection
window, the fact that a local file read can complete before the network is cut,
and a root/admin attacker deleting all components at once. These are inherent
limits of a user-space tool, not vulnerabilities.

## No warranty

This software is provided "as is", under the MIT License, without warranty of any
kind. It is an extra layer, not a replacement for an antivirus/EDR or for careful
habits.
