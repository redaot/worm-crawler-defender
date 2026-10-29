#!/usr/bin/env bash
# Worm-Crawler Defender - harmless test. made by REDAOT
# Runs a "download-and-run" style command that only decodes the word 'true'.
# The guard should BLOCK the internet and show an alert within a few seconds.
echo "Test: running a HARMLESS encoded command (it only decodes 'true')."
echo "Within a few seconds the internet should be blocked and an alert should appear."
echo "Then unlock with:  sudo wcd-unlock"
echo
# 'dHJ1ZQo=' = base64 for "true"
echo 'dHJ1ZQo=' | base64 -d | bash
echo "The test command has run. Wait for the guard to react..."
