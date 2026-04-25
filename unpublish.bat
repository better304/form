@echo off
setlocal
cd /d "%~dp0"

echo.
echo ================================================
echo   Donaeun Tax - Unpublish Site (temporary)
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
set /p CONFIRM="Unpublish the site? Repo stays. Type 'yes' to confirm: "
if /i not "%CONFIRM%"=="yes" (
  echo Cancelled.
  pause
  exit /b 0
)

echo.
echo Disabling GitHub Pages...
gh api -X DELETE /repos/%GHUSER%/%REPO%/pages
if errorlevel 1 (
  echo [!] Failed or already unpublished.
  pause
  exit /b 1
)

echo.
echo ================================================
echo   Site unpublished. Repo and code are kept.
echo ================================================
echo.
echo   The URL https://%GHUSER%.github.io/%REPO%/
echo   will return 404 within 1-2 minutes.
echo.
echo   To republish: run republish.bat
echo.
pause
endlocal
