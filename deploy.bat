@echo off
setlocal enabledelayedexpansion
cd /d "%~dp0"

echo.
echo ================================================
echo   Donaeun Tax - GitHub Pages Deploy
echo ================================================
echo.

where gh >nul 2>&1
if errorlevel 1 (
  echo [X] GitHub CLI not found.
  echo     Install: winget install --id GitHub.cli
  echo     Then: gh auth login
  pause
  exit /b 1
)

where git >nul 2>&1
if errorlevel 1 (
  echo [X] Git not found.
  echo     Install: winget install --id Git.Git
  pause
  exit /b 1
)

gh auth status >nul 2>&1
if errorlevel 1 (
  echo [!] Not logged in to GitHub. Starting login...
  gh auth login
  if errorlevel 1 (
    echo Login failed. Please retry.
    pause
    exit /b 1
  )
)

for /f "delims=" %%i in ('gh api user -q .login 2^>nul') do set GHUSER=%%i
if "%GHUSER%"=="" (
  echo [X] Failed to get GitHub username.
  pause
  exit /b 1
)
echo Logged in as: %GHUSER%
echo.

set /p REPO="Repository name (default: donaeun-tax): "
if "%REPO%"=="" set REPO=donaeun-tax

if exist ".git" (
  echo [!] This folder is already a git repo. Use redeploy.bat instead.
  pause
  exit /b 1
)

echo.
echo [1/4] Initializing local git...
git init -q
git checkout -q -b main
git add .
git -c user.email="%GHUSER%@users.noreply.github.com" -c user.name="%GHUSER%" commit -q -m "initial deploy"
if errorlevel 1 (
  echo [X] Commit failed.
  pause
  exit /b 1
)

echo [2/4] Creating GitHub repository and pushing...
gh repo create "%REPO%" --public --source=. --push --description "Donaeun Tax - Income tax filing intake form" --remote=origin
if errorlevel 1 (
  echo [X] Repo creation failed. Name may already exist.
  pause
  exit /b 1
)

echo [3/4] Enabling GitHub Pages...
gh api -X POST /repos/%GHUSER%/%REPO%/pages -f "source[branch]=main" -f "source[path]=/" >nul 2>&1

echo [4/4] Waiting 60 seconds for deployment...
timeout /t 60 /nobreak >nul

set URL=https://%GHUSER%.github.io/%REPO%/
echo.
echo ================================================
echo   Deploy complete!
echo ================================================
echo.
echo   Site URL: %URL%
echo.
echo   Repo: https://github.com/%GHUSER%/%REPO%
echo.
echo   To update later, run: redeploy.bat
echo.

start "" "%URL%"

pause
endlocal
