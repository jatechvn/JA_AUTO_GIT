@echo off
title JA Auto Git - Debug Mode
cd /d %~dp0

echo =======================================================================
echo              JA AUTO GIT - DEBUG ^& VERBOSE LOGGING MODE
echo =======================================================================
echo.
echo Starting application in DEBUG mode with live stdout/stderr stream...
echo Operation logs will be saved to: logs\yyyy-mm-dd.log
echo.

set DEBUG=true
call flutter run -d windows --debug

pause
