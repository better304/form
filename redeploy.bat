@echo off
setlocal enabledelayedexpansion
cd /d "%~dp0"

echo.
echo ================================================
echo   Donaeun Tax - Redeploy Update
echo ================================================
echo.

if not exist ".git" (
  echo [X] Not deployed yet. Run deploy.bat first.
  pause
  exit /b 1
)

git status --porcelain > _diff.tmp
for %%A in (_diff.tmp) do set DIFFSIZE=%%~zA
del _diff.tmp

if "%DIFFSIZE%"=="0" (
  echo [!] No changes to deploy.
  pause
  exit /b 0
)

echo Changed files:
git status -s
echo.

set /p MSG="Commit message (Enter for auto date): "
if "%MSG%"=="" (
  for /f "tokens=1-3 delims=/-. " %%a in ('date /t') do set D=%%a-%%b-%%c
  for /f "tokens=1-2 delims=:. " %%a in ('time /t') do set T=%%a:%%b
  set MSG=update !D! !T!
)

echo.
echo [1/3] Committing...
for /f "delims=" %%i in ('gh api user -q .login 2^>nul') do set GHUSER=%%i
git add .
git -c user.email="%GHUSER%@users.noreply.github.com" -c user.name="%GHUSER%" commit -q -m "%MSG%"
if errorlevel 1 (
  echo [X] Commit failed.
  pause
  exit /b 1
)

echo [2/3] Pushing to GitHub...
git push -q origin main
if errorlevel 1 (
  echo [X] Push failed. Check: gh auth status
  pause
  exit /b 1
)

echo [3/3] Waiting 30 seconds for rebuild...
timeout /t 30 /nobreak >nul

for /f "delims=" %%i in ('git config --get remote.origin.url') do set REMOTE=%%i
echo.
echo ================================================
echo   Redeploy complete!
echo ================================================
echo.
echo   Repo: %REMOTE%
echo.
echo   Site updates in 1-2 minutes.
echo.
pause
endlocal
