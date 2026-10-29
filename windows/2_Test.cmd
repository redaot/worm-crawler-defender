@echo off
title Worm-Crawler Defender - Test
echo This test starts PowerShell with a HARMLESS encoded command
echo (it only prints a line of text). Worm-Crawler Defender should block
echo the internet and show the alert within a few seconds.
echo.
echo After the test, unlock with the Desktop shortcut + your PIN.
echo.
pause
powershell -NoProfile -EncodedCommand VwByAGkAdABlAC0ASABvAHMAdAAgACcAVwBvAHIAbQAtAEMAcgBhAHcAbABlAHIAIABEAGUAZgBlAG4AZABlAHIAIAB0AGUAcwB0ADoAIABoAGEAcgBtAGwAZQBzAHMAIABlAG4AYwBvAGQAZQBkACAAYwBvAG0AbQBhAG4AZAAgACgAcwBoAG8AdwBzACAAbwBuAGwAeQAgAHQAaABpAHMAIAB0AGUAeAB0ACkALgAnADsAIABTAHQAYQByAHQALQBTAGwAZQBlAHAAIAA1AA==
pause
