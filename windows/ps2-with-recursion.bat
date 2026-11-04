@echo off
rem ps2-with-recursion.bat: Steam runs this instead of LaunchPad.exe (see ps2-with-recursion).
rem It hands over to ps2-with-recursion.js, run by wscript.exe, which has no console window,
rem and exits at once. https://github.com/ltsjoe/ps2-with-recursion  (GPL-3.0-or-later)
start "" wscript.exe "%~dp0ps2-with-recursion.js" %*
