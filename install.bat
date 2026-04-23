@echo off
setlocal EnableDelayedExpansion

if not "%~2"=="" (
  echo [ERROR] Too many arguments.
  echo Usage: %~nx0 ["PROJECT_ROOT_PATH"]
  timeout /t 10 /nobreak >nul
  exit /b 1
)

if "%~1"=="" (
  set "PROJECT_ROOT=%USERPROFILE%"
) else (
  set "PROJECT_ROOT=%~1"
)

set "SOURCE_DIR=%~dp0."
set "TARGET_DIR=%PROJECT_ROOT%\.cursor\plugins\local\r2e"

for %%I in ("%SOURCE_DIR%") do set "SOURCE_ABS=%%~fI"
for %%I in ("%PROJECT_ROOT%") do set "PROJECT_ROOT_ABS=%%~fI"

set "SOURCE_NORM=!SOURCE_ABS!"
if "!SOURCE_NORM:~-1!"=="\" set "SOURCE_NORM=!SOURCE_NORM:~0,-1!"
set "PROJECT_NORM=!PROJECT_ROOT_ABS!"
if "!PROJECT_NORM:~-1!"=="\" set "PROJECT_NORM=!PROJECT_NORM:~0,-1!"

if /I "!PROJECT_NORM!"=="!SOURCE_NORM!" (
  echo [ERROR] Invalid install target.
  echo [ERROR] Project root must not share source path prefix.
  echo [ERROR] Source: !SOURCE_NORM!
  echo [ERROR] Project root: !PROJECT_NORM!
  timeout /t 10 /nobreak >nul
  exit /b 1
)

set "PROJECT_AFTER_PREFIX=!PROJECT_NORM:%SOURCE_NORM%\=!"
if /I not "!PROJECT_AFTER_PREFIX!"=="!PROJECT_NORM!" (
  echo [ERROR] Invalid install target.
  echo [ERROR] Project root must not share source path prefix.
  echo [ERROR] Source: !SOURCE_NORM!
  echo [ERROR] Project root: !PROJECT_NORM!
  timeout /t 10 /nobreak >nul
  exit /b 1
)

echo Source: %SOURCE_DIR% ^| Target: %TARGET_DIR%

if not exist "%SOURCE_DIR%\.cursor-plugin\plugin.json" (
  echo [ERROR] Plugin manifest not found: %SOURCE_DIR%\.cursor-plugin\plugin.json
  timeout /t 10 /nobreak >nul
  exit /b 1
)

if exist "%TARGET_DIR%\" (
  echo Removing existing plugin: %TARGET_DIR%
  rmdir /s /q "%TARGET_DIR%"
  if errorlevel 1 (
    echo [ERROR] Failed to remove existing plugin directory.
    timeout /t 10 /nobreak >nul
    exit /b 1
  )
)

robocopy "%SOURCE_DIR%" "%TARGET_DIR%" /e /xf "install.bat" "uninstall.bat" >nul
set "ROBOCOPY_EXIT=%errorlevel%"
if %ROBOCOPY_EXIT% GEQ 8 (
  echo [ERROR] Failed to copy plugin files. ^(robocopy exit code: %ROBOCOPY_EXIT%^) 
  timeout /t 10 /nobreak >nul
  exit /b 1
)

echo Plugin installed successfully. Please restart Cursor
timeout /t 10 /nobreak >nul
exit /b 0
