@echo off
setlocal
cd /d "%~dp0"

echo.
echo ================================================
echo   Donaeun Tax - Republish Site
echo ================================================
echo.

where gh >nul 2>&1
if errorlevel 1 (
  echo [X] GitHub CLI not found.
  pause
  exit /b 1
)

for /f "delims=" %%i in ('gh api user -q .login 2^>nul') do set GHUSER=%%i
if "%GHUSER%"=="" (
  echo [X] Not logged in. Run: gh auth login
  pause
  exit /b 1
)

set REPO=form
if not "%~1"=="" set REPO=%~1

echo Target: %GHUSER%/%REPO%
echo.
echo Re-enabling GitHub Pages...
gh api -X POST /repos/%GHUSER%/%REPO%/pages -f "source[branch]=main" -f "source[path]=/"
if errorlevel 1 (
  echo [!] Failed. Pages may already be enabled.
  pause
  exit /b 1
)

echo.
echo Waiting 30 seconds for build...
timeout /t 30 /nobreak >nul

set URL=https://%GHUSER%.github.io/%REPO%/
echo.
echo ================================================
echo   Site republished!
echo ================================================
echo.
echo   URL: %URL%
echo.

start "" "%URL%"
pause
endlocal
