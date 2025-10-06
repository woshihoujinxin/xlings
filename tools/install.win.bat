@echo off
REM Robust Windows installer with multi-source xmake installation and fallbacks

setlocal ENABLEDELAYEDEXPANSION

REM SCRIPT_DIR ends with \
set "SCRIPT_DIR=%~dp0"
set "RUN_DIR=%cd%"
set "XLINGS_PROJECT_DIR=%SCRIPT_DIR%.."
set "XLINGS_TMP_BIN_DIR=%XLINGS_PROJECT_DIR%\bin"
set "XMAKE_BIN_DIR=%USERPROFILE%\xmake"
set "XLINGS_BIN_DIR=%USERPROFILE%\.xlings_data\bin"

set arg1=%1

echo [RunDir]: %RUN_DIR%
echo [ProjectDir]: %XLINGS_PROJECT_DIR%

cd "%XLINGS_PROJECT_DIR%"
set "PATH=%XLINGS_TMP_BIN_DIR%;%PATH%"

echo [xlings]: start detect environment and try to auto config...

REM 1) Install xmake with multi fallback
call :ensure_xmake
if errorlevel 1 (
    echo [xlings]: ERROR - failed to install xmake by all strategies
    goto :continue_flow
)

echo [xlings]: xmake ready

REM 2) Ensure git
where git >nul 2>&1
IF %ERRORLEVEL% EQU 0 (
    echo [xlings]: git installed
) ELSE (
    echo [xlings]: start install git...
    where winget >nul 2>&1
    IF %ERRORLEVEL% EQU 0 (
        winget install --id Git.Git --source winget --accept-source-agreements --accept-package-agreements
    ) ELSE (
        echo [xlings]: WARN - winget not available, please install Git manually if needed.
    )
)

REM 3) set xlings to PATH if missing
for /f "tokens=2*" %%a in ('reg query "HKEY_CURRENT_USER\Environment" /v PATH 2^>nul') do set UserPath=%%b
echo "%UserPath%" | findstr /i "\.xlings_data\\bin" >nul
if %errorlevel% neq 0 (
    echo [xlings]: set xlings to PATH
    setx PATH "%XLINGS_BIN_DIR%;%UserPath%"
) else (
    echo [xlings]: xlings is already in PATH.
)

REM 4) build & install xlings core
set "PATH=%XLINGS_BIN_DIR%;%XMAKE_BIN_DIR%;%PATH%"
if exist "%cd%\install.win.bat" (
    cd ..
)

cd core
xmake xlings unused self enforce-install
cd ..

REM 5) self init
xlings self init

REM 6) done
echo [xlings]: xlings installed
echo.
echo     run "xlings help" get more information
echo.

goto :eof

REM ======= FUNCTIONS =======

:ensure_xmake
where xmake >nul 2>&1
IF %ERRORLEVEL% EQU 0 (
    echo [xlings]: xmake installed
    exit /b 0
)

echo [xlings]: start install xmake...

REM Try winget
where winget >nul 2>&1
IF %ERRORLEVEL% EQU 0 (
    echo [xlings]: try winget...
    winget install --id xmake-io.xmake --source winget --accept-source-agreements --accept-package-agreements
    if %ERRORLEVEL% EQU 0 (
        where xmake >nul 2>&1 && exit /b 0
    )
)

REM Try choco
where choco >nul 2>&1
IF %ERRORLEVEL% EQU 0 (
    echo [xlings]: try choco...
    choco install xmake -y
    if %ERRORLEVEL% EQU 0 (
        where xmake >nul 2>&1 && exit /b 0
    )
)

REM Try scoop
where scoop >nul 2>&1
IF %ERRORLEVEL% EQU 0 (
    echo [xlings]: try scoop...
    scoop install xmake
    if %ERRORLEVEL% EQU 0 (
        where xmake >nul 2>&1 && exit /b 0
    )
)

REM Fallback: PowerShell from official then mirror
echo [xlings]: try PowerShell online script (xmake.io)...
powershell -NoLogo -NoProfile -ExecutionPolicy Bypass -Command ^
  "try { ^
      $ProgressPreference='SilentlyContinue'; ^
      $u='https://xmake.io/psget.text'; ^
      $r=Invoke-WebRequest -Uri $u -UseBasicParsing -TimeoutSec 10; ^
      iex $r.Content; ^
      $true ^
  } catch { ^
      $false ^
  }" 
if %ERRORLEVEL% EQU 0 (
    where xmake >nul 2>&1 && exit /b 0
)

echo [xlings]: fallback to mirror (gitee)...
powershell -NoLogo -NoProfile -ExecutionPolicy Bypass -Command ^
  "try { ^
      $ProgressPreference='SilentlyContinue'; ^
      $u='https://gitee.com/tboox/xmake/raw/master/scripts/psget.text'; ^
      $r=Invoke-WebRequest -Uri $u -UseBasicParsing -TimeoutSec 10; ^
      iex $r.Content; ^
      $true ^
  } catch { ^
      $false ^
  }"
if %ERRORLEVEL% EQU 0 (
    where xmake >nul 2>&1 && exit /b 0
)

exit /b 1

:continue_flow
echo [xlings]: continue but xmake missing may break build
exit /b 0