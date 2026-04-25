@echo off
setlocal
cd /d "%~dp0"
echo.
echo ================================================
echo   Local Test Server (PowerShell HttpListener)
echo ================================================
echo.
echo   URL: http://localhost:8000/
echo   Stop: Ctrl+C
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0serve.ps1"
endlocal
