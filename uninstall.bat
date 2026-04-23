@echo off
setlocal

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

set "TARGET_DIR=%PROJECT_ROOT%\.cursor\plugins\local\r2e"

echo Target: %TARGET_DIR%

if not exist "%TARGET_DIR%\" (
  echo Plugin not found, nothing to uninstall.
  timeout /t 10 /nobreak >nul
  exit /b 0
)

rmdir /s /q "%TARGET_DIR%"
if errorlevel 1 (
  echo [ERROR] Failed to remove plugin directory.
  timeout /t 10 /nobreak >nul
  exit /b 1
)

echo Plugin uninstalled successfully. Please restart Cursor
timeout /t 10 /nobreak >nul
exit /b 0
